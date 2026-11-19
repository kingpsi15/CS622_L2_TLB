#!/usr/bin/env python3
"""Generate tlb.{cc,hh}.colt.fixed (CoLT-FA on the fixed NINE L2) and
pagetable_walker.cc.colt (full-system coalescing hook).

  python make_colt_fixed.py <gem5/src/arch/x86 dir>

CoLT-FA (Pham et al., MICRO 2012): a small fully associative buffer of
coalesced runs of up to 8 contiguous 4KB translations, probed after an L1
miss and before the set-associative L2. The mid-review version only formed
runs from the SE-mode emulated page table (so it was a no-op in full-system
mode), had no PCID tag, hard-coded user/noExec permissions and was never
invalidated by flushes or demaps. This version fixes all of that.
"""
import sys, os

D = sys.argv[1] if len(sys.argv) > 1 else "."


def sub(text, old, new, what):
    if old not in text:
        sys.exit("anchor not found: " + what)
    return text.replace(old, new, 1)


hh = open(os.path.join(D, "tlb.hh.nine.fixed")).read()
hh = sub(hh, "            statistics::Scalar l2Evictions;",
"""            statistics::Scalar l2Evictions;
            statistics::Scalar coltHits;
            statistics::Scalar coltInserts;
            statistics::Scalar coltCoalescedPages;
            statistics::Scalar coltInvalidations;""", "hh stats")
hh = sub(hh, "        TlbEntry *insert(Addr vpn, const TlbEntry &entry, uint64_t pcid);",
"""        TlbEntry *insert(Addr vpn, const TlbEntry &entry, uint64_t pcid);

        // --- CoLT-FA coalescing buffer (see tlb.cc). COLT_ENABLE=0 turns it
        // off (pure NINE baseline from the same binary); COLT_FA_ENTRIES sets
        // the number of entries (default 8).
        struct ColtFaEntry {
            Addr vpnBase = 0;       // 4KB-aligned virtual base of the run
            Addr paddrBase = 0;
            uint8_t len = 0;        // pages in the run (2..8)
            uint64_t pcid = 0;
            uint64_t lruSeq = 0;
            bool valid = false;
            TlbEntry perm;          // permissions/attributes of the run
        };
        std::vector<ColtFaEntry> coltFa;
        uint64_t coltLruSeq = 0;
        bool coltEnable = true;
        TlbEntry coltTemp;
        TlbEntry *colt_lookup(Addr concVa);
        void colt_insert(Addr vbase, Addr pbase, uint8_t len, uint64_t pcid,
                         const TlbEntry &perm);
        void colt_flush(bool keepGlobal);
        void colt_demap(Addr va);

        /** Walker hook: leaf 4KB PTE at index idx of its 8-PTE cache line. */
        void coltObserveLeaf(Addr vaddr, const uint64_t pte[8], int idx,
                             const TlbEntry &leaf, uint64_t pcid);""", "hh decl")
open(os.path.join(D, "tlb.hh.colt.fixed"), "w", newline="\n").write(hh)

