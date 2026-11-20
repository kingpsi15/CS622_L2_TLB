#!/bin/bash
for h in csews20 $(seq -f csewsrm%g 1 70); do
ssh -n -o ConnectTimeout=3 -o StrictHostKeyChecking=accept-new -o BatchMode=yes $h '
ng=$(pgrep -x gem5.opt | wc -l)
ns=$(pgrep -f "[s]pawn_" | wc -l)
if [ "$ng" -eq 0 ] && [ "$ns" -eq 0 ]; then
  rm -rf /tmp/sahilag24/extra-*/spec*.img /tmp/sahilag24/work-*/cpu2017 /tmp/sahilag24/run* /tmp/sahilag24/work-*/run*
fi
printf "%02d %s\n" "$((ng + ns))" "$(hostname -s)"' 2>/dev/null &
done; wait
