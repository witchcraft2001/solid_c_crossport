#include <stdio.h>

#define W 12
#define H 12
#define WALL '#'
#define EMPTY '.'
#define GEM '*'
#define BALL 'o'
#define BOX 'X'

char board[W * H];
int ball_pos;
int box_pos;
int mode_box;

void init_level()
{
    int x, y, p;
    for (y = 0; y < H; ++y) {
        for (x = 0; x < W; ++x) {
            p = y * W + x;
            if (x == 0 || y == 0 || x == W - 1 || y == H - 1) board[p] = WALL;
            else board[p] = EMPTY;
        }
    }

    board[3 * W + 3] = GEM;
    board[3 * W + 8] = GEM;
    board[8 * W + 2] = GEM;
    board[8 * W + 9] = GEM;
    board[5 * W + 6] = GEM;

    ball_pos = 1 * W + 1;
    box_pos = 10 * W + 10;
}

int remaining_gems()
{
    int i, c;
    c = 0;
    for (i = 0; i < W * H; ++i) if (board[i] == GEM) ++c;
    return c;
}

void draw_board()
{
    int x, y, p;
    putchar('\n');
    for (y = 0; y < H; ++y) {
        for (x = 0; x < W; ++x) {
            p = y * W + x;
            if (p == ball_pos) putchar(BALL);
            else if (p == box_pos) putchar(BOX);
            else putchar(board[p]);
        }
        putchar('\n');
    }
    printf("Gems left: %d\n", remaining_gems());
    printf("Mode: %s (space toggles)\n", mode_box ? "BOX" : "BALL");
    puts("Move: wasd, retry:r, quit:q");
}

int can_enter(pos, is_ball)
int pos;
int is_ball;
{
    if (board[pos] == WALL) return 0;
    if (!is_ball && board[pos] == GEM) return 0;
    return 1;
}

void slide(dir)
int dir;
{
    int *obj;
    int is_ball;
    int cur, nxt;

    obj = mode_box ? &box_pos : &ball_pos;
    is_ball = mode_box ? 0 : 1;

    while (1) {
        cur = *obj;
        nxt = cur + dir;

        if (!can_enter(nxt, is_ball)) break;
        if (nxt == (mode_box ? ball_pos : box_pos)) break;

        *obj = nxt;
        if (is_ball && board[nxt] == GEM) board[nxt] = EMPTY;
    }
}

int main()
{
    int ch;

    init_level();
    mode_box = 0;

    while (1) {
        draw_board();
        if (remaining_gems() == 0) {
            puts("You win!");
            break;
        }

        ch = getchar();
        if (ch == 'q' || ch == 'Q') break;
        if (ch == 'r' || ch == 'R') {
            init_level();
            mode_box = 0;
            continue;
        }
        if (ch == ' ') {
            mode_box ^= 1;
            continue;
        }

        if (ch == 'w' || ch == 'W') slide(-W);
        else if (ch == 's' || ch == 'S') slide(W);
        else if (ch == 'a' || ch == 'A') slide(-1);
        else if (ch == 'd' || ch == 'D') slide(1);
    }

    return 0;
}
