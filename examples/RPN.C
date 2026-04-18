#include <stdio.h>
#include <ctype.h>
#include <stdlib.h>

#define MAXOP 40
#define NUMBER '0'
#define STACKSIZE 40

unsigned char sp;
int stack[STACKSIZE];

char s[MAXOP];
unsigned char pos;
int n;

void push(v)
int v;
{
    if (sp < STACKSIZE) stack[sp++] = v;
    else puts("Stack full");
}

int pop()
{
    if (sp > 0) return stack[--sp];
    puts("Stack empty");
    return 0;
}

int top()
{
    if (sp > 0) return stack[sp - 1];
    puts("Stack empty");
    return 0;
}

int read_op()
{
    if (pos == 0) {
        if (gets(s) == NULL) return 0;
    }

    while (s[pos] == ' ' || s[pos] == '\t') pos++;

    if (s[pos] == '\0') {
        pos = 0;
        return '\n';
    }

    if (!isdigit((unsigned char)s[pos])) return s[pos++];

    n = s[pos] - '0';
    while (isdigit((unsigned char)s[++pos])) {
        n = 10 * n + s[pos] - '0';
    }
    return NUMBER;
}

int main()
{
    int type;
    int op2;

    puts("RPN calculator. '.' to quit.");
    sp = 0;
    pos = 0;

    while ((type = read_op()) != 0) {
        switch (type) {
        case NUMBER:
            push(n);
            break;
        case '+':
            push(pop() + pop());
            break;
        case '*':
            push(pop() * pop());
            break;
        case '-':
            op2 = pop();
            push(pop() - op2);
            break;
        case '/':
            op2 = pop();
            if (op2 != 0) push(pop() / op2);
            else puts("Divide by 0");
            break;
        case '.':
            return 0;
        case '\n':
            printf("==> %d\n", top());
            break;
        default:
            printf("Unknown token: %c\n", type);
            break;
        }
    }

    return 0;
}
