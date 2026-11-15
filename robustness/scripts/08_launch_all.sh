#!/usr/bin/env bash
# Compatibility entry point. Each lane needs its own host and private /tmp.
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LANE=${1:-}
if [[ -z "$LANE" ]]; then
  case "$(hostname -s)" in
    csews20) LANE=inc ;;
    csewsrm22) LANE=excl ;;
    csewsrm23) LANE=nine ;;
    csewsrm24) LANE=agile ;;
    csewsrm25) LANE=perf ;;
    *) echo "usage: $0 inc|excl|nine|agile|perf" >&2; exit 2 ;;
  esac
fi
exec bash "$SCRIPT_DIR/launch_lane.sh" "$LANE"
