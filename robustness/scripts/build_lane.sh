#!/bin/bash
# usage: VARIANT=perf build_lane.sh  (single scons run in the lane's tree; stable SCons 4.8.1 from /tmp/sahilag24/sc)
source "$(dirname "$0")/env.sh"
SC=/tmp/sahilag24/sc
[ -d $SC/SCons ] || /usr/bin/python3 -m pip install -q --target $SC "scons==4.8.1"
cd $INC || exit 1
log "build_lane $VARIANT: scons4.8.1 START (gcc-11, py3.10)"
PYTHONPATH=$SC /usr/bin/python3 -m SCons build/X86/gem5.opt -j ${JOBS:-30} --linker=gold --ignore-style > $W/logs/build_$VARIANT.log 2>&1
if [ -x build/X86/gem5.opt ]; then touch $W/stamps/build_$VARIANT; log "build_lane $VARIANT: OK $(ls -l build/X86/gem5.opt | awk '{print $5}') bytes"
else log "build_lane $VARIANT: **FAILED** no gem5.opt; tail: $(tail -n 3 $W/logs/build_$VARIANT.log | tr '\n' ' ' | cut -c1-300)"; fi
