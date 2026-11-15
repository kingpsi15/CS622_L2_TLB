#!/usr/bin/env bash
# Persistent, one-lane build/SPEC runner. One launch per host; reruns after a
# fresh ADMIN RESUME message without needing another Claude prompt.
set -uo pipefail

LANE=${1:-}
case "$LANE" in
  inc|excl|nine|agile|perf) ;;
  *) echo "usage: $0 inc|excl|nine|agile|perf" >&2; exit 2 ;;
esac

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
COMMS="$SCRIPT_DIR/comms.sh"
TO="$ROOT/robustness/comms/to_$LANE.md"
RESULTS="$ROOT/robustness/results-$LANE"
SCRATCH="${LANE_SUPERVISOR_SCRATCH:-/tmp/${USER:-sahilag24}/tlb-supervisor-$LANE}"
POLL_SECONDS=${LANE_SUPERVISOR_POLL_SECONDS:-60}
[[ "$POLL_SECONDS" =~ ^[1-9][0-9]*$ ]] || { echo "invalid poll interval" >&2; exit 2; }
case "$LANE" in
  inc) WORK="/tmp/${USER:-sahilag24}/work" ;;
  *) WORK="/tmp/${USER:-sahilag24}/work-$LANE" ;;
esac
mkdir -p "$RESULTS" "$SCRATCH"

# Prevent two supervisors on the same host from building the same lane tree.
exec 9>"$SCRATCH/lock"
if ! flock -n 9; then
  echo "A $LANE supervisor is already running on $(hostname -s)" >&2
  exit 1
fi

message() { bash "$COMMS" say "$LANE" "$1"; }
heartbeat() { bash "$COMMS" hb "$LANE" "$1"; }
stamp() { date '+%Y%m%d-%H%M%S'; }
run_pid=
hb_pid=
cleanup_children() {
  [[ -n "$hb_pid" ]] && kill "$hb_pid" 2>/dev/null || true
  [[ -n "$run_pid" ]] && kill "$run_pid" 2>/dev/null || true
}
trap cleanup_children EXIT
trap 'cleanup_children; exit 143' HUP INT TERM

count_verdicts() {
  local table="$RESULTS/spec_fs_results.tsv"
  [[ -s "$table" ]] || return 1
  awk -F '\t' -v first="$1" 'NR > first && NR > 1 && $4 != "" { verdict[$4]=$5 }
    END {
      for (bench in verdict) {
        if (verdict[bench] == "PASS") pass++;
        else if (verdict[bench] == "FAIL") fail++;
        else missing++;
      }
      if (pass+fail+missing == 0) exit 1;
      printf "PASS=%d FAIL=%d OTHER=%d", pass, fail, missing;
    }' "$table"
}

wait_for_older_build() {
  # A lane may already have been started manually before this supervisor was
  # installed. Wait on this host instead of racing its gem5 build tree.
  while pgrep -f -u "$(id -u)" "five_lane_clean_build[.]sh $LANE( |$)" >/dev/null; do
    heartbeat "WAITING for existing manual $LANE build on $(hostname -s)"
    sleep "$POLL_SECONDS"
  done
}

wait_for_resume() {
  local after_lines=$1 now=0 new_lines
  while true; do
    now=$(wc -l < "$TO" 2>/dev/null || echo 0)
    if (( now > after_lines )); then
      new_lines=$(sed -n "$((after_lines + 1)),${now}p" "$TO")
      if grep -Eq '^\[ADMIN [^]]+\] RESUME( |$)|^\[RESUME [^]]+\]' <<< "$new_lines"; then
        message "RESUMING after new fix instruction; board=$TO"
        return 0
      fi
    fi
    heartbeat "BLOCKED; waiting for a new ADMIN RESUME after incident"
    sleep "$POLL_SECONDS"
  done
}

