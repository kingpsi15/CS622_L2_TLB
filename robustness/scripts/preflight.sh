#!/usr/bin/env bash
# Offline preflight for a full-system SPEC lane. Boots nothing.
LANE=${1:-}; [[ -n $LANE ]] || { echo "usage: preflight.sh <lane>"; exit 2; }
W=/tmp/$USER/work-$LANE; [[ $LANE == inc ]] && W=/tmp/$USER/work
IMG=$W/dl/x86-ubuntu-24.04.img; SPEC_IMG=$W/spec2017.fs.img; SPEC=$W/cpu2017
export PAGER=cat; bad=0
ok(){ echo "ok    $*"; }; no(){ echo "FAIL  $*"; bad=1; }
dbg(){ debugfs -R "$1" "$2" 2>/dev/null; }

for f in "$IMG" "$SPEC_IMG" "$SPEC/shrc"; do
  [[ -e $f ]] || { echo "FAIL  missing $f (wrong host, or /tmp was wiped)"; exit 1; }
done
pgrep -af gem5.opt | grep -q "$W" && echo "note  gem5 is running on $W (patching now is unsafe)"

OFF=$(( $(fdisk -l "$IMG" 2>/dev/null | awk '/img2/{print $2}') * 512 ))
[[ $OFF -eq 2097152 ]] && ok "image offset" || no "image offset $OFF"
dbg "ls -l /etc/sudoers.d" "$IMG?offset=$OFF" | grep -Eq '100440 .* 0 +0 .*90-gem5' && ok "sudoers file mode/owner" || no "sudoers file mode/owner"
dbg "cat /etc/sudoers.d/90-gem5" "$IMG?offset=$OFF" | grep -q NOPASSWD && ok "NOPASSWD rule" || no "NOPASSWD rule"
dbg "cat /etc/sudoers" "$IMG?offset=$OFF" | grep -q '@includedir /etc/sudoers.d' && ok "sudoers include" || no "sudoers include"

file "$SPEC_IMG" | grep -q 'SPEC2017' && ok "SPEC disk label" || no "SPEC disk label"
for f in /shrc /bin/harness/runcpu /config/gem5-static.cfg /config/gem5-static-parest.cfg; do
  dbg "stat $f" "$SPEC_IMG" | grep -q Inode && ok "disk has $f" || no "disk missing $f"
done

missing=0
for b in $(ls "$SPEC/benchspec/CPU" | grep -E '^[56][0-9]{2}\.'); do
  dbg "ls /benchspec/CPU/$b/exe" "$SPEC_IMG" | grep -q gem5static || { echo "note  no gem5static exe on disk: $b"; missing=$((missing+1)); }
done
echo "note  $missing benchmark(s) have no exe on the disk (the guest reports these as FAIL missing-build)"

if cd "$SPEC"; then
  out=$(source ./shrc >/dev/null 2>&1; runcpu --config=gem5-static --nobuild --action=run \
        --size=test --iterations=1 --fake 505.mcf_r 2>&1); rc=$?
  [[ $rc -eq 0 ]] && ok "shrc + runcpu --fake 505.mcf_r from SPEC dir" || { no "runcpu --fake rc=$rc"; echo "$out" | tail -5; }
else no "cannot cd $SPEC"; fi

echo; [[ $bad -eq 0 ]] && echo "PREFLIGHT PASS" || echo "PREFLIGHT FAIL"
