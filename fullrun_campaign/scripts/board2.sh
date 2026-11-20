#!/usr/bin/env bash
ROOT=$HOME/CS622_L2_TLB; COMMS=$ROOT/robustness/comms
SINCE=${SINCE:-"2026-11-15 15:30"}
now=$(date +%s)
echo "BOARD $(date '+%F %T')"
for lane in inc excl nine agile perf; do
  hb=$(cat $COMMS/hb_$lane.txt 2>/dev/null); flag=""
  [[ "$hb" == *BLOCKED* ]] && flag="  [SUPERVISOR BLOCKED: read the incident file]"
  echo "---- $lane$flag"
  inc=$(ls -t $ROOT/robustness/results-$lane/incident-*.md 2>/dev/null | head -n 1)
  if [ -n "$inc" ]; then
    if [ -n "$(find "$inc" -newermt "$SINCE" 2>/dev/null)" ]; then echo "  NEW INCIDENT: $(basename $inc) at $(date -r $inc '+%F %T')"
    else echo "  newest incident is old: $(date -r $inc '+%F %T')"; fi
  fi
  f=$COMMS/mon_$lane.txt
  if [ ! -f "$f" ]; then echo "  no report yet: start the share loop on that host"; continue; fi
  age=$(( (now - $(stat -c %Y $f)) / 60 ))
  [ $age -gt 12 ] && echo "  REPORT STALE (${age}m old): share loop stopped or host down"
  head -n 1 $f | cut -c1-80
  grep -E '^main gem5|^  main:|^results:|^host:|^ALERTS|^  - |^  run[0-9]+:.*(panic=[1-9]|trouble=[1-9])' $f | cut -c1-150
  awk '/^  run[0-9]+:/{n++; if($0~/started=[1-9]/)s++; if($0~/results=[1-9]/)r++; if($0~/panic=[1-9]|trouble=[1-9]/)b++} END{if(n)printf "  extras: %d guests, %d reached SPEC_START, %d have results, %d with panic/trouble\n",n,s,r,b}' $f
  grep -E '^  [0-9]+\.[a-z0-9_]+ ' $f | tail -n 3 | cut -c1-100
done
