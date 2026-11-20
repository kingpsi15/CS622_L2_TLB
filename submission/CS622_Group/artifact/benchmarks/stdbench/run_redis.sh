#!/bin/bash
# Redis 7.2.5 (no persistence) + redis-benchmark: load $KEYS x 1KB keys, then
# $GETS uniform-random GETs; WIN_BEGIN/WIN_END around the GET phase.
# The server is given time to start with idle sleeps (cheap to simulate):
# pinging a server that is not yet listening makes redis-benchmark spin,
# which costs billions of simulated instructions.
B=$(dirname "$0"); P=${RPORT:-6390}; KEYS=${KEYS:-20000}; GETS=${GETS:-50000}; C=/dev/ttyS0
m() { echo "REDIS_STEP $*" > $C 2>/dev/null; }
m start; "$B/redis-server" --port $P --save "" --appendonly no --bind 127.0.0.1 --protected-mode no --io-threads 1 > /tmp/redis.log 2>&1 & S=$!
sleep 3
for i in $(seq 20); do grep -q "Ready to accept" /tmp/redis.log && break; sleep 1; done; m "server-ready after $((i+2)) s"
timeout 1200 "$B/redis-benchmark" -p $P -t set -n $KEYS -r $KEYS -d 1024 -c 4 -P 8 -q > /tmp/redis_set.txt 2>&1; m "set rc=$? $(tr "\r" "\n" < /tmp/redis_set.txt | grep -a "requests per" | tail -1)"
eval "${WIN_BEGIN:-:}"
timeout 1200 "$B/redis-benchmark" -p $P -t get -n $GETS -r $KEYS -d 1024 -c 4 -P 8 -q > /tmp/redis_get.txt 2>&1; rc=$?
eval "${WIN_END:-:}"
m "get rc=$rc $(tr "\r" "\n" < /tmp/redis_get.txt | grep -a "requests per" | tail -1)"
echo "RESULT redis done"; kill $S; wait $S 2>/dev/null
