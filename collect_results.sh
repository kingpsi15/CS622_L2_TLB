#!/bin/bash
mkdir -p ~/CS622_L2_TLB/final_results
for h in csews20 $(seq -f csewsrm%g 1 41) $(seq -f csewsrm%g 43 70); do
ssh -n -o ConnectTimeout=3 -o BatchMode=yes $h 'cd /tmp/sahilag24 2>/dev/null || exit
files=$(find work-*/run* extra-*/run* suite-*/run* -maxdepth 1 \( -name "stats.txt" -o -name "board.pc.com_1.device" -o -name "EXITED" \) 2>/dev/null)
[ -n "$files" ] && tar -cf - $files' | (mkdir -p ~/CS622_L2_TLB/final_results/$h && cd ~/CS622_L2_TLB/final_results/$h && tar -xf - 2>/dev/null) &
done; wait
echo "Done: $(find ~/CS622_L2_TLB/final_results -name stats.txt | wc -l) stats"
