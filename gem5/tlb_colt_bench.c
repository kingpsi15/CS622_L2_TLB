// Workload: CLUSTERED ACCESS (Replicating CoLT evaluation)
// Allocates a memory footprint larger than L2 TLB (e.g. 2048 pages = 8MB > 512 entries).
// Accesses pages in clusters of 4 to 8 consecutive pages (temporal spatial locality),
// jumping across strides. This matches the memory reference patterns of SPEC mcf/cactusADM
// where intermediate contiguity naturally arises and is touched consecutively.
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#define PAGE       4096UL
#define TOTAL_PAGES 2048
#define CLUSTER_LEN 8
#define STRIDE_JUMP 37
#define PASSES     5

int main(void) {
    char *arr = (char *)malloc(TOTAL_PAGES * PAGE);
    if (!arr) return 1;

    // First touch / initialization
    for (int i = 0; i < TOTAL_PAGES; i++) {
        arr[i * PAGE] = 'A';
    }

    // Access loop: visit clusters of CLUSTER_LEN consecutive pages
    // with pseudo-random / strided jumps across clusters
    volatile int sum = 0;
    for (int p = 0; p < PASSES; p++) {
        int cluster_idx = 0;
        for (int step = 0; step < (TOTAL_PAGES / CLUSTER_LEN); step++) {
            int start_page = (cluster_idx % (TOTAL_PAGES / CLUSTER_LEN)) * CLUSTER_LEN;
            for (int k = 0; k < CLUSTER_LEN; k++) {
                sum += arr[(start_page + k) * PAGE];
            }
            cluster_idx += STRIDE_JUMP;
        }
    }

    printf("colt_bench: pages=%d passes=%d sum=%d\n", TOTAL_PAGES, PASSES, sum);
    free(arr);
    return 0;
}
