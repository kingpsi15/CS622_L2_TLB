#!/usr/bin/env bash
# Build static TLB microbenchmarks into $1 (default ~/tlbbench_bin).
set -e
R=$(cd "$(dirname "$0")/.." && pwd); O=${1:-$HOME/tlbbench_bin}; mkdir -p "$O"
CC=${CC:-gcc-11}
for f in "$R"/tests/{gups,pf_patterns,perf_holes,tlbstress}.c "$R"/../gem5/{tlb_colt_bench,tlb_perfpages_bench,tlb_random}.c; do
  b=$(basename "$f" .c); $CC -O2 -static -o "$O/$b" "$f" && echo "built $b"
done
