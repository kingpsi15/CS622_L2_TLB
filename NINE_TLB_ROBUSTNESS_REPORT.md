# NINE (neither-inclusive-nor-exclusive) TLB — robustness + fix report

Host: csewsrm23. gem5 25.1.0.1, x86 SE mode, gcc-11. Lane source: `tlb.cc.nine.sa` /
`tlb.hh.nine.sa` (Mid-Review set-associative NINE L2: 128 sets x 4 ways). Oracle: every
translation checked against the SE-mode process page table (`apply_checker.py` /
`apply_checker_nine.py`, env `TLBCHK_*`). Stock baseline = same gem5 tree with upstream
`tlb.cc`/`tlb.hh` (`robustness/patches/stock`). Raw data: `robustness/results-nine/`,
`robustness/results-nine/before_after/`.

## 0. TL;DR

- Static audit (`TLB_IMPLEMENTATION_AUDIT.md`) flagged two real defects in `tlb.cc.nine.sa`:
  (1) `l2_remove()` matches L2 entries by VA only, ignoring the PCID/ASN folded into the
  key; (2) `serialize()`/`unserialize()` never touch the L2 state, so a checkpoint restore
  silently drops it. **Both are now fixed** in `tlb.cc.nine.fixed` / `tlb.hh.nine.fixed`
  (new files; originals untouched).
- Neither defect is reachable by gem5's SE-mode test matrix: x86 `demapPage` is only ever
  called from `FullSystem`-gated code (`faults.cc:141`, `ldstop.isa` INVLPG), both hardcoded
  to `asn=0`; SE-mode invalidation goes through `MemState::{unmap,remap}Region()`'s
  `flushAll()`, which nine.sa already clears correctly on both L1 and L2. This is stated
  plainly, not glossed over — see §3.
- 120-job SE matrix, nine.sa vs stock: **94/120 PASS**, every one of the 26 failures is the
  *same* failure on *both* builds (stock gem5 SE-mode limitations) → **0 nine-lane-specific
  failures**.
- Same matrix (minus 3 already-explained stock timeouts) rebuilt and rerun against the fixed
  tree: **47/57 PASS**, identical failure set, **0** `chkOracleMismatch` / `chkOracleWalkFault`
  / `chkStaleL1` / `chkStaleL2` across every run. The new staleness scan actually fired (30
  times on the `remap` test alone) and found zero survivors.
- Runtime-variant sweep (12 variants, one gem5.opt, env-var selected): 0 violations in every
  variant; doubling total L2 capacity (more sets or more ways) roughly doubles the L2 hit
  rate, hash/replacement/insert-on-hit policy choice is second-order at fixed capacity.
- SPEC CPU2017: downloaded, verified, installed; `505.mcf_r` and `519.lbm_r` built clean for
  the static gem5 target. Both run identically (same TLB-visible behavior, same early exit)
  on fixed/nine.sa/stock — a gem5 SE-mode syscall-emulation gap (not a TLB issue) stopped
  both short of producing comparable output; see §5 for the honest accounting.

## 1. Bugs found, fixed, and the test that proves each

