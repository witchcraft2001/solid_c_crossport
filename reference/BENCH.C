/*
 * bench.c - Z80 Benchmark Suite
 * SOLID C port for ZX Sprinter / Estex DSS
 *
 * Build: bench.bat
 * Original: SDCC Sprinter SDK examples/14_bench
 */

#include <stdio.h>
#include <dos.h>

/* ==== Timer ==== */
unsigned int _t0;

void timer_start()
{
    struct time t;
    unsigned int m, s;
    unsigned char prev;
    gettime(&t);
    prev = t.ti_sec;
    do { gettime(&t); } while (t.ti_sec == prev);
    m = t.ti_min;
    s = t.ti_sec;
    _t0 = m * 60 + s;
}

unsigned int timer_elapsed()
{
    struct time t;
    unsigned int m, s, t1;
    gettime(&t);
    m = t.ti_min;
    s = t.ti_sec;
    t1 = m * 60 + s;
    if (t1 < _t0) t1 = t1 + 3600;
    return t1 - _t0;
}

/* ==== PRNG ==== */
unsigned char rng;

void rng_seed(s)
unsigned char s;
{
    rng = s;
}

unsigned char rng_next()
{
    rng = rng * 5 + 1;
    return rng;
}

/* ==== Data ==== */
unsigned char sieve[1000];
unsigned char arr[256];
unsigned char data[256];
unsigned char rc4_s[256];

/* ============================================ */
/*  Test 1: Sieve of Eratosthenes              */
/* ============================================ */
unsigned int bench_sieve(runs)
int runs;
{
    unsigned int i, j, k, count;
    int r;

    for (r = 0; r < runs; r++) {
        for (i = 0; i < 1000; i++) sieve[i] = 1;
        sieve[0] = 0;
        sieve[1] = 0;
        for (i = 2; i < 32; i++) {
            if (sieve[i]) {
                j = i * i;
                while (j < 1000) {
                    sieve[j] = 0;
                    j = j + i;
                }
            }
        }
    }
    count = 0;
    for (i = 0; i < 1000; i++) {
        if (sieve[i]) count = count + 1;
    }
    return count;
}

/* ============================================ */
/*  Test 2: Bubble Sort (256 bytes)             */
/* ============================================ */
unsigned int bench_bubble(runs)
int runs;
{
    int r, i, j;
    unsigned char t, sum;

    for (r = 0; r < runs; r++) {
        rng_seed(0x42);
        for (i = 0; i < 256; i++) arr[i] = rng_next();
        for (i = 0; i < 255; i++) {
            for (j = 0; j < 255 - i; j++) {
                if (arr[j] > arr[j + 1]) {
                    t = arr[j];
                    arr[j] = arr[j + 1];
                    arr[j + 1] = t;
                }
            }
        }
    }
    sum = 0;
    for (i = 0; i < 256; i++) sum = sum + arr[i];
    return sum;
}

/* ============================================ */
/*  Test 3: Shell Sort (256 bytes)              */
/* ============================================ */
unsigned int bench_shell(runs)
int runs;
{
    int r, i, j, gap;
    unsigned char t, sum;

    for (r = 0; r < runs; r++) {
        rng_seed(0x42);
        for (i = 0; i < 256; i++) arr[i] = rng_next();
        gap = 128;
        while (gap > 0) {
            for (i = gap; i < 256; i++) {
                t = arr[i];
                j = i;
                while (j >= gap) {
                    if (arr[j - gap] > t) {
                        arr[j] = arr[j - gap];
                        j = j - gap;
                    } else {
                        break;
                    }
                }
                arr[j] = t;
            }
            gap = gap / 2;
        }
    }
    sum = 0;
    for (i = 0; i < 256; i++) sum = sum + arr[i];
    return sum;
}

