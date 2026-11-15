#!/bin/bash
# SELF-CONTAINED per-machine campaign (no interactive session needed). usage: machine_run.sh <inc|excl|nine|agile|perf>
# Builds gem5 (lane TLB + stock baseline) in THIS machine's /tmp from the home repo, runs the lane's SE matrix with
# the translation oracle, writes tables to ~/CS622_L2_TLB/robustness/results-<lane>/ and key lines to the lane log (shared NFS home).
# Local /tmp is private to each machine, so five machines never collide. Safe to re-run (stamps).
LANE=$1; [ -n "$LANE" ] || { echo "usage: $0 lane"; exit 1; }
export VARIANT=$LANE; source "$(dirname "$0")/env.sh"
export HOSTN=$(hostname); export SHARED=$W          # each machine: its own shared dir = its own lane dir
log "[$HOSTN] machine_run $LANE: START (W=$W)"
case $LANE in
  inc)   SNAP=inc.fixed ;; excl) SNAP=excl.fixed ;; nine) SNAP=nine.fixed ;;
  agile) SNAP=agile.fixed ;; perf) SNAP=perf.fixed ;;
esac
SRC=$H/gem5/src/arch/x86
# Prefer the audited .fixed snapshot when present; fall back to the original
# lane snapshot only if a fixed variant does not exist for this architecture.
for candidate in "$SRC/tlb.cc.$SNAP" "$SRC/tlb.cc.${SNAP%.fixed}"; do
  if [ -f "$candidate" ]; then
    CC_SRC="$candidate"
    break
  fi
done
for candidate in "$SRC/tlb.hh.$SNAP" "$SRC/tlb.hh.${SNAP%.fixed}"; do
  if [ -f "$candidate" ]; then
    HH_SRC="$candidate"
    break
  fi
done
BASEDIR=$W/gem5-base; SC=/tmp/sahilag24/sc
if [ ! -d "$SC/SCons" ]; then
  mkdir -p "$SC"
  if [ -f "$R/vendor/scons-4.8.1.tar.gz" ]; then
    tar -xzf "$R/vendor/scons-4.8.1.tar.gz" -C "$SC"
  else
    "$PYTHON_BIN" -m pip install -q --target "$SC" "scons==4.8.1"
  fi
fi
scons_build() { ( cd $1 && PYTHONPATH=$SC "$PYTHON_BIN" -m SCons build/X86/gem5.opt -j ${JOBS:-30} --linker=gold --ignore-style ) > $W/logs/scons_$(basename $1).log 2>&1; }
link() { # link TREE TAG
  local tree=$1 tag=$2
  local generated_script="$W/ml_$tag.sh"
  sed -E \
    -e "s|source \"\$\(dirname \"\$0\"\)/env.sh\"|source \"$R/scripts/env.sh\"|" \
    -e "s|^T=\$INC|T=$tree|" \
    -e "s|stamps/build_\$VARIANT|stamps/linked_$tag|" \
    -e "s|O=\$W/elfobj|O=$W/elfobj_$tag|" \
    "$R/scripts/manual_link.sh" > "$generated_script"
  chmod +x "$generated_script"
  export -f log
  VARIANT=$LANE bash "$generated_script"
}

mk_tree() { # mk_tree DEST tlb.cc tlb.hh variant-of-checker
  rsync -a --delete --exclude=.git --exclude=build --exclude=results_v2 --exclude=presentation $H/gem5/ $1/
  find $1 -type f -exec grep -l -m1 '^#!' {} \; 2>/dev/null | xargs -r chmod +x
  cp $2 $1/src/arch/x86/tlb.cc; cp $3 $1/src/arch/x86/tlb.hh
  "$PYTHON_BIN" $R/patches/apply_checker.py $1 $4
}
HH=${HH_SRC:-$SRC/tlb.hh.nine.sa}
CC=${CC_SRC:-$SRC/tlb.cc.$SNAP}
t1() { mk_tree $INC $CC $HH $([ $LANE = inc ] && echo inc || echo base); scons_build $INC; link $INC lane; }
t2() { rm -rf $BASEDIR; cp -a $INC $BASEDIR && BS=$R/patches/stock; BH=$BS/tlb.hh; BC=$BS/tlb.cc; [ $LANE = agile ] && { BC=$SRC/tlb.cc.nine.sa; BH=$SRC/tlb.hh.nine.sa; }; cp $BC $BASEDIR/src/arch/x86/tlb.cc && cp $BH $BASEDIR/src/arch/x86/tlb.hh && \
       "$PYTHON_BIN" $R/patches/apply_checker.py $BASEDIR base && scons_build $BASEDIR && link $BASEDIR base; }
t3() { if [ -L "$W/tests" ] && [ ! -e "$W/tests" ]; then rm "$W/tests"; fi
       mkdir -p "$W/tests"; gcc-11 -O2 -static -pthread -o "$W/tests/tlbstress" "$R/tests/tlbstress.c" && gcc-11 -O2 -static -o "$W/tests/perf_holes" "$R/tests/perf_holes.c" \
       && gcc-11 -O2 -static -o "$W/tests/pf_patterns" "$R/tests/pf_patterns.c"; }
stage m_lane_build t1 || exit 1
stage m_base_build t2 || exit 1
stage m_tests t3 || exit 1
export BASE=$BASEDIR
case $LANE in
  perf)  GEN=gen_perf_jobs.py ;;
  agile) GEN=gen_agile_jobs.py ;;
  *)     GEN=gen_se_jobs.py ;;
esac
"$PYTHON_BIN" $R/scripts/$GEN || exit 1
JF=$([ $LANE = perf ] && echo perf || ([ $LANE = agile ] && echo agile || echo se))_matrix.json
if [ "${BUILD_ONLY:-0}" = "1" ]; then
  log "[$HOSTN] machine_run $LANE: BUILD_ONLY=1; binaries, tests, and $JF ready"
  exit 0
fi
"$PYTHON_BIN" $R/scripts/runner.py $W/jobs/$JF --jobs ${RJOBS:-24} --tag ${LANE}_matrix
log "[$HOSTN] machine_run $LANE: DONE; report=robustness/results-$LANE/${LANE}_matrix.md; runner printed PASS counts"
