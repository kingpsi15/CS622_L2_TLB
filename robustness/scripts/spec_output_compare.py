#!/usr/bin/env python3
"""Compare full SPEC test outputs with SPEC references and the paired baseline."""
import json
import os
import pathlib
import subprocess
import sys

if len(sys.argv) != 4:
    raise SystemExit("usage: spec_output_compare.py JOBS.json TEST_TAG HOST")

jobs_path = pathlib.Path(sys.argv[1])
tag = sys.argv[2]
host = sys.argv[3]
jobs = json.loads(jobs_path.read_text())
spec = pathlib.Path(os.environ["SPEC"])
work = pathlib.Path(os.environ["W"])
results = pathlib.Path(os.environ["RES"])
out_root = work / "runs" / tag


def run_specdiff(options, expected, actual):
    command = [
        "bash", "-c",
        'cd "$SPEC" && source shrc && exec bin/specperl bin/harness/specdiff "$@"',
        "specdiff", *options, str(expected), str(actual),
    ]
    env = dict(os.environ, SPEC=str(spec))
    try:
        proc = subprocess.run(command, env=env, capture_output=True, text=True, timeout=300)
        return proc.returncode, (proc.stdout + proc.stderr).strip()
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or ""
        if isinstance(output, bytes):
            output = output.decode(errors="replace")
        return 124, output + "\nspecdiff timed out"


def job_record(build, job):
    out = out_root / build / job["name"]
    done = out / "done.json"
    if not done.exists():
        return out, None
    try:
        return out, json.loads(done.read_text())
    except (OSError, json.JSONDecodeError):
        return out, None


def output_path(job, out, item):
    if item["actual"] == job.get("stdout_target"):
        index = job["name"].rsplit("-", 1)[-1]
        candidate = out / f"spec_stdout_{index}.txt"
        if candidate.is_file():
            return candidate
    cwd = pathlib.Path(job["cwd"])
    candidate = cwd / item["actual"]
    if candidate.is_file() and not candidate.is_symlink():
        return candidate
    candidate = out / item["actual"]
    return candidate if candidate.is_file() else None


primary_jobs = {}
for job in jobs:
    if job["build"] == "inc":
        primary_jobs[job["name"]] = job

rows = []
for name, job in sorted(primary_jobs.items()):
    expected_outputs = job.get("expected_outputs", [])
    inc_out, inc_done = job_record("inc", job)
    base_out, base_done = job_record("base", job)
    if not expected_outputs:
        rows.append({
            "job": name, "output": "-", "status": "UNVERIFIED",
            "detail": "SPEC compare.cmd produced no mapped expected outputs",
        })
        continue
    if not inc_done or inc_done.get("verdict") != "PASS" or \
       not base_done or base_done.get("verdict") != "PASS":
        rows.append({
            "job": name, "output": "-", "status": "NOT_RUN",
            "detail": "candidate or baseline job is missing or did not pass",
        })
        continue

    for item in expected_outputs:
        expected = pathlib.Path(item["expected"])
        inc_actual = output_path(job, inc_out, item)
        base_actual = output_path(job, base_out, item)
        if not expected.is_file() or inc_actual is None or base_actual is None:
            missing = []
            if not expected.is_file():
                missing.append(f"SPEC expected output missing: {expected}")
            if inc_actual is None:
                missing.append("candidate output missing")
            if base_actual is None:
                missing.append("baseline output missing")
            rows.append({
                "job": name, "output": item["actual"], "status": "FAIL",
                "detail": "; ".join(missing),
            })
            continue

        inc_rc, inc_text = run_specdiff(item["specdiff_args"], expected, inc_actual)
        base_rc, base_text = run_specdiff(item["specdiff_args"], expected, base_actual)
        pair_rc, pair_text = run_specdiff(item["specdiff_args"], inc_actual, base_actual)
        status = "PASS" if inc_rc == base_rc == pair_rc == 0 else "FAIL"
        details = []
        if inc_rc:
            details.append(f"candidate vs SPEC: {inc_text[-500:]}")
        if base_rc:
            details.append(f"baseline vs SPEC: {base_text[-500:]}")
        if pair_rc:
            details.append(f"candidate vs baseline: {pair_text[-500:]}")
        rows.append({
            "job": name, "output": item["actual"], "status": status,
            "detail": "; ".join(details),
        })

results.mkdir(parents=True, exist_ok=True)
stem = f"spec_output_compare_{tag.removeprefix('spec_test_')}"
(results / f"{stem}.json").write_text(json.dumps(rows, indent=2))
with (results / f"{stem}.md").open("w") as report:
    report.write(f"# SPEC output comparison: {tag}\n\n")
    report.write("Each output is checked against SPEC's reference with its declared `specdiff` options, ")
    report.write("then candidate and baseline are compared with the same options.\n\n")
    report.write("| job | output | status | details |\n|---|---|---|---|\n")
    for row in rows:
        detail = row["detail"].replace("|", "/").replace("\n", " ")[:1000]
        report.write(
            f"| {row['job']} | {row['output']} | **{row['status']}** | "
            f"{detail} |\n"
        )

passes = sum(row["status"] == "PASS" for row in rows)
failures = [row for row in rows if row["status"] != "PASS"]
with (results / f"{stem}.md").open("a") as report:
    report.write(f"\nOutcome: {passes}/{len(rows)} PASS; {len(failures)} FAIL or UNVERIFIED.\n")
print(f"SPEC output comparison: {passes}/{len(rows)} PASS; report: {results / (stem + '.md')}")
if failures:
    raise SystemExit(1)
