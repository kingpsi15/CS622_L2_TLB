#!/bin/bash
cd /tmp/sahilag24/CS622_L2_TLB/gem5-excl-isa || exit 1
i=0
while read -r line; do
  i=$((i+1)); echo "$line" > $HOME/c$i.pl
  N=$(/tmp/perl600 $HOME/c$i.pl | tr '\n' '|')
  LD_LIBRARY_PATH=$HOME/gcclib timeout 300 ./build/X86/gem5.opt -d /tmp/se_c$i configs/deprecated/example/se.py --cpu-type AtomicSimpleCPU --mem-size 2GiB -c /tmp/perl600 -o $HOME/c$i.pl > /tmp/se_c$i.log 2>&1
  G=$(grep -a -E '^[-0-9]' /tmp/se_c$i.log | tr '\n' '|')
  W=$(grep -a -c unimplemented /tmp/se_c$i.log)
  [ "$N" = "$G" ] && R=OK || R=DIFF
  echo "$R | $line"; echo "   native: $N"; echo "   gem5  : $G  (unimpl warns=$W)"
done <<'CASES'
printf("%a %a\n", 0, 1);
printf("%a %a\n", 1, 0);
printf("%a %a\n", 1, 1);
printf("%a %a %a\n", 0, 1, 0);
printf("%a %.13a\n", 1, 0);
printf("%a\n", 1); printf("%a\n", 1);
my $x=1; printf("%a %a\n", $x, $x);
printf("%a %a\n", 1.0, 2.0);
CASES
