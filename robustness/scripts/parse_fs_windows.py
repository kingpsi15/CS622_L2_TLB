#!/usr/bin/env python3
"""Collect per-benchmark timing-window stats from windowed FS shard runs.

  parse_fs_windows.py <shard_run_dir> [<shard_run_dir> ...] > windows.tsv

Each shard dir s<i>/ has simout.txt ("TLBFS-WINDOW <bench> dumped <why>"
lines, in order) and stats.txt (one "Begin Simulation Statistics" block per
m5.stats.dump(); the window dumps come first, the end-of-run dump last).
Output: one row per benchmark window with cycles, IPC and every TLB/MMU/
page-walk/cache-miss stat of the detailed (switch) core, as JSON in the last
column so lanes with different TLB stat names can all be compared.
"""
import json, os, re, sys

KEEP = re.compile(r"(tlb|mmu|walker|Walk|l2Hit|l2Ins|l2Evic|chk|prefetch|"
                  r"numCycles|committedInsts|ipc|cpi|overallMisses|overallHits|simInsts|simTicks)",
                  re.I)


def blocks(stats_path):
    cur = None
    with open(stats_path, errors="replace") as f:
        for line in f:
            if "Begin Simulation Statistics" in line:
                cur = {}
            elif "End Simulation Statistics" in line:
                if cur is not None:
                    yield cur
                cur = None
            elif cur is not None:
                p = line.split()
                if len(p) >= 2 and KEEP.search(p[0]):
                    try:
                        cur[p[0]] = float(p[1])
                    except ValueError:
                        pass


def main():
    print("lane\tshard\tbenchmark\twhy\tinsts\tcycles\tipc\tstats_json")
    for run in sys.argv[1:]:
        lane = re.search(r"shard_([a-z]+)_", os.path.basename(run.rstrip("/")))
        lane = lane.group(1) if lane else "?"
        for s in sorted(os.listdir(run)):
            d = os.path.join(run, s)
            simout = os.path.join(d, "simout.txt")
            stats = os.path.join(d, "stats.txt")
            if not (os.path.isfile(simout) and os.path.isfile(stats)):
                continue
            wins = [l.split()[1:4] for l in open(simout, errors="replace")
                    if l.startswith("TLBFS-WINDOW") and " dumped " in l]
            for (bench, _, why), blk in zip(wins, blocks(stats)):
                sw = {k: v for k, v in blk.items() if ".switch" in k or k.startswith("sim")}
                insts = blk.get("simInsts") or next((v for k, v in sw.items() if k.endswith("committedInsts")), 0)
                cyc = next((v for k, v in sw.items() if k.endswith("numCycles")), 0)
                ipc = insts / cyc if cyc else 0
                print(f"{lane}\t{s}\t{bench}\t{why}\t{int(insts)}\t{int(cyc)}\t{ipc:.4f}\t"
                      + json.dumps(blk, sort_keys=True))


if __name__ == "__main__":
    main()
