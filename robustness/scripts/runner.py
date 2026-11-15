#!/usr/bin/python3
"""Parallel gem5 job runner for the inclusive-TLB robustness campaign.

usage: runner.py JOBS.json [--jobs N] [--tag NAME]

JOBS.json is a list of {"name", "build": "inc"|"base", "args": [gem5 args...],
"env": {...}, "timeout": seconds, "expect": {"results": n}}.
Each job runs   <tree>/build/X86/gem5.opt -re -d <W>/runs/<tag>/<build>/<name> <args>
Skips jobs that already have a 'done.json' (resumable after logout/crash).

Verdict per job:
  PASS  gem5 exit 0, no panic/fatal/assert, every RESULT line PASS/SKIP,
        expected RESULT count reached (if given), chk* violation stats == 0
  FAIL  anything else (reason recorded)
Writes <R>/results/<tag>.md (+ .json) in the HOME directory and appends a
summary line to the persistent results log.
"""
import concurrent.futures as cf, json, os, re, subprocess, sys, time, pathlib, glob

W = os.environ["W"]; R = os.environ["R"]
TREES = {"inc": os.environ["INC"], "base": os.environ["BASE"]}
CHK = ("chkOracleMismatch", "chkOracleWalkFault", "chkInclusionViolations")


def log(msg):
    with open(os.environ["LOG"], "a") as f:
        f.write(f"- {time.strftime('%F %T')} — {msg}\n")
    print(msg, flush=True)


def parse_stats(outdir):
    """Sum chk* and miss counters over every TLB, over every stats dump."""
    tot = {}
    for st in glob.glob(f"{outdir}/stats.txt"):
        for line in open(st, errors="replace"):
            m = re.match(r"(\S+\.(?:dtb|itb|tlb)\.(\w+))\s+([\d.e+-]+)", line)
            if m and (m.group(2).startswith(("chk","coarse","secondary","l2Bitmap","est")) or m.group(2).endswith("Misses")
                      or m.group(2).endswith("Accesses")):
                k = m.group(2)
                try:
                    tot[k] = tot.get(k, 0) + float(m.group(3))
                except ValueError:
                    pass
    return tot


