#!/usr/bin/env bash
# Merge one L2 TLB design into a gem5 25.1.0.1 source tree and build gem5.opt.
#
#   bash build_design.sh <gem5_dir> <design> [--checker] [-j N]
#
#   <design>  : inc | excl | nine | agile | perf | perfstrict | colt
#               (mid-review snapshots also accepted: inclusive.sa, exclusive.sa,
#                nine.sa, naivefp, sp, colt_fa.verified, item2.verified,
#                item3.verified, hybrid.verified)
#   --checker : also add the translation oracle / invariant checker
#               (apply_checker*.py), needed for chk* statistics
#
# What it does: copies tlb.cc / tlb.hh for the design (and, for colt, the
# patched pagetable_walker.cc) over <gem5_dir>/src/arch/x86, optionally applies
# the checker, then runs scons build/X86/gem5.opt. The original files are
# saved once as *.orig. Needs gcc-11/g++-11 and python3 (gem5 build deps).
# Time: full build from a clean tree ~1-2 h on 16 cores; incremental rebuild
# after switching design ~5-10 min.
set -euo pipefail
G=${1:?gem5 dir}; D=${2:?design}; shift 2
CHECK=0; J=$(nproc 2>/dev/null || echo 8)
while (( $# )); do case $1 in --checker) CHECK=1;; -j) J=$2; shift;; esac; shift; done
HERE=$(cd "$(dirname "$0")" && pwd); P=$HERE/../gem5_patches
X=$G/src/arch/x86
[[ -f $X/tlb.cc ]] || { echo "not a gem5 tree: $G"; exit 1; }
for f in tlb.cc tlb.hh pagetable_walker.cc; do [[ -f $X/$f.orig ]] || cp "$X/$f" "$X/$f.orig"; done
cp "$X/pagetable_walker.cc.orig" "$X/pagetable_walker.cc"
case $D in
  perfstrict) cc=$P/tlb.cc.perf.strict; hh=$P/tlb.hh.perf.strict ;;
  inc|excl|nine|agile|perf|colt) cc=$P/tlb.cc.$D.fixed; hh=$P/tlb.hh.$D.fixed ;;
  *) cc=$P/midreview/tlb.cc.$D; hh=$P/midreview/tlb.hh.$D ;;
esac
[[ -f $cc && -f $hh ]] || { echo "unknown design $D ($cc)"; exit 1; }
cp "$cc" "$X/tlb.cc"; cp "$hh" "$X/tlb.hh"
[[ $D == colt ]] && cp "$P/pagetable_walker.cc.colt" "$X/pagetable_walker.cc"
if (( CHECK )); then
  case $D in
    inc|inclusive.sa) python3 "$P/apply_checker.py" "$G" inc ;;
    excl|exclusive.sa) python3 "$P/apply_checker_excl.py" "$G" ;;
    nine|colt) python3 "$P/apply_checker_nine.py" "$G" fixed ;;
    nine.sa) python3 "$P/apply_checker_nine.py" "$G" sa ;;
    *) python3 "$P/apply_checker.py" "$G" base ;;
  esac
fi
echo "design $D merged into $G (checker=$CHECK); building with -j$J"
cd "$G" && CC=${CC:-gcc-11} CXX=${CXX:-g++-11} scons build/X86/gem5.opt -j"$J" --ignore-style
echo "built $G/build/X86/gem5.opt for design $D"
