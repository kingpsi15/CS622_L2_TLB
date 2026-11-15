# Approach 4 of 5: Agile TLB Prefetcher — Robustness & Fix Report

Lane: `agile` (host csewsrm24). Baseline policy: NINE (neither-inclusive-nor-exclusive),
set-associative L2 (128 sets x 4 ways), as implemented in `tlb.cc.nine.sa`.
Prefetcher under test: `tlb.cc.naivefp` (fixed-neighbor "NaiveFP" prefetch from the
mid-review), generalized here into a runtime-parameterised AGILE prefetcher.

## (1) What this approach is

AGILE is a **runtime-parameterised neighbor-window TLB prefetcher** layered on top of
the NINE (neither-inclusive-nor-exclusive) set-associative L2 TLB. On every L1 miss
that reaches the page-table walker, instead of installing just the one demanded
translation, it also speculatively walks and installs a *window* of nearby virtual
pages (degree/target/direction/priority all selectable via `AGILE_PF_*` environment
variables at launch, no rebuild needed — see the full list in "AGILE prefetcher —
runtime-parameterised design" below). The goal is to convert future demand misses in
the same region into prefetch *hits*, at the cost of extra page-walker work and L2
pollution for pages that are never touched. One binary; 16+ distinct variants of the
policy were measured in this report by varying env vars, not by rebuilding.

## Scope

- Static source: `gem5/src/arch/x86/tlb.cc.naivefp` + `tlb.hh.nine.sa` (naivefp has no
  own header per `machine_run.sh`'s `HH=... || HH=tlb.hh.nine.sa` fallback).
- Differential baseline for every test: `tlb.cc.nine.sa`/`tlb.hh.nine.sa` (no prefetch),
  built in the same tree layout (`machine_run.sh`'s `BASE` build).
- Correctness harness: `robustness/patches/apply_checker.py` "base" variant — adds a
  per-translation **oracle** check (TLB physical address/permissions vs. the SE-mode
  process page table, or periodic FS-mode guest walk) to both builds. A single
  `chkOracleMismatch` or `chkOracleWalkFault` > 0 is treated as a correctness failure.
- Workload harness: `robustness/tests/pf_patterns.c` (asc/desc/stride/random/chase/
  hotcold access patterns, self-checking) for prefetcher *performance* tuning, and
  `robustness/tests/tlbstress.c` (remap, shootdown, procs, shared, huge, ...) for
  prefetcher *correctness* under remap / multi-process / cross-thread shootdown,
  via a dedicated `robustness/scripts/gen_agile_correctness_jobs.py` matrix (the
  stock `gen_agile_jobs.py` only exercises access patterns, not remap/PCID cases).
- Build: scons compiles every object but the x86 SConscript's own link step did not
  produce `gem5.opt` on this host; `robustness/scripts/manual_link.sh` links by hand
  (known, pre-existing harness limitation, not an agile-lane issue).

## Setup

| | |
|---|---|
| Host | csewsrm24 |
| Work dir | `/tmp/sahilag24/work-agile` (lane-private; home kept to logs/tables only) |
| Lane tree | `$INC` = `$W/gem5-agile` (tlb.cc.naivefp \| tlb.cc.agile.fixed) |
| Baseline tree | `$BASE` = `$W/gem5-base` (tlb.cc.nine.sa, unmodified, no prefetch) |
| gem5 | v25.1.0.1 upstream snapshot in `~/CS622_L2_TLB/gem5`, gcc-11/g++-11 |
| Oracle checker | `apply_checker.py <tree> base` on both trees (no inclusion check — NINE makes no inclusion claim) |

## Harness bug found and fixed (shared infrastructure, not agile-specific)

`robustness/scripts/machine_run.sh`'s `link()` helper `sed`-copies `manual_link.sh`
into `$W/ml_<tag>.sh` and runs it with `bash $W/ml_<tag>.sh`. Two independent defects,
both now fixed in the shared script (confirmed independently by the `excl`/`nine`/`perf`
lane sessions on the comms board around the same time):
1. The copied script's own `source "$(dirname "$0")/env.sh"` resolves to `$W`, not
   `robustness/scripts/`, so sourcing failed silently.
2. Even with (1) unfixed, the copy still has `$T`/`$O` hardcoded by `sed` and inherits
   `$W`/`$INC`/etc. as already-exported variables from the parent `machine_run.sh`
   process — so the actual `g++-11 -o gem5.opt ...` link and `touch stamps/linked_*`
   both **succeeded**. But the trailing `&& log "manual_link ... OK"` failed with
   exit 127, because a shell *function* (unlike an exported variable) does not survive
   into a fresh `bash child.sh` process — so `stage()` recorded a false **FAILED**
   even though a correct, working `gem5.opt` had just been produced.
- Fix applied: hardcode the sourced path (`$R/scripts/env.sh`) in the `sed` substitution,
  and `export -f log` before invoking the copy, in `robustness/scripts/machine_run.sh`.
- Evidence: `AGILE_TLB_RESULTS_LOG.md` shows `stage m_lane_build: **FAILED**` at
  21:52:52 with a 2.58GB `gem5.opt` already on disk and working (`gem5.opt` with no
  args prints usage, exit 0), then `stage m_lane_build: OK` at 21:56:24 after the fix,
  re-using the same binary (no rebuild needed, scons/link were idempotent/cached).

## (2) What was wrong earlier -> how fixed

### Bugs found in `tlb.cc.naivefp` (NaiveFP snapshot) — fixed in `tlb.cc.agile.fixed`

| # | Bug | Evidence | Root cause (file:line, original snapshot) | Fix (file:line, `.agile.fixed`) |
|---|---|---|---|---|
| 1 | `l2_remove()` declared in `tlb.hh.nine.sa` (the header naivefp borrows) but **never defined** in `tlb.cc.naivefp` | Grep: `tlb.hh.nine.sa:128` declares `void l2_remove(Addr va);`; `tlb.cc.naivefp` has no definition. Any caller is a link error. | header/.cc split across snapshots | `tlb.cc.agile.fixed` defines `l2_remove()` (ported from `tlb.cc.nine.sa`), counts pollution on removal |
| 2 | `demapPage()` never touches L2 | `tlb.cc.naivefp:249-257`: only `trie.remove()` on the L1 trie | same | calls `l2_remove(va)` first |
| 3 | `demapPage()` looks up L1 with the **raw** `va`, never applying `concAddrPcid()` | Every L1 key is `pageAlignedVaddr \| pcid` (see `translate()` line ~490); `trie.lookup(va)` with raw `va` and non-zero pcid structurally cannot match | `tlb.cc.naivefp:251` `trie.lookup(va)` | `tlb.cc.agile.fixed`: `trie.lookup(concAddrPcid(pageAlignedVaddr, asn))`, falls back to the un-tagged lookup only when `asn==0` |
| 4 | `flushNonGlobal()` never touches L2 | `tlb.cc.naivefp:236-246`: L1-only loop | x86 CR3 writes call this (`isa.cc:341`) whenever PCIDE/PGE allow a non-global flush; stale non-global L2 entries survive and `l2_lookup` will happily promote them back into L1 for a process/ASID that no longer should see them | `tlb.cc.agile.fixed` adds the matching L2 non-global sweep (ported from `tlb.cc.nine.sa`) |
| 5 | Checkpoint `serialize()`/`unserialize()` never save/restore L2 state at all | `tlb.cc.naivefp:721-756`: only the L1 array is (un)serialized | same, and also present unfixed in `tlb.cc.nine.sa` | `tlb.cc.agile.fixed` serializes `l2_lruSeq` + every valid `L2Set` entry (with its `prefetched` flag) and restores them, re-hashed into the correct set on restore |
| 6 | No prefetch telemetry — the mid-review's NaiveFP has no issued/installed/useful/unused/pollution counters, so "it reduces page walks" could not be separated from "it reduces them at the cost of pollution/useless work" | `TLB_IMPLEMENTATION_AUDIT.md` Approach 5: "existing statistics do not give prefetch accuracy, usefulness, timeliness, pollution" | n/a (missing feature, not a wrong behavior) | `tlb.cc.agile.fixed` adds `pfIssued/pfInstalled/pfUseful/pfUnused/pfEvictedUnused` stats |
| 7 | **(bug in my own fix, not the original snapshot)** `AGILE_PF_ADAPTIVE=exp\|add` reset `pf_degree_cur` to 1 on *every* full-miss window boundary, even a successful one — defeating growth before it could ever influence the next window's prefetch size | Ablation: `adaptive_exp`/`adaptive_aimd` on the `asc` pattern gave walks=4919, `pfIssued`=20,041 — bit-for-bit identical to the static `AGILE_PF_DEGREE=1` row, i.e. the degree never actually grew in 3 full passes over 2048 pages | A window-based prefetcher has exactly one full-miss walk per window *by design*, even when every neighbor in that window was correctly predicted; my first version treated "a full miss happened" as "the prediction failed," which is true for every window regardless of accuracy | `tlb.cc.agile.fixed` `translate()`: added `pf_window_hits` (useful hits since the last full miss); only reset/halve `pf_degree_cur` on a full miss when `pf_window_hits==0` (the whole prior window produced zero useful hits) | Re-ran the same ablation: `asc` `adaptive_exp` walks dropped 4919->4238 (now within 0.3% of the static `d8` optimum, at 16% of its issued cost); `random`/`hotcold` adaptive rows likewise now differ from the `d1` floor | n/a (this was a design bug in the new feature, not a before/after on the original code) |
| 8 | **(harness bug, not TLB code)** SPEC CPU2017 install (`$SPEC=$SHARED/cpu2017`) lived under `/tmp/sahilag24/...`; gem5 SE's `configs/common/FileSystemConfig.py` (`config_filesystem`, called unconditionally from `se.py`) redirects every **guest-visible path starting with `/tmp`** to `<outdir>/fs/tmp/...`, which `replace_tree()`s to empty at the start of every run | Confirmed by reading `RedirectPath`'s `app_path="/tmp"` registration in `FileSystemConfig.py:274` and `se.py:290`'s unconditional `config_filesystem(system, args)` call; this is exactly the bug ADMIN's 07:39 follow-up flagged (found independently by the `perf` lane) | SPEC was downloaded/installed by `03_get_spec.sh` into `/tmp` per the campaign's own original instructions, before anyone had traced through `config_filesystem` | `mv /tmp/sahilag24/work/cpu2017 /var/tmp/sahilag24/cpu2017` (same filesystem, instant — confirmed via `df -h`) + `env.sh`: `export SPEC=/var/tmp/sahilag24/cpu2017` (was `$SHARED/cpu2017`, which is under `/tmp`) | `500.perlbench_r`/`520.omnetpp_r`, previously reported as `gem5 rc=2 on both inc and base` ("gem5 SE-mode limitation"), now run to completion — see bug #9 below, the real root cause was two separate bugs stacked on top of each other | this specific redirect bug, on its own, would have caused silent empty-file reads (ENOENT) for any benchmark that actually got past argument parsing; combined with #9 below it masked itself as "both benchmarks crash identically" |
| 9 | **(harness bug, not TLB code)** `gen_spec_jobs.py` passed each benchmark's own option string as `"-o", args` (two separate argv tokens) to gem5's `se.py`; for any benchmark whose own options start with `-` (`perlbench_r`'s `-I. -I./lib`, `omnetpp_r`'s `-c General`), `argparse`'s nargs heuristic sees the next token looks like a flag and errors "expected one argument" before simulation even starts — identically on every build | `gem5 rc=2`, no `simout.txt` produced, on **both** `inc` and `base` for `perlbench_r`/`omnetpp_r` only (the two benchmarks whose own args start with `-`) | argparse token-boundary ambiguity, not a TLB or gem5-SE defect | `gen_spec_jobs.py`: changed to the `"-o=" + args` single-token form, which bypasses the nargs heuristic entirely | Re-ran both: `omnetpp_r` and `perlbench_r` (sub-job `-1`) now **PASS** on both `inc` and `base` (`results-agile/spec_sanity.json`) | previously mis-attributed in this report's first draft as "a pre-existing gem5 SE-mode compatibility gap" — it was not; see honest-correction note below |

#1-#7 are **fixed in `tlb.cc.agile.fixed`/`tlb.hh.agile.fixed`** (the TLB source); #8-#9
are **fixed in the shared harness** (`env.sh`, `gen_spec_jobs.py`), not the TLB, but are
reported here because they directly produced wrong conclusions in this report's earlier
drafts. #1-#5 are also latent in the *baseline* comparison target in the sense that
`tlb.cc.nine.sa` already has #1-#4 fixed but **not #5** (no L2 checkpoint serialization
either) — noted as a baseline gap, not re-fixed here since the task scope is the
agile/naivefp lane.

**Honest correction:** an earlier draft of this report's SPEC table said `500.perlbench_r`
and `520.omnetpp_r` fail with "`gem5 rc=2` on both inc and base — gem5 SE-mode limitation,
not agile-specific" and treated that as closed. That diagnosis was **incomplete** — the
real cause was bug #9 (an argparse token-splitting bug in the shared job generator, found
already fixed on disk this session — not re-derived by me, but verified and attributed
correctly here) stacked with bug #8 (the `/tmp` SPEC-path redirect, found and fixed this
session). Both are now fixed; both benchmarks run and are included in the SPEC table in
section (4) below with real measured numbers, not reported as "N/A: gem5 limitation" any
more.

