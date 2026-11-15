#!/usr/bin/python3
"""SPEC CPU2017 SE-mode jobs -> $W/jobs/spec_{test,ref}.json

test : every built rate benchmark, test input, run TO COMPLETION on 1 core
       (AtomicSimpleCPU).  inc vs base output files are diffed afterwards.
ref  : ref input, fast-forward 1e9 insts (atomic), then 2e8 insts on
       TimingSimpleCPU 1 core; plus 4-core multiprogrammed mixes and
       OpenMP SPECspeed (4 threads, multicore) windows.
"""
import glob, json, os, re, shlex, subprocess
W = os.environ["W"]; SPEC = os.environ["SPEC"]; INC = os.environ["INC"]
SE = f"{INC}/configs/deprecated/example/se.py"


def cmds(bench, size):
    rd = sorted(glob.glob(f"{SPEC}/benchspec/CPU/{bench}/run/run_base_{size}_gem5static*"))
    if not rd:
        return None, []
    rd = rd[-1]
    try:
        out = subprocess.run(["specinvoke", "-n"], cwd=rd, capture_output=True, text=True,
                             env=dict(os.environ, PATH=f"{SPEC}/bin:" + os.environ["PATH"]),
                             timeout=60).stdout
    except Exception:
        return rd, []
    res = []
    for line in out.splitlines():
        if line.startswith("#") or not line.strip() or "specinvoke" in line:
            continue
        line = re.sub(r"\s2>>?\s*\S+", "", line)
        m = re.search(r"\s>\s*(\S+)", line)
        stdout_target = os.path.basename(m.group(1)) if m else None
        if m:
            line = line[:m.start()]
        stdin = None
        m = re.search(r"\s<\s*(\S+)", line)
        if m:
            stdin = m.group(1); line = line.replace(m.group(0), "")
        parts = shlex.split(line)
        if parts and os.path.exists(os.path.join(rd, parts[0])):
            # input files -> absolute, so multiprogrammed mixes find them from any cwd
            args = [os.path.join(rd, t) if os.path.exists(os.path.join(rd, t)) else t for t in parts[1:]]
            res.append((os.path.join(rd, parts[0]), " ".join(args), stdin, stdout_target))
    return rd, res


def compare_outputs(rd, size):
    """Read SPEC's own specdiff declarations for this run directory."""
    outputs = []
    path = os.path.join(rd, "compare.cmd")
    if not os.path.isfile(path):
        return outputs
    for line in open(path, errors="replace"):
        if "specdiff" not in line:
            continue
        command = re.split(r"\s>\s", line, maxsplit=1)[0]
        try:
            parts = shlex.split(command)
            index = next(i for i, part in enumerate(parts)
                         if os.path.basename(part) == "specdiff")
        except (ValueError, StopIteration):
            continue
        args = parts[index + 1:]
        expected_index = next((i for i, arg in enumerate(args)
                               if f"/data/{size}/output/" in arg), None)
        if expected_index is None or expected_index + 1 >= len(args):
            continue
        outputs.append({
            "expected": args[expected_index],
            "actual": os.path.basename(args[expected_index + 1]),
            "specdiff_args": args[:expected_index],
        })
    return outputs


def command_outputs(outputs, stdout_target, command_count):
    selected = [item for item in outputs
                if stdout_target and item["actual"] == stdout_target]
    return outputs if command_count == 1 else selected


benches = sorted(os.path.basename(os.path.dirname(os.path.dirname(e)))
                 for e in glob.glob(f"{SPEC}/benchspec/CPU/*/exe/*gem5static*"))
benches = sorted(set(benches) - {"998.specrand_is", "999.specrand_ir", "996.specrand_fs", "997.specrand_fr"})
rate = [b for b in benches if b.endswith("_r")]
speed_omp = [b for b in benches if b in ("657.xz_s", "619.lbm_s", "638.imagick_s", "644.nab_s",
                                         "649.fotonik3d_s", "603.bwaves_s")]
ENV = {"TLBCHK_MAXWARN": "20"}
test_jobs, ref_jobs = [], []

