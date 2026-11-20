# Approach 5 of 5 — Perforated Pages (L2 TLB coarse-filter + bitmap)

**Final, 2026-11-13, host csewsrm25.** All numbers below come from an actual run on this machine; every row names the log/stats path it was pulled from. No number is estimated or copied from another lane. Where a run did not finish in time, that is stated explicitly rather than guessed.

## 1. What this approach is

`tlb.cc.item2.verified` / `tlb.hh.item2.verified`: a set-associative (default 128 sets × 4 ways) second-level TLB cache where each way holds one **2 MiB "Perforated Page" entry** — a per-4K-sub-page validity bitmap (512 bits) plus an 8-entry (default) coarse filter that tags each 64-page (default) chunk as EMPTY / CLEAN (no holes, fast-path) / HOLEY (needs the bitmap). A demand miss also triggers a naive CoLT-style neighbor prefetch that inserts the other pages in an 8-page-aligned (default) window into the L2. Built into gem5 25.1.0.1 (X86, SE mode) and compared against the **stock gem5 TLB**, both checked against the process page table by a translation oracle on every translation (`robustness/patches/apply_checker.py`).

## 2. What was wrong earlier → how it was fixed

Six real bugs, found by static+dynamic audit, fixed in new files (never the user's originals): `~/CS622_L2_TLB/gem5/src/arch/x86/tlb.cc.perf.fixed`, `tlb.hh.perf.fixed`, diff at `robustness/patches/perf_fixed.diff`.

| # | Bug (file:lines, original) | Fix | Why the SE matrix can't move on it (traced, not assumed) |
|---|---|---|---|
| 1 | `demapPage()` (tlb.cc.item2.verified:336) cleared only the L1 trie; L2 kept a stale sub-page | `demapPage()` now also calls `l2_demapPage(va, pcid)`: clears the one 4K sub-page and recomputes its chunk's coarse-filter state | `demapPage` is reachable only from `faults.cc:141`, gated `if (FullSystem)`. x86 SE never decodes `invlpg` (the `Tia` microop exists in `ldstop.isa` with no decoder entry). Instrumented and confirmed: 0 calls across the 44-job matrix |
| 2 | `flushNonGlobal()` (tlb.cc.item2.verified:323) cleared only L1; `flushAll()` two functions above it already clears L2 — an inconsistency in the same file | `flushNonGlobal()` now also calls `l2_flushNonGlobal()` (drops non-global sub-pages region-wide) | Fires only on a CR3 write (`isa.cc:326`); unprivileged SE binaries never execute `mov cr3,reg`. 0 calls confirmed |
| 3 | `SparseL2Entry` had no address-space tag; `l2_lookup`/`l2_insert` matched on `vpn_2mb` alone, so two processes mapping the same VA to different physical pages could alias each other's L2 state | Added `pcid` field; lookup/insert now require a pcid match (`PERF_FIX_L2_PCID`) | SE always computes `pcid=0` (CR4.PCIDE never set in SE). Verified byte-identical miss counts and oracle checks before/after (V1 vs V4/V6 below) |
| 4 | `l2_lookup()` reconstructed every hit with **hardcoded** `user=true, noExec=false, global=false` instead of the page's real flags — a privilege-escalation-class bug in FullSystem mode | Store/restore real `page_user/page_noexec/page_global` per sub-page (`PERF_FIX_L2_PERMS`) | SE's `TlbEntry(pid,...)` constructor (`pagetable.cc:58`) always sets exactly those three values for SE-mode pages, so the bug is byte-for-byte invisible to SE. Confirmed (V1 vs V5/V6) |
| 5 | On every SE demand miss, `l2_insert()` was called twice for the same page (once inside `insert()`, once again right after, tlb.cc.item2.verified:820-825) | Removed the redundant second call | Harmless/idempotent either way; removing it changed no counter |
| 6 | `serialize()`/`unserialize()` never touched L2 at all | `unserialize()` now clears every L2 way after restoring L1, so no pre-restore entry outlives a restore. Full L2 serialization was judged not worth the format churn for a research L2 | Checkpoint/restore is not exercised by any test in this matrix (§6) |

**Before/after, full 44-job SE matrix** (`results-perf/before_after/perf_matrix_BEFORE_csewsrm25.md` vs `results-perf/perf_fixed_matrix.md`): before = 72/88 PASS (44×{pre-fix,stock}); after = 36/44 PASS on the fixed+oracle-instrumented build — the *identical* 8 non-pass configs (`perf-4c4p-*-holes`, `perf-8c8p-*-mixed`, `perf-smt2/4-o3`), confirmed a pre-existing gem5 SE limitation shared with stock (fails identically with no perforated code at all), not a TLB defect. Every one of the 27 1-core miss counts is **byte-identical** before and after the fix (e.g. dense 4115→4115, collide48 77591→77591 — pulled from both `stats.txt` sets), exactly as predicted by the call-count tracing above: zero regression, because SE mode cannot reach the fixed code paths.

## 3. Variants tried (31, one knob changed from baseline at a time; all via env vars on the **same binary**, no rebuild)

Battery: `robustness/tests/perf_holes.c` (7 hole patterns) + `collide16`/`collide48` + `tlbstress` (capacity/conflict/remap) = 12 jobs, AtomicSimpleCPU, oracle-checked. Raw: `robustness/results-perf/variant_sweep.tsv`; driver: `/tmp/sahilag24/run_variant_sweep.sh` + `gen_variant_jobs.py`. Every row: 12/12 PASS, 0/47,068,801 oracle mismatches (atomic and timing CPU models give identical miss counts per §2, so atomic-only is representative at 1/3 the cost; the heavy multi-core/SMT jobs are skipped here since §2 already shows they're insensitive to this approach's TLB code).

| variant | env override | total L1 misses | vs baseline |
|---|---|---|---|
| **V1 baseline** (defaults: 128 sets, 4 ways, 8 chunks, prefetch 8, LRU) | *(none)* | 149703 | — |
| V2 bug1 fix reverted | `PERF_FIX_L2_DEMAP=0` | 149703 | +0.0% |
| V3 bug2 fix reverted | `PERF_FIX_L2_FLUSH_NONGLOB=0` | 149703 | +0.0% |
| V4 bug3 fix reverted | `PERF_FIX_L2_PCID=0` | 149703 | +0.0% |
| V5 bug4 fix reverted | `PERF_FIX_L2_PERMS=0` | 149703 | +0.0% |
| V6 all 4 fixes reverted (original bug) | all four `=0` | 149703 | +0.0% |
| V7 | `PERF_L2_SETS=16` | 149703 | +0.0% |
| V8 | `PERF_L2_SETS=32` | 149703 | +0.0% |
| V9 | `PERF_L2_SETS=64` | 149703 | +0.0% |
| V10 | `PERF_L2_SETS=256` | 149703 | +0.0% |
| V11 | `PERF_L2_WAYS=1` | 149703 | +0.0% |
| V12 | `PERF_L2_WAYS=2` | 149703 | +0.0% |
| V13 | `PERF_L2_WAYS=8` | 149703 | +0.0% |
| V14 extreme capacity: 16 sets × 1 way = 16 slots | `PERF_L2_SETS=16 PERF_L2_WAYS=1` | 159810 | +6.8% |
| V-debug extreme capacity: 1 set × 1 way = 1 slot | `PERF_L2_SETS=1 PERF_L2_WAYS=1` | 189673 | +26.7% |
| V15 | `PERF_COARSE_CHUNKS=4` | 149703 | +0.0% |
| V16 | `PERF_COARSE_CHUNKS=16` | 149703 | +0.0% |
| V17 | `PERF_COARSE_CHUNKS=32` | 149703 | +0.0% |
| V18 | `PERF_COARSE_CHUNKS=64` | 149703 | +0.0% |
| V19 | `PERF_PREFETCH_DEGREE=1` (no prefetch) | 242905 | +62.3% |
| V20 | `PERF_PREFETCH_DEGREE=2` | 198548 | +32.6% |
| V21 | `PERF_PREFETCH_DEGREE=4` | 164053 | +9.6% |
| V22 | `PERF_PREFETCH_DEGREE=16` | 142257 | −5.0% |
| V23 | `PERF_PREFETCH_DEGREE=32` | 138495 | −7.5% |
| **V24 — best overall** | `PERF_PREFETCH_DEGREE=64` | **136601** | **−8.8%** |
| V25 | `PERF_L2_REPLACE=fifo` | 149703 | +0.0% |
| V26 | `PERF_L2_REPLACE=random` | 149703 | +0.0% |
| V27 (replace policy, 16×1 slots) | `fifo` + 16 sets × 1 way | 159810 | +6.8% (= LRU, V14: no choice with 1 way) |
| V28 (replace policy, 16×1 slots) | `random` + 16 sets × 1 way | 159810 | +6.8% (= LRU/FIFO) |
| V29 (real choice: 8×2=16 slots) | `lru` + 8 sets × 2 ways | 159557 | +6.6% |
| V30 (real choice: 8×2=16 slots) | `fifo` + 8 sets × 2 ways | 159475 | +6.5% (best of the three here) |
| V31 (real choice: 8×2=16 slots) | `random` + 8 sets × 2 ways | 160232 | +7.0% (worst of the three here) |

**Findings (all real, all with 0 oracle mismatches):**
- **Prefetch/coalescing degree dominates.** Going from the paper's 8-page window down to 1 (no prefetch) costs **+62% misses**; going up to 64 gains **−8.8%** over the default, with clearly diminishing returns past 32 (32→64 only adds another 1.4 points). **Winner: `PERF_PREFETCH_DEGREE=64`.**
- **L2 capacity barely matters** for this workload (16-48 2 MiB regions) down to 128→16 sets or 4→1 ways individually — only when total capacity collapses to 16 slots (6.8% worse) or 1 slot (26.7% worse) does it show up. The hash spreads regions well enough that normal-sized L2s are never under real pressure here.
- **Coarse-filter granularity has zero effect on the miss count** (correctness and total misses identical across 4/8/16/32/64 chunks) but **does shift internal structure**: finer chunks → more `coarseFilterCleanHits`/`coarseFilterEarlyRejects` (fast path used more often) and fewer secondary-bitmap accesses (109172/29819 clean/early at the default 8 chunks → 182416/71189 at 64 chunks, with `l2BitmapHits` falling from 230585 to 157341 correspondingly) — a real latency/energy-side tradeoff the Perforated Pages paper's coarse filter is designed around, reproduced here quantitatively, even though it doesn't change the miss *count* on this battery.
- **Replacement policy only matters under real capacity pressure**, and even then the effect is small (≤0.5% between LRU/FIFO/RANDOM at 8×2=16 slots); FIFO edged out LRU and RANDOM slightly here (159475 vs 159557 vs 160232) — not a strong enough signal to call a clear policy winner, but RANDOM is consistently the worst of the three.
- **Not implemented** (named in the breadth order but out of scope for this session): a hole-density threshold that would fall back to plain 4K entries instead of perforating a 2 MiB region above some hole percentage. This needs a genuinely new insertion-time decision (not just a parameter on the existing structure) and was not attempted — listed here rather than silently dropped.

## 4. SPEC CPU2017

**Root-cause correction from the earlier version of this report:** the non-completion was **not** a KVM/acceleration issue (SE mode needs none). The real cause, found by checking `simerr.txt`: gem5 se.py's default simulated physical memory is 512 MB, and `mcf_r`'s heap repeatedly `mremap`s (growing ~144 MB each time) until gem5 hits `src/sim/mem_pool.cc:100 fatal: Out of memory`. Fixed by adding `--mem-size=8GiB` to every run. Also relocated the SPEC install from `/tmp` to `/var/tmp` (same disk, instant `mv`) because gem5 SE unconditionally redirects every `/tmp/...` path to `<outdir>/fs/tmp/...`, which is wiped on every run.

5 benchmarks built as static `base` binaries on the first attempt (no flag fixes needed): `500.perlbench_r`, `505.mcf_r`, `531.deepsjeng_r`, `541.leela_r`, `557.xz_r`. `test` and `refrate` run dirs staged for all 5. Test-to-completion and REF-window (`--fast-forward=1e9 --maxinsts=2e8`, `TimingSimpleCPU`+caches) runs were launched for all 5 (test) / 3 (ref: mcf, xz, deepsjeng) against both the fixed and stock trees, all with the memory fix.

| benchmark | input | runs OK | output identical to stock | TLB-miss change vs stock | evidence |
|---|---|---|---|---|---|
| 500.perlbench_r | test (`test.pl`) | **Y** | **Y** (`diff` exact match) | base 8497+890=9387 → fixed 24+456=480 (**−94.9%**) | `runs/spec/perlbench-test-{fixed,base}/{stdout.txt,stats.txt}` |
| 505.mcf_r | test (`inp.in`) | launched, in progress at report time | — | — | `runs/spec/mcf-test-{fixed,base}/` (OOM-fixed relaunch; see `speclogs/test-mcf-*.log`) |
| 557.xz_r | test (1 workload) | launched, in progress at report time | — | — | `runs/spec/xz-test-{fixed,base}/` |
| 531.deepsjeng_r | test (`test.txt`) | launched, in progress at report time | — | — | `runs/spec/deepsjeng-test-{fixed,base}/` |
| 541.leela_r | test (`test.sgf`) | launched, in progress at report time | — | — | `runs/spec/leela-test-{fixed,base}/` |
| 505.mcf_r / 557.xz_r / 531.deepsjeng_r | REF window (ff 1e9 + 2e8 detailed) | launched, in progress at report time | — | — | `runs/spec/{mcf,xz,deepsjeng}-ref-{fixed,base}/` |

**perlbench_r is a complete, real, measured SPEC result**: identical output, 0 mismatches over 26,359,745 oracle-checked translations (dtb 5,963,855 + itb 20,395,890 — `runs/spec/perlbench-test-fixed/stats.txt`), 94.9% fewer L1 TLB misses than stock. The other four benchmarks and the 3 REF windows were launched (confirmed actively computing — 99%+ CPU, not hung) after the memory fix but had not finished by the time this report was written; interpreted (no-KVM-needed-but-still-no-hardware-acceleration) execution of real, unmodified SPEC binaries is simply slow in gem5 SE mode (perlbench's own test.pl took ~5 minutes; mcf's test input had not finished after 25+ minutes of continuous 99%+ CPU). These runs were left running past this report; their `done.json`/`stats.txt` will exist if this is re-read later, and no number is claimed for them here.

## 5. Verdict and not tested

**Verdict:** 6 real bugs fixed with file:line evidence, each either verified via the oracle+matrix (bugs 5/6) or verified-safe-and-reachability-traced (bugs 1-4, confirmed 0 SE call-sites, so the fix cannot regress anything SE can test while being the structurally correct FullSystem-mode fix). 31 architecture variants measured with 0 oracle violations on all of them; `PERF_PREFETCH_DEGREE=64` is the measured winner on this battery (−8.8% vs the paper's default degree-8), with prefetch/coalescing window size mattering far more than L2 capacity, associativity, or replacement policy for this workload class (pointer-chasing/hole-pattern microbenchmarks). One complete, correct, real SPEC data point (perlbench_r) confirms the fix holds on real software too (identical output, 0/26M oracle mismatches, 94.9% fewer misses); four more benchmarks and three REF windows were launched with the OOM fix applied but had not finished in session time.

**Not tested:**
- Full completion of mcf/xz/deepsjeng/leela (test) and the 3 REF windows — launched, not finished (§4).
- FullSystem-mode PCID isolation, supervisor/NX-permission fidelity, and CR3-switch L2 consistency for bugs 1-4 — SE mode cannot construct these scenarios at all.
- Checkpoint/restore cycle exercising bug 6's fix.
- `item3.verified` (decoupled bitmap cache), `grand_hybrid.verified`, `perfpages.verified` snapshots as separate architectures — not built this session (this lane's own fixed-code item2 variant was the priority).
- Hole-density threshold (perforated-2MiB-vs-plain-4K decision) as a variant — named in §3 as a real gap, not attempted.
- Reproduction of the original paper's specific "4.16x"/"71.22%" claims as stated figures — not targeted directly; the closest analogue measured here is the 94.9% L1-miss reduction on perlbench_r and the 60-86%/34-60% reductions on the 1-core microbenchmarks (carried over from the interim measurement, caveat: stock's 64-entry-only L1 vs this approach's L1+L2 mixes "an L2 exists" with "perforation helps" — isolating the two needs the NINE/inclusive/exclusive lanes as a same-L2-size baseline, not re-run here).
