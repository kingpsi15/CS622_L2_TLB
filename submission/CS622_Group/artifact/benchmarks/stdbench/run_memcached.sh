#!/bin/bash
# memcached 1.6.29 (1 worker, 512MB) driven by mc-crusher: load 200k x 1KB keys,
# then uniform-random GETs over them until memcached has served $GETS gets.
B=$(dirname "$0"); P=${MCPORT:-11311}; GETS=${GETS:-300000}
st() { printf "stats\r\nquit\r\n" | timeout 5 bash -c "exec 3<>/dev/tcp/127.0.0.1/$P; cat >&3; cat <&3" | tr -d "\r" | awk -v k="$1" "\$2==k{print \$3}"; }
"$B/memcached" -u root -p $P -U 0 -t 1 -m 512 -l 127.0.0.1 & M=$!; sleep 1
"$B/mc-crusher" --conf "$B/mc_load.conf" --ip 127.0.0.1 --port $P >/dev/null 2>&1 & C=$!
until [ "$(st curr_items)" -ge 200000 ] 2>/dev/null; do sleep 0.2; done; kill $C; wait $C 2>/dev/null
eval "${WIN_BEGIN:-:}"
"$B/mc-crusher" --conf "$B/mc_get.conf" --ip 127.0.0.1 --port $P >/dev/null 2>&1 & C=$!
until [ "$(st cmd_get)" -ge $GETS ] 2>/dev/null; do sleep 0.2; done; kill $C; wait $C 2>/dev/null
eval "${WIN_END:-:}"
echo "RESULT memcached items=$(st curr_items) gets=$(st cmd_get) hits=$(st get_hits) misses=$(st get_misses)"
kill $M; wait $M 2>/dev/null
