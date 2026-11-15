# Start the five TLB workers

Start one Claude Code session on each machine. The repository is shared; each machine has its own /tmp.

| Host | Lane | Launch prompt |
|---|---|---|
| csews20 | inc | robustness/PROMPT_INC.md |
| csewsrm22 | excl | robustness/PROMPT_EXCL.md |
| csewsrm23 | nine | robustness/PROMPT_NINE.md |
| csewsrm24 | agile | robustness/PROMPT_AGILE.md |
| csewsrm25 | perf | robustness/PROMPT_PERF.md |

Paste the corresponding launch text from the orchestrator chat into Claude Code once, or run `bash robustness/scripts/launch_lane.sh <lane>` once directly on each host. The detached tmux supervisor keeps running after Claude exits and automatically reruns after a new ADMIN RESUME message. If a host name differs, use the lane explicitly assigned by the user; do not guess from an old heartbeat. The current workflow is in ORCHESTRATION_PROTOCOL.md. The older CLAUDE_TASK_*.md and PROMPT_TEMPLATE.md describe prior campaigns and are background only.
