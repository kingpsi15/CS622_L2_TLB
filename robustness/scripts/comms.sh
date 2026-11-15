#!/bin/bash
# Message board between the ADMIN session (csewsrm20) and the lane sessions (other machines). All files live on the shared NFS home:
#   ~/CS622_L2_TLB/robustness/comms/to_<lane>.md    admin -> lane (append-only; newest at the bottom)
#   ~/CS622_L2_TLB/robustness/comms/from_<lane>.md  lane -> admin (append-only status/questions)
#   ~/CS622_L2_TLB/robustness/comms/hb_<lane>.txt   one-line heartbeat (overwritten)
# usage:  comms.sh hb  <lane> "<one-line status>"     lane: update heartbeat (do this every ~10 min)
#         comms.sh say <lane> "<message>"              lane->admin (from_<lane>.md)   [alias: ask]
#         comms.sh read <lane>                         lane: print the last 25 lines of to_<lane>.md (ADMIN instructions override your task file)
#         comms.sh tell <lane|all> "<message>"         orchestrator -> lane
#         comms.sh resume <lane> "<fix summary>"      lane agent -> supervisor after a verified fix
#         comms.sh board                               admin: heartbeats + last line of every from_*.md
C=$HOME/CS622_L2_TLB/robustness/comms; mkdir -p $C; N=$(date '+%F %T'); H=$(hostname)
case $1 in
  hb)   echo "$N $H $2: $3" > $C/hb_$2.txt ;;
  say|ask) echo "[$N $H] $3" >> $C/from_$2.md ;;
  read) tail -n 25 $C/to_$2.md 2>/dev/null || echo "(no messages)" ;;
  tell) for l in $( [ "$2" = all ] && echo inc excl nine agile perf || echo $2 ); do echo "[ADMIN $N] $3" >> $C/to_$l.md; done ;;
  resume) echo "[RESUME $N $H $2] $3" >> $C/to_$2.md ;;
  board) for f in $C/hb_*.txt; do cat $f 2>/dev/null; done; for f in $C/from_*.md; do [ -f $f ] && echo "-- $(basename $f): $(tail -n 1 $f | cut -c1-200)"; done ;;
esac
