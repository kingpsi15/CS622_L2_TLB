# CS622_L2_TLB

L2 TLB support for sparse huge pages in gem5 25.1 (x86). Six L2 TLB designs
(Inclusive, Exclusive, NINE, Agile/NaiveFP prefetching, Perforated Pages,
CoLT-FA), checked against a translation oracle and evaluated in SE and
full-system mode on SPEC CPU2017, GAPBS, XSBench, STREAM, memcached and Redis.

Group: Aditya Sai Vemparala (240068), Sahil Agarwal (240902),
Abhinav Singh Baghel (261110004).

Final report: [`docs/project/CS622_Final_Report.pdf`](docs/project/CS622_Final_Report.pdf)

## Layout

| Path | What it holds |
|---|---|
| `report/` | LaTeX source of the final report (Part I mid-review, Part II results, Part III chronology, artifact appendix) and its figures |
| `gem5/` | The modified gem5 tree. Design sources are `src/arch/x86/tlb.{cc,hh}.<design>.fixed` |
| `robustness/` | Everything used to test and run the designs: `scripts/` (build, run, collect, plot), `patches/` (design generators, checkers), `tests/` (stress tests, benchmark drivers) |
| `results_final/` | Collected results as CSV, every report figure, and `numbers.txt` |
| `fullrun_campaign/` | The full-run SPEC campaign (five lanes, timing CPU end to end): launch and monitoring `scripts/`, `x87_tests/`, run `logs/`, `status/` snapshots and per-host `results/` |
| `docs/project/` | Final report PDF, mid-review document, project scope |
| `docs/ARTIFACT_README.md` | Artifact guide from the submission: features, test scenarios, getting started, detailed evaluation |
| `docs/design_reports/` | Per-design robustness reports and result logs, the implementation audit, background notes |
| `docs/papers/` | The CoLT (MICRO 2012) and Perforated Page (ISCA 2020) papers |

Not in git (see `.gitignore`): `fs_results/` (mirror of the lab runs),
`fs_assets_backup/` (built inputs), gem5 build output.

## Quick start

See `docs/ARTIFACT_README.md`. In short, with a gem5 25.1.0.1 checkout at `<gem5>`:

```bash
bash robustness/scripts/build_design.sh <gem5> colt --checker -j 16
bash robustness/scripts/quick_start.sh <gem5>
```
