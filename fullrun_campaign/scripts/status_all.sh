#!/bin/bash
for h in csews20 $(seq -f csewsrm%g 2 70); do
case $h in *rm7|*rm9|*rm16|*rm21|*rm41|*rm42) continue;; esac
ssh -n -o ConnectTimeout=3 $h 'cd /tmp/sahilag24 2>/dev/null || exit
for d in extra-*/run*; do [ -d "$d" ] || continue
ex=$(cat "$d/EXITED" 2>/dev/null); [ "$ex" = "exited 143" ] && continue
g=$(dirname "$d")/guest${d##*run}.sh
bs=$(grep -oE "SPEC_START[ _][0-9]+" "$g" 2>/dev/null | grep -oE "[0-9]+" | sort -u | tr "\n" ",")
st=$(grep -ac SPEC_START "$d/board.pc.com_1.device" 2>/dev/null)
rs=$(grep -acE "SPEC_RESULT .* PASS" "$d/board.pc.com_1.device" 2>/dev/null)
printf "%-10s %-26s [%s] st=%s res=%s ex=[%s]\n" "$(hostname -s)" "$d" "$bs" "${st:-0}" "${rs:-0}" "$ex"
done' 2>/dev/null &
done; wait
