cd /tmp/sahilag24 2>/dev/null || exit
for d in extra-*/run*; do
  [ -f $d/simerr.txt ] || continue
  u=$(grep -a -o "instruction '[a-z0-9_]*' unimplemented" $d/simerr.txt | cut -d"'" -f2 | sort -u | tr '\n' ',')
  b=$(grep -a -o 'SPEC_START_[0-9]*\.[a-z0-9_]*' $d/board.pc.com_1.device | sort -u | tr '\n' ',')
  echo "$(hostname -s) $d u=[$u] b=[$b]"
done
