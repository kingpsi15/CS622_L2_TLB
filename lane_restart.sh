source ~/lane_common.sh
set -u
echo "=== $H lane=$L work=$W"
rm -f /tmp/sahilag24/gate-$L.ok

echo "[1/6] config"
python3 ~/patch_spec_cfg.py $SPEC/config/gem5-static.cfg || exit 1

echo "[2/6] rebuild the 8 and run them natively"
cd $SPEC && source ./shrc >/dev/null 2>&1
runcpu --config=gem5-static --action=build --rebuild --size=test --noreportable $B > /tmp/sahilag24/build-fix-$L.log 2>&1
grep "^Build successes\|Build errors" /tmp/sahilag24/build-fix-$L.log | cut -c1-200
( ulimit -s unlimited; runcpu --config=gem5-static --nobuild --action=run --size=test --noreportable --iterations=1 $B > /tmp/sahilag24/native-fix-$L.log 2>&1 )
grep "^Success:\|^Error:" /tmp/sahilag24/native-fix-$L.log | cut -c1-250
n=$(grep '^Success:' /tmp/sahilag24/native-fix-$L.log | grep -o '1x[0-9]' | wc -l)
if [ "$n" != 8 ] || grep -q '^Error:' /tmp/sahilag24/native-fix-$L.log; then echo "ABORT: native gate $n/8. Old run left untouched. Paste the lines above."; exit 1; fi

echo "[3/6] sync run directories with exes"
cat > /tmp/sahilag24/sync-$L.sh <<'X'
source ~/lane_common.sh
for e in $SPEC/benchspec/CPU/*/exe/*gem5static*; do
  b=$(basename $(dirname $(dirname $e)))
  for d in $SPEC/benchspec/CPU/$b/run/run_base_test_gem5static*; do
    [ -d "$d" ] || continue
    cmp -s "$e" "$d/$(basename $e)" || { echo "FIXED $b $(basename $d)"; cp -p "$e" "$d/"; }
  done
done
X
bash /tmp/sahilag24/sync-$L.sh
bash /tmp/sahilag24/sync-$L.sh | grep -q FIXED && { echo "ABORT: run dirs still differ"; exit 1; }
ne=$(ls $SPEC/benchspec/CPU/*/exe/*gem5static* 2>/dev/null | wc -l)
echo "exe files: $ne"

echo "[4/6] stop the old guest run"
touch /tmp/sahilag24/kill-$L
pkill -f -- "gem5.opt -re -d $W/runs"; sleep 5
pgrep -af gem5.opt | grep -- "-d $W/runs" && { echo "ABORT: gem5 still alive, run kill -9"; exit 1; }
echo "[5/6] wait for supervisor BLOCKED"
for i in $(seq 1 60); do
  if [ -n "$(find $R/results-$L -name 'incident-*.md' -newer /tmp/sahilag24/kill-$L 2>/dev/null)" ] && grep -q BLOCKED $R/comms/hb_$L.txt; then ok=1; break; fi
  sleep 20
done
[ "${ok:-0}" = 1 ] || { echo "ABORT: supervisor not BLOCKED after 20 min: $(cut -c1-100 $R/comms/hb_$L.txt)"; exit 1; }

echo "[6/6] clean and resume from scratch"
rm -f $W/spec2017.fs.img $R/results-$L/spec_fs_pass_cache.tsv
echo "[ADMIN $(date +%F_%T)] RESUME $L: all fixes in place (sudoers, pthread, omnetpp C++14, ulimit, run dirs synced); full rerun of all 43" >> $R/comms/to_$L.md
echo "RESUMED $L"
