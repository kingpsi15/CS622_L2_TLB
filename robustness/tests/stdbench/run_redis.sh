#!/bin/bash
# Redis 7.2.5 (no persistence) + redis-benchmark: load 200k x 1KB keys, then
# $GETS random GETs; WIN_BEGIN/WIN_END around the GET phase. Every step is
# time-limited (guest time) and reports progress straight to the serial console.
B=$(dirname "$0"); P=${RPORT:-6390}; GETS=${GETS:-300000}; C=/dev/ttyS0
m() { echo "REDIS_STEP $*" > $C; }
m start; "$B/redis-server" --port $P --save "" --appendonly no --bind 127.0.0.1 --protected-mode no --daemonize no --io-threads 1 > /tmp/redis.log 2>&1 & S=$!
for i in $(seq 100); do timeout 5 "$B/redis-benchmark" -p $P -t ping -n 1 -q >/dev/null 2>&1 && break; sleep 0.2; done; m "server-up after $i tries"
timeout 1200 "$B/redis-benchmark" -p $P -t set -n 200000 -r 200000 -d 1024 -c 4 -P 8 -q > /tmp/redis_set.txt 2>&1; m "set rc=$? $(tr "\r" "\n" < /tmp/redis_set.txt | grep -a "requests per" | tail -1)"
eval "${WIN_BEGIN:-:}"
timeout 1200 "$B/redis-benchmark" -p $P -t get -n $GETS -r 200000 -d 1024 -c 4 -P 8 -q > /tmp/redis_get.txt 2>&1; rc=$?
eval "${WIN_END:-:}"
m "get rc=$rc $(tr "\r" "\n" < /tmp/redis_get.txt | grep -a "requests per" | tail -1)"
tail -3 /tmp/redis.log | sed "s/^/REDIS_LOG /" > $C
echo "RESULT redis done"; kill $S; wait $S 2>/dev/null
