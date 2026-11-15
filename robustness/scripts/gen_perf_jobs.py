#!/usr/bin/python3
"""Perforated-Pages SE matrix -> $W/jobs/perf_matrix.json (build key 'inc' = this lane's tree)."""
import json, os
W = os.environ["W"]; INC = os.environ["INC"]
SE = f"{INC}/configs/deprecated/example/se.py"
H = f"{W}/tests/perf_holes"; T = f"{W}/tests/tlbstress"
ENV = {"TLBCHK_MAXWARN": "20"}
jobs = []
def job(name, cpu, procs, n=1, extra=(), desc=""):
    args = [SE, "--cpu-type", cpu, "-n", str(n), "--mem-size", "4GiB",
            "-c", ";".join(p[0] for p in procs), "-o", ";".join(p[1] for p in procs)] + list(extra)
    if cpu != "AtomicSimpleCPU": args += ["--caches", "--l2cache"]
    for b in ("inc", "base"):   # inc = this lane's perforated tree, base = stock TLB (+same oracle)
        jobs.append({"name": name, "build": b, "args": args, "env": ENV, "timeout": 7200,
                     "expect": {"results": len(procs)}, "desc": desc})
pats = ["dense", "edge", "clustered", "dispersed", "chunk1", "sparse", "churn"]
cpus = [("AtomicSimpleCPU", "atomic"), ("TimingSimpleCPU", "timing"), ("DerivO3CPU", "o3")]
for cpu, s in cpus:
    for p in pats:
        job(f"perf-1c-{s}-{p}", cpu, [(H, f"{p} 4 4")], desc="1 core/1 process, real holes")
    job(f"perf-1c-{s}-collide16", cpu, [(H, "edge 16 3")], desc="16 regions: set-collision/replacement of 2MiB entries")
    job(f"perf-1c-{s}-collide48", cpu, [(H, "churn 48 2")], desc="48 regions + churn")
    for t in ("capacity 513 3", "conflict 80 6", "remap 10 96"):
        job(f"perf-1c-{s}-tlbstress-{t.split()[0]}", cpu, [(T, t)], desc="generic 4K stress on perforated TLB")
    job(f"perf-4c4p-{s}-holes", cpu, [(H, "edge 4 4"), (H, "clustered 4 4"), (H, "dispersed 4 4"), (H, "churn 4 4")], n=4,
        desc="4 cores, 4 processes, SAME VA layout, different hole patterns")
    job(f"perf-8c8p-{s}-mixed", cpu, [(H, "edge 4 3"), (H, "sparse 4 3"), (H, "chunk1 4 3"), (H, "churn 4 3"),
        (T, "capacity 513 3"), (T, "conflict 80 4"), (H, "dense 4 3"), (H, "clustered 4 3")], n=8, desc="8 processes")
job("perf-smt2-o3", "DerivO3CPU", [(H, "edge 4 4"), (H, "clustered 4 4")], n=1, extra=["--smt"], desc="SMT: 2 processes share TLB, same VAs")
job("perf-smt4-o3", "DerivO3CPU", [(H, "edge 4 3"), (H, "dispersed 4 3"), (H, "churn 4 3"), (H, "sparse 4 3")], n=1, extra=["--smt"], desc="SMT4")
os.makedirs(f"{W}/jobs", exist_ok=True)
json.dump(jobs, open(f"{W}/jobs/perf_matrix.json", "w"), indent=1)
print(len(jobs), "jobs")
