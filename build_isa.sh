#!/bin/bash
export LD_LIBRARY_PATH=/usr/local/gcc-15.2/lib64:$LD_LIBRARY_PATH
cd /tmp/sahilag24/CS622_L2_TLB/gem5-excl-isa || exit 1
/opt/anaconda3/bin/python3 -m SCons build/X86/gem5.opt -j16 > /tmp/sahilag24/isabuild.log 2>&1
echo done $? >> /tmp/sahilag24/isabuild.log
LD_LIBRARY_PATH=$HOME/gcclib timeout 900 ./build/X86/gem5.opt -d /tmp/se600isa configs/deprecated/example/se.py --cpu-type AtomicSimpleCPU --mem-size 2GiB -c /tmp/perl600 -o $HOME/t.pl > /tmp/sahilag24/isatest.log 2>&1
