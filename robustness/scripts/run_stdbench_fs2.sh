#!/usr/bin/env bash
# Well-known memory/TLB benchmarks in full-system gem5, one gem5 per benchmark:
# GAPBS bfs/pr/cc (Kronecker / uniform-random 2^20-vertex graphs, pre-generated),
# XSBench (event mode), STREAM, memcached 1.6.29 + mc-crusher (random GETs).
# Binaries + inputs on a small ext4 disk labelled SPEC2017 (built here from
# ~/stdbench_bin). Atomic warm-up W insts, then N insts on the timing CPU,
# simulation ends after the dump.      bash run_stdbench_fs.sh <lane>
set -uo pipefail
LANE=${1:?lane}; SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export VARIANT="$LANE"; source "$SCRIPT_DIR/env.sh"
TREE=/tmp/${TLB_USER:-$(id -un)}/CS622_L2_TLB/gem5-$LANE; GEM5=$TREE/build/X86/gem5.opt
IMG=/tmp/$(id -un)/stdbench.img
if [[ ! -s $IMG ]]; then truncate -s 2G "$IMG"; /sbin/mkfs.ext4 -F -q -L SPEC2017 -d "$HOME/stdbench_bin" "$IMG"; fi
OUT=/tmp/$(id -un)/std/std_${LANE}${STD_TAG:+_$STD_TAG}_$(date +%Y%m%d_%H%M%S); mkdir -p "$OUT"
# name | warm insts | window insts | command (relative to the disk root; @ = handles its own hypercalls)
cat > "$OUT/benches.txt" <<'B'
gapbs_bfs_kron20|250000000|1000000000|gapbs_bfs -f kron20.sg -n 8
gapbs_pr_kron20|250000000|1000000000|gapbs_pr -f kron20.sg -i 10 -n 1
gapbs_cc_urand20|250000000|1000000000|gapbs_cc -f urand20.sg -n 4
xsbench_small_event|2600000000|500000000|xsbench -t 1 -s small -m event -l 2000000
stream_20M|100000000|500000000|stream
memcached_randget|1|1500000000|@run_memcached.sh
B
while IFS='|' read -r name warm win cmd; do
  d=$OUT/$name; mkdir -p "$d"
  if [[ $cmd == @* ]]; then run="WIN_BEGIN=\"\$GB hypercall 11\" WIN_END=\"\$GB hypercall 12\" \"\$D/${cmd#@}\""
  else run="\"\$GB\" hypercall 11; (cd \"\$D\" && ./$cmd); rc=\$?; \"\$GB\" hypercall 12"; fi
  cat > "$d/guest.sh" <<G
#!/bin/bash
if [ "\$(id -u)" != 0 ]; then sudo -n bash "\$0" "\$@"; exit 0; fi
set +e; ulimit -s unlimited; exec > /dev/ttyS0 2>&1
D=/mnt/std; mkdir -p \$D; mount -t ext4 -o rw LABEL=SPEC2017 \$D || { echo STD_SETUP_FAIL mount; echo TLBFS-GUEST-DONE; exit 0; }
echo ${THP:-always} > /sys/kernel/mm/transparent_hugepage/enabled
GB=\$(command -v gem5-bridge || command -v m5 || ls /usr/local/bin/gem5-bridge /sbin/m5 2>/dev/null | head -1)
cd \$D; echo STD_START $name
"\$GB" hypercall 10
$run > /tmp/out.txt 2>&1; rc=\$?
echo "STD_RESULT $name rc=\$rc \$(grep -i 'RESULT\|Verification\|Average\|Triad\|Lookups/s' /tmp/out.txt | tail -n 3 | tr '\n' ' ')"
echo TLBFS-GUEST-DONE
G
  (cd "$TREE" && exec "$GEM5" -re -d "$d" "$SCRIPT_DIR/fs_run.py" --cores 1 --cpu atomic --start-cpu atomic \
     --script "$d/guest.sh" --spec-disk "$IMG" --window-insts "$win" --window-warm "$warm" \
     --window-cpu timing --window-benches "$name" --window-exit) > "$d/gem5_host.log" 2>&1 &
  echo "std $name pid $!"
done < "$OUT/benches.txt"
echo "$OUT" > /tmp/$(id -un)/std/LATEST_${LANE}${STD_TAG:+_$STD_TAG}
wait
