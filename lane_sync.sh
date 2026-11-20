source ~/lane_common.sh
MODE=${1:-check}
for e in $SPEC/benchspec/CPU/*/exe/*gem5static*; do
  b=$(basename $(dirname $(dirname $e)))
  for d in $SPEC/benchspec/CPU/$b/run/run_base_test_gem5static*; do
    [ -d "$d" ] || continue
    cmp -s "$e" "$d/$(basename $e)" && continue
    echo "DIFF $b $(basename $d)"
    [ "$MODE" = fix ] && cp -p "$e" "$d/"
  done
done
echo "sync $MODE done"
