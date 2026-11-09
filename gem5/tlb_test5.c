#include <stdio.h>
#include <stdlib.h>

#define PAGE_SIZE 4096
#define NUM_PAGES 600

int main() {
    size_t array_size = NUM_PAGES * PAGE_SIZE;
    char *arr = (char *)malloc(array_size);
    if (!arr) return 1;

    // Initialize array to avoid uninitialized read issues
    for (int i = 0; i < NUM_PAGES; i++) {
        arr[i * PAGE_SIZE] = 'A';
    }

    volatile int sum = 0;
    
    // We want arr[0] to be our TargetPage.
    // It is loaded into L1 and L2 during the initialization loop above,
    // but the initialization loop touched 600 pages, meaning arr[0] was EVICTED from L1.
    // So we first bring it back into L1 AND L2 by accessing it!
    sum += arr[0];

    // Now, we load 515 MORE unique pages to overflow L2.
    // L2 holds 512 entries.
    for (int i = 1; i <= 515; i++) {
        // Access a new page. This misses L1 and L2, and gets inserted into L2.
        sum += arr[i * PAGE_SIZE];
        
        // IMMEDIATELY access Page 0 again!
        // This hits in L1, keeping it MRU in L1.
        // Because it hits L1, L2 is NEVER queried for Page 0.
        // Therefore, Page 0's LRU timestamp in L2 gets extremely old!
        sum += arr[0];
    }

    // By the time i reaches ~512, L2 will be completely full.
    // The oldest entry in L2 will be Page 0 (because we haven't touched it in L2 since the start).
    // L2 will evict Page 0.
    // But since we kept Page 0 alive in L1 by hitting it every loop, it is still in L1!
    // This MUST trigger the "INCLUSIVE POLICY: Evicting..." back-invalidation message!

    free(arr);
    return 0;
}
