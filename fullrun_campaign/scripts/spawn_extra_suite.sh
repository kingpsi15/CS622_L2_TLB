#!/bin/bash
export RSYNC_RSH="ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes"
set -e
SUITE=$1; L=$2; BH=$3; MH=$4; D=cse.iitk.ac.in
W=/tmp/sahilag24/work-$L; X=/tmp/sahilag24/suite-$SUITE-$L; BD=/tmp/sahilag24/fixbin-$L
rm -rf $X; mkdir -p $W/dl $BD $X
rsync -aS sahilag24@$MH.$D:$W/dl/x86-ubuntu-24.04.img sahilag24@$MH.$D:$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic $W/dl/
rsync -aS sahilag24@$BH.$D:/tmp/sahilag24/CS622_L2_TLB/gem5-$L-fix/build/X86/gem5.opt $BD/
rsync -a $HOME/kv_gapbs_payload/ $X/payload/
truncate -s 512M $X/bench.img
mkfs.ext4 -F -q -L BENCH -d $X/payload $X/bench.img
mkdir -p $X/run0
tmux new -d -s $SUITE-$L "LD_LIBRARY_PATH=$HOME/gcclib FS_MEM=8GiB FS_KERNEL=$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic FS_DISK=$W/dl/x86-ubuntu-24.04.img $BD/gem5.opt -re --listener-mode=off -d $X/run0 $HOME/CS622_L2_TLB/robustness/scripts/fs_run_big.py --cores 1 --cpu timing --start-cpu atomic --script $X/payload/guest_$SUITE.sh --spec-disk $X/bench.img; echo exited \$? > $X/run0/EXITED"
echo "DONE $SUITE-$L on $(hostname -s)"
