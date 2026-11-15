# spec_test

Generated 2026-11-13 21:39:52. Raw outputs: `/tmp/sahilag24/work/runs/spec_test/`

| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| spec-test-500.perlbench_r-0 | base | **PASS** | 4185 | 0/0/0 | 0 | 0 | 0 | 0 | 4140039252 | 0 | 0 |  |
| spec-test-500.perlbench_r-0 | inc | **PASS** | 4322 | 0/0/0 | 343 | 0 | 665 | 0 | 4140039252 | 0 | 0 |  |
| spec-test-500.perlbench_r-1 | base | **PASS** | 2 | 0/0/0 | 0 | 0 | 0 | 0 | 1389448 | 0 | 0 |  |
| spec-test-500.perlbench_r-1 | inc | **PASS** | 2 | 0/0/0 | 194 | 0 | 496 | 0 | 1389448 | 0 | 0 |  |
| spec-test-502.gcc_r-0 | base | **PASS** | 10 | 0/0/0 | 0 | 0 | 0 | 0 | 8530735 | 0 | 0 |  |
| spec-test-502.gcc_r-0 | inc | **PASS** | 12 | 0/0/0 | 2390 | 7 | 3237 | 0 | 8530735 | 0 | 0 |  |
| spec-test-503.bwaves_r-0 | base | **PASS** | 7 | 0/0/0 | 0 | 0 | 0 | 0 | 6661150 | 0 | 0 |  |
| spec-test-503.bwaves_r-0 | inc | **PASS** | 7 | 0/0/0 | 80 | 0 | 285 | 0 | 6661150 | 0 | 0 |  |
| spec-test-503.bwaves_r-1 | base | **PASS** | 9 | 0/0/0 | 0 | 0 | 0 | 0 | 6661583 | 0 | 0 |  |
| spec-test-503.bwaves_r-1 | inc | **PASS** | 7 | 0/0/0 | 80 | 0 | 285 | 0 | 6661583 | 0 | 0 |  |
| spec-test-505.mcf_r-0 | base | **FAIL** | 28800 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=TIMEOUT |
| spec-test-505.mcf_r-0 | inc | **FAIL** | 28800 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=TIMEOUT |
| spec-test-507.cactuBSSN_r-0 | base | **FAIL** | 28800 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=TIMEOUT |
| spec-test-507.cactuBSSN_r-0 | inc | **FAIL** | 28800 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=TIMEOUT |
| spec-test-508.namd_r-0 | base | **PASS** | 2736 | 0/0/0 | 0 | 0 | 0 | 0 | 2666251047 | 0 | 0 |  |
| spec-test-508.namd_r-0 | inc | **PASS** | 2980 | 0/0/0 | 1391 | 144 | 12800 | 0 | 2666251047 | 0 | 0 |  |
| spec-test-511.povray_r-0 | base | **PASS** | 18 | 0/0/0 | 0 | 0 | 0 | 0 | 17507145 | 0 | 0 |  |
| spec-test-511.povray_r-0 | inc | **PASS** | 20 | 0/0/0 | 166 | 0 | 512 | 0 | 17507122 | 0 | 0 |  |
| spec-test-519.lbm_r-0 | base | **PASS** | 14128 | 0/0/0 | 0 | 0 | 0 | 0 | 16610358600 | 0 | 0 |  |
| spec-test-519.lbm_r-0 | inc | **PASS** | 16894 | 0/0/0 | 1228 | 32610 | 4439844 | 0 | 16610358600 | 0 | 0 |  |
| spec-test-520.omnetpp_r-0 | base | **PASS** | 68 | 0/0/0 | 0 | 0 | 0 | 0 | 59313178 | 0 | 0 |  |
| spec-test-520.omnetpp_r-0 | inc | **PASS** | 62 | 0/0/0 | 2532 | 0 | 3063 | 0 | 59313178 | 0 | 0 |  |
| spec-test-521.wrf_r-0 | base | **PASS** | 50 | 0/0/0 | 0 | 0 | 0 | 0 | 45781543 | 0 | 0 |  |
| spec-test-521.wrf_r-0 | inc | **PASS** | 53 | 0/0/0 | 2839 | 0 | 3431 | 0 | 45781543 | 0 | 0 |  |
| spec-test-523.xalancbmk_r-0 | base | **PASS** | 706 | 0/0/0 | 0 | 0 | 0 | 0 | 667147504 | 0 | 0 |  |
| spec-test-523.xalancbmk_r-0 | inc | **PASS** | 727 | 0/0/0 | 2808059 | 4985 | 2912181 | 0 | 667147504 | 0 | 0 |  |
| spec-test-525.x264_r-0 | base | **PASS** | 1 | 0/0/0 | 0 | 0 | 0 | 0 | 32892 | 0 | 0 |  |
| spec-test-525.x264_r-0 | inc | **PASS** | 1 | 0/0/0 | 0 | 0 | 108 | 0 | 32892 | 0 | 0 |  |
| spec-test-527.cam4_r-0 | base | **PASS** | 34 | 0/0/0 | 0 | 0 | 0 | 0 | 28657258 | 0 | 0 |  |
| spec-test-527.cam4_r-0 | inc | **PASS** | 29 | 0/0/0 | 1634 | 1 | 1986 | 0 | 28657258 | 0 | 0 |  |
| spec-test-531.deepsjeng_r-0 | base | **FAIL** | 28800 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=TIMEOUT |
| spec-test-531.deepsjeng_r-0 | inc | **FAIL** | 28800 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=TIMEOUT |
| spec-test-538.imagick_r-0 | base | **PASS** | 117 | 0/0/0 | 0 | 0 | 0 | 0 | 139790978 | 0 | 0 |  |
| spec-test-538.imagick_r-0 | inc | **PASS** | 121 | 0/0/0 | 191348 | 2572 | 312694 | 0 | 139790978 | 0 | 0 |  |
| spec-test-541.leela_r-0 | base | **FAIL** | 28800 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=TIMEOUT |
| spec-test-541.leela_r-0 | inc | **FAIL** | 28800 | 0/0/0 |  |  |  |  |  |  |  | gem5 rc=TIMEOUT |
| spec-test-544.nab_r-0 | base | **PASS** | 1 | 0/0/0 | 0 | 0 | 0 | 0 | 34019 | 0 | 0 |  |
| spec-test-544.nab_r-0 | inc | **PASS** | 1 | 0/0/0 | 0 | 0 | 104 | 0 | 34019 | 0 | 0 |  |
| spec-test-548.exchange2_r-0 | base | **PASS** | 7 | 0/0/0 | 0 | 0 | 0 | 0 | 6681715 | 0 | 0 |  |
| spec-test-548.exchange2_r-0 | inc | **PASS** | 7 | 0/0/0 | 14 | 0 | 183 | 0 | 6681715 | 0 | 0 |  |
| spec-test-549.fotonik3d_r-0 | base | **PASS** | 1 | 0/0/0 | 0 | 0 | 0 | 0 | 67888 | 0 | 0 |  |
| spec-test-549.fotonik3d_r-0 | inc | **PASS** | 1 | 0/0/0 | 16 | 0 | 158 | 0 | 67888 | 0 | 0 |  |
| spec-test-554.roms_r-0 | base | **PASS** | 2 | 0/0/0 | 0 | 0 | 0 | 0 | 1097261 | 0 | 0 |  |
| spec-test-554.roms_r-0 | inc | **PASS** | 2 | 0/0/0 | 70 | 0 | 342 | 0 | 1097261 | 0 | 0 |  |
| spec-test-557.xz_r-0 | base | **PASS** | 4595 | 0/0/0 | 0 | 0 | 0 | 0 | 4557373246 | 0 | 0 |  |
| spec-test-557.xz_r-0 | inc | **PASS** | 4505 | 0/0/0 | 4815006 | 11978 | 5024840 | 0 | 4557373246 | 0 | 0 |  |
| spec-test-557.xz_r-1 | base | **PASS** | 4038 | 0/0/0 | 0 | 0 | 0 | 0 | 4497468625 | 0 | 0 |  |
| spec-test-557.xz_r-1 | inc | **PASS** | 4531 | 0/0/0 | 7817706 | 123302 | 10935175 | 0 | 4497468625 | 0 | 0 |  |
| spec-test-557.xz_r-10 | base | **PASS** | 2441 | 0/0/0 | 0 | 0 | 0 | 0 | 2861179908 | 0 | 0 |  |
| spec-test-557.xz_r-10 | inc | **PASS** | 2818 | 0/0/0 | 1864510 | 45919 | 3075473 | 0 | 2861179908 | 0 | 0 |  |
| spec-test-557.xz_r-11 | base | **PASS** | 2704 | 0/0/0 | 0 | 0 | 0 | 0 | 4387690536 | 0 | 0 |  |
| spec-test-557.xz_r-11 | inc | **PASS** | 4807 | 0/0/0 | 1899398 | 53793 | 3152674 | 0 | 4387690536 | 0 | 0 |  |
| spec-test-557.xz_r-2 | base | **PASS** | 4425 | 0/0/0 | 0 | 0 | 0 | 0 | 4583837979 | 0 | 0 |  |
| spec-test-557.xz_r-2 | inc | **PASS** | 4067 | 0/0/0 | 9772582 | 147360 | 15444845 | 0 | 4583837979 | 0 | 0 |  |
| spec-test-557.xz_r-3 | base | **PASS** | 15831 | 0/0/0 | 0 | 0 | 0 | 0 | 16438088930 | 0 | 0 |  |
| spec-test-557.xz_r-3 | inc | **PASS** | 15428 | 0/0/0 | 9978914 | 287996 | 17644244 | 0 | 16438088930 | 0 | 0 |  |
| spec-test-557.xz_r-4 | base | **PASS** | 7561 | 0/0/0 | 0 | 0 | 0 | 0 | 7499298404 | 0 | 0 |  |
| spec-test-557.xz_r-4 | inc | **PASS** | 8137 | 0/0/0 | 9366812 | 192922 | 16177614 | 0 | 7499298404 | 0 | 0 |  |
| spec-test-557.xz_r-5 | base | **PASS** | 18996 | 0/0/0 | 0 | 0 | 0 | 0 | 18523697066 | 0 | 0 |  |
| spec-test-557.xz_r-5 | inc | **PASS** | 16730 | 0/0/0 | 10037876 | 294772 | 17755585 | 0 | 18523697066 | 0 | 0 |  |
| spec-test-557.xz_r-6 | base | **PASS** | 2150 | 0/0/0 | 0 | 0 | 0 | 0 | 2311649637 | 0 | 0 |  |
| spec-test-557.xz_r-6 | inc | **PASS** | 2136 | 0/0/0 | 2001056 | 8678 | 2183872 | 0 | 2311649637 | 0 | 0 |  |
| spec-test-557.xz_r-7 | base | **PASS** | 2278 | 0/0/0 | 0 | 0 | 0 | 0 | 2322583228 | 0 | 0 |  |
| spec-test-557.xz_r-7 | inc | **PASS** | 2493 | 0/0/0 | 2135495 | 46515 | 3250777 | 0 | 2322583228 | 0 | 0 |  |
| spec-test-557.xz_r-8 | base | **PASS** | 2090 | 0/0/0 | 0 | 0 | 0 | 0 | 2327532721 | 0 | 0 |  |
| spec-test-557.xz_r-8 | inc | **PASS** | 2360 | 0/0/0 | 2034377 | 40262 | 3198757 | 0 | 2327532721 | 0 | 0 |  |
| spec-test-557.xz_r-9 | base | **PASS** | 4140 | 0/0/0 | 0 | 0 | 0 | 0 | 4109142643 | 0 | 0 |  |
| spec-test-557.xz_r-9 | inc | **PASS** | 4230 | 0/0/0 | 1893946 | 53293 | 3144276 | 0 | 4109142643 | 0 | 0 |  |

## Per-test RESULT lines

