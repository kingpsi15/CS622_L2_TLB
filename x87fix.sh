#!/bin/bash
lane=$1
T=/tmp/sahilag24/CS622_L2_TLB/gem5-$lane-isa
echo "$(hostname -s) $(date +%H:%M) lane=$lane tree=$T"
[ -d "$T" ] || { echo "NO TREE"; exit 1; }
cd "$T" || exit 1
D=src/arch/x86/isa/insts/x87
[ -f /tmp/x87_orig_$lane.tgz ] || tar czf /tmp/x87_orig_$lane.tgz $D
grep -rl --include=*.py '^[[:space:]]*movfp ' $D | xargs sed -i -E '/^[[:space:]]*movfp /{/dataSize=/!s/[[:space:]]*$/, dataSize=8/}'
echo "movfp lines: $(grep -rh --include=*.py '^[[:space:]]*movfp ' $D | wc -l)  with dataSize=8: $(grep -rh --include=*.py '^[[:space:]]*movfp .*dataSize=8' $D | wc -l)"
cp -n build/X86/gem5.opt build/X86/gem5.opt.pre_x87
export PATH=/usr/local/gcc-15.2/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/gcc-15.2/lib64:$HOME/gcclib:$LD_LIBRARY_PATH
/opt/anaconda3/bin/python3 -m SCons build/X86/gem5.opt -j8 2>&1 | tail -n 15
echo "BUILD DONE $(date +%H:%M)"; ls -la --time-style=+%d-%H:%M build/X86/gem5.opt build/X86/gem5.opt.pre_x87
if [ "$lane" = excl ]; then
  export LD_LIBRARY_PATH=$HOME/gcclib
  grep -a -E '^(cmd|executable)=' /tmp/se_tr1/config.ini
  printf 'printf("%%a %%a %%a\\n", 0, 1, 0);\n' > $HOME/c2.pl
  g(){ rm -rf /tmp/se_v; timeout 600 ./build/X86/gem5.opt -d /tmp/se_v configs/deprecated/example/se.py --cpu-type AtomicSimpleCPU --mem-size 2GiB -c "$1" ${3:+-o "$3"} 2>&1 | grep -a -E "$2"; }
  chk(){ if [ "$2" = "$3" ]; then echo "MATCH $1"; else echo "DIFF  $1"; echo "  native: $2"; echo "  gem5  : $3"; fi; }
  for m in 0 1 2 3 4; do chk "x87s $m" "$(/tmp/x87s $m)" "$(g /tmp/x87s '^S[0-9]' $m)"; done
  for d in 0 1 2 3; do for p in 0 1 2; do chk "x87q $d $p" "$(/tmp/x87q $d $p)" "$(g /tmp/x87q '^D[0-9]' "$d $p")"; done; done
  for d in 0 1 4 5 6 7 8 9; do chk "x87r $d" "$(/tmp/x87r $d)" "$(g /tmp/x87r '^R[0-9]' $d)"; done
  chk x87y "$(/tmp/x87y)" "$(g /tmp/x87y '^Y')"
  chk x87z "$(/tmp/x87z)" "$(g /tmp/x87z '^Z')"
  for c in c1 c2 c3; do chk "perl $c" "$(/tmp/perl600 $HOME/$c.pl)" "$(g /tmp/perl600 '^-?0x' $HOME/$c.pl)"; done
  echo "VERIFY DONE $(date +%H:%M)"
fi
