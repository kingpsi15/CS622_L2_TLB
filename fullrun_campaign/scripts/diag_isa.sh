#!/bin/bash
cd /tmp/sahilag24/CS622_L2_TLB/gem5-excl-isa || exit 1
cat > $HOME/t2.pl <<'PL'
printf("%a\n", 1); printf("%a\n", 2); printf("%a\n", 0.5); printf("%a\n", 3); printf("%a\n", 1.5);
printf("%a\n", 0); printf("%a\n", -1); printf("%.3a\n", 0); printf("%a\n", 1e10); printf("%e\n", 12345.678);
PL
echo "=== native"; /tmp/perl600 $HOME/t2.pl | tr '\n' ' '; echo
echo "=== gem5 SE new build"
LD_LIBRARY_PATH=$HOME/gcclib timeout 600 ./build/X86/gem5.opt -d /tmp/se600b configs/deprecated/example/se.py --cpu-type AtomicSimpleCPU --mem-size 2GiB -c /tmp/perl600 -o $HOME/t2.pl > /tmp/se600b.log 2>&1
grep -a -E "^[-0-9]|unimplemented" /tmp/se600b.log | sort | uniq -c | sort -rn | head -n 20
echo "=== decoder stubs"; grep -n -E "fwait|fninit|ftst|fxam|fnop|fclex|fscale|fxtract|fprem|frndint|fsin|fcos|fpatan|f2xm1|fyl2x" src/arch/x86/isa/decoder/x87.isa
echo "=== x87 insts"; ls src/arch/x86/isa/insts/x87/*
echo "=== FNSTSW/FNSTCW/FLDCW/FNCLEX macroops"; grep -rn -A8 "macroop FNSTSW\|macroop FNSTCW\|macroop FLDCW\|macroop FNCLEX" src/arch/x86/isa/insts/x87 --include=*.py | cut -c1-150 | head -n 60
echo "=== fpop.isa classes"; grep -n "class " src/arch/x86/isa/microops/fpop.isa | cut -c1-100
echo "=== Compfp"; grep -n -A30 "class Compfp" src/arch/x86/isa/microops/fpop.isa | cut -c1-140
