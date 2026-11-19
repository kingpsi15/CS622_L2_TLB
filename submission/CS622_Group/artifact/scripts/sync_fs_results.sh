#!/usr/bin/env bash
# Laptop side: pull run outputs (not disk images/SPEC/gem5 binaries) from every
# lab host into fs_results/<host>/, every 30 min. Usage: bash sync_fs_results.sh [once]
DEST=${DEST:-$(cd "$(dirname "$0")/../.." && pwd)/fs_results}
HOSTS=${HOSTS:-"csews2 csews4 csews5 csewsrm7 csewsrm9 csews12 csews14 csews16 csews18 csews19 csews21 csews22 csews23 csews25 csews26 csews24 csews31 csews37 csews1 csews7 csews8 csews9 csews10 csews11 csews13 csews15 csews38 csews39 csews28 csews29 csews36 csews30 csews35 csews40 csews20 csewsrm22 csewsrm23 csewsrm24 csewsrm25"}
SAHIL_HOSTS=${SAHIL_HOSTS:-"csews20 csewsrm22 csewsrm23 csewsrm24 csewsrm25 csewsrm2 csewsrm3 csewsrm4 csewsrm5 csewsrm6 csewsrm8 csewsrm10 csewsrm11 csewsrm12 csewsrm13 csewsrm26 csewsrm27 csewsrm28 csewsrm29 csewsrm30 csewsrm31 csewsrm32 csewsrm33 csewsrm34 csewsrm35"}
while :; do
  for H in $HOSTS; do
    mkdir -p "$DEST/$H"
    ssh -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 adityasv24@$H.cse.iitk.ac.in \
      'cd /tmp && ls -d adityasv24/runs adityasv24/long adityasv24/micro adityasv24/ref adityasv24/std adityasv24/reruns adityasv24_wide_*.log prov_adityasv24_*.log 2>/dev/null | xargs -r tar --exclude="*.img" --exclude="*.cpt" -czf - 2>/dev/null' \
      2>/dev/null | tar -xzf - -C "$DEST/$H" 2>/dev/null && echo "$(date +%T) synced $H" || echo "$(date +%T) $H unreachable/empty"
  done
  # Sahil's outputs (world-readable): logs/runs/stats only, no images, SPEC or gem5 trees.
  for H in $SAHIL_HOSTS; do
    mkdir -p "$DEST/sahilag24/$H"
    ssh -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o StrictHostKeyChecking=accept-new adityasv24@$H.cse.iitk.ac.in       'cd /tmp && [ -d sahilag24 ] && find sahilag24 \( -name cpu2017 -o -name spec-dl -o -name build -o -name .git -o -name gem5-resources -o -name "gem5-*" -o -name CS622_L2_TLB -o -name sc -o -name 90-gem5 -o -name spec2017-installer -o -name spec2017 -o -name tests \) -prune -o -type f -size -50M -readable -print0 2>/dev/null | tar --null -T - -czf - 2>/dev/null'       2>/dev/null | tar -xzf - -C "$DEST/sahilag24/$H" 2>/dev/null && echo "$(date +%T) synced sahil@$H" || echo "$(date +%T) sahil@$H unreachable/empty"
  done
  echo "$(date '+%F %T') SYNC DONE $(du -sh "$DEST" | cut -f1)" | tee -a "$DEST/sync.log"
  [[ ${1:-} == once ]] && break
  sleep 1800
done
