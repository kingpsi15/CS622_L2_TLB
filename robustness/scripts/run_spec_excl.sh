#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
cd "$ROOT"
HOSTN=$(hostname -s)
mkdir -p "$ROOT/robustness/results-excl"
export JOBS=${JOBS:-32}
export RJOBS=${RJOBS:-32}
"$SCRIPT_DIR/approach_spec_worker.sh" excl 2>&1 \
    | tee -a "$ROOT/robustness/results-excl/host-${HOSTN}-spec-worker.log"
