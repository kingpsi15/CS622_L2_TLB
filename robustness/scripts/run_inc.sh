#!/bin/bash
# Run on ONE machine (e.g. csewsrm2X): builds + tests the 'inc' approach. Needs ~15GB free in /tmp. Detach-safe via tmux:
#   tmux new -s lane-inc 'bash ~/CS622_L2_TLB/robustness/scripts/run_inc.sh; exec bash'
exec bash "$(dirname "$0")/machine_run.sh" inc
