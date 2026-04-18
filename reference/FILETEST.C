#include <conio.h>

char sample[] = "This is a compile-time text block used instead of file I/O.";

void main()
{
    int i;
    cputs("FILETEST replacement (no stdio.h)\n");
    cputs("First 10 chars as codes:\n");
    for (i = 0; i < 10 && sample[i]; ++i) {
        cprintf("%d ", sample[i]);
    }
    cputs("\nText preview:\n");
    cputs(sample);
    cputs("\n");
}
