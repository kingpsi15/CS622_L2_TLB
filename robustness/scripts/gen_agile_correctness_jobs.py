#!/usr/bin/python3
"""Agile lane correctness matrix (tlbstress) -> $W/jobs/agile_correctness_matrix.json.
Separate from gen_agile_jobs.py (which only covers pf_patterns access-pattern perf).
This one targets the bugs the audit called out for the NaiveFP snapshot: stale L2
entries after demapPage/flushNonGlobal, and PCID/ASID separation across processes.
'inc' build = lane (naivefp / fixed, whichever is currently linked at $INC),
'base' build = NINE baseline (no prefetch, used as the differential reference)."""
import json, os
W = os.environ["W"]; INC = os.environ["INC"]
SE = f"{INC}/configs/deprecated/example/se.py"; T = f"{W}/tests/tlbstress"
ENV = {"TLBCHK_MAXWARN": "20"}
jobs = []

def job(name, cpu, cmds, n=1, extra=(), timeout=3600, desc=""):
    opts = ";".join(cmds)
    args = [SE, "--cpu-type", cpu, "-n", str(n), "--mem-size", "4GiB",
            "-c", ";".join([T] * len(cmds)), "-o", opts] + list(extra)
    if cpu != "AtomicSimpleCPU":
        args += ["--caches", "--l2cache"]
    for b in ("inc", "base"):
        jobs.append({"name": name, "build": b, "args": args, "env": ENV, "timeout": timeout,
                     "expect": {"results": len(cmds)}, "desc": desc})

for cpu, short in (("AtomicSimpleCPU", "atomic"), ("TimingSimpleCPU", "timing")):
    job(f"agile-remap-{short}", cpu, ["remap 30 96"],
        desc="munmap+MAP_FIXED remap same VA: stale L2 must not resurface in L1")
    job(f"agile-remap-big-{short}", cpu, ["remap 60 512"],
        desc="remap sized to span multiple 8-page prefetch windows")
    job(f"agile-shootdown-{short}", cpu, ["shootdown 4 10"], n=4, extra=["--caches", "--l2cache"] if cpu != "AtomicSimpleCPU" else [],
        desc="mprotect cross-thread shootdown: no stale writable translation (flushNonGlobal/L2)")
    job(f"agile-procs-{short}", cpu, ["procs 4 10"], n=5,
        desc="fork + same-VA multi-process: PCID-tagged L1/L2 must not cross-contaminate")
    job(f"agile-shared-{short}", cpu, ["shared 30"], n=3,
        desc="fork + MAP_SHARED: prefetch of a shared page must stay coherent")
    job(f"agile-huge-{short}", cpu, ["huge 4"],
        desc="THP split/remap while prefetcher is active on 4KiB neighbors")

os.makedirs(f"{W}/jobs", exist_ok=True)
json.dump(jobs, open(f"{W}/jobs/agile_correctness_matrix.json", "w"), indent=1)
print(len(jobs), "jobs")
