#!/bin/bash
for c in 1 3; do
  grep -a -E ': 0x[0-9a-f]+ +: f[a-z0-9]+' /tmp/se_tr$c/trace.txt | sed -E 's/^[0-9]+: system.cpu: (0x[0-9a-f]+) +: +/\1 /' | cut -c1-90 > /tmp/x87full_$c.txt
  awk '{print $2}' /tmp/x87full_$c.txt > /tmp/x87_$c.txt
  echo "== case c$c: x87 ops: $(wc -l < /tmp/x87_$c.txt)"
done
echo "=== mnemonic counts, (0,1) '<' vs (1,1) '>'"
diff <(sort /tmp/x87_1.txt | uniq -c) <(sort /tmp/x87_3.txt | uniq -c)
echo "=== all mnemonics seen in (0,1)"; sort /tmp/x87_1.txt | uniq -c | sort -rn
echo "=== first position where the two op sequences diverge"
cmp -l /tmp/x87_1.txt /tmp/x87_3.txt | head -n 1
diff <(cat /tmp/x87_1.txt) <(cat /tmp/x87_3.txt) | head -n 30
echo "=== last 50 x87 instrs with PCs, case (0,1)"; tail -n 50 /tmp/x87full_1.txt
echo "=== last 50 x87 instrs with PCs, case (1,1)"; tail -n 50 /tmp/x87full_3.txt
