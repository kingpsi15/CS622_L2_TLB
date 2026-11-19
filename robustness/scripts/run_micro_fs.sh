#!/usr/bin/env bash
# Full-system TLB microbenchmarks for one lane: one gem5 per microbenchmark,
# whole run measured on the timing CPU (warm 1 inst, window up to 3G insts),
# simulation ends after the dump. Binaries live in $SPEC/tlbbench (baked into
# spec2017.fs.img by provision_fs_host.sh).   bash run_micro_fs.sh <lane>
set -uo pipefail
LANE=${1:?lane}; SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export VARIANT="$LANE"; source "$SCRIPT_DIR/env.sh"
TREE=/tmp/${TLB_USER:-$(id -un)}/CS622_L2_TLB/gem5-$LANE; GEM5=$TREE/build/X86/gem5.opt
OUT=/tmp/$(id -un)/micro/micro_${LANE}_$(date +%Y%m%d_%H%M%S); mkdir -p "$OUT"
declare -A M=(
 [gups_512M]="gups 512 2"            [chase_256M]="pf_patterns chase 65536 4"
 [random_256M]="pf_patterns random 65536 4" [hotcold_256M]="pf_patterns hotcold 65536 4"
 [stride8_256M]="pf_patterns s8 65536 4"    [seq_256M]="pf_patterns asc 65536 4"
 [holes_dispersed]="perf_holes dispersed 16 6" [holes_clustered]="perf_holes clustered 16 6"
 [holes_sparse]="perf_holes sparse 16 6"    [colt_8M]="tlb_colt_bench"
 [perfpages_32M]="tlb_perfpages_bench"      [stress_conflict]="tlbstress conflict"
 [stress_huge]="tlbstress huge" )
for name in "${!M[@]}"; do
  d=$OUT/$name; mkdir -p "$d"; cmd=${M[$name]}
  cat > "$d/guest.sh" <<G
#!/bin/bash
if [ "\$(id -u)" != 0 ]; then sudo -n bash "\$0" "\$@"; exit 0; fi
set +e; ulimit -s unlimited; exec > /dev/ttyS0 2>&1
SPEC=$SPEC; mkdir -p "\$SPEC"; mount -t ext4 -o rw LABEL=SPEC2017 "\$SPEC" || { echo MICRO_SETUP_FAIL mount; echo TLBFS-GUEST-DONE; exit 0; }
echo always > /sys/kernel/mm/transparent_hugepage/enabled
echo MICRO_THP \$(cat /sys/kernel/mm/transparent_hugepage/enabled)
GB=\$(command -v gem5-bridge || command -v m5 || ls /usr/local/bin/gem5-bridge /sbin/m5 2>/dev/null | head -1)
cd /tmp; echo MICRO_START $name
"\$GB" hypercall 10; "\$GB" hypercall 11
"\$SPEC/tlbbench/$cmd" > /tmp/out.txt 2>&1; rc=\$?
"\$GB" hypercall 12
echo "MICRO_RESULT $name rc=\$rc \$(tail -n 2 /tmp/out.txt | tr '\n' ' ')"
echo TLBFS-GUEST-DONE
G
  (cd "$TREE" && exec "$GEM5" -re -d "$d" "$SCRIPT_DIR/fs_run.py" --cores 1 --cpu atomic --start-cpu atomic \
     --script "$d/guest.sh" --spec-disk "$W/spec2017.fs.img" --window-insts 3000000000 --window-warm 1 \
     --window-cpu timing --window-benches "$name" --window-exit) > "$d/gem5_host.log" 2>&1 &
  echo "micro $name pid $!"
done
echo "$OUT" > /tmp/$(id -un)/micro/LATEST_$LANE
wait
