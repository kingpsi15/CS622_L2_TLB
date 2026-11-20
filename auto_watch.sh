#!/bin/bash
while true; do
  { date; bash ~/check_all.sh; bash ~/collect_results.sh; } >> ~/watch_progress.log 2>&1
  sleep 1200
done
