# excl_variant_no_spill

Generated 2026-11-13 19:42:47. Raw outputs: `/tmp/sahilag24/work-excl/runs/excl_variant_no_spill/`

| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| no_spill-capacity_513_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 858612 | 0 | 0 |  |
| no_spill-capacity_513_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 48736 | 0 | 858612 | 0 | 0 |  |
| no_spill-conflict_200_4 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 572144 | 0 | 0 |  |
| no_spill-conflict_200_4 | inc | **PASS** | 0 | 1/0/0 | 0 | 0 | 6194 | 0 | 572144 | 0 | 0 |  |
| no_spill-remap_20_96 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 180489 | 0 | 0 |  |
| no_spill-remap_20_96 | inc | **PASS** | 0 | 1/0/0 | 0 | 0 | 10567 | 0 | 180489 | 0 | 0 |  |

## Per-test RESULT lines

- base/no_spill-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- inc/no_spill-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- base/no_spill-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- inc/no_spill-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- base/no_spill-remap_20_96: `remap PASS rounds=20 pages=96`
- inc/no_spill-remap_20_96: `remap PASS rounds=20 pages=96`
