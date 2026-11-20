#!/bin/bash
set -e
L=$1; BH=$2; XH=$3; MH=$4; D=cse.iitk.ac.in
W=/tmp/sahilag24/work-$L; X=/tmp/sahilag24/extra-x87atom-$L; XB=/tmp/sahilag24/x87bin2-$L
rm -rf $X; mkdir -p $W/dl $XB $X
rsync -aS sahilag24@$MH.$D:$W/dl/x86-ubuntu-24.04.img sahilag24@$MH.$D:$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic $W/dl/
rsync -aS sahilag24@$BH.$D:/tmp/sahilag24/CS622_L2_TLB/gem5-$L-fix/build/X86/gem5.opt $XB/
rsync -a sahilag24@$XH.$D:/tmp/sahilag24/extra-x87-$L/guest0.sh sahilag24@$XH.$D:/tmp/sahilag24/extra-x87-$L/guest1.sh $X/
rsync -aS sahilag24@$MH.$D:$W/cpu2017/ $W/cpu2017/
data=$(du -sb $W/cpu2017 | cut -f1)
truncate -s $(( data*11/10 + 1073741824 )) $X/spec0.img
mkfs.ext4 -F -q -L SPEC2017 -d $W/cpu2017 $X/spec0.img
cp --sparse=always $X/spec0.img $X/spec1.img
for k in 0 1; do
  mkdir -p $X/run$k
  tmux new -d -s x87atom-$L-$k "LD_LIBRARY_PATH=$HOME/gcclib FS_KERNEL=$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic FS_DISK=$W/dl/x86-ubuntu-24.04.img $XB/gem5.opt -re --listener-mode=off -d $X/run$k $HOME/CS622_L2_TLB/robustness/scripts/fs_run_atomic.py --cores 1 --cpu timing --start-cpu atomic --script $X/guest$k.sh --spec-disk $X/spec$k.img; echo exited \$? > $X/run$k/EXITED"
done
sleep 5
echo "DONE x87atom $L gem5=$(pgrep -x gem5.opt | wc -l)"
