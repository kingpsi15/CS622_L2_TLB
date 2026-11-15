#!/usr/bin/env bash
set -euo pipefail

LANE="${1:-}"
TREE="${2:-}"
case "$LANE" in
  inc|excl|nine|agile|perf) ;;
  *) echo "Usage: $0 <inc|excl|nine|agile|perf> <built-gem5-tree>" >&2; exit 2 ;;
esac
[[ -n "$TREE" ]] || { echo "A built gem5 tree is required" >&2; exit 2; }

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
export VARIANT="$LANE"
source "$SCRIPT_DIR/env.sh"
INC="$TREE"
GEM5="$TREE/build/X86/gem5.opt"
SPEC_DISK="$W/spec2017.fs.img"
RESULT_DIR="$ROOT/robustness/results-$LANE"
mkdir -p "$RESULT_DIR"
RUN_LOG="$RESULT_DIR/spec_fs.log"
RESULTS_TSV="$RESULT_DIR/spec_fs_results.tsv"

log() {
  printf '[%s] [%s] [%s] %s\n' \
    "$(date '+%F %T')" "$(hostname -s)" "$LANE" "$*" | tee -a "$RUN_LOG"
}

ensure_fs_assets() {
  mkdir -p "$W/dl"
  local kernel="$W/dl/vmlinux-x86-ubuntu-6.8.0-52-generic"
  local disk="$W/dl/x86-ubuntu-24.04.img"
  local disk_archive="$W/dl/x86-ubuntu-24.04-20250515.gz"

  if [[ ! -s "$kernel" ]]; then
    log "downloading full-system kernel into /tmp"
    (cd "$W/dl" && wget -c -t 50 --retry-connrefused --waitretry=30 -nv \
      https://dist.gem5.org/dist/develop/kernels/x86/static/vmlinux-x86-ubuntu-6.8.0-52-generic)
  fi
  file "$kernel" | grep -q "ELF 64-bit" || {
    log "invalid x86 full-system kernel: $kernel"
    return 1
  }

  if [[ ! -s "$disk" ]]; then
    if [[ ! -s "$disk_archive" ]]; then
      log "downloading Ubuntu full-system disk into /tmp"
      (cd "$W/dl" && wget -c -t 50 --retry-connrefused --waitretry=30 -nv \
        https://dist.gem5.org/dist/develop/images/x86/ubuntu-24-04/x86-ubuntu-24.04-20250515.gz)
    fi
    echo "b38e011663259220cbdb00a14272d1bc  $disk_archive" | md5sum -c
    gunzip -c "$disk_archive" > "$disk.tmp"
    mv "$disk.tmp" "$disk"
  fi
  [[ -s "$disk" ]] || { log "full-system disk missing: $disk"; return 1; }
  export FS_KERNEL="$kernel" FS_DISK="$disk"
}

ensure_spec() {
  if [[ ! -x "$SPEC/bin/runcpu" ]]; then
    local delay=0
    case "$LANE" in
      excl) delay=180 ;;
      nine) delay=360 ;;
      agile) delay=540 ;;
      perf) delay=720 ;;
    esac
    if [[ ! -s "$SPECTAR" ]]; then
      log "SPEC is not installed or downloaded in /tmp; download stagger=${delay}s"
      sleep "${SPEC_DOWNLOAD_STAGGER:-$delay}"
    fi
    VARIANT="$LANE" bash "$SCRIPT_DIR/03_get_spec.sh" 2>&1 | tee -a "$RUN_LOG"
  fi
  [[ -x "$SPEC/bin/runcpu" ]] || {
    log "SPEC installation missing runcpu at $SPEC/bin/runcpu"
    return 1
  }
}

ensure_spec_built() {
  local need_build=0
  if ! compgen -G "$SPEC/benchspec/CPU/*/exe/*gem5static*" >/dev/null; then
    log "building static SPEC CPU2017 binaries and test run directories in /tmp"
    rm -f "$W/stamps/spec_build" "$W/stamps/spec_setup"
    need_build=1
  elif ! compgen -G "$SPEC/benchspec/CPU/*/run/run_base_test_gem5static*" >/dev/null; then
    log "SPEC test run directories are missing; regenerating them in /tmp"
    rm -f "$W/stamps/spec_setup"
    need_build=1
  elif ! compgen -G "$SPEC/benchspec/CPU/510.parest_r/exe/*gem5static*" >/dev/null; then
    log "510.parest_r static build is missing; applying GCC 11 fix and rebuilding SPEC"
    rm -f "$W/stamps/spec_build" "$W/stamps/spec_setup"
    need_build=1
  fi
  if (( need_build )); then
    SPEC_BUILD_JOBS="${SPEC_BUILD_JOBS:-4}" bash "$SCRIPT_DIR/01_spec_build.sh" \
      >> "$RUN_LOG" 2>&1
    # The guest sees a snapshot of SPEC. A rebuilt executable must be copied
    # into a newly created disk image on this host before the next boot.
    rm -f -- "$SPEC_DISK"
  fi
  if ! compgen -G "$SPEC/benchspec/CPU/*/exe/*gem5static*" >/dev/null; then
    log "SPEC build produced no gem5static executables; missing benchmarks will be logged as FAIL"
  fi
  if ! compgen -G "$SPEC/benchspec/CPU/*/run/run_base_test_gem5static*" >/dev/null; then
    log "SPEC test run directories are missing; missing benchmarks will be logged as FAIL"
  fi
}

