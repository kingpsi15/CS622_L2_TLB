import sys

# Read tlb.hh
with open('src/arch/x86/tlb.hh', 'r') as f:
    hh = f.read()

old_hh_decl = '''        struct SparseL2Entry {
            Addr vpn_2mb;
            uint64_t lruSeq;
            Addr paddrs[512];
            bool sub_valid[512];
            bool uncacheable[512];
            bool read_only[512];
            uint8_t coarse_filter[8]; // Perforated Pages: 8-bit coarse filter
            
            SparseL2Entry() : vpn_2mb(0), lruSeq(0) {
                for (int i = 0; i < 512; i++) {
                    sub_valid[i] = false;
                    paddrs[i] = 0;
                }
                for (int i = 0; i < 8; i++) {
                    coarse_filter[i] = COARSE_EMPTY;
                }
            }
        };

        struct L2Set {
            SparseL2Entry entries[L2_WAYS];
            bool valid[L2_WAYS];
        };
        
        std::vector<L2Set> l2_sets;'''

new_hh_decl = '''        // Entry types in Unified L2 TLB (ISCA 2020 Section IV-C)
        enum L2EntryType {
            L2_TYPE_EMPTY = 0,
            L2_TYPE_TRANSLATION = 1, // Regular / Perforated large page mapping
            L2_TYPE_BITMAP = 2       // Decoupled 32-bit hole bitmap cache line
        };

        struct DecoupledBitmapLine {
            Addr vpn_2mb;
            uint8_t chunk_idx; // Chunk index (0..15) for 32-bit sub-bitmaps
            uint32_t bitmap_bits; // 32 bits for 32 sub-pages
            uint64_t lruSeq;
            
            DecoupledBitmapLine() : vpn_2mb(0), chunk_idx(0), bitmap_bits(0), lruSeq(0) {}
        };

        struct SparseL2Entry {
            Addr vpn_2mb;
            uint64_t lruSeq;
            Addr paddrs[512];
            bool sub_valid[512];
            bool uncacheable[512];
            bool read_only[512];
            uint8_t coarse_filter[8]; // 8-bit coarse filter in PTE
            
            SparseL2Entry() : vpn_2mb(0), lruSeq(0) {
                for (int i = 0; i < 512; i++) {
                    sub_valid[i] = false;
                    paddrs[i] = 0;
                }
                for (int i = 0; i < 8; i++) {
                    coarse_filter[i] = COARSE_EMPTY;
                }
            }
        };

        struct UnifiedL2Way {
            L2EntryType type;
            SparseL2Entry trans;
            DecoupledBitmapLine bmp;
            uint64_t lruSeq;
            
            UnifiedL2Way() : type(L2_TYPE_EMPTY), lruSeq(0) {}
        };

        struct L2Set {
            UnifiedL2Way ways[L2_WAYS];
        };
        
        std::vector<L2Set> l2_sets;
        
        // Decoupled bitmap cache helpers
        bool probe_bitmap_cache(Addr vpn_2mb, uint8_t chunk_idx);
        void install_bitmap_cache(Addr vpn_2mb, uint8_t chunk_idx, uint32_t bits);'''

if old_hh_decl not in hh:
    print(
