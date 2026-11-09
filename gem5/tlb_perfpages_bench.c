// Workload: FRAGMENTED MEMORY (Replicating Perforated Pages evaluation)
// In a fragmented memory scenario, 2MB regions have 4KB "holes" (e.g. 15% to 25% holes).
// The benchmark iterates repeatedly over an allocated region of 16 huge-page chunks (32MB),
// touching only the valid pages within each 2MB region.
// Under standard systems, having holes prevents 2MB superpages, forcing 4KB entries that thrash L2.
// Under Perforated Pages, the 2MB huge page reach is retained despite the holes.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define PAGE          4096UL
#define PAGES_PER_2MB 512
#define NUM_REGIONS   16
#define PASSES        5

int main(void) {
    size_t total_pages = NUM_REGIONS * PAGES_PER_2MB;
    char *arr = NULL;
    if (posix_memalign((void **)&arr, PAGES_PER_2MB * PAGE,
                       total_pages * PAGE) != 0) {
        return 1;
    }

    // Pattern: 25% holes (clustered holes in each 2MB chunk)
    // Pages 0..383 are valid allocated pages, pages 384..511 are unmovable holes (skipped)
    for (int r = 0; r < NUM_REGIONS; r++) {
        for (int p = 0; p < 384; p++) {
            arr[(r * PAGES_PER_2MB + p) * PAGE] = 'B';
        }
    }

    volatile int sum = 0;
    for (int pass = 0; pass < PASSES; pass++) {
        for (int r = 0; r < NUM_REGIONS; r++) {
            for (int p = 0; p < 384; p += 4) { // stride through valid pages
                sum += arr[(r * PAGES_PER_2MB + p) * PAGE];
            }
        }
    }

    printf("perfpages_bench: regions=%d valid_pages=%d passes=%d sum=%d\n",
           NUM_REGIONS, NUM_REGIONS * 384, PASSES, sum);
    free(arr);
    return 0;
}
