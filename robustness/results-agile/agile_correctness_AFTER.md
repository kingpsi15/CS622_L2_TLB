# agile_correctness_AFTER

Generated 2026-11-12 23:10:16. Raw outputs: `/tmp/sahilag24/work-agile/runs/agile_correctness_AFTER/`

| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| agile-huge-atomic | base | **PASS** | 0 | 0/0/1 | 0 | 0 | 0 | 0 | 127285 | 0 | 0 |  |
| agile-huge-atomic | inc | **PASS** | 0 | 0/0/1 | 0 | 0 | 0 | 0 | 127285 | 0 | 0 |  |
| agile-huge-timing | base | **PASS** | 0 | 0/0/1 | 0 | 0 | 0 | 0 | 127285 | 0 | 0 |  |
| agile-huge-timing | inc | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 127285 | 0 | 0 |  |
| agile-procs-atomic | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 490232 | 0 | 0 |  |
| agile-procs-atomic | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 490232 | 0 | 0 |  |
| agile-procs-timing | base | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 490232 | 0 | 0 |  |
| agile-procs-timing | inc | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 490232 | 0 | 0 |  |
| agile-remap-atomic | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 258923 | 0 | 0 |  |
| agile-remap-atomic | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 258923 | 0 | 0 |  |
| agile-remap-big-atomic | base | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 2516880 | 0 | 0 |  |
| agile-remap-big-atomic | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 2516880 | 0 | 0 |  |
| agile-remap-big-timing | base | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 2516880 | 0 | 0 |  |
| agile-remap-big-timing | inc | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 2516880 | 0 | 0 |  |
| agile-remap-timing | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 258923 | 0 | 0 |  |
| agile-remap-timing | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 258923 | 0 | 0 |  |
| agile-shared-atomic | base | **FAIL** | 106 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=-15; only 0/1 test RESULT lines (guest/workload did not finish) |
| agile-shared-atomic | inc | **FAIL** | 106 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=-15; only 0/1 test RESULT lines (guest/workload did not finish) |
| agile-shared-timing | base | **FAIL** | 104 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=-15; only 0/1 test RESULT lines (guest/workload did not finish) |
| agile-shared-timing | inc | **FAIL** | 105 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=-15; only 0/1 test RESULT lines (guest/workload did not finish) |
| agile-shootdown-atomic | base | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 23163 | 0 | 0 |  |
| agile-shootdown-atomic | inc | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 23163 | 0 | 0 |  |
| agile-shootdown-timing | base | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 23163 | 0 | 0 |  |
| agile-shootdown-timing | inc | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 23163 | 0 | 0 |  |

## Per-test RESULT lines

- base/agile-huge-atomic: `huge SKIP mprotect not enforced (SE mode?)`
- inc/agile-huge-atomic: `huge SKIP mprotect not enforced (SE mode?)`
- base/agile-huge-timing: `huge SKIP mprotect not enforced (SE mode?)`
- inc/agile-huge-timing: `huge SKIP mprotect not enforced (SE mode?)`
- base/agile-procs-atomic: `procs PASS procs=4 rounds=10 same_va=0x600000000000 pages=160`
- inc/agile-procs-atomic: `procs PASS procs=4 rounds=10 same_va=0x600000000000 pages=160`
- base/agile-procs-timing: `procs PASS procs=4 rounds=10 same_va=0x600000000000 pages=160`
- inc/agile-procs-timing: `procs PASS procs=4 rounds=10 same_va=0x600000000000 pages=160`
- base/agile-remap-atomic: `remap PASS rounds=30 pages=96`
- inc/agile-remap-atomic: `remap PASS rounds=30 pages=96`
- base/agile-remap-big-atomic: `remap PASS rounds=60 pages=512`
- inc/agile-remap-big-atomic: `remap PASS rounds=60 pages=512`
- base/agile-remap-big-timing: `remap PASS rounds=60 pages=512`
- inc/agile-remap-big-timing: `remap PASS rounds=60 pages=512`
- base/agile-remap-timing: `remap PASS rounds=30 pages=96`
- inc/agile-remap-timing: `remap PASS rounds=30 pages=96`
- base/agile-shootdown-atomic: `shootdown SKIP mprotect not enforced (SE mode)`
- inc/agile-shootdown-atomic: `shootdown SKIP mprotect not enforced (SE mode)`
- base/agile-shootdown-timing: `shootdown SKIP mprotect not enforced (SE mode)`
- inc/agile-shootdown-timing: `shootdown SKIP mprotect not enforced (SE mode)`
