# CS622 Project Artifact: L2 TLB Support for Sparse Huge Pages

This artifact contains six L2 TLB designs for the x86 TLB of gem5 25.1.0.1, the
scripts that build them, the benchmarks and configurations used to test them in
syscall-emulation (SE) and full-system (FS) mode, the automation that runs the
experiments, parses the output and draws the plots, and all results used in
`project_report.pdf`.

Designs: **Inclusive, Exclusive, NINE, Agile/NaiveFP prefetching, Perforated
Pages, CoLT-FA** (plus a strict variant of Perforated Pages). The mid-review
snapshots (set-associative policies, SP, NaiveFP, CoLT-FA, Perforated Pages,
Hybrid) are included for reference.

---

## 1. Artifact directory structure

```
<group>/
  declaration.txt            group, members, contribution, declaration
  project_report.pdf         final report (Part I: up to mid-review, Part II: after, Appendix A: artifact)
  README.md                  this file
  report_source/             LaTeX source and figures of the report (compiles on Overleaf)
  artifact/
    gem5_patches/            simulator source modifications
      tlb.{cc,hh}.<d>.fixed    d = inc | excl | nine | agile | perf | colt  (final designs)
      tlb.{cc,hh}.perf.strict  Perforated Pages with the PERF_STRICT option
      pagetable_walker.cc.colt page walker with the CoLT coalescing hook (colt only)
      make_colt_fixed.py       generates the three colt files from nine.fixed + stock walker
      make_perf_strict.py      generates the perf.strict files from perf.fixed
      apply_checker*.py        add the translation oracle and invariant checkers to a tree
      *_fixed.diff             patches of each .fixed file against its mid-review snapshot
      midreview/               mid-review snapshots (sa policies, sp, naivefp, colt_fa, item2/3, hybrid)
    benchmarks/
      tests/                   tlbstress.c, pf_patterns.c, perf_holes.c, gups.c (correctness/stress)
      microbench/              mid-review microbenchmarks (tlb_colt_bench.c, tlb_perfpages_bench.c, ...)
      stdbench/                drivers: run_memcached.sh, run_redis.sh, mc-crusher configs
      spec/spec-gem5-static.cfg SPEC CPU2017 config used to build static binaries
    configs/fs_run.py        gem5 full-system configuration (X86Board, windows, hypercalls)
    scripts/                 build, run, collect and plot automation (table in Section 6)
    results/                 every result used in the report
      windows.csv            one row per timing window (554 rows)
      spec_fs_matrix.csv     SPEC CPU2017 FS pass/fail per design (238 verdicts)
      se_bigmem.csv          SE 8 GiB results for 631.deepsjeng_s and 619.lbm_s
      colt_se_verification.csv  CoLT-FA SE checks (36 runs)
      figures/*.png, figures/numbers.txt   plots and the exact numbers they show
      design_reports/        audit and per-design fix/verification reports (SE mode)
```

## 2. Features and test scenarios

All designs are selected at build time (`build_design.sh`); their parameters are
read from environment variables at run time, so one binary covers a parameter sweep.

