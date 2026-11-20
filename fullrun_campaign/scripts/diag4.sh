#!/bin/bash
cd /tmp/sahilag24/CS622_L2_TLB/gem5-excl-isa || exit 1
for c in 1 3; do
  LD_LIBRARY_PATH=$HOME/gcclib timeout 900 ./build/X86/gem5.opt -d /tmp/se_tr$c --debug-flags=ExecMacro configs/deprecated/example/se.py --cpu-type AtomicSimpleCPU --mem-size 2GiB -c /tmp/perl600 -o $HOME/c$c.pl > /tmp/raw_$c.txt 2>&1
  echo "== case c$c: $(cat $HOME/c$c.pl)"
  echo "raw lines: $(wc -l < /tmp/raw_$c.txt)"
  grep -a -oE ' : F[A-Z0-9_]+ ' /tmp/raw_$c.txt | tr -d ' :' > /tmp/x87_$c.txt
  echo "x87 ops: $(wc -l < /tmp/x87_$c.txt)"
  sort /tmp/x87_$c.txt | uniq -c | sort -rn | head -n 25
done
echo "=== raw sample (first 6 lines containing ' : ')"; grep -a -m6 ' : ' /tmp/raw_1.txt | cut -c1-160
echo "=== mnemonics only in failing case (0,1) vs (1,1), by count diff"
diff <(sort /tmp/x87_1.txt | uniq -c) <(sort /tmp/x87_3.txt | uniq -c)
echo "=== last 40 x87 ops, failing case (0,1)"; tail -n 40 /tmp/x87_1.txt | tr '\n' ' '; echo
