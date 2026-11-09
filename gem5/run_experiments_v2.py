#!/usr/bin/env python3
"""Full mid-review experiment sweep (v2).

6 TLB configurations x 5 workloads, every run kept in its own m5out dir.
All configurations are restored from the backup files in src/arch/x86/;
the originally active tlb.cc / tlb.hh are backed up first and restored at the end.
"""
import os, re, json, csv, shutil, subprocess, time

GEM5 = os.path.expanduser("~/gem5")
X86 = os.path.join(GEM5, "src/arch/x86")
OUT = os.path.join(GEM5, "results_v2")
os.chdir(GEM5)
os.makedirs(OUT, exist_ok=True)

# Ordered so that tlb.hh changes as rarely as possible (header change => big rebuild)
CONFIGS = [
    ("FA-NINE",      "tlb.cc.nine",         "tlb.hh.nine"),
    ("SA-Exclusive", "tlb.cc.exclusive.sa", "tlb.hh.exclusive.sa"),
    ("SA-NINE",      "tlb.cc.nine.sa",      "tlb.hh.nine.sa"),
    ("SA-Inclusive", "tlb.cc.inclusive.sa", "tlb.hh.inclusive.sa"),
    ("SA-NINE+SP",   "tlb.cc.sp",           "tlb.hh.nine.sa"),
    ("SA-NINE+NaiveFP", "tlb.cc.naivefp",   "tlb.hh.nine.sa"),
]

WORKLOADS = [
    ("seq_fit",   "tlb_test3",    "200 pages x4 passes (fits in L2)"),
    ("overflow",  "tlb_test5",    "600 pages + hot page (exceeds L2)"),
    ("spread80",  "tlb_spread",   "80 pages, distinct L2 sets, x10"),
    ("conflict80","tlb_conflict", "80 pages, SAME L2 set, x10"),
    ("random1k",  "tlb_random",   "20k random accesses over 1024 pages"),
]

STAT_KEYS = ["rdAccesses", "wrAccesses", "rdMisses", "wrMisses"]

def parse(stats_file):
    vals = {}
    with open(stats_file) as f:
        for line in f:
            for k in STAT_KEYS:
                if line.startswith(f"system.cpu.mmu.dtb.{k} "):
                    vals[k] = int(line.split()[1])
            if line.startswith("simInsts "):
                vals["simInsts"] = int(line.split()[1])
    vals["dtbAccesses"] = vals.get("rdAccesses", 0) + vals.get("wrAccesses", 0)
    vals["dtbWalks"] = vals.get("rdMisses", 0) + vals.get("wrMisses", 0)
    return vals

# Back up whatever is active right now (never lose work)
stamp = time.strftime("%Y%m%d_%H%M%S")
shutil.copy(os.path.join(X86, "tlb.cc"), os.path.join(X86, f"tlb.cc.pre_v2_{stamp}"))
shutil.copy(os.path.join(X86, "tlb.hh"), os.path.join(X86, f"tlb.hh.pre_v2_{stamp}"))

results = {}
log = open(os.path.join(OUT, "sweep_log.txt"), "a")
def say(msg):
    print(msg, flush=True); log.write(msg + "\n"); log.flush()

try:
    for name, cc, hh in CONFIGS:
        say(f"\n=== {name}: {cc} + {hh} ===")
        shutil.copy(os.path.join(X86, cc), os.path.join(X86, "tlb.cc"))
        if open(os.path.join(X86, hh)).read() != open(os.path.join(X86, "tlb.hh")).read():
            shutil.copy(os.path.join(X86, hh), os.path.join(X86, "tlb.hh"))
        t0 = time.time()
        r = subprocess.run(["scons", "build/X86/gem5.opt", "-j", "2", "--linker=gold", "--ignore-style"],
                           stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        say(f"  build rc={r.returncode} in {time.time()-t0:.0f}s")
        if r.returncode != 0:
            say(r.stdout[-3000:])
            # one retry with -j1 (linker OOM is the usual culprit)
            r = subprocess.run(["scons", "build/X86/gem5.opt", "-j", "1", "--linker=gold", "--ignore-style"],
                               stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            say(f"  retry rc={r.returncode}")
            if r.returncode != 0:
                say(r.stdout[-3000:]); continue
        results[name] = {}
        for wl, binary, desc in WORKLOADS:
            d = os.path.join(OUT, f"{name}__{wl}")
            subprocess.run(["build/X86/gem5.opt", "-d", d, "configs/deprecated/example/se.py",
                            "-c", binary], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            v = parse(os.path.join(d, "stats.txt"))
            results[name][wl] = v
            say(f"  {wl:<11} walks={v['dtbWalks']:>6}  accesses={v['dtbAccesses']:>7}  insts={v.get('simInsts')}")
        json.dump(results, open(os.path.join(OUT, "results.json"), "w"), indent=2)
finally:
    # Always restore the originally-active Hybrid version
    say("\nRestoring original active tlb.cc and tlb.hh...")
    shutil.copy(os.path.join(X86, f"tlb.cc.pre_v2_{stamp}"), os.path.join(X86, "tlb.cc"))
    shutil.copy(os.path.join(X86, f"tlb.hh.pre_v2_{stamp}"), os.path.join(X86, "tlb.hh"))
    # Rebuild original active Hybrid binary
    subprocess.run(["scons", "build/X86/gem5.opt", "-j", "2", "--linker=gold", "--ignore-style"],
                   stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    say("Original active build restored.")

with open(os.path.join(OUT, "results.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["config", "workload", "dtb_walks(L1+L2 miss)", "dtb_accesses", "simInsts"])
    for name in results:
        for wl in results[name]:
            v = results[name][wl]
            w.writerow([name, wl, v["dtbWalks"], v["dtbAccesses"], v.get("simInsts")])

say("\n================ FINAL TABLE: DTB page walks (missed L1 AND L2) ================")
say("config".ljust(18) + "".join(wl.rjust(12) for wl, _, _ in WORKLOADS))
for name in results:
    say(name.ljust(18) + "".join(str(results[name].get(wl, {}).get("dtbWalks", "-")).rjust(12)
                                for wl, _, _ in WORKLOADS))
say("DONE")
