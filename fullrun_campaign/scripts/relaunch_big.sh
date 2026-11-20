#!/bin/bash
# usage: relaunch_big.sh LANE SRCHOST SRC_WORKDIR
L=$1; SRC=$2; SW=$3
pkill -u $USER -f 'spawn_new_big[.]sh'; pkill -u $USER -x rsync; pkill -u $USER -x gem5.opt
tmux kill-server 2>/dev/null; sleep 3
rm -rf /tmp/sahilag24/extra-$L
tmux new -d -s spawnbig "bash ~/spawn_new_big.sh $L $SRC 631 $SW > /tmp/spawn_big.log 2>&1"
