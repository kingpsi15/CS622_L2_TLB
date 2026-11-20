#!/bin/bash
C=/tmp/sahilag24/work-nine/cpu2017/benchspec/CPU
P=/tmp/sahilag24/memprobe; mkdir -p $P
ulimit -s unlimited; ulimit -v 16777216
meas() {
python3 - "$1" "$2" <<'PY'
import subprocess, resource, sys, time
t = time.time()
try:
    r = subprocess.run(sys.argv[2], shell=True, cwd=sys.argv[1], executable="/bin/bash", timeout=1500)
    rc = r.returncode
except subprocess.TimeoutExpired:
    rc = "TIMEOUT"
kb = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss
print("   rc=%s peakRSS=%.2f GiB wall=%ds" % (rc, kb/1048576.0, time.time()-t), flush=True)
PY
}
run() { # bench dirname cmd...
  b=$1; shift
  rm -rf $P/$b; cp -r $C/$b/run/run_base_test_gem5static-m64.0000 $P/$b
  echo "=== $b"
  for c in "$@"; do echo "  $c"; meas $P/$b "$c"; done
}
run 631.deepsjeng_s "./deepsjeng_s_base.gem5static-m64 test.txt > test.out 2> test.err"
run 605.mcf_s "./mcf_s_base.gem5static-m64 inp.in > inp.out 2> inp.err"
run 654.roms_s "./sroms_base.gem5static-m64 < ocean_benchmark0.in > o.log 2> o.err"
run 603.bwaves_s "./speed_bwaves_base.gem5static-m64 bwaves_1 < bwaves_1.in > o1.out 2> o1.err" "./speed_bwaves_base.gem5static-m64 bwaves_2 < bwaves_2.in > o2.out 2> o2.err"
run 649.fotonik3d_s "./fotonik3d_s_base.gem5static-m64 > f.log 2> f.err"
run 628.pop2_s "./speed_pop2_base.gem5static-m64 > p.out 2> p.err"
run 627.cam4_s "./cam4_s_base.gem5static-m64 > c.txt 2> c.err"
run 621.wrf_s "./wrf_s_base.gem5static-m64 > rsl.out.0000 2> wrf.err"
echo ALLDONE
