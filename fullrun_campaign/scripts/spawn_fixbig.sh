#!/bin/bash
# usage: spawn_fixbig.sh LANE BINHOST WORKHOST GUESTHOST   (run on target host)
set -e
L=$1; BH=$2; MH=$3; GH=$4; D=cse.iitk.ac.in
W=/tmp/sahilag24/work-$L; X=/tmp/sahilag24/extra-fb-$L; GD=/tmp/sahilag24/fixbin-$L
G=$GD/gem5.opt
F=$HOME/CS622_L2_TLB/robustness/scripts/fs_run_big.py
KERN=$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic
ROOT=$W/dl/x86-ubuntu-24.04.img
[ -f $F ] || { echo "no fs_run_big.py"; exit 1; }
[ "$(df -BG --output=avail /tmp | tail -1 | tr -dc 0-9)" -gt 80 ] || { echo "low disk"; exit 1; }
[ -z "$(ls $X 2>/dev/null | grep -E '^(run|guest)')" ] || { echo "old files exist"; exit 1; }
mkdir -p $W/dl $GD $X
echo "$(date +%T) copying"
rsync -aS sahilag24@$MH.$D:$W/dl/x86-ubuntu-24.04.img sahilag24@$MH.$D:$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic $W/dl/
rsync -aS sahilag24@$BH.$D:/tmp/sahilag24/CS622_L2_TLB/gem5-$L-fix/build/X86/gem5.opt $GD/
rsync -a sahilag24@$GH.$D:/tmp/sahilag24/extra-$L/guest0.sh $X/guest0.sh
rsync -aS sahilag24@$MH.$D:$W/cpu2017/ $W/cpu2017/
[ -x $G ] && [ -f $KERN ] && [ -f $ROOT ] && [ -d $W/cpu2017 ] || { echo "copy failed"; exit 1; }
[ "$(grep -o '^echo SPEC_START [0-9]*' $X/guest0.sh | awk '{print $3}' | sort -u | tr '\n' ' ')" = "619 " ] || { echo "guest0 is not 619-only"; exit 1; }
echo "$(date +%T) building disk"
data=$(du -sb $W/cpu2017 | cut -f1)
truncate -s $(( data*11/10 + 1073741824 )) $X/spec0.img
mkfs.ext4 -F -q -L SPEC2017 -d $W/cpu2017 $X/spec0.img
e2fsck -fn $X/spec0.img >/dev/null 2>&1 || { echo "disk not clean"; exit 1; }
mkdir -p $X/run0
tmux new -d -s fb-$L "LD_LIBRARY_PATH=$HOME/gcclib FS_MEM=12GiB FS_KERNEL=$KERN FS_DISK=$ROOT $G -re --listener-mode=off -d $X/run0 $F --cores 1 --cpu timing --start-cpu atomic --script $X/guest0.sh --spec-disk $X/spec0.img; echo exited \$? > $X/run0/EXITED"
sleep 20
echo "gem5 total: $(pgrep -c -x gem5.opt)"
