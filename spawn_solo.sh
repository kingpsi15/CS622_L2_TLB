#!/bin/bash
set -e
export RSYNC_RSH="ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes"
L=$1; B=$2; BH=$3; MH=$4; D=cse.iitk.ac.in
W=/tmp/sahilag24/work-$L; X=/tmp/sahilag24/extra-solo-$L-$B; BD=/tmp/sahilag24/fixbin-$L
rm -rf $X; mkdir -p $W/dl $BD $X/run0
rsync -aS sahilag24@$MH.$D:$W/dl/x86-ubuntu-24.04.img sahilag24@$MH.$D:$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic $W/dl/
rsync -aS sahilag24@$BH.$D:/tmp/sahilag24/CS622_L2_TLB/gem5-$L-fix/build/X86/gem5.opt $BD/
rsync -aS sahilag24@$BH.$D:/tmp/sahilag24/extra-$L/spec0.img $X/spec0.img
cat > $X/guest0.sh <<G
#!/bin/bash
[ "\$(id -u)" != 0 ] && exec sudo -n bash "\$0" "\$@"
set +e; ulimit -s unlimited; exec > /dev/ttyS0 2>&1
mkdir -p /mnt/spec && mount -t ext4 -o rw LABEL=SPEC2017 /mnt/spec
echo "SPEC_FS_GUEST_READY path=/mnt/spec"
cd /mnt/spec && source ./shrc && mkdir -p /mnt/spec/fs-results
echo SPEC_START $B
/mnt/spec/bin/runcpu --config=gem5-static --nobuild --action=run --size=test --noreportable --iterations=1 $B > /mnt/spec/fs-results/$B.log 2>&1
rc=\$?
if [ "\$rc" -eq 0 ] && grep "^Success:" /mnt/spec/fs-results/$B.log | grep -Fq 1x$B; then
  echo "SPEC_RESULT $B PASS rc=\$rc"
else
  echo "SPEC_RESULT $B FAIL rc=\$rc"; tail -n 8 /mnt/spec/fs-results/$B.log
fi
sync; echo TLBFS-GUEST-DONE
G
tmux new -d -s solo-$L-$B "LD_LIBRARY_PATH=$HOME/gcclib FS_MEM=8GiB FS_KERNEL=$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic FS_DISK=$W/dl/x86-ubuntu-24.04.img $BD/gem5.opt -re --listener-mode=off -d $X/run0 $HOME/CS622_L2_TLB/robustness/scripts/fs_run_big.py --cores 1 --cpu timing --start-cpu atomic --script $X/guest0.sh --spec-disk $X/spec0.img; echo exited \$? > $X/run0/EXITED"
echo "STARTED solo-$L-$B on $(hostname -s)"
