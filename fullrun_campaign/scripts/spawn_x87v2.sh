#!/bin/bash
# usage: spawn_x87v2.sh LANE BINHOST X87HOST MAINHOST
set -e
L=$1; BH=$2; XH=$3; MH=$4; D=cse.iitk.ac.in
W=/tmp/sahilag24/work-$L; X=/tmp/sahilag24/extra-x87v2-$L; XB=/tmp/sahilag24/x87bin2-$L
G=$XB/gem5.opt
F=$HOME/CS622_L2_TLB/robustness/scripts/fs_run.py
KERN=$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic
ROOT=$W/dl/x86-ubuntu-24.04.img
[ -f $F ] || { echo "no fs_run.py"; exit 1; }
[ "$(df -BG --output=avail /tmp | tail -1 | tr -dc 0-9)" -gt 60 ] || { echo "low disk"; exit 1; }
[ -z "$(ls $X 2>/dev/null | grep -E '^(run|guest)')" ] || { echo "old files exist"; exit 1; }
mkdir -p $W/dl $XB $X
echo "$(date +%T) copying"
rsync -aS sahilag24@$MH.$D:$W/dl/x86-ubuntu-24.04.img sahilag24@$MH.$D:$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic $W/dl/
rsync -aS sahilag24@$BH.$D:/tmp/sahilag24/CS622_L2_TLB/gem5-$L-fix/build/X86/gem5.opt $XB/
rsync -a sahilag24@$XH.$D:/tmp/sahilag24/extra-x87-$L/guest0.sh sahilag24@$XH.$D:/tmp/sahilag24/extra-x87-$L/guest1.sh $X/
rsync -aS sahilag24@$MH.$D:$W/cpu2017/ $W/cpu2017/
[ -x $G ] && [ -f $KERN ] && [ -f $ROOT ] && [ -d $W/cpu2017 ] || { echo "copy failed"; exit 1; }
echo "$(date +%T) building disk"
data=$(du -sb $W/cpu2017 | cut -f1)
rm -f $X/spec0.img $X/spec1.img
truncate -s $(( data*11/10 + 1073741824 )) $X/spec0.img
mkfs.ext4 -F -q -L SPEC2017 -d $W/cpu2017 $X/spec0.img
e2fsck -fn $X/spec0.img >/dev/null 2>&1 || { echo "disk not clean"; exit 1; }
cp --sparse=always $X/spec0.img $X/spec1.img
echo "$(date +%T) launching"
for k in 0 1; do
  mkdir -p $X/run$k
  tmux new -d -s x87v2-$L-$k "LD_LIBRARY_PATH=$HOME/gcclib FS_KERNEL=$KERN FS_DISK=$ROOT $G -re --listener-mode=off -d $X/run$k $F --cores 1 --cpu timing --start-cpu atomic --script $X/guest$k.sh --spec-disk $X/spec$k.img; echo exited \$? > $X/run$k/EXITED"
done
sleep 15
echo "gem5 total: $(pgrep -c -x gem5.opt)"
