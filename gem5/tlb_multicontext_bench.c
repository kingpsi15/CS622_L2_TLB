#define _GNU_SOURCE
#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

enum {
    PageSize = 4096,
    DefaultPages = 768,
    Passes = 4,
    MaxPages = 4096
};

static uint64_t
value_for(uint64_t seed, size_t page)
{
    return UINT64_C(0x9e3779b97f4a7c15) * (seed + 1) ^
           (UINT64_C(0xd1b54a32d192ed03) * (page + 1));
}

int
main(int argc, char **argv)
{
    char *end = NULL;
    uint64_t seed = argc > 1 ? strtoull(argv[1], &end, 0) : 1;
    if ((argc > 1 && (!end || *end != '\0')) || seed == 0) {
        fprintf(stderr, "seed must be a non-zero integer\n");
        return 2;
    }

    end = NULL;
    size_t pages = argc > 2 ? strtoul(argv[2], &end, 0) : DefaultPages;
    if ((argc > 2 && (!end || *end != '\0')) ||
        pages < 65 || pages > MaxPages) {
        fprintf(stderr, "pages must be between 65 and %d\n", MaxPages);
        return 2;
    }

    size_t bytes = pages * PageSize;
    volatile uint64_t *memory = mmap(NULL, bytes, PROT_READ | PROT_WRITE,
                                     MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (memory == MAP_FAILED) {
        perror("mmap");
        return 1;
    }

    printf("seed=%" PRIu64 " pages=%zu base=%p passes=%d\n",
           seed, pages, (void *)memory, Passes);
    for (size_t pass = 0; pass < Passes; ++pass) {
        for (size_t page = 0; page < pages; ++page)
            memory[page * PageSize / sizeof(*memory)] =
                value_for(seed, page);

        for (size_t page = 0; page < pages; ++page) {
            uint64_t actual = memory[page * PageSize / sizeof(*memory)];
            if (actual != value_for(seed, page)) {
                fprintf(stderr,
                        "FAIL seed=%" PRIu64 " pass=%zu page=%zu "
                        "expected=%#" PRIx64 " actual=%#" PRIx64 "\n",
                        seed, pass, page, value_for(seed, page), actual);
                munmap((void *)memory, bytes);
                return 1;
            }
        }
    }

    printf("PASS seed=%" PRIu64 " pages=%zu\n", seed, pages);
    munmap((void *)memory, bytes);
    return 0;
}
