#include <conio.h>

int getc();

void redrawscreen()
{
    cputs("----------------------------------------\n");
    cputs("  A silly, pointless demo for app flow  \n");
    cputs("----------------------------------------\n");
    cputs("Commands: e=eat d=drink s=sleep q=quit\n");
}

void handlecmd(c)
int c;
{
    if (c == 'e' || c == 'E') cputs("So you want to... eat\n");
    else if (c == 'd' || c == 'D') cputs("So you want to... drink\n");
    else if (c == 's' || c == 'S') cputs("So you want to... sleep\n");
    else if (c == 'q' || c == 'Q') return;
    else cputs("Unknown command\n");
}

void main()
{
    int c;
    redrawscreen();
    while (1) {
        c = getc();
        if (c == 'q' || c == 'Q') return;
        if (c == '\n' || c == '\r') continue;
        handlecmd(c);
    }
}
