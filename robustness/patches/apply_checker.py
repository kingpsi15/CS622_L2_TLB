#!/usr/bin/env python3
"""Add robustness instrumentation to a gem5 x86 TLB (tlb.cc / tlb.hh).

Usage: apply_checker.py <gem5-tree> {inc|base}

Both variants get a translation ORACLE (on every translation that paging
completes, before req->setPaddr):
  * SE mode : compare the TLB's physical address / read-only flag with the
              process page table (p->pTable->lookup).  Every translation.
  * FS mode : every Nth translation (env TLBCHK_FS_PERIOD, default 64; 0=off)
              do a functional page walk of the guest page tables and compare
              the physical address; a walk fault (not present) means the TLB
              used a translation the OS has removed.
'inc' additionally gets an INCLUSION INVARIANT check: every valid L1 entry must
have an L2 entry with the same key, paddr, size and permissions.  Checked after
insert / flushAll / flushNonGlobal / demapPage / unserialize.

Mismatches are counted in stats.txt (system.*.mmu.{dtb,itb}.chk*), the first
TLBCHK_MAXWARN (default 20) are printed with details, and if TLBCHK_PANIC=1 the
simulation panics on the first one (used by the directed tests).

The script is idempotent and aborts if an anchor is missing.
"""
import sys, pathlib

tree, variant = pathlib.Path(sys.argv[1]), sys.argv[2]
assert variant in ("inc", "base")
cc = tree / "src/arch/x86/tlb.cc"
hh = tree / "src/arch/x86/tlb.hh"
MARK = "TLBCHK-INSTRUMENTATION"

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
            // TLBCHK-INSTRUMENTATION
            statistics::Scalar chkOracleChecks;
            statistics::Scalar chkOracleMismatch;
            statistics::Scalar chkOracleWalkFault;
            statistics::Scalar chkInclusionChecks;
            statistics::Scalar chkInclusionViolations;
            statistics::Scalar chkL2Hits;
            statistics::Scalar chkBackInvalidations;
