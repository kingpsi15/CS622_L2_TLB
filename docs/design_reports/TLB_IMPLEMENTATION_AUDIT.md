# TLB Implementation Audit

**Date:** 2026-11-11  
**Scope:** Static audit of the x86 L2 TLB policy variants, Perforated Pages code, existing Agile-TLB-related prefetch code, and bounded verification. CoLT is excluded as requested.  
**Constraints honored:** No `sudo`, `apt`, package installs, or implementation-source edits. Build/test validation was authorized later; temporary build and simulation outputs were removed afterward. Existing worktree changes were left untouched.

## Plan and completion

- [x] Identify the source files used by the normal x86 gem5 build and separate them from archived policy snapshots.
- [x] Check the stated inclusive, exclusive, and neither-inclusive-nor-exclusive (NINE) invariants against the implementation paths.
- [x] Trace address-space tagging, TLB flushes, page demaps, permissions, and checkpoint behavior.
- [x] Inspect the Perforated Pages representation and compare the benchmark to the behaviors it claims to test.
- [x] Check the Agile-TLB citation and compare the implemented prefetch path with the described behavior.
- [x] Review existing configuration/results for core, thread, process, and workload coverage.
- [x] Record a separate report for each audit approach below.
- [x] Compile and run the existing native correctness and Perforated Pages benchmark programs with warnings treated as errors.
- [x] Add and natively validate a bounded deterministic multi-context benchmark with distinct translation data.
- [x] Compile the active `src/arch/x86/tlb.cc` object with the compatible local toolchain.
- [x] Build the full x86 gem5 binary in scratch storage after disabling the unavailable optional gRPC integration.
- [x] Run bounded gem5 smoke tests for one core/one process, two cores/two processes, and one SMT O3 core with two process contexts.
- [ ] Verify strict policy invariants, actual page holes/faults, remap/invalidation, protection changes, and checkpoint behavior in gem5; the current benchmark does not exercise these.
- [ ] Re-run against the user’s requested specifications and workflows once provided.

## Executive verdict

**The implementation cannot currently be signed off as correct across the requested workflows.** The active build contains a small, fixed-capacity, fully associative second-level array in each x86 TLB object, but the inclusive/exclusive alternatives are separate source snapshots rather than selectable runtime policies. Static inspection finds correctness gaps in invalidation and address-space separation. The Perforated Pages implementation is also only present in alternate files and is not part of the normal build. Existing result logs cover one CPU and one thread, not multicore, multithreaded, or multiprocess behavior.

This is a static audit, not a proof of runtime failure in every workload. Fixed mappings on a single context may appear to work, but important remap, context-switch, permission, and sparsity cases are not established.

## Approach 1 — Build-path and implementation-surface audit

**Result: Fail for feature integration; active source identified.**

- `gem5/src/arch/x86/SConscript` compiles `tlb.cc`; it does not compile names such as `tlb.cc.inclusive.sa`, `tlb.cc.exclusive.sa`, or `tlb.cc.item2.verified`.
- The active `tlb.cc` hard-codes an L2 capacity of 512 entries and uses a fully associative trie/LRU structure. It has no runtime policy selector or SimObject parameters for the L2 size/policy.
- The policy alternatives are snapshots that would need to be copied into the active source and rebuilt. Their presence in the repository does not make them selectable or jointly testable in an ordinary run.
- `X86MMU.py` instantiates separate `itb` and `dtb` TLBs. Because the L2 state is stored inside each `TLB`, this is not a unified instruction/data L2 TLB. Each CPU’s MMU also owns its TLB objects, so the current implementation does not model a shared multicore L2 TLB.

