#!/usr/bin/env python3
"""NINE-lane robustness instrumentation for a gem5 x86 TLB (tlb.cc / tlb.hh).

Usage: apply_checker_nine.py <gem5-tree> {sa|fixed}
  sa    : original tlb.cc.nine.sa / tlb.hh.nine.sa layout
          (per-set fixed arrays: l2_sets[i].valid[j] / l2_sets[i].entries[j],
          constants L2_SETS / L2_WAYS)
  fixed : tlb.cc.nine.fixed / tlb.hh.nine.fixed layout
          (flat vectors: l2_valid[i] / l2_entries[i], runtime l2NumSets/l2NumWays)

Adds, for BOTH layouts:
  * The translation ORACLE (same as apply_checker.py 'base'): every
    translation that completes paging is compared against the process page
    table (SE) / a functional guest walk (FS, every TLBCHK_FS_PERIOD-th).
  * A STALENESS SCAN: after flushAll(), flushNonGlobal(), demapPage() and
    unserialize(), walk every valid L1 entry AND every valid L2 entry and
    recheck each one against the page table oracle. This is the NINE-lane
    equivalent of the 'inc' lane's inclusion-invariant scan: NINE has no
    inclusion invariant to check (L1/L2 residency is intentionally
    independent), so the thing worth scanning for is a stale survivor of an
    invalidation event, in either array.

Mismatches are counted in stats.txt (system.*.mmu.{dtb,itb}.chk*), the first
TLBCHK_MAXWARN (default 20) are printed with details, and TLBCHK_PANIC=1
makes the first mismatch fatal (used by directed tests).

Idempotent; aborts if an anchor is missing (fails loudly on a layout drift
instead of silently no-op'ing).
"""
import sys, pathlib

tree, layout = pathlib.Path(sys.argv[1]), sys.argv[2]
assert layout in ("sa", "fixed")
cc = tree / "src/arch/x86/tlb.cc"
hh = tree / "src/arch/x86/tlb.hh"
MARK = "TLBCHK-NINE-INSTRUMENTATION"

def sub(text, anchor, new, count=1):
    n = text.count(anchor)
    if n != count:
        sys.exit(f"anchor found {n}x (want {count}): {anchor[:70]!r}")
    return text.replace(anchor, new)

h = hh.read_text()
c = cc.read_text()
if MARK in c:
    print("already instrumented"); sys.exit(0)

# ---------------- header: stats + helper declarations ----------------
stats_extra = """            statistics::Scalar exMisses;
            // TLBCHK-NINE-INSTRUMENTATION
            statistics::Scalar chkOracleChecks;
            statistics::Scalar chkOracleMismatch;
            statistics::Scalar chkOracleWalkFault;
            statistics::Scalar chkStaleScans;
            statistics::Scalar chkStaleL1;
            statistics::Scalar chkStaleL2;
            statistics::Scalar chkStaleDup;
"""
h = sub(h, "            statistics::Scalar exMisses;\n", stats_extra)
h = sub(h, "        void evictLRU();\n",
        "        void evictLRU();\n"
        "        // TLBCHK-NINE-INSTRUMENTATION\n"
        "        bool chkOracleOne(Addr vaddr, Addr paddr, unsigned logBytes,\n"
        "                          bool writable, ThreadContext *tc, BaseMMU::Mode mode);\n"
        "        void chkStaleness(const char *where, ThreadContext *tc);\n"
        "        uint64_t chkTranslations = 0;\n"
        "        ThreadContext *chkLastTc = nullptr;\n")

