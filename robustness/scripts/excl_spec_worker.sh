#!/bin/bash
# Build local EXCL/stock binaries and run one SPEC benchmark shard.
# usage: excl_spec_worker.sh <benchmark> [--ref]
set -euo pipefail

BENCH=${1:?usage: $0 <benchmark> [--ref]}
RUN_REF=${2:-}
case "$BENCH" in
  500.perlbench_r|505.mcf_r|531.deepsjeng_r|541.leela_r|557.xz_r) ;;
  *) echo "unsupported benchmark: $BENCH" >&2; exit 2 ;;
esac
if [ -n "$RUN_REF" ] && [ "$RUN_REF" != "--ref" ]; then
  echo "usage: $0 <benchmark> [--ref]" >&2
  exit 2
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
R=$(cd "$SCRIPT_DIR/.." && pwd)
export VARIANT=excl
source "$SCRIPT_DIR/env.sh"
export SHARED=$W
export BASE=$W/gem5-base
export INC=$W/gem5-excl

# These are host-local builds; BUILD_ONLY avoids duplicating the full
# microbenchmark matrix while still producing the stock baseline and tests.
if [ ! -x "$INC/build/X86/gem5.opt" ] || [ ! -x "$BASE/build/X86/gem5.opt" ]; then
  BUILD_ONLY=1 JOBS=${JOBS:-8} bash "$SCRIPT_DIR/run_excl.sh"
fi

if [ ! -x "$SPEC/bin/runcpu" ]; then
  bash "$SCRIPT_DIR/03_get_spec.sh"
fi
if ! compgen -G "$SPEC/benchspec/CPU/$BENCH/exe/*gem5static*" >/dev/null; then
  bash "$SCRIPT_DIR/01_spec_build.sh"
fi

JOBS=${JOBS:-8} bash "$SCRIPT_DIR/excl_fixed_build.sh" after
cp "$INC/build/X86/gem5.opt.after" "$INC/build/X86/gem5.opt"

export BASE INC
python3 "$SCRIPT_DIR/gen_spec_jobs.py"

TAG="excl_spec_$(hostname -s)_${BENCH}"
python3 - "$W/jobs/spec_test.json" "$W/jobs/${TAG}_test.json" "$BENCH" <<'PY'
import json, sys
src, dst, bench = sys.argv[1:]
jobs = json.load(open(src))
prefix = f"spec-test-{bench}-"
selected = [j for j in jobs if j["name"].startswith(prefix)]
if not selected:
    raise SystemExit(f"no test jobs generated for {bench}")
json.dump(selected, open(dst, "w"), indent=1)
print(f"{bench}: selected {len(selected)} test jobs")
PY

python3 "$SCRIPT_DIR/runner.py" "$W/jobs/${TAG}_test.json" \
  --jobs "${RJOBS:-2}" --tag "${TAG}_test"

if [ "$RUN_REF" = "--ref" ]; then
  python3 - "$W/jobs/spec_ref.json" "$W/jobs/${TAG}_ref.json" "$BENCH" <<'PY'
import json, sys
src, dst, bench = sys.argv[1:]
jobs = json.load(open(src))
prefix = f"spec-ref-1c-{bench}"
selected = [j for j in jobs if j["name"] == prefix]
if len(selected) != 2:
    raise SystemExit(f"expected fixed/stock ref jobs for {bench}, found {len(selected)}")
json.dump(selected, open(dst, "w"), indent=1)
print(f"{bench}: selected {len(selected)} reference jobs")
PY
  python3 "$SCRIPT_DIR/runner.py" "$W/jobs/${TAG}_ref.json" \
    --jobs "${RJOBS:-2}" --tag "${TAG}_ref"
fi
