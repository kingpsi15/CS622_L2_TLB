source ~/lane_common.sh
set -u
rm -f /tmp/sahilag24/gate-$L.ok
python3 ~/patch_spec_cfg.py $SPEC/config/gem5-static.cfg || exit 1
cd $SPEC && source ./shrc >/dev/null 2>&1
runcpu --config=gem5-static --action=build --rebuild --size=test --noreportable $B > /tmp/sahilag24/build-fix-$L.log 2>&1
grep "^Build successes\|Build errors" /tmp/sahilag24/build-fix-$L.log | cut -c1-200
( ulimit -s unlimited; runcpu --config=gem5-static --nobuild --action=run --size=test --noreportable --iterations=1 $B > /tmp/sahilag24/native-fix-$L.log 2>&1 )
grep "^Success:\|^Error:" /tmp/sahilag24/native-fix-$L.log | cut -c1-250
bash ~/lane_sync.sh fix
n=$(grep '^Success:' /tmp/sahilag24/native-fix-$L.log | grep -o '1x[0-9]' | wc -l)
if [ "$n" = 8 ] && ! grep -q '^Error:' /tmp/sahilag24/native-fix-$L.log; then touch /tmp/sahilag24/gate-$L.ok; echo "GATE PASSED: $L"; else echo "GATE FAILED ($n/8): paste the lines above"; fi
