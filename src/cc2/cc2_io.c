/*
 * cc2_io.c — File I/O for CC2 Code Generator
 *
 * Replaces IO2.ASM routines: read_byte, write_byte, open_file, create_file.
 * TMC input is text with CR+LF or LF line endings (CR skipped).
 * ASM output uses CR+LF line endings.
 */

#include "cc2_defs.h"

/* ----------------------------------------------------------------
 *  Open TMC input file
 * ---------------------------------------------------------------- */
int io_open_input(Cc2State *cc, const char *filename)
{
    if (cc->fp_input) {
        fclose(cc->fp_input);
        cc->fp_input = NULL;
    }

    cc->fp_input = fopen(filename, "rb");
    if (!cc->fp_input) return -1;

    cc->in_pos = 0;
    cc->in_filled = 0;
    cc->in_eof = 0;
    cc->tmc_line = 1;
    cc->tmc_col = 0;

    return 0;
}

/* ----------------------------------------------------------------
 *  Close TMC input file
 * ---------------------------------------------------------------- */
void io_close_input(Cc2State *cc)
{
    if (cc->fp_input) {
        fclose(cc->fp_input);
        cc->fp_input = NULL;
    }
}

/* ----------------------------------------------------------------
 *  Read one byte from TMC input (buffered)
 *  Mirrors: read_byte in IO2.ASM
 *  Skips CR (0x0D), returns 0x1A on EOF
 * ---------------------------------------------------------------- */
int io_read_byte(Cc2State *cc)
{
    for (;;) {
        if (cc->in_pos >= cc->in_filled) {
            /* Refill buffer */
            cc->in_filled = (int)fread(cc->inbuf, 1, IO_BUF_SIZE, cc->fp_input);
            cc->in_pos = 0;
            if (cc->in_filled == 0) {
                cc->in_eof = 1;
                return 0x1A; /* EOF marker */
            }
        }

        u8 byte = cc->inbuf[cc->in_pos++];
        if (byte == 0x0D) continue;  /* Skip CR, mirrors read_byte in IO2.ASM */
        if (byte == 0xFF) return 0x1A; /* EOF sentinel */
        return byte;
    }
}

/* ----------------------------------------------------------------
 *  Create ASM output file
 * ---------------------------------------------------------------- */
int io_create_output(Cc2State *cc, const char *filename)
{
    if (cc->fp_output) {
        fclose(cc->fp_output);
        cc->fp_output = NULL;
    }

    cc->fp_output = fopen(filename, "wb");
    if (!cc->fp_output) return -1;

    cc->out_pos = 0;
    return 0;
}

/* ----------------------------------------------------------------
 *  Write one byte to ASM output (buffered)
 *  Mirrors: write_byte in IO2.ASM
 * ---------------------------------------------------------------- */
void io_write_byte(Cc2State *cc, u8 byte)
{
    cc->outbuf[cc->out_pos++] = byte;
    if (cc->out_pos >= IO_BUF_SIZE) {
        io_flush_output(cc);
    }
}

/* ----------------------------------------------------------------
 *  Flush output buffer
 * ---------------------------------------------------------------- */
void io_flush_output(Cc2State *cc)
{
    if (cc->out_pos > 0 && cc->fp_output) {
        fwrite(cc->outbuf, 1, cc->out_pos, cc->fp_output);
        cc->out_pos = 0;
    }
}

/* ----------------------------------------------------------------
 *  Close output file
 * ---------------------------------------------------------------- */
void io_close_output(Cc2State *cc)
{
    io_flush_output(cc);
    if (cc->fp_output) {
        fclose(cc->fp_output);
        cc->fp_output = NULL;
    }
}

/* ----------------------------------------------------------------
 *  Write character to ASM output
 *  Mirrors: A7808 in CCC.ASM (without <...> function name handling)
 *  LF (0x0A) → CR+LF
 * ---------------------------------------------------------------- */
void io_write_char(Cc2State *cc, char ch)
{
    if (ch == '\n') {
        io_write_byte(cc, 0x0D);
    }
    io_write_byte(cc, (u8)ch);
}

/* ----------------------------------------------------------------
 *  Write null-terminated string to ASM output
 *  Mirrors: A7866 / fprint_outfile in CCC.ASM
 * ---------------------------------------------------------------- */
void io_write_str(Cc2State *cc, const char *s)
{
    while (*s) {
        io_write_char(cc, *s++);
    }
}

/* ----------------------------------------------------------------
 *  Write CR+LF newline
 * ---------------------------------------------------------------- */
void io_write_newline(Cc2State *cc)
{
    io_write_byte(cc, 0x0D);
    io_write_byte(cc, 0x0A);
}

/* ----------------------------------------------------------------
 *  Write decimal number (no leading zeros)
 *  Mirrors: A7873 in CCC.ASM
 * ---------------------------------------------------------------- */
void io_write_decimal(Cc2State *cc, int val)
{
    char buf[16];
    snprintf(buf, sizeof(buf), "%d", val);
    /* Write without CR/LF conversion (digits only) */
    const char *p = buf;
    while (*p) {
        io_write_byte(cc, (u8)*p++);
    }
}
