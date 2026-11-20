#!/bin/bash
source ~/lane_common.sh
X=/tmp/sahilag24/extra-$L
TL=/tmp/sahilag24/timeline-$L.log
SEEN=/tmp/sahilag24/seen-$L.txt
IMGF=$W/dl/x86-ubuntu-24.04.img
touch $TL $SEEN
[ -f /tmp/sahilag24/imgm-$L ] || stat -c %Y $IMGF > /tmp/sahilag24/imgm-$L
once() {
  A=""
  al() { A="$A\n  - $*"; }
  now=$(date +%s)
  d=$(ls -td $W/runs/spec_fs_${L}_* 2>/dev/null | head -n 1)
  tags=(main); cons=($d/board.pc.com_1.device); errs=($d/simerr.txt)
  for k in $X/run*; do [ -d "$k" ] || continue; tags+=($(basename $k)); cons+=($k/board.pc.com_1.device); errs+=($k/simerr.txt); done
  for i in "${!tags[@]}"; do
    t=${tags[$i]}
    grep -E '^SPEC_(START|RESULT)' ${cons[$i]} 2>/dev/null | cut -c1-90 | while read -r line; do
      grep -qxF "$t|$line" $SEEN && continue
      echo "$t|$line" >> $SEEN
      set -- $line
      echo "$now $t ${1#SPEC_} $2 ${*:3}" >> $TL
    done
  done
  echo "=== $(date +%T) $(hostname -s) $L"
  p=$(pgrep -f "gem5.opt -re -d $W/runs" | head -n 1)
  if [ -n "$p" ]; then ms="up $(ps -o etime= -p $p | xargs)"; else ms="NOT RUNNING"; grep -q TLBFS-GUEST-DONE ${cons[0]} 2>/dev/null || al "main gem5 not running and guest not finished"; fi
  n=$(( ${#tags[@]} - 1 ))
  alive=$(pgrep -fc "^/tmp/.*gem5.opt .*extra-$L/run")
  echo "main gem5: $ms | extra guests alive: $alive of $n"
  fin=0
  for i in "${!tags[@]}"; do
    pn=$(grep -cE 'panic:|fatal:' ${errs[$i]} 2>/dev/null); pn=${pn:-0}
    tr=$(grep -cE 'Out of memory|oom-kill|Killed process|No space left|Segmentation fault|SPEC_SETUP_FAIL|Call Trace|soft lockup|blocked for more than' ${cons[$i]} 2>/dev/null); tr=${tr:-0}
    ns=$(grep -c '^SPEC_START' ${cons[$i]} 2>/dev/null); ns=${ns:-0}
    nr=$(grep -c '^SPEC_RESULT' ${cons[$i]} 2>/dev/null); nr=${nr:-0}
    dn=$(grep -c TLBFS-GUEST-DONE ${cons[$i]} 2>/dev/null); dn=${dn:-0}
    [ "${tags[$i]}" != main ] && [ "$dn" -gt 0 ] && fin=$((fin+1))
    mt=$(stat -c %Y ${cons[$i]} 2>/dev/null || echo $now); idle=$(( (now-mt)/60 ))
    last=$(grep -E '^SPEC_(START|RESULT)' ${cons[$i]} 2>/dev/null | tail -n 1 | cut -c1-48)
    echo "  ${tags[$i]}: panic=$pn trouble=$tr started=$ns results=$nr idle=${idle}m $last"
    [ "$pn" -gt 0 ] && al "${tags[$i]}: gem5 panic: $(grep -E 'panic:|fatal:' ${errs[$i]} | head -n 1 | cut -c1-120)"
    [ "$tr" -gt 0 ] && al "${tags[$i]}: guest trouble lines ($tr): OOM, no space, segfault or setup fail"
    [ "$ns" -eq 0 ] && [ "$idle" -ge 30 ] && al "${tags[$i]}: console idle ${idle}m before SPEC_START"
  done
  [ $((alive+fin)) -lt $n ] && al "only $alive of $n extra guests alive ($fin finished)"
  R=$(grep -h '^SPEC_RESULT' ${cons[@]} 2>/dev/null | cut -c1-90 | sort -u)
  np=$(echo "$R" | grep -c ' PASS'); nf=$(echo "$R" | grep -c ' FAIL'); nt=$(echo "$R" | grep -c 'rc=124')
  echo "results: PASS=$np FAIL=$nf timeout(rc=124)=$nt"
  [ "$nf" -gt 0 ] && { echo "$R" | grep ' FAIL'; al "$nf benchmark FAIL line(s)"; }
  [ "$nt" -gt 0 ] && al "$nt benchmark(s) hit the 8h timeout"
  echo "benchmark minutes (as observed by this monitor):"
  awk '$3=="START"{s[$2" "$4]=$1} $3=="RESULT"{k=$2" "$4; if(k in s) printf "  %s %s %s %d min\n",$2,$4,$5,($1-s[k])/60}' $TL | tail -n 12
  fg=$(df -BG --output=avail /tmp | tail -n 1 | tr -dc 0-9); mg=$(free -g | awk '/Mem:/{print $7}'); upm=$(( $(cut -d. -f1 /proc/uptime) / 60 ))
  echo "host: /tmp free ${fg}G | mem avail ${mg}G | load $(cut -d' ' -f1 /proc/loadavg) | uptime ${upm}m"
  [ "$fg" -lt 20 ] && al "/tmp only ${fg}G free"
  [ "$mg" -lt 6 ] && al "memory available only ${mg}G"
  [ "$upm" -lt 240 ] && al "host rebooted ${upm} min ago"
  [ "$(stat -c %Y $IMGF)" = "$(cat /tmp/sahilag24/imgm-$L)" ] || al "shared root image was modified"
  o=$(ps -eo user:14,pcpu,comm --sort=-pcpu | awk 'NR>1 && $1!="sahilag24" && $2>80' | head -n 2); [ -n "$o" ] && echo "other users using CPU: $o"
  if [ -n "$A" ]; then echo "ALERTS:"; printf "%b\n" "$A"; else echo "ALERTS: none"; fi
}
if [ "$1" = loop ]; then
  while true; do
    once > /tmp/sahilag24/mon-last-$L.txt 2>&1
    grep -q '^ALERTS: none' /tmp/sahilag24/mon-last-$L.txt || tee -a /tmp/sahilag24/mon-alerts-$L.log < /tmp/sahilag24/mon-last-$L.txt | tail -n 8
    sleep 300
  done
else once; fi
