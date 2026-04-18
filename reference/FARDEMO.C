#include <conio.h>

#define BLOCK 256

char s1[] = "This is string 1..dull as hell";
char s2[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
char s3[] = "The quick brown fox ";
char s4[] = "jumped over the lazy dog";

char a[BLOCK];
char b[BLOCK];

void mycpy(dst, src)
char *dst;
char *src;
{
    while ((*dst++ = *src++) != 0) ;
}

void mycat(dst, src)
char *dst;
char *src;
{
    while (*dst) dst++;
    while ((*dst++ = *src++) != 0) ;
}

void to_upper(s)
char *s;
{
    while (*s) {
        if (*s >= 'a' && *s <= 'z') *s = *s - 'a' + 'A';
        s++;
    }
}

void to_lower(s)
char *s;
{
    while (*s) {
        if (*s >= 'A' && *s <= 'Z') *s = *s - 'A' + 'a';
        s++;
    }
}

void main()
{
    cputs("FARDEMO string stress (SolidC-safe)\n");

    mycpy(a, s2);
    cputs("Copy 1: ");
    cputs(a);
    cputs("\n");

    mycpy(a, s3);
    mycat(a, s4);
    cputs("Concat: ");
    cputs(a);
    cputs("\n");

    mycpy(b, s1);
    mycat(b, " :: ");
    mycat(b, a);
    cputs("Merged: ");
    cputs(b);
    cputs("\n");

    to_upper(b);
    cputs("Upper : ");
    cputs(b);
    cputs("\n");

    to_lower(b);
    cputs("Lower : ");
    cputs(b);
    cputs("\n");
}
