source ~/lane_common.sh
while true; do
  d=$(ls -td $W/runs/spec_fs_${L}_* | head -1)
  if ! pgrep -f "gem5.opt -re -d $W/runs" >/dev/null; then echo "$(date +%T) $L: GEM5 NOT RUNNING"; grep -nE 'panic|fatal' $d/simerr.txt | head -n 3 | cut -c1-200; fi
  sleep 300
done
