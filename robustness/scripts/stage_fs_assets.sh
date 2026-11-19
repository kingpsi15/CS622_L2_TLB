#!/usr/bin/env bash
# Copy one lane's FS inputs from another account's /tmp into NFS staging.
#   bash stage_fs_assets.sh <lane> [shared]   (SRC_USER=sahilag24 by default)
# "shared" also stages the kernel, Ubuntu image and SPEC tree (same for all lanes).
set -euo pipefail
L=${1:?lane}; SU=${SRC_USER:-sahilag24}; A=$HOME/fsassets; mkdir -p "$A"
case $L in inc) WS=work;; *) WS=work-$L;; esac
cp /tmp/$SU/CS622_L2_TLB/gem5-$L/build/X86/gem5.opt "$A/gem5-$L.opt.part" && mv "$A/gem5-$L.opt.part" "$A/gem5-$L.opt"
if [[ ${2:-} == shared ]]; then
  cp /tmp/$SU/$WS/dl/vmlinux-x86-ubuntu-6.8.0-52-generic "$A/"
  cp /tmp/$SU/$WS/dl/x86-ubuntu-24.04.img "$A/x86-ubuntu-24.04.img.part" && mv "$A/x86-ubuntu-24.04.img.part" "$A/x86-ubuntu-24.04.img"
  tar -C /tmp/$SU/$WS -cf "$A/cpu2017.tar.part" cpu2017 && mv "$A/cpu2017.tar.part" "$A/cpu2017.tar"
fi
echo "STAGED $L $(date +%T)"
