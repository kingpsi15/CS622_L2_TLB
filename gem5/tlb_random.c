// Workload: RANDOM access over a footprint larger than the L2 (1024 pages > 512)
// Deterministic LCG so every configuration sees the identical address stream.
// Neither spatial prefetcher should help much here (no locality).
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define PAGE     4096UL
#define NPAGES   1024
#define ACCESSES 20000

int main(void) {
    char *arr = (char *)malloc(NPAGES * PAGE);
    if (!arr) return 1;
    for (int i = 0; i < NPAGES; i++) arr[i * PAGE] = 'A';     // warm-up / first touch

    volatile int sum = 0;                                      // no syscalls below
    uint32_t x = 12345;
    for (int k = 0; k < ACCESSES; k++) {
        x = x * 1103515245u + 12345u;
        sum += arr[((x >> 8) % NPAGES) * PAGE];
    }
    printf("random: pages=%d accesses=%d sum=%d\n", NPAGES, ACCESSES, sum);
    return 0;
}
