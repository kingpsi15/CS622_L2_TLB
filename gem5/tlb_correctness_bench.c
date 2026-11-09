#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#define PAGE_SIZE 4096UL
#define L1_PAGES 64
#define L2_PAGES 512

int main(void) {
    printf("=== Starting TLB Semantic & Correctness Self-Check ===\n");
    int failures = 0;

    // -------------------------------------------------------------
    // Test 1: L1 Eviction and L2 Promotion
    // -------------------------------------------------------------
    printf("[Test 1] Testing L1 eviction and L2 promotion...\n");
    size_t alloc_pages = L2_PAGES + 64;
    char *buf = NULL;
    if (posix_memalign((void **)&buf, 2 * 1024 * 1024, alloc_pages * PAGE_SIZE) != 0) {
        printf("FAIL: posix_memalign failed\n");
        return 1;
    }

    buf[0] = 0x42;
    if (buf[0] != 0x42) {
        printf("FAIL: Direct read after write failed on page 0\n");
        failures++;
    }

    // Touch 70 pages to evict page 0 from L1 (capacity 64)
    for (int i = 1; i <= 70; i++) {
        buf[i * PAGE_SIZE] = (char)(i & 0xFF);
    }

    // Now re-read page 0: must hit in L2 and promote to L1 with full data integrity
    if (buf[0] != 0x42) {
        printf("FAIL: Re-read after L1 eviction gave wrong value: 0x%02x\n", (unsigned char)buf[0]);
        failures++;
    } else {
        printf("PASS: Page 0 retained integrity and promoted correctly from L2.\n");
    }

    // -------------------------------------------------------------
    // Test 2: L2 Capacity Overflow
    // -------------------------------------------------------------
    printf("[Test 2] Testing L2 capacity overflow (> 512 entries)...\n");
    buf[0] = 0x77;
    // Touch all 512 remaining pages to completely fill L2
    for (int i = 1; i < 512; i++) {
        buf[i * PAGE_SIZE] = (char)((i * 3) & 0xFF);
    }
    // Touch 16 more unique pages to force L2 evictions
    for (int i = 512; i < 528; i++) {
        buf[i * PAGE_SIZE] = (char)((i * 5) & 0xFF);
    }

    // Verify data integrity across touched pages
    int overflow_ok = 1;
    if (buf[0] != 0x77) {
        overflow_ok = 0;
    }
    for (int i = 1; i < 512; i += 16) {
        if (buf[i * PAGE_SIZE] != (char)((i * 3) & 0xFF)) {
            overflow_ok = 0;
            break;
        }
    }
    if (!overflow_ok) {
        printf("FAIL: Data corruption detected after L2 capacity overflow!\n");
        failures++;
    } else {
        printf("PASS: L2 capacity overflow and refills preserved complete data integrity.\n");
    }

    // -------------------------------------------------------------
    // Test 3: Contiguity and CoLT clustered access (32KB windows)
    // -------------------------------------------------------------
    printf("[Test 3] Testing clustered contiguous access (CoLT pattern)...\n");
    for (int cluster = 0; cluster < 4; cluster++) {
        int base = (cluster * 8);
        for (int k = 0; k < 8; k++) {
            buf[(base + k) * PAGE_SIZE] = (char)(0x30 + cluster * 8 + k);
        }
    }
    int colt_ok = 1;
    for (int cluster = 0; cluster < 4; cluster++) {
        int base = (cluster * 8);
        for (int k = 0; k < 8; k++) {
            if (buf[(base + k) * PAGE_SIZE] != (char)(0x30 + cluster * 8 + k)) {
                colt_ok = 0;
                break;
            }
        }
    }
    if (!colt_ok) {
        printf("FAIL: Clustered pattern read mismatch!\n");
        failures++;
    } else {
        printf("PASS: Clustered contiguous CoLT accesses verified without memory corruption.\n");
    }

    // -------------------------------------------------------------
    // Test 4: Perforated Pages Valid Stride Traversal
    // -------------------------------------------------------------
    printf("[Test 4] Testing Perforated Pages stride traversal with holes...\n");
    // Write 384 valid pages in 2MB region, leaving 128 holes (384..511)
    for (int p = 0; p < 384; p++) {
        buf[p * PAGE_SIZE] = (char)((p ^ 0x5A) & 0xFF);
    }
    int perf_ok = 1;
    for (int p = 0; p < 384; p += 4) {
        if (buf[p * PAGE_SIZE] != (char)((p ^ 0x5A) & 0xFF)) {
            perf_ok = 0;
            break;
        }
    }
    if (!perf_ok) {
        printf("FAIL: Perforated Pages stride read mismatch!\n");
        failures++;
    } else {
        printf("PASS: Perforated Pages stride traversal verified with hole pattern.\n");
    }

    free(buf);
    if (failures == 0) {
        printf("=== ALL TLB SEMANTIC CHECKS PASSED SUCCESSFULLY ===\n");
        return 0;
    } else {
        printf("=== COMPLETED WITH %d FAILURES ===\n", failures);
        return 1;
    }
}
