#!/usr/bin/env python3
"""Robustness instrumentation for the EXCLUSIVE x86 L2 TLB (lane 'excl').

Copy of apply_checker.py with the inclusion invariant replaced by an
EXCLUSIVITY invariant: no key may be resident in BOTH L1 and L2 at the same
time. Checked after every completed insert/promotion, L1->L2 spill (evictLRU),
flushAll, flushNonGlobal, demapPage, and unserialize.

Usage: apply_checker_excl.py <gem5-tree> {excl|base}
  excl : oracle (SE: compare TLB pa/perm against the process page table;
         every translation) + exclusivity invariant.
  base : oracle only (same as apply_checker.py's 'base', kept for symmetry /
         so the same driver script can instrument a stock copy if needed).

Mismatches are counted in stats.txt. The exclusivity counters reuse the
*existing* stat names the shared runner.py/gen_se_jobs.py table already know
how to read (chkInclusionChecks / chkInclusionViolations) so no change to
the shared runner.py is needed; for this lane those columns mean "exclusivity
checks / exclusivity violations", not "inclusion violations" -- documented
in EXCLUSIVE_TLB_ROBUSTNESS_REPORT.md.

Idempotent; aborts if an anchor is missing.
"""
import sys, pathlib

tree, variant = pathlib.Path(sys.argv[1]), sys.argv[2]
assert variant in ("excl", "base")
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
        "        void chkExclusivity(const char *where);\n"
        "        void chkReport(const char *kind, const std::string &msg);\n"
        "        uint64_t chkTranslations = 0;\n"
        "        bool chkPromoting = false;\n")

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

if variant == "excl":
    lookup_call = ("l2_lookup(e.vaddr, 0, false)"
                   if "l2_lookup(Addr va, uint64_t pcid" in h
                   else "l2_lookup(e.vaddr, false)")
    helpers += r'''
void
TLB::chkExclusivity(const char *where)
{
    if (chkPromoting)
        return;
    stats.chkInclusionChecks++;  // reused counter name: see file header
    for (unsigned i = 0; i < size; i++) {
        const TlbEntry &e = tlb[i];
        if (!e.trieHandle)
            continue;
        TlbEntry *l2 = l2_lookup(e.vaddr, 0, false);
        if (l2) {
            stats.chkInclusionViolations++;  // reused counter name
            chkReport("EXCLUSIVITY-VIOLATION", csprintf(
                "after %s: key %#x (pa %#x log %d) resident in BOTH L1 and "
                "L2 (L2 pa %#x log %d) -- violates the exclusive policy",
                where, e.vaddr, e.paddr, e.logBytes, l2->paddr, l2->logBytes));
        }
    }
}
'''
    helpers = helpers.replace("l2_lookup(e.vaddr, 0, false)", lookup_call)
else:
    helpers += "\nvoid TLB::chkExclusivity(const char *) {}\n"

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

# ---------------- stats registration -------------
anchor = '               "TLB misses on execute (instr) requests")'
assert c.count(anchor) == 1, "exMisses ADD_STAT anchor"
mine = [("chkOracleChecks","TLBCHK: translations compared against the page-table oracle"),
        ("chkOracleMismatch","TLBCHK: TLB pa/permission disagreed with page tables"),
        ("chkOracleWalkFault","TLBCHK: TLB translated a page the page tables do not map"),
        ("chkInclusionChecks","TLBCHK(excl lane): exclusivity invariant checks"),
        ("chkInclusionViolations","TLBCHK(excl lane): keys resident in both L1 and L2"),
        ("chkL2Hits","TLBCHK: L1 misses served by the L2"),
        ("chkBackInvalidations","TLBCHK: L1 entries back-invalidated by an L2 eviction")]
ins = ",\n".join(f'      ADD_STAT({n}, statistics::units::Count::get(),\n               "{d}")' for n, d in mine)
k = c.index(anchor) + len(anchor)
c = c[:k] + ",\n" + ins + c[k:]

# ---------------- exclusivity-check hook points (excl only) ----------------
if variant == "excl":
    insert_line = ("                    entry = insert(pageAlignedVaddr, promoted, pcid);\n"
                   if "entry = insert(pageAlignedVaddr, promoted, pcid);" in c else
                   "                    entry = insert(pageAlignedVaddr, *l2_entry, pcid);\n")
    remove_line = ("                    l2_remove(pageAlignedVaddr, pcid);\n"
                   if "l2_remove(pageAlignedVaddr, pcid);" in c else
                   "                    l2_remove(pageAlignedVaddr);\n")
    c = sub(c, insert_line,
            "                    stats.chkL2Hits++;\n"
            "                    chkPromoting = true;\n" + insert_line)
    c = sub(c, remove_line,
            remove_line + "                    chkPromoting = false;\n"
            "                    chkExclusivity(\"L2 promotion\");\n")
    # insert(): wrap by renaming the original (same pattern as apply_checker.py)
    c = sub(c, "TlbEntry *\nTLB::insert(Addr vpn, const TlbEntry &entry, uint64_t pcid)\n{",
            "TlbEntry *\nTLB::insert(Addr vpn, const TlbEntry &entry, uint64_t pcid)\n{\n"
            "    TlbEntry *r = insertImpl(vpn, entry, pcid);\n"
            "    chkExclusivity(\"insert\");\n    return r;\n}\n\n"
            "TlbEntry *\nTLB::insertImpl(Addr vpn, const TlbEntry &entry, uint64_t pcid)\n{")
    h = sub(h, "        void chkExclusivity(const char *where);\n",
            "        void chkExclusivity(const char *where);\n"
            "        TlbEntry *insertImpl(Addr vpn, const TlbEntry &entry, uint64_t pcid);\n")
    # end-of-function hooks
    for fn in ("flushAll", "flushNonGlobal", "evictLRU"):
        start = c.index(f"TLB::{fn}()\n{{")
        end = c.index("\n}\n", start)
        c = c[:end] + f'\n    chkExclusivity("{fn}");' + c[end:]
    start = c.index("TLB::demapPage(Addr va, uint64_t asn)\n{")
    end = c.index("\n}\n", start)
    c = c[:end] + '\n    chkExclusivity("demapPage");' + c[end:]
    start = c.index("TLB::unserialize(CheckpointIn &cp)\n{")
    end = c.index("\n}\n", start)
    c = c[:end] + '\n    chkExclusivity("unserialize(checkpoint-restore)");' + c[end:]

hh.write_text(h)
cc.write_text(c)
print(f"instrumented {variant}: {cc}")
