#!/bin/bash
# Stock-TLB (+oracle checker) baseline: copy a finished tree, swap in stock tlb.cc/hh, recompile changed objects only, manual link.
export VARIANT=perf; source "$(dirname "$0")/env.sh"
B=/tmp/sahilag24/work/gem5-base; mkdir -p /tmp/sahilag24/work/stamps
rm -rf $B; cp -a $INC $B
cp $R/patches/stock/tlb.cc $B/src/arch/x86/tlb.cc; cp $R/patches/stock/tlb.hh $B/src/arch/x86/tlb.hh
/usr/bin/python3 $R/patches/apply_checker.py $B base || exit 1
cd $B && PYTHONPATH=/tmp/sahilag24/sc /usr/bin/python3 -m SCons build/X86/gem5.opt -j30 --linker=gold --ignore-style > $W/logs/build_base.log 2>&1
sed "s|^T=\$INC|T=$B|; s|stamps/build_\$VARIANT|stamps/build_base_manual|; s|O=\$W/elfobj|O=$W/elfobj_base|" $R/scripts/manual_link.sh > $W/manual_link_base.sh
VARIANT=perf bash $W/manual_link_base.sh && touch /tmp/sahilag24/work/stamps/build_base && log "BASE (stock TLB + oracle) built at $B"