cc = open(os.path.join(D, "tlb.cc.nine.fixed")).read()
cc = sub(cc, """    walker = p.walker;
    walker->setTLB(this);
}""", """    coltEnable = envU32("COLT_ENABLE", 1) != 0;
    coltFa.resize(std::min<uint32_t>(64, std::max<uint32_t>(1,
                      envU32("COLT_FA_ENTRIES", 8))));

    walker = p.walker;
    walker->setTLB(this);
}

// --- CoLT-FA helpers ---
TlbEntry *
TLB::colt_lookup(Addr concVa)
{
    if (!coltEnable)
        return nullptr;
    Addr va = concVa & ~((Addr)0xFFF);
    uint64_t pcid = concVa & 0xFFF;
    for (auto &e : coltFa) {
        if (!e.valid || (!e.perm.global && e.pcid != pcid))
            continue;
        if (va >= e.vpnBase &&
            va < e.vpnBase + (Addr)e.len * X86ISA::PageBytes) {
            e.lruSeq = ++coltLruSeq;
            coltTemp = e.perm;
            coltTemp.trieHandle = NULL;
            coltTemp.vaddr = va;
            coltTemp.paddr = e.paddrBase + (va - e.vpnBase);
            coltTemp.logBytes = X86ISA::PageShift;
            stats.coltHits++;
            return &coltTemp;
        }
    }
    return nullptr;
}

void
TLB::colt_insert(Addr vbase, Addr pbase, uint8_t len, uint64_t pcid,
                 const TlbEntry &perm)
{
    ColtFaEntry *v = nullptr;
    for (auto &e : coltFa) {
        if (e.valid && e.vpnBase == vbase && e.pcid == pcid) {
            v = &e;
            break;
        }
    }
    if (!v) {
        for (auto &e : coltFa) {
            if (!e.valid) {
                v = &e;
                break;
            }
            if (!v || e.lruSeq < v->lruSeq)
                v = &e;
        }
    }
    v->valid = true;
    v->vpnBase = vbase;
    v->paddrBase = pbase;
    v->len = len;
    v->pcid = pcid;
    v->perm = perm;
    v->perm.trieHandle = NULL;
    v->lruSeq = ++coltLruSeq;
    stats.coltInserts++;
    stats.coltCoalescedPages += len;
}

void
TLB::colt_flush(bool keepGlobal)
{
    for (auto &e : coltFa) {
        if (e.valid && !(keepGlobal && e.perm.global)) {
            e.valid = false;
            stats.coltInvalidations++;
        }
    }
}

void
TLB::colt_demap(Addr va)
{
    // Conservative: drop every run covering va, whatever its PCID.
    Addr a = va & ~((Addr)0xFFF);
    for (auto &e : coltFa) {
        if (e.valid && a >= e.vpnBase &&
            a < e.vpnBase + (Addr)e.len * X86ISA::PageBytes) {
            e.valid = false;
            stats.coltInvalidations++;
        }
    }
}

void
TLB::coltObserveLeaf(Addr vaddr, const uint64_t pte[8], int idx,
                     const TlbEntry &leaf, uint64_t pcid)
{
    if (!coltEnable)
        return;
    // Attribute bits that must match across a run: P(0) W(1) U(2) PWT(3)
    // PCD(4) PAT(7) G(8) NX(63). A/D are not compared (the leaf's own A bit
    // is written back after this hook, as in hardware CoLT). Every member
    // must be present and the frames physically contiguous.
    const uint64_t attr = 0x19FULL | (1ULL << 63);
    auto pfn = [](uint64_t p) { return p & 0x000FFFFFFFFFF000ULL; };
    auto ok = [&](int i) {
        return (pte[i] & 0x1) &&
               (pte[i] & attr) == (pte[idx] & attr);
    };
    if (!ok(idx))
        return;
    int lo = idx, hi = idx;
    while (lo > 0 && ok(lo - 1) &&
           pfn(pte[lo - 1]) + X86ISA::PageBytes == pfn(pte[lo]))
        lo--;
    while (hi < 7 && ok(hi + 1) &&
           pfn(pte[hi]) + X86ISA::PageBytes == pfn(pte[hi + 1]))
        hi++;
    int len = hi - lo + 1;
    if (len < 2)
        return;
    Addr va = vaddr & ~((Addr)0xFFF);
    Addr vbase = va - (Addr)(idx - lo) * X86ISA::PageBytes;
    colt_insert(vbase, pfn(pte[lo]), len, pcid, leaf);
}""", "ctor")
cc = sub(cc, """    l2_flushAll();
}""", """    l2_flushAll();
    colt_flush(false);
}""", "flushAll")
cc = sub(cc, """    l2_flushNonGlobal();
}""", """    l2_flushNonGlobal();
    colt_flush(true);
}""", "flushNonGlobal")
cc = sub(cc, """    l2_remove(va, asn);
    Addr pageAlignedVaddr""", """    l2_remove(va, asn);
    colt_demap(va);
    Addr pageAlignedVaddr""", "demap")
cc = sub(cc, """            if (!entry) {
                // It missed in L1. Check the L2.
                TlbEntry *l2_entry = l2_lookup(pageAlignedVaddr);""", """            if (!entry) {
                // L1 miss: probe the CoLT-FA coalescing buffer first.
                TlbEntry *colt_entry = colt_lookup(pageAlignedVaddr);
                if (colt_entry)
                    entry = insert(pageAlignedVaddr, *colt_entry, pcid);
            }
            if (!entry) {
                // Missed L1 and CoLT-FA. Check the L2.
                TlbEntry *l2_entry = l2_lookup(pageAlignedVaddr);""", "translate")