| Feature | What it means | Test scenario (parameters) | Script | Expected outcome |
|---|---|---|---|---|
| F1 Correct L2 invalidation | L2 entry removed on unmap (`demapPage`), non-global entries removed on CR3 switch (`flushNonGlobal`) | FS SPEC CPU2017 (Linux unmaps and switches constantly); SE `tlbstress remap 20 96` | `run_spec_fs_shards.sh`, `quick_start.sh` | SPEC output check passes; oracle mismatches 0 |
| F2 PCID-aware L2 | entries tagged with PCID, removal uses (va, pcid) | SE multi-process matrix; FS runs | `gen_se_jobs.py` + `runner.py` | 0 oracle mismatches |
| F3 L2 checkpointing | L2 saved/restored (perf: cleared on restore) | SE checkpoint/restore of a capacity run | see design reports | restore succeeds, 0 mismatches |
| F4 Runtime parameters | L2 sets/ways/hash/replacement, L1 size, policy knobs via env vars | e.g. `NINE_L2_SETS=256`, `EXCL_SPILL=never`, `AGILE_PF_DEGREE=8`, `COLT_FA_ENTRIES=32`, `PERF_STRICT=1` | env vars on any run | statistics change, correctness unchanged |
| F5 Translation oracle | every translation compared with the true page table (SE: all, FS: every 64th) | `TLBCHK_FS_PERIOD`, `TLBCHK_MAXWARN`, `TLBCHK_PANIC` | `apply_checker*.py`, `build_design.sh --checker` | `chkOracleMismatch = 0` |
| F6 Exclusivity / inclusion / staleness checks | duplicates (excl), missing L2 copy (inc), stale entries after flush (nine, colt) | SE matrix | `apply_checker*.py` | violation counters 0 |
| F7 CoLT-FA in FS | coalescing from the page walker (8 PTEs of the leaf's cache line), PCID-tagged 8-entry buffer | `COLT_ENABLE=1/0`, `COLT_FA_ENTRIES=8/32`, THP on/off | `run_stdbench_fs3.sh`, `quick_start.sh` | coltHits > 0 only when enabled; fewer walks on graph workloads |
| F8 Perforated strict mode | a page joins a 2MB region only if physically contiguous with it | `PERF_STRICT=1` | `run_stdbench_fs3.sh` | `perfStrictRebases` > 0 |
| F9 Measurement windows | atomic CPU everywhere, timing CPU for a window of N instructions after W of warm-up | `WINDOW_WARM`, `WINDOW_INSTS`, `WINDOW_EXIT` | `run_spec_fs_shards.sh` | stats dumped once per benchmark, `TLBFS-WINDOW ... dumped` in simout |

### Findings while executing the tests (crashes, failures)

| Finding | Where | Frequency | Cause |
|---|---|---|---|
| 500.perlbench_r and 600.perlbench_s FAIL | FS, every design | always | gem5 x87 floating-point emulation bug (long double formatting); both pass natively with the same setup, and still fail with the window wrapper removed |
| 631.deepsjeng_s FAIL | FS, every design | always | needs 6.9 GB, X86Board guest limited to 3 GiB. PASSES in SE with 8 GiB on all designs |
| 619.lbm_s: gem5 assertion `Packet::setCacheResponding(): !flags.isSet(CACHE_RESPONDING)` | FS, every design | always, right after its window when switching timing -> atomic | 3.2 GB working set over the 3 GiB guest; window stats saved. PASSES in SE with 8 GiB on all designs |
| 525.x264_r, 625.x264_s no result | FS | always | ~1 trillion instructions; window stats only |
| 627.cam4_s fails natively | native | always | SPEC build issue; passes in gem5 |
| Redis runs make no progress in the guest | FS | first attempt, all configs | under investigation (driver now time-limited with progress markers) |
| SE matrix failures (setitimer, fork + MAP_SHARED timeout, multi-process remap STALE) | SE | always | identical on stock gem5 (SE-mode limits) |

## 3. Assumptions and unsupported features

- gem5 **25.1.0.1**, x86, gcc-11/g++-11, Python 3.10, scons 4.8.1.
- Full-system runs need: the gem5 resources Linux kernel `vmlinux-x86-ubuntu-6.8.0-52-generic` and disk `x86-ubuntu-24.04.img`, and a SPEC CPU2017 installation (licensed, not included) built with `benchmarks/spec/spec-gem5-static.cfg`.
- Single simulated core; X86Board guest memory at most 3 GiB.
- No KVM was available to us (boot on the atomic CPU, about 1.5 to 2.5 hours per boot); with KVM pass `--start-cpu kvm` (automatic when `/dev/kvm` is usable).
- CoLT-FA does not compare accessed/dirty bits when forming a run (gem5's walker never sets the dirty bit).
- Perforated Pages as built stores one physical address per 4KB page of a region (see report Section "A Second Look at Perforated Pages"); `PERF_STRICT=1` enforces physical contiguity.
- The Hybrid L2 TLB of the mid-review is provided as a snapshot only, not as a fixed design.
- `env.sh` expects the scripts at `$HOME/CS622_L2_TLB/robustness/scripts` and lane workspaces under `/tmp/$USER/work-<design>`; `provision_fs_host.sh` creates that layout.

## 4. Getting started (about 30 minutes with a built gem5 tree)

| Step | Command | Human time | Compute time |
|---|---|---|---|
| 1. Get gem5 25.1.0.1 | `git clone https://github.com/gem5/gem5 -b v25.1.0.1` | 2 min | 5 min |
| 2. Merge CoLT-FA + checker and build | `bash artifact/scripts/build_design.sh <gem5> colt --checker -j 16` | 1 min | 1 to 2 h from a clean tree; 6 min on a previously built tree (measured, 28 jobs) |
| 3. Quick functional check | `bash artifact/scripts/quick_start.sh <gem5>` | 1 min | under 1 min (measured 5 s) |
| 4. Re-draw all plots from the included results | `python3 artifact/scripts/plot_results.py artifact/results /tmp/fig` | 1 min | 10 s |

Expected output of step 3 (our test run on a stock gem5 25.1.0.1 tree):

```
ascending_16MB  colt=1  RESULT pf_asc PASS  oracleMismatch=0  coltHits=14330  walks=10329
ascending_16MB  colt=0  RESULT pf_asc PASS  oracleMismatch=0  coltHits=0      walks=24659
colt_bench      colt=0                      oracleMismatch=0  coltHits=0      walks=14328
```
Every line must show `oracleMismatch=0`; with `colt=1` there are CoLT hits and fewer walks.

**Your own input:** any static x86-64 Linux binary can be used:
`QS_PROG=/path/to/prog QS_ARGS="arg1 arg2" bash artifact/scripts/quick_start.sh <gem5>`.
Any other design: `build_design.sh <gem5> <inc|excl|nine|agile|perf|perfstrict|colt> [--checker]`.

## 5. Detailed evaluation

| # | Experiment | Purpose | How to run | Estimated runtime | Expected result | Where the result is |
|---|---|---|---|---|---|---|
| E1 | SE correctness matrix | oracle and invariants on every design vs stock | `VARIANT=<d> source scripts/env.sh; python3 scripts/gen_se_jobs.py; python3 scripts/runner.py $W/jobs/se_matrix.json --jobs 24` | 3 to 6 h on 24 cores per design | 0 oracle mismatches; failures identical on stock | `results/design_reports/*`, runner output |
| E2 | CoLT-FA SE checks | CoLT on/off, Atomic/Timing, 9 programs | `quick_start.sh` (subset) or loop in report Sec. CoLT | 10 min | 36/36 pass, 0 mismatches | `results/colt_se_verification.csv` |
| E3 | SPEC CPU2017 FS, test inputs | correctness of every design under Linux | `TLB_USER=$USER WINDOW_INSTS=200000000 WINDOW_WARM=50000000 bash scripts/run_spec_fs_shards.sh <d> 43 atomic` | about 2 h boot + 8 h SPEC setup + 0.31 h per G instructions; 1 to 3 days for the long benchmarks | 37/43 PASS per design (report Table) | `<run>/s*/board.pc.com_1.device` (SPEC_RESULT lines), `results/spec_fs_matrix.csv` |
| E4 | SE 8 GiB big benchmarks | deepsjeng_s, lbm_s on every design | `bash scripts/se_bigmem.sh 631.deepsjeng_s inc excl nine agile perf colt` (and 619.lbm_s) | 6 to 16 h | PASS on all 6 | `results/se_bigmem.csv` |
| E5 | TLB-intensive workloads | GAPBS, XSBench, STREAM, memcached per design, THP on/off | `bash scripts/build_stdbench.sh; TLB_USER=$USER [THP=never] [COLT_ENABLE=0] STD_TAG=<t> bash scripts/run_stdbench_fs3.sh <d>` (`BENCH_LIST` selects programs) | about 2.5 h boot + 1 to 4 h window | report Tables (CoLT vs NINE, all designs) | `/tmp/$USER/std/LATEST_<d>_<t>`, `results/windows.csv` |
| E6 | SPEC reference windows | real input sizes | `SPEC_FS_SIZE=ref WINDOW_WARM=3000000000 WINDOW_INSTS=200000000 WINDOW_EXIT=1 bash scripts/run_spec_fs_shards.sh <d> 9 atomic <benches>` | about 5 h | report Table (ref) | `results/windows.csv` (kind=ref) |
| E7 | Perforated strict | realistic Perforated Pages | build `perfstrict`, run E5/E6 with `PERF_STRICT=1` | as E5/E6 | report Table (strict) | `results/windows.csv` (lane=perfstrict) |
| E8 | Collect and plot | build all tables and figures | `python3 scripts/collect_results.py <mirror> out; python3 scripts/plot_results.py out out/figures` | 1 min | figures in report | `out/*.csv`, `out/figures/` |

To spread many runs over machines, `provision_fs_host.sh <design> <source_host>`
copies one design's inputs to a fresh machine, and `sync_fs_results.sh` copies all
results back every 30 minutes into a mirror that `collect_results.py` reads.

## 6. Script reference

| Script | Role |
|---|---|
| `build_design.sh` | merge a design (+ optional checker) into a gem5 tree and build |
| `quick_start.sh` | 5-minute SE check, also runs your own program |
| `build_microbench.sh`, `build_stdbench.sh` | build the test programs and the standard workloads |
| `fs_run.py` | gem5 FS configuration (boot, hypercalls 10/11/12, windows, `--window-exit`) |
| `gen_spec_fs_guest.py` | guest script that runs SPEC benchmarks and prints SPEC_RESULT / SPEC_DIAG |
| `run_spec_fs_shards.sh` | one gem5 per benchmark, FS SPEC runs |
| `run_stdbench_fs3.sh`, `run_micro_fs.sh` | FS runs of the standard workloads / microbenchmarks |
| `se_bigmem.sh` | SE 8 GiB runs with byte-by-byte output check |
| `gen_se_jobs.py`, `gen_spec_jobs.py`, `runner.py` | SE job matrix and runner |
| `provision_fs_host.sh`, `sync_fs_results.sh`, `env.sh` | multi-machine setup and result collection |
| `collect_results.py`, `plot_results.py`, `win_table.sh`, `parse_fs_windows.py` | parse output, build CSVs and plots |
