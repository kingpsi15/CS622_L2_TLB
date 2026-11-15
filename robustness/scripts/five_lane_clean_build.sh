#!/usr/bin/env bash
set -euo pipefail

ROOT="${ROOT:-$HOME/CS622_L2_TLB}"
GEM5_SRC="${GEM5_SRC:-$ROOT/gem5}"
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3.10}"
WORK_ROOT="${WORK_ROOT:-/tmp/${USER:-sahilag24}/CS622_L2_TLB}"
SCONS_DIR="${SCONS_DIR:-$WORK_ROOT/scons}"

usage() {
  echo "Usage: $0 [inc|excl|nine|agile|perf]" >&2
  echo "On csewsrm21-25, the lane is detected from the hostname if omitted." >&2
  exit 2
}

detect_lane() {
  case "$(hostname -s)" in
    csewsrm21) echo inc ;;
    csewsrm22) echo excl ;;
    csewsrm23) echo nine ;;
    csewsrm24) echo agile ;;
    csewsrm25) echo perf ;;
    *) return 1 ;;
  esac
}

LANE="${1:-}"
if [[ -z "$LANE" ]]; then
  LANE="$(detect_lane)" || usage
fi
[[ $# -le 1 ]] || usage
case "$LANE" in
  inc|excl|nine|agile|perf) ;;
  *) usage ;;
esac

RESULT_DIR="$ROOT/robustness/results-$LANE"
RUN_LOG="$RESULT_DIR/clean_build.log"
BUILD_LOG="$RESULT_DIR/clean_build_scons.log"
TREE="$WORK_ROOT/gem5-$LANE"
mkdir -p "$RESULT_DIR" "$WORK_ROOT"

log() {
  printf '[%s] [%s] [%s] %s\n' \
    "$(date '+%F %T')" "$(hostname -s)" "$LANE" "$*" | tee -a "$RUN_LOG"
}

ensure_scons() {
  local archive="$ROOT/robustness/vendor/scons-4.8.1.tar.gz"
  local version=""

  if [[ -d "$SCONS_DIR/SCons" ]]; then
    version="$(PYTHONPATH="$SCONS_DIR" "$PYTHON_BIN" -c \
      'import SCons; print(SCons.__version__)' 2>/dev/null || true)"
  fi
  if [[ "$version" != "4.8.1" ]]; then
    [[ -f "$archive" ]] || {
      log "SCons 4.8.1 is unavailable and vendored archive is missing: $archive"
      return 1
    }
    log "installing SCons 4.8.1 from the repository archive (offline)"
    mkdir -p "$SCONS_DIR"
    tar -xzf "$archive" -C "$SCONS_DIR"
    version="$(PYTHONPATH="$SCONS_DIR" "$PYTHON_BIN" -c \
      'import SCons; print(SCons.__version__)' 2>/dev/null || true)"
  fi
  if [[ "$version" != "4.8.1" ]]; then
    log "could not load SCons 4.8.1 from $SCONS_DIR (found: ${version:-none})"
    return 1
  fi
  log "using SCons $version from $SCONS_DIR"
}

main() {
  local cc_file="tlb.cc.$LANE.fixed"
  local hh_file="tlb.hh.$LANE.fixed"
  local cc_path="$GEM5_SRC/src/arch/x86/$cc_file"
  local hh_path="$GEM5_SRC/src/arch/x86/$hh_file"

  [[ -x "$PYTHON_BIN" ]] || { log "Python executable not found: $PYTHON_BIN"; return 1; }
  [[ -d "$GEM5_SRC" ]] || { log "gem5 source tree not found: $GEM5_SRC"; return 1; }
  [[ -f "$cc_path" && -f "$hh_path" ]] || {
    log "fixed TLB sources not found: $cc_path or $hh_path"
    return 1
  }

  log "starting single-lane clean build; source=$GEM5_SRC; worktree=$TREE"
  ensure_scons

  # Reuse a valid temporary checkout for incremental retries. If /tmp was
  # cleared or the copy is incomplete, recreate it from the persistent source.
  if [[ ! -f "$TREE/SConstruct" || ! -d "$TREE/src" ]]; then
    log "creating fresh temporary checkout"
    rm -rf -- "$TREE"
    mkdir -p "$(dirname "$TREE")"
    cp -a "$GEM5_SRC" "$TREE"
  else
    log "reusing existing temporary checkout for incremental build"
  fi
  while IFS= read -r -d '' script; do
    IFS= read -r first_line < "$script" || true
    if [[ "${first_line:-}" == '#!'* ]]; then
      chmod +x "$script"
    fi
    unset first_line
  done < <(find "$TREE" -path "$TREE/build" -prune -o -type f -print0)
  cp "$cc_path" "$TREE/src/arch/x86/tlb.cc"
  cp "$hh_path" "$TREE/src/arch/x86/tlb.hh"
  log "installed $cc_file and $hh_file; restored executable bits on shebang scripts in the temporary tree"

  if (
    cd "$TREE"
    export PATH="$HOME/.local/bin:/usr/sbin:/usr/bin:/bin"
    export CC=gcc-11 CXX=g++-11
    export PYTHONPATH="$SCONS_DIR"
    "$PYTHON_BIN" -m SCons build/X86/gem5.opt -j2 --ignore-style
  ) > >(tee -a "$BUILD_LOG") 2>&1; then
    :
  else
    local build_status=$?
    log "SCons build failed (exit $build_status); see $BUILD_LOG"
    return "$build_status"
  fi

  if [[ ! -x "$TREE/build/X86/gem5.opt" ]]; then
    log "build returned success but gem5.opt is missing; see $BUILD_LOG"
    return 1
  fi
  "$TREE/build/X86/gem5.opt" --help >/dev/null 2>&1 || {
    log "gem5.opt smoke test failed"
    return 1
  }

  log "PASS: $LANE build and smoke test; binary=$TREE/build/X86/gem5.opt"
  log "starting the lane's full-system SPEC CPU2017 test run"
  bash "$ROOT/robustness/scripts/run_spec_fs.sh" "$LANE" "$TREE"
}

main