def run(job, tag):
    out = pathlib.Path(W) / "runs" / tag / job["build"] / job["name"]
    done = out / "done.json"
    if done.exists():
        try:
            previous = json.loads(done.read_text())
        except json.JSONDecodeError:
            print(f"[{time.strftime('%T')}] retrying {job['build']}/{job['name']}: invalid done.json",
                  flush=True)
            done.unlink()
        else:
            if previous.get("verdict") == "PASS":
                return previous
            print(f"[{time.strftime('%T')}] retrying {job['build']}/{job['name']}: "
                  f"previous verdict {previous.get('verdict', 'unknown')}", flush=True)
            done.unlink()
    out.mkdir(parents=True, exist_ok=True)
    for f in out.glob("*"):
        if f.is_file():
            f.unlink()
    for src in ([job["prep_copy"]] if job.get("prep_copy") else []) + job.get("prep_multi", []):
        subprocess.run(["cp", "-alf", src + "/.", str(out)], check=False)   # hardlink SPEC inputs
    if job.get("spec_rundir") and not os.path.isdir(job["cwd"]):
        # private working dir per job: symlink copy of the SPEC run dir
        os.makedirs(os.path.dirname(job["cwd"]), exist_ok=True)
        subprocess.run(["cp", "-as", job["spec_rundir"], job["cwd"]], check=True)
    gem5 = f"{TREES[job['build']]}/build/X86/gem5.opt"
    cmd = [gem5, "-re", "-d", str(out)] + job["args"]
    env = dict(os.environ, **job.get("env", {}))
    t0 = time.time()
    (out / "cmd.txt").write_text(" ".join(cmd) + "\nENV " + json.dumps(job.get("env", {})) + "\n")
    try:
        p = subprocess.run(cmd, env=env, cwd=job.get("cwd", str(out)),
                           timeout=job.get("timeout", 4 * 3600),
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        rc = p.returncode
    except subprocess.TimeoutExpired:
        rc = "TIMEOUT"
    dt = time.time() - t0
    text = ""
    for fn in ("simout.txt", "simerr.txt", "board.pc.com_1.device", "system.pc.com_1.device"):
        if (out / fn).exists():
            text += (out / fn).read_text(errors="replace")
    results = re.findall(r"RESULT (\S+) (PASS|FAIL|SKIP) ?(.*)", text)
    stats = parse_stats(out)
    reasons = []
    if rc != 0:
        reasons.append(f"gem5 rc={rc}")
    for pat in (r"panic:.*", r"fatal:.*", r"Assertion .* failed.*", r"Segmentation fault.*",
                r"TLBCHK [A-Z-]+ in .*"):
        for m in re.findall(pat, text)[:3]:
            reasons.append(m[:300])
    for r in results:
        if r[1] == "FAIL":
            reasons.append(f"test {r[0]} FAIL: {r[2][:200]}")
    want = job.get("expect", {}).get("results")
    if want is not None and len(results) < want:
        reasons.append(f"only {len(results)}/{want} test RESULT lines (guest/workload did not finish)")
    for k in CHK:
        if stats.get(k, 0) > 0:
            reasons.append(f"{k}={int(stats[k])}")
    for pat in job.get("expect", {}).get("must_contain", []):
        if not re.search(pat, text):
            reasons.append(f"missing expected output /{pat}/")
    verdict = "PASS" if not reasons else "FAIL"
    rec = {"name": job["name"], "build": job["build"], "verdict": verdict,
           "reasons": reasons, "rc": rc, "secs": round(dt), "results": results,
           "stats": {k: int(v) for k, v in stats.items()}, "outdir": str(out),
           "desc": job.get("desc", "")}
    done.write_text(json.dumps(rec, indent=1))
    print(f"[{time.strftime('%T')}] {verdict} {job['build']}/{job['name']} {dt:.0f}s {reasons[:2]}", flush=True)
    return rec


def main():
    jobsfile = sys.argv[1]
    n = int(sys.argv[sys.argv.index("--jobs") + 1]) if "--jobs" in sys.argv else 24
    tag = sys.argv[sys.argv.index("--tag") + 1] if "--tag" in sys.argv else pathlib.Path(jobsfile).stem
    jobs = json.load(open(jobsfile))
    log(f"runner {tag}: START {len(jobs)} jobs, parallel={n}")
    recs = []
    with cf.ThreadPoolExecutor(n) as ex:
        futs = {ex.submit(run, j, tag): j for j in jobs}
        for f in cf.as_completed(futs):
            try:
                recs.append(f.result())
            except Exception as e:  # runner bug: record, keep going
                j = futs[f]
                recs.append({"name": j["name"], "build": j["build"], "verdict": "ERROR",
                             "reasons": [repr(e)], "results": [], "stats": {}, "secs": 0})
    recs.sort(key=lambda r: (r["name"], r["build"]))
    res = pathlib.Path(os.environ.get("RES", R + "/results"))
    (res / f"{tag}.json").write_text(json.dumps(recs, indent=1))
    with open(res / f"{tag}.md", "w") as f:
        f.write(f"# {tag}\n\nGenerated {time.strftime('%F %T')}. Raw outputs: `{W}/runs/{tag}/`\n\n")
        f.write("| job | build | verdict | sim secs | tests (P/F/S) | L2 hits | back-inval | incl. checks | incl. viol. | oracle checks | oracle mism. | stale/not-present | reasons |\n")
        f.write("|---|---|---|---|---|---|---|---|---|---|---|---|---|\n")
        for r in recs:
            s = r["stats"]; rs = r["results"]
            pfs = "/".join(str(sum(1 for x in rs if x[1] == v)) for v in ("PASS", "FAIL", "SKIP"))
            f.write(f"| {r['name']} | {r['build']} | **{r['verdict']}** | {r['secs']} | {pfs} | "
                    f"{s.get('chkL2Hits', '')} | {s.get('chkBackInvalidations', '')} | "
                    f"{s.get('chkInclusionChecks', '')} | {s.get('chkInclusionViolations', '')} | "
                    f"{s.get('chkOracleChecks', '')} | {s.get('chkOracleMismatch', '')} | "
                    f"{s.get('chkOracleWalkFault', '')} | {'; '.join(r['reasons'])[:400].replace('|', '/')} |\n")
        f.write("\n## Per-test RESULT lines\n\n")
        for r in recs:
            for t in r["results"]:
                f.write(f"- {r['build']}/{r['name']}: `{' '.join(t)[:250]}`\n")
    npass = sum(r["verdict"] == "PASS" for r in recs)
    fails = [f"{r['build']}/{r['name']}" for r in recs if r["verdict"] != "PASS"]
    log(f"runner {tag}: DONE {npass}/{len(recs)} PASS; not-pass: {', '.join(fails) or 'none'} "
        f"(table: robustness/results/{tag}.md)")


if __name__ == "__main__":
    main()
