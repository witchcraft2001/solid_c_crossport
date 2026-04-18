#include <conio.h>

int getc(), putc();

char *lines[] = {
    "VIEWER demo line 01",
    "VIEWER demo line 02",
    "VIEWER demo line 03",
    "VIEWER demo line 04",
    "VIEWER demo line 05",
    "VIEWER demo line 06",
    "VIEWER demo line 07",
    "VIEWER demo line 08",
    "VIEWER demo line 09",
    "VIEWER demo line 10",
    "VIEWER demo line 11",
    "VIEWER demo line 12",
    0
};

void main()
{
    int i;
    int page;
    int ch;

    i = 0;
    page = 0;
    cputs("VIEWER (q to quit, any key for next page)\n\n");

    while (lines[i]) {
        cputs(lines[i]);
        putc('\n');
        i++;
        page++;
        if (page == 6) {
            cputs("--more--");
            ch = getc();
            putc('\n');
            if (ch == 'q' || ch == 'Q') return;
            page = 0;
        }
    }
}
