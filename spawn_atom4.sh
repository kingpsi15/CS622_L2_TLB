#!/bin/bash
set -e
L=$1; BH=$2; SH=$3; MH=$4; D=cse.iitk.ac.in
W=/tmp/sahilag24/work-$L; X=/tmp/sahilag24/extra-atom4-$L; BD=/tmp/sahilag24/atombin-$L
rm -rf $X; mkdir -p $W/dl $BD $X
rsync -aS sahilag24@$MH.$D:$W/dl/x86-ubuntu-24.04.img sahilag24@$MH.$D:$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic $W/dl/
rsync -aS sahilag24@$BH.$D:/tmp/sahilag24/CS622_L2_TLB/gem5-$L-fix/build/X86/gem5.opt $BD/
for k in 1 2 4 5; do rsync -a sahilag24@$SH.$D:/tmp/sahilag24/extra-atomic-$L/guest$k.sh $X/guest$k.sh; done
rsync -aS sahilag24@$MH.$D:$W/cpu2017/ $W/cpu2017/
data=$(du -sb $W/cpu2017 | cut -f1)
truncate -s $(( data*11/10 + 1073741824 )) $X/spec_base.img
mkfs.ext4 -F -q -L SPEC2017 -d $W/cpu2017 $X/spec_base.img
for k in 1 2 4 5; do
  cp --sparse=always $X/spec_base.img $X/spec$k.img; mkdir -p $X/run$k
  tmux new -d -s atom4-$L-$k "LD_LIBRARY_PATH=$HOME/gcclib FS_KERNEL=$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic FS_DISK=$W/dl/x86-ubuntu-24.04.img $BD/gem5.opt -re --listener-mode=off -d $X/run$k $HOME/CS622_L2_TLB/robustness/scripts/fs_run_atomic.py --cores 1 --cpu timing --start-cpu atomic --script $X/guest$k.sh --spec-disk $X/spec$k.img; echo exited \$? > $X/run$k/EXITED"
done
rm -f $X/spec_base.img; echo "DONE atom4 $L gem5=$(pgrep -x gem5.opt | wc -l)"
