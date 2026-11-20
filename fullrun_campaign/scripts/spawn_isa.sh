#!/bin/bash
# usage: spawn_new.sh LANE SRCHOST "ids" [SRC_WORKDIR]
set -e
L=$1; SRC=$2; IDS=$3; SW=${4:-/tmp/sahilag24/work-$L}
S=sahilag24@$SRC.cse.iitk.ac.in
W=/tmp/sahilag24/work-$L; X=/tmp/sahilag24/extra-$L
GD=/tmp/sahilag24/CS622_L2_TLB/gem5-$L/build/X86
G=$GD/gem5.opt
F=$HOME/CS622_L2_TLB/robustness/scripts/fs_run.py
KERN=$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic
ROOT=$W/dl/x86-ubuntu-24.04.img
command -v rsync >/dev/null || { echo "no rsync"; exit 1; }
[ -f $F ] || { echo "no fs_run.py"; exit 1; }
[ -z "$(ls $X 2>/dev/null | grep -E '^(run|guest)')" ] || { echo "old run/guest files exist"; exit 1; }
mkdir -p $W/dl $W/jobs $X $GD
echo "$(date +%T) copying"
rsync -aS $S:$SW/dl/x86-ubuntu-24.04.img $S:$SW/dl/vmlinux-x86-ubuntu-6.8.0-52-generic $W/dl/
rsync -aS $S:/tmp/sahilag24/CS622_L2_TLB/gem5-$L-isa/build/X86/gem5.opt $GD/
rsync -aS $S:$SW/jobs/spec_fs_guest.sh $W/jobs/
rsync -aS $S:$SW/cpu2017/ $W/cpu2017/
[ -x $G ] && [ -f $KERN ] && [ -f $ROOT ] || { echo "copy failed"; exit 1; }
echo "$(date +%T) building disk"
data=$(du -sb $W/cpu2017 | cut -f1)
rm -f $X/spec0.img
truncate -s $(( data*11/10 + 1073741824 )) $X/spec0.img
mkfs.ext4 -F -q -L SPEC2017 -d $W/cpu2017 $X/spec0.img
e2fsck -fn $X/spec0.img >/dev/null 2>&1 || { echo "disk not clean"; exit 1; }
python3 - $W/jobs/spec_fs_guest.sh $X "$IDS" <<'PY'
import sys
src, X, ids = sys.argv[1], sys.argv[2], sys.argv[3].split()
L = open(src).read().split('\n')
idx = [i for i, l in enumerate(L) if l.startswith('echo SPEC_START ')]
head = L[:idx[0]]
blocks = [L[i:(idx[n+1] if n+1 < len(idx) else len(L))] for n, i in enumerate(idx)]
last = blocks[-1]
while last and last[-1].strip() == '': last.pop()
assert last[-2:] == ['sync', 'echo TLBFS-GUEST-DONE'], last[-3:]
del last[-2:]
names = [b[0].split()[2] for b in blocks]
for k, i in enumerate(ids):
    m = [n for n in range(len(blocks)) if names[n].split('.')[0] == i]
    assert len(m) == 1, i
    out = head[:] + blocks[m[0]] + ['sync', 'echo TLBFS-GUEST-DONE', '']
    open(f'{X}/guest{k}.sh', 'w').write('\n'.join(out))
    print('slice', k, names[m[0]])
PY
K=$(ls $X/guest*.sh | wc -l)
for k in $(seq 1 $((K-1))); do cp --sparse=always $X/spec0.img $X/spec$k.img & done; wait
echo "$(date +%T) launching $K guests"
for k in $(seq 0 $((K-1))); do
  mkdir -p $X/run$k
  tmux new -d -s extra-$L-$k "LD_LIBRARY_PATH=$HOME/gcclib FS_KERNEL=$KERN FS_DISK=$ROOT $G -re --listener-mode=off -d $X/run$k $F --cores 1 --cpu timing --start-cpu atomic --script $X/guest$k.sh --spec-disk $X/spec$k.img; echo exited \$? > $X/run$k/EXITED"
done
sleep 20
echo "gem5 processes: $(pgrep -fc "gem5.opt .*extra-$L/run")"
