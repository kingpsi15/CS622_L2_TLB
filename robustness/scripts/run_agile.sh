#!/bin/bash
# Run on ONE machine (e.g. csewsrm2X): builds + tests the 'agile' approach. Needs ~15GB free in /tmp. Detach-safe via tmux:
#   tmux new -s lane-agile 'bash ~/CS622_L2_TLB/robustness/scripts/run_agile.sh; exec bash'
exec bash "$(dirname "$0")/machine_run.sh" agile
