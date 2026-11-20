#!/bin/bash
SSH="ssh -n -o LogLevel=ERROR -o ConnectTimeout=8 -o BatchMode=yes"
[ -f ~/spawn_fix.sh ] && grep -q -- '-fix/build' ~/spawn_fix.sh || { echo "spawn_fix.sh missing or wrong"; exit 1; }
PENDING="inc:csews20:work:36 excl:csewsrm22:work-excl:43 nine:csewsrm23:work-nine:38 agile:csewsrm24:work-agile:39 perf:csewsrm25:work-perf:46"
while [ -n "$PENDING" ]; do
  NEXT=""
  for e in $PENDING; do
    IFS=: read L H W T <<<"$e"
    r=$($SSH sahilag24@$H.cse.iitk.ac.in "tail -n 1 /tmp/sahilag24/fixbuild-$L.log")
    case "$r" in
      "done 0")
        $SSH sahilag24@csewsrm$T.cse.iitk.ac.in "mv /tmp/sahilag24/extra-$L /tmp/sahilag24/extra-$L-old 2>/dev/null; tmux new -d -s fix619 \"bash ~/spawn_fix.sh $L $H '619' /tmp/sahilag24/$W > /tmp/spawn_f.log 2>&1\""
        echo "$(date +%T) LAUNCHED $L on csewsrm$T";;
      done*) echo "$(date +%T) BUILD FAILED $L: $r";;
      *) NEXT="$NEXT $e";;
    esac
  done
  PENDING=${NEXT# }
  [ -n "$PENDING" ] && sleep 60
done
echo FINISHED
