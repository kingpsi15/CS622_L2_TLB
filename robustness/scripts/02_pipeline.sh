#!/bin/bash
# Master unattended pipeline (run in tmux session tlbinc-pipeline). Resumable:
# every stage is stamped; runner.py skips finished jobs. Re-run after a crash/reboot
# (after 00_setup.sh if /tmp was wiped).
source "$(dirname "$0")/env.sh"
S=$R/scripts
log "PIPELINE: start"

# 1. wait for the plain gem5 builds (00b_builds.sh in tmux tlbinc-build)
for i in $(seq 1 360); do
    [ -f $W/stamps/build_inc ] && [ -f $W/stamps/build_base ] && break
    if grep -q "build_inc: \*\*FAILED\|build_base: \*\*FAILED" <(tail -n 30 $LOG) && \
       ! tmux has-session -t tlbinc-build 2>/dev/null; then break; fi
    sleep 60
done
if [ ! -f $W/stamps/build_inc ] || [ ! -f $W/stamps/build_base ]; then
    log "PIPELINE: plain builds missing/failed - retrying builds"; JOBS=28 bash $S/00b_builds.sh
fi

# 2. instrument (inclusion invariant + page-table oracle) and rebuild incrementally
instr() { /usr/bin/python3 $R/patches/apply_checker.py $1 $2 && cd $1 && \
          scons build/X86/gem5.opt -j ${JOBS:-14} --linker=gold --ignore-style && ls -l build/X86/gem5.opt; }
( stage instr_inc instr $INC inc ) & ( stage instr_base instr $BASE base ) & wait
if [ ! -f $W/stamps/instr_inc ] || [ ! -f $W/stamps/instr_base ]; then log "PIPELINE: ABORT - instrumented build failed"; exit 1; fi
( cd $INC && diff -u $H/gem5/src/arch/x86/tlb.cc.inclusive.sa src/arch/x86/tlb.cc > $R/patches/inclusive_checker_cc.diff;
  diff -u $H/gem5/src/arch/x86/tlb.hh.inclusive.sa src/arch/x86/tlb.hh > $R/patches/inclusive_checker_hh.diff ) || true

# 3. SE robustness matrix (both builds, 1c/multicore/multiprocess/SMT/fork, Atomic/Timing/O3)
/usr/bin/python3 $S/gen_se_jobs.py
/usr/bin/python3 $S/runner.py $W/jobs/se_matrix.json --jobs 26 --tag se_matrix

# 4. SE checkpoint/restore lifecycle (take with Atomic, restore with Timing + O3)
ckpt() {
  for b in inc base; do
    T=$( [ $b = inc ] && echo $INC || echo $BASE ); O=$W/runs/ckpt/$b; rm -rf $O; mkdir -p $O
    TLBCHK_MAXWARN=20 $T/build/X86/gem5.opt -re -d $O/take $INC/configs/deprecated/example/se.py \
      --cpu-type AtomicSimpleCPU -c $W/tests/tlbstress -o "capacity 2048 6" --take-checkpoints 30000000000,30000000000 \
      --max-checkpoints 1 --mem-size 4GiB
    for cpu in TimingSimpleCPU DerivO3CPU; do
      TLBCHK_MAXWARN=20 $T/build/X86/gem5.opt -re -d $O/restore-$cpu $INC/configs/deprecated/example/se.py \
        --cpu-type AtomicSimpleCPU --restore-with-cpu $cpu --caches --l2cache -c $W/tests/tlbstress \
        -o "capacity 2048 6" --checkpoint-dir $O/take --checkpoint-restore 1 --mem-size 4GiB
      echo "== $b restore-$cpu: $(grep -h 'RESULT' $O/restore-$cpu/simout.txt) ; $(grep -h 'TLBCHK' $O/restore-$cpu/simerr.txt | head -3)"
      grep -h "chkInclusionViolations\|chkOracle" $O/restore-$cpu/stats.txt | awk '$2>0' | head
    done
  done
}
stage se_checkpoint ckpt; cp $W/logs/se_checkpoint.log $RES/se_checkpoint.txt 2>/dev/null

# 5. FS Linux matrix: KVM boot -> 1/2/4/8 simulated cores; interrupts, IPIs, preemption, COW, THP
/usr/bin/python3 $S/gen_fs_jobs.py
/usr/bin/python3 $S/runner.py $W/jobs/fs_matrix.json --jobs 12 --tag fs_matrix

# 6. SPEC CPU2017
for i in $(seq 1 240); do [ -f $W/stamps/spec_setup ] && break; tmux has-session -t tlbinc-spec 2>/dev/null || break; sleep 60; done
if [ ! -f $W/stamps/spec_setup ]; then rm -f $W/stamps/spec_build; bash $S/01_spec_build.sh; fi
cd $SPEC && source shrc && cd - >/dev/null
/usr/bin/python3 $S/gen_spec_jobs.py
/usr/bin/python3 $S/runner.py $W/jobs/spec_ref.json  --jobs 28 --tag spec_ref
/usr/bin/python3 $S/runner.py $W/jobs/spec_test.json --jobs 28 --tag spec_test
/usr/bin/python3 $S/spec_diff.py

# 7. summary into the audit + copy compact evidence home
/usr/bin/python3 $S/summarize.py
log "PIPELINE: COMPLETE - see TLB_IMPLEMENTATION_AUDIT.md 'Results summary' and robustness/results/"
