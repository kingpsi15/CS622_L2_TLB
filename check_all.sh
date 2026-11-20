#!/bin/bash
bash ~/dashboard.sh
echo ""
for p in "16 gapbs-inc" "21 gapbs-excl" "41 gapbs-nine" "10 gapbs-agile" "12 gapbs-perf" "20 kv-inc" "7 kv-excl" "46 kv-nine" "54 kv-agile" "55 kv-perf"; do
set -- $p
echo "== rm$1 $2: $(ssh -n -o ConnectTimeout=4 -o BatchMode=yes csewsrm$1 "d=/tmp/sahilag24/suite-$2/run0; printf 'st=%s res=%s ex=[%s]' \$(grep -ac BENCH_START \$d/board.pc.com_1.device 2>/dev/null) \$(grep -ac BENCH_RESULT \$d/board.pc.com_1.device 2>/dev/null) \"\$(cat \$d/EXITED 2>/dev/null)\"")"
done