**Evidence:** [x86 SConscript](gem5/src/arch/x86/SConscript#L75), [active TLB constructor and L2 state](gem5/src/arch/x86/tlb.cc#L63), [TLB fields](gem5/src/arch/x86/tlb.hh#L100), [X86MMU topology](gem5/src/arch/x86/X86MMU.py#L37).

## Approach 2 — Policy-invariant review

**Result: The active source is NINE-like; the archived SA policies implement distinct insertion/replacement paths but still require invariant-focused validation.**

- **Active source:** Each L1 insertion first attempts an L2 insertion. L2 eviction does not invalidate a resident L1 entry, and L1 eviction does not remove a copy from L2. This is relaxed/non-inclusive behavior, not strict inclusion or strict exclusivity.
- **Inclusive snapshot:** The SA variant attempts to invalidate the matching L1 entry on L2 eviction and has L2 non-global flush/page-removal paths. Those paths still require ASID-aware checks (see Approach 3), so this is not yet a correctness sign-off.
- **Exclusive snapshots differ:** The older fully-associative [tlb.cc.exclusive](/users/btech/sahilag24/CS622_L2_TLB/gem5/src/arch/x86/tlb.cc.exclusive) promotes an L2 hit without removing the L2 copy. The Mid Review's set-associative [tlb.cc.exclusive.sa](/users/btech/sahilag24/CS622_L2_TLB/gem5/src/arch/x86/tlb.cc.exclusive.sa) calls `l2_remove` on promotion, so that duplicate-residency defect does not apply to its normal promotion path. Its flush/demap paths still need separate testing.
- **NINE snapshots:** They intentionally allow independent L1/L2 residency and are the closest match to the “neither inclusive nor exclusive” policy. The SA snapshot has explicit L2 non-global flushing and page removal, but its address-space tags and ASID-aware removal still need validation.

**Evidence:** [active L1/L2 insertion and L2 eviction](gem5/src/arch/x86/tlb.cc#L90), [active L1 insertion](gem5/src/arch/x86/tlb.cc#L154), [inclusive snapshot](gem5/src/arch/x86/tlb.cc.inclusive#L90), [exclusive spill](gem5/src/arch/x86/tlb.cc.exclusive#L135), [exclusive promotion path](gem5/src/arch/x86/tlb.cc.exclusive#L490), [NINE set-associative snapshot](gem5/src/arch/x86/tlb.cc.nine.sa#L75).

## Approach 3 — Address-space, invalidation, and lifecycle review

**Result: High-confidence correctness gaps in active code and separate gaps in some SA/Perforated snapshots; address-space behavior is not safe to assume.**

1. **Active source L2 is not invalidated on page demap.** Active `demapPage` removes only from the L1 trie. x86 page-fault handling calls MMU `demapPage`, so a stale L2 copy can later be promoted back into L1 after a page mapping changes. The Inclusive/NINE SA snapshots call L2 removal; Exclusive SA, Perforated Pages, and Grand Hybrid snapshots do not.
2. **Active source L2 is not flushed on non-global CR3 changes.** x86 CR3 writes call `flushNonGlobal`, but the active implementation only removes non-global L1 entries. The Inclusive/NINE SA snapshots clear non-global L2 entries; the Exclusive SA, Perforated Pages, and Grand Hybrid snapshots do not.
3. **PCID/process identity is not represented as a robust TLB tag.** `concAddrPcid` ORs the PCID into the low address bits. The trie is installed with a prefix length that excludes the page-offset bits (`MaxBits - logBytes`), so these low bits do not distinguish translations at the page granularity. In addition, `TlbEntry` has no stored ASID/PCID field, and its constructor’s `asn` argument is not retained. Thus same-virtual-address mappings from different contexts are not demonstrably distinct.
4. **Snapshot demap paths have related risks.** Inclusive and NINE SA snapshots call L2 removal, but removal matches virtual address only and does not use the supplied address-space number. The exclusive SA snapshot's demap path does not clear L2. Same-VA mappings in different contexts can therefore be invalidated incorrectly or leave stale translations behind.
5. **Checkpoint state is incomplete.** The custom L2 state is not serialized with the L1 entries. This can break policy invariants across restore (especially strict inclusion/exclusion) and makes post-checkpoint behavior differ from uninterrupted behavior.

**Evidence:** [PCID composition](gem5/src/arch/x86/tlb.hh#L79), [L2 trie key construction](gem5/src/arch/x86/tlb.cc#L103), [L1 trie key construction](gem5/src/arch/x86/tlb.cc#L154), [active flush/demap methods](gem5/src/arch/x86/tlb.cc#L203), [CR3 flush call](gem5/src/arch/x86/isa.cc#L337), [page-fault demap call](gem5/src/arch/x86/faults.cc#L138), [TlbEntry constructor and serialization](gem5/src/arch/x86/pagetable.cc#L58), [L1-only checkpoint serialization](gem5/src/arch/x86/tlb.cc#L700).

## Approach 4 — Perforated Pages representation and semantic-test review

**Result: Not integrated; current tests do not establish perforated-page correctness.**

- The Perforated Pages structures and lookup helpers are in alternate files such as `tlb.cc.item2.verified` / `tlb.hh.item2.verified`; the normal build does not use them.
- The snapshot represents a 2 MiB virtual region using 512 per-4-KiB validity bits and physical addresses, plus eight coarse 64-page states. It is an aggregate of 4 KiB translations, not evidence of full OS/shadow-PTE support for the paper’s perforated huge-page mechanism.
- The bitmap lookup identifies a region using `vpn_2mb`, without incorporating PCID/process identity. It reconstructs a temporary translation with fixed `user`, `noExec`, and `global` values; the stored sparse metadata includes write/cacheability information but not the complete per-page protection state. Mixed permissions and process isolation are consequently unverified.
- The benchmark named `tlb_perfpages_bench.c` allocates an aligned region, writes the first 384 pages, and skips accesses to the remaining 128. It does not create/map/unmap actual holes or assert that accesses to a hole fault. `tlb_correctness_bench.c` similarly checks ordinary data values; its “hole pattern” only skips pages.
- No Perforated Pages result appears in the saved `results_v2/sweep_log.txt`.

**Evidence:** [Perforated snapshot metadata](gem5/src/arch/x86/tlb.hh.item2.verified#L105), [bitmap lookup and reconstructed entry](gem5/src/arch/x86/tlb.cc.item2.verified#L93), [Perforated insertion](gem5/src/arch/x86/tlb.cc.item2.verified#L154), [benchmark’s allocation/access pattern](gem5/tlb_perfpages_bench.c#L19), [correctness bench hole-pattern check](gem5/tlb_correctness_bench.c#L104), [saved experiment summary](gem5/results_v2/sweep_log.txt#L117).

## Approach 5 — Agile-TLB reference and prefetch-path review

**Result: A limited fixed-neighbor prefetch exists in an alternate experiment, but it does not establish a complete Agile-TLB implementation.**

- The mid-review text describes an 8-PTE/32-KiB aligned neighbor prefetch. The `NaiveFP` code probes the seven other 4-KiB virtual pages in that aligned window and installs present translations into L2. This is a fixed-degree free-adjacent prefetch; it does not by itself establish the full Agile-TLB design or its evaluation methodology.
- The fixed-neighbor prefetch is in the alternate `tlb.cc.naivefp` snapshot, not the active `tlb.cc` compiled by the normal build. In that snapshot, the prefetch loop is reached in the SE `Process` path; the Full-System path delegates a miss to the hardware walker and does not run that loop.
- The prefetch loop does not model a page-table cache-line fill or incremental memory/timing cost; it reads the simulator’s process page table directly. The existing statistics do not give prefetch accuracy, usefulness, timeliness, pollution, or bandwidth, so page-walk-count changes alone are not sufficient to validate the mechanism.
- **Citation discrepancy:** The mid-review bibliography attributes “Exploiting Page Table Locality for Agile TLB Prefetching” to Margaritov et al. in *IEEE Micro*. An exact-title Crossref lookup resolves the work to Vavouliotis et al., ISCA 2021, DOI [10.1109/ISCA52012.2021.00016](https://doi.org/10.1109/ISCA52012.2021.00016). Please verify the intended paper/version and correct the bibliography before treating it as the implementation specification.
- Useful additional reference-aligned checks: vary prefetch degree and target level; test 32-KiB boundaries, non-present and sparse neighbors, different page sizes, address-space changes, and working sets that expose L2 pollution; report useful/unused prefetches, page walks, latency/cycles, and any modeled traffic. These remain proposals, not executed tests.

**Evidence:** [mid-review Agile-TLB section](CS622_Mid_Review_Doc.pdf), [NaiveFP prefetch loop](gem5/src/arch/x86/tlb.cc.naivefp#L569), [NaiveFP L2-hit path](gem5/src/arch/x86/tlb.cc.naivefp#L496), [saved prefetch result](gem5/results_v2/sweep_log.txt#L123).

## Approach 6 — Workflow and topology coverage audit

**Result: Historical evidence is limited to one core/thread; bounded multi-core and SMT smoke runs now pass, but correctness-specific concurrency cases remain untested.**

- The inspected saved config has one `system.cpu` object, `numThreads=1`, and a single `Process` workload. The sweep log covers five access patterns and six policy/prefetch configurations.
- No saved experiment covers multiple CPUs, SMT threads, multiple processes sharing a core, migration, address-space reuse, or multicore TLB shootdowns. The existence of multiple CPUs in gem5 generally does not prove that the custom TLB implementation handles their interactions correctly.
- New bounded smoke runs execute the deterministic benchmark as (a) one process on one `AtomicSimpleCPU`, (b) two processes on two `AtomicSimpleCPU`s, and (c) two process contexts on one `DerivO3CPU` with SMT enabled and caches configured. In the latter two, both processes report the same virtual mapping base and distinct seeds, and both finish with `PASS`. These are workload smoke tests only: they do not prove ASID/PCID isolation across all schedules, implement POSIX pthread coverage, or test migration/shootdowns.
- The user’s requested classes should be tested separately: single-core/single-thread; multicore with private per-core translations; SMT/shared-context or context-switching cases; and multiprocess cases with the same virtual address mapped to different physical pages. Include explicit invalidation and mapping-change events in each where applicable.

**Evidence:** [one-thread saved config](gem5/results_v2/SA-NINE__random1k/config.ini#L52), [workload process entry](gem5/results_v2/SA-NINE__random1k/config.ini#L216), [five-workload summary](gem5/results_v2/sweep_log.txt#L117), [per-core MMU structure](gem5/src/arch/x86/X86MMU.py#L37).

## Approach 7 — Existing results and test-quality review

**Result: Historical build/simulation evidence exists, but it is not a correctness sign-off.**

- The sweep log records successful builds for FA-NINE, SA-Exclusive, SA-NINE, SA-Inclusive, SA-NINE+SP, and SA-NINE+NaiveFP, with page-walk counts for five workloads. This supports that those source snapshots compiled at the time of the sweep.
- The results measure page-walk counts, not correctness properties such as no stale translations, policy invariants, or memory-protection behavior. They also do not report the added L2 lookup latency/traffic and do not include Perforated Pages.
- The `tlb_correctness_bench.c` checks values returned from normal allocated memory. It does not directly observe TLB residency, distinguish an L1 hit from an L2 hit, or validate faults and translations after remap/invalidation. The `tlb_perfpages_bench.c` skips addresses rather than creating actual holes.
- Existing logs report fewer walks for NaiveFP on some patterns, but this demonstrates only a metric change in those configurations, not correctness or general performance improvement. For example, the conflict workload’s SA counts differ substantially from FA, illustrating that indexing/associativity itself needs targeted conflict tests.

**Evidence:** [sweep build and result rows](gem5/results_v2/sweep_log.txt#L1), [summary table](gem5/results_v2/sweep_log.txt#L117), [value-only correctness checks](gem5/tlb_correctness_bench.c#L10), [prefetch-only walk-count evidence](gem5/results_v2/sweep_log.txt#L50).

## Recommended next validation matrix

These checks define the remaining correctness matrix. The bounded smoke runs cover only basic single-core, multi-core, and SMT process execution; tests requiring policy observability or the user’s detailed specs remain pending:

1. **Policy invariants:** Deterministic accesses beyond L1 and L2 capacity; assert inclusion after every operation for inclusive, no duplicate residency for exclusive, and permitted independent residency for NINE. Include associativity-conflict and replacement-order cases.
2. **Translation correctness:** Same VA with different PIDs/PCIDs and different physical mappings; switch CR3; test INVLPG/demap, non-global/global flushes, remap, permission changes, and page faults.
3. **Concurrency/topology:** One core/one thread, multiple cores, SMT/multiple thread contexts, and multiple processes; include same-VA collisions, CPU migration, and shootdown/invalidation behavior.
4. **Page sizes and protection:** 4 KiB, 2 MiB, and supported larger pages; boundary-crossing accesses; read/write/execute and user/supervisor permission checks.
5. **Perforated Pages:** Explicit valid/empty/mixed bitmap regions; accesses both to valid subpages and holes; expected fault on a hole; late map/unmap and permission updates; multiple address spaces; bitmap eviction and re-fill.
6. **Agile-TLB-style prefetch:** Demand-only versus prefetching baselines; vary degree/target; test locality, sparse neighbors, boundary cases, and pollution; measure accuracy, usefulness, timeliness, walks, latency/cycles, and modeled traffic.
7. **Lifecycle:** Checkpoint/restore and CPU takeover with populated L1/L2 state; verify policy and mapping invariants before and after restore.

## Bottom line

The current state is **not validated for all requested workflows**, and static review reveals correctness risks that should be resolved before trusting multiprocess or remapping workloads. The highest-priority items are (1) L2 invalidation on demap and CR3/non-global flush in the active source and affected snapshots, (2) reliable process/PCID tags and ASID-aware removal, (3) invariant checks for the Mid Review's SA Exclusive path (which removes L2 copies on normal promotion but does not clear L2 on demap/flush), and (4) wiring and validating the intended Perforated Pages implementation. Once the specifications are available, the matrix above can be narrowed to the exact required workflows.

## Verification run log

- Native compile command (both with `gcc -D_POSIX_C_SOURCE=200112L -O2 -Wall -Wextra -Werror`): `tlb_correctness_bench.c` and `tlb_perfpages_bench.c` **PASS**.
- Native correctness benchmark output: all four ordinary memory checks pass, including the claimed L1/L2 overflow and “hole pattern.” This is only a host-process smoke test: it runs against the host OS/hardware TLB, not gem5’s modified TLB; the checks test data integrity and do not establish TLB policy behavior.
- Native Perforated Pages benchmark output: `regions=16 valid_pages=6144 passes=5 sum=506880` **PASS**. It skips unaccessed addresses, so this does not test actual page holes or their fault behavior.
- First gem5 build attempt used the default Python 3.13/GCC 15.2 environment and **FAILED during Python embed/configure validation**. gem5 warned GCC 15 is unsupported; no simulator build result came from this attempt.
- The multi-context benchmark at [tlb_multicontext_bench.c](gem5/tlb_multicontext_bench.c) **PASSes** native compilation with `-Wall -Wextra -Werror`, both seeds at 768 pages × 4 bounded passes, and invalid-seed rejection. This checks benchmark behavior only; it is not simulator evidence.
- The active `src/arch/x86/tlb.cc` object **compiled successfully** with GCC 11/Python 3.10.
- Full x86 build in the workspace used 4.8 GiB before failing on the account’s disk quota; the partial tree created by that attempt was removed. A separate full build in `/tmp/tlb-verification/build/X86` first compiled all objects but failed at final linking because `grpc_cpp_plugin` was found while the gRPC development linker setup was unavailable. Retrying with a system-only `PATH` hid that optional plugin; the full `gem5.opt` link then **PASSed** (gem5 25.1.0.1). No packages were installed.
- The full x86 gem5 simulator ran the benchmark successfully in three configurations: one `AtomicSimpleCPU`/one process (seed 1); two `AtomicSimpleCPU`s/two processes (seeds 1 and 2); and one `DerivO3CPU` with SMT/two process contexts (seeds 1 and 2). Each process used 768 pages and four deterministic passes; all emitted `PASS`. The two-context configurations reported the same virtual base, but this remains a bounded smoke test, not a proof of address-space isolation or broad concurrency correctness. The first SMT configuration attempt omitted the caches required by `DerivO3CPU` and failed during configuration; the rerun with `--caches` passed.
- gem5 SE emitted expected environment/configuration warnings (deprecated `se.py`, DRAM capacity mismatch, and unsupported/unneeded optional integrations). These did not prevent the three simulations. The generated simulator, run directories, and scratch build are temporary validation artifacts and are removed after recording results; the benchmark source and this report remain.
- Initial attempts also exposed tracked build helper scripts without execute bits. Temporary permission changes were restored to `0644`; no implementation files were edited.

## Expanded Mid Review verification campaign

This campaign expands coverage beyond the earlier smoke tests. It is finite and deterministic, not literally exhaustive over all addresses, schedules, or machine states. Each run is bounded by the stated page/pass/access counts; fixed seeds and expected output checks make the workload reproducible. **A passing data-integrity benchmark is not, by itself, proof of TLB invariants.** Policy claims require the corresponding gem5 counters/debug evidence; unsupported behavior is marked blocked rather than inferred.

The Mid Review's implemented architectures, excluding standalone CoLT as requested, are the XOR-7 set-associative L2 and its Inclusive/NINE/Exclusive policies; Sequential Prefetching (SP); Naive Free Prefetching (NaiveFP); the Perforated Pages coarse-filter version; its decoupled bitmap-cache version; and the Grand Hybrid. Grand Hybrid's combined CoLT path is exercised only as an interacting component of that composite, not as a standalone CoLT study. Trail, Revelator, SnakeByte, STAR, and Marching Page Walks appear only as future-work surveys; no corresponding implementation is present to execute.

### A. XOR-7 indexing and inclusion-policy triplet

Run each case against Inclusive, NINE, and Exclusive snapshots independently; retain the exact binary/source pair and parse identical stats for comparisons.

1. Cold fill and repeated-read steady state (1 and 200 pages, four passes).
2. L1 capacity edge (63, 64, and 65 distinct pages).
3. Nominal L2 capacity edge (511, 512, and 513 pages).
4. Set-spread control (80 pages selected for distinct sets).
5. Same-set conflict (80 pages sharing one XOR-7 set, 4-way L2).
6. Overflow with an interleaved hot translation (600 pages plus hot page).
7. Deterministic random read stream over 1,024 pages, multiple fixed seeds.
8. Reversed order and page strides 1, 2, 4, 8, including aligned-boundary crossings.
9. Same virtual address in distinct processes: one core/context switching, two cores, and SMT.
10. Semantic faults/lifecycle: actual hole, same-VA remap, read-only permission, global/non-global flush, and checkpoint/restore where supported.

### B. Agile-style Sequential Prefetching (SP)

1. Demand-only NINE baseline.
2. Fixed successor degree 1 page (the archived SP implementation).
3. Ascending contiguous stream.
4. Descending contiguous stream.
5. Strides 2, 4, and 8 pages.
6. Accesses at both sides of each 8-page/32-KiB alignment boundary.
7. Sparse mapped neighbors and genuine unmapped neighbors.
8. Random stream and same-set pressure to measure pollution as well as misses.
9. Working sets below, at, and above L2 capacity with warm/repeated phases.
10. Same-VA multi-process and permission/remap cases to detect speculative cross-context or stale entries.

### C. Agile-style NaiveFP and fetch-degree experiments

1. Demand-only baseline.
2. One 64-byte PTE cache line (8 neighboring 4-KiB translations; archived NaiveFP).
3. Two-line/16-page fixed degree.
4. Four-line/32-page fixed degree.
5. Eight-line/64-page fixed degree.
6. Adaptive 1→2→4→8-line growth on confirmed consecutive demand, with reset on a mismatch.
7. Ascending, descending, and strides 1, 2, 4, and 8 pages.
8. Demand positions 0–7 within a line and line/block-boundary crossings.
9. Partial mappings, holes, and non-present neighbors.
10. Random/irregular streams, capacity/conflict pollution, and same-VA multi-process checks.

The multi-line and adaptive policies are **experimental scratch variants**, not features already implemented in the repository. Their results must not be attributed to the archived one-line NaiveFP implementation.

### D. Perforated Pages coarse-filter snapshot

1. Fully populated 2-MiB region (all eight chunks clean).
2. Empty region and expected fault on access.
3. One valid 4-KiB subpage per 64-page chunk.
4. One hole per chunk, otherwise populated.
5. Holes at subpage indices 0, 31, 32, 63, 64, 127, 448, and 511.
6. Clustered holes and clean/empty chunk transitions.
7. Dispersed holes (for example every fourth page).
8. Several 2-MiB regions with repeated alternating accesses.
9. More than four colliding 2-MiB regions to exercise set replacement.
10. Same-VA contexts, remap, read/write/execute protection, flush, and checkpoint/restore.

### E. Perforated Pages decoupled-bitmap snapshot

1. Dense/clean-chunk path.
2. Empty-chunk early reject and expected fault.
3. Holey-chunk bitmap miss followed by same-chunk repeat.
4. Alternating sub-bitmap chunks to test bitmap-cache reuse.
5. More distinct bitmap chunks than the set can retain.
6. Translation/bitmap same-set conflict and translation-eviction accounting.
7. Clustered versus dispersed masks at equal valid-page count.
8. Bitmap-word correctness at bit positions 0, 31, and chunk boundaries.
9. Refill after translation/bitmap eviction and after a region changes.
10. Address-space isolation, permissions, remap, flush, and checkpoint/restore.

### F. Grand Hybrid (composite only; no standalone CoLT evaluation)

1. Ordinary 4-KiB random baseline.
2. Local 8-page access patterns through the hybrid's coalescing path.
3. Dense 2-MiB regions through the sparse-page path.
4. Clustered holes with local coalescing activity.
5. Dispersed holes with local coalescing activity.
6. Interleaved accesses that should hit the fine- and coarse-grained structures.
7. Boundaries between 4-KiB pages, 32-KiB spans, and 2-MiB regions.
8. Translation-set pressure and >4 colliding sparse regions.
9. Bitmap-cache pressure while fine-grained accesses remain hot.
10. Same-VA contexts, permissions, remap, invalidation, and lifecycle operations.

### G. Future-work architectures listed in the Mid Review

These are verification plans only; the repository contains no implementations to build or simulate.

- **Trail:** 1) cold correlation, 2) repeated delta, 3) alternating deltas, 4) random/no correlation, 5) confidence and wrong-prefetch rate, 6) page-table metadata validity, 7) ASID isolation, 8) prefetch pollution/latency.
- **Revelator:** 1) prediction accuracy, 2) address-region phase changes, 3) aliasing, 4) wrong prediction cancellation, 5) cache side-effect checks, 6) permission/fault handling, 7) L2-hit/miss overlap timing, 8) multicore isolation.
- **SnakeByte:** 1) contiguous runs of 2/4/8/16 pages, 2) irregular run lengths, 3) alignment boundaries, 4) fragmented physical frames, 5) merge/split churn, 6) permissions, 7) descriptor capacity/eviction, 8) process isolation.
- **STAR:** 1) shared PFN/different VAs, 2) same VA/different PFNs, 3) differing permissions on shared data, 4) copy-on-write transition, 5) permission revocation, 6) multicore sharer pressure, 7) ASID reuse, 8) invalidation/checkpoint lifecycle.
- **Marching Page Walks:** 1) 1/2/4/8 simultaneous misses, 2) common versus divergent page-table prefixes, 3) walker-queue saturation, 4) duplicate virtual misses, 5) mixed page sizes, 6) faulting members in a batch, 7) cancellation/replay, 8) bounded memory traffic and latency.

