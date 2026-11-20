#!/bin/bash
LANES="inc:csews20:work:36 excl:csewsrm22:work-excl:43 nine:csewsrm23:work-nine:38 agile:csewsrm24:work-agile:39 perf:csewsrm25:work-perf:46"
SSH="ssh -n -o LogLevel=ERROR -o ConnectTimeout=8 -o BatchMode=yes"
sed 's#gem5-\$L/build/X86/gem5.opt \$GD/#gem5-$L-fix/build/X86/gem5.opt $GD/#' ~/spawn_new.sh > ~/spawn_fix.sh
grep -q -- '-fix/build' ~/spawn_fix.sh || { echo "spawn_fix sed failed"; exit 1; }
for e in $LANES; do
  IFS=: read L H W T <<<"$e"
  echo "== build $L on $H"
  $SSH sahilag24@$H.cse.iitk.ac.in "bash ~/fix_walker_func.sh $L" || { echo "BUILD START FAILED $L"; exit 1; }
done
while true; do
  ok=0
  for e in $LANES; do
    IFS=: read L H W T <<<"$e"
    r=$($SSH sahilag24@$H.cse.iitk.ac.in "tail -n 1 /tmp/sahilag24/fixbuild-$L.log")
    case "$r" in
      "done 0") ok=$((ok+1));;
      done*) echo "BUILD FAILED $L: $r"; exit 1;;
    esac
  done
  echo "$(date +%T) builds done: $ok/5"
  [ $ok -eq 5 ] && break
  sleep 60
done
for e in $LANES; do
  IFS=: read L H W T <<<"$e"
  $SSH sahilag24@csewsrm$T.cse.iitk.ac.in "mv /tmp/sahilag24/extra-$L /tmp/sahilag24/extra-$L-old 2>/dev/null; tmux new -d -s fix619 \"bash ~/spawn_fix.sh $L $H '619' /tmp/sahilag24/$W > /tmp/spawn_f.log 2>&1\""
  echo "$(date +%T) launched 619 fix: $L on csewsrm$T"
done
echo ALL LAUNCHED
