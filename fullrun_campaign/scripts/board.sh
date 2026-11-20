#!/usr/bin/env bash
# One-screen board for all five lanes. Run from any host: bash ~/board.sh
# Optional: SINCE="2026-11-15 18:00" bash ~/board.sh  (incidents older than this show as old)
ROOT=$HOME/CS622_L2_TLB
COMMS=$ROOT/robustness/comms
SINCE=${SINCE:-"2026-11-15 15:00"}
DOM=cse.iitk.ac.in
declare -A H=( [inc]=csews20 [excl]=csewsrm22 [nine]=csewsrm23 [agile]=csewsrm24 [perf]=csewsrm25 )
T=$(mktemp -d); trap 'rm -rf $T' EXIT
for lane in inc excl nine agile perf; do
  ( timeout 40 ssh -o BatchMode=yes -o ConnectTimeout=8 sahilag24@${H[$lane]}.$DOM 'bash ~/lane_mon.sh' > $T/$lane.txt 2>&1 || echo "SSH_FAILED" >> $T/$lane.txt ) &
done
wait
echo "BOARD $(date '+%F %T')"
for lane in inc excl nine agile perf; do
  hb=$(cat $COMMS/hb_$lane.txt 2>/dev/null)
  flag=""; [[ "$hb" == *BLOCKED* ]] && flag="  [SUPERVISOR BLOCKED: read the incident file]"
  inc=$(ls -t $ROOT/robustness/results-$lane/incident-*.md 2>/dev/null | head -n 1)
  echo "---- $lane (${H[$lane]})$flag"
  if [ -n "$inc" ]; then
    if [ -n "$(find "$inc" -newermt "$SINCE" 2>/dev/null)" ]; then
      echo "  NEW INCIDENT: $(basename $inc) at $(date -r $inc '+%F %T')"
    else
      echo "  newest incident is old: $(date -r $inc '+%F %T')"
    fi
  fi
  f=$T/$lane.txt
  if grep -q SSH_FAILED $f; then
    echo "  ssh failed: run 'bash ~/lane_mon.sh' on ${H[$lane]} instead"; head -n 2 $f | cut -c1-120
    continue
  fi
  grep -E '^main gem5|^  main:|^results:|^host:|^ALERTS|^  - |^  run[0-9]+:.*(panic=[1-9]|trouble=[1-9])' $f | cut -c1-150
  awk '/^  run[0-9]+:/{n++; if($0~/started=[1-9]/)s++; if($0~/results=[1-9]/)r++; if($0~/panic=[1-9]|trouble=[1-9]/)b++} END{if(n)printf "  extras: %d guests, %d reached SPEC_START, %d have results, %d with panic/trouble\n",n,s,r,b}' $f
  grep -E '^  [0-9]+\.[a-z0-9_]+ ' $f | tail -n 3 | cut -c1-100
done
