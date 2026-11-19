/*
 * tlbstress.c - self-checking TLB robustness tests (SE mode, FS guest, native).
 *
 * usage: tlbstress <test> [args]      tests: see usage() / main()
 * Every test prints exactly one line:  RESULT <test> PASS|FAIL|SKIP <details>
 * and exits 0 on PASS/SKIP, 1 on FAIL.  Data values are tagged with the
 * (pid, thread, page, generation) so a stale or cross-process translation
 * shows up as a wrong value; permission tests expect SIGSEGV via sigsetjmp.
 */
#define _GNU_SOURCE
#include <errno.h>
#include <inttypes.h>
#include <pthread.h>
#include <sched.h>
#include <setjmp.h>
#include <signal.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <sys/wait.h>
#include <unistd.h>

#define PG 4096UL
#define HUGE (2UL << 20)

static const char *g_test = "?";
static int g_fail;

static void result(const char *st, const char *fmt, ...)
    __attribute__((format(printf, 2, 3)));
static void
result(const char *st, const char *fmt, ...)
{
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    printf("RESULT %s %s %s\n", g_test, st, buf);
    fflush(stdout);
    if (!strcmp(st, "FAIL"))
        g_fail = 1;
}

static inline uint64_t
tag(uint64_t pid, uint64_t tid, uint64_t page, uint64_t gen)
{
    uint64_t x = (pid << 40) ^ (tid << 32) ^ (page << 8) ^ gen;
    x ^= x >> 31; x *= 0x9e3779b97f4a7c15ULL; x ^= x >> 29;
    return x | 1;
}

