#!/bin/bash
# Build + (incrementally) rebuild the EXCLUSIVE-TLB lane's exclusivity-checked
# trees: BEFORE = original tlb.cc.exclusive.sa + apply_checker_excl.py,
# AFTER = tlb.cc.excl.fixed (the fix) + apply_checker_excl.py. One rsync'd
# tree is reused for both (only tlb.cc/tlb.hh differ -> fast incremental
# scons relink between them). Stock baseline is NOT rebuilt here; it is
# assumed already built by machine_run.sh excl at $BASE (set in env.sh).
#
# usage: excl_fixed_build.sh {before|after}
set -e
STAGE=$1; [ "$STAGE" = before ] || [ "$STAGE" = after ] || { echo "usage: $0 before|after"; exit 1; }
export VARIANT=excl; source "$(dirname "$0")/env.sh"
SRC=$H/gem5/src/arch/x86
FIX=$SRC
CHKTREE=${EXCL_CHECK_TREE:-$W/gem5-excl}
J=${JOBS:-16}

scons_build() { ( cd "$CHKTREE" && PYTHONPATH=/tmp/sahilag24/sc /usr/bin/python3 -m SCons build/X86/gem5.opt -j "$J" --linker=gold --ignore-style ) > "$W/logs/scons_excl_chk_$STAGE.log" 2>&1; }
link() {
  sed "s|^T=\$INC|T=$CHKTREE|; s|stamps/build_\$VARIANT|stamps/linked_chk_$STAGE|; s|O=\$W/elfobj|O=$W/elfobj_chk_$STAGE|; s|\\\$(dirname \"\\\$0\")/env.sh|$R/scripts/env.sh|" "$R/scripts/manual_link.sh" > "$W/ml_chk_$STAGE.sh"
  VARIANT=$VARIANT bash "$W/ml_chk_$STAGE.sh"
}

if [ ! -d "$CHKTREE" ]; then
  if [ -x "$W/gem5-excl/build/X86/gem5.opt" ]; then
    log "[excl-chk] seed checker tree from completed lane build -> $CHKTREE"
    cp -a "$W/gem5-excl" "$CHKTREE"
  else
    log "[excl-chk] rsync fresh tree -> $CHKTREE"
    rsync -a --delete --exclude=.git --exclude=build --exclude=results_v2 --exclude=presentation "$H/gem5/" "$CHKTREE/"
    find "$CHKTREE" -type f -exec grep -l -m1 '^#!' {} \; 2>/dev/null | xargs -r chmod +x
  fi
fi

if [ "$STAGE" = before ]; then
  cp "$SRC/tlb.cc.exclusive.sa" "$CHKTREE/src/arch/x86/tlb.cc"
  cp "$SRC/tlb.hh.exclusive.sa" "$CHKTREE/src/arch/x86/tlb.hh"
else
  cp "$FIX/tlb.cc.excl.fixed" "$CHKTREE/src/arch/x86/tlb.cc"
  cp "$FIX/tlb.hh.excl.fixed" "$CHKTREE/src/arch/x86/tlb.hh"
fi
python3 "$R/patches/apply_checker_excl.py" "$CHKTREE" excl

log "[excl-chk] $STAGE build: START"
scons_build || { log "[excl-chk] $STAGE build: scons FAILED (see $W/logs/scons_excl_chk_$STAGE.log)"; exit 1; }
link || { log "[excl-chk] $STAGE build: link FAILED"; exit 1; }
cp "$CHKTREE/build/X86/gem5.opt" "$CHKTREE/build/X86/gem5.opt.$STAGE"
log "[excl-chk] $STAGE build: OK -> gem5.opt.$STAGE"
