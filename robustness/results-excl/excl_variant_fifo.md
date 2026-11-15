# excl_variant_fifo

Generated 2026-11-13 19:42:43. Raw outputs: `/tmp/sahilag24/work-excl/runs/excl_variant_fifo/`

| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| fifo-capacity_513_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 858612 | 0 | 0 |  |
| fifo-capacity_513_4 | inc | **PASS** | 1 | 1/0/0 | 23494 | 0 | 25242 | 0 | 858612 | 0 | 0 |  |
| fifo-conflict_200_4 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 572144 | 0 | 0 |  |
| fifo-conflict_200_4 | inc | **PASS** | 0 | 1/0/0 | 27 | 0 | 6167 | 0 | 572144 | 0 | 0 |  |
| fifo-remap_20_96 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 180489 | 0 | 0 |  |
| fifo-remap_20_96 | inc | **PASS** | 0 | 1/0/0 | 3764 | 0 | 6803 | 0 | 180489 | 0 | 0 |  |

## Per-test RESULT lines

- base/fifo-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- inc/fifo-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- base/fifo-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- inc/fifo-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- base/fifo-remap_20_96: `remap PASS rounds=20 pages=96`
- inc/fifo-remap_20_96: `remap PASS rounds=20 pages=96`
