/*
 * cc2_tmc.c — TMC token parser
 *
 * Reads TMC intermediate code file token by token.
 * Mirrors: A76D5, A76BB, A7728, A7731, A773B, A77A1 in CCC.ASM
 */

#include "cc2_defs.h"

/* ----------------------------------------------------------------
 *  Read next character from TMC file
 *  Mirrors: A76D5 in CCC.ASM
 *  Returns character, or 0x1A for EOF
 * ---------------------------------------------------------------- */
int tmc_read_char(Cc2State *cc)
{
    int ch;

    /* Check pushback buffer first */
    if (cc->pushback_count > 0) {
        ch = (u8)cc->pushback[--cc->pushback_count];
    } else if (cc->replay_buf) {
        /* Replay mode: read from buffer */
        if (cc->replay_pos >= cc->replay_len)
            ch = 0x1A; /* EOF */
        else
            ch = (u8)cc->replay_buf[cc->replay_pos++];
    } else {
        ch = io_read_byte(cc);
    }

    /* Track line/column */
    if (ch == '\n') {
        cc->tmc_line++;
        cc->tmc_col = 0;
    } else {
        cc->tmc_col++;
    }

    return ch;
}

/* ----------------------------------------------------------------
 *  Push back a character
 *  Mirrors: A76BB in CCC.ASM (accumulate/pushback)
 * ---------------------------------------------------------------- */
void tmc_pushback(Cc2State *cc, int ch)
{
    if (cc->pushback_count < (int)sizeof(cc->pushback)) {
        cc->pushback[cc->pushback_count++] = (char)ch;
    }
}

/* ----------------------------------------------------------------
 *  Peek at next character without consuming it
 * ---------------------------------------------------------------- */
int tmc_peek_char(Cc2State *cc)
{
    int ch = tmc_read_char(cc);
    tmc_pushback(cc, ch);
    return ch;
}

/* ----------------------------------------------------------------
 *  Skip to next line (discard rest of current line)
 *  Mirrors: A7728 in CCC.ASM
 * ---------------------------------------------------------------- */
void tmc_skip_line(Cc2State *cc)
{
    int ch;
    do {
        ch = tmc_read_char(cc);
    } while (ch != '\n' && ch != 0x1A);
}

/* ----------------------------------------------------------------
 *  Expect tab character
 *  Mirrors: A7731 in CCC.ASM
 * ---------------------------------------------------------------- */
void tmc_expect_tab(Cc2State *cc)
{
    int ch = tmc_read_char(cc);
    if (ch != '\t') {
        fprintf(stderr, "cc2: expected tab at line %d col %d, got 0x%02X\n",
                cc->tmc_line, cc->tmc_col, ch);
    }
}

/* ----------------------------------------------------------------
 *  Read token (identifier, number, etc.) until delimiter
 *  Mirrors: A773B in CCC.ASM
 *  Delimiters: tab, LF, comma, quote
 *  Returns length of token, stores in buf (null-terminated)
 *  The delimiter is pushed back.
 * ---------------------------------------------------------------- */
int tmc_read_token(Cc2State *cc, char *buf, int maxlen)
{
    int len = 0;
    int ch;

    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == '\t' || ch == '\n' || ch == ',' || ch == '"' || ch == 0x1A) {
            /* Delimiter found - push back */
            tmc_pushback(cc, ch);
            break;
        }
        if (len < maxlen - 1) {
            buf[len++] = (char)ch;
        }
    }
    buf[len] = '\0';
    return len;
}

/* ----------------------------------------------------------------
 *  Read decimal number from TMC
 *  Mirrors: A77A1 in CCC.ASM
 *  Reads a token, parses it as decimal (may be negative)
 * ---------------------------------------------------------------- */
int tmc_read_number(Cc2State *cc)
{
    char buf[32];
    tmc_read_token(cc, buf, sizeof(buf));

    int negative = 0;
    const char *p = buf;
    if (*p == '-') {
        negative = 1;
        p++;
    }

    int val = 0;
    while (*p >= '0' && *p <= '9') {
        val = val * 10 + (*p - '0');
        p++;
    }

    if (negative) val = -val;

    /* Return as 16-bit value (matching Z80 behavior) */
    return (i16)val;
}