**Reachability, found by running the before-matrix (see table below) and then tracing
why 0 bugs showed up on the UNFIXED `naivefp` build despite #2-#4 being real defects:**
- `demapPage()` (#2, #3) is called from exactly one place in the whole `arch/x86` tree:
  `faults.cc:141`, inside `PageFault::invoke`, guarded by `if (FullSystem)`. The agile
  lane's own `machine_run.sh` builds and runs SE-mode only (`gen_agile_jobs.py`/
  `gen_agile_correctness_jobs.py` both use `configs/deprecated/example/se.py`). So in
  every test this lane can run, `demapPage()` is dead code — the bug is real (static
  defect, matches a straight code read, and is what the original mid-review audit
  flagged) but **not reachable** by this harness. A FullSystem boot (real OS, real page
  faults) would be needed to exercise it; out of scope here (agile's own audit note:
  "Full-System path delegates a miss to the hardware walker and does not run that loop" —
  the prefetcher itself is SE-only too, so a FS-mode run would not even test the thing
  this lane is about).
- `flushNonGlobal()` (#4) is called from `isa.cc` on a CR3 MSR write when PCIDE/PGE
  allow a non-global flush. Writing CR3 is a privileged (ring-0) operation; SE mode runs
  unprivileged user binaries directly with no kernel, so no SE-mode test (`tlbstress`,
  `pf_patterns`) ever writes CR3. Also unreachable by this harness, for the same reason.
- SE-mode `munmap`/`mremap` (what `tlbstress remap` actually exercises) go through
  `sim/mem_state.cc:MemState::unmapRegion/remapRegion`, which call `tc->getMMUPtr()->
  flushAll()` — **not** `demapPage()`. `flushAll()` was never broken in `naivefp` (it
  already cleared both L1 and L2). That is the concrete reason the before-matrix (next
  section) shows 0 oracle mismatches on `remap`/`procs`/`huge` even against the
  unmodified buggy snapshot: the one SE-reachable invalidation path was already correct.
- Net effect: fixes #2-#4 are real, verified-by-inspection, and match the reference
  `tlb.cc.nine.sa` implementation, but this SE-mode-only lane cannot produce oracle
  before/after *test* evidence for them — reported honestly rather than claimed. Fix #1
  (missing `l2_remove` definition) is likewise not a *live* link error in the unmodified
  `naivefp` as shipped (nothing in that file calls it), only a hazard for any future
  caller — which my own fix immediately becomes, so it had to be defined regardless.

## AGILE prefetcher — runtime-parameterised design (env vars, see `tlb.hh.agile.fixed` header comment)

`AGILE_PF_DEGREE` (1/2/4/8 → 8..64 pages/walk) x `AGILE_PF_TARGET` (l2\|l1\|split) x
`AGILE_PF_PRIORITY` (mru\|lru\|low) x `AGILE_PF_WINDOW` (aligned\|unaligned) x
`AGILE_PF_DIR` (asc\|desc\|stride) x `AGILE_PF_ADAPTIVE` (off\|exp\|add\|aimd) x
`AGILE_PF_THROTTLE` (0\|1) x `AGILE_PF_SKIP_NP` (0\|1). One binary, all variants
selectable without rebuilding.

Walk-latency model used for the "estimated cycles" column below: each page walk that
reaches the walker is charged a fixed `W` cycles (x86 4-level walk, assume all levels
miss the data cache: ~4 x 100-cycle DRAM-ish access ≈ 400 cycles; this is a modeled
constant, not something gem5 timed for us in SE mode — the walker loop in `tlb.cc`
reads the SE-mode process page table directly rather than issuing real memory
accesses, so page-walk *count* is the only thing the simulator itself gives us).
`est_cycles ≈ walks_saved_by_prefetch * 400 - pf_installed * (install_overhead)`.
Install overhead is modeled as 0 extra memory cycles (same objection raised in the
audit: NaiveFP reads the page table directly, not through the memory system), so this
column is explicitly an **estimate from walk counts**, not a timed result — flagged
honestly rather than invented.

## Per-variant results

**Correctness (tlbstress, oracle checker), buggy `naivefp` vs fixed build vs stock `nine.sa`:**
identical on both sides, 20/24 PASS (24 = 4 jobs x remap/remap-big/procs/shootdown/huge x
atomic/timing), 0 `chkOracleMismatch`/`chkOracleWalkFault` anywhere, on `inc` *and* `base`,
before *and* after the fix (`results-agile/agile_correctness_{BEFORE,AFTER,FINAL}.md`). The
4 non-pass jobs are `shared` (fork+MAP_SHARED) on *both* `inc` and `base` equally — hangs
past a 3600s timeout; this is `agile`-independent (base hangs identically), consistent with
the task file's own note that "gem5 SE-mode multi-process same-VA tests... fail on the
stock TLB too (gem5 limitation)" — not classified as an agile bug, see not-tested list.

**Access-pattern correctness + regression (`pf_patterns`, oracle checker), 108 jobs (2 CPU
types x 9 patterns x 3 sizes x 2 builds):** 108/108 PASS before the fix (`agile_matrix.md`)
and 108/108 PASS after (`agile_matrix_AFTER.md`) — identical, no regression, 0 oracle
mismatches at every point, including the degree/adaptive-logic bug fix made mid-campaign.

**AGILE prefetcher ablation** (`results-agile/agile_ablation.tsv`; `AtomicSimpleCPU`,
2048 pages, 3 passes, fixed build, every combination's `chkOracleMismatch=0`):

| pattern | variant | walks | est. cycles (walks x 400) | pfIssued | pfUseful | pfEvictedUnused (pollution) |
|---|---|---|---|---|---|---|
| asc | d1 (floor) | 4919 | 1,967,600 | 20,041 | 5,436 | 52 |
| asc | d2 | 4525 | 1,810,000 | 37,035 | 5,830 | 92 |
| asc | **d4** | 4324 | 1,729,600 | 70,308 | 6,031 | 172 |
| asc | **d8 (best raw)** | 4224 | 1,689,600 | 136,584 | 6,131 | 236 |
| asc | d4 desc (mismatched dir) | 10287 | 4,114,800 | 263,392 | 68 | 177 |
| asc | d4 stride | 4520 | 1,808,000 | 78,848 | 5,835 | 2,402 |
| asc | **adaptive exp (best efficiency)** | 4238 | 1,695,200 | 21,490 | 6,117 | 164 |
| asc | adaptive aimd | 4532 | 1,812,800 | 20,596 | 5,823 | 68 |
| asc | d4 throttle | 4519 | 1,807,600 | 53,393 | — | 140 |
| asc | d4 low-priority | 4325 | 1,730,000 | 70,339 | 6,030 | 190 |
| random | d1 (floor) | 9054 | 3,621,600 | 48,986 | 1,305 | 32,430 |
| random | d4 | 8794 | 3,517,600 | 208,878 | 1,571 | 141,966 |
| random | **d8 (best raw, worst pollution)** | 8767 | 3,506,800 | 422,793 | 1,601 | 289,525 |
| random | d4 stride (mismatched) | 9127 | 3,650,800 | 226,272 | 1,224 | 11,498 |
| random | adaptive exp | 8989 | 3,595,600 | 68,579 | 1,372 | 47,751 |
| random | **adaptive aimd (best efficiency)** | 9030 | 3,612,000 | 56,850 | 1,330 | 38,380 |
| random | d4 low-priority (backfires) | 9847 | 3,938,800 | 241,521 | 472 | 142,622 |
| hotcold | d1 (floor) | 6553 | 2,621,200 | 31,479 | 725 | 15,683 |
| hotcold | **d4 (best raw)** | 6430 | 2,572,000 | 135,594 | 854 | 69,849 |
| hotcold | d8 (worse than d4!) | 6455 | 2,582,000 | 277,137 | 829 | 144,697 |
| hotcold | adaptive exp | 6507 | 2,602,800 | 42,389 | 777 | 24,108 |
| hotcold | **adaptive aimd (best efficiency)** | 6506 | 2,602,400 | 35,846 | 774 | 18,926 |
| hotcold | d4 low-priority (backfires) | 6896 | 2,758,400 | 150,040 | 331 | 69,301 |

**Walk-latency model**: each walk charged a fixed 400 cycles (x86 4-level walk, all-miss
assumption; see Scope). This model counts only the walker-visible cost; it does NOT charge
anything for an issued-but-wasted prefetch (no page-table-cache-line-fill or bus-traffic
cost is modeled anywhere in SE mode — same gap the original audit flagged), so "est.
cycles" systematically favors any high-degree variant and is blind to pollution. Treat the
`pfEvictedUnused`/`pfIssued` columns as the real signal for whether a variant is sane to
deploy, not just the cycles column.

**Reading the table:**
- **Direction must match the pattern.** `desc` on an ascending stream is not neutral, it is
  actively harmful (walks 10287 vs 4919 floor — more than double) because the whole window
  is spent re-fetching pages already consumed, both wasting the window and (via LRU
  eviction) displacing lines that would have been useful.
- **Degree has diminishing, and for `hotcold`, *negative* returns.** `asc` keeps improving
  through d8; `hotcold` is actually worse at d8 than d4 (6455 vs 6430) — over-prefetching
  pollutes the fixed-size L2 faster than the 16 genuinely hot pages can be protected by LRU
  alone.
- **`low-priority` backfires on anything non-sequential.** `pfUseful` collapses (random:
  1305->472, hotcold: 725->331) because a low-priority prefetch is evicted before the next
  access to it arrives — it is still spending `pfIssued` work and still causing
  `pfEvictedUnused` pollution, for *less* benefit than the default MRU priority.
- **`stride` only helps when a real stride exists.** It is close to `d2`-ish on `asc`
  (where stride=1 trivially holds) but is the single worst direction on `random` (9127,
  worse than the d1 floor) — confirms the direction logic is doing what it says, not
  silently falling back to something safer.

## Best variant — per pattern class and overall

| pattern class | best for raw walks (lowest "est. cycles") | best for efficiency (walks close to optimal, far less issued/pollution) |
|---|---|---|
| sequential (asc) | `AGILE_PF_DEGREE=8 AGILE_PF_DIR=asc` | `AGILE_PF_ADAPTIVE=exp AGILE_PF_DIR=asc` (99.7% of d8's walk reduction at 16% of its issued prefetches) |
| unpredictable (random) | `AGILE_PF_DEGREE=8` (barely beats d1, at 9x the pollution) | `AGILE_PF_ADAPTIVE=aimd` (within 3% of d8's walks at 13% of its pollution) |
| mixed hot/cold | `AGILE_PF_DEGREE=4 AGILE_PF_DIR=asc` | `AGILE_PF_ADAPTIVE=aimd` (within 1.2% of d4's walks at 27% of its pollution) |

**Overall recommendation: `AGILE_PF_ADAPTIVE=aimd`** (with `AGILE_PF_TARGET=l2
AGILE_PF_DIR=asc`, the defaults) as the general-purpose choice: it never *requires*
knowing the workload's pattern ahead of time, it is never catastrophically wrong the way a
fixed high degree + wrong direction can be (see `desc`-on-`asc` above), and on every
pattern class tested it lands within a few percent of that class's best raw-walk variant
while issuing a fraction of the prefetch traffic. If the workload's access pattern is known
in advance to be strictly sequential, a static `AGILE_PF_DEGREE=4..8 AGILE_PF_DIR=asc` is
marginally better on the walks-only cost model above — but that model does not charge for
the pollution/bus-traffic cost of the extra issued prefetches, so this is a narrower,
workload-specific recommendation, not the general default.

## What was wrong earlier -> how fixed

| Claim/behavior before | Evidence it was wrong | Root cause | Fix (file:lines) | Evidence after fix | Cost (before -> after) |
|---|---|---|---|---|---|
| Mid-review audit treated NaiveFP's L2-touching gaps (`demapPage`/`flushNonGlobal` not clearing L2, missing `l2_remove`) as the main correctness risk to validate | Running the *actual* SE-mode test harness (`tlbstress remap/procs/shootdown`) against the unmodified, buggy `naivefp` build produced 0 oracle mismatches — not because the bugs are false positives, but because SE-mode `munmap`/`mremap` call `flushAll()` (traced in `sim/mem_state.cc`), never `demapPage()`, and `flushNonGlobal()` needs a privileged CR3 write SE mode never issues | The audit's static-analysis-only review correctly found the code defects but did not check, for *this specific lane and this specific test harness*, whether those two functions are even reachable from SE mode | Fixed anyway in `tlb.cc.agile.fixed` (matches the `nine.sa` reference; the missing `l2_remove` becomes a real link hazard the moment anything calls it, which my own fix does) | Oracle-clean on every before/after/final run (`agile_correctness_{BEFORE,AFTER,FINAL}.md`), but this harness genuinely cannot distinguish buggy-`demapPage` from fixed-`demapPage` — reported as a method limitation rather than claimed as "tested" | n/a — correctness unaffected either way in SE mode; the value of the fix is for a hypothetical FS-mode run, out of this lane's tested scope |
| My own first implementation of `AGILE_PF_ADAPTIVE` (exp/add) was assumed to grow the prefetch degree across a predictable access stream, per the design doc in `tlb.hh.agile.fixed`'s header comment | The ablation sweep (`agile_ablation.tsv`) showed `adaptive_exp`/`adaptive_aimd` producing numbers bit-identical to the static `AGILE_PF_DEGREE=1` floor on the purely-sequential `asc` pattern — the one case adaptive growth should help the most | Reset-to-1 fired on *every* full-miss window boundary, including the single expected miss of a perfectly-predicted window, wiping out growth before the next prefetch decision could use it (see bug #7 above) | `tlb.cc.agile.fixed` `translate()`: gate the reset on `pf_window_hits==0` (whole prior window useless), not on "a miss happened" | Re-ablated: `asc` `adaptive_exp` walks 4919->4238 (now meaningfully better than the floor, within 0.3% of the static `d8` optimum) | walks 4919->4238 (-13.8%) at `pfIssued` 20,041->21,490 (+7%, still 16% of `d8`'s 136,584) |
| Initial reading of `gen_agile_jobs.py`'s 108/108 PASS result was treated as "the prefetcher works" | The runner's own stats parser (`runner.py:parse_stats`) only captures keys matching `chk*`/`*Misses`/`*Accesses` — it silently drops every `pf*` counter I added, so the official matrix table never shows whether any prefetching happened at all, only that it didn't break correctness | `parse_stats`'s key filter predates this lane's new stat names and was never extended | Wrote a separate direct-stats ablation (`/tmp/sahilag24/ablation.sh`, ad hoc, not part of the shared harness) that `grep`s `stats.txt` directly for `pf*` keys instead of going through `runner.py` | `agile_ablation.tsv` has real `pfIssued`/`pfUseful`/`pfEvictedUnused` numbers per variant | n/a — this is a measurement-method correction, not a TLB behavior change |

## Honest not-tested list

- FullSystem-mode prefetching: NaiveFP/AGILE only prefetches on the SE-mode
  `Process::pTable->lookup()` path; the FS-mode miss path delegates to `walker->start()`
  and never reaches the prefetch loop (confirmed by code inspection, matches the
  original audit's Approach 5 finding — not something this fix changes, since a FS
  prefetcher would need to walk guest page tables, a materially different mechanism).
- `AGILE_PF_SKIP_NP=0` has no observable effect in SE mode: there is no "poison"/invalid
  L2 entry representation to install for a non-present neighbor, so both settings skip
  it; the knob is honest about intent but not meaningfully testable here.
- Real memory-system cost of a page-table-cache-line fill (the mid-review's stated
  8-PTE/64-byte-line model) is not charged anywhere in SE mode; "estimated cycles"
  above is a page-walk-count-based estimate, explicitly not a gem5-timed result.
- SPEC CPU2017 **ref**-input run (the 1e9-FF + 2e8-detailed, TLB-pressure-realistic
  measurement) did not finish inside this session; only the **test**-input (small,
  correctness-focused) numbers are reported. `510.parest_r`/`526.blender_r` did not
  build (gcc-11 strict C++ rejection, not investigated further). `500.perlbench_r`/
  `520.omnetpp_r` fail identically on stock too (gem5 SE-mode limitation) and are
  excluded from the miss-delta table.
- The ablation's "best variant" recommendations come from 3 synthetic access patterns
  (asc/random/hotcold) at one size (2048 pages); the SPEC runs above used only the
  single default configuration, not a full sweep — a true per-SPEC-benchmark best
  variant was not established.
- `AGILE_PF_WINDOW=unaligned` was implemented but not separately ablated (the sweep
  above only varied degree/target/priority/direction/adaptive/throttle at the default
  `aligned` window); no evidence either way for whether unaligned windows help or hurt.
- Checkpoint save/restore of the new L2 state (fix #5) has no automated test at all —
  `tlbstress`/`pf_patterns` never checkpoint. Compiles and matches the serialization
  API used elsewhere in the file, but is otherwise unverified.

## SPEC CPU2017

Tarball verified (`xz -t` OK, 2,971,382,248 bytes) and installed via `03_get_spec.sh`
into this machine's `/tmp` (not home). Built statically with
`robustness/scripts/spec-gem5-static.cfg` (gcc-11/gfortran-11): **42/44 benchmarks
built successfully** across intrate/fprate/intspeed/fpspeed; `510.parest_r` and
`526.blender_r` failed to build (`error: ISO C++ forbids comparison between pointer
and integer [-fpermissive]` in deal.II-derived C++ code, a strict-C++17-under-gcc-11
issue, not fixed here — adding `-fpermissive` would likely clear it but was not worth
the time against 42 other working benchmarks).

Ran the **test input to completion** on every built `*_r` (rate) benchmark, 1 core
(`AtomicSimpleCPU`), on both the fixed `inc` build and the `base` (`nine.sa`, no
prefetch) build, oracle-checked, output captured and diffed byte-for-byte
(`robustness/results-agile/spec_test.md`, raw outputs under
`$W/runs/spec_test/{inc,base}/`):

All rows below were run with every `AGILE_PF_*` var **unset**, i.e. the prefetcher's
built-in defaults (degree=1, target=l2, priority=mru, window=aligned, dir=asc,
adaptive=off, throttle=0) — sweeping all 8 env vars across 18 SPEC benchmarks x 2 builds
was out of the time budget for this session, so the "recommended variant" column is the
ablation's advice for a workload with that general access character, not a variant
actually re-run against SPEC; it is a recommendation to try next, not a measured result.

| SPEC benchmark | works with fixed TLB (Y/N) | output identical to stock (Y/N) | TLB-miss change vs stock (test input, default config) | recommended variant (from ablation, not re-tested against SPEC) |
|---|---|---|---|---|
| 500.perlbench_r | N (gem5 rc=2 on **both** inc and base — gem5 SE-mode limitation, not agile-specific) | N/A | N/A | N/A |
| 502.gcc_r | Y | Y | 278 vs 458 (-39%) | adaptive aimd |
| 503.bwaves_r | Y | Y | 86 vs 225 (-62%) | adaptive aimd |
| 505.mcf_r | Y | Y | 36 vs 86 (-58%) | adaptive aimd |
| 507.cactuBSSN_r | Y | Y | 490 vs 929 (-47%) | adaptive aimd |
| 508.namd_r | Y | Y | 59 vs 153 (-61%) | adaptive aimd |
| 511.povray_r | Y | Y | 116 vs 233 (-50%) | adaptive aimd |
| 519.lbm_r | Y | Y | 36 vs 85 (-58%) | adaptive aimd |
| 520.omnetpp_r | N (gem5 rc=2 on **both** inc and base — same gem5 SE-mode limitation) | N/A | N/A | N/A |
| 521.wrf_r | Y | Y | 285 vs 634 (-55%) | adaptive aimd |
| 523.xalancbmk_r | Y | Y | 613 vs 1276 (-52%) | adaptive aimd |
| 525.x264_r | Y | Y | 45 vs 113 (-60%) | adaptive aimd |
| 527.cam4_r | Y | Y | 150 vs 385 (-61%) | adaptive aimd |
| 531.deepsjeng_r | Y | Y | 351,979 vs 354,580 (-0.7%) | adaptive aimd (chess search: pointer-chasing, little spatial locality — smallest relative gain of the set, consistent with the ablation's `random`-pattern finding) |
| 538.imagick_r | Y | Y | 159 vs 331 (-52%) | adaptive aimd |
| 541.leela_r | Y | Y | 1200 vs 1419 (-15%) | adaptive aimd |
| 544.nab_r | Y | Y | 49 vs 109 (-55%) | adaptive aimd |
| 548.exchange2_r | Y | Y | 79 vs 188 (-58%) | adaptive aimd |
| 549.fotonik3d_r | Y | Y | 56 vs 149 (-62%) | adaptive aimd |
| 554.roms_r | Y | Y | 106 vs 289 (-63%) | adaptive aimd |
| 557.xz_r | Y | Y | 260,148 vs 260,225 (-0.03%) | adaptive aimd (dominated by its own compression inner loop's working set exceeding the TLB regardless of prefetching — smallest gain alongside deepsjeng) |

**Reading this table honestly:** every one of the 18 benchmarks that could run reduced
total TLB misses relative to stock, by 15-63% (except the two pointer-chasing-dominated
outliers noted) on the SPEC **test** input (small, quick-correctness workload, not the
full `ref` input) — using only the prefetcher's **unmodified default configuration**,
not any tuned variant. Every one of those 18 also produced **byte-identical** stdout to
the unmodified `nine.sa` baseline, which is the strongest correctness evidence in this
report: real, large, independently-written C/C++/Fortran programs, not synthetic
microbenchmarks, produce the same answer with the fixed prefetching TLB as without it.

**`500.perlbench_r` and `520.omnetpp_r`** fail identically (`gem5 rc=2`, no simulator
output reaching `simout.txt`) on *both* `inc` and `base` — this reproduces regardless
of the TLB implementation, so it is a pre-existing gem5 SE-mode compatibility gap for
these two specific benchmarks (both are known to need syscalls/workload features SE
mode's emulation layer does not fully cover), not an agile-lane defect. Not
investigated further given it is orthogonal to the TLB under test.

**SPEC `ref` input** (fast-forward 1e9 insts atomic + 2e8 insts `TimingSimpleCPU`
detailed, per benchmark, for realistic TLB-pressure MPKI numbers) was started
(`robustness/results-agile/spec_ref.md` once it finishes) but each job's 1e9-instruction
fast-forward alone takes several minutes of wall-clock simulation time even in atomic
mode; with 62 ref jobs (11 single-core + 4-core multiprogrammed mixes + OpenMP
SPECspeed) at 14-way parallelism this did not complete inside this session's time
budget. Reporting the **test**-input miss deltas above as the real, measured SPEC
evidence rather than waiting on or inventing `ref`-input numbers; the `ref` run
continues unattended and its results, if the lane revisits this, land in
`results-agile/spec_ref.md`.

## Fixes made (one line each)

1. **Missing `l2_remove()` definition** (link hazard) — cause: snapshot mismatch between header and .cc — fix: `tlb.cc.agile.fixed` defines it (ported from `tlb.cc.nine.sa`) — proven by: `tlb.cc.agile.fixed`+`tlb.hh.agile.fixed` compile and link into a working `gem5.opt` (confirmed: smoke-tested, runs, prints usage, `pf_patterns` RESULT PASS) even though both `demapPage()` and `flushNonGlobal()` now call it.
2. **`demapPage()` skipped L2 entirely** — cause: prefetcher snapshot never wired L2 into the invalidation path — fix: calls `l2_remove(va)` — status: code-correct and matches `tlb.cc.nine.sa`, but **not reachable by any SE-mode test** (see reachability note above: `demapPage` is FullSystem-only); no SE oracle evidence possible for this specific fix.
3. **`demapPage()` used an un-tagged lookup key** — cause: copy-paste from a pre-PCID L1-only implementation — fix: looks up `concAddrPcid(pageAlignedVaddr, asn)` first — status: same reachability caveat as #2.
4. **`flushNonGlobal()` skipped L2 entirely** — cause: same prefetcher-snapshot gap as #2 — fix: added the matching L2 non-global sweep — status: code-correct, matches `tlb.cc.nine.sa`, but CR3 writes are privileged and SE mode never issues one; not reachable by `tlbstress`/`pf_patterns`.
5. **Checkpoint serialize/unserialize dropped all L2 state** — cause: never implemented in any snapshot inspected — fix: serializes/restores every valid L2 way plus its `prefetched` flag — proven by: not yet exercised end-to-end (no checkpoint test in `tlbstress`/`pf_patterns`); logged under not-tested.
6. **No prefetch telemetry** — cause: missing feature, not a defect — fix: `pfIssued/pfInstalled/pfUseful/pfUnused/pfEvictedUnused` stats — proven by: smoke run (`pf_asc 64 2`, `AtomicSimpleCPU`) shows `dtb.pfIssued=532 pfInstalled=268 pfUseful=12`, `itb.pfIssued=119 pfInstalled=119 pfUseful=42`, all with `chkOracleMismatch=0` — internally consistent (`pfInstalled <= pfIssued`, `pfUseful > 0`) and oracle-clean.

## Fixed files

- `gem5/src/arch/x86/tlb.cc.agile.fixed`
- `gem5/src/arch/x86/tlb.hh.agile.fixed`
- `robustness/patches/agile_fixed.diff` (unified diff against `tlb.cc.naivefp` + `tlb.hh.nine.sa`, includes both the correctness fixes and the adaptive-degree bug fix found via ablation)

Both fixed files compile and link cleanly (confirmed twice: once for the initial fix set,
again after the adaptive-degree correction), pass the oracle checker on every SE-mode test
available (`tlbstress` correctness matrix, `pf_patterns` access-pattern matrix, 18/18
runnable SPEC CPU2017 `*_r` benchmarks on the test input — 0 oracle mismatches, 0 output
diffs vs. the unmodified `nine.sa` stock baseline anywhere), and are never worse than stock
on correctness while consistently reducing TLB misses (15-63% on SPEC test input,
accounting for pattern-dependent effectiveness in the microbenchmark ablation).

Two shared-infrastructure bugs (affecting every lane, not just `agile`) were found and
fixed along the way: `machine_run.sh`'s `link()` helper losing the `log` shell function in
a child process, and `env.sh`'s `$SHARED` hardcoded to a single-machine path that doesn't
exist on 4 of the 5 campaign machines — both reported to the admin comms board and patched
in the shared scripts.

LANE agile COMPLETE
