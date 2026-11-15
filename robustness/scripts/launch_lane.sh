#!/usr/bin/env bash
# Idempotent one-time launcher for a lane's persistent supervisor.
set -euo pipefail
LANE=${1:-}
case "$LANE" in
  inc|excl|nine|agile|perf) ;;
  *) echo "usage: $0 inc|excl|nine|agile|perf" >&2; exit 2 ;;
esac
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
SESSION="tlb-supervisor-$LANE"
OWNER_FILE="$ROOT/robustness/comms/owner_$LANE.txt"
if [[ -s "$OWNER_FILE" ]]; then
  owner=$(head -n 1 "$OWNER_FILE")
  if [[ "$(hostname -s)" != "$owner" ]]; then
    echo "lane $LANE is assigned to $owner; refusing duplicate launch on $(hostname -s)" >&2
    exit 3
  fi
fi

# Keep the one-time launch across a host reboot. Preserve any existing user
# crontab and add only this lane's tagged entry. Cron may start before the NFS
# checkout is mounted, so retry until the launcher becomes available.
if [[ ${LANE_LAUNCH_FROM_CRON:-0} != 1 ]]; then
  if command -v crontab >/dev/null; then
    marker="CS622_L2_TLB-supervisor-$LANE"
    if ! (crontab -l 2>/dev/null || true) | grep -Fq "$marker"; then
      cron_line="@reboot /usr/bin/bash -c 'until test -f \"$SCRIPT_DIR/launch_lane.sh\"; do sleep 60; done; LANE_LAUNCH_FROM_CRON=1 /usr/bin/bash \"$SCRIPT_DIR/launch_lane.sh\" $LANE' >/dev/null 2>&1 # $marker"
      { crontab -l 2>/dev/null || true; printf '%s\n' "$cron_line"; } | crontab -
      echo "installed reboot start for $LANE"
    fi
  else
    echo "warning: crontab unavailable; relaunch $LANE after host reboot" >&2
  fi
fi
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "already running: $SESSION"
  exit 0
fi
tmux new-session -d -s "$SESSION" -c "$ROOT" \
  "exec bash '$SCRIPT_DIR/lane_supervisor.sh' '$LANE'"
echo "started: $SESSION on $(hostname -s)"
echo "status: tmux attach -t $SESSION"
echo "board: bash '$SCRIPT_DIR/comms.sh' board"
