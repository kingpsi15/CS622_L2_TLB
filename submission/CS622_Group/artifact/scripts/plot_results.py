#!/usr/bin/env python3
"""Plot the full-system results and print the numbers behind every plot.

  python plot_results.py <results dir from collect_results.py> <figure dir>

Rules used for every comparison (see the report, Section "Methodology notes"):
  * metric = page walks per 1000 instructions in the timing window
    (data-TLB misses counted after the L1, CoLT buffer and L2 all miss);
  * huge pages OFF: compared across hosts (stable to within a few percent);
  * huge pages ON: compared only between runs on the SAME host.
Writes PNG figures plus numbers.txt with the exact values plotted.
"""
import os, sys
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

RES, FIG = sys.argv[1], sys.argv[2]
os.makedirs(FIG, exist_ok=True)
w = pd.read_csv(os.path.join(RES, "windows.csv"))
m = pd.read_csv(os.path.join(RES, "spec_fs_matrix.csv"))
out = open(os.path.join(FIG, "numbers.txt"), "w")
plt.rcParams.update({"font.size": 9, "figure.dpi": 150})
COL = {"inc": "#4C72B0", "excl": "#55A868", "nine": "#8172B2", "agile": "#C44E52",
       "colt": "#DD8452", "perf": "#937860", "perfstrict": "#8C8C8C"}
LABEL = {"inc": "Inclusive", "excl": "Exclusive", "nine": "NINE", "agile": "Agile",
         "colt": "CoLT-FA", "perf": "Perforated (as built)", "perfstrict": "Perforated (strict)"}
WL = {"gapbs_bfs_kron20": "bfs", "gapbs_cc_urand20": "cc", "gapbs_pr_kron20": "pr",
      "gapbs_bc_kron20": "bc", "gapbs_sssp_kron20": "sssp", "gapbs_tc_kron20": "tc",
      "xsbench_small_event": "XSBench", "memcached_randget": "memcached",
      "stream_20M": "STREAM"}


def p(*a):
    print(*a, file=out)


def val(df):
    return float(df["walks_per_kinst"].iloc[0]) if len(df) else None


# ---------- 1. SPEC full-system outcome per design ----------
lanes = ["inc", "excl", "nine", "agile", "perf", "colt"]
cats = {"PASS": [], "FAIL: gem5 x87 bug (perlbench)": [],
        "FAIL: needs > 3 GB (deepsjeng_s)": [], "No FS result": []}
p("== SPEC CPU2017 test inputs, full system (43 benchmarks)")
for L in lanes:
    sub = m[m.lane == L]
    npass = int((sub.verdict == "PASS").sum())
    fx87 = int(((sub.verdict == "FAIL") & sub.benchmark.str.contains("perlbench")).sum())
    fmem = int(((sub.verdict == "FAIL") & sub.benchmark.str.contains("deepsjeng_s")).sum())
    other = int(((sub.verdict == "FAIL") & ~sub.benchmark.str.contains("perlbench|deepsjeng_s")).sum())
    none = 43 - npass - fx87 - fmem - other
    cats["PASS"].append(npass); cats["FAIL: gem5 x87 bug (perlbench)"].append(fx87)
    cats["FAIL: needs > 3 GB (deepsjeng_s)"].append(fmem); cats["No FS result"].append(none)
    p(f"{L:6} PASS={npass} FAILx87={fx87} FAILmem={fmem} FAILother={other} none={none}")
fig, ax = plt.subplots(figsize=(7.6, 2.8))
bottom = [0] * len(lanes)
colors = ["#55A868", "#C44E52", "#DD8452", "#BBBBBB"]
for (k, v), c in zip(cats.items(), colors):
    ax.bar([LABEL[l] for l in lanes], v, bottom=bottom, label=k, color=c)
    bottom = [b + x for b, x in zip(bottom, v)]
ax.set_ylabel("Benchmarks (of 43)"); ax.set_ylim(0, 45)
ax.legend(fontsize=7, loc="upper left", bbox_to_anchor=(1.01, 1.0)); ax.set_title("SPEC CPU2017 (test inputs) in gem5 full-system mode")
plt.xticks(rotation=15); plt.tight_layout(); plt.savefig(os.path.join(FIG, "spec_fs_outcome.png")); plt.close()

# pie of outcomes over all designs
tot = {k: sum(v) for k, v in cats.items()}
fig, ax = plt.subplots(figsize=(3.6, 3.0))
ax.pie(list(tot.values()), labels=[f"{k}\n({v})" for k, v in tot.items()], colors=colors,
       textprops={"fontsize": 7}, startangle=90)
ax.set_title("All 6 designs x 43 benchmarks", fontsize=8)
plt.tight_layout(); plt.savefig(os.path.join(FIG, "spec_fs_pie.png")); plt.close()
p("pie totals", tot)

