#!/usr/bin/python3
"""Generate FS-mode job matrix -> $W/jobs/fs_matrix.json  (+ guest scripts)

Each job boots Linux on KVM, switches to 1/2/4/8 simulated cores and runs the
whole tlbstress battery under a real kernel: timer interrupts, preemption,
context switches (CR3 writes -> flushNonGlobal), INVLPG / shootdown IPIs,
page faults, COW, THP, signals and CPU migration.  Both builds (inc / base).
"""
import base64, json, os
W = os.environ["W"]; R = os.environ["R"]; INC = os.environ["INC"]
binb64 = base64.b64encode(open(f"{W}/tests/tlbstress", "rb").read()).decode()


def battery(n):
    t = max(2, n)
    return ["capacity 65 2", "capacity 513 2", "capacity 1024 1", "conflict 80 4",
            "remap 10 96", "protect 6", "huge 2", f"shootdown {max(2, n)} 6",
            f"threads {t} 200 2", f"procs {max(3, n)} 6", "interrupts 6 200", "shared 20",
            # concurrency: run several tests at once so they preempt each other
            "PAR capacity 513 2 | conflict 80 4 | remap 6 64 | threads 2 150 2"]


def script(tests):
    lines = ["#!/bin/bash", "exec > /dev/ttyS0 2>&1", "cd /tmp",
             f"echo '{binb64}' | base64 -d > tlbstress && chmod +x tlbstress",
             "echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null",
             "echo TLBFS-GUEST nproc=$(nproc) kernel=$(uname -r)"]
    for t in tests:
        if t.startswith("PAR "):
            parts = [p.strip() for p in t[4:].split("|")]
            lines.append(" & ".join(f"timeout 60 ./tlbstress {p}" for p in parts) + " & wait")
        else:
            lines.append(f"timeout 60 ./tlbstress {t}; echo \"RC {t.split()[0]} $?\"")
    lines.append("echo TLBFS-GUEST-DONE")
    return "\n".join(lines) + "\n"


jobs = []
os.makedirs(f"{W}/jobs", exist_ok=True)
for cores in (1, 2, 4, 8):
    for cpu in ("timing", "o3"):
        if cpu == "o3" and cores > 4:
            continue
        tests = battery(cores)
        sp = f"{W}/jobs/guest_fs_{cores}c_{cpu}.sh"
        open(sp, "w").write(script(tests))
        nres = len(tests) + 3   # PAR line yields 4 RESULT lines
        for b in ("inc", "base"):
            jobs.append({"name": f"fs-{cores}c-{cpu}", "build": b,
                         "args": [f"{R}/scripts/fs_run.py", "--cores", str(cores),
                                  "--script", sp, "--cpu", cpu],
                         "env": {"TLBCHK_FS_PERIOD": "16", "TLBCHK_MAXWARN": "30"},
                         "timeout": 10 * 3600,
                         "expect": {"results": nres, "must_contain": ["TLBFS-GUEST-DONE"]},
                         "desc": f"full-system Linux, {cores} simulated {cpu} cores"})
json.dump(jobs, open(f"{W}/jobs/fs_matrix.json", "w"), indent=1)
print(len(jobs), "jobs")
