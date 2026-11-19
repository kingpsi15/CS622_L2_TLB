#include <stdio.h>
#include <stdlib.h>

#define PAGE_SIZE 4096
#define NUM_PAGES 200

int main() {
    size_t array_size = NUM_PAGES * PAGE_SIZE;
    char *arr = (char *)malloc(array_size);
    if (!arr) return 1;

    // Loop 1
    for (int i = 0; i < NUM_PAGES; i++) arr[i * PAGE_SIZE] = 'A';

    // Loop 2, 3, 4 without ANY syscalls
    volatile int sum1 = 0;
    for (int i = 0; i < NUM_PAGES; i++) sum1 += arr[i * PAGE_SIZE];
    
    volatile int sum2 = 0;
    for (int i = 0; i < NUM_PAGES; i++) sum2 += arr[i * PAGE_SIZE];

    volatile int sum3 = 0;
    for (int i = 0; i < NUM_PAGES; i++) sum3 += arr[i * PAGE_SIZE];

    // Force usage so it doesn't get optimized out
    printf("Sum1: %d, Sum2: %d, Sum3: %d\n", sum1, sum2, sum3);

    free(arr);
    return 0;
}
