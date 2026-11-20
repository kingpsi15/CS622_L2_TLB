#!/bin/bash
cd /tmp/sahilag24/CS622_L2_TLB/gem5-excl-isa || exit 1
for c in 1 3; do
  LD_LIBRARY_PATH=$HOME/gcclib timeout 900 ./build/X86/gem5.opt -d /tmp/se_tr$c --debug-flags=ExecMacro configs/deprecated/example/se.py --cpu-type AtomicSimpleCPU --mem-size 2GiB -c /tmp/perl600 -o $HOME/c$c.pl 2>&1 | grep -a -i -E ':[ ]*F[A-Z0-9]+( |$)' | sed -E 's/^ *[0-9]+: *//' | cut -c1-110 > /tmp/x87_$c.txt
  echo "== case c$c: $(cat $HOME/c$c.pl)"; wc -l < /tmp/x87_$c.txt
  awk '{print $2}' /tmp/x87_$c.txt | sort | uniq -c | sort -rn | head -n 25
done
echo "=== last 40 x87 ops, failing case (0,1)"; tail -n 40 /tmp/x87_1.txt
