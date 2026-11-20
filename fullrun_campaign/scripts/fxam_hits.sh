cd /tmp/sahilag24 2>/dev/null || exit
for d in extra-*/run*; do
  grep -a -q "instruction 'fxam'" $d/simerr.txt 2>/dev/null || continue
  k=${d##*run}; g=$(dirname $d)/guest$k.sh
  echo "$(hostname -s) $d [$(grep -o '^echo SPEC_START [0-9]*\.[a-z0-9_]*' $g 2>/dev/null | awk '{print $3}' | sort -u | tr '\n' ' ')]"
done
