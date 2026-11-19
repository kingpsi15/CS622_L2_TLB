#include <stdio.h>
#include <stdlib.h>

#define PAGE_SIZE 4096
#define NUM_PAGES 600 // More than L2 size (512)

int main() {
    size_t array_size = NUM_PAGES * PAGE_SIZE;
    char *arr = (char *)malloc(array_size);
    if (!arr) return 1;

    // Loop 1: Thrash L2 (will cause L2 to evict!)
    for (int i = 0; i < NUM_PAGES; i++) {
        arr[i * PAGE_SIZE] = 'A';
    }

    free(arr);
    return 0;
}
