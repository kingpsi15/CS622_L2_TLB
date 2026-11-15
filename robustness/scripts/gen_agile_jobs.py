#!/usr/bin/python3
"""Agile prefetch matrix -> $W/jobs/agile_matrix.json.  build 'inc' = lane (naivefp), 'base' = NINE baseline (no prefetch)."""
import json, os
W = os.environ["W"]; INC = os.environ["INC"]
SE = f"{INC}/configs/deprecated/example/se.py"; P = f"{W}/tests/pf_patterns"
jobs = []
for cpu, s in (("TimingSimpleCPU", "timing"), ("DerivO3CPU", "o3")):
    for pat in ("asc", "desc", "s2", "s4", "s8", "s16", "random", "chase", "hotcold"):
        for pages in (512, 2048, 8192):
            args = [SE, "--cpu-type", cpu, "-n", "1", "--mem-size", "4GiB", "--caches", "--l2cache", "-c", P, "-o", f"{pat} {pages} 4"]
            for b in ("inc", "base"):
                jobs.append({"name": f"pf-{s}-{pat}-{pages}", "build": b, "args": args, "env": {"TLBCHK_MAXWARN": "20"},
                             "timeout": 7200, "expect": {"results": 1}, "desc": "prefetch pattern"})
os.makedirs(f"{W}/jobs", exist_ok=True)
json.dump(jobs, open(f"{W}/jobs/agile_matrix.json", "w"), indent=1); print(len(jobs), "jobs")
