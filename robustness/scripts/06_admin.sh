#!/bin/bash
# Waits for all five lanes to log "LANE <v> COMPLETE", then appends their reports to TLB_IMPLEMENTATION_AUDIT.md (plain concatenation, no LLM).
source "$(dirname "$0")/env.sh"
declare -A F=( [inc]=INCLUSIVE_TLB_RESULTS_LOG.md [excl]=EXCLUSIVE_TLB_RESULTS_LOG.md [nine]=NINE_TLB_RESULTS_LOG.md [agile]=AGILE_TLB_RESULTS_LOG.md [perf]=PERFORATED_TLB_RESULTS_LOG.md )
declare -A REP=( [inc]=INCLUSIVE_TLB_ROBUSTNESS_REPORT.md [excl]=EXCLUSIVE_TLB_ROBUSTNESS_REPORT.md [nine]=NINE_TLB_ROBUSTNESS_REPORT.md [agile]=AGILE_TLB_REPORT.md [perf]=PERFORATED_TLB_REPORT.md )
while true; do
  n=0; for v in "${!F[@]}"; do grep -q "LANE $v COMPLETE" $H/docs/design_reports/${F[$v]} 2>/dev/null && n=$((n+1)); done
  [ $n -ge 5 ] && break; sleep 600
done
{ echo; echo "# Consolidated lane reports ($(date '+%F %T'))"; echo
  for v in inc excl nine agile perf; do echo; echo "---"; echo "## Lane: $v"; echo; [ -f $H/docs/design_reports/${REP[$v]} ] && cat $H/docs/design_reports/${REP[$v]} || echo "_report file missing_"; done
} >> $H/docs/design_reports/TLB_IMPLEMENTATION_AUDIT.md
log "ADMIN: all 5 lanes COMPLETE; reports merged into TLB_IMPLEMENTATION_AUDIT.md"
