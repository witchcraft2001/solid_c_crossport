#include <conio.h>

char text[] = "SolidC word count demo.\nThis example avoids stdio headers but still\ntests character classification and counters.\nNumbers: 12345. Symbols: *&^%.\n";

int is_space(ch)
int ch;
{
    return (ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' || ch == '\f');
}

void main()
{
    int i;
    int lcount, wcount, ccount;
    int inword;
    int ch;

    lcount = 0;
    wcount = 0;
    ccount = 0;
    inword = 0;

    for (i = 0; text[i]; ++i) {
        ch = text[i];
        ccount++;
        if (ch == '\n') lcount++;

        if (is_space(ch)) {
            if (inword) wcount++;
            inword = 0;
        } else {
            inword = 1;
        }
    }
    if (inword) wcount++;

    cputs("WORDCNT sample stats\n");
    cprintf("Lines=%d Words=%d Chars=%d\n", lcount, wcount, ccount);
}
