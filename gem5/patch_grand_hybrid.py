import sys

# Read tlb.hh
with open('src/arch/x86/tlb.hh', 'r') as f:
    hh = f.read()

# Add CoLT-FA buffer struct and functions to tlb.hh
target_hh_pos = '        // --- UNIFIED SET-ASSOCIATIVE L2 SETUP LOOP (ISCA 2020) ---'
if target_hh_pos not in hh:
    # let's find UnifiedL2Way
    target_hh_pos = '        struct UnifiedL2Way {'

colt_fa_decl = '''        // --- GRAND HYBRID: CoLT-FA Buffer (MICRO 2012) ---
        static const uint32_t COLT_FA_ENTRIES = 8;
        struct ColtFaEntry {
            Addr vpn_base;          // base VPN (page-aligned, unconcatenated)
            Addr paddr_base;        // base physical address
            uint8_t coal_len;       // number of contiguous pages coalesced (1 to 8)
            uint64_t lruSeq;
            bool valid;
            bool uncacheable;
            bool read_only;
        };
        ColtFaEntry colt_fa_array[COLT_FA_ENTRIES];
        uint64_t colt_fa_lruSeq;
        TlbEntry temp_colt_entry;

        TlbEntry *colt_fa_lookup(Addr va, bool update_lru = true);
        void colt_fa_insert(Addr base_vpn, Addr base_paddr, uint8_t coal_len, bool uncacheable, bool read_only);
        
'''

hh = hh.replace(target_hh_pos, colt_fa_decl + target_hh_pos)

# Add stats for Grand Hybrid
stats_target = '            statistics::Scalar decoupledBitmapEvictedTranslations;'
stats_addition = '''            statistics::Scalar decoupledBitmapEvictedTranslations;
            // Grand Hybrid Statistics
            statistics::Scalar coltFaLookups;
            statistics::Scalar coltFaHits;
            statistics::Scalar l2ExclusivePromotions;
            statistics::Scalar l1EvictionsSpilledToL2;'''

hh = hh.replace(stats_target, stats_addition)

with open('src/arch/x86/tlb.hh.hybrid', 'w') as f:
    f.write(hh)
print(