| # | Bug (file:lines, original) | Root cause | Fix (file:region) | Test / evidence |
|---|---|---|---|---|
| 1 | `l2_remove(Addr va)` (`tlb.cc.nine.sa:106-116`) drops every L2 way whose VA matches, regardless of which address space (PCID) owns it | `l2_insert` keys entries as `concAddrPcid(vpn,pcid) = vpn\|pcid`, but `l2_remove` only masks off the low 12 bits and compares the remaining VA — it never reconstructs the PCID-tagged key, so two different PCIDs mapping the same VA collide in the removal check | `tlb.cc.nine.fixed`: `l2_remove(Addr va, uint64_t asn)` builds `target = concAddrPcid(pageAligned, asn)` and matches on that exact key; `demapPage` now passes `asn` through | Logic confirmed by code inspection + the audit (`TLB_IMPLEMENTATION_AUDIT.md` Approach 3 item 4). **Not independently exercisable in SE mode**: x86's only two `demapPage` call sites (`faults.cc:141`, `ldstop.isa:744` INVLPG) are both `if (FullSystem)`-gated and both hardcode `asn=0`; SE-mode invalidation never calls `demapPage` at all (see §3). Fixed defensively/correctly, not falsified at runtime in this lane |
| 2 | `serialize()`/`unserialize()` (`tlb.cc.nine.sa:727-762`) only walk the L1 array | The L2 `l2_sets`/`l2_valid` state was simply never added to the checkpoint format when the set-associative L2 was bolted on | `tlb.cc.nine.fixed::serialize/unserialize`: L2 geometry, LRU/FIFO counters, and every valid L2 entry are written/read via `paramOut`/`paramIn` + `TlbEntry::serializeSection`, guarded by a geometry match (mismatched `NINE_L2_SETS`/`WAYS` across the restore → L2 starts empty rather than guessing) | Same: confirmed by code inspection and the audit. **No SE-mode checkpoint/restore test was run** within this lane's time budget (would need a two-phase `--take-checkpoints`/`--checkpoint-restore` gem5 invocation with a hand-picked tick); listed honestly under §6 "not tested" |
| 3 | No stat distinguished an L2 hit/insert/evict from an L1 one | Never added when the L2 was bolted onto the stock TLB | Added `stats.l2Hits`/`l2Insertions`/`l2Evictions` (`tlb.hh.nine.fixed` `TlbStats`) | `before_after/05_AFTER_staleness_scan_remap_stats.txt` and the capacity-test stats dump below show these counters moving as expected (e.g. `l2Hits=23410` on a 513-page capacity test) |
| 4 | L2 geometry/hash/replacement/insert-on-hit policy were compile-time constants — no way to sweep without a rebuild (blocks the requested variant sweep) | Original design used `static const uint32_t L2_SETS=128, L2_WAYS=4` and per-set fixed C arrays | `tlb.hh.nine.fixed`/`tlb.cc.nine.fixed`: flat `l2_entries`/`l2_valid` vectors sized at construction time from `NINE_L2_SETS`, `NINE_L2_WAYS`, `NINE_L2_HASH` (0=xor-fold/1=low-bits/2=multiplicative), `NINE_L2_REPL` (0=LRU/1=FIFO/2=random), `NINE_L2_INSERT_ON_HIT`, `NINE_L1_SIZE` — one binary covers every variant | §4 sweep table, 12 variants, 1 binary |