attempt=0
message "SUPERVISOR START host=$(hostname -s); command=five_lane_clean_build.sh $LANE"
while true; do
  attempt=$((attempt + 1))
  run_id="$(stamp)-$attempt"
  attempt_start_epoch=$(date +%s)
  run_log="$SCRATCH/attempt-$run_id.log"
  before_rows=$(wc -l < "$RESULTS/spec_fs_results.tsv" 2>/dev/null || echo 0)
  heartbeat "RUNNING attempt=$attempt log=$run_log"
  message "RUNNING attempt=$attempt host=$(hostname -s) log=$run_log"

  # The runner restores a wiped /tmp and missing SPEC/full-system assets.
  wait_for_older_build
  bash "$SCRIPT_DIR/five_lane_clean_build.sh" "$LANE" > "$run_log" 2>&1 &
  run_pid=$!
  (
    while kill -0 "$run_pid" 2>/dev/null; do
      heartbeat "RUNNING attempt=$attempt pid=$run_pid log=$run_log"
      sleep 60
    done
  ) &
  hb_pid=$!
  wait "$run_pid"
  rc=$?
  kill "$hb_pid" 2>/dev/null || true
  wait "$hb_pid" 2>/dev/null || true
  run_pid=
  hb_pid=
  after_rows=$(wc -l < "$RESULTS/spec_fs_results.tsv" 2>/dev/null || echo 0)
  verdicts=$(count_verdicts "$before_rows" 2>/dev/null || true)
  if (( rc == 0 && after_rows > before_rows )) && \
     [[ -s "$RESULTS/spec_fs_results.md" ]] && \
     [[ "$verdicts" == *"FAIL=0"* && "$verdicts" == *"OTHER=0"* ]]; then
    heartbeat "DONE $verdicts"
    message "DONE attempt=$attempt $verdicts table=$RESULTS/spec_fs_results.md log=$run_log"
    exit 0
  fi

  incident="$RESULTS/incident-$run_id.md"
  evidence="$RESULTS/incident-$run_id-evidence"
  mkdir -p "$evidence"
  for source in "$RESULTS/clean_build_scons.log" "$RESULTS/spec_fs.log" \
      "$WORK/cpu2017/benchspec/CPU/510.parest_r/build/build_base_gem5static-m64.0000/make.out"; do
    if [[ -f "$source" ]]; then
      tail -n 120 "$source" > "$evidence/$(basename "$source").tail.txt"
    fi
  done
  latest_fs_run=$(find "$WORK/runs" -maxdepth 1 -type d \
    -name "spec_fs_${LANE}_*" 2>/dev/null | sort | tail -n 1)
  if [[ -n "$latest_fs_run" ]] && \
     (( $(stat -c %Y "$latest_fs_run") >= attempt_start_epoch )); then
    for name in simerr.txt simout.txt gem5_host.log serial.log board.pc.com_1.device; do
      [[ -f "$latest_fs_run/$name" ]] || continue
      tail -n 160 "$latest_fs_run/$name" > "$evidence/$name.tail.txt"
    done
  fi
  {
    printf '# Automated incident: %s\n\n' "$LANE"
    printf -- '- Host: `%s`\n- Time: `%s`\n- Attempt: `%s`\n' \
      "$(hostname -s)" "$(date '+%F %T %Z')" "$attempt"
    printf -- '- Command: `bash %s/five_lane_clean_build.sh %s`\n' "$SCRIPT_DIR" "$LANE"
    printf -- '- Exit code: `%s`\n- Latest verdicts: `%s`\n- Result rows before/after: `%s` / `%s`\n' \
      "$rc" "${verdicts:-unavailable}" "$before_rows" "$after_rows"
    printf -- '- Full attempt log: `%s`\n' "$run_log"
    printf -- '- Shared evidence excerpts: `%s/`\n' "$evidence"
    printf -- '- Build logs: `%s/clean_build.log`, `%s/clean_build_scons.log`\n' "$RESULTS" "$RESULTS"
    printf -- '- SPEC logs/table: `%s/spec_fs.log`, `%s/spec_fs_results.tsv`, `%s/spec_fs_results.md`\n' "$RESULTS" "$RESULTS" "$RESULTS"
    printf '\n## Relevant tail\n\n```text\n'
    tail -n 80 "$run_log"
    printf '```\n\nStock comparison and output equality are unverified unless separately recorded above.\n'
  } > "$incident"
  board_lines=$(wc -l < "$TO" 2>/dev/null || echo 0)
  message "ERROR $incident: attempt=$attempt exit=$rc ${verdicts:-no-verdicts}; awaiting orchestrator fix"
  heartbeat "BLOCKED incident=$incident"

  # Capture the board position before publishing the incident so an immediate
  # admin reply cannot be missed. Older RESUME messages cannot restart it.
  wait_for_resume "$board_lines"
done
