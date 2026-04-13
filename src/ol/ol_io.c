/*
 * ol_io.c — File I/O for Object Librarian
 *
 * Replaces IO.ASM routines: open_file, create_file, close_file,
 * read_file (1024-byte buffered reads), write_file (1024-byte buffered writes),
 * move_pointer (seek).
 */

#include "ol_defs.h"

/* ----------------------------------------------------------------
 *  Open input file for reading
 *  Mirrors: open_file in IO.ASM
 * ---------------------------------------------------------------- */
int io_open_input(OlState *ol, const char *filename)
{
    if (ol->fp_input) {
        fclose(ol->fp_input);
        ol->fp_input = NULL;
    }

    ol->fp_input = fopen(filename, "rb");
    if (!ol->fp_input) return -1;

    /* Reset read buffer */
    ol->in_pos = 0;
    ol->in_filled = 0;

    /* Reset REL reader state.
     * bit_count=0xFF so first rel_read_bit increments to 0x00
     * which triggers reading the first byte from file.
     * Mirrors: move_pointer in IO.ASM: ld hl,0FF00h; ld (D0D1E),hl */
    ol->rd.cur_byte = 0;
    ol->rd.bit_count = 0xFF;

    return 0;
}

/* ----------------------------------------------------------------
 *  Close input file
 *  Mirrors: close_file in IO.ASM
 * ---------------------------------------------------------------- */
void io_close_input(OlState *ol)
{
    if (ol->fp_input) {
        fclose(ol->fp_input);
        ol->fp_input = NULL;
    }
}

/* ----------------------------------------------------------------
 *  Read one byte from input (buffered)
 *  Mirrors: A016B in OL1.ASM
 * ---------------------------------------------------------------- */
u8 io_read_byte(OlState *ol)
{
    if (ol->in_pos >= ol->in_filled) {
        /* Refill buffer */
        ol->in_filled = (int)fread(ol->inbuf, 1, IO_BUF_SIZE, ol->fp_input);
        ol->in_pos = 0;
        if (ol->in_filled == 0) {
            /* EOF — return 0xFF as sentinel */
            return 0xFF;
        }
    }

    u8 byte = ol->inbuf[ol->in_pos++];
    ol->rel_size++;  /* track REL data size */
    return byte;
}

/* ----------------------------------------------------------------
 *  Seek in input file
 *  Mirrors: move_pointer in IO.ASM
 * ---------------------------------------------------------------- */
void io_seek_input(OlState *ol, long offset)
{
    fseek(ol->fp_input, offset, SEEK_SET);
    /* Reset read buffer */
    ol->in_pos = 0;
    ol->in_filled = 0;
    /* Reset REL reader state (0xFF triggers byte load on first read) */
    ol->rd.cur_byte = 0;
    ol->rd.bit_count = 0xFF;
    /* Reset rel_size counter (it was incremented by format detection) */
    ol->rel_size = 0;
}

/* ----------------------------------------------------------------
 *  Create output file for writing
 *  Mirrors: create_file in IO.ASM
 * ---------------------------------------------------------------- */
int io_create_output(OlState *ol, const char *filename)
{
    if (ol->fp_output) {
        fclose(ol->fp_output);
        ol->fp_output = NULL;
    }

    ol->fp_output = fopen(filename, "wb");
    if (!ol->fp_output) return -1;

    /* Reset write buffer */
    ol->out_pos = 0;

    /* Reset REL writer state */
    ol->wr.cur_byte = 0;
    ol->wr.bit_count = 0xF8;

    return 0;
}

/* ----------------------------------------------------------------
 *  Write one byte to output (buffered)
 *  Mirrors: write_file in OL1.ASM
 * ---------------------------------------------------------------- */
void io_write_byte(OlState *ol, u8 byte)
{
    ol->outbuf[ol->out_pos++] = byte;
    if (ol->out_pos >= IO_BUF_SIZE) {
        io_flush_output(ol);
    }
}

/* ----------------------------------------------------------------
 *  Flush output buffer to file
 *  Mirrors: A01EB in IO.ASM
 * ---------------------------------------------------------------- */
void io_flush_output(OlState *ol)
{
    if (ol->out_pos > 0 && ol->fp_output) {
        fwrite(ol->outbuf, 1, ol->out_pos, ol->fp_output);
        ol->out_pos = 0;
    }
}

/* ----------------------------------------------------------------
 *  Close output file (flush first)
 *  Mirrors: A0236 in IO.ASM
 * ---------------------------------------------------------------- */
void io_close_output(OlState *ol)
{
    io_flush_output(ol);
    if (ol->fp_output) {
        fclose(ol->fp_output);
        ol->fp_output = NULL;
    }
}
