#!/usr/bin/env python3
"""Add PERF_STRICT to the Perforated Pages L2 (tlb.cc.perf.fixed -> tlb.cc.perf.strict).

Problem: each L2 "2MB region" stores an independent physical address for every
one of its 512 4KB sub-pages (paddrs[512]) and never checks that they are
physically contiguous. Real perforated / sparse huge pages are 2MB-aligned,
physically contiguous regions with holes, described by ONE base address plus a
validity bitmap. As modelled, the L2 holds up to 128x4x512 = 262,144 unrelated
4KB translations (~512x the reach of the other 512-entry designs).

PERF_STRICT=1: a 4KB page may join an existing region only if
    paddr == region_base + offset_4k * 4KB
(region_base taken from any valid sub-page of the region). Otherwise the
region is re-based on the new page (its other sub-pages dropped) and
perfStrictRebases is counted. PERF_STRICT=0 (default) keeps the original
behaviour, so existing results are unchanged. Huge (logBytes > 12) inserts are
not checked.

  python make_perf_strict.py <gem5/src/arch/x86>
"""
import os, sys

D = sys.argv[1] if len(sys.argv) > 1 else "."


def sub(t, old, new, what):
    if t.count(old) != 1:
        sys.exit("anchor %s found %dx" % (what, t.count(old)))
    return t.replace(old, new)


cc = open(os.path.join(D, "tlb.cc.perf.fixed")).read()
cc = sub(cc, """            // Region exists! Coalesce it!
            l2_sets[set_idx].entries[i].sub_valid[offset_4k] = true;""",
"""            // Region exists! Coalesce it!
            // PERF_STRICT: only a page at region_base + offset may join;
            // otherwise re-base the region on this page.
            static const bool perfStrict = perfEnvUint("PERF_STRICT", 0) != 0;
            if (perfStrict && entry.logBytes == X86ISA::PageShift) {
                auto &R = l2_sets[set_idx].entries[i];
                for (uint32_t k = 0; k < 512; k++) {
                    if (!R.sub_valid[k] || k == offset_4k)
                        continue;
                    Addr base = R.paddrs[k] - (Addr)k * X86ISA::PageBytes;
                    if (base + (Addr)offset_4k * X86ISA::PageBytes != entry.paddr) {
                        stats.perfStrictRebases++;
                        R.resetTo(numCoarseChunks);
                        R.vpn_2mb = vpn_2mb;
                        R.pcid = pcid;
                    }
                    break;
                }
            }
            l2_sets[set_idx].entries[i].sub_valid[offset_4k] = true;""", "coalesce")
cc = sub(cc, """      ADD_STAT(estDynamicEnergyUnitsSaved, statistics::units::Count::get(),""",
"""      ADD_STAT(perfStrictRebases, statistics::units::Count::get(),
               "PERF_STRICT: regions re-based on a non-contiguous page"),
      ADD_STAT(estDynamicEnergyUnitsSaved, statistics::units::Count::get(),""", "stat")
open(os.path.join(D, "tlb.cc.perf.strict"), "w", newline="\n").write(cc)

hh = open(os.path.join(D, "tlb.hh.perf.fixed")).read()
hh = sub(hh, "            statistics::Scalar estDynamicEnergyUnitsSaved;",
"""            statistics::Scalar perfStrictRebases;
            statistics::Scalar estDynamicEnergyUnitsSaved;""", "hh stat")
open(os.path.join(D, "tlb.hh.perf.strict"), "w", newline="\n").write(hh)
print("wrote tlb.cc.perf.strict tlb.hh.perf.strict")
