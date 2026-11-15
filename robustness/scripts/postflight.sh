#!/usr/bin/env bash
# Offline checks for everything AFTER shrc in the guest. Boots nothing.
LANE=${1:-}; [[ -n $LANE ]] || { echo "usage: postflight.sh <lane>"; exit 2; }
W=/tmp/$USER/work-$LANE; [[ $LANE == inc ]] && W=/tmp/$USER/work
IMG=$W/dl/x86-ubuntu-24.04.img; S=$W/spec2017.fs.img; SPEC=$W/cpu2017; OFF=2097152
export PAGER=cat; bad=0
ok(){ echo "ok    $*"; }; no(){ echo "FAIL  $*"; bad=1; }
dbg(){ debugfs -R "$1" "$2" 2>/dev/null; }

# 1. free space on the SPEC disk (run dirs and logs are written there)
fb=$(dumpe2fs -h "$S" 2>/dev/null | awk -F: '/^Free blocks/{f=$2}/^Block size/{b=$2}END{printf "%d", f*b/1073741824}')
[[ ${fb:-0} -ge 3 ]] && ok "SPEC disk free: ${fb} GiB" || no "SPEC disk free only ${fb:-?} GiB"

# 2. benchmark exes must be static (the guest cannot supply libs for them)
dyn=$(file "$SPEC"/benchspec/CPU/*/exe/*gem5static* 2>/dev/null | grep -vc 'statically linked')
[[ $dyn -eq 0 ]] && ok "all benchmark exes static" || no "$dyn exes are dynamically linked"

# 3. shared libs that SPEC's own tools need must exist in the guest OS image
for t in specperl specinvoke specmake specdiff; do
  p=$SPEC/bin/$t; [[ -x $p ]] || { echo "note  no $p"; continue; }
  libs=$(readelf -d "$p" 2>/dev/null | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p')
  [[ -z $libs ]] && echo "note  $t has no shared libs (static)"
  for l in $libs; do
    dbg "stat /usr/lib/x86_64-linux-gnu/$l" "$IMG?offset=$OFF" | grep -q Inode \
      && ok "guest has $l ($t)" || no "guest MISSING $l needed by $t"
  done
done

# 4. test inputs present on the SPEC disk
b0=$bad
for b in $(ls "$SPEC/benchspec/CPU" | grep -E '^[56][0-9]{2}\.'); do
  dbg "ls /benchspec/CPU/$b/data" "$S" | grep -Eq 'test|all' || no "no data/test or data/all on disk: $b"
done
[[ $bad -eq $b0 ]] && ok "test inputs on disk for every benchmark"

# 5. run the EXACT guest command natively on the host (exes are plain static x86).
#    Writes run dirs into the host cpu2017 tree, not into the guest disk image.
#    ALL=1 runs every benchmark (long; use tmux). MEMKB=3000000 caps memory like the 3 GB guest.
cd "$SPEC" || { no "cannot cd $SPEC"; exit 1; }
source ./shrc >/dev/null 2>&1
if [[ -n ${ALL:-} ]]; then
  list=$(for b in $(ls benchspec/CPU | grep -E '^[56][0-9]{2}\.'); do ls benchspec/CPU/$b/exe/*gem5static* >/dev/null 2>&1 && echo $b; done)
else list=505.mcf_r; fi
log=/tmp/$USER/postflight-$LANE.log
( [[ -n ${MEMKB:-} ]] && ulimit -v "$MEMKB"
  runcpu --config=gem5-static --nobuild --action=run --size=test --noreportable --iterations=1 $list >"$log" 2>&1 )
for b in $list; do
  grep "^Success:" "$log" | grep -Fq "1x$b" && ok "native Success: $b" || no "native run did not succeed: $b"
done
echo "log: $log"
echo; [[ $bad -eq 0 ]] && echo "POSTFLIGHT PASS" || echo "POSTFLIGHT FAIL"
