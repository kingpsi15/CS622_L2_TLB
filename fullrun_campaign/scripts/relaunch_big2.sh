#!/bin/bash
# usage: relaunch_big2.sh LANE SRCHOST BENCH SRC_WORKDIR
L=$1; SRC=$2; B=$3; SW=$4
tmux kill-server 2>/dev/null; sleep 1
rm -rf /tmp/sahilag24/extra-$L
tmux new -d -s spawnbig "bash ~/spawn_new_big.sh $L $SRC $B $SW > /tmp/spawn_big.log 2>&1"
