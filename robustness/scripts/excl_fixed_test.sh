#!/bin/bash
# Run the SE job matrix (same matrix machine_run.sh already generated for
# this lane at $W/jobs/se_matrix.json) against the exclusivity-checked
# excl_fixed_build.sh tree for STAGE (before|after), vs. the already-built
# stock baseline ($W/gem5-base). Copies the matrix under a distinct name so
# this never races the main run_excl.sh's own runner.py invocation, and uses
# a distinct --tag so output lands in its own results-excl/<tag>.md.
#
# usage: excl_fixed_test.sh {before|after}
set -e
STAGE=$1; [ "$STAGE" = before ] || [ "$STAGE" = after ] || { echo "usage: $0 before|after"; exit 1; }
export VARIANT=excl; source "$(dirname "$0")/env.sh"
export SHARED=$W; export BASE=$W/gem5-base
CHKTREE=${EXCL_CHECK_TREE:-$W/gem5-excl}
cp "$CHKTREE/build/X86/gem5.opt.$STAGE" "$CHKTREE/build/X86/gem5.opt"
export INC=$CHKTREE
TAG=excl_chk_$STAGE
mkdir -p "$W/jobs"
SRCJOBS="$W/jobs/se_matrix.json"
until [ -f "$SRCJOBS" ]; do
  log "[excl-chk-test] waiting for $SRCJOBS (written by the main run_excl.sh's gen_se_jobs.py)"
  sleep 15
done
cp "$SRCJOBS" "$W/jobs/se_matrix_$TAG.json"
log "[excl-chk-test] $STAGE: runner START tag=$TAG (INC=$INC BASE=$BASE)"
python3 "$R/scripts/runner.py" "$W/jobs/se_matrix_$TAG.json" --jobs "${RJOBS:-16}" --tag "$TAG"
log "[excl-chk-test] $STAGE: DONE -> robustness/results-excl/$TAG.md"
