# excl_matrix

Generated 2026-11-13 12:45:22. Raw outputs: `/tmp/sahilag24/work-excl/runs/excl_matrix/`

| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| se-1c1p1t-atomic-capacity_2048_2 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 1700592 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_2048_2 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 1700592 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_511_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 855367 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_511_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 855367 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_512_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 856990 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_512_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 856990 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_513_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 858612 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_513_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 858612 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_63_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 127692 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_63_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 127692 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_64_4 | base | **PASS** | 0 | 1/0/0 | 0 | 0 | 0 | 0 | 129315 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_64_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 129315 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_65_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 130937 | 0 | 0 |  |
| se-1c1p1t-atomic-capacity_65_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 130937 | 0 | 0 |  |
| se-1c1p1t-atomic-conflict_200_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 572144 | 0 | 0 |  |
| se-1c1p1t-atomic-conflict_200_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 572144 | 0 | 0 |  |
| se-1c1p1t-atomic-conflict_80_10 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 310472 | 0 | 0 |  |
| se-1c1p1t-atomic-conflict_80_10 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 310472 | 0 | 0 |  |
| se-1c1p1t-atomic-huge_2 | base | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 127285 | 0 | 0 |  |
| se-1c1p1t-atomic-huge_2 | inc | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 127285 | 0 | 0 |  |
| se-1c1p1t-atomic-interrupts_4_200 | base | **FAIL** | 0 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=1; fatal: syscall setitimer (#38) unimplemented.; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-1c1p1t-atomic-interrupts_4_200 | inc | **FAIL** | 0 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=1; fatal: syscall setitimer (#38) unimplemented.; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-1c1p1t-atomic-protect_3 | base | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 25436 | 0 | 0 |  |
| se-1c1p1t-atomic-protect_3 | inc | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 25436 | 0 | 0 |  |
| se-1c1p1t-atomic-remap_20_96 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 180489 | 0 | 0 |  |
| se-1c1p1t-atomic-remap_20_96 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 180489 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_2048_2 | base | **PASS** | 11 | 1/0/0 | 0 | 0 | 0 | 0 | 278326 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_2048_2 | inc | **PASS** | 11 | 1/0/0 | 0 | 0 | 0 | 0 | 278326 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_511_4 | base | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 135178 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_511_4 | inc | **PASS** | 6 | 1/0/0 | 0 | 0 | 0 | 0 | 135178 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_512_4 | base | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 136041 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_512_4 | inc | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 136041 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_513_4 | base | **PASS** | 6 | 1/0/0 | 0 | 0 | 0 | 0 | 135626 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_513_4 | inc | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 135626 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_63_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 27802 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_63_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 27802 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_64_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 27615 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_64_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 27615 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_65_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 27781 | 0 | 0 |  |
| se-1c1p1t-o3-capacity_65_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 27781 | 0 | 0 |  |
| se-1c1p1t-o3-conflict_200_4 | base | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 32113 | 0 | 0 |  |
| se-1c1p1t-o3-conflict_200_4 | inc | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 32113 | 0 | 0 |  |
| se-1c1p1t-o3-conflict_80_10 | base | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 28954 | 0 | 0 |  |
| se-1c1p1t-o3-conflict_80_10 | inc | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 28954 | 0 | 0 |  |
| se-1c1p1t-o3-huge_2 | base | **PASS** | 3 | 0/0/1 | 0 | 0 | 0 | 0 | 60963 | 0 | 0 |  |
| se-1c1p1t-o3-huge_2 | inc | **PASS** | 3 | 0/0/1 | 0 | 0 | 0 | 0 | 60963 | 0 | 0 |  |
| se-1c1p1t-o3-interrupts_4_200 | base | **FAIL** | 1 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=1; fatal: syscall setitimer (#38) unimplemented.; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-1c1p1t-o3-interrupts_4_200 | inc | **FAIL** | 1 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=1; fatal: syscall setitimer (#38) unimplemented.; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-1c1p1t-o3-protect_3 | base | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 13008 | 0 | 0 |  |
| se-1c1p1t-o3-protect_3 | inc | **PASS** | 2 | 0/0/1 | 0 | 0 | 0 | 0 | 13008 | 0 | 0 |  |
| se-1c1p1t-o3-remap_20_96 | base | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 171844 | 0 | 0 |  |
| se-1c1p1t-o3-remap_20_96 | inc | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 171844 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_2048_2 | base | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 1700592 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_2048_2 | inc | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 1700592 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_511_4 | base | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 855367 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_511_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 855367 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_512_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 856990 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_512_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 856990 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_513_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 858612 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_513_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 858612 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_63_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 127692 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_63_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 127692 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_64_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 129315 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_64_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 129315 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_65_4 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 130937 | 0 | 0 |  |
| se-1c1p1t-timing-capacity_65_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 130937 | 0 | 0 |  |
| se-1c1p1t-timing-conflict_200_4 | base | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 572144 | 0 | 0 |  |
| se-1c1p1t-timing-conflict_200_4 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 572144 | 0 | 0 |  |
| se-1c1p1t-timing-conflict_80_10 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 310472 | 0 | 0 |  |
| se-1c1p1t-timing-conflict_80_10 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 310472 | 0 | 0 |  |
| se-1c1p1t-timing-huge_2 | base | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 127285 | 0 | 0 |  |
| se-1c1p1t-timing-huge_2 | inc | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 127285 | 0 | 0 |  |
| se-1c1p1t-timing-interrupts_4_200 | base | **FAIL** | 0 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=1; fatal: syscall setitimer (#38) unimplemented.; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-1c1p1t-timing-interrupts_4_200 | inc | **FAIL** | 1 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=1; fatal: syscall setitimer (#38) unimplemented.; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-1c1p1t-timing-protect_3 | base | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 25436 | 0 | 0 |  |
| se-1c1p1t-timing-protect_3 | inc | **PASS** | 1 | 0/0/1 | 0 | 0 | 0 | 0 | 25436 | 0 | 0 |  |
| se-1c1p1t-timing-remap_20_96 | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 180489 | 0 | 0 |  |
| se-1c1p1t-timing-remap_20_96 | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 180489 | 0 | 0 |  |
| se-2c-atomic-fork-procs | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 209399 | 0 | 0 |  |
| se-2c-atomic-fork-procs | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 209399 | 0 | 0 |  |
| se-2c-atomic-fork-shared | base | **FAIL** | 217 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=-15; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-2c-atomic-fork-shared | inc | **FAIL** | 217 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=-15; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-2c-o3-fork-procs | base | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 166030 | 0 | 0 |  |
| se-2c-o3-fork-procs | inc | **PASS** | 5 | 1/0/0 | 0 | 0 | 0 | 0 | 166030 | 0 | 0 |  |
| se-2c-o3-fork-shared | base | **FAIL** | 110 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=-15; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-2c-o3-fork-shared | inc | **FAIL** | 114 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=-15; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-2c-timing-fork-procs | base | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 209399 | 0 | 0 |  |
| se-2c-timing-fork-procs | inc | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 209399 | 0 | 0 |  |
| se-2c-timing-fork-shared | base | **FAIL** | 201 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=-15; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-2c-timing-fork-shared | inc | **FAIL** | 202 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=-15; only 0/1 test RESULT lines (guest/workload did not finish) |
| se-4c1p3t-atomic-threads | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 239554 | 0 | 0 |  |
| se-4c1p3t-atomic-threads | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 239554 | 0 | 0 |  |
| se-4c1p3t-o3-threads | base | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 68988 | 0 | 0 |  |
| se-4c1p3t-o3-threads | inc | **PASS** | 4 | 1/0/0 | 0 | 0 | 0 | 0 | 68988 | 0 | 0 |  |
| se-4c1p3t-timing-threads | base | **PASS** | 2 | 1/0/0 | 0 | 0 | 0 | 0 | 239416 | 0 | 0 |  |
| se-4c1p3t-timing-threads | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 239416 | 0 | 0 |  |
| se-4c4p-atomic-multiprog | base | **FAIL** | 2 | 3/1/0 | 0 | 0 | 0 | 0 | 1831713 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data) |
| se-4c4p-atomic-multiprog | inc | **FAIL** | 2 | 3/1/0 | 0 | 0 | 0 | 0 | 1831713 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data) |
| se-4c4p-o3-multiprog | base | **FAIL** | 10 | 3/1/0 | 0 | 0 | 0 | 0 | 331494 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data) |
| se-4c4p-o3-multiprog | inc | **FAIL** | 15 | 3/1/0 | 0 | 0 | 0 | 0 | 331494 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data) |
| se-4c4p-timing-multiprog | base | **FAIL** | 4 | 3/1/0 | 0 | 0 | 0 | 0 | 1831713 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data) |
| se-4c4p-timing-multiprog | inc | **FAIL** | 4 | 3/1/0 | 0 | 0 | 0 | 0 | 1831713 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data) |
| se-8c1p7t-atomic-threads | base | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 527356 | 0 | 0 |  |
| se-8c1p7t-atomic-threads | inc | **PASS** | 1 | 1/0/0 | 0 | 0 | 0 | 0 | 527356 | 0 | 0 |  |
| se-8c1p7t-o3-threads | base | **PASS** | 7 | 1/0/0 | 0 | 0 | 0 | 0 | 145210 | 0 | 0 |  |
| se-8c1p7t-o3-threads | inc | **PASS** | 7 | 1/0/0 | 0 | 0 | 0 | 0 | 145210 | 0 | 0 |  |
| se-8c1p7t-timing-threads | base | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 527113 | 0 | 0 |  |
| se-8c1p7t-timing-threads | inc | **PASS** | 3 | 1/0/0 | 0 | 0 | 0 | 0 | 527113 | 0 | 0 |  |
| se-8c8p-atomic-multiprog | base | **FAIL** | 3 | 7/1/0 | 0 | 0 | 0 | 0 | 3466418 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0xfbcc1cdf85d15fd7 (old frame data) |
| se-8c8p-atomic-multiprog | inc | **FAIL** | 3 | 7/1/0 | 0 | 0 | 0 | 0 | 3466418 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0xfbcc1cdf85d15fd7 (old frame data) |
| se-8c8p-o3-multiprog | base | **FAIL** | 20 | 7/1/0 | 0 | 0 | 0 | 0 | 553271 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0xb799e8d7135d2781 (old frame data) |
| se-8c8p-o3-multiprog | inc | **FAIL** | 18 | 7/1/0 | 0 | 0 | 0 | 0 | 553271 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0xb799e8d7135d2781 (old frame data) |
| se-8c8p-timing-multiprog | base | **FAIL** | 7 | 7/1/0 | 0 | 0 | 0 | 0 | 3466418 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data) |
| se-8c8p-timing-multiprog | inc | **FAIL** | 6 | 7/1/0 | 0 | 0 | 0 | 0 | 3466418 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data) |
| se-smt2-o3-mixed | base | **PASS** | 4 | 2/0/0 | 0 | 0 | 0 | 0 | 157984 | 0 | 0 |  |
| se-smt2-o3-mixed | inc | **PASS** | 5 | 2/0/0 | 0 | 0 | 0 | 0 | 157984 | 0 | 0 |  |
| se-smt2-o3-same-test | base | **PASS** | 6 | 2/0/0 | 0 | 0 | 0 | 0 | 366376 | 0 | 0 |  |
| se-smt2-o3-same-test | inc | **PASS** | 6 | 2/0/0 | 0 | 0 | 0 | 0 | 366376 | 0 | 0 |  |
| se-smt4-o3-mixed | base | **FAIL** | 5 | 3/1/0 | 0 | 0 | 0 | 0 | 183928 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7fbf000 got 0x853f788ab7e18561 (old frame data) |
| se-smt4-o3-mixed | inc | **FAIL** | 6 | 3/1/0 | 0 | 0 | 0 | 0 | 183928 | 0 | 0 | test remap FAIL: STALE after remap round 1 page 0 va 0x7ffff7fbf000 got 0x853f788ab7e18561 (old frame data) |

