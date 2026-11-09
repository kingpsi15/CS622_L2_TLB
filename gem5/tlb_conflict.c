// Workload: L2 SET-CONFLICT (true thrashing of one xor_7 set)
// Picks NPAGES pages whose virtual page number hashes to the SAME
// L2 set under xor_7 = ((vpn>>7)&0x7F) ^ (vpn&0x7F), then cycles over them.
// NPAGES (80) > L1 entries (64)  -> every access misses the L1 (cyclic LRU)
// NPAGES (80) > L2 ways (4)      -> a set-associative L2 also thrashes
// NPAGES (80) < L2 entries (512) -> a fully-associative L2 would still hit
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define PAGE   4096UL
#define NPAGES 80
#define PASSES 10
#define WINDOW (16384UL + 64)   /* 2^14 pages: each set appears 128 times */

static unsigned xor7(uint64_t vpn) { return ((vpn >> 7) & 0x7F) ^ (vpn & 0x7F); }

static volatile char *pages[NPAGES];

int main(void) {
    char *region = (char *)malloc(WINDOW * PAGE);
    if (!region) return 1;
    uint64_t first = ((uint64_t)region + PAGE - 1) & ~(PAGE - 1);
    unsigned target = xor7(first / PAGE);

    int n = 0;
    for (uint64_t a = first; n < NPAGES && a < (uint64_t)region + WINDOW * PAGE; a += PAGE)
        if (xor7(a / PAGE) == target) pages[n++] = (volatile char *)a;
    if (n < NPAGES) return 2;

    for (int i = 0; i < NPAGES; i++) pages[i][0] = 'A';      // warm-up / first touch

    volatile int sum = 0;                                     // no syscalls below
    for (int p = 0; p < PASSES; p++)
        for (int i = 0; i < NPAGES; i++) sum += pages[i][0];

    printf("conflict: set=%u pages=%d passes=%d sum=%d\n", target, n, PASSES, sum);
    return 0;
}
