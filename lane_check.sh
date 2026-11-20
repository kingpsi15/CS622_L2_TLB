source ~/lane_common.sh
echo "== host=$H lane=$L work=$W"
echo "owner file : $(head -1 $R/comms/owner_$L.txt)   (must equal host: $H)"
echo "heartbeat  : $(cut -c1-110 $R/comms/hb_$L.txt)"
echo "gem5 procs : $(pgrep -af gem5.opt | grep -c -- "-d $W/runs")  (must be 0 before fixing)"
echo "tmux       : $(tmux ls 2>&1 | grep supervisor | cut -c1-60)"
echo "supervisor : $(pgrep -f lane_supervisor.sh | wc -l) proc"
echo "kvm rw     : $([ -r /dev/kvm ] && [ -w /dev/kvm ] && echo yes || echo no)"
echo "tmp free   : $(df -h /tmp | tail -1 | awk '{print $4}')"
echo "partition  : $(fdisk -l $IMG 2>/dev/null | grep 'img2' | cut -c1-80)   (start 4096 sectors = offset 2097152)"
echo "sudoers    : $(debugfs -R 'stat /etc/sudoers.d/90-gem5' "$IMG?offset=2097152" 2>&1 | grep -oE 'Mode: +[0-9]+|not found' | head -1)  / $(debugfs -R 'cat /etc/sudoers.d/90-gem5' "$IMG?offset=2097152" 2>/dev/null)"
echo "cfg        : bw=$(grep -c '^603.bwaves_s,621.wrf_s' $SPEC/config/gem5-static.cfg) omn=$(grep -c '^520.omnetpp_r,620.omnetpp_s' $SPEC/config/gem5-static.cfg)   (want 1 and 1)"
for b in $B; do
  st=ok
  for f in $SPEC/benchspec/CPU/$b/exe/*gem5static*; do
    [ -e "$f" ] || { st=NO-EXE; break; }
    [ "$f" -nt $SPEC/config/gem5-static.cfg ] || st=STALE-EXE
    r=$SPEC/benchspec/CPU/$b/run/run_base_test_gem5static-m64.0000/$(basename $f)
    cmp -s "$f" "$r" || st="$st+RUNDIR-DIFF"
  done
  echo "  $b: $st"
done
echo "spec disk  : $(ls -la --time-style=long-iso $W/spec2017.fs.img 2>&1 | awk '{print $5, $6, $7, $8}')   (must NOT exist before resume)"
echo "last board : $(tail -n 2 $R/comms/to_$L.md | cut -c1-110)"
