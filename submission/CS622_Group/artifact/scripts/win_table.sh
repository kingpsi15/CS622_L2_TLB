#!/usr/bin/env bash
# Print one line per dumped timing window in /tmp/$USER/{std,micro,ref}/LATEST_<lane>[_tag]:
# lane kind name why insts ipc dtbMiss mpki l2Hits coltHits walkDRAM
L=${1:?lane}; U=$(id -un)
for f in /tmp/$U/std/LATEST_${L}* /tmp/$U/micro/LATEST_${L}* /tmp/$U/ref/LATEST_${L}*; do
  [ -f "$f" ] || continue; d=$(cat "$f"); k=$(basename "$(dirname "$f")")$(basename "$f" | sed "s/LATEST_$L//")
  for s in "$d"/*/; do
    w=$(grep -a "dumped" "$s/simout.txt" 2>/dev/null | head -1) || continue; [ -n "$w" ] || continue
    awk -v L=$L -v k=$k -v n="$(echo $w | awk '{print $2}')" -v why="$(echo $w | awk '{print $4}')" '
      /Begin Simulation/{b++} b!=1{next}
      /^simInsts /{i=$2} /switch.core.ipc /{ipc=$2}
      /switch.core.mmu.dtb.(rd|wr)Misses /{m+=$2} /switch.core.mmu.dtb.l2Hits /{l2=$2}
      /switch.core.mmu.dtb.coltHits /{c=$2} /requestorReadAccesses::processor.switch.core.mmu.dtb.walker /{w=$2}
      END{printf "%s %s %s %s %d %.3f %d %.2f %d %d %d\n", L,k,n,why,i,ipc,m,(i?m*1000/i:0),l2,c,w}' "$s/stats.txt"
  done
done
