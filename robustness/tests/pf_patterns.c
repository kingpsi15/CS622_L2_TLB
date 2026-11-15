/* pf_patterns.c - access-pattern workloads for TLB prefetcher (Agile) evaluation; self-checking.
 * usage: pf_patterns <asc|desc|s2|s4|s8|s16|random|chase|hotcold> [pages=2048] [passes=4] */
#define _GNU_SOURCE
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#define PG 4096UL
static uint64_t tag(size_t i, unsigned p) { uint64_t x = (i + 1) * 0x9e3779b97f4a7c15ULL ^ p; x ^= x >> 29; return x | 1; }
int main(int argc, char **argv)
{
    const char *pat = argc > 1 ? argv[1] : "asc";
    size_t n = argc > 2 ? strtoul(argv[2], 0, 0) : 2048;
    unsigned passes = argc > 3 ? atoi(argv[3]) : 4;
    char *b = mmap(0, n * PG, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (b == MAP_FAILED) return 2;
    size_t *perm = malloc(n * sizeof *perm);
    for (size_t i = 0; i < n; i++) { perm[i] = i; *(volatile uint64_t *)(b + i * PG) = tag(i, 0); }
    uint64_t s = 88172645463325252ULL;
    for (size_t i = n - 1; i > 0; i--) { s ^= s << 13; s ^= s >> 7; s ^= s << 17; size_t j = s % (i + 1); size_t t = perm[i]; perm[i] = perm[j]; perm[j] = t; }
    unsigned stride = !strcmp(pat, "s2") ? 2 : !strcmp(pat, "s4") ? 4 : !strcmp(pat, "s8") ? 8 : !strcmp(pat, "s16") ? 16 : 1;
    uint64_t acc = 0; size_t reads = 0;
    for (unsigned p = 0; p < passes; p++) {
        size_t cur = 0;
        for (size_t k = 0; k < n; k++) {
            size_t i;
            if (!strcmp(pat, "desc")) i = n - 1 - k;
            else if (!strcmp(pat, "random") || !strcmp(pat, "chase")) i = perm[k];
            else if (!strcmp(pat, "hotcold")) i = (k & 1) ? (k / 2) % 16 : perm[k];   /* 16 hot pages interleaved with random cold */
            else i = (k * stride) % n;
            uint64_t v = *(volatile uint64_t *)(b + i * PG);
            if (v != tag(i, 0)) { printf("RESULT pf_%s FAIL page %zu got %#" PRIx64 "\n", pat, i, v); return 1; }
            acc += v; reads++; (void)cur;
        }
    }
    printf("RESULT pf_%s PASS pages=%zu passes=%u reads=%zu sum=%#" PRIx64 "\n", pat, n, passes, reads, acc);
    return 0;
}
