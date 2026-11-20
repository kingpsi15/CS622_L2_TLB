#!/bin/bash
source ~/lane_common.sh
K=${1:-6}
G=/tmp/sahilag24/CS622_L2_TLB/gem5-$L/build/X86/gem5.opt
F=$HOME/CS622_L2_TLB/robustness/scripts/fs_run.py
KERN=$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic
ROOT=$W/dl/x86-ubuntu-24.04.img
X=/tmp/sahilag24/extra-$L
[ -x $G ] && [ -f $KERN ] && [ -f $ROOT ] && [ -f $F ] || { echo "missing gem5/kernel/image/fs_run.py"; exit 1; }
avail=$(df -BG --output=avail /tmp | tail -n 1 | tr -dc 0-9)
need=$((K*17))
[ "$avail" -ge "$need" ] || { echo "only ${avail}G free, need ${need}G; use a smaller K"; exit 1; }
[ -e $X ] && { echo "$X exists; remove it first"; exit 1; }
mkdir -p $X
python3 - $W/jobs/spec_fs_guest.sh $K $X <<'PY'
import sys
src, K, X = sys.argv[1], int(sys.argv[2]), sys.argv[3]
L = open(src).read().split('\n')
idx = [i for i, l in enumerate(L) if l.startswith('echo SPEC_START ')]
head = L[:idx[0]]
blocks = [L[i:(idx[n+1] if n+1 < len(idx) else len(L))] for n, i in enumerate(idx)]
last = blocks[-1]
while last and last[-1].strip() == '': last.pop()
assert last[-2:] == ['sync', 'echo TLBFS-GUEST-DONE'], last[-3:]
del last[-2:]
names = [b[0].split()[2] for b in blocks]
fixed = ['520.omnetpp_r','620.omnetpp_s','603.bwaves_s','621.wrf_s','627.cam4_s','628.pop2_s','649.fotonik3d_s','654.roms_s']
order = [n for n in range(len(blocks)) if names[n] in fixed] + [n for n in range(len(blocks)) if names[n] not in fixed]
sl = [[] for _ in range(K)]
for r, n in enumerate(order): sl[r % K].append(n)
for k, s in enumerate(sl):
    out = head[:]
    for n in s: out += blocks[n]
    out += ['sync', 'echo TLBFS-GUEST-DONE', '']
    open(f'{X}/guest{k}.sh', 'w').write('\n'.join(out))
    print('slice', k, len(s), ' '.join(names[n] for n in s))
PY
[ -f $X/guest0.sh ] || { echo "slicing failed"; exit 1; }
bytes=$(du -sb $W/cpu2017 | cut -f1)
truncate -s $((bytes + bytes/10 + 1073741824)) $X/spec0.img
mkfs.ext4 -F -q -L SPEC2017 -d $W/cpu2017 $X/spec0.img || { echo "mkfs failed"; exit 1; }
for k in $(seq 1 $((K-1))); do cp --sparse=always $X/spec0.img $X/spec$k.img & done; wait
for k in $(seq 0 $((K-1))); do
  mkdir -p $X/run$k
  tmux new -d -s extra-$L-$k "FS_KERNEL=$KERN FS_DISK=$ROOT $G -re --listener-mode=off -d $X/run$k $F --cores 1 --cpu timing --start-cpu atomic --script $X/guest$k.sh --spec-disk $X/spec$k.img; echo exited \$? > $X/run$k/EXITED"
done
sleep 20
echo "extra gem5 processes: $(pgrep -fc "^/tmp/.*gem5.opt .*extra-$L/run")"
