# excl_variant_dirty_hot

Generated 2026-11-13 19:42:46. Raw outputs: `/tmp/sahilag24/work-excl/runs/excl_variant_dirty_hot/`

| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| dirty_hot-capacity_513_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 858612 | 0 | 0 |  |
| dirty_hot-capacity_513_4 | inc | **PASS** | 1 | 1/0/0 | 88 | 0 | 48648 | 0 | 858612 | 0 | 0 |  |
| dirty_hot-conflict_200_4 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 572144 | 0 | 0 |  |
| dirty_hot-conflict_200_4 | inc | **PASS** | 0 | 1/0/0 | 16 | 0 | 6178 | 0 | 572144 | 0 | 0 |  |
| dirty_hot-remap_20_96 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 180489 | 0 | 0 |  |
| dirty_hot-remap_20_96 | inc | **PASS** | 0 | 1/0/0 | 0 | 0 | 10567 | 0 | 180489 | 0 | 0 |  |

## Per-test RESULT lines

- base/dirty_hot-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- inc/dirty_hot-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- base/dirty_hot-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- inc/dirty_hot-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- base/dirty_hot-remap_20_96: `remap PASS rounds=20 pages=96`
- inc/dirty_hot-remap_20_96: `remap PASS rounds=20 pages=96`
