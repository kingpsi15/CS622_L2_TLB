#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

for lane in inc excl nine agile perf; do
    case "$lane" in
        inc)  result_dir=$ROOT/robustness/results ;;
        excl) result_dir=$ROOT/robustness/results-excl ;;
        nine) result_dir=$ROOT/robustness/results-nine ;;
        agile) result_dir=$ROOT/robustness/results-agile ;;
        perf) result_dir=$ROOT/robustness/results-perf ;;
    esac

    printf '\n=== %s ===\n' "$lane"
    found=0
    for logfile in "$result_dir"/host-*-spec-worker.log; do
        [ -f "$logfile" ] || continue
        found=1
        printf '%s\n' "$(basename "$logfile")"
        tail -n 3 "$logfile"
    done
    if [ "$found" -eq 0 ]; then
        echo "no host log yet"
    fi

    for table in "$result_dir"/spec_{test,ref}_${lane}_*.md \
                 "$result_dir"/spec_output_compare_${lane}_*.md; do
        [ -f "$table" ] || continue
        printf 'result: %s\n' "$(basename "$table")"
        grep -E '^Generated |^Outcome:|runner .*DONE|Non-passing' "$table" | tail -n 3 || true
    done
done