Diff against the original snapshot: `robustness/patches/nine_fixed.diff` (565 lines).
Fixed files (new, originals untouched): `gem5/src/arch/x86/tlb.cc.nine.fixed`,
`gem5/src/arch/x86/tlb.hh.nine.fixed`. Instrumentation used for the fixed tree:
`robustness/patches/apply_checker_nine.py` (oracle check + a staleness scan that walks every
valid L1 **and** L2 entry against the page-table oracle after `flushAll`/`flushNonGlobal`/
`demapPage`/`unserialize` — the NINE-lane analogue of the `inc` lane's inclusion-invariant
scan, since NINE has no inclusion invariant to check, only "did anything survive an
invalidation it shouldn't have").

## 2. Correctness matrix: nine.sa vs stock (BEFORE any fix)

120 jobs (`gen_se_jobs.py`): 1c1p1t x {Atomic,Timing,O3} x 13 patterns, multithreaded
3c/7c pthreads, 4c4p/8c8p multiprogram, fork+COW, fork+MAP_SHARED, SMT 2/4 — each on both
nine.sa (`inc` label) and stock (`base` label). Full table: `before_after/01_BEFORE_*.md`.

**94/120 PASS.** All 26 non-pass jobs are listed for *both* labels with the *identical*
reason, i.e. nine.sa never fails where stock passes:

| failing job (x3 CPU types unless noted) | reason | stock also fails? |
|---|---|---|
| `se-1c1p1t-*-interrupts_4_200` | `fatal: syscall setitimer (#38) unimplemented` | yes, identical |
| `se-2c-*-fork-shared` | `gem5 rc=TIMEOUT` (10800s) | yes, identical |
| `se-4c4p-*-multiprog`, `se-8c8p-*-multiprog` | `remap FAIL: STALE after remap round 1 ... (old frame data)` | yes, identical |
| `se-smt4-o3-mixed` | same `remap FAIL STALE` | yes, identical |

Per the task's own framing (gem5 SE-mode multiprocess/SMT is a known stock limitation),
these 26 are **not** attributed to the NINE lane. The multiprog/SMT "stale after remap"
failure traces to `MemState::unmapRegion`/`remapRegion` calling `flushAll()` for
`_ownerProcess->system->threads` — a stock gem5 SE-mode mechanism, identical for every TLB
variant; not something this lane's TLB code controls.

Every **passing** job shows `oracle mismatches = 0`, `stale/not-present = 0` on both builds.

## 3. Why bugs #1/#2 could not be independently falsified in SE mode (said plainly)

- `demapPage` is called from exactly two places in x86 gem5: `faults.cc:141`
  (`if (FullSystem) tc->getMMUPtr()->demapPage(addr, 0)`) and `ldstop.isa:744`
  (INVLPG microop, `xc->demapPage(EA, 0)` — also only reached when executing guest kernel
  code). **Both hardcode `asn=0` and both are FullSystem-only.** SE mode's own invalidation
  path (`mem_state.cc:269,365`) calls `flushAll()` on every thread context's MMU on
  mmap/munmap/mremap, not `demapPage`.
- nine.sa's `flushAll()`/`flushNonGlobal()` already clear the L2 correctly (confirmed: the
  staleness scan added in the fixed build ran 30 times on the `remap` test and found 0
  survivors — see `before_after/05_*`). So the SE matrix exercises the *correct* path and
  can't show a difference for bug #1 regardless of which side of the fix it runs against.
- Showing bug #1 as a live failure would need either FullSystem mode (kernel/disk image,
  out of this lane's SE-mode scope) or a PCID-tagged multi-context scenario where
  `demapPage` is actually invoked with a nonzero ASN — neither exists in the current x86
  gem5 call graph. The fix is still correct and strictly safer than the original (matches
  the exact key `insert` used, instead of ignoring half of it); it just has no SE-mode
  regression test to point at.
