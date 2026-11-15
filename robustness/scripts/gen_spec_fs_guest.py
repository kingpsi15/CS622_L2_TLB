#!/usr/bin/env python3
"""Generate a guest script to run every available SPEC CPU2017 test input."""

import glob
import os
import shlex

SPEC = os.environ["SPEC"]
W = os.environ["W"]
GUEST_SPEC = SPEC
pass_cache = os.environ.get("SPEC_PASS_CACHE", "")
run_key = os.environ.get("SPEC_RUN_KEY", "")
cached_passes = set()
if pass_cache and run_key and os.path.isfile(pass_cache):
    with open(pass_cache, encoding="utf-8") as cache:
        for row in cache:
            fields = row.rstrip("\n").split("\t")
            if len(fields) == 2 and fields[0] == run_key:
                cached_passes.add(fields[1])

excluded = {"996.specrand_fs", "997.specrand_fr", "998.specrand_is", "999.specrand_ir"}
benchmarks = sorted(
    os.path.basename(path)
    for path in glob.glob(f"{SPEC}/benchspec/CPU/*")
    if os.path.isdir(path) and os.path.basename(path) not in excluded
)
available = {
    bench
    for bench in benchmarks
    if glob.glob(f"{SPEC}/benchspec/CPU/{bench}/exe/*gem5static*")
    and glob.glob(f"{SPEC}/benchspec/CPU/{bench}/run/run_base_test_gem5static*")
}

if not benchmarks:
    raise SystemExit(f"No SPEC CPU2017 benchmark directories found under {SPEC}")

guest_script = os.path.join(W, "jobs", "spec_fs_guest.sh")
benchmark_list = os.path.join(W, "jobs", "spec_fs_benchmarks.txt")
os.makedirs(os.path.dirname(guest_script), exist_ok=True)
with open(benchmark_list, "w", encoding="utf-8") as f:
    f.write("\n".join(benchmarks) + "\n")
lines = [
    "#!/bin/bash",
    'if [ "$(id -u)" != 0 ]; then sudo -n bash "$0" "$@" || { echo SPEC_SETUP_FAIL sudo > /dev/ttyS0; echo TLBFS-GUEST-DONE > /dev/ttyS0; }; exit 0; fi',
    "set +e",
    "ulimit -s unlimited",
    "exec > /dev/ttyS0 2>&1",
    f"SPEC={shlex.quote(GUEST_SPEC)}",
    'mkdir -p "$SPEC"',
    'if ! mount -t ext4 -o rw LABEL=SPEC2017 "$SPEC"; then',
    '  echo "SPEC_SETUP_FAIL mount"',
    "  echo TLBFS-GUEST-DONE",
    "  exit 0",
    "fi",
    'echo "SPEC_FS_GUEST_READY path=$SPEC"',
    'cd "$SPEC" || { echo SPEC_SETUP_FAIL cd; echo TLBFS-GUEST-DONE; exit 0; }',
    'if ! source ./shrc; then',
    '  echo "SPEC_SETUP_FAIL shrc"',
    "  echo TLBFS-GUEST-DONE",
    "  exit 0",
    "fi",
    'mkdir -p "$SPEC/fs-results"',
]

for bench in benchmarks:
    if bench in cached_passes:
        lines.append(f'echo "SPEC_RESULT {bench} PASS cached-pass"')
        continue
    if bench not in available:
        lines.append(f'echo "SPEC_RESULT {bench} FAIL missing-build-or-test-run"')
        continue
    log_path = f"$SPEC/fs-results/{bench}.log"
    config_name = "gem5-static-parest" if bench == "510.parest_r" else "gem5-static"
    lines.extend(
        [
            f"echo SPEC_START {bench}",
            f'timeout "${{SPEC_GUEST_TIMEOUT:-28800}}" "$SPEC/bin/runcpu" '
            f'--config={config_name} --nobuild --action=run --size=test --noreportable '
            f'--iterations=1 {shlex.quote(bench)} > "{log_path}" 2>&1',
            "rc=$?",
            f'if [ "$rc" -eq 0 ] && grep "^Success:" "{log_path}" | grep -Fq {shlex.quote("1x" + bench)}; then',
            f'  echo "SPEC_RESULT {bench} PASS rc=$rc"',
            "else",
            f'  echo "SPEC_RESULT {bench} FAIL rc=$rc"',
            f'  tail -n 8 "{log_path}"',
            "fi",
        ]
    )

lines.extend(["sync", "echo TLBFS-GUEST-DONE"])
with open(guest_script, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
os.chmod(guest_script, 0o755)
print(f"generated {guest_script}: {len(benchmarks)} SPEC benchmarks "
      f"({len(available)} runnable; {len(benchmarks) - len(available)} unavailable; "
      f"{len(cached_passes & set(benchmarks))} cached PASS)")
