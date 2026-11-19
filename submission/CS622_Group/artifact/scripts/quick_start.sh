#!/usr/bin/env bash
# Getting-started check (SE mode, a few minutes once gem5 is built).
#
#   bash quick_start.sh <gem5_dir_built_with: build_design.sh <dir> colt --checker>
#
# Builds the test programs, then runs two small SE-mode jobs on the CoLT-FA
# design with the translation oracle on: the CoLT microbenchmark and an
# ascending page walk, once with COLT_ENABLE=1 and once with COLT_ENABLE=0
# (= plain NINE from the same binary). Prints PASS/FAIL, oracle mismatches,
# CoLT hits and page walks. Expected: oracle mismatches 0 everywhere; CoLT
# hits > 0 only with COLT_ENABLE=1; fewer walks with CoLT on.
# To try your own program: QS_PROG=/path/to/static_binary QS_ARGS="..." bash quick_start.sh <gem5_dir>
set -uo pipefail
G=${1:?gem5 dir}; HERE=$(cd "$(dirname "$0")" && pwd); B=$HERE/../benchmarks
OUT=${QS_OUT:-/var/tmp/$(id -un)/quickstart}; mkdir -p "$OUT/bin"
for s in "$B"/tests/pf_patterns.c "$B"/microbench/tlb_colt_bench.c; do
  ${CC:-gcc} -O2 -static -o "$OUT/bin/$(basename "$s" .c)" "$s"
done
run() {  # name prog args colt
  local d=$OUT/$1_colt$4; rm -rf "$d"; mkdir -p "$d"
  (cd "$d" && COLT_ENABLE=$4 TLBCHK_MAXWARN=20 "$G/build/X86/gem5.opt" -re -d . \
     "$G/configs/deprecated/example/se.py" --cpu-type AtomicSimpleCPU --mem-size 4GiB \
     -c "$2" ${3:+-o "$3"} > run.log 2>&1)
  local s=$d/stats.txt
  printf "%-22s colt=%s rc=%-3s %-28s oracleMismatch=%-3s coltHits=%-7s walks=%s\n" "$1" "$4" "$?" \
    "$(grep -aho 'RESULT [a-z_0-9]* [A-Z]*' "$d/simout.txt" | head -1)" \
    "$(grep -h 'dtb.chkOracleMismatch ' "$s" | awk '{print $2}')" \
    "$(grep -h 'dtb.coltHits ' "$s" | awk '{print $2}')" \
    "$(grep -h 'dtb.rdMisses \|dtb.wrMisses ' "$s" | awk '{s+=$2} END{print s}')"
}
if [[ -n ${QS_PROG:-} ]]; then
  for c in 1 0; do run custom "$QS_PROG" "${QS_ARGS:-}" $c; done; exit 0
fi
for c in 1 0; do
  run colt_bench "$OUT/bin/tlb_colt_bench" "" $c
  run ascending_16MB "$OUT/bin/pf_patterns" "asc 4096 4" $c
done
echo "outputs in $OUT"
