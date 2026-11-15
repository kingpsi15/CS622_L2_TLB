#!/usr/bin/env bash
# Block a lane Codex tool call until a new ERROR or DONE appears on the board.
# Use --current once to surface an unresolved existing ERROR; then --next.
set -euo pipefail
LANE=${1:-}
MODE=${2:---next}
case "$LANE" in
  inc|excl|nine|agile|perf) ;;
  *) echo "usage: $0 inc|excl|nine|agile|perf [--current|--next]" >&2; exit 2 ;;
esac
case "$MODE" in --current|--next) ;; *) echo "bad mode: $MODE" >&2; exit 2 ;; esac
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
FROM="$ROOT/robustness/comms/from_$LANE.md"
HB="$ROOT/robustness/comms/hb_$LANE.txt"
mkdir -p "$(dirname "$FROM")"
touch "$FROM"

if [[ "$MODE" == --current ]]; then
  if grep -q 'BLOCKED' "$HB" 2>/dev/null; then
    last_error=$(grep 'ERROR .*incident-' "$FROM" | tail -n 1 || true)
    if [[ -n "$last_error" ]]; then
      echo "$last_error"
      exit 0
    fi
  elif grep -q 'DONE' "$HB" 2>/dev/null; then
    last_done=$(grep 'DONE attempt=' "$FROM" | tail -n 1 || true)
    if [[ -n "$last_done" ]]; then
      echo "$last_done"
      exit 0
    fi
  fi
fi

cursor=$(wc -l < "$FROM")
while true; do
  count=$(wc -l < "$FROM")
  if (( count > cursor )); then
    event=$(sed -n "$((cursor + 1)),${count}p" "$FROM" |
      grep -m1 -E '(^|\] )(ERROR |DONE )' || true)
    if [[ -n "$event" ]]; then
      echo "$event"
      exit 0
    fi
    cursor=$count
  fi
  sleep "${LANE_WATCH_POLL_SECONDS:-30}"
done