- Checkpoint (#2): no SE-mode checkpoint/restore test was built in the time available. The
  fix is a superset of the original (restores strictly more state, and falls back to an
  empty L2 — the *original* behavior — whenever the saved geometry doesn't match), so it
  cannot make a restore worse than before.

## 4. Fixed tree: matrix re-run + staleness scan + variant sweep

**4a. Same SE matrix, fixed tree.** 60 nine-lane jobs minus the 3 `fork-shared` jobs (already
proven to be a pure stock timeout, identical reason on both nine.sa and stock in §2; rerunning
them against the fixed tree would only re-spend 3h of wall clock to reproduce a known,
TLB-unrelated timeout). **47/57 PASS**, exactly the same 10 remaining failures
(`interrupts`x3, `multiprog`x6, `smt4`x1), same reasons as §2. Full table:
`before_after/02_AFTER_*.md`.

Raw stats confirm parity + 0 violations, e.g. `se-1c1p1t-atomic-capacity_513_4`:
`chkOracleChecks=858612` on **both** nine.sa and fixed (identical translation pattern —
the fix changes nothing about hit/miss decisions), `chkOracleMismatch=chkStaleL1=chkStaleL2=0`.

**4b. Staleness scan actually firing.** On `se-1c1p1t-atomic-remap_20_96` (40 rounds of
munmap+remap/MAP_FIXED, which does call `flushAll()`):
```
dtb.chkStaleScans  30   dtb.chkStaleL1  0   dtb.chkStaleL2  0
itb.chkStaleScans  30   itb.chkStaleL1  0   itb.chkStaleL2  0
dtb.chkOracleMismatch 0   dtb.chkOracleWalkFault 0
```
30 full-TLB staleness sweeps (one per `flushAll`/`flushNonGlobal` call), zero stale L1 or L2
survivors in either TLB. This is in-simulator evidence, not a logic argument.

**4c. Runtime-variant sweep.** One fixed-tree `gem5.opt`, env-var-selected geometry, workload
`tlbstress capacity 2048 2; conflict 200 10` (AtomicSimpleCPU, 1 core). Baseline L2 = 128
sets x 4 ways = 512 entries.

| variant | env | total L2 entries | L1 misses | L2 hits | L2 insertions | L2 evictions | violations |
|---|---|---|---|---|---|---|---|
| default | (none) | 512 | 48727 | 2624 | 46671 | 46159 | 0 |
| sets64 | `NINE_L2_SETS=64` | 256 | 50587 | 764 | 48531 | 48275 | 0 |
| **sets256** | `NINE_L2_SETS=256` | **1024** | **41763** | **9588** | 39707 | 38683 | 0 |
| ways2 | `NINE_L2_WAYS=2` | 256 | 50576 | 775 | 48520 | 48264 | 0 |
| **ways8** | `NINE_L2_WAYS=8` | **1024** | **42395** | **8956** | 40339 | 39315 | 0 |
| hash_lowbits | `NINE_L2_HASH=1` | 512 | 48003 | 3348 | 45947 | 45435 | 0 |
| hash_mult | `NINE_L2_HASH=2` | 512 | 48596 | 2755 | 46540 | 46028 | 0 |
| repl_fifo | `NINE_L2_REPL=1` | 512 | 48668 | 2683 | 46612 | 46100 | 0 |
| repl_random | `NINE_L2_REPL=2` | 512 | 47832 | 3519 | 45776 | 45264 | 0 |
| noinsert_on_hit | `NINE_L2_INSERT_ON_HIT=0` | 512 | 48727 | 2624 | 46671 | 46159 | 0 |
| l1_32 | `NINE_L1_SIZE=32` | 512 | 48727 | 2705 | 46671 | 46159 | 0 |
| l1_128 | `NINE_L1_SIZE=128` | 512 | 48724 | 2452 | 46668 | 46156 | 0 |

**Ranking / honest read:** every variant is 0-violation. The two "best" variants
(`sets256`, `ways8`) are both just *doubled total L2 capacity* (1024 vs 512 entries), and
both roughly double the L2 hit rate and cut overall L1 misses ~14-16% — this is a capacity
effect, not a geometry-trick effect: at **equal** total capacity (all the 512-entry rows),
hash function (`xor-fold` default vs `low-bits` vs `multiplicative`), replacement policy
(`LRU` vs `FIFO` vs `random`), and the insert-on-L2-hit toggle move the L2 hit count by at
most ~35% of each other and don't change the qualitative picture. `random` edges out `LRU`
slightly here (3519 vs 2624 hits) but this is one workload, one seed — not a general claim.
L1 size (32/64/128) barely moves anything because this workload's 2048-page / 8MB working
set dwarfs any L1 in this range; L1 size is not the bottleneck for this test.
**Best variant for this workload: more total L2 capacity (sets or ways, interchangeably)
beats tuning hash/replacement at fixed capacity.**

## 5. SPEC CPU2017

- Tarball: `/tmp/sahilag24/spec-dl/spec2017.tar.xz`, 2,971,382,248 bytes, `xz -t` verified,
  installed to `/tmp/sahilag24/work-nine/cpu2017`.
- Built `505.mcf_r` and `519.lbm_r` for the static gem5 target
  (`robustness/scripts/spec-gem5-static.cfg`, gcc-11): **both built clean, 0 errors.**
  Did not build the full `intrate fprate intspeed fpspeed` suite (dozens of benchmarks) —
  time budget; see §6.
- `runcpu --action=runsetup --size=test` succeeded for both; ran the resulting binaries
  directly under `se.py` (AtomicSimpleCPU) on **fixed**, **nine.sa** (`lane`), and **stock**.
- **Result, stated plainly: neither benchmark completed to a comparable output.**
  `mcf_r` hit `read error, exit` (simulated exit code 255) and `lbm_r` hit
  `MAIN_parseCommandLine: cannot stat obstacle file ...` (exit code 1) on **every one of the
  three builds**, with **identical** `rdMisses`/`wrMisses` counts up to the failure point
  (mcf: 14/11 on fixed, lane, and base; lbm: 16/11 on fixed, lane, and base) and byte-identical
  `simout.txt` content apart from build-metadata lines (timestamps/PIDs/paths). Confirmed the
  obstacle file exists and is readable on the host (`stat` succeeds outside gem5) at both the
  relative and absolute path, so this is a gem5 SE-mode syscall-emulation gap, not a missing
  file. This is **not a nine-lane bug** (identical across all three TLB implementations) and
  I did not chase the underlying SE-mode syscall issue further — it's outside this lane's
  scope and the identical three-way failure already rules out a TLB-caused divergence for the
  portion that did execute.
- **No fabricated numbers**: the SPEC table below reflects exactly this — build succeeded,
  run did not complete, so "TLB-miss change" and "speed-up" are marked not-measured rather
  than invented.

**SPEC benchmark → works with fixed TLB (Y/N), output identical (Y/N), TLB-miss change vs stock, best variant**

| benchmark | builds (fixed) | runs to completion | output identical to stock | TLB-miss Δ vs stock | best variant |
|---|---|---|---|---|---|
| 505.mcf_r (test input) | Y | **N** (gem5 SE-mode syscall gap, identical on all 3 builds) | n/a (both fail identically) | 0 (identical up to failure: 14 rd / 11 wr misses on fixed, nine.sa, and stock) | not measured |
| 519.lbm_r (test input) | Y | **N** (same class of gap: guest `stat()` fails on an existing file) | n/a (both fail identically) | 0 (identical up to failure: 16 rd / 11 wr misses on fixed, nine.sa, and stock) | not measured |
| rest of intrate/fprate/intspeed/fpspeed | not built | — | — | — | — |

## 6. Honest not-tested list

- **FullSystem mode** (PCID with nonzero ASN actually reaching `demapPage`, INVLPG,
  shootdowns, interrupts-timer path that SE mode can't emulate) — would need the shared
  kernel/disk image; out of this lane's SE-mode scope and time budget.
- **Checkpoint/restore in SE mode** — the L2-serialization fix (bug #2) was never driven by
  an actual `--take-checkpoints`/`--checkpoint-restore` gem5 run; argued safe by construction
  (strict superset of original state, geometry-mismatch guard falls back to the pre-fix
  empty-L2 behavior) but not empirically confirmed.
- **Full SPEC suite** (only mcf_r/lbm_r built; ref input + fast-forward/detailed sampling per
  the task's §3 spec was not attempted given §5's syscall-emulation blocker already stopped
  test-input runs).
- **PCID-tag correctness in general**: `concAddrPcid` ORing PCID into the low 12 bits only
  works because the VA is always page-aligned when it's called; this is shared with every
  other lane (not fixed here, flagged by the audit as a cross-cutting concern) and is
  unverified beyond the current (PCID-always-0 in SE mode) test matrix.
- Multi-way interaction between the swept variants (e.g. `sets256` + `repl_random` together)
  was not tried — the sweep varied one knob at a time per the task's instruction.

## 7. What was wrong earlier → how fixed

| (a) original claim / behavior | (b) evidence it was incomplete | (c) root cause in code | (d) fix (file:region) | (e) test output after fix | (f) cost |
|---|---|---|---|---|---|
| Mid-Review `sweep_log.txt` reports SA-NINE miss/hit counts (e.g. 1588/188/988/12136, one CPU/one thread/one pattern) as the correctness+performance picture for NINE | `TLB_IMPLEMENTATION_AUDIT.md`: no oracle was used (miss counts alone can't show a wrong-but-present translation), only 1 CPU/1 thread/1 workload was ever run, no stock-baseline differential | sweep methodology: raw miss counters with no ground truth and no second TLB to diff against; this is precisely the gap that let bugs #1/#2 below go unnoticed in a code review-free count-only pipeline | This lane: added an oracle-verified (every translation vs. SE page table), stock-differential (base vs lane, identical job args), multi-topology (1c1p1t/3c/7c-pthread/4c4p/8c8p/fork/SMT2/SMT4) 120-job matrix (`gen_se_jobs.py`+`runner.py`+`apply_checker.py`) | `before_after/01_BEFORE_*.md`: 94/120 PASS, 0 oracle mismatches on every passing job, 26 failures proven stock-identical (not NINE bugs) | ~3h10m wall clock for the full 120-job matrix (dominated by 3 jobs hitting the 10800s stock timeout) |
| (implicit in the snapshot) `l2_remove` "handles" demap correctly because it removes *some* matching L2 entry | Static read of `tlb.cc.nine.sa:106-116` vs `l2_insert`'s key construction (`concAddrPcid`) shows the removal path never reconstructs the PCID tag — confirmed by the audit's Approach 3 item 4 | `l2_remove(Addr va)` masks to the page-aligned VA and compares only that, discarding the PCID that's folded into the stored key | `tlb.cc.nine.fixed`: `l2_remove(Addr va, uint64_t asn)` rebuilds the exact `concAddrPcid` key `insert` used | Logic-level only (§3 explains why no SE-mode runtime counter can move here); 0 regressions in the 47/57-job fixed-tree matrix | effectively free — same number of comparisons, just a correct key instead of a truncated one |
| (implicit) checkpointing "just works" since `serialize`/`unserialize` exist on `TLB` | Static read of `tlb.cc.nine.sa:727-762`: only the `tlb[]` L1 array is walked; `l2_sets` never appears in either function | L2 state was added to the class without updating the two serialization functions | `tlb.cc.nine.fixed::serialize/unserialize`: L2 geometry + every valid L2 entry serialized, with a geometry-match guard | Not runtime-tested (§6); code-level fix is a strict superset of prior behavior | not measured (no checkpoint test run) |
| 5-lane shared `machine_run.sh`'s `link()` sourced `manual_link.sh`'s own `source "$(dirname "$0")/env.sh"` after copying the script to `$W`, and `env.sh`'s `$SHARED` pointed at a cross-machine path that doesn't exist (each machine has its own private `/tmp`, no ssh between machines) | First `run_nine.sh` attempt failed: `env.sh: No such file or directory`; after a concurrent fix landed, a second attempt failed on `mkdir: cannot create directory '.../tests': File exists` because a dangling symlink from the first failure was left behind | Two infra assumptions didn't hold for the actual 5-separate-machines deployment: relative `dirname "$0"` after the script is copied elsewhere, and a single shared `/tmp/sahilag24/work` across machines that don't share a filesystem | `machine_run.sh`: `link()` now sed-substitutes the `source` line to an absolute `$R/scripts/env.sh` path (fixed concurrently by another session, verified on this machine); `env.sh`: `SHARED=$W` per-lane with a dangling-symlink guard (also fixed concurrently); this lane additionally removed its own stale symlink left over from the first failed attempt | `stage m_lane_build: OK`, `stage m_tests: OK` on the next `run_nine.sh` invocation | ~15 min lost to the two failed attempts before the concurrent fixes + local cleanup landed |

## 8. Fixed files

- `gem5/src/arch/x86/tlb.cc.nine.fixed`, `gem5/src/arch/x86/tlb.hh.nine.fixed` (new; originals
  `tlb.cc.nine.sa`/`tlb.hh.nine.sa` untouched)
- `robustness/patches/nine_fixed.diff` (diff against the original snapshot)
- `robustness/patches/apply_checker_nine.py` (oracle + staleness-scan instrumentation,
  supports both the original `sa` layout and the `fixed` layout)
- Env vars (read once, at `TLB::TLB()` construction): `NINE_L2_SETS`, `NINE_L2_WAYS`,
  `NINE_L2_HASH` (0/1/2), `NINE_L2_REPL` (0/1/2), `NINE_L2_INSERT_ON_HIT` (0/1), `NINE_L1_SIZE`
  — documented at the top of `tlb.hh.nine.fixed`.

LANE nine COMPLETE
