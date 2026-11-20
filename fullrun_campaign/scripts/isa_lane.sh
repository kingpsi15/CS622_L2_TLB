#!/bin/bash
# usage: isa_lane.sh LANE SRCHOST TARGETHOST SRC_WORKDIR   (runs on the lane host)
L=$1; SRC=$2; TGT=$3; SW=$4
T=/tmp/sahilag24/CS622_L2_TLB/gem5-$L; N=$T-isa; LOG=/tmp/sahilag24/isa_$L.log
export LD_LIBRARY_PATH=/usr/local/gcc-15.2/lib64:$LD_LIBRARY_PATH
if [ "$L" = excl ]; then
  until grep -q '^done' /tmp/sahilag24/isabuild.log; do sleep 30; done
  grep -q '^done 0' /tmp/sahilag24/isabuild.log || { echo "build failed" > $LOG; exit 1; }
else
  [ -d $N ] || cp -a $T $N
  cd $N || exit 1
  B=src/arch/x86/pagetable_walker.cc.orig_walker
  [ -f $B ] && cp $B src/arch/x86/pagetable_walker.cc
  python3 ~/isa_patch.py $N > $LOG 2>&1 || { echo "patch failed" >> $LOG; exit 1; }
  /opt/anaconda3/bin/python3 -m SCons build/X86/gem5.opt -j16 >> $LOG 2>&1 || { echo "build failed" >> $LOG; exit 1; }
fi
echo "build ok $(date +%T)" >> $LOG
ssh -n -o LogLevel=ERROR sahilag24@csewsrm$TGT.cse.iitk.ac.in "bash ~/spawn_isa.sh $L $SRC '600' $SW" >> $LOG 2>&1
