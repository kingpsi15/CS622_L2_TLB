#!/bin/bash
# Run on ONE machine (e.g. csewsrm2X): builds + tests the 'perf' approach. Needs ~15GB free in /tmp. Detach-safe via tmux:
#   tmux new -s lane-perf 'bash ~/CS622_L2_TLB/robustness/scripts/run_perf.sh; exec bash'
exec bash "$(dirname "$0")/machine_run.sh" perf
