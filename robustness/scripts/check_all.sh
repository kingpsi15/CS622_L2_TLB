#!/usr/bin/env bash
# Usage: bash robustness/scripts/check_all.sh
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
C="$ROOT/robustness/comms"
U=${TLB_USER:-$(id -un)}
HOST=$(hostname -s)
now=$(date +%s)
WORRY=()
OK=()

echo "== $(date '+%F %T') on $HOST =="

# ---------- Shared board (valid from any host) ----------
for lane in inc excl nine agile perf; do
  hb=$(tail -n 1 "$C/hb_$lane.txt" 2>/dev/null)
  [[ -z "$hb" ]] && { WORRY+=("$lane: no heartbeat file"); continue; }
  if [[ "$hb" == *BLOCKED* ]]; then
    inc=$(ls -t "$ROOT"/robustness/results-$lane/incident-*.md 2>/dev/null | head -1)
    WORRY+=("$lane: BLOCKED, needs a fix. Newest incident: ${inc#$ROOT/}")
  fi
  # incidents created in the last 90 minutes
  recent=$(find "$ROOT/robustness/results-$lane" -maxdepth 1 -name 'incident-*.md' -mmin -90 2>/dev/null | head -1)
  [[ -n "$recent" && "$hb" != *BLOCKED* ]] && WORRY+=("$lane: incident in last 90 min: ${recent#$ROOT/}")
  [[ "$hb" == *DONE* ]] && OK+=("$lane: DONE reported")
done

# ---------- Local lane (only if this host runs one) ----------
LANE=""
for lane in inc excl nine agile perf; do
  own=$(head -n 1 "$C/owner_$lane.txt" 2>/dev/null)
  hbh=$(tail -n 1 "$C/hb_$lane.txt" 2>/dev/null | awk '{print $3}')
  if [[ "$own" == "$HOST" || "$hbh" == "$HOST" ]]; then LANE=$lane; break; fi
done

if [[ -z "$LANE" ]]; then
  echo "(this host runs no lane; local gem5 checks skipped)"
else
  W=/tmp/$U/work; [[ $LANE != inc ]] && W=/tmp/$U/work-$LANE
  D=$(ls -dt "$W"/runs/spec_fs_${LANE}_* 2>/dev/null | head -1)
  echo "local lane: $LANE   run dir: ${D:-none}"

  tmux has-session -t "tlb-supervisor-$LANE" 2>/dev/null \
    || WORRY+=("$LANE: tmux session tlb-supervisor-$LANE is gone. Run 08_launch_all.sh on this host")

  pid=$(pgrep -f "gem5.opt.*spec_fs_${LANE}" | head -1)
  if [[ -n "$D" ]]; then
    con="$D/board.pc.com_1.device"
    nres=$(grep -c SPEC_RESULT "$con" 2>/dev/null); nres=${nres:-0}
    npass=$(grep SPEC_RESULT "$con" 2>/dev/null | grep -c PASS)
    pan=$(grep -ih "panic" "$D/simerr.txt" 2>/dev/null | tail -1)
    age=999999
    [[ -f "$con" ]] && age=$(( (now - $(stat -c %Y "$con")) / 60 ))

    echo "gem5 pid: ${pid:-none} | console age: ${age}m | SPEC_RESULT: $nres ($npass PASS)"
    tail -n 1 "$con" 2>/dev/null | cut -c1-100

    if [[ -n "$pan" ]]; then
      WORRY+=("$LANE: PANIC: ${pan:0:200}")
    elif [[ -z "$pid" ]]; then
      WORRY+=("$LANE: gem5 not running (finished or died). Check the heartbeat and incident")
    elif (( age >= 30 )); then
      WORRY+=("$LANE: console silent ${age}m while gem5 is alive. Likely hung; wait once more, then pkill -f 'gem5.opt.*spec_fs_${LANE}'")
    else
      OK+=("$LANE: gem5 alive, console active ${age}m ago")
    fi
    (( nres > 0 )) && OK+=("$LANE: $nres benchmark results so far")
  else
    WORRY+=("$LANE: no run directory yet in $W/runs (build may still be in progress)")
  fi
fi

# ---------- Verdict ----------
echo
if ((${#WORRY[@]})); then
  echo "!! WORRY (${#WORRY[@]}):"; printf '   - %s\n' "${WORRY[@]}"
else
  echo "NO WORRIES: nothing needs action."
fi
((${#OK[@]})) && { echo "OK:"; printf '   - %s\n' "${OK[@]}"; }
echo
echo "Ignore: stale heartbeats, old FAILED lists, 0 results in the first hours of boot."




