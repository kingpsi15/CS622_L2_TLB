#!/bin/bash
export VARIANT=perf; source "$(dirname "$0")/env.sh"
until [ -f $W/stamps/build_perf ]; do
  [ -f $W/stamps/build_failed ] && exit 1; sleep 20; done
smoke() { $INC/build/X86/gem5.opt -re -d $W/runs/smoke $INC/configs/deprecated/example/se.py --cpu-type TimingSimpleCPU --caches --l2cache \
   -c $W/tests/perf_holes -o "edge 2 2" && grep -q "RESULT perf_edge PASS" $W/runs/smoke/simout.txt; }
stage smoke smoke || { log "perf_pipeline: smoke failed"; tail -n 20 $W/runs/smoke/simout.txt $W/runs/smoke/simerr.txt >> $RES/smoke.fail.txt; exit 1; }
grep -h "coarse\|secondary\|l2Bitmap\|chkOracle" $W/runs/smoke/stats.txt | head -12 > $RES/smoke_stats.txt
/usr/bin/python3 $R/scripts/gen_perf_jobs.py
/usr/bin/python3 $R/scripts/runner.py $W/jobs/perf_matrix.json --jobs 20 --tag perf_matrix
log "perf_pipeline: SE matrix done -> robustness/results-perf/perf_matrix.md"
