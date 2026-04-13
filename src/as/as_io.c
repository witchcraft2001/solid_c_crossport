/*
 * as_io.c — File I/O for the Z80 assembler
 * Replaces RST 10h / DSS kernel calls with standard C file ops.
 */

#include "as_defs.h"

void io_print_char(char c)
{
    putchar(c);
}

void io_print_str(const char *str)
{
    while (*str) {
        putchar(*str);
        str++;
    }
}

void io_newline(void)
{
    putchar('\r');
    putchar('\n');
}

/* Open .asm input file */
int io_open_asm(AsmState *as)
{
    as->f_asm = fopen(as->asm_filename, "rb");
    if (!as->f_asm) return -1;
    as->asm_ptr = ASM_BUF_SIZE - 1; /* force initial read */
    return 0;
}

/* Close .asm file */
void io_close_asm(AsmState *as)
{
    if (as->f_asm) {
        fclose(as->f_asm);
        as->f_asm = NULL;
    }
}

/* Create .rel output file */
int io_create_rel(AsmState *as)
{
    as->f_rel = fopen(as->rel_filename, "wb");
    if (!as->f_rel) return -1;
    as->rel_ptr = 0;
    return 0;
}

/* Write 512-byte block of REL data */
static void io_write_rel_block(AsmState *as)
{
    if (as->rel_ptr == 0) return;
    size_t written = fwrite(as->outrel, 1, as->rel_ptr, as->f_rel);
    if (written != as->rel_ptr) {
        io_print_str("\r\nWrite error !\r\n");
        exit(1);
    }
    as->rel_ptr = 0;
}

/* Write a single byte to REL output buffer */
void io_write_rel_byte(AsmState *as, u8 byte)
{
    if (as->rel_ptr >= REL_BUF_SIZE) {
        io_write_rel_block(as);
    }
    as->outrel[as->rel_ptr++] = byte;
}

/* Flush remaining REL data and close */
void io_flush_rel(AsmState *as)
{
    if (as->rel_ptr > 0) {
        io_write_rel_block(as);
    }
}

void io_close_rel(AsmState *as)
{
    if (as->f_rel) {
        io_flush_rel(as);
        fclose(as->f_rel);
        as->f_rel = NULL;
    }
}

/* Read next byte from .asm file.
   Returns byte value, or -1 (0x1A) on EOF.
   Mirrors A427B: reads 1024-byte blocks. */
int io_read_asm_byte(AsmState *as)
{
    if (as->asm_ptr >= 1024) {
        /* Read next block */
        size_t n = fread(as->asm_buf, 1, 1024, as->f_asm);
        as->asm_buf[n] = 0x1A; /* EOF marker */
        as->asm_ptr = 0;
    }
    u8 ch = as->asm_buf[as->asm_ptr++];
    if (ch == 0x1A) return -1; /* EOF */
    return ch;
}

/* Open include file */
int io_open_include(AsmState *as, const char *name)
{
    /* Build filename - copy name, add .asm extension if missing */
    char buf[MAX_PATH_LEN];
    int i = 0, has_ext = 0;
    while (name[i] && i < MAX_PATH_LEN - 5) {
        buf[i] = name[i];
        if (name[i] == '.') has_ext = 1;
        if ((u8)name[i] < 0x21) break;
        i++;
    }
    if (!has_ext) {
        buf[i++] = '.';
        buf[i++] = 'A';
        buf[i++] = 'S';
        buf[i++] = 'M';
    }
    buf[i] = 0;

    /* Convert to lowercase for case-sensitive filesystems */
    strncpy(as->incl_filename, buf, MAX_PATH_LEN - 1);
    as->incl_filename[MAX_PATH_LEN - 1] = 0;

    as->f_incl = fopen(as->incl_filename, "rb");
    if (!as->f_incl) return -1;

    as->incl_counter = 0; /* will trigger initial read */
    return 0;
}

/* Read next byte from include file.
   Returns byte value, or -1 on EOF.
   Mirrors read_include: reads 64-byte blocks. */
int io_read_include_byte(AsmState *as)
{
    if (as->incl_counter == 0) {
        /* Read next 64-byte block */
        size_t n = fread(as->incl_buf, 1, 64, as->f_incl);
        as->incl_buf[n] = 0x1A; /* EOF marker */
        as->incl_ptr = 0;
        as->incl_counter = (u8)(n > 0 ? n : 0);
    }

    u8 ch = as->incl_buf[as->incl_ptr];
    if (ch == 0x1A) {
        /* EOF of include file */
        io_close_include(as);
        return -1;
    }
    as->incl_ptr++;
    if (as->incl_counter > 0) as->incl_counter--;
    return ch;
}

void io_close_include(AsmState *as)
{
    if (as->f_incl) {
        fclose(as->f_incl);
        as->f_incl = NULL;
    }
}
