#!/bin/bash
export VARIANT=perf; source "$(dirname "$0")/env.sh"
/usr/bin/python3 $R/scripts/gen_perf_jobs.py && /usr/bin/python3 $R/scripts/runner.py $W/jobs/perf_matrix.json --jobs 24 --tag perf_matrix
