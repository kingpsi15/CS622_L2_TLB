#!/usr/bin/env python3
"""Collect every full-system result into CSV tables.

  python collect_results.py <fs_results dir> <out dir>

Input is the mirror written by sync_fs_results.sh (one sub-directory per lab
host, each holding /tmp/<user>/{runs,long,std,micro,ref,...}). Output:

  spec_fs_matrix.csv   lane, benchmark, verdict, source   (SPEC test inputs,
                       best verdict over the main and the long-tail runs)
  windows.csv          one row per timing window: host, kind, lane, design,
                       tag, thp, benchmark, why, insts, cycles, ipc, dtb
                       misses (= page walks), walks per kilo-inst, L2 hits,
                       CoLT hits, walker DRAM reads
  se_bigmem.csv        SE-mode 8 GiB results for the big speed benchmarks
  colt_se_verification.csv (copied as is)

"design" is the TLB that actually ran: for the colt binary with
COLT_ENABLE=0 (tags containing "nine") it is "nine(colt-bin)".
"""
import csv, os, re, sys, glob, shutil

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)


def first_block(stats):
    blk = {}
    started = False
    try:
        with open(stats, errors="replace") as f:
            for line in f:
                if "Begin Simulation Statistics" in line:
                    if started:
                        break
                    started = True
                    continue
                if "End Simulation Statistics" in line:
                    break
                p = line.split()
                if started and len(p) >= 2:
                    blk[p[0]] = p[1]
    except OSError:
        pass
    return blk


def num(blk, key):
    try:
        return float(blk.get(key, 0))
    except ValueError:
        return 0.0


def window_row(host, kind, lane, tag, bench, why, blk):
    insts = num(blk, "simInsts")
    m = num(blk, "board.processor.switch.core.mmu.dtb.rdMisses") + \
        num(blk, "board.processor.switch.core.mmu.dtb.wrMisses")
    tagl = tag.lower()
    design = lane
    if lane == "colt" and "nine" in tagl:
        design = "nine(colt-bin)"
    thp = "off" if "thpoff" in tagl else "on"
    return {
        "host": host, "kind": kind, "lane": lane, "design": design, "tag": tag,
        "thp": thp, "benchmark": bench, "why": why, "insts": int(insts),
        "cycles": int(num(blk, "board.processor.switch.core.numCycles")),
        "ipc": round(num(blk, "board.processor.switch.core.ipc"), 4),
        "dtb_misses": int(m),
        "walks_per_kinst": round(m * 1000 / insts, 3) if insts else "",
        "l2_hits": int(num(blk, "board.processor.switch.core.mmu.dtb.l2Hits")),
        "colt_hits": int(num(blk, "board.processor.switch.core.mmu.dtb.coltHits")),
        "walker_dram_reads": int(num(blk, "board.memory.mem_ctrl.requestorReadAccesses::processor.switch.core.mmu.dtb.walker")),
    }


windows, verdicts = [], {}
pri = {"PASS": 2, "FAIL": 1}
for simout in glob.glob(os.path.join(SRC, "*", "*", "*", "*", "*", "simout.txt")):
    parts = simout.replace(os.sep, "/").split("/")
    host, kind, rundir, sub = parts[-6], parts[-4], parts[-3], parts[-2]
    d = os.path.dirname(simout)
    m = re.match(r"(shard|std|micro)_([a-z]+)(?:_(.*))?_(\d{8}_\d{6})$", rundir)
    if not m:
        continue
    lane, tag = m.group(2), (m.group(3) or "default")
    if m.group(1) == "shard":
        tag = kind
        try:
            bench = open(os.path.join(d, "benches.txt")).read().split()[0]
        except (OSError, IndexError):
            continue
    else:
        bench = sub
    for line in open(simout, errors="replace"):
        w = re.match(r"TLBFS-WINDOW (\S+) dumped (\S+)", line)
        if w:
            windows.append(window_row(host, kind, lane, tag, bench, w.group(2),
                                      first_block(os.path.join(d, "stats.txt"))))
            break
    if kind in ("runs", "long"):
        dev = os.path.join(d, "board.pc.com_1.device")
        if os.path.exists(dev):
            for line in open(dev, errors="replace"):
                r = re.match(r"SPEC_RESULT (\S+) (PASS|FAIL)", line)
                if r:
                    b, v = r.groups()
                    key = (lane, b)
                    if pri[v] > pri.get(verdicts.get(key, ("", ""))[0], 0):
                        verdicts[key] = (v, kind)

with open(os.path.join(OUT, "windows.csv"), "w", newline="") as f:
    cols = list(windows[0].keys()) if windows else []
    w = csv.DictWriter(f, fieldnames=cols)
    w.writeheader()
    for r in sorted(windows, key=lambda r: (r["kind"], r["benchmark"], r["lane"], r["tag"], r["host"])):
        w.writerow(r)

with open(os.path.join(OUT, "spec_fs_matrix.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["lane", "benchmark", "verdict", "source"])
    for (lane, b), (v, src) in sorted(verdicts.items()):
        w.writerow([lane, b, v, src])

rows = []
for fn in glob.glob(os.path.join(SRC, "extra", "se_bigmem_*.txt")):
    for line in open(fn):
        p = line.split()
        if len(p) >= 4 and p[0] == "SE_RESULT":
            mm = re.search(r"dtb\.chkOracleMismatch=(\d+)", line)
            rows.append([p[1], p[2], p[3], mm.group(1) if mm else ""])
with open(os.path.join(OUT, "se_bigmem.csv"), "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["benchmark", "lane", "verdict", "oracle_mismatches"])
    w.writerows(sorted(rows))
src = os.path.join(SRC, "extra", "colt_se_verification.csv")
if os.path.exists(src):
    with open(src) as fi, open(os.path.join(OUT, "colt_se_verification.csv"), "w", newline="") as fo:
        fo.write("job,rc,result,oracle_mismatches,colt_hits,colt_inserts,l2_hits\n")
        fo.write(fi.read())
print(f"{len(windows)} windows, {len(verdicts)} SPEC verdicts, {len(rows)} SE big-mem results -> {OUT}")
