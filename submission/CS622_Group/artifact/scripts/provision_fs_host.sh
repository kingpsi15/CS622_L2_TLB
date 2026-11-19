#!/usr/bin/env bash
# On a fresh lab host: pull one lane's FS inputs from a source host's
# /tmp/$SRC_USER over ssh (needs agent forwarding), laid out like a lane
# workspace so run_spec_fs_shards.sh works with TLB_USER=$USER unchanged.
#   bash provision_fs_host.sh <lane> <src_host>
set -euo pipefail
L=${1:?lane}; SRC=${2:?src host}; SU=${SRC_USER:-sahilag24}; U=$(id -un)
case $L in inc) WS=work;; *) WS=work-$L;; esac
W=/tmp/$U/$WS; T=/tmp/$U/CS622_L2_TLB/gem5-$L/build/X86
mkdir -p "$W" "$T"
R="ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new $SRC"
[[ -s $T/gem5.opt ]] || { $R "cat /tmp/$SU/CS622_L2_TLB/gem5-$L/build/X86/gem5.opt" > "$T/gem5.opt.part"; mv "$T/gem5.opt.part" "$T/gem5.opt"; chmod +x "$T/gem5.opt"; }
[[ -s $W/dl/x86-ubuntu-24.04.img && -d $W/cpu2017 ]] || \
  $R "tar -C /tmp/$SU/${ASSET_WS:-$WS} --exclude=cpu2017/tmp --ignore-failed-read -cf - dl/vmlinux-x86-ubuntu-6.8.0-52-generic dl/x86-ubuntu-24.04.img cpu2017" | tar -C "$W" -xf -
# Bake TLB microbenchmarks into the SPEC disk (built by build_microbench.sh).
if [[ -d $HOME/tlbbench_bin ]]; then mkdir -p "$W/cpu2017/tlbbench"; cp "$HOME"/tlbbench_bin/* "$W/cpu2017/tlbbench/"; fi
S=$W/spec2017.fs.img
if [[ ! -s $S ]]; then
  b=$(du -sb "$W/cpu2017" | awk '{print $1}'); truncate -s $((b + b/10 + 1073741824)) "$S"
  /sbin/mkfs.ext4 -F -q -L SPEC2017 -d "$W/cpu2017" "$S"
fi
echo "PROVISIONED $L $(hostname) $(date +%T)"
