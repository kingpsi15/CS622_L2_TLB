#!/bin/bash
for X in /tmp/sahilag24/extra*; do for r in $X/run*; do [ -d $r ] || continue; k=${r##*run}
  b=$(grep -a -m1 '^echo SPEC_START' $X/guest$k.sh 2>/dev/null | awk '{print $3}')
  t=$(stat -c %y $r/config.ini 2>/dev/null | cut -c6-16)
  e=$(cat $r/EXITED 2>/dev/null | tr ' ' '_')
  v=$(grep -a 'SPEC_' $r/board.pc.com_1.device 2>/dev/null | tail -1 | tr -d '\r' | cut -c1-50 | tr ' ' '_')
  p=$(grep -a -c -i -E 'panic|fatal' $r/simerr.txt 2>/dev/null)
  echo "$t|$(hostname -s)|$(basename $X)|run$k|$b|${e:-RUNNING}|panics=$p|$v"
done; done
