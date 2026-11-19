#!/usr/bin/env bash
# SE-mode pass/fail for the SPEC speed benchmarks that exceed the 3 GB FS guest
# (631.deepsjeng_s 6.9 GB, 619.lbm_s 3.2 GB), with --mem-size 8GiB, on every
# lane's gem5. Output is compared byte-for-byte with the native run's output
# (which passed SPEC's own compare). Run dirs live under /var/tmp because gem5
# SE redirects guest paths under /tmp.        bash se_bigmem.sh <bench> <lanes...>
set -uo pipefail
B=${1:?bench}; shift; R=/var/tmp/$(id -un)/se_bigmem; G=$R/gem5
case $B in
  631.deepsjeng_s) EXE=deepsjeng_s_base.gem5static-m64; ARGS="test.txt"; OUTF=test.out ;;
  619.lbm_s) EXE=lbm_s_base.gem5static-m64; ARGS="20 reference.dat 0 1 200_200_260_ldc.of"; OUTF=lbm.out ;;
esac
printf "OMP_NUM_THREADS=1
OMP_THREAD_LIMIT=1
" > "$R/guest.env"
for L in "$@"; do
  d=$R/$B/$L; rm -rf "$d"; mkdir -p "$d"; cp -r "$R/src/$B/." "$d/run/"
  (cd "$d/run" && rm -f "$OUTF" && /usr/bin/time -f "wall=%e" \
     "$G/gem5-$L.opt" -re -d "$d/m5out" "$G/configs/deprecated/example/se.py" \
     --cpu-type AtomicSimpleCPU --mem-size 8GiB --env "$R/guest.env" -c "./$EXE" -o "$ARGS" --output "$d/run/$OUTF" > "$d/host.log" 2>&1
   rc=$?
   if cmp -s "$d/run/$OUTF" "$R/src/$B/$OUTF.native"; then v=PASS; else v=FAIL; fi
   echo "SE_RESULT $B $L $v rc=$rc $(grep -h 'chkOracleMismatch\|coltHits' $d/m5out/stats.txt 2>/dev/null | awk '{printf "%s=%s ",$1,$2}')" | tee "$d/result.txt") &
done
wait
