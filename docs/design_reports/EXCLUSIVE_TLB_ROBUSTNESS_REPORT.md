# Approach 2 of 5: Exclusive L1/L2 TLB — Fix and Robustness Report

Status: implementation and checker validation complete; SPEC test-input runs are
still running on this host. SPEC values are intentionally left unclaimed until
the run and output comparisons finish.

## 1. What this approach is

The exclusive policy keeps each translation in exactly one level. A cold page
walk fills L1; when L1 evicts a translation, it spills to L2. An L2 hit is
promoted to L1 and removed from L2. This differs from an inclusive L2, which
keeps a second copy, and from NINE, where the two levels may overlap.

Fixed source files (the original snapshots remain unchanged):
`gem5/src/arch/x86/tlb.cc.excl.fixed` and
`gem5/src/arch/x86/tlb.hh.excl.fixed`. Patch:
`robustness/patches/excl_fixed.diff`.

Runtime configuration: `EXCL_L2_SETS` (1–4096, rounded up to a power of two),
`EXCL_L2_WAYS` (1–16), `EXCL_L2_HASH` (0=xor7, 1=modulo, 2=xor-fold),
`EXCL_L2_REPL` (0=LRU, 1=FIFO, 2=random), `EXCL_L1_SIZE` (>0), and
`EXCL_SPILL` (`always`, `dirty-hot`, or `never`).

## 2. What was wrong earlier -> how fixed

| Earlier behavior / method | Evidence before fix | Root cause | Fix | Evidence after fix / cost |
|---|---|---|---|---|
| L1/L2 exclusivity was assumed, not enforced by an invariant checker. SMT promotion/eviction could leave duplicate translations. | The original-source checker run recorded 1,368,154 checks and 391,950 duplicate violations, concentrated in SMT2/SMT4; oracle mismatches were 0. See `robustness/results-excl/before_after/original_excl_checked_matrix.md` and `.json`. | Promotion used an L2-resident entry while inserting into a full L1; that insertion can spill another entry into the same L2 set, aliasing or displacing the promotion source. | Copy the source entry locally, protect its L2 way during the L1 insertion, then remove the source after promotion. The checker defers its invariant scan only during that transient move and checks immediately after completion. | Fixed-source checker run: 1,366,678 checks, zero duplicate violations, zero oracle mismatches/walk faults. `excl_chk_after.md` / `.json`. No cycle-cost estimate is claimed; the suite’s simulator wall time is not a hardware-cycle comparison. |
| L2 demap matched by virtual page while ignoring the PCID/ASN key. | `tlb.cc.exclusive.sa::l2_remove` masks away the low 12 bits and removes the first matching VA, regardless of PCID. This path is not independently reachable in the tested SE setup. | Removal did not use the same address-space-qualified key as lookup/insertion. | Pass ASN to L2 removal and match the exact page-aligned VA plus PCID key. | Code-level correction is in `tlb.cc.excl.fixed::l2_remove` / `demapPage`. PCID-specific FullSystem behavior was not runtime-tested; no performance cost measured. |
| The old checkpoint routines serialized L1 only, losing L2 entries and relevant policy state at restore. | `tlb.cc.exclusive.sa::serialize/unserialize` did not visit the L2 array. No checkpoint/restore run was part of the old evidence. | L2 state was absent from the checkpoint format. | Serialize/restore L2 ways, geometry/policy metadata, and dirty-hot spill state; restore L2 only if checkpoint and runtime policies match. | Fixed implementation builds and passes the SE checker suite. A checkpoint/restore scenario was not run, so runtime restoration and its cost remain unverified. |
| The original evidence had no EXCL-specific invariant counters and no runtime design sweep. | The pre-fix run had no EXCL invariant measurement; historical per-policy performance was not a controlled, logged sweep. | Exclusivity and performance counters/knobs were not instrumented. | Add an EXCL invariant checker for the run, L2 hit/insert/evict counters, and environment-selected geometry/hash/replacement/spill/L1 size. | Fixed matrix plus the 12-configuration focused sweep below; sweep results are logged under `robustness/results-excl/excl_variant_*.json`. |
| Earlier SPEC setup/run claims were not yet backed by completed EXCL-vs-stock outputs. | Before this campaign, there was no completed EXCL SPEC comparison to cite. The first SPEC run attempt also put the installation under `/tmp`, which gem5 SE redirects inside the simulated output directory. | SPEC job evidence was missing; guest file paths under `/tmp` did not refer to the real host installation. | Install/run SPEC from `/var/tmp`; compare fixed and stock with separate working directories and preserve each job’s output/stats. | SPEC tests and reference windows are active at report time. Output equality and miss changes are pending; no SPEC conclusion is claimed yet. |

Original-vs-stock 120-job SE matrix: 94/120 jobs passed. The 26 non-passes
occurred on both EXCL and stock: `setitimer` is unsupported, same-VA
multiprocess remap reports stale data, and the MAP_SHARED cases did not finish
before the run was stopped. Fixed-source checked matrix also had 94/120 jobs
pass; the EXCL invariant and oracle counters were zero on all completed jobs.
Full tables and run details: `robustness/results-excl/excl_matrix.md`,
`excl_chk_before.md`, and `excl_chk_after.md`.

## 3. Runtime variants tried

Each row uses three focused workloads (capacity, conflict, remap) on fixed EXCL
and stock. “Misses” is the sum of read/write/execute TLB misses across those
three jobs; it is not a SPEC result. All three EXCL jobs passed with zero
invariant violations, oracle mismatches, and oracle walk faults. Each table
row’s raw JSON is `robustness/results-excl/excl_variant_<name>.json`.

