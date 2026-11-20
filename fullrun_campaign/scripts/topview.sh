#!/bin/bash
# usage: bash ~/topview.sh [host ...]   (default: all 30 hosts)
ALL="csews20 csewsrm22 csewsrm23 csewsrm24 csewsrm25 csewsrm26 csewsrm27 csewsrm28 csewsrm29 csewsrm30 csewsrm31 csewsrm32 csewsrm33 csewsrm34 csewsrm35 csewsrm2 csewsrm3 csewsrm4 csewsrm5 csewsrm6 csewsrm13 csewsrm8 csewsrm10 csewsrm11 csewsrm12 csewsrm14 csewsrm15 csewsrm17 csewsrm18 csewsrm19"
HOSTS=${@:-$ALL}
T=$(mktemp -d)
for h in $HOSTS; do
  ( timeout 25 ssh -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=6 sahilag24@$h.cse.iitk.ac.in \
    'echo "=================== $(hostname -s)  $(date +%T)"; top -b -n 1 -w 200 -o TIME+ | sed -n "1,5p;7p"; top -b -n 1 -w 200 -o TIME+ | grep gem5.opt' > $T/$h.out 2>&1 ) &
done; wait
for h in $HOSTS; do cat $T/$h.out; echo; done
rm -rf $T