# ---------- 2. TLB pressure of SPEC test inputs ----------
t = w[(w.kind == "runs") & (w.lane == "inc")].sort_values("walks_per_kinst", ascending=False)
p("\n== SPEC test-input page walks per kilo-inst (Inclusive, 200M window)")
for _, r in t.iterrows():
    p(f"{r.benchmark:18} {r.walks_per_kinst}")
fig, ax = plt.subplots(figsize=(6.4, 2.6))
ax.bar([b.split(".")[1] for b in t.benchmark], t.walks_per_kinst, color="#4C72B0")
ax.set_ylabel("Page walks / 1000 instr"); ax.set_title("TLB pressure of SPEC CPU2017 test inputs (Inclusive design)")
plt.xticks(rotation=90, fontsize=6); plt.tight_layout(); plt.savefig(os.path.join(FIG, "spec_test_pressure.png")); plt.close()

# ---------- 3. Huge pages OFF: all designs on the TLB-intensive workloads ----------
off = w[(w.kind == "std") & (w.thp == "off")]


def pick_off(design, bench):
    if design == "nine":
        d = off[(off.design == "nine(colt-bin)") & (off.benchmark == bench)]
    elif design == "colt":
        d = off[(off.lane == "colt") & (off.design == "colt") & (off.benchmark == bench) &
                (off.tag.str.contains("colt8"))]
    else:
        d = off[(off.lane == design) & (off.benchmark == bench)]
    return val(d)


order = ["gapbs_bfs_kron20", "gapbs_cc_urand20", "gapbs_sssp_kron20", "gapbs_bc_kron20",
         "gapbs_pr_kron20", "gapbs_tc_kron20", "xsbench_small_event", "memcached_randget", "stream_20M"]
designs = ["inc", "excl", "nine", "agile", "colt", "perf", "perfstrict"]
p("\n== Huge pages OFF, page walks per kilo-inst")
p("workload " + " ".join(f"{d:>11}" for d in designs))
tab = {}
for b in order:
    row = [pick_off(d, b) for d in designs]
    tab[b] = row
    p(f"{WL[b]:9} " + " ".join(f"{(x if x is not None else float('nan')):11.3f}" for x in row))
fig, ax = plt.subplots(figsize=(7.0, 3.6))
width = 0.12
for i, d in enumerate(designs):
    ys = [tab[b][i] if tab[b][i] is not None else 0 for b in order]
    ax.bar([j + (i - 3) * width for j in range(len(order))], ys, width, label=LABEL[d], color=COL[d])
ax.set_xticks(range(len(order))); ax.set_xticklabels([WL[b] for b in order], rotation=20)
ax.set_yscale("log"); ax.set_ylabel("Page walks / 1000 instr (log)")
ax.set_title("TLB-intensive workloads, transparent huge pages OFF")
ax.legend(fontsize=6, ncol=4, loc="upper center", bbox_to_anchor=(0.5, -0.22)); ax.set_ylim(0.08, 300); plt.tight_layout(); plt.savefig(os.path.join(FIG, "thp_off_all_designs.png")); plt.close()

# ---------- 4. CoLT vs NINE reduction (huge pages OFF) ----------
p("\n== CoLT-FA (8 entries) vs NINE, huge pages OFF: change in page walks")
red = []
for b in order:
    n, c = tab[b][designs.index("nine")], tab[b][designs.index("colt")]
    if n and c is not None:
        red.append((WL[b], (c - n) / n * 100, n, c))
        p(f"{WL[b]:9} NINE {n:8.3f}  CoLT {c:8.3f}  change {(c - n) / n * 100:6.1f}%")
fig, ax = plt.subplots(figsize=(6.0, 2.6))
ax.bar([r[0] for r in red], [r[1] for r in red], color=["#DD8452" if r[1] < 0 else "#999999" for r in red])
ax.axhline(0, color="black", lw=0.6); ax.set_ylabel("Change vs NINE (%)")
ax.set_title("CoLT-FA vs NINE page walks, huge pages OFF (negative = fewer walks)")
for i, r in enumerate(red):
    ax.text(i, r[1] - 4 if r[1] < 0 else r[1] + 1, f"{r[1]:.0f}%", ha="center", fontsize=7)
plt.tight_layout(); plt.savefig(os.path.join(FIG, "colt_vs_nine_thpoff.png")); plt.close()

# ---------- 5. CoLT buffer size 8 vs 32 (huge pages OFF) ----------
p("\n== CoLT buffer size, huge pages OFF (walks/kinst): NINE, CoLT-8, CoLT-32")
sz = []
for b in order:
    c32 = val(off[(off.tag == "colt32_thpoff") & (off.benchmark == b)])
    n, c8 = tab[b][designs.index("nine")], tab[b][designs.index("colt")]
    if c32 is not None and n is not None:
        sz.append((WL[b], n, c8, c32)); p(f"{WL[b]:9} {n:8.3f} {c8:8.3f} {c32:8.3f}")