| Variant | Setting | EXCL misses / stock misses | Change vs stock | Correctness |
|---|---|---:|---:|---|
| **Default** | defaults (128 sets, 4 ways, xor7, LRU, always spill) | 9,063 / 36,348 | −75.1% | 3/3 pass; 0 invariant/oracle errors |
| Sets 64 | `EXCL_L2_SETS=64` | 23,491 / 36,348 | −35.4% | 3/3 pass; 0 errors |
| Sets 256 | `EXCL_L2_SETS=256` | 5,891 / 36,348 | −83.8% | 3/3 pass; 0 errors |
| Ways 2 | `EXCL_L2_WAYS=2` | 26,658 / 36,348 | −26.7% | 3/3 pass; 0 errors |
| Modulo hash | `EXCL_L2_HASH=1` | 6,114 / 36,348 | −83.2% | 3/3 pass; 0 errors |
| Fold hash | `EXCL_L2_HASH=2` | 8,947 / 36,348 | −75.4% | 3/3 pass; 0 errors |
| FIFO | `EXCL_L2_REPL=1` | 9,063 / 36,348 | −75.1% | 3/3 pass; 0 errors |
| Random | `EXCL_L2_REPL=2` | 9,061 / 36,348 | −75.1% | 3/3 pass; 0 errors |
| Dirty-hot spill | `EXCL_SPILL=dirty-hot` | 36,244 / 36,348 | −0.3% | 3/3 pass; 0 errors |
| No spill | `EXCL_SPILL=never` | 36,348 / 36,348 | 0.0% | 3/3 pass; 0 errors |
| Smaller L1 | `EXCL_L1_SIZE=32` | 9,260 / 36,348 | −74.5% | 3/3 pass; 0 errors |
| One-set hash edge | `EXCL_L2_SETS=1 EXCL_L2_HASH=2` | 239 / 735 | −67.5% | capacity-only job passed; 0 errors |

Among the three-workload sweep, `EXCL_L2_SETS=256` had the fewest measured
misses. This is a microbenchmark result only, not a SPEC winner. The one-set
edge is reported separately because it used only the capacity workload, so its
miss total is not directly comparable to the three-workload rows.

## 4. SPEC CPU2017

The archive was verified and SPEC was installed under `/var/tmp/sahilag24/cpu2017`.
Five statically built test-input benchmarks are staged:
`500.perlbench_r`, `505.mcf_r`, `531.deepsjeng_r`, `541.leela_r`, and
`557.xz_r`. Test-input commands are being run to completion on fixed EXCL and
stock. Three 1-core reference windows use fast-forward 1e9 instructions and
2e8 detailed TimingSimpleCPU instructions.

| Benchmark | Test runs complete? | Fixed/stock output identical? | TLB-miss change | Evidence |
|---|---|---|---|---|
| `500.perlbench_r` | In progress | Pending | Pending | `/tmp/sahilag24/work-excl/runs/excl_spec_test_first/` |
| `505.mcf_r` | In progress | Pending | Pending | `/tmp/sahilag24/work-excl/runs/excl_spec_test_first/` |
| `531.deepsjeng_r` | Not yet run in test campaign | Pending | Pending | staged job: `/tmp/sahilag24/work-excl/jobs/spec_test.json` |
| `541.leela_r` | Not yet run in test campaign | Pending | Pending | staged job: `/tmp/sahilag24/work-excl/jobs/spec_test.json` |
| `557.xz_r` | Not yet run in test campaign | Pending | Pending | staged job: `/tmp/sahilag24/work-excl/jobs/spec_test.json` |
| Reference windows (`perlbench`, `mcf`, `deepsjeng`) | Partial; completed windows are identified in `done.json` | Pending | Pending | `/tmp/sahilag24/work-excl/runs/excl_spec_ref_first3/` |

The jobs still running or not yet started are explicitly not counted as
successful. A final version of this table must be filled only from completed
job records and output comparisons.

Completed reference-window measurements so far (not full benchmark runs):

| Benchmark | Fixed EXCL TLB misses | Stock TLB misses | Change | Status / raw evidence |
|---|---:|---:|---:|---|
| `500.perlbench_r` | 2,633 | 170,197 | −98.5% | Both jobs PASS; outputs not yet diffed. `runs/excl_spec_ref_first3/{inc,base}/spec-ref-1c-500.perlbench_r/{stats.txt,done.json}` |
| `505.mcf_r` | 1,323,058 | Pending | Pending | Fixed job PASS; stock job still running. `runs/excl_spec_ref_first3/inc/spec-ref-1c-505.mcf_r/{stats.txt,done.json}` |
| `531.deepsjeng_r` | Pending | Pending | Pending | Fixed and stock jobs still running. |

## 5. Verdict and not tested

The fixed EXCL implementation builds and its instrumentation reports zero
duplicate-residency violations across 1,366,678 checks, with zero oracle
mismatches/walk faults in the completed fixed-source matrix. The original code
did not meet the exclusivity invariant under SMT pressure. The focused sweep
shows substantial miss sensitivity to geometry and spill policy; the best
microbenchmark result is not yet validated on SPEC.

Not yet tested or completed:

- SPEC test-input completion and output comparison for all five benchmarks.
- Three complete fixed-vs-stock SPEC reference-window pairs and their miss
  comparisons.
- SPEC runs for non-default EXCL variants.
- FullSystem PCID isolation and demap behavior.
- A checkpoint save/restore test of the L2 state.
- Hardware-cycle cost; simulator wall-clock seconds are not a substitute.
- Independent diagnosis/fix of the common stock-SE multiprocess remap and
  unsupported-`setitimer` failures.