prepare_spec_disk() {
  if [[ -s "$SPEC_DISK" ]]; then
    log "reusing SPEC guest data disk $SPEC_DISK"
    return
  fi
  command -v mkfs.ext4 >/dev/null || { log "mkfs.ext4 is required"; return 1; }
  local data_bytes free_bytes disk_bytes
  data_bytes=$(du -sb "$SPEC" | awk '{print $1}')
  free_bytes=$(df -PB1 "$W" | awk 'NR == 2 {print $4}')
  disk_bytes=$((data_bytes + data_bytes / 10 + 1073741824))
  if (( free_bytes < disk_bytes )); then
    log "insufficient /tmp space for SPEC guest disk: need about $disk_bytes bytes, have $free_bytes"
    return 1
  fi
  log "creating guest-visible SPEC data disk in /tmp ($disk_bytes bytes)"
  truncate -s "$disk_bytes" "$SPEC_DISK"
  if ! mkfs.ext4 -F -q -L SPEC2017 -d "$SPEC" "$SPEC_DISK"; then
    rm -f "$SPEC_DISK"
    log "failed to create SPEC ext4 data disk"
    return 1
  fi
}

run_suite() {
  local guest_script="$W/jobs/spec_fs_guest.sh"
  local out="$W/runs/spec_fs_${LANE}_$(date '+%Y%m%d_%H%M%S')"
  local gen_output start_cpu
  mkdir -p "$out"

  # Most lane hosts have /dev/kvm but the user is not in its ACL/group. Pick
  # the boot CPU before gem5 constructs a KVM VM; otherwise all benchmarks get
  # misleading missing-result-marker failures without ever reaching the guest.
  start_cpu=${FS_START_CPU:-}
  if [[ -z "$start_cpu" ]]; then
    if [[ -r /dev/kvm && -w /dev/kvm ]]; then
      start_cpu=kvm
    else
      start_cpu=atomic
    fi
  fi
  case "$start_cpu" in
    kvm|atomic) ;;
    *) log "invalid FS_START_CPU=$start_cpu (expected kvm or atomic)"; return 2 ;;
  esac
  log "full-system boot CPU=$start_cpu; /dev/kvm access: read=$([[ -r /dev/kvm ]] && echo yes || echo no), write=$([[ -w /dev/kvm ]] && echo yes || echo no)"

  # Reuse only benchmark PASS results from this exact gem5 binary and SPEC
  # executable set. The guest writes logs to its disk image, so that image's
  # modification time is not a stable identity across retries.
  local pass_cache="$RESULT_DIR/spec_fs_pass_cache.tsv" run_key
  run_key=$({
    sha256sum "$GEM5" "$SPEC/config/gem5-static.cfg" \
      "$SPEC/config/gem5-static-parest.cfg" "$SCRIPT_DIR/gen_spec_fs_guest.py"
    find "$SPEC/benchspec/CPU" -path '*/exe/*gem5static*' -type f -print0 \
      | sort -z | xargs -0 -r sha256sum
  } | sha256sum | cut -d' ' -f1)
  gen_output=$(SPEC_PASS_CACHE="$pass_cache" SPEC_RUN_KEY="$run_key" \
    "$PYTHON_BIN" "$SCRIPT_DIR/gen_spec_fs_guest.py")
  log "$gen_output"
  local expected
  expected=$(sed -n 's/.*: \([0-9][0-9]*\) SPEC benchmarks.*/\1/p' <<< "$gen_output")
  [[ "$expected" =~ ^[0-9]+$ ]] || { log "could not determine SPEC test count"; return 1; }

  log "starting full-system SPEC test-input run: $expected benchmarks; gem5=$GEM5"
  local gem5_status=0
  if ! (cd "$TREE" && "$GEM5" -re -d "$out" "$SCRIPT_DIR/fs_run.py" \
      --cores 1 --cpu timing --start-cpu "$start_cpu" \
      --script "$guest_script" --spec-disk "$SPEC_DISK") \
      > "$out/gem5_host.log" 2>&1; then
    log "gem5 full-system SPEC run failed; see $out/gem5_host.log"
    tail -n 25 "$out/gem5_host.log" | tee -a "$RUN_LOG"
    gem5_status=1
  fi

  local serial="$out/serial.log"
  : > "$serial"
  find "$out" -type f \( -name '*.device' -o -name 'simout.txt' \) \
    -exec cat {} + >> "$serial"
  local count=0 passed=0 marker_count=0
  declare -A result_status=() result_detail=()
  if [[ ! -e "$RESULTS_TSV" ]]; then
    printf 'timestamp\thost\tlane\tbenchmark\tverdict\tdetail\n' > "$RESULTS_TSV"
  fi
  while IFS= read -r result; do
    local bench verdict detail
    bench=$(awk '{print $2}' <<< "$result")
    verdict=$(awk '{print $3}' <<< "$result")
    detail=$(cut -d' ' -f4- <<< "$result")
    result_status["$bench"]="$verdict"
    result_detail["$bench"]="$detail"
    marker_count=$((marker_count + 1))
  done < <(grep -E '^SPEC_RESULT [^ ]+ (PASS|FAIL)' "$serial" || true)

  for bench in "${!result_status[@]}"; do
    if [[ "${result_status[$bench]}" == PASS && \
          "${result_detail[$bench]}" != cached-pass ]]; then
      printf '%s\t%s\n' "$run_key" "$bench" >> "$pass_cache"
    fi
  done

  if grep -q '^SPEC_SETUP_FAIL ' "$serial"; then
    log "$(grep '^SPEC_SETUP_FAIL ' "$serial" | tail -n 1)"
  fi
  while IFS= read -r bench; do
    [[ -n "$bench" ]] || continue
    local verdict detail
    verdict="${result_status[$bench]:-FAIL}"
    detail="${result_detail[$bench]:-missing-result-marker}"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$(date '+%F %T')" "$(hostname -s)" "$LANE" "$bench" "$verdict" "$detail" \
      >> "$RESULTS_TSV"
    log "SPEC_RESULT $bench $verdict $detail"
    count=$((count + 1))
    [[ "$verdict" == PASS ]] && passed=$((passed + 1))
  done < "$W/jobs/spec_fs_benchmarks.txt"

  "$PYTHON_BIN" - "$RESULTS_TSV" "$LANE" "$RESULT_DIR/spec_fs_results.md" <<'PY'