# ---------------- cc: helpers ----------------
helpers = r'''
// ===================== TLBCHK-NINE-INSTRUMENTATION =====================
namespace
{
struct ChkCfg
{
    bool panicOnError = false;
    uint64_t fsPeriod = 64;
    uint64_t maxWarn = 20;
    ChkCfg()
    {
        if (const char *s = std::getenv("TLBCHK_PANIC")) panicOnError = atoi(s);
        if (const char *s = std::getenv("TLBCHK_FS_PERIOD")) fsPeriod = strtoull(s, 0, 0);
        if (const char *s = std::getenv("TLBCHK_MAXWARN")) maxWarn = strtoull(s, 0, 0);
    }
};
ChkCfg &chkCfg() { static ChkCfg c; return c; }
uint64_t chkWarned = 0;
void
chkReportImpl(const char *kind, const std::string &name, const std::string &msg)
{
    if (chkCfg().panicOnError)
        panic("TLBCHK %s in %s: %s", kind, name.c_str(), msg.c_str());
    if (chkWarned++ < chkCfg().maxWarn)
        warn("TLBCHK %s in %s @tick %llu: %s", kind, name.c_str(),
             (unsigned long long)curTick(), msg.c_str());
}
} // anonymous namespace

// One-translation oracle check against the SE-mode page table / FS guest
// walk. Returns false on a confirmed mismatch or staleness, true otherwise
// (including "not checked this time", e.g. FS mode outside the sampling
// period) so callers that only care about pass/fail (the staleness scan)
// don't have to diff stat counters.
bool
TLB::chkOracleOne(Addr vaddr, Addr paddr, unsigned logBytes, bool writable,
                   ThreadContext *tc, BaseMMU::Mode mode)
{
    if (!FullSystem) {
        stats.chkOracleChecks++;
        Process *cp = tc->getProcessPtr();
        const EmulationPageTable::Entry *opte = cp->pTable->lookup(vaddr);
        if (!opte) {
            stats.chkOracleWalkFault++;
            chkReportImpl("ORACLE-STALE-UNMAPPED", name(), csprintf(
                "va %#x -> pa %#x but page table has no mapping "
                "(pid %d mode %d)", vaddr, paddr, cp->pid(), (int)mode));
            return false;
        }
        Addr opa = opte->paddr + (vaddr & mask(PageShift));
        bool oro = opte->flags & EmulationPageTable::ReadOnly;
        if (opa != paddr || (oro && writable)) {
            stats.chkOracleMismatch++;
            chkReportImpl("ORACLE-MISMATCH", name(), csprintf(
                "va %#x: TLB pa %#x w%d, page table pa %#x ro%d "
                "(pid %d mode %d)", vaddr, paddr, writable, opa, oro,
                cp->pid(), (int)mode));
            return false;
        }
        return true;
    } else if (chkCfg().fsPeriod && (++chkTranslations % chkCfg().fsPeriod) == 0) {
        stats.chkOracleChecks++;
        Addr wa = vaddr;
        unsigned wlog = 0;
        Fault wf = walker->startFunctional(tc, wa, wlog, mode);
        if (wf != NoFault) {
            stats.chkOracleWalkFault++;
            chkReportImpl("ORACLE-STALE-NOTPRESENT", name(), csprintf(
                "va %#x -> pa %#x (log %d) but guest page tables say not "
                "present (cr3 %#x mode %d)", vaddr, paddr, logBytes,
                tc->readMiscRegNoEffect(misc_reg::Cr3), (int)mode));
            return false;
        }
        Addr wpa = wa | (vaddr & mask(wlog));
        if (wpa != paddr) {
            stats.chkOracleMismatch++;
            chkReportImpl("ORACLE-MISMATCH", name(), csprintf(
                "va %#x: TLB pa %#x (log %d), walk pa %#x (log %d) cr3 %#x",
                vaddr, paddr, logBytes, wpa, wlog,
                tc->readMiscRegNoEffect(misc_reg::Cr3)));
            return false;
        }
        return true;
    }
    return true;
}
'''

if layout == "sa":
    helpers += r'''
void
TLB::chkStaleness(const char *where, ThreadContext *tc)
{
    stats.chkStaleScans++;
    if (FullSystem || !tc) return; // SE-mode-only scan, like the oracle above.
    for (unsigned i = 0; i < size; i++) {
        const TlbEntry &e = tlb[i];
        if (!e.trieHandle) continue;
        Addr va = e.vaddr & ~mask(X86ISA::PageShift);
        Addr pa = e.paddr | (va & mask(e.logBytes));
        if (!chkOracleOne(va, pa, e.logBytes, e.writable, tc, BaseMMU::Read)) {
            stats.chkStaleL1++;
            chkReportImpl("STALE-L1-SURVIVOR", name(), csprintf(
                "after %s: stale L1 entry va %#x pa %#x log %d survived",
                where, va, e.paddr, e.logBytes));
        }
    }
    for (int s = 0; s < L2_SETS; s++) {
        for (int w = 0; w < L2_WAYS; w++) {
            if (!l2_sets[s].valid[w]) continue;
            const TlbEntry &e = l2_sets[s].entries[w];
            Addr va = e.vaddr & ~mask(X86ISA::PageShift);
            Addr pa = e.paddr | (va & mask(e.logBytes));
            if (!chkOracleOne(va, pa, e.logBytes, e.writable, tc, BaseMMU::Read)) {
                stats.chkStaleL2++;
                chkReportImpl("STALE-L2-SURVIVOR", name(), csprintf(
                    "after %s: stale L2 entry set %d way %d va %#x pa %#x "
                    "log %d survived", where, s, w, va, e.paddr, e.logBytes));
            }
        }
    }
}
'''
else:
    helpers += r'''
void
TLB::chkStaleness(const char *where, ThreadContext *tc)
{
    stats.chkStaleScans++;
    if (FullSystem || !tc) return;
    for (unsigned i = 0; i < size; i++) {
        const TlbEntry &e = tlb[i];
        if (!e.trieHandle) continue;
        Addr va = e.vaddr & ~mask(X86ISA::PageShift);
        Addr pa = e.paddr | (va & mask(e.logBytes));
        if (!chkOracleOne(va, pa, e.logBytes, e.writable, tc, BaseMMU::Read)) {
            stats.chkStaleL1++;
            chkReportImpl("STALE-L1-SURVIVOR", name(), csprintf(
                "after %s: stale L1 entry va %#x pa %#x log %d survived",
                where, va, e.paddr, e.logBytes));
        }
    }
    for (size_t i = 0; i < l2_valid.size(); i++) {
        if (!l2_valid[i]) continue;
        const TlbEntry &e = l2_entries[i];
        Addr va = e.vaddr & ~mask(X86ISA::PageShift);
        Addr pa = e.paddr | (va & mask(e.logBytes));
        if (!chkOracleOne(va, pa, e.logBytes, e.writable, tc, BaseMMU::Read)) {
            stats.chkStaleL2++;
            chkReportImpl("STALE-L2-SURVIVOR", name(), csprintf(
                "after %s: stale L2 entry slot %zu va %#x pa %#x log %d "
                "survived", where, i, va, e.paddr, e.logBytes));
        }
    }
}
'''