"""
h = sub(h, "            statistics::Scalar exMisses;\n", stats_extra)
h = sub(h, "        void evictLRU();\n",
        "        void evictLRU();\n"
        "        // TLBCHK-INSTRUMENTATION\n"
        "        void chkInclusion(const char *where);\n"
        "        void chkReport(const char *kind, const std::string &msg);\n"
        "        uint64_t chkTranslations = 0;\n")
# (header written at the end)

# ---------------- cc: helpers ----------------
helpers = r'''
// ===================== TLBCHK-INSTRUMENTATION =====================
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
} // anonymous namespace

void
TLB::chkReport(const char *kind, const std::string &msg)
{
    if (chkCfg().panicOnError)
        panic("TLBCHK %s in %s: %s", kind, name(), msg);
    if (chkWarned++ < chkCfg().maxWarn)
        warn("TLBCHK %s in %s @tick %llu: %s", kind, name(),
             (unsigned long long)curTick(), msg);
}
'''

if variant == "inc":
    helpers += r'''
void
TLB::chkInclusion(const char *where)
{
    stats.chkInclusionChecks++;
    for (unsigned i = 0; i < size; i++) {
        const TlbEntry &e = tlb[i];
        if (!e.trieHandle)
            continue;
        // L2 is keyed by the same concatenated (vaddr|pcid) key as L1.
        TlbEntry *l2 = l2_lookup(e.vaddr, false);
        if (!l2 || l2->paddr != e.paddr || l2->logBytes != e.logBytes ||
            l2->writable != e.writable || l2->user != e.user ||
            l2->noExec != e.noExec || l2->global != e.global ||
            l2->uncacheable != e.uncacheable) {
            stats.chkInclusionViolations++;
            chkReport("INCLUSION-VIOLATION", csprintf(
                "after %s: L1 key %#x pa %#x log %d w%d u%d g%d has %s",
                where, e.vaddr, e.paddr, e.logBytes, e.writable, e.user,
                e.global, l2 ? csprintf("MISMATCHED L2 pa %#x log %d w%d",
                    l2->paddr, l2->logBytes, l2->writable).c_str()
                    : "NO L2 copy"));
        }
    }
}
'''
else:
    helpers += "\nvoid TLB::chkInclusion(const char *) {}\n"

c = sub(c, "namespace X86ISA {\n", "namespace X86ISA {\n" + helpers, 1)
c = sub(c, '#include <cstring>\n', '#include <cstdlib>\n#include <cstring>\n')

# ---------------- oracle, just before the physical address is produced ----------------
oracle = r'''            // TLBCHK-INSTRUMENTATION: translation oracle
            {
                Addr chk_pa = entry->paddr | (vaddr & mask(entry->logBytes));
                chkTranslations++;
                if (!FullSystem) {
                    stats.chkOracleChecks++;
                    Process *cp = tc->getProcessPtr();
                    const EmulationPageTable::Entry *opte =
                        cp->pTable->lookup(vaddr);
                    if (!opte) {
                        stats.chkOracleWalkFault++;
                        chkReport("ORACLE-STALE-UNMAPPED", csprintf(
                            "va %#x -> pa %#x but page table has no mapping "
                            "(pid %d mode %d)", vaddr, chk_pa,
                            cp->pid(), (int)mode));
                    } else {
                        Addr opa = opte->paddr + (vaddr & mask(PageShift));
                        bool oro = opte->flags & EmulationPageTable::ReadOnly;
                        if (opa != chk_pa || (oro && entry->writable)) {
                            stats.chkOracleMismatch++;
                            chkReport("ORACLE-MISMATCH", csprintf(
                                "va %#x: TLB pa %#x w%d, page table pa %#x "
                                "ro%d (pid %d mode %d)", vaddr, chk_pa,
                                entry->writable, opa, oro, cp->pid(),
                                (int)mode));
                        }
                    }
                } else if (chkCfg().fsPeriod &&
                           chkTranslations % chkCfg().fsPeriod == 0) {
                    stats.chkOracleChecks++;
                    Addr wa = vaddr;
                    unsigned wlog = 0;
                    Fault wf = walker->startFunctional(tc, wa, wlog, mode);
                    if (wf != NoFault) {
                        stats.chkOracleWalkFault++;
                        chkReport("ORACLE-STALE-NOTPRESENT", csprintf(
                            "va %#x -> pa %#x (log %d) but guest page "
                            "tables say not present (cr3 %#x mode %d)",
                            vaddr, chk_pa, entry->logBytes,
                            tc->readMiscRegNoEffect(misc_reg::Cr3),
                            (int)mode));
                    } else {
                        Addr wpa = wa | (vaddr & mask(wlog));
                        if (wpa != chk_pa) {
                            stats.chkOracleMismatch++;
                            chkReport("ORACLE-MISMATCH", csprintf(
                                "va %#x: TLB pa %#x (log %d), walk pa %#x "
                                "(log %d) cr3 %#x", vaddr, chk_pa,
                                entry->logBytes, wpa, wlog,
                                tc->readMiscRegNoEffect(misc_reg::Cr3)));
                        }
                    }
                }
            }
            Addr paddr = entry->paddr | (vaddr & mask(entry->logBytes));
'''
c = sub(c, "            Addr paddr = entry->paddr | (vaddr & mask(entry->logBytes));\n", oracle)

# ---------------- stats registration (works with or without extra stats after exMisses) -------------
anchor = '               "TLB misses on execute (instr) requests")'
assert c.count(anchor) == 1, "exMisses ADD_STAT anchor"
mine = [("chkOracleChecks","TLBCHK: translations compared against the page-table oracle"),
        ("chkOracleMismatch","TLBCHK: TLB pa/permission disagreed with page tables"),
        ("chkOracleWalkFault","TLBCHK: TLB translated a page the page tables do not map"),
        ("chkInclusionChecks","TLBCHK: L1-subset-of-L2 invariant checks"),
        ("chkInclusionViolations","TLBCHK: L1 entries without a matching L2 copy"),
        ("chkL2Hits","TLBCHK: L1 misses served by the L2"),
        ("chkBackInvalidations","TLBCHK: L1 entries back-invalidated by an L2 eviction")]
ins = ",\n".join(f'      ADD_STAT({n}, statistics::units::Count::get(),\n               "{d}")' for n, d in mine)
k = c.index(anchor) + len(anchor)
c = c[:k] + ",\n" + ins + c[k:]

# ---------------- inclusion-check hook points (inc only) ----------------
if variant == "inc":
    # counters inside the existing design (no behaviour change)
    c = sub(c, '            freeList.push_back(l1_entry);\n            DPRINTF(TLB, "INCLUSIVE POLICY',
               '            freeList.push_back(l1_entry);\n            stats.chkBackInvalidations++;\n            DPRINTF(TLB, "INCLUSIVE POLICY')
    c = sub(c, "                    // Copy it into the L1.\n",
               "                    // Copy it into the L1.\n                    stats.chkL2Hits++;\n")
    # after insert: wrap by renaming the original
    c = sub(c, "TlbEntry *\nTLB::insert(Addr vpn, const TlbEntry &entry, uint64_t pcid)\n{",
            "TlbEntry *\nTLB::insert(Addr vpn, const TlbEntry &entry, uint64_t pcid)\n{\n"
            "    TlbEntry *r = insertImpl(vpn, entry, pcid);\n"
            "    chkInclusion(\"insert\");\n    return r;\n}\n\n"
            "TlbEntry *\nTLB::insertImpl(Addr vpn, const TlbEntry &entry, uint64_t pcid)\n{")
    h2 = h
    h2 = sub(h2, "        void chkInclusion(const char *where);\n",
             "        void chkInclusion(const char *where);\n"
             "        TlbEntry *insertImpl(Addr vpn, const TlbEntry &entry, uint64_t pcid);\n")
    h = h2
    # end-of-function hooks: insert a call before the closing brace of each fn
    for fn in ("flushAll", "flushNonGlobal"):
        start = c.index(f"TLB::{fn}()\n{{")
        end = c.index("\n}\n", start)
        c = c[:end] + f'\n    chkInclusion("{fn}");' + c[end:]
    start = c.index("TLB::demapPage(Addr va, uint64_t asn)\n{")
    end = c.index("\n}\n", start)
    c = c[:end] + '\n    chkInclusion("demapPage");' + c[end:]
    start = c.index("TLB::unserialize(CheckpointIn &cp)\n{")
    end = c.index("\n}\n", start)
    c = c[:end] + '\n    chkInclusion("unserialize(checkpoint-restore)");' + c[end:]

hh.write_text(h)
cc.write_text(c)
print(f"instrumented {variant}: {cc}")
