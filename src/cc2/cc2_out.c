/*
 * cc2_out.c — ASM output formatting
 *
 * Generates Z80 assembly text output.
 * Mirrors: A6225 template system, set_cseg/set_dseg, fprint_outfile
 */

#include "cc2_defs.h"
#include <stdarg.h>

/* ----------------------------------------------------------------
 *  Set code segment (cseg)
 *  Mirrors: set_cseg in CCC.ASM
 * ---------------------------------------------------------------- */
void out_set_cseg(Cc2State *cc)
{
    if (cc->cur_seg == 0) return; /* already cseg */
    io_write_str(cc, "\tcseg\n");
    cc->cur_seg = 0;
}

/* ----------------------------------------------------------------
 *  Set data segment (dseg)
 *  Mirrors: set_dseg in CCC.ASM
 * ---------------------------------------------------------------- */
void out_set_dseg(Cc2State *cc)
{
    if (cc->cur_seg == 1) return; /* already dseg */
    io_write_str(cc, "\tdseg\n");
    cc->cur_seg = 1;
}

/* ----------------------------------------------------------------
 *  Output a label at column 0 (no tab prefix)
 *  name followed by colon and newline
 * ---------------------------------------------------------------- */
void out_label(Cc2State *cc, const char *name)
{
    io_write_str(cc, name);
    io_write_str(cc, ":\n");
}

/* ----------------------------------------------------------------
 *  Output a string constant label: ?NNNNN:
 * ---------------------------------------------------------------- */
void out_str_label(Cc2State *cc, int num)
{
    char buf[16];
    snprintf(buf, sizeof(buf), "?%d", num);
    out_label(cc, buf);
}

/* ----------------------------------------------------------------
 *  Output a db byte value
 *  Groups up to 10 values per line.
 *  Mirrors: A0AC8 in CCC.ASM
 * ---------------------------------------------------------------- */
void out_db_byte(Cc2State *cc, int val)
{
    if (cc->db_count >= 10) {
        /* End current line and start fresh */
        io_write_newline(cc);
        cc->db_count = 0;
    }

    if (cc->db_count == 0) {
        /* Start new db line */
        io_write_str(cc, "\tdb\t");
    } else {
        /* Comma separator */
        io_write_byte(cc, ',');
    }

    io_write_decimal(cc, val);
    cc->db_count++;
}

/* ----------------------------------------------------------------
 *  Finish db output (newline if pending)
 * ---------------------------------------------------------------- */
void out_db_finish(Cc2State *cc)
{
    if (cc->db_count > 0) {
        io_write_newline(cc);
        cc->db_count = 0;
    }
}

/* ----------------------------------------------------------------
 *  Output an instruction with tab prefix
 *  out_instruction(cc, "ld", "bc,?63999")
 * ---------------------------------------------------------------- */
void out_instruction(Cc2State *cc, const char *mnemonic, const char *operands)
{
    io_write_byte(cc, '\t');
    io_write_str(cc, mnemonic);
    if (operands && operands[0]) {
        io_write_byte(cc, '\t');
        io_write_str(cc, operands);
    }
    io_write_newline(cc);
}

/* ----------------------------------------------------------------
 *  Output a comment line: ;<text>
 * ---------------------------------------------------------------- */
void out_comment(Cc2State *cc, const char *text)
{
    io_write_byte(cc, ';');
    io_write_str(cc, text);
    io_write_newline(cc);
}

/* ----------------------------------------------------------------
 *  Output public declaration
 * ---------------------------------------------------------------- */
void out_public(Cc2State *cc, const char *name)
{
    io_write_byte(cc, '\t');
    io_write_str(cc, "public");
    io_write_byte(cc, '\t');
    io_write_str(cc, name);
    io_write_newline(cc);
}

/* ----------------------------------------------------------------
 *  Output extrn declaration
 * ---------------------------------------------------------------- */
void out_extrn(Cc2State *cc, const char *name)
{
    io_write_byte(cc, '\t');
    io_write_str(cc, "extrn");
    io_write_byte(cc, '\t');
    io_write_str(cc, name);
    io_write_newline(cc);
}

/* ----------------------------------------------------------------
 *  Output end directive
 * ---------------------------------------------------------------- */
void out_end(Cc2State *cc)
{
    io_write_newline(cc);
    io_write_byte(cc, '\t');
    io_write_str(cc, "end");
    io_write_newline(cc);
}

/* ----------------------------------------------------------------
 *  Output raw string (no conversion)
 * ---------------------------------------------------------------- */
void out_raw(Cc2State *cc, const char *text)
{
    io_write_str(cc, text);
}
