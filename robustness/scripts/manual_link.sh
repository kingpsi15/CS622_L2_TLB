#!/bin/bash
# WORKAROUND on this host: scons compiles every object but never builds libelf.a / links gem5.opt (root cause not found;
# the missing +x on ext/libelf/native-elf-format was one defect but not the only one). Link by hand. usage: VARIANT=x manual_link.sh
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [ -f "$SCRIPT_DIR/env.sh" ]; then
  source "$SCRIPT_DIR/env.sh"
else
  source "$HOME/CS622_L2_TLB/robustness/scripts/env.sh"
fi
export PATH=/usr/sbin:/usr/bin:/bin
T=$INC; E=$T/ext/libelf; O=$W/elfobj; rm -rf $O; mkdir -p $O
PYTHON_CONFIG=${PYTHON_CONFIG:-/usr/bin/python3.10-config}
find $T -path $T/build -prune -o -type f -exec grep -l -m1 '^#!' {} \; 2>/dev/null | xargs -r chmod +x
(cd $E && ./native-elf-format > $O/native-elf-format.h)
for n in convert fsize msize; do m4 -DSRCDIR=$E $E/elf_types.m4 $E/libelf_$n.m4 > $O/libelf_$n.c; done
cp $E/*.h $O/
for f in $E/*.c $O/libelf_convert.c $O/libelf_fsize.c $O/libelf_msize.c; do gcc-11 -c -fPIC -O1 -w -I$O -I$E -o $O/$(basename $f .c).os $f || exit 1; done
(cd $O && ar rcs libelf.a *.os)
cd $T/build/X86
find . -name '*.o' -not -path './gem5.build/*' | grep -v gem5py > $W/o.txt
for f in $(find . -name '*.pyo' -not -path './gem5.build/*' | grep -v gem5py); do [ -f ${f%.pyo}.o ] || echo $f; done >> $W/o.txt
g++-11 -o gem5.opt @$W/o.txt $(ls ext/*/*.a) $O/libelf.a -fuse-ld=gold -Wl,--as-needed -O1 $($PYTHON_CONFIG --embed --ldflags) -lz -lpng -lpthread -ldl -lutil -lm -lrt \
  && touch $W/stamps/build_$VARIANT && log "manual_link $VARIANT: OK $(ls -l gem5.opt | awk '{print $5}') bytes"
