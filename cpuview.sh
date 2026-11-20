#!/bin/bash
HOSTS="csews20 csewsrm22 csewsrm23 csewsrm24 csewsrm25 csewsrm26 csewsrm27 csewsrm28 csewsrm29 csewsrm30 csewsrm31 csewsrm32 csewsrm33 csewsrm34 csewsrm35 csewsrm2 csewsrm3 csewsrm4 csewsrm5 csewsrm6 csewsrm13 csewsrm8 csewsrm10 csewsrm11 csewsrm12 csewsrm14 csewsrm15 csewsrm17 csewsrm18 csewsrm19"
T=$(mktemp -d)
for h in $HOSTS; do
  ( timeout 20 ssh -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=6 sahilag24@$h.cse.iitk.ac.in '
    a=($(head -n 1 /proc/stat)); sleep 2; b=($(head -n 1 /proc/stat))
    ta=0; tb=0; for v in "${a[@]:1:8}"; do ta=$((ta+v)); done; for v in "${b[@]:1:8}"; do tb=$((tb+v)); done
    ia=$((a[4]+a[5])); ib=$((b[4]+b[5]))
    busy=$(( 100*( (tb-ta) - (ib-ia) ) / (tb-ta) ))
    echo "$(hostname -s) busy=${busy}% mine=$(pgrep -c -x -u sahilag24 gem5.opt) all=$(pgrep -c -x gem5.opt) load=$(cut -d" " -f1 /proc/loadavg)"
  ' > $T/$h.out 2>&1 ) &
done; wait
for h in $HOSTS; do cat $T/$h.out; done | column -t
rm -rf $T