for b in rate:
    rd, cs = cmds(b, "test")
    expected = compare_outputs(rd, "test") if rd else []
    for i, (exe, args, stdin, stdout_target) in enumerate(cs):
        # NOTE: "-o", args as two argv tokens breaks when a benchmark's own
        # options start with '-' (e.g. perlbench's "-I.", omnetpp's "-c
        # General"): argparse's default nargs heuristic sees the next token
        # looks like a flag and errors "expected one argument" before
        # simulation starts, identically on every build (not a TLB bug).
        # The "-o=value" form sidesteps that heuristic entirely.
        a = [SE, "--cpu-type", "AtomicSimpleCPU", "--mem-size", "8GiB", "-c", exe, "-o=" + args,
             "--output", f"spec_stdout_{i}.txt"]
        if stdin:
            a += ["--input", os.path.join(rd, stdin)]
        expected_outputs = command_outputs(expected, stdout_target, len(cs))
        for bd in ("inc", "base"):
            test_jobs.append({"name": f"spec-test-{b}-{i}", "build": bd, "args": a, "cwd": f"/var/tmp/sahilag24/spec_cwd/test-{b}-{i}-{bd}",
                              "env": ENV, "timeout": 8 * 3600, "desc": "SPEC test input, full run, 1 core",
                              "spec_rundir": rd, "stdout_target": stdout_target,
                              "expected_outputs": expected_outputs})

FF = ["-F", "1000000000", "--maxinsts", "200000000"]
first = {}
for b in rate:
    rd, cs = cmds(b, "refrate")
    if not cs:
        rd, cs = cmds(b, "ref")
    if not cs:
        continue
    exe, args, stdin, _stdout_target = cs[0]
    first[b] = (rd, exe, args, stdin)
    a = [SE, "--cpu-type", "TimingSimpleCPU", "--caches", "--l2cache", "--mem-size", "8GiB",
         "-c", exe, "-o=" + args, "--output", "spec_stdout.txt"] + FF
    if stdin:
        a += ["--input", os.path.join(rd, stdin)]
    for bd in ("inc", "base"):
        ref_jobs.append({"name": f"spec-ref-1c-{b}", "build": bd, "args": a, "cwd": f"/var/tmp/sahilag24/spec_cwd/ref1-{b}-{bd}", "spec_rundir": rd,
                         "env": ENV, "timeout": 8 * 3600, "desc": "SPEC ref, FF 1e9 + 2e8 timing, 1 core"})

# 4-core multiprogrammed mixes (no stdin-driven benchmarks in a mix; se.py has one --input)
mixable = [b for b in first if not first[b][3]]
for k in range(0, len(mixable) - 3, 4):
    mix = mixable[k:k + 4]
    a = [SE, "--cpu-type", "TimingSimpleCPU", "--caches", "--l2cache", "--mem-size", "16GiB", "-n", "4",
         "-c", ";".join(first[b][1] for b in mix), "-o=" + ";".join(first[b][2] for b in mix),
         "--output", "spec_stdout.txt"] + FF
    for bd in ("inc", "base"):
        ref_jobs.append({"name": "spec-ref-4c4p-" + "+".join(b.split(".")[1] for b in mix), "build": bd,
                         "args": a, "cwd": f"/var/tmp/sahilag24/spec_cwd/mix{k}-{bd}", "spec_rundir": first[mix[0]][0], "env": ENV, "timeout": 10 * 3600,
                         "desc": "4 cores, 4 SPEC ref processes"})

# OpenMP SPECspeed: 4 threads on 5 cores (multicore, multithreaded, one process)
for b in speed_omp:
    rd, cs = cmds(b, "refspeed")
    if not cs:
        continue
    exe, args, stdin, _stdout_target = cs[0]
    a = [SE, "--cpu-type", "TimingSimpleCPU", "--caches", "--l2cache", "--mem-size", "16GiB", "-n", "5",
         "-c", exe, "-o=" + args, "--output", "spec_stdout.txt",
         "--env", f"{W}/jobs/omp4.env"] + FF
    if stdin:
        a += ["--input", os.path.join(rd, stdin)]
    for bd in ("inc", "base"):
        ref_jobs.append({"name": f"spec-ref-omp4-{b}", "build": bd, "args": a, "cwd": f"/var/tmp/sahilag24/spec_cwd/omp-{b}-{bd}", "spec_rundir": rd, "env": ENV,
                         "timeout": 10 * 3600, "desc": "OpenMP SPECspeed, 4 threads, 5 cores"})

os.makedirs(f"{W}/jobs", exist_ok=True)
open(f"{W}/jobs/omp4.env", "w").write("OMP_NUM_THREADS=4\nOMP_STACKSIZE=120M\n")
json.dump(test_jobs, open(f"{W}/jobs/spec_test.json", "w"), indent=1)
json.dump(ref_jobs, open(f"{W}/jobs/spec_ref.json", "w"), indent=1)
print(f"benchmarks={len(benches)} test_jobs={len(test_jobs)} ref_jobs={len(ref_jobs)}")
