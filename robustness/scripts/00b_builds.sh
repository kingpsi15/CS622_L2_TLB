#!/bin/bash
# Build-only subset of 00_setup.sh (used when downloads/SPEC install are already running).
source "$(dirname "$0")/env.sh"
eval "$(sed -n '/^make_tree()/,/^build_m5()/p' "$(dirname "$0")/00_setup.sh")"
JOBS=${JOBS:-14}
rm -f $W/stamps/tree_inc $W/stamps/tree_base
( stage tree_inc tree_inc && stage build_inc build $INC && stage build_m5 build_m5 ) &
( stage tree_base tree_base && stage build_base build $BASE ) &
wait
