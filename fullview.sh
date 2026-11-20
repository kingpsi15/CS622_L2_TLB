#!/bin/bash
# usage: bash ~/fullview.sh [full]     (default = summary)
MODE=${1:-summary}
ENTRIES="inc:csews20:1 excl:csewsrm22:1 nine:csewsrm23:1 agile:csewsrm24:1 perf:csewsrm25:1 nine:csewsrm26:0 nine:csewsrm27:0 inc:csewsrm28:0 inc:csewsrm29:0 excl:csewsrm30:0 excl:csewsrm31:0 agile:csewsrm32:0 agile:csewsrm33:0 perf:csewsrm34:0 perf:csewsrm35:0 inc:csewsrm2:0 inc:csewsrm3:0 excl:csewsrm4:0 excl:csewsrm5:0 nine:csewsrm6:0 nine:csewsrm13:0 agile:csewsrm8:0 agile:csewsrm10:0 perf:csewsrm11:0 perf:csewsrm12:0 inc:csewsrm14:0 excl:csewsrm15:0 nine:csewsrm17:0 agile:csewsrm18:0 perf:csewsrm19:0 inc:csewsrm36:0 excl:csewsrm37:0 nine:csewsrm38:0 agile:csewsrm39:0 perf:csewsrm40:0 inc:csewsrm42:0 excl:csewsrm43:0 nine:csewsrm44:0 agile:csewsrm45:0 perf:csewsrm46:0 inc:csewsrm47:0 excl:csewsrm48:0 nine:csewsrm49:0 agile:csewsrm50:0 perf:csewsrm51:0 inc:csewsrm52:0 inc:csewsrm53:0 inc:csewsrm54:0 inc:csewsrm55:0 excl:csewsrm56:0 excl:csewsrm57:0 excl:csewsrm58:0 excl:csewsrm59:0 nine:csewsrm60:0 nine:csewsrm61:0 nine:csewsrm62:0 nine:csewsrm63:0 agile:csewsrm64:0 agile:csewsrm65:0 agile:csewsrm66:0 agile:csewsrm67:0 perf:csewsrm68:0 perf:csewsrm69:0 perf:csewsrm70:0"
T=$(mktemp -d)
for e in $ENTRIES; do IFS=: read l h m <<<"$e"
  ( timeout 45 ssh -o LogLevel=ERROR -o BatchMode=yes -o ConnectTimeout=6 sahilag24@$h.cse.iitk.ac.in "bash ~/fullview_remote.sh $l $m" > $T/$h.out 2> $T/$h.err ) &
done; wait
python3 - $T $MODE $ENTRIES <<'PY'
import os, sys, collections, time
T, mode, entries = sys.argv[1], sys.argv[2], sys.argv[3:]
LANES = ['inc', 'excl', 'nine', 'agile', 'perf']
H, G = {}, {}
S, R = collections.defaultdict(list), collections.defaultdict(list)
B = {}; missing = []; alerts = []
for e in entries:
    l, h, m = e.split(':')
    p = f'{T}/{h}.out'
    txt = open(p).read() if os.path.exists(p) else ''
    if not txt.strip():
        err = open(f'{T}/{h}.err').read().strip()[:80] if os.path.exists(f'{T}/{h}.err') else ''
        missing.append((l, h)); alerts.append(f'{l} {h}: NO DATA ({err or "timeout/unreachable"})'); continue
    H[h] = dict(lane=l, main=(m == '1'), load=0, mem=0, tmp=0, mine=0, allg=0)
    for ln in txt.splitlines():
        f = ln.split('|')
        try:
            if f[0] == 'H': H[h].update(load=f[3], mem=int(f[4] or 0), tmp=int(f[5] or 0), mine=int(f[6]), allg=int(f[7]))
            elif f[0] == 'B': B.setdefault(l, [])
            elif f[0] == 'G': G[(h, f[3])] = dict(lane=l, alive=f[4] == '1', cpu=int(f[5]), ns=int(f[6]), pan=int(f[7]), trb=int(f[8]), idle=int(f[9]), done=int(f[10]) > 0, ex=f[11])
            elif f[0] == 'S': S[(h, f[3])].append(f[4])
            elif f[0] == 'R': R[(h, f[3])].append((f[4], f[5], f[6]))
        except (IndexError, ValueError): pass
    for ln in txt.splitlines():
        f = ln.split('|')
        if f[0] == 'B' and f[3] not in B[l]: B[l].append(f[3])

def sh(n):
    return n.split('.')[0] + (n[-1] if n[-2:] in ('_r', '_s') else '')
def hs(h): return h.replace('csewsrm', 'rm')

