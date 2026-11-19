#!/usr/bin/env bash
# Parallel full-system SPEC run for one lane: K gem5 processes, each boots its
# own guest and runs a slice of the benchmark list. Root disk and SPEC disk are
# copy-on-write, so all shards share the same image files read-only.
#
#   bash run_spec_fs_shards.sh <lane> <K> [atomic|timing] [bench ...]
#
# Assets may belong to another account: TLB_USER=sahilag24 reuses its gem5
# build, SPEC tree and disks read-only; output goes to /tmp/$(id -un)/runs.
# Timing windows: WINDOW_INSTS=N [WINDOW_WARM=W WINDOW_CPU=timing|o3] -> per
# benchmark, W atomic warm-up insts then N detailed insts, stats dumped.
# Run inside tmux. Output: $W/runs/shard_<lane>_<ts>/s<i>/ (board.pc.com_1.device
# has SPEC_RESULT lines). Summary: $W/runs/shard_<lane>_<ts>/summary.tsv and
# robustness/results-<lane>/spec_fs_shard_results.tsv.
set -uo pipefail
LANE=${1:?lane}; K=${2:?shards}; CPU=${3:-atomic}; shift 3 || shift $#
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
export VARIANT="$LANE"; source "$SCRIPT_DIR/env.sh"
TREE=/tmp/${TLB_USER:-$(id -un)}/CS622_L2_TLB/gem5-$LANE
GEM5=$TREE/build/X86/gem5.opt
SPEC_DISK=${SPEC_DISK:-$W/spec2017.fs.img}   # read-only base; guest writes are COW
OUT_ROOT=${SHARD_OUT_ROOT:-/tmp/$(id -un)/runs}   # always writable by the caller
[[ -x $GEM5 && -s $SPEC_DISK && -s $FS_DISK && -s $FS_KERNEL ]] || { echo "missing gem5/disk/kernel"; exit 1; }
start_cpu=atomic; [[ -r /dev/kvm && -w /dev/kvm ]] && start_cpu=kvm

if (( $# )); then benches=("$@"); else
  mapfile -t benches < <(ls "$SPEC/benchspec/CPU" | grep -E '^[56][0-9]{2}\.' | sort)
fi
# Round-robin so long and short benchmarks mix across shards.
TAG=$CPU; [[ ${WINDOW_INSTS:-0} -gt 0 ]] && TAG=${CPU}win${WINDOW_CPU:-timing}
TS=$(date +%Y%m%d_%H%M%S); OUT=$OUT_ROOT/shard_${LANE}_${TAG}_$TS; mkdir -p "$OUT"
for ((i=0;i<K;i++)); do sl[$i]=""; done
for ((j=0;j<${#benches[@]};j++)); do i=$((j%K)); sl[$i]="${sl[$i]} ${benches[$j]}"; done

pids=()
for ((i=0;i<K;i++)); do
  [[ -n ${sl[$i]// } ]] || continue
  d=$OUT/s$i; mkdir -p "$d"
  echo "${sl[$i]}" > "$d/benches.txt"
  SPEC_FS_WINDOW=$([[ ${WINDOW_INSTS:-0} -gt 0 ]] && echo 1) \
  SPEC_FS_BENCHES="${sl[$i]}" SPEC_FS_GUEST_SCRIPT=$d/guest.sh SPEC_FS_BENCH_LIST=$d/bench_list.txt \
    "$PYTHON_BIN" "$SCRIPT_DIR/gen_spec_fs_guest.py" > "$d/gen.txt"
  wb=$(tr '\n' ' ' < "$d/bench_list.txt")
  (cd "$TREE" && exec "$GEM5" -re -d "$d" "$SCRIPT_DIR/fs_run.py" --cores 1 --cpu "$CPU" \
      --start-cpu "$start_cpu" --script "$d/guest.sh" --spec-disk "$SPEC_DISK" \
      --window-insts "${WINDOW_INSTS:-0}" --window-warm "${WINDOW_WARM:-100000000}" \
      --window-cpu "${WINDOW_CPU:-timing}" --window-benches "$wb" ${WINDOW_EXIT:+--window-exit}) > "$d/gem5_host.log" 2>&1 &
  pids+=($!); echo "shard $i pid $! :${sl[$i]}"
done
echo "$OUT" > "$OUT_ROOT/LATEST_${LANE}"
wait "${pids[@]}"

printf 'lane\tbenchmark\tverdict\tdetail\n' > "$OUT/summary.tsv"
for d in "$OUT"/s*; do
  for b in $(cat "$d/benches.txt"); do
    r=$(grep -a "^SPEC_RESULT $b " "$d/board.pc.com_1.device" 2>/dev/null | tail -1)
    if [[ -n $r ]]; then v=$(awk '{print $3}' <<<"$r"); det=$(cut -d' ' -f4- <<<"$r")
    else v=FAIL; det="no-result$(grep -qa 'panic\|fatal' "$d/simerr.txt" 2>/dev/null && echo ' gem5-died')"; fi
    printf '%s\t%s\t%s\t%s\n' "$LANE" "$b" "$v" "$det" >> "$OUT/summary.tsv"
  done
done
mkdir -p "$ROOT/robustness/results-$LANE"
sed "s/^/$TS\t$CPU\t/" "$OUT/summary.tsv" | tail -n +2 >> "$ROOT/robustness/results-$LANE/spec_fs_shard_results.tsv"
echo "DONE $OUT: $(grep -c $'\tPASS\t' "$OUT/summary.tsv") PASS / $(($(wc -l < "$OUT/summary.tsv")-1))"
