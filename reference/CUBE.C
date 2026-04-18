#include <conio.h>

#define NODES 8
#define SCALE 256
#define FRAMES 12

int cube_x[NODES] = { -24, -24, 24, 24, -24, -24, 24, 24 };
int cube_y[NODES] = { -24,  24, 24, -24, -24, 24, 24, -24 };
int cube_z[NODES] = { -24, -24, -24, -24, 24, 24, 24, 24 };

int sin_tab[24] = {
    0, 66, 128, 181, 221, 247, 256, 247, 221, 181, 128, 66,
    0, -66, -128, -181, -221, -247, -256, -247, -221, -181, -128, -66
};

int cos_tab[24] = {
    256, 247, 221, 181, 128, 66, 0, -66, -128, -181, -221, -247,
    -256, -247, -221, -181, -128, -66, 0, 66, 128, 181, 221, 247
};

void rotate_point(x, y, z, a, rx, ry)
int x, y, z;
int a;
int *rx, *ry;
{
    int cx, sx;
    int tx, ty, tz;
    cx = cos_tab[a % 24];
    sx = sin_tab[a % 24];
    tx = x;
    ty = (y * cx - z * sx) / SCALE;
    tz = (y * sx + z * cx) / SCALE;
    *rx = tx + tz / 2;
    *ry = ty + tz / 4;
}

void main()
{
    int f, i, rx, ry;
    cputs("CUBE projection (text)\n");
    for (f = 0; f < FRAMES; ++f) {
        cprintf("Frame %d\n", f);
        for (i = 0; i < NODES; ++i) {
            rotate_point(cube_x[i], cube_y[i], cube_z[i], f, &rx, &ry);
            cprintf("V%u: %d %d\n", i, rx, ry);
        }
        cputs("\n");
    }
}
