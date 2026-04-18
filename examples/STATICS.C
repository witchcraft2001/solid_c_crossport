#include <stdio.h>

struct strprt {
    char *j;
    char k[10];
};

struct strprt mystr2[2] = { { "Hello!", "Hellohell" }, { "Hello", "Hello" } };
char blah[1] = "h";

char *j = "Hello";
char *m[] = { "Hello" };
char *n = "Hello";
char k[] = "Hello";
char o[10] = "Hello";
char *l[3] = { "Hello", "Hello", 0 };
char *p[3] = { "Hello", 0, 0 };

int ij = 1;
int ik[] = { 1, 2, 3 };
int il[10] = { 1 };

void dump_ints(a, nitems)
int *a;
int nitems;
{
    int i;
    for (i = 0; i < nitems; ++i) printf("%d ", a[i]);
    putchar('\n');
}

int main()
{
    static int ls;
    static int lk = 2;
    static char *lj = "Hello";

    ls = ij + lk;

    puts("STATICS init test");
    printf("mystr2[0]=%s/%s\n", mystr2[0].j, mystr2[0].k);
    printf("strings: %s %s %s %s %s %s\n", j, m[0], n, k, o, l[0]);
    printf("p[0]=%s ls=%d lk=%d lj=%s\n", p[0], ls, lk, lj);
    dump_ints(ik, 3);
    dump_ints(il, 4);

    return 0;
}
