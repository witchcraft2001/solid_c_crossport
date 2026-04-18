#include <stdio.h>

#define FP 256
#define WIDTH 78
#define HEIGHT 40
#define MAXITER 40

char shade[] = " .:-=+*#%@";

int main()
{
    int x, y;
    int cr, ci;
    int zr, zi;
    int zr2, zi2;
    int iter;
    int idx;

    puts("MANDEL fixed-point");

    for (y = 0; y < HEIGHT; ++y) {
        ci = ((y * (3 * FP)) / HEIGHT) - (3 * FP) / 2;
        for (x = 0; x < WIDTH; ++x) {
            cr = ((x * (3 * FP)) / WIDTH) - (2 * FP);

            zr = 0;
            zi = 0;
            iter = 0;

            while (iter < MAXITER) {
                zr2 = (zr * zr) / FP;
                zi2 = (zi * zi) / FP;
                if (zr2 + zi2 > 4 * FP) break;

                zi = (2 * zr * zi) / FP + ci;
                zr = zr2 - zi2 + cr;
                ++iter;
            }

            idx = (iter * 9) / MAXITER;
            if (idx < 0) idx = 0;
            if (idx > 9) idx = 9;
            putchar(shade[idx]);
        }
        putchar('\n');
    }

    return 0;
}
