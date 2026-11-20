#!/bin/bash
bash ~/status_all.sh | sort > ~/cluster_status.txt
python3 - <<'PY'
import re
rows = [l.strip() for l in open("/users/btech/sahilag24/cluster_status.txt") if l.strip()]
lanes = ["inc", "excl", "nine", "agile", "perf"]
targets = ["500", "600", "619", "525", "527", "625", "627"]
def lane_of(p):
    for l in lanes:
        if f"-{l}/" in p or f"-{l}-" in p: return l
    return "?"
print(f"{'BENCH':<6} | " + " | ".join(f"{l:^15}" for l in lanes))
print("-" * 92)
for b in targets:
    cells = []
    for l in lanes:
        done = run = fail = 0
        for r in rows:
            if lane_of(r) != l: continue
            mb = re.search(r"\[([0-9,]+)\]", r)
            if not mb or b not in mb.group(1).split(","): continue
            ex = re.search(r"ex=\[(.*?)\]", r).group(1)
            res = int(re.search(r"res=(\d+)", r).group(1))
            if ex == "exited 0" and res >= 1: done += 1
            elif ex == "": run += 1
            else: fail += 1
        tag = f"PASS({done}) run={run}" if done else f"run={run}"
        if fail: tag += f" f={fail}"
        cells.append(tag)
    print(f"{b:<6} | " + " | ".join(f"{c:^15}" for c in cells))
PY
