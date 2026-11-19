/* GUPS-style random update: hops to a random 8-byte word anywhere in a large
 * table on every access, so nearly every access lands on a different page.
 * usage: gups [table_MB=512] [updates_M=4] */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
int main(int argc, char **argv)
{
    size_t mb = argc > 1 ? strtoul(argv[1], 0, 0) : 512;
    size_t upd = (argc > 2 ? strtoul(argv[2], 0, 0) : 4) * 1000000UL;
    size_t n = mb * (1UL << 20) / sizeof(uint64_t);
    uint64_t *t = malloc(n * sizeof(uint64_t));
    if (!t) { printf("RESULT gups FAIL malloc\n"); return 1; }
    for (size_t i = 0; i < n; i++) t[i] = i;
    uint64_t x = 0x9E3779B97F4A7C15ULL, sum = 0;
    for (size_t i = 0; i < upd; i++) {
        x ^= x << 13; x ^= x >> 7; x ^= x << 17;     /* xorshift64 */
        t[x % n] ^= x;
    }
    for (size_t i = 0; i < n; i += 4096) sum += t[i];
    printf("RESULT gups PASS mb=%zu updates=%zu sum=%llu\n", mb, upd, (unsigned long long)sum);
    return 0;
}
