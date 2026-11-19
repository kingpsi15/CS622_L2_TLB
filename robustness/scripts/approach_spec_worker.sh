#!/usr/bin/env bash
set -euo pipefail

LANE=${1:-}
if [ -z "$LANE" ]; then
    echo "usage: approach_spec_worker.sh inc|excl|nine|agile|perf" >&2
    exit 2
fi
case "$LANE" in
    inc|excl|nine|agile|perf) ;;
    *) echo "unknown lane: $LANE" >&2; exit 2 ;;
esac
if [ "${2:-}" = "--check" ]; then
    echo "lane argument accepted: $LANE"
    exit 0
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
R=$(cd "$SCRIPT_DIR/.." && pwd)
export VARIANT=$LANE
source "$SCRIPT_DIR/env.sh"
export HOSTN=$(hostname -s)
export SHARED=$W
export BASE=$W/gem5-base
export INC=$W/gem5-$LANE

CORES=${JOBS:-32}
SPEC_JOBS=${RJOBS:-$CORES}
SRC=$H/gem5/src/arch/x86
SC=/tmp/${TLB_USER:-$(id -un)}/sc

log "[$HOSTN] fixed SPEC worker $LANE: START cores=$CORES spec_jobs=$SPEC_JOBS"

if [ ! -x "$SPEC/bin/runcpu" ]; then
    log "[$HOSTN] SPEC missing at $SPEC; downloading/installing from Drive"
    bash "$SCRIPT_DIR/03_get_spec.sh"
else
    log "[$HOSTN] SPEC available at $SPEC"
fi
if [ ! -x "$SPEC/bin/runcpu" ]; then
    echo "SPEC installation missing runcpu at $SPEC/bin/runcpu" >&2
    exit 1
fi

BUILD_ONLY=1 JOBS=$CORES bash "$SCRIPT_DIR/run_${LANE}.sh"

if [ "$LANE" = excl ]; then
    JOBS=$CORES bash "$SCRIPT_DIR/excl_fixed_build.sh" after
    cp "$INC/build/X86/gem5.opt.after" "$INC/build/X86/gem5.opt"
else
    case "$LANE" in
        inc)
            FIXED_CC=$SRC/tlb.cc.inc.fixed
            FIXED_HH=$SRC/tlb.hh.inc.fixed
            CHECKER=$R/patches/apply_checker.py
            CHECKER_MODE=inc
            ;;
        nine)
            FIXED_CC=$SRC/tlb.cc.nine.fixed
            FIXED_HH=$SRC/tlb.hh.nine.fixed
            CHECKER=$R/patches/apply_checker_nine.py
            CHECKER_MODE=fixed
            ;;
        agile|perf)
            FIXED_CC=$SRC/tlb.cc.$LANE.fixed
            FIXED_HH=$SRC/tlb.hh.$LANE.fixed
            CHECKER=$R/patches/apply_checker.py
            CHECKER_MODE=base
            ;;
    esac

    cp "$FIXED_CC" "$INC/src/arch/x86/tlb.cc"
    cp "$FIXED_HH" "$INC/src/arch/x86/tlb.hh"
    /usr/bin/python3 "$CHECKER" "$INC" "$CHECKER_MODE"

    if ! (cd "$INC" && PYTHONPATH=$SC /usr/bin/python3 -m SCons \
        build/X86/gem5.opt -j "$CORES" --linker=gold --ignore-style) \
        > "$W/logs/fixed_spec_scons.log" 2>&1; then
        tail -80 "$W/logs/fixed_spec_scons.log" >&2
        exit 1
    fi
    JOBS=$CORES bash "$SCRIPT_DIR/manual_link.sh"
fi

rm -f "$W/stamps/spec_build" "$W/stamps/spec_setup"
SPEC_BUILD_JOBS=$CORES JOBS=$CORES bash "$SCRIPT_DIR/01_spec_build.sh"

if ! compgen -G "$SPEC/benchspec/CPU/*/exe/*gem5static*" >/dev/null; then
    echo "No gem5static SPEC executables found under $SPEC/benchspec/CPU" >&2
    exit 1
fi

/usr/bin/python3 "$SCRIPT_DIR/gen_spec_jobs.py"
/usr/bin/python3 -c '
import json, sys
for filename in sys.argv[1:]:
    jobs = json.load(open(filename))
    if not jobs:
        raise SystemExit(f"no SPEC jobs generated: {filename}")
    print(f"{filename}: {len(jobs)} jobs")
' "$W/jobs/spec_test.json" "$W/jobs/spec_ref.json"

TEST_TAG="spec_test_${LANE}_${HOSTN}"
REF_TAG="spec_ref_${LANE}_${HOSTN}"
RESULT_FAILED=0
/usr/bin/python3 "$SCRIPT_DIR/runner.py" "$W/jobs/spec_test.json" \
    --jobs "$SPEC_JOBS" --tag "$TEST_TAG"
if ! /usr/bin/python3 "$SCRIPT_DIR/spec_output_compare.py" \
    "$W/jobs/spec_test.json" "$TEST_TAG" "$HOSTN"; then
    RESULT_FAILED=1
fi
/usr/bin/python3 "$SCRIPT_DIR/runner.py" "$W/jobs/spec_ref.json" \
    --jobs "$SPEC_JOBS" --tag "$REF_TAG"

for TAG in "$TEST_TAG" "$REF_TAG"; do
    if ! /usr/bin/python3 -c '
import json, sys
rows = json.load(open(sys.argv[1]))
failed = [r for r in rows if r.get("verdict") != "PASS"]
print(f"{sys.argv[1]}: {len(rows) - len(failed)}/{len(rows)} PASS")
if failed:
    print("Non-passing jobs:", ", ".join(
        str(r.get("build")) + "/" + str(r.get("name")) for r in failed))
    raise SystemExit(1)
' "$RES/$TAG.json"; then
        RESULT_FAILED=1
    fi
done

if [ "$RESULT_FAILED" -eq 0 ]; then
    log "[$HOSTN] fixed SPEC worker $LANE: COMPLETE; review $RES/$TEST_TAG.md and $RES/$REF_TAG.md"
else
    log "[$HOSTN] fixed SPEC worker $LANE: FINISHED WITH NON-PASSING JOBS; review $RES/$TEST_TAG.md and $RES/$REF_TAG.md"
    exit 1
fi
