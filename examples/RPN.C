#include <conio.h>

#define MAXOP 40
#define STACKSIZE 40
#define NUMBER '0'

char line[MAXOP + 2];
int sp;
int stack[STACKSIZE];
int pos;
int num;

int is_digit(ch)
int ch;
{
    return (ch >= '0' && ch <= '9');
}

void push(v)
int v;
{
    if (sp < STACKSIZE) stack[sp++] = v;
    else cputs("Stack full\n");
}

int pop()
{
    if (sp > 0) return stack[--sp];
    cputs("Stack empty\n");
    return 0;
}

int top()
{
    if (sp > 0) return stack[sp - 1];
    return 0;
}

int read_op()
{
    int ch;
    char *s;

    if (pos == 0) {
        line[0] = MAXOP;
        line[1] = 0;
        s = cgets(line);
        if (s == 0) return 0;
    }

    while (line[pos + 2] == ' ' || line[pos + 2] == '\t') pos++;

    if (line[pos + 2] == '\0') {
        pos = 0;
        return '\n';
    }

    ch = line[pos + 2];
    if (!is_digit(ch)) {
        pos++;
        return ch;
    }

    num = 0;
    while (is_digit(line[pos + 2])) {
        num = num * 10 + (line[pos + 2] - '0');
        pos++;
    }
    return NUMBER;
}

void main()
{
    int type;
    int op2;

    cputs("RPN calculator ('.' to exit)\n");
    sp = 0;
    pos = 0;

    while ((type = read_op()) != 0) {
        switch (type) {
        case NUMBER:
            push(num);
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
            if (op2 == 0) cputs("Divide by zero\n");
            else push(pop() / op2);
            break;
        case '.':
            return;
        case '\n':
            cprintf("==> %d\n", top());
            break;
        default:
            cprintf("Unknown token: %c\n", type);
            break;
        }
    }
}
