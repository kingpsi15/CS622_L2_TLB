#!/bin/bash
# usage: isa_atomic_wait.sh LANE SRCHOST TARGETHOST SRC_WORKDIR  (runs on the lane host)
L=$1; SRC=$2; TGT=$3; SW=$4; LOG=/tmp/sahilag24/isa_$L.log
until grep -q -E 'build ok|build failed' $LOG 2>/dev/null; do sleep 30; done
grep -q 'build ok' $LOG || { echo "build failed, no atomic 600" > ~/isa_atomic_$L.out; exit 1; }
ssh -n -o LogLevel=ERROR sahilag24@csewsrm$TGT.cse.iitk.ac.in "bash ~/spawn_atomic_isa.sh $L $SRC '600' $SW" > ~/isa_atomic_$L.out 2>&1
