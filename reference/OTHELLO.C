#include <conio.h>

int getc(), putc();

#define EMPTY '.'
#define BLACK '*'
#define WHITE 'O'

char board[64];

int idx(r, c)
int r, c;
{
    return r * 8 + c;
}

int inside(r, c)
int r, c;
{
    return (r >= 0 && r < 8 && c >= 0 && c < 8);
}

void init_board()
{
    int i;
    for (i = 0; i < 64; ++i) board[i] = EMPTY;
    board[idx(3, 3)] = WHITE;
    board[idx(3, 4)] = BLACK;
    board[idx(4, 3)] = BLACK;
    board[idx(4, 4)] = WHITE;
}

void print_board()
{
    int r, c;
    cputs("  1 2 3 4 5 6 7 8\n");
    for (r = 0; r < 8; ++r) {
        cprintf("%d ", r + 1);
        for (c = 0; c < 8; ++c) {
            putc(board[idx(r, c)]);
            putc(' ');
        }
        putc('\n');
    }
}

int flip_dir(r, c, dr, dc, me, him, do_flip)
int r, c, dr, dc, me, him, do_flip;
{
    int rr, cc, n, i;
    rr = r + dr;
    cc = c + dc;
    n = 0;
    while (inside(rr, cc) && board[idx(rr, cc)] == him) {
        n++;
        rr += dr;
        cc += dc;
    }
    if (n == 0) return 0;
    if (!inside(rr, cc) || board[idx(rr, cc)] != me) return 0;
    if (do_flip) {
        rr = r + dr;
        cc = c + dc;
        for (i = 0; i < n; ++i) {
            board[idx(rr, cc)] = me;
            rr += dr;
            cc += dc;
        }
    }
    return n;
}

int apply_move(r, c, me, him, do_flip)
int r, c, me, him, do_flip;
{
    int total;
    if (!inside(r, c) || board[idx(r, c)] != EMPTY) return 0;
    total = 0;
    total += flip_dir(r, c, -1, -1, me, him, do_flip);
    total += flip_dir(r, c, -1, 0, me, him, do_flip);
    total += flip_dir(r, c, -1, 1, me, him, do_flip);
    total += flip_dir(r, c, 0, -1, me, him, do_flip);
    total += flip_dir(r, c, 0, 1, me, him, do_flip);
    total += flip_dir(r, c, 1, -1, me, him, do_flip);
    total += flip_dir(r, c, 1, 0, me, him, do_flip);
    total += flip_dir(r, c, 1, 1, me, him, do_flip);
    if (total > 0 && do_flip) board[idx(r, c)] = me;
    return total;
}

int has_move(me, him)
int me, him;
{
    int r, c;
    for (r = 0; r < 8; ++r)
        for (c = 0; c < 8; ++c)
            if (apply_move(r, c, me, him, 0) > 0) return 1;
    return 0;
}

void count_score(pb, pw)
int *pb, *pw;
{
    int i;
    *pb = *pw = 0;
    for (i = 0; i < 64; ++i) {
        if (board[i] == BLACK) (*pb)++;
        if (board[i] == WHITE) (*pw)++;
    }
}

int ai_move(me, him, pr, pc)
int me, him, *pr, *pc;
{
    int r, c, cur, best;
    best = 0;
    *pr = -1;
    *pc = -1;
    for (r = 0; r < 8; ++r) {
        for (c = 0; c < 8; ++c) {
            cur = apply_move(r, c, me, him, 0);
            if (cur > best) {
                best = cur;
                *pr = r;
                *pc = c;
            }
        }
    }
    return best;
}

void main()
{
    int turn, me, him;
    int r, c, b, w;
    int pass, ch1, ch2;

    init_board();
    turn = BLACK;
    pass = 0;
    cputs("OTHELLO (you are *)\n");

    while (1) {
        me = turn;
        him = (turn == BLACK) ? WHITE : BLACK;

        print_board();
        count_score(&b, &w);
        cprintf("Score *=%d O=%d\n", b, w);

        if (!has_move(me, him)) {
            pass++;
            if (pass == 2) break;
            cprintf("%c passes\n", me);
            turn = him;
            continue;
        }
        pass = 0;

        if (turn == BLACK) {
            cputs("Your move rc (q to quit): ");
            ch1 = getc();
            if (ch1 == 'q' || ch1 == 'Q') break;
            ch2 = getc();
            if (ch1 < '1' || ch1 > '8' || ch2 < '1' || ch2 > '8') {
                cputs("Bad move\n");
                continue;
            }
            r = ch1 - '1';
            c = ch2 - '1';
            if (apply_move(r, c, me, him, 1) == 0) {
                cputs("Illegal\n");
                continue;
            }
        } else {
            ai_move(me, him, &r, &c);
            if (r >= 0) {
                apply_move(r, c, me, him, 1);
                cprintf("AI: %d%d\n", r + 1, c + 1);
            }
        }

        turn = him;
    }

    count_score(&b, &w);
    print_board();
    cprintf("Final *=%d O=%d\n", b, w);
}
