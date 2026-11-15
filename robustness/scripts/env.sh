# Shared environment for the inclusive-L2-TLB robustness campaign.
# Source this file; do not execute it.
#   H   = persistent home copy (scripts, verified patches, and results)
#   W   = this lane's scratch work area in /tmp (may be wiped; rebuildable)
export H=$HOME/CS622_L2_TLB
export R=$H/robustness
# VARIANT selects this machine's lane. Each lane runs on its own computer and
# keeps its build, downloaded assets, and SPEC installation in its local /tmp.
export VARIANT=${VARIANT:-inc}
case $VARIANT in
  inc)  export W=/tmp/sahilag24/work;      LANELOG=INCLUSIVE_TLB_RESULTS_LOG.md;  RESDIR=results ;;
  excl) export W=/tmp/sahilag24/work-excl; LANELOG=EXCLUSIVE_TLB_RESULTS_LOG.md;  RESDIR=results-excl ;;
  nine) export W=/tmp/sahilag24/work-nine; LANELOG=NINE_TLB_RESULTS_LOG.md;       RESDIR=results-nine ;;
  agile) export W=/tmp/sahilag24/work-agile; LANELOG=AGILE_TLB_RESULTS_LOG.md;     RESDIR=results-agile ;;
  perf) export W=/tmp/sahilag24/work-perf;  LANELOG=PERFORATED_TLB_RESULTS_LOG.md; RESDIR=results-perf ;;
  *) echo "unknown VARIANT"; return 1 ;;
esac
export SHARED=$W
export RES=$R/$RESDIR
export SPECTAR=$W/spec-dl/spec2017.tar.xz
# SPEC stays in this machine's /tmp workspace. Full-system SPEC runs expose it
# to the guest through a lane-local disk image.
export SPEC=$W/cpu2017
export LOG=$H/$LANELOG
export INC=$W/gem5-$VARIANT   # gem5 tree with this lane's TLB policy (inc|excl|nine)
export BASE=$SHARED/gem5-base   # gem5 with stock upstream v25.1.0.1 TLB (differential baseline)
export FS_KERNEL=$SHARED/dl/vmlinux-x86-ubuntu-6.8.0-52-generic
export FS_DISK=$SHARED/dl/x86-ubuntu-24.04.img
# Hide anaconda (python 3.13 / gcc 15 / grpc plugin) - gem5 25.1 builds with gcc-11 + python3.10
export PYTHON_BIN=/usr/bin/python3.10
export PYTHON_CONFIG=/usr/bin/python3.10-config
mkdir -p "$HOME/.local/bin"
if [ ! -e "$HOME/.local/bin/python3" ] || [ "$(readlink -f "$HOME/.local/bin/python3")" != "/usr/bin/python3.10" ]; then
  ln -sf /usr/bin/python3.10 "$HOME/.local/bin/python3"
fi
if [ ! -e "$HOME/.local/bin/python" ] || [ "$(readlink -f "$HOME/.local/bin/python")" != "/usr/bin/python3.10" ]; then
  ln -sf /usr/bin/python3.10 "$HOME/.local/bin/python"
fi
export PATH="$HOME/.local/bin:/usr/sbin:/usr/bin:/bin"
export CC=gcc-11 CXX=g++-11
export GEM5_RESOURCE_DIR=$W/gem5-resources
mkdir -p "$W"/{dl,logs,runs,stamps,jobs,tests} "$RES"

# log "message"  -> timestamped line in the persistent home log + stdout
log() { printf -- '- %s — %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; echo "[$(date +%T)] $*"; }

# stage NAME cmd...  -> run once (stamp file), output to $W/logs/NAME.log
stage() {
    local name=$1; shift
    if [ -f "$W/stamps/$name" ]; then echo "skip $name (done)"; return 0; fi
    log "stage $name: START"
    if "$@" > "$W/logs/$name.log" 2>&1; then
        touch "$W/stamps/$name"; log "stage $name: OK"
    else
        log "stage $name: **FAILED** (log: $W/logs/$name.log; tail copied to $RES/$name.fail.txt)"
        tail -60 "$W/logs/$name.log" > "$RES/$name.fail.txt"; return 1
    fi
}
