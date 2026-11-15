# Five-lane SPEC coordination protocol

The user starts one lane supervisor on each host, directly or through one
Claude Code session per host. This Codex chat is the orchestrator. The five
lane names are `inc`, `excl`, `nine`, `agile`, and `perf`.
Each host has its own `/tmp`; the repository and `robustness/comms/` are shared.

## Ownership

- Worker supervisor: build and run its assigned fixed TLB and SPEC tests in its own `/tmp`.
  It saves small verdict tables and error evidence in `robustness/results-<lane>/`.
- Lane Codex: wait on `watch_lane_event.sh <lane> --current` and then `--next`.
  When an ERROR arrives, inspect shared incident evidence, diagnose it, and fix
  lane-specific TLB source if the evidence supports a change. The Codex task's
  host may differ from the lane supervisor's host; never assume its `/tmp` is
  the lane's `/tmp`. Do not edit
  another lane or shared scripts. Record the fix and evidence, then send
  `comms.sh resume <lane> "<fix summary>"` to trigger the supervisor's rerun.
- Orchestrator: read incidents, diagnose and fix persistent code/scripts, then
  send a resume instruction for shared fixes. The supervisor automatically
  reruns after a new instruction from either the orchestrator or lane Codex.
  No second worker launch or prompt is needed.
- Preserve all existing result reports and logs. Do not claim a benchmark passed
  merely because gem5 exited zero; inspect guest `SPEC_RESULT` verdicts and
  benchmark output. Compare with stock where the harness supports it.
- The current full-system runner produces guest PASS/FAIL markers. It does not
  by itself prove byte-for-byte equality with stock. Report output equality only
  when a separate comparison was actually run.

## Worker start and run

1. Record `hostname -s` and the lane named in your launch prompt. The user may
   assign a different host than the historical map in `START_HERE.md`; the
   explicitly assigned lane wins. Never infer a lane from a stale heartbeat.
2. Run **once**: `bash robustness/scripts/launch_lane.sh <lane>`. It starts
   `lane_supervisor.sh` in a detached tmux session named `tlb-supervisor-<lane>`.
   The launcher is idempotent and installs a tagged `@reboot` crontab entry
   when cron is available. The Codex session then waits for its lane's events
   with `watch_lane_event.sh`.
3. The supervisor runs `five_lane_clean_build.sh <lane>`. This copies the
   repository gem5 tree into this host's `/tmp`, installs the fixed TLB files,
   builds and smoke-tests it, restores missing SPEC/kernel/disk assets under
   `/tmp`, and runs full-system SPEC test inputs. After a reboot, cron restarts
   the supervisor and it rebuilds all missing `/tmp` assets. If cron is absent,
   the launcher prints a warning and must be rerun after reboot.
4. Results appear in `robustness/results-<lane>/clean_build.log`,
   `clean_build_scons.log`, `spec_fs.log`, `spec_fs_results.tsv`, and
   `spec_fs_results.md`. Report the actual count of PASS/FAIL/missing verdicts.
   Keep long simulator logs in `/tmp`; put only a short relevant excerpt in the
   shared incident file.

## Error handoff

On **any** nonzero stage, failed SPEC verdict, or missing verdict, the
supervisor automatically:

1. Stops this lane's pipeline and writes
   `robustness/results-<lane>/incident-<timestamp>.md` with the command, exit
   code, verdict count, and relevant log paths and excerpts.
2. Sends `ERROR <incident-path>` through `comms.sh say` and sets a `BLOCKED`
   heartbeat.
3. Polls `robustness/comms/to_<lane>.md` for a **new** `ADMIN RESUME` message.
   Old messages cannot trigger a retry.
4. After `RESUME`, reruns the full clean build and SPEC test sequence. It writes
   a new incident if the retry still fails. No user relaunch is needed.

If a worker notices an output mismatch or suspected false PASS that the runner
did not detect, it writes an incident and alerts the orchestrator. The current
full-system runner does not automatically compare outputs with stock.

The board commands are `comms.sh read <lane>`, `comms.sh say <lane> "message"`,
and `comms.sh hb <lane> "state"`. The orchestrator writes with
`comms.sh tell <lane> "RESUME ..."`; a lane Codex writes with
`comms.sh resume <lane> "<fix summary>"` after its own verified fix. The
supervisor polls the board while blocked. Its tmux session survives a Codex
exit or terminal logout; the Codex wait itself lasts only as long as its task
session remains active.

## Completion

The supervisor sends `DONE` only after build/smoke test succeeded, the SPEC
result table gained new rows, and all latest recorded benchmark verdicts are
PASS. `DONE` means full-system guest verdicts passed; output equality with
stock remains unverified unless separately tested. The orchestrator decides
whether stock-level failures are accepted or need a harness fix. Do not delete
old evidence.
