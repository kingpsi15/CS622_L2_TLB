source ~/lane_common.sh
d=$(ls -td $W/runs/spec_fs_${L}_* 2>/dev/null | head -1); c=$d/board.pc.com_1.device
echo "== $H $L run=$(basename $d)"
echo "gem5 up    : $(ps -eo etime,args | grep gem5.opt | grep -- "-d $W/runs" | grep -v grep | awk '{print $1}')"
echo "console    : last write $(( ($(date +%s)-$(stat -c %Y $c))/60 ))m ago; $(grep -c '^SPEC_RESULT' $c) results"
echo "setup fail : $(grep -c 'SPEC_SETUP_FAIL\|a password is required' $c)"
echo "verdicts   : $(grep '^SPEC_RESULT' $c | awk '{print $3}' | sort | uniq -c | tr '\n' ' ')"
grep '^SPEC_RESULT' $c | tail -n 3 | cut -c1-120
tail -n 2 $c | cut -c1-120
