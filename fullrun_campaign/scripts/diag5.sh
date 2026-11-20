#!/bin/bash
cd /tmp/sahilag24/CS622_L2_TLB/gem5-excl-isa || exit 1
for c in 1 3; do
  rm -rf /tmp/se_tr$c
  LD_LIBRARY_PATH=$HOME/gcclib timeout 900 ./build/X86/gem5.opt -d /tmp/se_tr$c --debug-flags=ExecEnable,ExecMacro,ExecUser --debug-file=trace.txt configs/deprecated/example/se.py --cpu-type AtomicSimpleCPU --mem-size 2GiB -c /tmp/perl600 -o $HOME/c$c.pl > /tmp/raw_$c.txt 2>&1
  echo "== case c$c: $(cat $HOME/c$c.pl)  output: $(grep -a '^-\?0x' /tmp/raw_$c.txt)"
  echo "trace lines: $(wc -l < /tmp/se_tr$c/trace.txt)"
  grep -a -oE ' : F[A-Z0-9_]+ ' /tmp/se_tr$c/trace.txt | tr -d ' :' > /tmp/x87_$c.txt
  echo "x87 ops: $(wc -l < /tmp/x87_$c.txt)"
done
echo "=== trace sample"; sed -n '1000,1005p' /tmp/se_tr1/trace.txt | cut -c1-160
echo "=== x87 count diff, (0,1) '<' vs (1,1) '>'"
diff <(sort /tmp/x87_1.txt | uniq -c) <(sort /tmp/x87_3.txt | uniq -c)
echo "=== x87 ops, case (0,1), last 60"; tail -n 60 /tmp/x87_1.txt | tr '\n' ' '; echo
echo "=== x87 ops, case (1,1), last 60"; tail -n 60 /tmp/x87_3.txt | tr '\n' ' '; echo
