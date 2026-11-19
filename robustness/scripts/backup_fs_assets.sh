#!/usr/bin/env bash
# Laptop side: back up each lane's FS inputs (gem5.opt, kernel, Ubuntu image,
# SPEC tree minus regenerable run dirs) as gzip tarballs into fs_assets_backup/.
# Restore on any host: mkdir -p /tmp/$USER && tar -xzf <lane>.tar.gz -C /tmp/$USER
# then rebuild spec2017.fs.img with provision_fs_host.sh's mkfs step.
DEST=$(cd "$(dirname "$0")/../.." && pwd)/fs_assets_backup; mkdir -p "$DEST"
for p in inc:csews2:work excl:csewsrm7:work-excl nine:csewsrm9:work-nine agile:csews16:work-agile perf:csews18:work-perf; do
  IFS=: read L H WS <<<"$p"; f=$DEST/$L.tar.gz
  [[ -s $f ]] && { echo "skip $L"; continue; }
  echo "$(date +%T) start $L from $H"
  ssh -o BatchMode=yes -o ServerAliveInterval=30 adityasv24@$H.cse.iitk.ac.in \
    "cd /tmp/adityasv24 && nice tar --sparse --exclude='cpu2017/benchspec/CPU/*/run' --exclude=cpu2017/tmp -cf - CS622_L2_TLB/gem5-$L/build/X86/gem5.opt $WS/dl/vmlinux-x86-ubuntu-6.8.0-52-generic $WS/dl/x86-ubuntu-24.04.img $WS/cpu2017 | nice gzip -1" > "$f.part" \
    && mv "$f.part" "$f" && echo "$(date +%T) done $L $(du -h "$f" | cut -f1)" || echo "$(date +%T) FAILED $L"
done
