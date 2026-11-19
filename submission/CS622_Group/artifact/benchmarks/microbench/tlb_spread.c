// Workload: CONTROL for tlb_conflict.c
// Same number of pages / passes / access order, but every page is chosen
// so that it maps to a DIFFERENT xor_7 L2 set (no set conflicts).
// L1 still thrashes (80 > 64), but the L2 should serve all re-accesses.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define PAGE   4096UL
#define NPAGES 80
#define PASSES 10
#define WINDOW 1024UL

static unsigned xor7(uint64_t vpn) { return ((vpn >> 7) & 0x7F) ^ (vpn & 0x7F); }

static volatile char *pages[NPAGES];
static unsigned char used[128];

int main(void) {
    char *region = (char *)malloc(WINDOW * PAGE);
    if (!region) return 1;
    uint64_t first = ((uint64_t)region + PAGE - 1) & ~(PAGE - 1);

    int n = 0;
    for (uint64_t a = first; n < NPAGES && a < (uint64_t)region + WINDOW * PAGE; a += PAGE) {
        unsigned s = xor7(a / PAGE);
        if (!used[s]) { used[s] = 1; pages[n++] = (volatile char *)a; }
    }
    if (n < NPAGES) return 2;

    for (int i = 0; i < NPAGES; i++) pages[i][0] = 'A';      // warm-up / first touch

    volatile int sum = 0;                                     // no syscalls below
    for (int p = 0; p < PASSES; p++)
        for (int i = 0; i < NPAGES; i++) sum += pages[i][0];

    printf("spread: pages=%d passes=%d sum=%d\n", n, PASSES, sum);
    return 0;
}