## Per-test RESULT lines

- base/se-1c1p1t-atomic-capacity_2048_2: `capacity PASS pages=2048 passes=2 orders=6`
- inc/se-1c1p1t-atomic-capacity_2048_2: `capacity PASS pages=2048 passes=2 orders=6`
- base/se-1c1p1t-atomic-capacity_511_4: `capacity PASS pages=511 passes=4 orders=6`
- inc/se-1c1p1t-atomic-capacity_511_4: `capacity PASS pages=511 passes=4 orders=6`
- base/se-1c1p1t-atomic-capacity_512_4: `capacity PASS pages=512 passes=4 orders=6`
- inc/se-1c1p1t-atomic-capacity_512_4: `capacity PASS pages=512 passes=4 orders=6`
- base/se-1c1p1t-atomic-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- inc/se-1c1p1t-atomic-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- base/se-1c1p1t-atomic-capacity_63_4: `capacity PASS pages=63 passes=4 orders=6`
- inc/se-1c1p1t-atomic-capacity_63_4: `capacity PASS pages=63 passes=4 orders=6`
- base/se-1c1p1t-atomic-capacity_64_4: `capacity PASS pages=64 passes=4 orders=6`
- inc/se-1c1p1t-atomic-capacity_64_4: `capacity PASS pages=64 passes=4 orders=6`
- base/se-1c1p1t-atomic-capacity_65_4: `capacity PASS pages=65 passes=4 orders=6`
- inc/se-1c1p1t-atomic-capacity_65_4: `capacity PASS pages=65 passes=4 orders=6`
- base/se-1c1p1t-atomic-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- inc/se-1c1p1t-atomic-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- base/se-1c1p1t-atomic-conflict_80_10: `conflict PASS same-set pages=80 set=2 passes=10`
- inc/se-1c1p1t-atomic-conflict_80_10: `conflict PASS same-set pages=80 set=2 passes=10`
- base/se-1c1p1t-atomic-huge_2: `huge SKIP mprotect not enforced (SE mode?)`
- inc/se-1c1p1t-atomic-huge_2: `huge SKIP mprotect not enforced (SE mode?)`
- base/se-1c1p1t-atomic-protect_3: `protect SKIP write to read-only page 0 round 0 did NOT fault (mprotect not enforced - SE mode?)`
- inc/se-1c1p1t-atomic-protect_3: `protect SKIP write to read-only page 0 round 0 did NOT fault (mprotect not enforced - SE mode?)`
- base/se-1c1p1t-atomic-remap_20_96: `remap PASS rounds=20 pages=96`
- inc/se-1c1p1t-atomic-remap_20_96: `remap PASS rounds=20 pages=96`
- base/se-1c1p1t-o3-capacity_2048_2: `capacity PASS pages=2048 passes=2 orders=6`
- inc/se-1c1p1t-o3-capacity_2048_2: `capacity PASS pages=2048 passes=2 orders=6`
- base/se-1c1p1t-o3-capacity_511_4: `capacity PASS pages=511 passes=4 orders=6`
- inc/se-1c1p1t-o3-capacity_511_4: `capacity PASS pages=511 passes=4 orders=6`
- base/se-1c1p1t-o3-capacity_512_4: `capacity PASS pages=512 passes=4 orders=6`
- inc/se-1c1p1t-o3-capacity_512_4: `capacity PASS pages=512 passes=4 orders=6`
- base/se-1c1p1t-o3-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- inc/se-1c1p1t-o3-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- base/se-1c1p1t-o3-capacity_63_4: `capacity PASS pages=63 passes=4 orders=6`
- inc/se-1c1p1t-o3-capacity_63_4: `capacity PASS pages=63 passes=4 orders=6`
- base/se-1c1p1t-o3-capacity_64_4: `capacity PASS pages=64 passes=4 orders=6`
- inc/se-1c1p1t-o3-capacity_64_4: `capacity PASS pages=64 passes=4 orders=6`
- base/se-1c1p1t-o3-capacity_65_4: `capacity PASS pages=65 passes=4 orders=6`
- inc/se-1c1p1t-o3-capacity_65_4: `capacity PASS pages=65 passes=4 orders=6`
- base/se-1c1p1t-o3-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- inc/se-1c1p1t-o3-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- base/se-1c1p1t-o3-conflict_80_10: `conflict PASS same-set pages=80 set=2 passes=10`
- inc/se-1c1p1t-o3-conflict_80_10: `conflict PASS same-set pages=80 set=2 passes=10`
- base/se-1c1p1t-o3-huge_2: `huge SKIP mprotect not enforced (SE mode?)`
- inc/se-1c1p1t-o3-huge_2: `huge SKIP mprotect not enforced (SE mode?)`
- base/se-1c1p1t-o3-protect_3: `protect SKIP write to read-only page 0 round 0 did NOT fault (mprotect not enforced - SE mode?)`
- inc/se-1c1p1t-o3-protect_3: `protect SKIP write to read-only page 0 round 0 did NOT fault (mprotect not enforced - SE mode?)`
- base/se-1c1p1t-o3-remap_20_96: `remap PASS rounds=20 pages=96`
- inc/se-1c1p1t-o3-remap_20_96: `remap PASS rounds=20 pages=96`
- base/se-1c1p1t-timing-capacity_2048_2: `capacity PASS pages=2048 passes=2 orders=6`
- inc/se-1c1p1t-timing-capacity_2048_2: `capacity PASS pages=2048 passes=2 orders=6`
- base/se-1c1p1t-timing-capacity_511_4: `capacity PASS pages=511 passes=4 orders=6`
- inc/se-1c1p1t-timing-capacity_511_4: `capacity PASS pages=511 passes=4 orders=6`
- base/se-1c1p1t-timing-capacity_512_4: `capacity PASS pages=512 passes=4 orders=6`
- inc/se-1c1p1t-timing-capacity_512_4: `capacity PASS pages=512 passes=4 orders=6`
- base/se-1c1p1t-timing-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- inc/se-1c1p1t-timing-capacity_513_4: `capacity PASS pages=513 passes=4 orders=6`
- base/se-1c1p1t-timing-capacity_63_4: `capacity PASS pages=63 passes=4 orders=6`
- inc/se-1c1p1t-timing-capacity_63_4: `capacity PASS pages=63 passes=4 orders=6`
- base/se-1c1p1t-timing-capacity_64_4: `capacity PASS pages=64 passes=4 orders=6`
- inc/se-1c1p1t-timing-capacity_64_4: `capacity PASS pages=64 passes=4 orders=6`
- base/se-1c1p1t-timing-capacity_65_4: `capacity PASS pages=65 passes=4 orders=6`
- inc/se-1c1p1t-timing-capacity_65_4: `capacity PASS pages=65 passes=4 orders=6`
- base/se-1c1p1t-timing-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- inc/se-1c1p1t-timing-conflict_200_4: `conflict PASS same-set pages=200 set=2 passes=4`
- base/se-1c1p1t-timing-conflict_80_10: `conflict PASS same-set pages=80 set=2 passes=10`
- inc/se-1c1p1t-timing-conflict_80_10: `conflict PASS same-set pages=80 set=2 passes=10`
- base/se-1c1p1t-timing-huge_2: `huge SKIP mprotect not enforced (SE mode?)`
- inc/se-1c1p1t-timing-huge_2: `huge SKIP mprotect not enforced (SE mode?)`
- base/se-1c1p1t-timing-protect_3: `protect SKIP write to read-only page 0 round 0 did NOT fault (mprotect not enforced - SE mode?)`
- inc/se-1c1p1t-timing-protect_3: `protect SKIP write to read-only page 0 round 0 did NOT fault (mprotect not enforced - SE mode?)`
- base/se-1c1p1t-timing-remap_20_96: `remap PASS rounds=20 pages=96`
- inc/se-1c1p1t-timing-remap_20_96: `remap PASS rounds=20 pages=96`
- base/se-2c-atomic-fork-procs: `procs PASS procs=3 rounds=5 same_va=0x600000000000 pages=160`
- inc/se-2c-atomic-fork-procs: `procs PASS procs=3 rounds=5 same_va=0x600000000000 pages=160`
- base/se-2c-o3-fork-procs: `procs PASS procs=3 rounds=5 same_va=0x600000000000 pages=160`
- inc/se-2c-o3-fork-procs: `procs PASS procs=3 rounds=5 same_va=0x600000000000 pages=160`
- base/se-2c-timing-fork-procs: `procs PASS procs=3 rounds=5 same_va=0x600000000000 pages=160`
- inc/se-2c-timing-fork-procs: `procs PASS procs=3 rounds=5 same_va=0x600000000000 pages=160`
- base/se-4c1p3t-atomic-threads: `threads PASS threads=3 pages/thread=300 passes=3`
- inc/se-4c1p3t-atomic-threads: `threads PASS threads=3 pages/thread=300 passes=3`
- base/se-4c1p3t-o3-threads: `threads PASS threads=3 pages/thread=300 passes=3`
- inc/se-4c1p3t-o3-threads: `threads PASS threads=3 pages/thread=300 passes=3`
- base/se-4c1p3t-timing-threads: `threads PASS threads=3 pages/thread=300 passes=3`
- inc/se-4c1p3t-timing-threads: `threads PASS threads=3 pages/thread=300 passes=3`
- base/se-4c4p-atomic-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data)`
- base/se-4c4p-atomic-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- base/se-4c4p-atomic-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- base/se-4c4p-atomic-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- inc/se-4c4p-atomic-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data)`
- inc/se-4c4p-atomic-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- inc/se-4c4p-atomic-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- inc/se-4c4p-atomic-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- base/se-4c4p-o3-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data)`
- base/se-4c4p-o3-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- base/se-4c4p-o3-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- base/se-4c4p-o3-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- inc/se-4c4p-o3-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data)`
- inc/se-4c4p-o3-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- inc/se-4c4p-o3-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- inc/se-4c4p-o3-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- base/se-4c4p-timing-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data)`
- base/se-4c4p-timing-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- base/se-4c4p-timing-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- base/se-4c4p-timing-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- inc/se-4c4p-timing-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data)`
- inc/se-4c4p-timing-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- inc/se-4c4p-timing-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- inc/se-4c4p-timing-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- base/se-8c1p7t-atomic-threads: `threads PASS threads=7 pages/thread=300 passes=3`
- inc/se-8c1p7t-atomic-threads: `threads PASS threads=7 pages/thread=300 passes=3`
- base/se-8c1p7t-o3-threads: `threads PASS threads=7 pages/thread=300 passes=3`
- inc/se-8c1p7t-o3-threads: `threads PASS threads=7 pages/thread=300 passes=3`
- base/se-8c1p7t-timing-threads: `threads PASS threads=7 pages/thread=300 passes=3`
- inc/se-8c1p7t-timing-threads: `threads PASS threads=7 pages/thread=300 passes=3`
- base/se-8c8p-atomic-multiprog: `threads PASS threads=1 pages/thread=200 passes=2`
- base/se-8c8p-atomic-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0xfbcc1cdf85d15fd7 (old frame data)`
- base/se-8c8p-atomic-multiprog: `capacity PASS pages=65 passes=6 orders=6`
- base/se-8c8p-atomic-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- base/se-8c8p-atomic-multiprog: `conflict PASS same-set pages=200 set=2 passes=3`
- base/se-8c8p-atomic-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- base/se-8c8p-atomic-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- base/se-8c8p-atomic-multiprog: `capacity PASS pages=700 passes=3 orders=6`
- inc/se-8c8p-atomic-multiprog: `threads PASS threads=1 pages/thread=200 passes=2`
- inc/se-8c8p-atomic-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0xfbcc1cdf85d15fd7 (old frame data)`
- inc/se-8c8p-atomic-multiprog: `capacity PASS pages=65 passes=6 orders=6`
- inc/se-8c8p-atomic-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- inc/se-8c8p-atomic-multiprog: `conflict PASS same-set pages=200 set=2 passes=3`
- inc/se-8c8p-atomic-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- inc/se-8c8p-atomic-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- inc/se-8c8p-atomic-multiprog: `capacity PASS pages=700 passes=3 orders=6`
- base/se-8c8p-o3-multiprog: `threads PASS threads=1 pages/thread=200 passes=2`
- base/se-8c8p-o3-multiprog: `capacity PASS pages=65 passes=6 orders=6`
- base/se-8c8p-o3-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0xb799e8d7135d2781 (old frame data)`
- base/se-8c8p-o3-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- base/se-8c8p-o3-multiprog: `conflict PASS same-set pages=200 set=2 passes=3`
- base/se-8c8p-o3-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- base/se-8c8p-o3-multiprog: `capacity PASS pages=700 passes=3 orders=6`
- base/se-8c8p-o3-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- inc/se-8c8p-o3-multiprog: `threads PASS threads=1 pages/thread=200 passes=2`
- inc/se-8c8p-o3-multiprog: `capacity PASS pages=65 passes=6 orders=6`
- inc/se-8c8p-o3-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0xb799e8d7135d2781 (old frame data)`
- inc/se-8c8p-o3-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- inc/se-8c8p-o3-multiprog: `conflict PASS same-set pages=200 set=2 passes=3`
- inc/se-8c8p-o3-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- inc/se-8c8p-o3-multiprog: `capacity PASS pages=700 passes=3 orders=6`
- inc/se-8c8p-o3-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- base/se-8c8p-timing-multiprog: `threads PASS threads=1 pages/thread=200 passes=2`
- base/se-8c8p-timing-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data)`
- base/se-8c8p-timing-multiprog: `capacity PASS pages=65 passes=6 orders=6`
- base/se-8c8p-timing-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- base/se-8c8p-timing-multiprog: `conflict PASS same-set pages=200 set=2 passes=3`
- base/se-8c8p-timing-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- base/se-8c8p-timing-multiprog: `capacity PASS pages=700 passes=3 orders=6`
- base/se-8c8p-timing-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- inc/se-8c8p-timing-multiprog: `threads PASS threads=1 pages/thread=200 passes=2`
- inc/se-8c8p-timing-multiprog: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7f9f000 got 0x268d5bd070e0559f (old frame data)`
- inc/se-8c8p-timing-multiprog: `capacity PASS pages=65 passes=6 orders=6`
- inc/se-8c8p-timing-multiprog: `conflict PASS same-set pages=80 set=2 passes=6`
- inc/se-8c8p-timing-multiprog: `conflict PASS same-set pages=200 set=2 passes=3`
- inc/se-8c8p-timing-multiprog: `capacity PASS pages=513 passes=3 orders=6`
- inc/se-8c8p-timing-multiprog: `capacity PASS pages=700 passes=3 orders=6`
- inc/se-8c8p-timing-multiprog: `capacity PASS pages=2048 passes=1 orders=6`
- base/se-smt2-o3-mixed: `conflict PASS same-set pages=80 set=2 passes=6`
- base/se-smt2-o3-mixed: `capacity PASS pages=700 passes=3 orders=6`
- inc/se-smt2-o3-mixed: `conflict PASS same-set pages=80 set=2 passes=6`
- inc/se-smt2-o3-mixed: `capacity PASS pages=700 passes=3 orders=6`
- base/se-smt2-o3-same-test: `capacity PASS pages=513 passes=3 orders=6`
- base/se-smt2-o3-same-test: `capacity PASS pages=513 passes=3 orders=6`
- inc/se-smt2-o3-same-test: `capacity PASS pages=513 passes=3 orders=6`
- inc/se-smt2-o3-same-test: `capacity PASS pages=513 passes=3 orders=6`
- base/se-smt4-o3-mixed: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7fbf000 got 0x853f788ab7e18561 (old frame data)`
- base/se-smt4-o3-mixed: `conflict PASS same-set pages=80 set=2 passes=4`
- base/se-smt4-o3-mixed: `capacity PASS pages=300 passes=3 orders=6`
- base/se-smt4-o3-mixed: `capacity PASS pages=513 passes=2 orders=6`
- inc/se-smt4-o3-mixed: `remap FAIL STALE after remap round 1 page 0 va 0x7ffff7fbf000 got 0x853f788ab7e18561 (old frame data)`
- inc/se-smt4-o3-mixed: `conflict PASS same-set pages=80 set=2 passes=4`
- inc/se-smt4-o3-mixed: `capacity PASS pages=300 passes=3 orders=6`
- inc/se-smt4-o3-mixed: `capacity PASS pages=513 passes=2 orders=6`
