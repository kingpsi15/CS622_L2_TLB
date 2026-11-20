# gem5 simulator fixes used in the full-system runs

These change gem5 itself, not the TLB designs (report Part III).

| File | What it changes |
|---|---|
| patch_i8237.py, patch_i8237_b.py | src/dev/x86/i8237.cc: unmodelled ISA DMA registers warn once and return 0 instead of panicking |
| isa_patch.py | adds the FCOMIP_R macro-op and its decoder entry (fcomip was a stub) |
| isa_patch_v2.py | isa_patch.py plus an fxam implementation (Examfp micro-op) |
| x87fix.sh | adds dataSize=8 to the x87 movfp micro-ops (they copied only 32 of 64 bits), rebuilds, checks against native |
| patch_walker_write.py | page walker writes the PTE back with a fresh packet instead of reusing the read response |
| fix_walker_func.sh | page walker PTE write done functionally (sendFunctional); differs from stock gem5 |

Each script takes the gem5 tree (or lane) as its argument; paths inside refer to the lab machines used.
