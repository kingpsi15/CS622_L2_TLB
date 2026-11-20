#!/bin/bash
# usage: fullview_remote.sh LANE ISMAIN(1/0)
L=$1; MAIN=$2; U=sahilag24
if [ "$L" = inc ] && [ "$MAIN" = 1 ]; then W=/tmp/$U/work; else W=/tmp/$U/work-$L; fi
X=/tmp/$U/extra-$L
host=$(hostname -s)
PS=$(ps -u $U -o pid=,etimes=,times=,args= 2>/dev/null | grep '[g]em5.opt')
load=$(cut -d' ' -f1 /proc/loadavg)
mem=$(free -g | awk 'NR==2{print $7}')
tmp=$(df -BG --output=avail /tmp | tail -n 1 | tr -dc 0-9)
mine=$(pgrep -c -x -u $U gem5.opt); all=$(pgrep -c -x gem5.opt)
echo "H|$host|$L|$load|$mem|$tmp|${mine:-0}|${all:-0}"
[ -f $W/jobs/spec_fs_guest.sh ] && grep '^echo SPEC_START' $W/jobs/spec_fs_guest.sh | awk -v h=$host -v l=$L '{print "B|"h"|"l"|"$3}'
guest() { # gid dir
  local gid=$1 d=$2 con=$2/board.pc.com_1.device
  [ -f $con ] || return
  local line alive=0 cpu=0 ns pan trb idle done ex=""
  line=$(echo "$PS" | grep -- "-d $d " | sort -k3 -nr | head -n 1)
  [ -n "$line" ] && { alive=1; cpu=$(echo "$line" | awk '{print $3}'); }
  ns=$(grep -c '^SPEC_START' $con)
  pan=$(grep -cE '(^|: )(panic|fatal):' $d/simerr.txt 2>/dev/null); pan=${pan:-0}
  trb=$(grep -iE 'Out of memory|oom-kill|No space left|Segmentation|Call Trace|soft lockup|SETUP_FAIL|Kernel panic' $con | grep -vc 'libglib\|netplan')
  idle=$(( ($(date +%s) - $(stat -c %Y $con)) / 60 ))
  done=$(grep -c 'TLBFS-GUEST-DONE' $con)
  [ -f $d/EXITED ] && ex=$(tr -d ' \n' < $d/EXITED)
  echo "G|$host|$L|$gid|$alive|$cpu|$ns|$pan|$trb|$idle|$done|$ex"
  tr -d '\r' < $con | grep '^SPEC_START' | awk -v h=$host -v l=$L -v g=$gid '{print "S|"h"|"l"|"g"|"$2}'
  tr -d '\r' < $con | grep '^SPEC_RESULT' | awk -v h=$host -v l=$L -v g=$gid '{print "R|"h"|"l"|"g"|"$2"|"$3"|"$4}'
}
if [ "$MAIN" = 1 ]; then
  d=$(ls -td $W/runs/spec_fs_${L}_* 2>/dev/null | head -n 1)
  [ -n "$d" ] && guest main $d
fi
for d in $(ls -d $X/run* 2>/dev/null | sort -V); do guest x${d##*run} $d; done
