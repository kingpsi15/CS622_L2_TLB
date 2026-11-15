#!/bin/bash
# Fast per-lane gem5 tree: copy the finished stock build and recompile ONLY tlb.cc (+ relink).
# usage: VARIANT=nine 04_fast_tree.sh <tlb.cc> <tlb.hh>
source "$(dirname "$0")/env.sh"
[ -f $SHARED/stamps/build_base ] || { echo "waiting for stock build"; timeout 7200 bash -c "until [ -f $SHARED/stamps/build_base ]; do sleep 30; done"; }
mkdir -p $(dirname $INC)
[ -d $INC ] || cp -a $SHARED/gem5-base $INC          # includes build/ with objects
cp "$1" $INC/src/arch/x86/tlb.cc; cp "$2" $INC/src/arch/x86/tlb.hh
cd $INC && scons build/X86/gem5.opt -j 6 --linker=gold --ignore-style 2>&1 | tail -n 5
ls -l build/X86/gem5.opt
