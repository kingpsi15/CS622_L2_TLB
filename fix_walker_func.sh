#!/bin/bash
# usage: fix_walker_func.sh LANE   (runs on the lane host)
set -e
L=$1; T=/tmp/sahilag24/CS622_L2_TLB/gem5-$L; N=$T-fix
[ -d $N ] || cp -a $T $N
python3 - $N/src/arch/x86/pagetable_walker.cc <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
if "sendFunctional(write)" in s:
    print("already patched"); sys.exit(0)
old="""                write->setLE<uint32_t>(pte);
            delete oldRead;"""
new="""                write->setLE<uint32_t>(pte);
            walker->port.sendFunctional(write);
            delete write;
            write = NULL;
            delete oldRead;"""
assert s.count(old)==1, "pattern not found"
open(p,'w').write(s.replace(old,new))
print("patched")
PY
grep -n "sendFunctional(write)" $N/src/arch/x86/pagetable_walker.cc
cd $N && tmux new -d -s fixbuild "export LD_LIBRARY_PATH=/usr/local/gcc-15.2/lib64:\$LD_LIBRARY_PATH; scons build/X86/gem5.opt -j6 > /tmp/sahilag24/fixbuild-$L.log 2>&1; echo done \$? >> /tmp/sahilag24/fixbuild-$L.log"
