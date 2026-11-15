# excl_variant_l1_32

Generated 2026-11-13 19:42:49. Raw outputs: `/tmp/sahilag24/work-excl/runs/excl_variant_l1_32/`

| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| l1_32-capacity_513_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 858612 | 0 | 0 |  |
| l1_32-capacity_513_4 | inc | **PASS** | 1 | 1/0/0 | 23782 | 0 | 25720 | 0 | 858612 | 0 | 0 |  |
| l1_32-conflict_200_4 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 572144 | 0 | 0 |  |
| l1_32-conflict_200_4 | inc | **PASS** | 0 | 1/0/0 | 39 | 0 | 6511 | 0 | 572144 | 0 | 0 |  |
| l1_32-remap_20_96 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 180489 | 0 | 0 |  |
| l1_32-remap_20_96 | inc | **PASS** | 0 | 1/0/0 | 3766 | 0 | 7501 | 0 | 180489 | 0 | 0 |  |

## Per-test RESULT lines

- base/l1_32-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- inc/l1_32-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- base/l1_32-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- inc/l1_32-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- base/l1_32-remap_20_96: `remap PASS rounds=20 pages=96`
- inc/l1_32-remap_20_96: `remap PASS rounds=20 pages=96`
