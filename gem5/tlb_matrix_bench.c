#define _GNU_SOURCE
#include <errno.h>
#include <inttypes.h>
#include <setjmp.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

static sigjmp_buf fault_env;
static volatile sig_atomic_t expect_fault;

static void
fault_handler(int signal_number)
{
    if (expect_fault)
        siglongjmp(fault_env, signal_number);
    _exit(128 + signal_number);
}

static uint64_t
page_value(uint64_t seed, size_t page)
{
    return UINT64_C(0x9e3779b97f4a7c15) * (seed + 1) ^
           (UINT64_C(0xd1b54a32d192ed03) * (page + 1));
}

static int
check_args(int argc, char **argv, size_t *pages, size_t *passes)
{
    char *end = NULL;
    unsigned long parsed;

    if (argc < 3)
        return -1;
    parsed = strtoul(argv[2], &end, 0);
    if (!end || *end != '\0' || parsed == 0 || parsed > 16384)
        return -1;
    *pages = parsed;
    *passes = 1;
    if (argc > 3) {
        end = NULL;
        parsed = strtoul(argv[3], &end, 0);
        if (!end || *end != '\0' || parsed == 0 || parsed > 100)
            return -1;
        *passes = parsed;
    }
    return 0;
}

static int
run_data_pattern(const char *mode, size_t pages, size_t passes,
                 uint64_t seed)
{
    size_t bytes = pages * (size_t)sysconf(_SC_PAGESIZE);
    volatile uint64_t *memory = mmap(NULL, bytes, PROT_READ | PROT_WRITE,
        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (memory == MAP_FAILED) {
        perror("mmap");
        return 1;
    }

    printf("case=%s pages=%zu passes=%zu base=%p seed=%" PRIu64 "\n",
           mode, pages, passes, (void *)memory, seed);
    for (size_t page = 0; page < pages; ++page)
        memory[page * (size_t)sysconf(_SC_PAGESIZE) /
               sizeof(*memory)] = page_value(seed, page);

    uint64_t state = seed ? seed : 1;
    volatile uint64_t checksum = 0;
    for (size_t pass = 0; pass < passes; ++pass) {
        for (size_t n = 0; n < pages; ++n) {
            size_t page = n;
            if (strcmp(mode, "reverse") == 0) {
                page = pages - 1 - n;
            } else if (strcmp(mode, "stride") == 0) {
                page = (n * 17) % pages;
            } else if (strcmp(mode, "random") == 0) {
                state ^= state << 13;
                state ^= state >> 7;
                state ^= state << 17;
                page = state % pages;
            }

            uint64_t actual = memory[page *
                (size_t)sysconf(_SC_PAGESIZE) / sizeof(*memory)];
            uint64_t expected = page_value(seed, page);
            if (actual != expected) {
                fprintf(stderr, "FAIL case=%s pass=%zu page=%zu "
                        "expected=%#" PRIx64 " actual=%#" PRIx64 "\n",
                        mode, pass, page, expected, actual);
                munmap((void *)memory, bytes);
                return 1;
            }
            checksum += actual;
        }
    }
    printf("PASS case=%s checksum=%" PRIu64 "\n", mode, checksum);
    munmap((void *)memory, bytes);
    return 0;
}

static int
run_capacity_boundaries(void)
{
    static const size_t page_counts[] = {1, 63, 64, 65, 511, 512, 513};
    for (size_t i = 0; i < sizeof(page_counts) / sizeof(page_counts[0]); ++i) {
        if (run_data_pattern("boundary", page_counts[i], 2, i + 1) != 0)
            return 1;
    }
    puts("PASS case=capacity-boundaries");
    return 0;
}

static int
run_prefetch_offsets(void)
{
    const size_t page_size = (size_t)sysconf(_SC_PAGESIZE);
    const size_t pages = 64;
    volatile uint64_t *memory = mmap(NULL, pages * page_size,
        PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (memory == MAP_FAILED) {
        perror("mmap");
        return 1;
    }

    size_t words_per_page = page_size / sizeof(*memory);
    for (size_t offset = 0; offset < 8; ++offset) {
        size_t group = offset * 8;
        uint64_t expected[8];
        for (size_t step = 0; step < 8; ++step) {
            size_t page = group + ((offset + step) % 8);
            expected[step] = page_value(offset + 1, page);
            memory[page * words_per_page] = expected[step];
        }
        for (size_t step = 0; step < 8; ++step) {
            size_t page = group + ((offset + step) % 8);
            uint64_t actual = memory[page * words_per_page];
            if (actual != expected[step]) {
                fprintf(stderr, "FAIL prefetch-offset offset=%zu page=%zu\n",
                        offset, page);
                munmap((void *)memory, pages * page_size);
                return 1;
            }
        }
    }
    munmap((void *)memory, pages * page_size);
    puts("PASS case=prefetch-offsets positions=0..7");
    return 0;
}

static int
page_is_valid(const char *pattern, size_t page)
{
    if (strcmp(pattern, "dense") == 0)
        return 1;
    if (strcmp(pattern, "clustered") == 0)
        return page < 384;
    if (strcmp(pattern, "dispersed") == 0)
        return page % 4 != 0;
    if (strcmp(pattern, "one-per-chunk") == 0)
        return page % 64 == 0;
    if (strcmp(pattern, "boundary") == 0)
        return page != 63 && page != 64 && page != 127 && page != 128 &&
               page != 255 && page != 256 && page != 447 && page != 448;
    if (strcmp(pattern, "empty") == 0)
        return 0;
    return -1;
}

static int
run_sparse_region(const char *pattern, size_t passes)
{
    const size_t page_size = (size_t)sysconf(_SC_PAGESIZE);
    const size_t region_size = 512 * page_size;
    const size_t reserve_size = 2 * region_size;
    if (page_size != 4096) {
        fprintf(stderr, "FAIL sparse-region requires 4-KiB host pages\n");
        return 1;
    }

    unsigned char *reserve = mmap(NULL, reserve_size,
        PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (reserve == MAP_FAILED) {
        perror("mmap");
        return 1;
    }
    uintptr_t base_value = ((uintptr_t)reserve + region_size - 1) &
                           ~(uintptr_t)(region_size - 1);
    unsigned char *base = (unsigned char *)base_value;
    size_t prefix = base - reserve;
    size_t suffix = reserve_size - prefix - region_size;
    if (prefix && munmap(reserve, prefix) != 0) {
        perror("munmap prefix");
        munmap(reserve, reserve_size);
        return 1;
    }
    if (suffix && munmap(base + region_size, suffix) != 0) {
        perror("munmap suffix");
        munmap(base, region_size);
        return 1;
    }

    size_t valid_pages = 0;
    size_t first_hole = 512;
    for (size_t page = 0; page < 512; ++page) {
        int valid = page_is_valid(pattern, page);
        if (valid < 0) {
            fprintf(stderr, "unknown sparse pattern: %s\n", pattern);
            munmap(base, region_size);
            return 2;
        }
        if (!valid) {
            if (first_hole == 512)
                first_hole = page;
            if (munmap(base + page * page_size, page_size) != 0) {
                perror("munmap hole");
                munmap(base, region_size);
                return 1;
            }
        } else {
            ++valid_pages;
            *(volatile uint64_t *)(base + page * page_size) =
                page_value(17, page);
        }
    }
    printf("case=perforated pattern=%s base=%p valid_pages=%zu "
           "passes=%zu\n", pattern, (void *)base, valid_pages, passes);

    volatile uint64_t checksum = 0;
    for (size_t pass = 0; pass < passes; ++pass) {
        for (size_t page = 0; page < 512; ++page) {
            if (!page_is_valid(pattern, page))
                continue;
            uint64_t actual = *(volatile uint64_t *)(base + page * page_size);
            uint64_t expected = page_value(17, page);
            if (actual != expected) {
                fprintf(stderr, "FAIL perforated pattern=%s pass=%zu "
                        "page=%zu expected=%#" PRIx64 " actual=%#" PRIx64
                        "\n", pattern, pass, page, expected, actual);
                munmap(base, region_size);
                return 1;
            }
            checksum += actual;
        }
    }

    if (first_hole != 512) {
        struct sigaction action = {0};
        struct sigaction previous;
        action.sa_handler = fault_handler;
        sigemptyset(&action.sa_mask);
        if (sigaction(SIGSEGV, &action, &previous) != 0) {
            perror("sigaction");
            munmap(base, region_size);
            return 1;
        }
        expect_fault = 1;
        int fault_signal = sigsetjmp(fault_env, 1);
        if (fault_signal == 0) {
            volatile uint64_t value = *(volatile uint64_t *)(
                base + first_hole * page_size);
            (void)value;
            expect_fault = 0;
            fprintf(stderr, "FAIL perforated hole access succeeded "
                    "pattern=%s page=%zu\n", pattern, first_hole);
            sigaction(SIGSEGV, &previous, NULL);
            munmap(base, region_size);
            return 1;
        }
        expect_fault = 0;
        sigaction(SIGSEGV, &previous, NULL);
        if (fault_signal != SIGSEGV) {
            fprintf(stderr, "FAIL perforated expected SIGSEGV, got %d\n",
                    fault_signal);
            munmap(base, region_size);
            return 1;
        }
    }
    munmap(base, region_size);
    printf("PASS perforated pattern=%s checksum=%" PRIu64
           " hole_fault=%s\n", pattern, checksum,
           first_hole == 512 ? "not-applicable" : "SIGSEGV");
    return 0;
}

static int
run_hole_fault(void)
{
    const size_t page_size = (size_t)sysconf(_SC_PAGESIZE);
    size_t bytes = 3 * page_size;
    volatile unsigned char *region = mmap(NULL, bytes,
        PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (region == MAP_FAILED) {
        perror("mmap");
        return 1;
    }
    region[0] = 0x31;
    region[2 * page_size] = 0x73;
    if (munmap((void *)(region + page_size), page_size) != 0) {
        perror("munmap");
        munmap((void *)region, bytes);
        return 1;
    }

    struct sigaction action = {0};
    struct sigaction previous;
    action.sa_handler = fault_handler;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGSEGV, &action, &previous) != 0) {
        perror("sigaction");
        munmap((void *)region, bytes);
        return 1;
    }

    expect_fault = 1;
    int fault_signal = sigsetjmp(fault_env, 1);
    if (fault_signal == 0) {
        volatile unsigned char value = region[page_size];
        (void)value;
        expect_fault = 0;
        fprintf(stderr, "FAIL case=hole-fault unmapped access succeeded\n");
        sigaction(SIGSEGV, &previous, NULL);
        munmap((void *)region, page_size);
        munmap((void *)(region + 2 * page_size), page_size);
        return 1;
    }
    expect_fault = 0;
    if (fault_signal != SIGSEGV || region[0] != 0x31 ||
        region[2 * page_size] != 0x73) {
        fprintf(stderr, "FAIL case=hole-fault signal=%d\n", fault_signal);
        sigaction(SIGSEGV, &previous, NULL);
        munmap((void *)region, page_size);
        munmap((void *)(region + 2 * page_size), page_size);
        return 1;
    }

    sigaction(SIGSEGV, &previous, NULL);
    munmap((void *)region, page_size);
    munmap((void *)(region + 2 * page_size), page_size);
    puts("PASS case=hole-fault signal=SIGSEGV");
    return 0;
}

static int
run_remap(void)
{
    const size_t page_size = (size_t)sysconf(_SC_PAGESIZE);
    volatile uint64_t *first = mmap(NULL, page_size,
        PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (first == MAP_FAILED) {
        perror("mmap");
        return 1;
    }
    void *base = (void *)first;
    first[0] = UINT64_C(0x1122334455667788);
    if (first[0] != UINT64_C(0x1122334455667788) ||
        munmap(base, page_size) != 0) {
        perror("initial mapping");
        return 1;
    }

    volatile uint64_t *second = mmap(base, page_size,
        PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED,
        -1, 0);
    if (second == MAP_FAILED) {
        perror("fixed remap");
        return 1;
    }
    if ((void *)second != base) {
        fprintf(stderr, "FAIL case=remap base changed\n");
        munmap((void *)second, page_size);
        return 1;
    }
    second[0] = UINT64_C(0xa5a5c3c35a5a3c3c);
    if (second[0] != UINT64_C(0xa5a5c3c35a5a3c3c)) {
        fprintf(stderr, "FAIL case=remap stale translation/data\n");
        munmap((void *)second, page_size);
        return 1;
    }
    munmap((void *)second, page_size);
    puts("PASS case=remap same-VA");
    return 0;
}

static int
run_protection(void)
{
    const size_t page_size = (size_t)sysconf(_SC_PAGESIZE);
    volatile uint64_t *memory = mmap(NULL, page_size,
        PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (memory == MAP_FAILED) {
        perror("mmap");
        return 1;
    }
    memory[0] = UINT64_C(0x123456789abcdef0);
    if (mprotect((void *)memory, page_size, PROT_READ) != 0) {
        perror("mprotect read-only");
        munmap((void *)memory, page_size);
        return 1;
    }

    struct sigaction action = {0};
    struct sigaction previous;
    action.sa_handler = fault_handler;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGSEGV, &action, &previous) != 0) {
        perror("sigaction");
        munmap((void *)memory, page_size);
        return 1;
    }

    expect_fault = 1;
    int fault_signal = sigsetjmp(fault_env, 1);
    if (fault_signal == 0) {
        memory[0] = UINT64_C(0xfedcba9876543210);
        expect_fault = 0;
        fprintf(stderr, "FAIL case=protection read-only write succeeded\n");
        sigaction(SIGSEGV, &previous, NULL);
        munmap((void *)memory, page_size);
        return 1;
    }
    expect_fault = 0;

    if (mprotect((void *)memory, page_size, PROT_READ | PROT_WRITE) != 0) {
        perror("mprotect read-write");
        sigaction(SIGSEGV, &previous, NULL);
        munmap((void *)memory, page_size);
        return 1;
    }
    sigaction(SIGSEGV, &previous, NULL);
    if (fault_signal != SIGSEGV ||
        memory[0] != UINT64_C(0x123456789abcdef0)) {
        fprintf(stderr, "FAIL case=protection signal=%d\n", fault_signal);
        munmap((void *)memory, page_size);
        return 1;
    }
    munmap((void *)memory, page_size);
    puts("PASS case=protection read-only");
    return 0;
}

int
main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "usage: %s CASE [PAGES [PASSES [SEED]]]\n", argv[0]);
        return 2;
    }

    if (strcmp(argv[1], "boundaries") == 0)
        return run_capacity_boundaries();
    if (strcmp(argv[1], "prefetch-offsets") == 0)
        return run_prefetch_offsets();
    if (strcmp(argv[1], "hole") == 0)
        return run_hole_fault();
    if (strcmp(argv[1], "remap") == 0)
        return run_remap();
    if (strcmp(argv[1], "protection") == 0)
        return run_protection();
    if (strcmp(argv[1], "perforated") == 0) {
        if (argc < 3) {
            fprintf(stderr, "usage: %s perforated PATTERN [PASSES]\n",
                    argv[0]);
            return 2;
        }
        size_t passes = 2;
        if (argc > 3) {
            char *end = NULL;
            unsigned long parsed = strtoul(argv[3], &end, 0);
            if (!end || *end != '\0' || parsed == 0 || parsed > 20) {
                fprintf(stderr, "passes must be 1..20\n");
                return 2;
            }
            passes = parsed;
        }
        return run_sparse_region(argv[2], passes);
    }

    size_t pages;
    size_t passes;
    if (check_args(argc, argv, &pages, &passes) != 0) {
        fprintf(stderr, "pages must be 1..16384; passes must be 1..100\n");
        return 2;
    }
    uint64_t seed = 1;
    if (argc > 4) {
        char *end = NULL;
        errno = 0;
        if (argv[4][0] == '-') {
            fprintf(stderr, "seed must be a non-zero integer\n");
            return 2;
        }
        seed = strtoull(argv[4], &end, 0);
        if (errno == ERANGE || !end || *end != '\0' || seed == 0) {
            fprintf(stderr, "seed must be a non-zero integer\n");
            return 2;
        }
    }
    if (strcmp(argv[1], "linear") != 0 &&
        strcmp(argv[1], "reverse") != 0 &&
        strcmp(argv[1], "stride") != 0 &&
        strcmp(argv[1], "random") != 0) {
        fprintf(stderr, "unknown case: %s\n", argv[1]);
        return 2;
    }
    return run_data_pattern(argv[1], pages, passes, seed);
}
