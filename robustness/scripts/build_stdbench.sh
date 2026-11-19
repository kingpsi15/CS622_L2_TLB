#!/usr/bin/env bash
# Download and build the standard TLB-intensive workloads as static binaries
# into $1 (default ~/stdbench_bin), plus the pre-generated GAPBS graphs.
#
#   bash build_stdbench.sh [out_dir]          (~10 min, needs internet + gcc-11)
#
# GAPBS (bfs pr cc bc sssp tc + converter), XSBench (openmp-threading),
# STREAM (20M elements), memcached 1.6.29 + libevent 2.1.12 + mc-crusher,
# Redis 7.2.5 (server + redis-benchmark). Graphs: kron20.sg, urand20.sg,
# kron20.wsg (2^20 vertices). Also copies the drivers run_memcached.sh,
# run_redis.sh and the mc-crusher configs from ../benchmarks/stdbench.
set -euo pipefail
O=${1:-$HOME/stdbench_bin}; HERE=$(cd "$(dirname "$0")" && pwd)
W=$(mktemp -d); mkdir -p "$O"; cd "$W"; export CC=${CC:-gcc-11} CXX=${CXX:-g++-11}
git clone -q --depth 1 https://github.com/sbeamer/gapbs.git
git clone -q --depth 1 https://github.com/ANL-CESAR/XSBench.git
git clone -q --depth 1 https://github.com/jeffhammond/STREAM.git
git clone -q --depth 1 https://github.com/memcached/mc-crusher.git
curl -sSLo memcached.tgz https://memcached.org/files/memcached-1.6.29.tar.gz
curl -sSLo libevent.tgz https://github.com/libevent/libevent/releases/download/release-2.1.12-stable/libevent-2.1.12-stable.tar.gz
curl -sSLo redis.tgz https://download.redis.io/releases/redis-7.2.5.tar.gz
for k in bfs pr cc bc sssp tc converter; do $CXX -std=c++11 -O3 -static gapbs/src/$k.cc -o "$O/gapbs_$k"; done
(cd XSBench/openmp-threading && $CC -std=gnu99 -O3 -static -fopenmp *.c -o "$O/xsbench" -lm)
$CC -O3 -static -DSTREAM_ARRAY_SIZE=20000000 -DNTIMES=3 STREAM/stream.c -o "$O/stream"
tar -xzf libevent.tgz && tar -xzf memcached.tgz && tar -xzf redis.tgz
P=$W/le
(cd libevent-2.1.12-stable && ./configure -q --prefix=$P --disable-shared --disable-openssl --disable-samples --disable-libevent-regress && make -s -j8 && make -s install) >/dev/null
(cd memcached-1.6.29 && ./configure -q --with-libevent=$P LDFLAGS=-static && make -s -j8) >/dev/null
(cd mc-crusher && $CC -O2 -static -I$P/include -o mc-crusher mc-crusher.c pcg-basic.c itoa_ljust.c $P/lib/libevent.a -lm -lpthread)
(cd redis-7.2.5 && make -s -j16 MALLOC=libc BUILD_TLS=no USE_SYSTEMD=no LDFLAGS=-static) >/dev/null
cp memcached-1.6.29/memcached mc-crusher/mc-crusher redis-7.2.5/src/redis-server redis-7.2.5/src/redis-benchmark "$O/"
cp "$HERE"/../benchmarks/stdbench/* "$O/"
cd "$O" && ./gapbs_converter -g 20 -b kron20.sg && ./gapbs_converter -u 20 -b urand20.sg && ./gapbs_converter -g 20 -wb kron20.wsg
rm -rf "$W"; ls -la "$O"
