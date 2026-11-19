#include <stdio.h>
#include <stdlib.h>

#define PAGE_SIZE 4096
#define NUM_PAGES 200 // More than L1 (64), less than L2 (512)

int main() {
    printf("Starting TLB test...\n");
    
    // Allocate enough memory to span NUM_PAGES pages
    size_t array_size = NUM_PAGES * PAGE_SIZE;
    char *arr = (char *)malloc(array_size);

    if (arr == NULL) {
        printf("Malloc failed\n");
        return 1;
    }

    // Pass 1: Write to one byte in each page to load them into the TLB.
    // This will cause L1 and L2 misses, loading all 200 pages into L2.
    // But the L1 (64 entries) will start evicting the oldest pages!
    for (int i = 0; i < NUM_PAGES; i++) {
        arr[i * PAGE_SIZE] = 'A';
    }

    // Pass 2: Read from the first page again.
    // Since the L1 only holds 64 pages, the first page was evicted a long time ago.
    // However, the L2 holds 512 pages, so it should still be in the L2!
    // This access MUST trigger an L2 TLB HIT!
    int sum = 0;
    for (int i = 0; i < NUM_PAGES; i++) {
        sum += arr[i * PAGE_SIZE];
    }

    printf("TLB test complete! Sum: %d\n", sum);
    free(arr);
    return 0;
}
