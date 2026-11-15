#!/usr/bin/python3
"""Generate the SE-mode robustness job matrix -> $W/jobs/se_matrix.json

Topologies (each on both builds: inc = Mid-Review SA-Inclusive, base = stock gem5):
  1c1p1t  : one core, one process, one thread  (Atomic, Timing, O3 = speculative wrong-path translations)
  Nc1pMt  : multicore, one process, pthreads   (Timing, O3)
  Nc Np   : multicore multiprogrammed, different tests per core (Timing, O3)
  SMT     : one O3 core, 2 and 4 hardware threads running different processes (shared TLB)
  fork    : fork/COW + MAP_SHARED inside SE (gem5 SE clone support)
"""
import json, os
W = os.environ["W"]
INC = os.environ["INC"]
T = f"{W}/tests/tlbstress"
SE = f"{INC}/configs/deprecated/example/se.py"
ENV = {"TLBCHK_MAXWARN": "20"}
jobs = []

def job(name, cpu, cmds, n=1, extra=(), timeout=3 * 3600, desc=""):
    opts = ";".join(c for c in cmds)
    args = [SE, "--cpu-type", cpu, "-n", str(n), "--mem-size", "4GiB",
            "-c", ";".join([T] * len(cmds)), "-o", opts] + list(extra)
    if cpu != "AtomicSimpleCPU":
        args += ["--caches", "--l2cache"]
    for b in ("inc", "base"):
        jobs.append({"name": name, "build": b, "args": args, "env": ENV, "timeout": timeout,
                     "expect": {"results": len(cmds)}, "desc": desc})

single = ["capacity 63 4", "capacity 64 4", "capacity 65 4", "capacity 511 4", "capacity 512 4",
          "capacity 513 4", "capacity 2048 2", "conflict 80 10", "conflict 200 4", "remap 20 96",
          "protect 3", "huge 2", "interrupts 4 200"]
for cpu, short in (("AtomicSimpleCPU", "atomic"), ("TimingSimpleCPU", "timing"), ("DerivO3CPU", "o3")):
    for s in single:
        job(f"se-1c1p1t-{short}-{s.replace(' ', '_')}", cpu, [s],
            desc="single core / single process / single thread")
    # multithreaded on multicore: N worker threads + main thread need N+1 contexts
    for nt in (3, 7):
        job(f"se-{nt+1}c1p{nt}t-{short}-threads", cpu, [f"threads {nt} 300 3"], n=nt + 1,
            desc="multicore, one process, pthreads (clone) - shared address space, private TLBs")
    # multiprogrammed multicore
    mp = ["capacity 513 3", "conflict 80 6", "remap 10 96", "capacity 2048 1",
          "threads 1 200 2", "capacity 700 3", "conflict 200 3", "capacity 65 6"]
    job(f"se-4c4p-{short}-multiprog", cpu, mp[:4], n=4, desc="4 cores, 4 different processes")
    job(f"se-8c8p-{short}-multiprog", cpu, mp, n=8, desc="8 cores, 8 different processes")
    job(f"se-2c-{short}-fork-procs", cpu, ["procs 3 5"], n=5, desc="fork + COW + same-VA processes")
    job(f"se-2c-{short}-fork-shared", cpu, ["shared 10"], n=3, desc="fork + MAP_SHARED")

# SMT: several processes on ONE O3 core -> they share one MMU/TLB
job("se-smt2-o3-same-test", "DerivO3CPU", ["capacity 513 3", "capacity 513 3"], n=1, extra=["--smt"],
    desc="SMT, 2 processes with identical VA layout share one TLB")
job("se-smt2-o3-mixed", "DerivO3CPU", ["conflict 80 6", "capacity 700 3"], n=1, extra=["--smt"],
    desc="SMT, conflict storm + capacity in the other thread")
job("se-smt4-o3-mixed", "DerivO3CPU", ["capacity 513 2", "conflict 80 4", "remap 10 64", "capacity 300 3"],
    n=1, extra=["--smt"], desc="SMT, 4 hardware threads / 4 processes on one core")

os.makedirs(f"{W}/jobs", exist_ok=True)
json.dump(jobs, open(f"{W}/jobs/se_matrix.json", "w"), indent=1)
print(len(jobs), "jobs")
