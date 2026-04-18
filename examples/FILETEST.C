#include <stdio.h>
#include <stdlib.h>

int main()
{
    FILE *fp;
    char line[128];
    int i;

    puts("FILETEST - enter filename:");
    if (gets(line) == NULL || line[0] == '\0') {
        puts("No input file.");
        return 1;
    }

    fp = fopen(line, "r");
    if (fp == NULL) {
        puts("Can't open file.");
        return 1;
    }

    puts("First 10 chars as number:");
    printn(fp, 10, stdout);
    puts("\nFirst 5 lines:");

    for (i = 0; i < 5; ++i) {
        if (fgets(line, 127, fp) == NULL) break;
        fputs(line, stdout);
    }

    fclose(fp);
    return 0;
}