# per-guest alerts
for (h, gid), g in sorted(G.items()):
    tag = f'{g["lane"]} {h}/{gid}'
    if g['pan']: alerts.append(f'{tag}: PANIC lines={g["pan"]}')
    if g['trb']: alerts.append(f'{tag}: guest trouble lines={g["trb"]}')
    if not g['alive'] and not g['done']:
        alerts.append(f'{tag}: NOT RUNNING' + (f' (exit {g["ex"]})' if g['ex'] else ''))
for h, d in H.items():
    if d['main'] and (h, 'main') not in G: alerts.append(f'{d["lane"]} {h}: no main run dir/console found')
    if d['mem'] < 6: alerts.append(f'{d["lane"]} {h}: memory available {d["mem"]}G')
    if d['tmp'] < 20: alerts.append(f'{d["lane"]} {h}: /tmp free {d["tmp"]}G')

print('FULLVIEW', time.strftime('%Y-%m-%d %H:%M:%S'), f'| hosts reporting {len(H)}/{len(entries)}')
res_lines = []
lane_txt = {}
for l in LANES:
    gs = [(k, v) for k, v in G.items() if v['lane'] == l]
    res = collections.defaultdict(list)
    for (h, gid), v in gs:
        for b, verdict, rc in R[(h, gid)]: res[b].append((verdict, f'{hs(h)}/{gid}', rc))
    running = []
    for (h, gid), v in gs:
        if v['alive'] and not v['done']:
            done_b = {b for b, _, _ in R[(h, gid)]}
            cur = [b for b in S[(h, gid)] if b not in done_b]
            if cur: running.append(f'{sh(cur[-1])}@{hs(h)}/{gid}')
    names = B.get(l, [])
    started = {b for k in S for b in S[k] if G.get(k, {}).get('lane') == l}
    pas = {b: v for b, v in res.items() if any(x[0] == 'PASS' for x in v)}
    fail = {b: v for b, v in res.items() if all(x[0] != 'PASS' for x in v)}
    for b, v in res.items():
        kinds = {x[0] for x in v}
        if len(kinds) > 1: alerts.append(f'{l} {sh(b)}: PASS/FAIL DISAGREE {v}')
        for x in v:
            if x[0] != 'PASS': alerts.append(f'{l} {sh(b)}: {x[0]} {x[2]} on {x[1]}')
            if 'rc=124' in x[2]: alerts.append(f'{l} {sh(b)}: TIMEOUT rc=124')
    alive = sum(1 for _, v in gs if v['alive']); n = len(gs)
    cpuh = sum(v['cpu'] for _, v in gs) / 3600
    notstarted = [b for b in names if b not in started]
    t = [f'== {l:5} guests alive {alive}/{n} | cpu-hours {cpuh:.0f} | PASS {len(pas)} FAIL {len(fail)} running {len(running)} not-started-yet {len(notstarted)}/{len(names) or "?"}']
    if pas: t.append('   PASS : ' + ' '.join(f'{sh(b)}({v[0][1]})' for b, v in sorted(pas.items())))
    if fail: t.append('   FAIL : ' + ' '.join(f'{sh(b)}({v[0][1]},{v[0][2]})' for b, v in sorted(fail.items())))
    t.append('   RUN  : ' + (' '.join(sorted(running)) or '-'))
    if mode == 'full':
        t.append('   guest              state  cpu-h  starts results panic trouble idle  current')
        for (h, gid), v in sorted(gs, key=lambda kv: (kv[0][0], kv[0][1] != 'main', len(kv[0][1]), kv[0][1])):
            st = 'DONE' if v['done'] else ('RUN' if v['alive'] else ('EXIT' + v['ex'] if v['ex'] else 'DEAD'))
            done_b = {b for b, _, _ in R[(h, gid)]}
            cur = [b for b in S[(h, gid)] if b not in done_b]
            t.append(f'   {h+"/"+gid:18} {st:6} {v["cpu"]/3600:5.1f} {v["ns"]:6} {len(R[(h, gid)]):7} {v["pan"]:5} {v["trb"]:7} {v["idle"]:4}m  {cur[-1] if cur else "-"}')
    lane_txt[l] = t

print(f'ALERTS: {len(alerts) or "none"}')
for a in alerts: print('  -', a)
print('\nHOSTS')
print('  host         lane  role          guests  load   memGB  tmpGB  others')
for e in entries:
    l, h, m = e.split(':')
    if h not in H: print(f'  {h:12} {l:5} NO DATA'); continue
    d = H[h]; gs = [v for (hh, _), v in G.items() if hh == h]
    print(f'  {h:12} {l:5} {"main+extras" if d["main"] else "extras":13} {sum(v["alive"] for v in gs):2}/{len(gs):<5} {d["load"]:>5}  {d["mem"]:5}  {d["tmp"]:5}  {d["allg"] - d["mine"]}')
print()
for l in LANES: print('\n'.join(lane_txt[l]))
PY
rm -rf $T