if sz:
    fig, ax = plt.subplots(figsize=(6.0, 2.6))
    for i, (lab, col) in enumerate([("NINE", "#8172B2"), ("CoLT-FA 8 entries", "#DD8452"), ("CoLT-FA 32 entries", "#A65628")]):
        ax.bar([j + (i - 1) * 0.27 for j in range(len(sz))], [s[i + 1] for s in sz], 0.27, label=lab, color=col)
    ax.set_xticks(range(len(sz))); ax.set_xticklabels([s[0] for s in sz]); ax.set_yscale("log")
    ax.set_ylabel("Page walks / 1000 instr (log)"); ax.legend(fontsize=7)
    ax.set_title("CoLT-FA buffer size, huge pages OFF")
    plt.tight_layout(); plt.savefig(os.path.join(FIG, "colt_size.png")); plt.close()

# ---------- 6. Huge pages ON, same-host pairs only ----------
on = w[(w.kind == "std") & (w.thp == "on")]
p("\n== Huge pages ON, same-host CoLT vs NINE pairs (walks/kinst)")
pairs = []
for host in sorted(on.host.unique()):
    h = on[on.host == host]
    for b in order:
        n = val(h[(h.design == "nine(colt-bin)") & (h.benchmark == b)])
        c = val(h[(h.design == "colt") & (h.benchmark == b) & (h.tag.str.contains("colt8"))])
        if n is not None and c is not None:
            pairs.append((host, WL[b], n, c))
            p(f"{host} {WL[b]:9} NINE {n:8.3f}  CoLT-8 {c:8.3f}  change {(c - n) / n * 100:6.1f}%")
if pairs:
    fig, ax = plt.subplots(figsize=(6.0, 2.6))
    labs = [f"{x[1]}\n({x[0]})" for x in pairs]
    ax.bar([i - 0.2 for i in range(len(pairs))], [x[2] for x in pairs], 0.4, label="NINE", color="#8172B2")
    ax.bar([i + 0.2 for i in range(len(pairs))], [x[3] for x in pairs], 0.4, label="CoLT-FA 8", color="#DD8452")
    ax.set_xticks(range(len(pairs))); ax.set_xticklabels(labs, fontsize=7)
    ax.set_ylabel("Page walks / 1000 instr"); ax.legend(fontsize=7)
    ax.set_title("Huge pages ON, CoLT-FA vs NINE on the same machine")
    plt.tight_layout(); plt.savefig(os.path.join(FIG, "colt_vs_nine_thpon_samehost.png")); plt.close()

# ---------- 7. Huge pages ON vs OFF for NINE ----------
p("\n== Effect of transparent huge pages on NINE (same binary, host csews36)")
h = w[(w.kind == "std") & (w.host == "csews36") & (w.design == "nine(colt-bin)")]
hp = []
for b in order:
    a = val(h[(h.thp == "on") & (h.benchmark == b)]); o = val(h[(h.thp == "off") & (h.benchmark == b)])
    if a is not None and o is not None:
        hp.append((WL[b], o, a)); p(f"{WL[b]:9} THP off {o:8.3f}  THP on {a:8.3f}")
if hp:
    fig, ax = plt.subplots(figsize=(6.0, 2.6))
    ax.bar([i - 0.2 for i in range(len(hp))], [x[1] for x in hp], 0.4, label="huge pages OFF", color="#4C72B0")
    ax.bar([i + 0.2 for i in range(len(hp))], [x[2] for x in hp], 0.4, label="huge pages ON", color="#55A868")
    ax.set_xticks(range(len(hp))); ax.set_xticklabels([x[0] for x in hp]); ax.set_yscale("log")
    ax.set_ylabel("Page walks / 1000 instr (log)"); ax.legend(fontsize=7)
    ax.set_title("NINE with and without transparent huge pages")
    plt.tight_layout(); plt.savefig(os.path.join(FIG, "thp_effect_nine.png")); plt.close()

# ---------- 8. SPEC reference inputs (huge pages ON, one host per design) ----------
r = w[w.kind == "ref"]
p("\n== SPEC reference inputs (walks/kinst, huge pages ON; each design on its own host)")
refb = sorted(r.benchmark.unique())
for b in refb:
    row = []
    for d in ["inc", "excl", "nine", "agile", "perf", "perfstrict", "colt"]:
        x = r[(r.lane == d) & (r.benchmark == b)]
        row.append(f"{d}={x.walks_per_kinst.iloc[0]}@{x.host.iloc[0]}" if len(x) else f"{d}=-")
    p(f"{b:18} " + " ".join(row))
out.close()
print(open(os.path.join(FIG, "numbers.txt")).read())
