#include <stdio.h>
#include <stdlib.h>

#define PAGE_SIZE 4096
#define NUM_PAGES 200

int main() {
    size_t array_size = NUM_PAGES * PAGE_SIZE;
    char *arr = (char *)malloc(array_size);

    if (arr == NULL) {
        return 1;
    }

    // Pass 1: Warm up L1 and L2
    for (int i = 0; i < NUM_PAGES; i++) {
        arr[i * PAGE_SIZE] = 'A';
    }

    // Pass 2: Thrash L1, should hit L2!
    volatile int sum1 = 0;
    for (int i = 0; i < NUM_PAGES; i++) {
        sum1 += arr[i * PAGE_SIZE];
    }

    // Pass 3: Thrash L1 again, should hit L2!
    volatile int sum2 = 0;
    for (int i = 0; i < NUM_PAGES; i++) {
        sum2 += arr[i * PAGE_SIZE];
    }

    free(arr);
    return 0;
}
