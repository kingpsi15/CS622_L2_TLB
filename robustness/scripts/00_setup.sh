#!/bin/bash
# Phase 0: downloads (need internet; done FIRST), SPEC install, gem5 trees + builds.
# Idempotent: re-running skips finished stages. Safe to re-run after /tmp is wiped.
source "$(dirname "$0")/env.sh"
JOBS=${JOBS:-14}

dl_kernel() {
    cd $W/dl && wget -c -t 50 --retry-connrefused --waitretry=30 -nv \
      https://dist.gem5.org/dist/develop/kernels/x86/static/vmlinux-x86-ubuntu-6.8.0-52-generic
    # DB md5 (b52643ae...) is stale; verified copy used in campaign has md5 341f1c156725d8611c2fcd32d42459fa
    file vmlinux-x86-ubuntu-6.8.0-52-generic | grep -q "ELF 64-bit"
}
dl_disk() {
    cd $W/dl && wget -c -t 50 --retry-connrefused --waitretry=30 -nv \
      https://dist.gem5.org/dist/develop/images/x86/ubuntu-24-04/x86-ubuntu-24.04-20250515.gz
    echo "fb91c0ef6a6120a3411cddb7d7fce47e  x86-ubuntu-24.04-20250515.gz" | md5sum -c
    gunzip -c x86-ubuntu-24.04-20250515.gz > x86-ubuntu-24.04.img.tmp && mv x86-ubuntu-24.04.img.tmp x86-ubuntu-24.04.img
    ls -l x86-ubuntu-24.04.img
}
spec_install() {
    cd $W && rm -rf spec2017-installer && mkdir spec2017-installer && cd spec2017-installer
    xz -T0 -dc "$SPECTAR" | tar x
    cd spec2017 && echo yes | ./install.sh -f -d "$SPEC"
    ls "$SPEC"/benchspec/CPU | head -60
}
make_tree() {   # make_tree DEST tlb.cc tlb.hh
    local d=$1
    rsync -a --delete --exclude=.git --exclude=build --exclude=results_v2 --exclude=presentation \
        $H/gem5/ "$d"/
    cp "$2" "$d"/src/arch/x86/tlb.cc; cp "$3" "$d"/src/arch/x86/tlb.hh
    # tracked helper scripts lost their +x bits in git; fix only in the /tmp copy
    find "$d" -path "$d/build" -prune -o -type f -exec grep -l -m1 "^#!" {} ; 2>/dev/null | xargs -r chmod +x   # ALL shebang scripts (native-elf-format etc.), not only .py
    md5sum "$d"/src/arch/x86/tlb.cc "$d"/src/arch/x86/tlb.hh
}
tree_inc()  { make_tree $INC  $H/gem5/src/arch/x86/tlb.cc.inclusive.sa $H/gem5/src/arch/x86/tlb.hh.inclusive.sa
              # campaign instrumentation (invariant + stale-translation checker), if present
              if [ -f $R/patches/inclusive_checker.patch ]; then cd $INC && patch -p1 < $R/patches/inclusive_checker.patch; fi; }
tree_base() { make_tree $BASE $R/patches/stock/tlb.cc $R/patches/stock/tlb.hh; }
build() {  # build TREE
    cd "$1" && python3 --version && $CXX --version | head -1
    scons build/X86/gem5.opt -j $JOBS --linker=gold --ignore-style
    ls -l build/X86/gem5.opt
}
build_m5() { cd $INC/util/m5 && scons build/x86/out/m5 -j 8 && ls -l build/x86/out/; }

# downloads first, in parallel with SPEC install (no network) and builds
( stage dl_kernel dl_kernel; stage dl_disk dl_disk ) &
( stage spec_install spec_install ) &
( stage tree_inc tree_inc && stage build_inc build $INC && stage build_m5 build_m5 ) &
( stage tree_base tree_base && stage build_base build $BASE ) &
wait
log "00_setup.sh finished; stamps: $(ls $W/stamps | tr '\n' ' ')"
