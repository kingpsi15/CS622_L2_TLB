# excl_variant_sets256

Generated 2026-11-13 19:42:38. Raw outputs: `/tmp/sahilag24/work-excl/runs/excl_variant_sets256/`

| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| sets256-capacity_513_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 858612 | 0 | 0 |  |
| sets256-capacity_513_4 | inc | **PASS** | 1 | 1/0/0 | 23825 | 0 | 24911 | 0 | 858612 | 0 | 0 |  |
| sets256-conflict_200_4 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 572144 | 0 | 0 |  |
| sets256-conflict_200_4 | inc | **PASS** | 0 | 1/0/0 | 2868 | 0 | 3326 | 0 | 572144 | 0 | 0 |  |
| sets256-remap_20_96 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 180489 | 0 | 0 |  |
| sets256-remap_20_96 | inc | **PASS** | 0 | 1/0/0 | 3764 | 0 | 6803 | 0 | 180489 | 0 | 0 |  |

## Per-test RESULT lines

- base/sets256-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- inc/sets256-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- base/sets256-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- inc/sets256-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- base/sets256-remap_20_96: `remap PASS rounds=20 pages=96`
- inc/sets256-remap_20_96: `remap PASS rounds=20 pages=96`
