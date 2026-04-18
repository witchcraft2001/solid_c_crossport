#include <stdio.h>

int main()
{
    int x;

    puts("ANSI test");

    printf("\033[1mBold\033[0m\n");
    printf("\033[4mUnderline\033[0m\n");
    printf("\033[7mInverse\033[0m\n");

    for (x = 30; x <= 37; ++x) {
        printf("\033[%dmFG %d\033[0m\n", x, x);
    }

    for (x = 40; x <= 47; ++x) {
        printf("\033[%dmBG %d\033[0m\n", x, x);
    }

    puts("Draw X with cursor moves:");
    for (x = 0; x < 11; ++x) {
        printf("\033[%d;%dH*", 10 + x, 25 + x);
        printf("\033[%d;%dH*", 20 - x, 25 + x);
    }

    printf("\033[24;1H");
    return 0;
}