cc = sub(cc, """                                pte->flags & EmulationPageTable::ReadOnly),
                                pcid);
                    }""", """                                pte->flags & EmulationPageTable::ReadOnly),
                                pcid);
                        // SE-mode CoLT: build the 8 "PTEs" of the aligned
                        // 32KB window from the emulated page table.
                        if (coltEnable) {
                            Addr cl = alignedVaddr & ~((Addr)0x7FFF);
                            int ti = (alignedVaddr - cl) >> X86ISA::PageShift;
                            uint64_t q8[8];
                            for (int i = 0; i < 8; i++) {
                                const auto *q = p->pTable->lookup(
                                    cl + i * X86ISA::PageBytes);
                                q8[i] = !q ? 0 : (q->paddr | 0x25 |
                                    ((q->flags & EmulationPageTable::ReadOnly)
                                        ? 0 : 0x2) |
                                    ((q->flags & EmulationPageTable::Uncacheable)
                                        ? 0x10 : 0));
                            }
                            coltObserveLeaf(alignedVaddr, q8, ti, *entry, pcid);
                        }
                    }""", "SE path")
cc = sub(cc, """      ADD_STAT(l2Evictions, statistics::units::Count::get(),
               "NINE: L2 entries evicted to make room")""", """      ADD_STAT(l2Evictions, statistics::units::Count::get(),
               "NINE: L2 entries evicted to make room"),
      ADD_STAT(coltHits, statistics::units::Count::get(),
               "CoLT-FA: L1 misses served by the coalescing buffer"),
      ADD_STAT(coltInserts, statistics::units::Count::get(),
               "CoLT-FA: coalesced runs inserted"),
      ADD_STAT(coltCoalescedPages, statistics::units::Count::get(),
               "CoLT-FA: 4KB pages covered by inserted runs"),
      ADD_STAT(coltInvalidations, statistics::units::Count::get(),
               "CoLT-FA: runs invalidated by flush/demap/restore")""", "stats")
cc = sub(cc, """TLB::unserialize(CheckpointIn &cp)
{""", """TLB::unserialize(CheckpointIn &cp)
{
    // CoLT-FA runs are not checkpointed; start empty after a restore.
    colt_flush(false);""", "unserialize")
open(os.path.join(D, "tlb.cc.colt.fixed"), "w", newline="\n").write(cc)

w = open(os.path.join(D, "pagetable_walker.cc")).read()
w = sub(w, '#include "mem/request.hh"', '#include "mem/request.hh"\n#include "sim/system.hh"', "walker include")
w = sub(w, """        entry.vaddr = mbits(entry.vaddr, 63, 12);
        doTLBInsert = true;
        doEndWalk = true;
        break;
      case PAEPDP:""", """        entry.vaddr = mbits(entry.vaddr, 63, 12);
        doTLBInsert = true;
        doEndWalk = true;
        coltLeafPte = read->getAddr();
        break;
      case PAEPDP:""", "walker LongPTE")
w = sub(w, """    PageTableEntry pte;
    if (dataSize == 8)""", """    PageTableEntry pte;
    Addr coltLeafPte = 0;   // CoLT: address of a 4KB leaf PTE, if any
    if (dataSize == 8)""", "walker local")
w = sub(w, """                    walker->tlb->insert(entry.vaddr, entry, cr3.pcid);
                }""", """                    walker->tlb->insert(entry.vaddr, entry, cr3.pcid);
                    coltPcid = cr3.pcid;
                }""", "walker pcid")
w = sub(w, """                    walker->tlb->insert(entry.vaddr, entry, 0x000);
                }
            }""", """                    walker->tlb->insert(entry.vaddr, entry, 0x000);
                }
                // CoLT-FA: the leaf PTE's 64-byte line holds 8 PTEs; read
                // them (functionally, as the line was just fetched) and let
                // the TLB coalesce a contiguous run around this page.
                if (coltLeafPte) {
                    uint64_t line[8];
                    Addr base = coltLeafPte & ~((Addr)63);
                    walker->sys->physProxy.readBlob(base, line, sizeof(line));
                    for (auto &q : line)
                        q = letoh(q);
                    walker->tlb->coltObserveLeaf(entry.vaddr, line,
                        (coltLeafPte - base) / 8, entry, coltPcid);
                }
            }""", "walker hook")
w = sub(w, """        if (doTLBInsert)
            if (!functional) {
""", """        uint64_t coltPcid = 0;
        if (doTLBInsert)
            if (!functional) {
""", "walker pcid decl")
open(os.path.join(D, "pagetable_walker.cc.colt"), "w", newline="\n").write(w)
print("wrote tlb.cc.colt.fixed tlb.hh.colt.fixed pagetable_walker.cc.colt")
