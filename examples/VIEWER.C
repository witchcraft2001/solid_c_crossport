#include <stdio.h>
#include <stdlib.h>

int main()
{
    char filename[128];
    char buffer[128];
    int count;
    int ch;
    FILE *fp;

    puts("VIEWER - enter filename:");
    if (gets(filename) == NULL || filename[0] == '\0') {
        puts("No input file.");
        return 1;
    }

    fp = fopen(filename, "r");
    if (fp == NULL) {
        puts("Cannot open file.");
        return 1;
    }

    count = 0;
    while (fgets(buffer, 127, fp) != NULL) {
        fputs(buffer, stdout);
        ++count;

        if (count == 20) {
            puts("-- more -- (q to quit)");
            ch = getchar();
            if (ch == 'q' || ch == 'Q') break;
            count = 0;
        }
    }

    fclose(fp);
    return 0;
}
