#!/bin/bash
# Build SPEC CPU2017 statically (gcc-11) and create run directories (test + ref inputs).
SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
source "$SCRIPT_DIR/env.sh"
cp -n "$R/scripts/spec-gem5-static.cfg" "$SPEC/config/gem5-static.cfg"
# Only the manually repaired parest binary needs relaxed checksum matching.
# Keep verification enabled for every other benchmark in gem5-static.cfg.
awk '/^reportable[[:space:]]*=[[:space:]]*0/ {
    print; print "verify_binaries = 0"; print "strict_rundir_verify = 0"; next
} { print }' "$SPEC/config/gem5-static.cfg" > "$SPEC/config/gem5-static-parest.cfg"
spec_build() {
    local parest="$SPEC/benchspec/CPU/510.parest_r"
    local build_dir="$parest/build/build_base_gem5static-m64.0000"
    /usr/bin/python3 "$SCRIPT_DIR/patch_parest_gcc11.py" "$SPEC" restore-source || return 1
    # A prior attempt made with edited installed source can leave an incomplete
    # generated build directory. Recreate only parest's temporary build copy.
    if [[ ! -f "$build_dir/source/fe/fe_abf.cc" && -d "$build_dir" ]]; then
        echo "discarding incomplete generated parest build directory: $build_dir"
        rm -rf -- "$build_dir"
    fi
    cd "$SPEC" && source shrc
    runcpu --config=gem5-static --define build_ncpus="${SPEC_BUILD_JOBS:-12}" --action=build --ignore_errors \
        intrate fprate intspeed fpspeed
    if ! compgen -G "$SPEC/benchspec/CPU/510.parest_r/exe/*gem5static*" >/dev/null; then
        echo "repairing only 510.parest_r generated build copy for GCC 11"
        /usr/bin/python3 "$SCRIPT_DIR/patch_parest_gcc11.py" "$SPEC" patch-build || return 1
        if ! (cd "$build_dir" && specmake --output-sync --jobs="${SPEC_BUILD_JOBS:-4}" build) \
            > "$R/results-$VARIANT/parest_manual_build.log" 2>&1; then
            tail -n 180 "$R/results-$VARIANT/parest_manual_build.log" >&2
            return 1
        fi
        [[ -x "$build_dir/parest_r" ]] || return 1
        mkdir -p "$parest/exe"
        cp -a "$build_dir/parest_r" "$parest/exe/parest_r_base.gem5static-m64"
    fi
    compgen -G "$SPEC/benchspec/CPU/510.parest_r/exe/*gem5static*" >/dev/null || {
        echo "510.parest_r still has no static executable; inspect its make.out" >&2
        mkdir -p "$R/results-$VARIANT"
        find "$SPEC/benchspec/CPU/510.parest_r/build" -name make.out -type f \
            -exec tail -n 180 {} \; > "$R/results-$VARIANT/parest_build_latest.tail.txt" 2>/dev/null || true
        find "$SPEC/benchspec/CPU/510.parest_r/build" -name make.out -type f \
            -exec grep -n -C 5 -E 'error:|fatal error:|Error|undefined reference|Killed' {} \; \
            > "$R/results-$VARIANT/parest_build_errors.txt" 2>/dev/null || true
        return 1
    }
    ls benchspec/CPU/*/exe/ | grep -c gem5static
}
spec_setup() {
    cd $SPEC && source shrc
    for sz in test ref; do
        runcpu --config=gem5-static --nobuild --action=runsetup --size=$sz --ignore_errors --noreportable \
            intrate fprate intspeed fpspeed
    done
    runcpu --config=gem5-static-parest --nobuild --action=runsetup --size=test --noreportable \
        510.parest_r || return 1
    ls -d benchspec/CPU/*/run/run_base_*gem5static* | head -100
}
stage spec_build spec_build || exit 1
stage spec_setup spec_setup || exit 1
log "SPEC exes built: $(ls $SPEC/benchspec/CPU/*/exe/ 2>/dev/null | grep -c gem5static) ; build errors: $(grep -l 'Error\|error:' $SPEC/benchspec/CPU/*/build/build_base_gem5static*/make.out 2>/dev/null | wc -l) make.out files with errors"
