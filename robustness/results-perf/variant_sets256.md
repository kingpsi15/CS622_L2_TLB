# variant_sets256

Generated 2026-11-13 08:58:28. Raw outputs: `/tmp/sahilag24/work-perf/runs/variant_sets256/`

| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| v-atomic-chunk1 | fixed | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 3111201 | 0 | 0 |  |
| v-atomic-churn | fixed | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 2291184 | 0 | 0 |  |
| v-atomic-clustered | fixed | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 2740552 | 0 | 0 |  |
| v-atomic-collide16 | fixed | **PASS** | 11 | 1/0/0 | 0 | 0 | 0 | 0 | 9174870 | 0 | 0 |  |
| v-atomic-collide48 | fixed | **PASS** | 21 | 1/0/0 | 0 | 0 | 0 | 0 | 18676973 | 0 | 0 |  |
| v-atomic-dense | fixed | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 2711688 | 0 | 0 |  |
| v-atomic-dispersed | fixed | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 2840244 | 0 | 0 |  |
| v-atomic-edge | fixed | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 2940212 | 0 | 0 |  |
| v-atomic-sparse | fixed | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 1563434 | 0 | 0 |  |
| v-atomic-tlbstress-capacity | fixed | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 651623 | 0 | 0 |  |
| v-atomic-tlbstress-conflict | fixed | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 264766 | 0 | 0 |  |
| v-atomic-tlbstress-remap | fixed | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 102054 | 0 | 0 |  |

## Per-test RESULT lines

- fixed/v-atomic-chunk1: `perf_chunk1 PASS regions=4 passes=4 holes=32 valid_reads=24396 remaps=32 late_unmaps=0`
- fixed/v-atomic-churn: `perf_churn PASS regions=4 passes=4 holes=410 valid_reads=19656 remaps=48 late_unmaps=48`
- fixed/v-atomic-clustered: `perf_clustered PASS regions=4 passes=4 holes=256 valid_reads=21720 remaps=48 late_unmaps=0`
- fixed/v-atomic-collide16: `perf_edge PASS regions=16 passes=3 holes=128 valid_reads=73008 remaps=128 late_unmaps=0`
- fixed/v-atomic-collide48: `perf_churn PASS regions=48 passes=2 holes=4915 valid_reads=117966 remaps=288 late_unmaps=288`
- fixed/v-atomic-dense: `perf_dense PASS regions=4 passes=4 holes=0 valid_reads=24576 remaps=0 late_unmaps=0`
- fixed/v-atomic-dispersed: `perf_dispersed PASS regions=4 passes=4 holes=256 valid_reads=21720 remaps=48 late_unmaps=0`
- fixed/v-atomic-edge: `perf_edge PASS regions=4 passes=4 holes=32 valid_reads=24396 remaps=32 late_unmaps=0`
- fixed/v-atomic-sparse: `perf_sparse PASS regions=4 passes=4 holes=2016 valid_reads=600 remaps=48 late_unmaps=0`
- fixed/v-atomic-tlbstress-capacity: `capacity PASS pages=513 passes=3 orders=6`
- fixed/v-atomic-tlbstress-conflict: `conflict PASS same-set pages=80 set=2 passes=6`
- fixed/v-atomic-tlbstress-remap: `remap PASS rounds=10 pages=96`