/* ============================================ */
/*  Test 4: CRC-16 CCITT                        */
/* ============================================ */
unsigned int bench_crc(runs)
int runs;
{
    unsigned int crc, i;
    int r;
    unsigned char j, b;

    for (i = 0; i < 256; i++) data[i] = i;

    for (r = 0; r < runs; r++) {
        crc = 0xFFFF;
        for (i = 0; i < 256; i++) {
            b = data[i];
            for (j = 0; j < 8; j++) {
                if ((crc ^ b) & 1)
                    crc = (crc >> 1) ^ 0x8408;
                else
                    crc = crc >> 1;
                b = b >> 1;
            }
        }
    }
    return crc ^ 0xFFFF;
}

/* ============================================ */
/*  Test 5: RC4 stream cipher                   */
/* ============================================ */
unsigned int bench_rc4(runs)
int runs;
{
    int r;
    unsigned int n;
    unsigned char i, j, t, sum, k;

    for (r = 0; r < runs; r++) {
        for (n = 0; n < 256; n++) rc4_s[n] = n;
        j = 0;
        for (n = 0; n < 256; n++) {
            i = n;
            k = n * 7 + 0x1F;
            j = j + rc4_s[i] + k;
            t = rc4_s[i]; rc4_s[i] = rc4_s[j]; rc4_s[j] = t;
        }
        i = 0;
        j = 0;
        for (n = 0; n < 256; n++) {
            i = i + 1;
            j = j + rc4_s[i];
            t = rc4_s[i]; rc4_s[i] = rc4_s[j]; rc4_s[j] = t;
            k = rc4_s[i] + rc4_s[j];
            data[n] = rc4_s[k];
        }
    }
    sum = 0;
    for (n = 0; n < 256; n++) sum = sum + data[n];
    return sum;
}

/* ============================================ */
/*  Test 6: 16-bit integer arithmetic           */
/* ============================================ */
unsigned int bench_math(runs)
int runs;
{
    unsigned int i, sum, x;
    int r;

    sum = 0;
    for (r = 0; r < runs; r++) {
        x = 1;
        for (i = 1; i <= 1000; i++) {
            x = x * 3 + i;
            sum = sum + x;
        }
    }
    return sum;
}

/* ============================================ */
/*  Main                                        */
/* ============================================ */
void main()
{
    unsigned int total, check, secs;

    total = 0;

    printf("Z80 Benchmark v1.0 (SOLID C)\n");
    printf("============================\n\n");
    printf("  Test          Runs  Check  Time\n");
    printf("  ------------ ----- ------ -----\n");

    printf("  Sieve        x200  ");
    timer_start();
    check = bench_sieve(200);
    secs = timer_elapsed();
    total = total + secs;
    printf(" %5u  %2u:%02u\n", check, secs / 60, secs % 60);

    printf("  Bubble sort  x10   ");
    timer_start();
    check = bench_bubble(10);
    secs = timer_elapsed();
    total = total + secs;
    printf(" %5u  %2u:%02u\n", check, secs / 60, secs % 60);

    printf("  Shell sort   x60   ");
    timer_start();
    check = bench_shell(60);
    secs = timer_elapsed();
    total = total + secs;
    printf(" %5u  %2u:%02u\n", check, secs / 60, secs % 60);

    printf("  CRC-16       x400  ");
    timer_start();
    check = bench_crc(400);
    secs = timer_elapsed();
    total = total + secs;
    printf(" %5u  %2u:%02u\n", check, secs / 60, secs % 60);

    printf("  RC4          x500  ");
    timer_start();
    check = bench_rc4(500);
    secs = timer_elapsed();
    total = total + secs;
    printf(" %5u  %2u:%02u\n", check, secs / 60, secs % 60);

    printf("  Int math     x200  ");
    timer_start();
    check = bench_math(200);
    secs = timer_elapsed();
    total = total + secs;
    printf(" %5u  %2u:%02u\n", check, secs / 60, secs % 60);

    printf("  ------------ ----- ------ -----\n");
    printf("  TOTAL                     %2u:%02u\n", total / 60, total % 60);
}
