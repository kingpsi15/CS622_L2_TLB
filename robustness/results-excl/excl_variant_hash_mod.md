# excl_variant_hash_mod

Generated 2026-11-13 19:42:41. Raw outputs: `/tmp/sahilag24/work-excl/runs/excl_variant_hash_mod/`

| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| hash_mod-capacity_513_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 858612 | 0 | 0 |  |
| hash_mod-capacity_513_4 | inc | **PASS** | 1 | 1/0/0 | 23602 | 0 | 25134 | 0 | 858612 | 0 | 0 |  |
| hash_mod-conflict_200_4 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 572144 | 0 | 0 |  |
| hash_mod-conflict_200_4 | inc | **PASS** | 0 | 1/0/0 | 2868 | 0 | 3326 | 0 | 572144 | 0 | 0 |  |
| hash_mod-remap_20_96 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 180489 | 0 | 0 |  |
| hash_mod-remap_20_96 | inc | **PASS** | 0 | 1/0/0 | 3764 | 0 | 6803 | 0 | 180489 | 0 | 0 |  |

## Per-test RESULT lines

- base/hash_mod-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- inc/hash_mod-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- base/hash_mod-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- inc/hash_mod-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- base/hash_mod-remap_20_96: `remap PASS rounds=20 pages=96`
- inc/hash_mod-remap_20_96: `remap PASS rounds=20 pages=96`
