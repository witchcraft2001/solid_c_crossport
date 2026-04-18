#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>

int main()
{
    char filename[128];
    int lcount, wcount, ccount;
    int word;
    int c;
    FILE *fp;

    puts("WORDCNT - enter filename:");
    if (gets(filename) == NULL || filename[0] == '\0') {
        puts("No input file.");
        return 1;
    }

    fp = fopen(filename, "r");
    if (fp == NULL) {
        printf("Cannot open file: %s\n", filename);
        return 1;
    }

    lcount = wcount = ccount = 0;
    word = 0;

    while ((c = fgetc(fp)) != EOF) {
        ++ccount;

        if (isspace((unsigned char)c)) {
            if (word) ++wcount;
            word = 0;
            if (c == '\n' || c == '\f' || c == '\r') ++lcount;
        } else {
            word = 1;
        }
    }

    if (word) ++wcount;
    fclose(fp);

    printf("File %s\n", filename);
    printf("Lines=%d Words=%d Chars=%d\n", lcount, wcount, ccount);
    return 0;
}