c = sub(c, "namespace X86ISA {\n", "namespace X86ISA {\n" + helpers, 1)
c = sub(c, '#include <cstring>\n', '#include <cstdlib>\n#include <cstring>\n')

# ---------------- oracle, just before the physical address is produced ----------------
oracle = r'''            // TLBCHK-NINE-INSTRUMENTATION: translation oracle
            chkLastTc = tc;
            chkOracleOne(vaddr, entry->paddr | (vaddr & mask(entry->logBytes)),
                         entry->logBytes, entry->writable, tc, mode);
            Addr paddr = entry->paddr | (vaddr & mask(entry->logBytes));
'''
c = sub(c, "            Addr paddr = entry->paddr | (vaddr & mask(entry->logBytes));\n", oracle)

# ---------------- stats registration ----------------
anchor = '               "TLB misses on execute (instr) requests")'
assert c.count(anchor) == 1, "exMisses ADD_STAT anchor"
mine = [("chkOracleChecks","TLBCHK: translations compared against the page-table oracle"),
        ("chkOracleMismatch","TLBCHK: TLB pa/permission disagreed with page tables"),
        ("chkOracleWalkFault","TLBCHK: TLB translated a page the page tables do not map"),
        ("chkStaleScans","TLBCHK: full-TLB staleness scans run (after demap/flush/restore)"),
        ("chkStaleL1","TLBCHK: stale L1 entries found by a staleness scan"),
        ("chkStaleL2","TLBCHK: stale L2 entries found by a staleness scan"),
        ("chkStaleDup","TLBCHK: reserved")]
ins = ",\n".join(f'      ADD_STAT({n}, statistics::units::Count::get(),\n               "{d}")' for n, d in mine)
k = c.index(anchor) + len(anchor)
c = c[:k] + ",\n" + ins + c[k:]

# ---------------- staleness-scan hook points ----------------
# flushAll/flushNonGlobal/demapPage do not receive a ThreadContext in this
# TLB's API (BaseTLB::demapPage(Addr, uint64_t) / flushAll()). translate()
# always does, so we cache the most recently seen tc (chkLastTc, set above)
# and use it here. This is exact for the SE-mode matrix used by this lane
# (one Process per TLB object; multi-context sharing one TLB -- SMT -- is a
# known gem5/stock limitation per the audit, not something this scan claims
# to cover).
for fn in ("flushAll", "flushNonGlobal", "demapPage"):
    sig = "TLB::demapPage(Addr va, uint64_t asn)\n{" if fn == "demapPage" \
          else f"TLB::{fn}()\n{{"
    start = c.index(sig)
    end = c.index("\n}\n", start)
    c = c[:end] + f'\n    if (!FullSystem && chkLastTc) chkStaleness("{fn}", chkLastTc);' + c[end:]
start = c.index("TLB::unserialize(CheckpointIn &cp)\n{")
end = c.index("\n}\n", start)
c = c[:end] + '\n    if (!FullSystem && chkLastTc) chkStaleness("unserialize(checkpoint-restore)", chkLastTc);' + c[end:]

hh.write_text(h)
cc.write_text(c)
print(f"instrumented nine ({layout}): {cc}")
