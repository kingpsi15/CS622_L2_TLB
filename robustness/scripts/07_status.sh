#!/usr/bin/env bash
# Shared board status for all five lanes. Reads only shared files, so it
# gives the same answer from any host. Run: bash robustness/scripts/07_status.sh
set -u
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
COMMS="$ROOT/robustness/comms"

now=$(date +%s)

for lane in inc excl nine agile perf; do
  owner=$(head -n 1 "$COMMS/owner_$lane.txt" 2>/dev/null || echo unknown)
  hb=$(cat "$COMMS/hb_$lane.txt" 2>/dev/null || echo 'no heartbeat')
  hb_host=$(awk '{print $3}' <<< "$hb")

  # Heartbeat age
  age="?"
  if t=$(date -d "${hb:0:19}" +%s 2>/dev/null); then
    age="$(( (now - t) / 60 ))m"
  fi

  # Flags
  flag=""
  [[ "$hb" != "no heartbeat" && "$hb_host" != "$owner" ]] && flag+=" [heartbeat from $hb_host, not owner]"
  [[ "$hb" == *BLOCKED* ]] && flag+=" [BLOCKED: needs fix]"
  [[ "$age" != "?" && "${age%m}" -gt 15 ]] && flag+=" [STALE: supervisor may be down]"

  # Last ERROR line on the lane's board
  last_err=$(grep -h 'ERROR' "$COMMS/from_$lane.md" 2>/dev/null | tail -n 1)

  # Failed benchmarks (column 4 = benchmark, column 5 = verdict)
  res="$ROOT/robustness/results-$lane/spec_fs_results.tsv"
  fails=""
  passed=0
  total=0
  if [[ -s "$res" ]]; then
    fails=$(awk -F '\t' 'NR>1 && $4!="" && $5!="PASS" {print $4}' "$res" | sort -u | tr '\n' ' ')
    passed=$(awk -F '\t' 'NR>1 && $4!="" && $5=="PASS" {print $4}' "$res" | sort -u | wc -l)
    total=$(awk -F '\t' 'NR>1 && $4!="" {print $4}' "$res" | sort -u | wc -l)
  fi

  # Newest incident file
  latest_inc=$(ls -t "$ROOT"/robustness/results-"$lane"/incident-*.md 2>/dev/null | head -n 1)

  printf '%-6s owner:%-10s hb-age:%-5s%s\n' "$lane" "$owner" "$age" "$flag"
  printf '       hb:  %s\n' "${hb:0:130}"
  [[ "$total" -gt 0 ]] && printf '       spec: %s PASS of %s reported\n' "$passed" "$total"
  [[ -n "$fails" ]] && printf '       FAILED: %s\n' "$fails"
  [[ -n "$latest_inc" ]] && printf '       incident: %s\n' "${latest_inc#$ROOT/}"
  [[ -n "$last_err" ]] && printf '       err: %s\n' "${last_err:0:150}"
  echo
done