### Campaign status

- [x] Add a deterministic multi-context benchmark (`tlb_multicontext_bench.c`); bounded gem5 smoke runs recorded above. Remaining campaign items superseded by the plan below.

## Inclusive L2 TLB robustness campaign (started 2026-11-12)

**Target:** the Mid Review's SA-Inclusive design (`src/arch/x86/tlb.cc.inclusive.sa` / `tlb.hh.inclusive.sa`), swapped into a separate gem5 copy for building.
**Workloads:** SPEC CPU2017 (from `spec2017.tar.xz`) plus targeted microbenchmarks.
**Running log:** every command, run status and result is appended to [`INCLUSIVE_TLB_RESULTS_LOG.md`](INCLUSIVE_TLB_RESULTS_LOG.md). This section holds the plan and the final summary.
**Execution:** all long jobs run in named tmux sessions (`tlbinc-*`) and log to files, so they survive the user logging out.

### Plan (revised from the earlier matrix; may change as results come in)

- [ ] **0. Setup.** Unpack SPEC into `/tmp/sahilag24/spec2017` and install it. Make a gem5 working copy with the inclusive-SA snapshot as the active `tlb.cc`/`tlb.hh`. Build `gem5.opt` with GCC 11, Python 3.10 and the gold linker.
- [ ] **1. Invariant instrumentation.** Add a debug-only inclusion check: every valid L1 entry must also be in L2, checked after insert, evict, flush and demap. A violation aborts the run with a message, so passing runs actually show the invariant held.
- [ ] **2. Targeted correctness microbenchmarks** (SE mode, then FS mode):
  - Capacity edges (L1 63/64/65 entries, L2 511/512/513).
  - Same-set conflicts to force back-invalidation.
  - Same virtual address mapped to different physical pages in different processes.
  - Remap after `munmap`/`mmap`, `mprotect` permission changes, and genuine page faults.
- [ ] **3. Topology matrix.** Each topology runs on SPEC and on the microbenchmarks:
  - (a) 1 core, 1 process, 1 thread.
  - (b) N cores running different SPEC programs (multi-programmed).
  - (c) N processes time-shared on one core (context switches and CR3 flushes; FS mode).
  - (d) SMT core with 2 hardware threads.
  - (e) Multi-threaded OpenMP SPECspeed programs (pthreads/clone) across cores.
- [ ] **4. Interrupt and lifecycle survival** (FS mode, Linux guest):
  - Timer interrupts and preemption.
  - Cross-core TLB shootdown IPIs (`munmap` and `mprotect` in a multi-threaded process).
  - Process migration between CPUs.
  - Checkpoint and restore, plus CPU switch (Atomic to O3).
- [ ] **5. SPEC CPU2017 sweep.** Statically linked builds. Each benchmark fast-forwards, then runs a detailed window. Compare against the stock gem5 TLB for output correctness, simulator crashes or asserts, and TLB statistics.
- [ ] **6. Verdict.** Record every pass and fail with its evidence. Fix and re-test any failures only if the user approves.

### Results summary

_Pending. See the running log._

