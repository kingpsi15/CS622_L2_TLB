/*
 * perf_holes.c - Perforated-Pages robustness test with REAL holes (munmap of single 4 KiB
 * pages inside 2 MiB-aligned regions) and late remaps.  Works in gem5 SE and natively.
 * usage: perf_holes <pattern> [regions=4] [passes=6]
 *   patterns: dense | edge | clustered | dispersed | chunk1 | sparse | churn
 * Valid pages must always read back their tag (stale/foreign frame => FAIL); a hole is
 * never touched (SE mode kills the process on a fault) but is later re-mapped with a NEW
 * tag, which a stale 2 MiB perforated entry/bitmap would still translate to the old frame.
 * Output: RESULT perf_<pattern> PASS|FAIL details
 */
#define _GNU_SOURCE
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>

#define PG 4096UL
#define HUGE (2UL << 20)
#define NP 512

static uint64_t tag(uint64_t r, uint64_t i, uint64_t gen)
{
    uint64_t x = (r << 48) ^ (i << 16) ^ gen ^ 0x9e3779b97f4a7c15ULL;
    x ^= x >> 31; x *= 0xd1b54a32d192ed03ULL; x ^= x >> 29;
    return x | 1;
}

static const char *pat;
static int fail;
#define FAILF(...) do { printf("RESULT perf_%s FAIL ", pat); printf(__VA_ARGS__); printf("\n"); fail = 1; return 1; } while (0)

static int is_hole(const char *p, unsigned i, unsigned r)
{
    static const unsigned edge[] = {0, 31, 32, 63, 64, 127, 448, 511};
    if (!strcmp(p, "dense")) return 0;
    if (!strcmp(p, "edge")) { for (unsigned k = 0; k < 8; k++) if (edge[k] == i) return 1; return 0; }
    if (!strcmp(p, "clustered")) return i >= 100 + (r % 4) * 16 && i < 164 + (r % 4) * 16;  /* 64 holes in a row */
    if (!strcmp(p, "dispersed")) return (i % 8) == (r % 8);                                 /* 64 holes spread */
    if (!strcmp(p, "chunk1")) return (i % 64) == 17;                                        /* one hole per 64-page chunk */
    if (!strcmp(p, "sparse")) return (i % 64) != 0;                                         /* one valid page per chunk */
    if (!strcmp(p, "churn")) return (i * 7 + r) % 5 == 0;
    return 0;
}

int main(int argc, char **argv)
{
    pat = argc > 1 ? argv[1] : "edge";
    unsigned regions = argc > 2 ? atoi(argv[2]) : 4;
    unsigned passes = argc > 3 ? atoi(argv[3]) : 6;
    if (regions < 1 || regions > 64) return 2;
    size_t len = ((size_t)regions + 1) * HUGE;
    char *raw = mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (raw == MAP_FAILED) { perror("mmap"); return 2; }
    char *base = (char *)(((uintptr_t)raw + HUGE - 1) & ~(HUGE - 1));
    static uint8_t valid[64][NP];
    static uint64_t gen[64][NP];
    unsigned nvalid = 0, nhole = 0, remaps = 0, unmaps = 0;

    for (unsigned r = 0; r < regions; r++)
        for (unsigned i = 0; i < NP; i++) {
            volatile uint64_t *p = (volatile uint64_t *)(base + r * HUGE + i * PG);
            *p = tag(r, i, 0); valid[r][i] = 1; gen[r][i] = 0;
        }
    for (unsigned r = 0; r < regions; r++)             /* punch real holes */
        for (unsigned i = 0; i < NP; i++)
            if (is_hole(pat, i, r)) {
                if (munmap(base + r * HUGE + i * PG, PG)) { perror("munmap"); return 2; }
                valid[r][i] = 0; nhole++;
            }

    for (unsigned pass = 0; pass < passes; pass++) {
        /* several access orders so entries are (re)built from different first-touch pages */
        for (unsigned ord = 0; ord < 3; ord++)
            for (unsigned rr = 0; rr < regions; rr++) {
                unsigned r = ord == 1 ? regions - 1 - rr : rr;
                for (unsigned k = 0; k < NP; k++) {
                    unsigned i = ord == 0 ? k : ord == 1 ? NP - 1 - k : (k * 37 + pass) % NP;
                    if (!valid[r][i]) continue;
                    volatile uint64_t *p = (volatile uint64_t *)(base + r * HUGE + i * PG);
                    uint64_t v = *p;
                    if (v != tag(r, i, gen[r][i]))
                        FAILF("pass %u region %u page %u va %p got %#" PRIx64 " want %#" PRIx64 " (stale/foreign translation)",
                              pass, r, i, (void *)p, v, tag(r, i, gen[r][i]));
                    nvalid++;
                }
            }
        /* late map/unmap while the region entry/bitmap is cached */
        for (unsigned r = 0; r < regions; r++) {
            unsigned filled = 0, cut = 0;
            for (unsigned i = (pass * 13 + r) % NP, n = 0; n < NP && (filled < 3 || cut < 3); i = (i + 29) % NP, n++) {
                char *a = base + r * HUGE + i * PG;
                if (!valid[r][i] && filled < 3) {            /* re-map a hole with NEW data */
                    if (mmap(a, PG, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0) != a)
                        { perror("mmap fixed"); return 2; }
                    gen[r][i] = pass + 1;
                    *(volatile uint64_t *)a = tag(r, i, gen[r][i]);
                    valid[r][i] = 1; filled++; remaps++;
                } else if (valid[r][i] && cut < 3 && !strcmp(pat, "churn")) {   /* new hole in a populated chunk */
                    if (munmap(a, PG)) { perror("munmap"); return 2; }
                    valid[r][i] = 0; cut++; unmaps++;
                }
            }
        }
    }
    printf("RESULT perf_%s PASS regions=%u passes=%u holes=%u valid_reads=%u remaps=%u late_unmaps=%u\n",
           pat, regions, passes, nhole, nvalid, remaps, unmaps);
    return fail;
}