static void *
xmap(size_t len, int prot)
{
    void *p = mmap(NULL, len, prot, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (p == MAP_FAILED) { perror("mmap"); exit(2); }
    return p;
}

/* ---------- fault capture (per thread) ---------- */
static __thread sigjmp_buf t_jb;
static __thread volatile int t_armed;
static void
segv(int sig, siginfo_t *si, void *uc)
{
    (void)si; (void)uc;
    if (t_armed) { t_armed = 0; siglongjmp(t_jb, sig); }
    signal(sig, SIG_DFL); raise(sig);
}
static void
install_segv(void)
{
    struct sigaction sa;
    memset(&sa, 0, sizeof sa);
    sa.sa_sigaction = segv;
    sa.sa_flags = SA_SIGINFO | SA_NODEFER;
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
}
/* returns 1 if writing *p faulted */
static int
write_faults(volatile uint64_t *p, uint64_t v)
{
    if (sigsetjmp(t_jb, 1)) return 1;
    t_armed = 1; *p = v; t_armed = 0;
    return 0;
}
static int
read_faults(volatile uint64_t *p, uint64_t *out)
{
    if (sigsetjmp(t_jb, 1)) return 1;
    t_armed = 1; *out = *p; t_armed = 0;
    return 0;
}

/* ---------- page-set helpers ---------- */
static int
fill_verify(volatile uint64_t **pages, size_t n, int passes, uint64_t tid,
            int order)
{
    uint64_t pid = getpid();
    for (int pass = 0; pass < passes; pass++) {
        if (order >= 2) {            /* strided order: residue classes -> full permutation */
            for (size_t r = 0; r < (size_t)order; r++)
                for (size_t i = r; i < n; i += order)
                    pages[i][(i * 8) % 512] = tag(pid, tid, i, pass);
        } else {
            for (size_t k = 0; k < n; k++) {
                size_t i = order == 1 ? n - 1 - k : k;
                pages[i][(i * 8) % 512] = tag(pid, tid, i, pass);
            }
        }
        for (size_t k = 0; k < n; k++) {
            size_t i = order == 2 ? n - 1 - k : (k * 7919) % n; /* different read order */
            uint64_t v = pages[i][(i * 8) % 512];
            if (v != tag(pid, tid, i, pass)) {
                result("FAIL", "pid %" PRIu64 " tid %" PRIu64 " pass %d page %zu va %p got %#" PRIx64 " want %#" PRIx64,
                       pid, tid, pass, i, (void *)pages[i], v, tag(pid, tid, i, pass));
                return 1;
            }
        }
    }
    return 0;
}

/* T1: capacity edges + access orders.  args: npages passes */
static int
t_capacity(int argc, char **argv)
{
    size_t n = argc > 0 ? strtoul(argv[0], 0, 0) : 513;
    int passes = argc > 1 ? atoi(argv[1]) : 4;
    char *base = xmap(n * PG, PROT_READ | PROT_WRITE);
    volatile uint64_t **pg = calloc(n, sizeof *pg);
    for (size_t i = 0; i < n; i++) pg[i] = (volatile uint64_t *)(base + i * PG);
    int orders[] = {0, 1, 2, 3, 5, 8};
    for (unsigned o = 0; o < sizeof orders / sizeof *orders; o++)
        if (fill_verify(pg, n, passes, o, orders[o])) return 1;
    result("PASS", "pages=%zu passes=%d orders=6", n, passes);
    return 0;
}

/* T2: same XOR-7 set conflict storm (forces L2 evictions -> L1 back-invalidation) */
static int
t_conflict(int argc, char **argv)
{
    size_t want = argc > 0 ? strtoul(argv[0], 0, 0) : 80;
    int passes = argc > 1 ? atoi(argv[1]) : 10;
    size_t span = 16384 * 2 + 256;               /* 128 MiB of VA, mapped lazily */
    char *base = xmap(span * PG, PROT_READ | PROT_WRITE);
    volatile uint64_t **pg = calloc(want, sizeof *pg);
    size_t n = 0;
    uintptr_t vpn0 = (uintptr_t)base / PG;
    unsigned target = ((vpn0 >> 7) ^ vpn0) & 0x7f;
    for (size_t i = 0; i < span && n < want; i++) {
        uintptr_t vpn = vpn0 + i;
        if ((((vpn >> 7) & 0x7f) ^ (vpn & 0x7f)) == target)
            pg[n++] = (volatile uint64_t *)(base + i * PG);
    }
    if (fill_verify(pg, n, passes, 0, 0) || fill_verify(pg, n, passes, 1, 1)) return 1;
    result("PASS", "same-set pages=%zu set=%u passes=%d", n, target, passes);
    return 0;
}

/* T3: munmap + MAP_FIXED remap of the same VA must never show old frames */
static int
t_remap(int argc, char **argv)
{
    int rounds = argc > 0 ? atoi(argv[0]) : 40;
    size_t n = argc > 1 ? strtoul(argv[1], 0, 0) : 96;
    char *base = xmap(n * PG, PROT_READ | PROT_WRITE);
    for (int r = 0; r < rounds; r++) {
        for (size_t i = 0; i < n; i++)
            *(volatile uint64_t *)(base + i * PG) = tag(getpid(), 0, i, r);
        for (size_t i = 0; i < n; i++)
            if (*(volatile uint64_t *)(base + i * PG) != tag(getpid(), 0, i, r)) {
                result("FAIL", "round %d page %zu wrong before remap", r, i); return 1;
            }
        if (r & 1) {   /* munmap + fixed remap: fresh zero pages expected */
            if (munmap(base, n * PG)) { perror("munmap"); return 2; }
            void *p = mmap(base, n * PG, PROT_READ | PROT_WRITE,
                           MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
            if (p != base) { perror("mmap fixed"); return 2; }
        } else {       /* MAP_FIXED over a live mapping (implicit unmap) */
            void *p = mmap(base, n * PG, PROT_READ | PROT_WRITE,
                           MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
            if (p != base) { perror("mmap fixed2"); return 2; }
        }
        for (size_t i = 0; i < n; i++) {
            uint64_t v = *(volatile uint64_t *)(base + i * PG);
            if (v != 0) {
                result("FAIL", "STALE after remap round %d page %zu va %p got %#" PRIx64 " (old frame data)",
                       r, i, base + i * PG, v);
                return 1;
            }
        }
    }
    result("PASS", "rounds=%d pages=%zu", rounds, n);
    return 0;
}

/* T4: permission downgrade + unmap must fault (FS; SE ignores mprotect) */
static int
t_protect(int argc, char **argv)
{
    int rounds = argc > 0 ? atoi(argv[0]) : 20;
    size_t n = 64;
    install_segv();
    char *base = xmap(n * PG, PROT_READ | PROT_WRITE);
    int prot_faults = 0, unmap_faults = 0;
    for (int r = 0; r < rounds; r++) {
        for (size_t i = 0; i < n; i++) *(volatile uint64_t *)(base + i * PG) = r + i;
        mprotect(base, n * PG, PROT_READ);
        for (size_t i = 0; i < n; i += 7) {
            if (!write_faults((volatile uint64_t *)(base + i * PG), 0xdead)) {
                result(r == 0 ? "SKIP" : "FAIL",
                       "write to read-only page %zu round %d did NOT fault%s", i, r,
                       r == 0 ? " (mprotect not enforced - SE mode?)" : " (stale writable TLB entry)");
                return r == 0 ? 0 : 1;
            }
            prot_faults++;
            uint64_t v;
            if (read_faults((volatile uint64_t *)(base + i * PG), &v) || v != r + i) {
                result("FAIL", "read-only page %zu has wrong data", i); return 1;
            }
        }
        mprotect(base, n * PG, PROT_READ | PROT_WRITE);
        /* punch a hole and verify it faults, neighbours intact */
        munmap(base + 13 * PG, PG);
        uint64_t v;
        if (!read_faults((volatile uint64_t *)(base + 13 * PG), &v)) {
            result("FAIL", "read of unmapped page did NOT fault (stale TLB) round %d", r); return 1;
        }
        unmap_faults++;
        if (*(volatile uint64_t *)(base + 12 * PG) != (uint64_t)r + 12) {
            result("FAIL", "neighbour of hole corrupted"); return 1;
        }
        mmap(base + 13 * PG, PG, PROT_READ | PROT_WRITE,
             MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
    }
    result("PASS", "rounds=%d prot_faults=%d unmap_faults=%d", rounds, prot_faults, unmap_faults);
    return 0;
}

/* T5: transparent huge pages - fill 2MiB pages, then split by mprotect/munmap */
static int
t_huge(int argc, char **argv)
{
    int rounds = argc > 0 ? atoi(argv[0]) : 6;
    size_t regions = 4;
    install_segv();
    for (int r = 0; r < rounds; r++) {
        char *raw = xmap((regions + 1) * HUGE, PROT_READ | PROT_WRITE);
        char *b = (char *)(((uintptr_t)raw + HUGE - 1) & ~(HUGE - 1));
        madvise(b, regions * HUGE, MADV_HUGEPAGE);
        for (size_t i = 0; i < regions * HUGE / PG; i++)
            *(volatile uint64_t *)(b + i * PG) = tag(1, r, i, 7);
        /* re-read at many 4K offsets of each huge page (L2 keys) */
        for (int pass = 0; pass < 3; pass++)
            for (size_t i = 0; i < regions * HUGE / PG; i += 3)
                if (*(volatile uint64_t *)(b + i * PG) != tag(1, r, i, 7)) {
                    result("FAIL", "huge region data wrong r%d page %zu", r, i); return 1;
                }
        /* split region 0: write-protect its upper half */
        mprotect(b + HUGE / 2, HUGE / 2, PROT_READ);
        int enforced = write_faults((volatile uint64_t *)(b + HUGE / 2 + 5 * PG), 1);
        if (!enforced && r == 0) {
            result("SKIP", "mprotect not enforced (SE mode?)"); return 0;
        }
        if (!enforced) { result("FAIL", "stale writable huge-page entry after split r%d", r); return 1; }
        if (!write_faults((volatile uint64_t *)(b + HUGE - PG), 1)) {
            result("FAIL", "last 4K of write-protected huge half still writable r%d", r); return 1;
        }
        /* region 1: unmap a 4K page in the middle of a huge page */
        munmap(b + HUGE + 100 * PG, PG);
        uint64_t v;
        if (!read_faults((volatile uint64_t *)(b + HUGE + 100 * PG), &v)) {
            result("FAIL", "unmapped 4K inside huge page still readable r%d", r); return 1;
        }
        /* region 1 first 4K page (base key) and others must still be right */
        if (*(volatile uint64_t *)(b + HUGE) != tag(1, r, HUGE / PG, 7) ||
            *(volatile uint64_t *)(b + HUGE + 101 * PG) != tag(1, r, HUGE / PG + 101, 7)) {
            result("FAIL", "huge-page neighbours wrong after partial unmap r%d", r); return 1;
        }
        /* region 2: munmap whole huge page then remap fresh -> zero */
        munmap(b + 2 * HUGE, HUGE);
        mmap(b + 2 * HUGE, HUGE, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1, 0);
        for (size_t i = 0; i < HUGE / PG; i += 17)
            if (*(volatile uint64_t *)(b + 2 * HUGE + i * PG) != 0) {
                result("FAIL", "STALE huge page after unmap/remap r%d page %zu", r, i); return 1;
            }
        munmap(raw, (regions + 1) * HUGE);
    }
    FILE *f = fopen("/sys/kernel/mm/transparent_hugepage/enabled", "r");
    char thp[128] = "n/a";
    if (f) { if (!fgets(thp, sizeof thp, f)) strcpy(thp, "?"); fclose(f); thp[strcspn(thp, "\n")] = 0; }
    result("PASS", "rounds=%d thp=[%s]", rounds, thp);
    return 0;
}

/* T6: multi-thread data + cross-core shootdown (mprotect/remap while others use it) */
struct shoot {
    char *base; size_t n; int nthreads;
    atomic_int phase, ready, fail;
    atomic_int faults;
};
static struct shoot S;
static void *
shoot_worker(void *arg)
{
    long id = (long)arg;
    install_segv();
    int cpus = sysconf(_SC_NPROCESSORS_ONLN);
    for (int ph = 1; ; ph++) {
        while (atomic_load(&S.phase) < ph) {
            if (atomic_load(&S.phase) < 0) return NULL;
            /* keep our TLB warm with writable entries in the shared region */
            for (size_t i = id; i < S.n; i += S.nthreads)   /* may fault if main already protected */
                (void)write_faults((volatile uint64_t *)(S.base + i * PG + 8 * (id + 1)), id);
        }
        if (atomic_load(&S.phase) < 0) return NULL;
        /* main has completed mprotect(READ): every write must fault now */
        for (size_t i = 0; i < S.n; i++) {
            if (!write_faults((volatile uint64_t *)(S.base + i * PG + 8 * (id + 1)), 0xbad)) {
                fprintf(stderr, "thread %ld cpu %d page %zu: write after mprotect did NOT fault\n",
                        id, sched_getcpu(), i);
                atomic_store(&S.fail, 1);
                break;
            }
            atomic_fetch_add(&S.faults, 1);
        }
        /* migrate to stress per-CPU TLB state */
        cpu_set_t set; CPU_ZERO(&set); CPU_SET((id + ph) % cpus, &set);
        sched_setaffinity(0, sizeof set, &set);
        atomic_fetch_add(&S.ready, 1);
    }
}
static int
t_shootdown(int argc, char **argv)
{
    S.nthreads = argc > 0 ? atoi(argv[0]) : 4;
    int rounds = argc > 1 ? atoi(argv[1]) : 10;
    S.n = 48;
    S.base = xmap(S.n * PG, PROT_READ | PROT_WRITE);
    install_segv();
    /* probe: is mprotect enforced at all? */
    mprotect(S.base, PG, PROT_READ);
    int enforced = write_faults((volatile uint64_t *)S.base, 1);
    mprotect(S.base, PG, PROT_READ | PROT_WRITE);
    if (!enforced) { result("SKIP", "mprotect not enforced (SE mode)"); return 0; }
    pthread_t th[64];
    for (long i = 0; i < S.nthreads; i++) pthread_create(&th[i], 0, shoot_worker, (void *)i);
    for (int r = 1; r <= rounds && !atomic_load(&S.fail); r++) {
        for (volatile int spin = 0; spin < 200000; spin++) ;   /* let workers warm TLBs */
        atomic_store(&S.ready, 0);
        mprotect(S.base, S.n * PG, PROT_READ);                /* -> TLB shootdown IPIs */
        atomic_store(&S.phase, r);
        while (atomic_load(&S.ready) < S.nthreads && !atomic_load(&S.fail)) sched_yield();
        mprotect(S.base, S.n * PG, PROT_READ | PROT_WRITE);
    }
    atomic_store(&S.phase, -1);
    for (int i = 0; i < S.nthreads; i++) pthread_join(th[i], 0);
    if (atomic_load(&S.fail)) { result("FAIL", "stale writable translation survived a cross-CPU shootdown"); return 1; }
    result("PASS", "threads=%d rounds=%d expected_faults=%d", S.nthreads, rounds, atomic_load(&S.faults));
    return 0;
}

/* T7: threads with private + shared data, sched_yield + migration (works in SE too) */
struct thr { long id; int pages, passes, fail; };
static void *
thr_main(void *a)
{
    struct thr *t = a;
    char *b = xmap(t->pages * PG, PROT_READ | PROT_WRITE);
    volatile uint64_t **pg = calloc(t->pages, sizeof *pg);
    for (int i = 0; i < t->pages; i++) pg[i] = (volatile uint64_t *)(b + i * PG);
    for (int p = 0; p < t->passes; p++) {
        if (fill_verify(pg, t->pages, 1, t->id * 1000 + p, p % 4)) { t->fail = 1; break; }
        sched_yield();
    }
    return NULL;
}
static int
t_threads(int argc, char **argv)
{
    int n = argc > 0 ? atoi(argv[0]) : 4;
    int pages = argc > 1 ? atoi(argv[1]) : 300;
    int passes = argc > 2 ? atoi(argv[2]) : 4;
    pthread_t th[64]; struct thr t[64];
    for (int i = 0; i < n; i++) {
        t[i] = (struct thr){i, pages, passes, 0};
        pthread_create(&th[i], 0, thr_main, &t[i]);
    }
    int bad = 0;
    for (int i = 0; i < n; i++) { pthread_join(th[i], 0); bad |= t[i].fail; }
    if (bad) { result("FAIL", "a thread saw wrong data"); return 1; }
    result("PASS", "threads=%d pages/thread=%d passes=%d", n, pages, passes);
    return 0;
}

/* T8: N processes, SAME virtual addresses, different data, heavy context switching
 *     + fork copy-on-write breaks. */
static int
t_procs(int argc, char **argv)
{
    int nproc = argc > 0 ? atoi(argv[0]) : 6;
    int rounds = argc > 1 ? atoi(argv[1]) : 20;
    size_t n = 160;
    char *b = mmap((void *)0x600000000000UL, n * PG, PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE, -1, 0);
    if (b == MAP_FAILED) { perror("mmap fixed va"); return 2; }
    for (size_t i = 0; i < n; i++) *(volatile uint64_t *)(b + i * PG) = tag(0, 0, i, 99);
    for (int c = 0; c < nproc; c++) {
        pid_t pid = fork();
        if (pid < 0) { result("SKIP", "fork failed: %s", strerror(errno)); return 0; }
        if (pid == 0) {
            /* child: COW the parent's pages, then hammer same VAs */
            for (size_t i = 0; i < n; i++)
                if (*(volatile uint64_t *)(b + i * PG) != tag(0, 0, i, 99)) _exit(3);
            for (int r = 0; r < rounds; r++) {
                for (size_t i = 0; i < n; i++) *(volatile uint64_t *)(b + i * PG) = tag(getpid(), c, i, r);
                sched_yield();
                for (size_t i = 0; i < n; i++)
                    if (*(volatile uint64_t *)(b + i * PG) != tag(getpid(), c, i, r)) {
                        fprintf(stderr, "child %d round %d page %zu: wrong (another process's frame?)\n", c, r, i);
                        _exit(1);
                    }
            }
            _exit(0);
        }
    }
    int bad = 0, st;
    for (int c = 0; c < nproc; c++) {
        if (wait(&st) < 0 || !WIFEXITED(st) || WEXITSTATUS(st)) bad++;
    }
    for (size_t i = 0; i < n; i++)
        if (*(volatile uint64_t *)(b + i * PG) != tag(0, 0, i, 99)) {
            result("FAIL", "parent page %zu modified by a child (COW/TLB leak)", i); return 1;
        }
    if (bad) { result("FAIL", "%d of %d children saw wrong data", bad, nproc); return 1; }
    result("PASS", "procs=%d rounds=%d same_va=%p pages=%zu", nproc, rounds, b, n);
    return 0;
}

/* T9: high-rate timer signals whose handler touches its own pages, while the
 *     main loop verifies a working set larger than L1 (interrupt + nested TLB use). */
static volatile uint64_t *g_hpages[128];
static volatile sig_atomic_t g_ticks;
static void
on_alarm(int s)
{
    (void)s;
    uint64_t t = g_ticks++;
    for (int i = 0; i < 128; i++) {
        g_hpages[i][1] = tag(7, 7, i, t);
        if (g_hpages[i][1] != tag(7, 7, i, t)) g_fail = 1;
    }
}
static int
t_interrupts(int argc, char **argv)
{
    int passes = argc > 0 ? atoi(argv[0]) : 30;
    long usec = argc > 1 ? atol(argv[1]) : 200;
    char *h = xmap(128 * PG, PROT_READ | PROT_WRITE);
    for (int i = 0; i < 128; i++) g_hpages[i] = (volatile uint64_t *)(h + i * PG);
    size_t n = 700;
    char *b = xmap(n * PG, PROT_READ | PROT_WRITE);
    volatile uint64_t **pg = calloc(n, sizeof *pg);
    for (size_t i = 0; i < n; i++) pg[i] = (volatile uint64_t *)(b + i * PG);
    signal(SIGALRM, on_alarm);
    struct itimerval it = {{0, usec}, {0, usec}};
    if (setitimer(ITIMER_REAL, &it, NULL)) { result("SKIP", "setitimer unsupported"); return 0; }
    for (int p = 0; p < passes; p++)
        if (fill_verify(pg, n, 1, p, p % 4)) return 1;
    struct itimerval off = {{0, 0}, {0, 0}};
    setitimer(ITIMER_REAL, &off, NULL);
    if (g_fail) { result("FAIL", "signal handler saw wrong data"); return 1; }
    if (g_ticks == 0) { result("SKIP", "no timer signals delivered (SE mode?) passes=%d", passes); return 0; }
    result("PASS", "passes=%d timer_signals=%d", passes, (int)g_ticks);
    return 0;
}

/* T10: shared memory between processes (same frame, different VAs) */
static int
t_shared(int argc, char **argv)
{
    int rounds = argc > 0 ? atoi(argv[0]) : 50;
    size_t n = 64;
    volatile uint64_t *sh = mmap(NULL, n * PG, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    if (sh == MAP_FAILED) { result("SKIP", "MAP_SHARED unsupported"); return 0; }
    pid_t pid = fork();
    if (pid < 0) { result("SKIP", "fork unsupported"); return 0; }
    if (pid == 0) {
        for (int r = 1; r <= rounds; r++) {
            while (sh[0] != (uint64_t)(2 * r - 1)) sched_yield();
            for (size_t i = 1; i < n; i++)
                if (sh[i * PG / 8] != tag(1, 0, i, r)) _exit(1);
            for (size_t i = 1; i < n; i++) sh[i * PG / 8] = tag(2, 0, i, r);
            __atomic_store_n(&sh[0], 2 * r, __ATOMIC_SEQ_CST);
        }
        _exit(0);
    }
    for (int r = 1; r <= rounds; r++) {
        for (size_t i = 1; i < n; i++) sh[i * PG / 8] = tag(1, 0, i, r);
        __atomic_store_n(&sh[0], 2 * r - 1, __ATOMIC_SEQ_CST);
        while (sh[0] != (uint64_t)(2 * r)) sched_yield();
        for (size_t i = 1; i < n; i++)
            if (sh[i * PG / 8] != tag(2, 0, i, r)) { result("FAIL", "shared page %zu not coherent r%d", i, r); return 1; }
    }
    int st; waitpid(pid, &st, 0);
    if (!WIFEXITED(st) || WEXITSTATUS(st)) { result("FAIL", "child saw stale shared data"); return 1; }
    result("PASS", "rounds=%d pages=%zu", rounds, n);
    return 0;
}

static const struct { const char *name; int (*fn)(int, char **); } tests[] = {
    {"capacity", t_capacity}, {"conflict", t_conflict}, {"remap", t_remap},
    {"protect", t_protect},   {"huge", t_huge},         {"shootdown", t_shootdown},
    {"threads", t_threads},   {"procs", t_procs},       {"interrupts", t_interrupts},
    {"shared", t_shared},
};

int
main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    if (argc < 2) {
        fprintf(stderr, "usage: %s <test> [args]; tests:", argv[0]);
        for (unsigned i = 0; i < sizeof tests / sizeof *tests; i++) fprintf(stderr, " %s", tests[i].name);
        fprintf(stderr, "\n");
        return 2;
    }
    for (unsigned i = 0; i < sizeof tests / sizeof *tests; i++)
        if (!strcmp(argv[1], tests[i].name)) {
            g_test = tests[i].name;
            int rc = tests[i].fn(argc - 2, argv + 2);
            return rc ? rc : g_fail;
        }
    fprintf(stderr, "unknown test %s\n", argv[1]);
    return 2;
}