import csv
import sys

tsv_path, lane, markdown_path = sys.argv[1:]
latest = {}
with open(tsv_path, newline="", encoding="utf-8") as f:
    for row in csv.DictReader(f, delimiter="\t"):
        if row["lane"] == lane:
            latest[row["benchmark"]] = row
with open(markdown_path, "w", encoding="utf-8") as f:
    f.write(f"# {lane.upper()} SPEC CPU2017 full-system test-input results\n\n")
    f.write("| Benchmark | Verdict | Detail | Run time |\n|---|---|---|---|\n")
    for name in sorted(latest):
        row = latest[name]
        detail = row["detail"].replace("|", "/")
        f.write(f"| {name} | **{row['verdict']}** | {detail} | {row['timestamp']} |\n")
PY

  if ! grep -q 'TLBFS-GUEST-DONE' "$serial"; then
    log "guest did not reach the SPEC completion marker; see $serial"
  fi
  if (( marker_count != expected )); then
    log "incomplete SPEC results: $marker_count/$expected result markers; see $serial"
  fi
  if (( gem5_status != 0 || marker_count != expected )) || ! grep -q 'TLBFS-GUEST-DONE' "$serial"; then
    local name
    for name in simerr.txt simout.txt gem5_host.log serial.log board.pc.com_1.device; do
      if [[ -f "$out/$name" ]]; then
        tail -n 200 "$out/$name" > "$RESULT_DIR/latest_fs_${name}.tail.txt"
      fi
    done
    log "saved remote simulator tails under $RESULT_DIR/latest_fs_*.tail.txt"
    return 1
  fi
  log "full-system SPEC test inputs complete: $passed/$count PASS; table=$RESULTS_TSV"
  (( passed == count ))
}

main() {
  [[ -x "$GEM5" ]] || { log "built gem5.opt not found: $GEM5"; return 1; }
  log "preparing lane-local SPEC CPU2017 full-system run in /tmp"
  ensure_fs_assets
  ensure_spec
  ensure_spec_built
  prepare_spec_disk
  run_suite
}

main "$@"
