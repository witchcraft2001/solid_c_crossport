/*
 * as_directives.c — Assembler directive handling
 *
 * Handles: ORG, EQU, DB, DW, DS, DC, ASEG, CSEG, DSEG, COMMON,
 * PUBLIC, EXTERN, ENTRY, INCLUDE, NAME, END, IF/ELSE/ENDIF,
 * MACRO/ENDM, .PHASE/.DEPHASE, .RADIX, etc.
 *
 * Directive dispatch codes match those defined in as_symtab.c.
 */

#include "as_defs.h"

/* Directive dispatch codes — must match as_symtab.c */
#define DIR_ORG     0x01
#define DIR_EQU     0x02
#define DIR_DEFL    0x03
#define DIR_DB      0x04
#define DIR_DW      0x05
#define DIR_DS      0x06
#define DIR_DC      0x07
#define DIR_ASEG    0x08
#define DIR_CSEG    0x09
#define DIR_DSEG    0x0A
#define DIR_COMMON  0x0B
#define DIR_PUBLIC  0x0C
#define DIR_EXTERN  0x0D
#define DIR_ENTRY   0x0E
#define DIR_EXT     0x0F
#define DIR_NAME    0x10
#define DIR_END     0x11
#define DIR_IF      0x12
#define DIR_ELSE    0x13
#define DIR_ENDIF   0x14
#define DIR_MACRO   0x15
#define DIR_ENDM    0x16
#define DIR_REPT    0x17
#define DIR_IRP     0x18
#define DIR_IRPC    0x19
#define DIR_EXITM   0x1A
#define DIR_LOCAL   0x1B
#define DIR_PHASE   0x1C
#define DIR_DEPHASE 0x1D
#define DIR_RADIX   0x1E
#define DIR_PAGE    0x1F
#define DIR_TITLE   0x20
#define DIR_SUBTTL  0x21
#define DIR_INCLUDE 0x22
#define DIR_COND    0x23
#define DIR_NOCOND  0x24
#define DIR_LIST    0x25
#define DIR_XLIST   0x26
#define DIR_SET     0x27

/* ----------------------------------------------------------------
 *  Helper: save current segment state
 * ---------------------------------------------------------------- */

static void save_segment_counter(AsmState *as)
{
    switch (as->seg_type) {
        case SEG_ASEG:  as->aseg_size = as->org_counter; break;
        case SEG_CSEG:  as->cseg_size = as->org_counter; break;
        case SEG_DSEG:  as->dseg_size = as->org_counter; break;
        case SEG_COMMON: as->common_size = as->org_counter; break;
    }
}

static void restore_segment_counter(AsmState *as)
{
    switch (as->seg_type) {
        case SEG_ASEG:  as->org_counter = as->aseg_size; break;
        case SEG_CSEG:  as->org_counter = as->cseg_size; break;
        case SEG_DSEG:  as->org_counter = as->dseg_size; break;
        case SEG_COMMON: as->org_counter = as->common_size; break;
    }
}

/* ----------------------------------------------------------------
 *  ORG directive
 *  ORG nn — set origin / location counter
 * ---------------------------------------------------------------- */

void dir_do_org(AsmState *as)
{
    u16 val = expr_eval_simple(as);
    as->org_counter = val;
    as->org_flag = 1;
}

/* ----------------------------------------------------------------
 *  EQU directive
 *  label EQU expression
 * ---------------------------------------------------------------- */

void dir_do_equ(AsmState *as)
{
    if (as->label_ptr == 0) {
        err_report(as, 'Q', "EQU without label");
        return;
    }

    u16 saved_label = as->label_ptr;
    u16 val = expr_eval_simple(as);
    as->label_ptr = saved_label;  /* restore after expr may have changed it */

    u8 *entry = &as->memory[as->label_ptr];

    if (as->pass2) {
        /* Pass 2: check value matches */
        u16 old_val = (u16)entry[6] | ((u16)entry[7] << 8);
        if (old_val != val) {
                err_phase(as);
        }
        entry[6] = val & 0xFF;
        entry[7] = (val >> 8) & 0xFF;
    } else {
        /* Pass 1: define the symbol */
        if (entry[5] & SYM_DEFINED) {
            err_duplicate(as);
            return;
        }
        entry[5] |= SYM_DEFINED | SYM_PASS1DEF;
        entry[5] = (entry[5] & ~0x07) | (as->expr_seg_type & 0x07);
        entry[6] = val & 0xFF;
        entry[7] = (val >> 8) & 0xFF;
    }
}

/* ----------------------------------------------------------------
 *  DB / DEFB directive
 *  DB expr [, expr | 'string' ...]
 * ---------------------------------------------------------------- */

void dir_do_db(AsmState *as)
{
    for (;;) {
        int ch = lex_skipspace(as);

        if (ch == 0x0D || ch == ';') {
            lex_pushback(as);
            break;
        }

        /* String constant */
        if (ch == '\'' || ch == '"') {
            int quote = ch;
            for (;;) {
                ch = lex_nextchar(as);
                if (ch == 0x0D) {
                    err_syntax(as);
                    lex_pushback(as);
                    return;
                }
                if (ch == quote) {
                    /* Check for doubled quote */
                    int next = lex_nextchar(as);
                    if (next != quote) {
                        lex_pushback(as);
                        break;
                    }
                }
                rel_output_code_byte(as, (u8)ch);
            }
        } else {
            /* Expression */
            lex_pushback(as);
            int val = expr_get_byte(as);
            rel_output_code_byte(as, (u8)(val & 0xFF));
        }

        /* Check for comma */
        ch = lex_skipspace(as);
        if (ch != ',') {
            lex_pushback(as);
            break;
        }
    }
}

/* ----------------------------------------------------------------
 *  DW / DEFW directive
 *  DW expr [, expr ...]
 * ---------------------------------------------------------------- */

void dir_do_dw(AsmState *as)
{
    for (;;) {
        int ch = lex_skipspace(as);

        if (ch == 0x0D || ch == ';') {
            lex_pushback(as);
            break;
        }

        lex_pushback(as);
        expr_evaluate(as);
        rel_put_word(as, as->expr_saved, as->expr_seg_type);

        /* Check for comma */
        ch = lex_skipspace(as);
        if (ch != ',') {
            lex_pushback(as);
            break;
        }
    }
}

/* ----------------------------------------------------------------
 *  DS / DEFS directive
 *  DS count [, fill]
 * ---------------------------------------------------------------- */

void dir_do_ds(AsmState *as)
{
    u16 count = expr_eval_simple(as);
    u8 fill = 0;

    /* Check for optional fill value */
    int ch = lex_skipspace(as);
    if (ch == ',') {
        fill = (u8)expr_get_byte(as);
    } else {
        lex_pushback(as);
    }

    /* Apply -z flag: zero fill if requested */
    if (as->opt_zero_ds) {
        fill = 0;
    }

    /* Emit bytes (or just advance PC in pass 1) */
    u16 i;
    for (i = 0; i < count; i++) {
        if (as->pass2 && as->opt_zero_ds) {
            rel_output_code_byte(as, fill);
        } else {
            as->org_counter++;
        }
    }
}

/* ----------------------------------------------------------------
 *  DC directive (define constant — null-terminated string)
 *  DC 'string'
 * ---------------------------------------------------------------- */

static void dir_do_dc(AsmState *as)
{
    int ch = lex_skipspace(as);

    if (ch == '\'' || ch == '"') {
        int quote = ch;
        u8 last_byte = 0;
        int count = 0;

        for (;;) {
            ch = lex_nextchar(as);
            if (ch == 0x0D) {
                err_syntax(as);
                lex_pushback(as);
                break;
            }
            if (ch == quote) {
                int next = lex_nextchar(as);
                if (next != quote) {
                    lex_pushback(as);
                    break;
                }
            }
            /* Output previous byte (if any) */
            if (count > 0) {
                rel_output_code_byte(as, last_byte);
            }
            last_byte = (u8)ch;
            count++;
        }

        /* Output last byte with high bit set */
        if (count > 0) {
            rel_output_code_byte(as, last_byte | 0x80);
        }
    } else {
        lex_pushback(as);
        err_syntax(as);
    }
}

/* ----------------------------------------------------------------
 *  ASEG / CSEG / DSEG directives
 * ---------------------------------------------------------------- */

static void dir_do_aseg(AsmState *as)
{
    save_segment_counter(as);
    as->seg_type = SEG_ASEG;
    restore_segment_counter(as);
}

static void dir_do_cseg(AsmState *as)
{
    save_segment_counter(as);
    as->seg_type = SEG_CSEG;
    restore_segment_counter(as);
}

static void dir_do_dseg(AsmState *as)
{
    save_segment_counter(as);
    as->seg_type = SEG_DSEG;
    restore_segment_counter(as);
}

/* ----------------------------------------------------------------
 *  COMMON directive
 *  COMMON /name/ [size]
 * ---------------------------------------------------------------- */

static void dir_do_common(AsmState *as)
{
    /* TODO: Full implementation requires COMMON block management.
     * Needs to parse /name/, look up or create the common block
     * in the symbol table, and switch segment context. */

    int ch = lex_skipspace(as);
    if (ch != '/') {
        err_syntax(as);
        lex_pushback(as);
        return;
    }

    /* Read common block name */
    lex_token_copy(as);

    ch = lex_skipspace(as);
    if (ch != '/') {
        err_syntax(as);
        lex_pushback(as);
    }

    save_segment_counter(as);
    as->seg_type = SEG_COMMON;
    as->org_counter = 0;
}

/* ----------------------------------------------------------------
 *  PUBLIC / GLOBAL / ENTRY directive
 *  PUBLIC name [, name ...]
 * ---------------------------------------------------------------- */

static void dir_do_public(AsmState *as)
{
    for (;;) {
        int ch = lex_skipspace(as);
        if (ch == 0x0D || ch == ';') {
            lex_pushback(as);
            break;
        }

        lex_pushback(as);
        lex_token_copy(as);

        if (as->idlen == 0) {
            err_syntax(as);
            break;
        }

        /* Look up or create symbol */
        if (!sym_search_user(as)) {
            sym_add_entry(as, 0);
        }

        /* Mark as public */
        u8 *entry = &as->memory[as->label_ptr];
        entry[5] |= SYM_PUBLIC;
        /* Entry point items are output by dir_do_end after all code */

        /* Check for comma */
        ch = lex_skipspace(as);
        if (ch != ',') {
            lex_pushback(as);
            break;
        }
    }
}

/* ----------------------------------------------------------------
 *  EXTERN / EXTRN / EXT directive
 *  EXTERN name [, name ...]
 * ---------------------------------------------------------------- */

static void dir_do_extern(AsmState *as)
{
    for (;;) {
        int ch = lex_skipspace(as);
        if (ch == 0x0D || ch == ';') {
            lex_pushback(as);
            break;
        }

        lex_pushback(as);
        lex_token_copy(as);

        if (as->idlen == 0) {
            err_syntax(as);
            break;
        }

        /* Look up or create symbol */
        if (!sym_search_user(as)) {
            sym_add_entry(as, 1); /* carry_flag=1 means external */
        }

        /* Mark as external */
        u8 *entry = &as->memory[as->label_ptr];
        entry[5] |= SYM_EXTERN;
        /* Chain external items are output by dir_do_end after all code */

        ch = lex_skipspace(as);
        if (ch != ',') {
            lex_pushback(as);
            break;
        }
    }
}

/* ----------------------------------------------------------------
 *  NAME directive
 *  NAME ('module_name')
 * ---------------------------------------------------------------- */

static void dir_do_name(AsmState *as)
{
    int ch = lex_skipspace(as);
    if (ch != '(') {
        lex_pushback(as);
        /* NAME without parens — use next token as name */
        lex_token_copy(as);
        if (as->idlen > 0) {
            int i;
            for (i = 0; i < 8 && i < as->idlen; i++) {
                as->module_name[i] = as->idname[i];
            }
            as->module_name[i] = 0;
        }
        return;
    }

    ch = lex_skipspace(as);
    if (ch != '\'') {
        lex_pushback(as);
        err_syntax(as);
        return;
    }

    int i = 0;
    for (;;) {
        ch = lex_nextchar(as);
        if (ch == 0x0D || ch == '\'') break;
        if (i < 8) {
            as->module_name[i++] = (u8)ch;
        }
    }
    as->module_name[i] = 0;

    ch = lex_skipspace(as);
    if (ch != ')') {
        lex_pushback(as);
    }
}

/* ----------------------------------------------------------------
 *  END directive
 *  END [start_address]
 * ---------------------------------------------------------------- */

static int end_called_pass2 = 0; /* prevent double finalize */

void dir_do_end(AsmState *as)
{
    if (as->pass2 && end_called_pass2) return; /* already finalized */
    if (as->pass2) end_called_pass2 = 1;

    /* Save current segment size */
    save_segment_counter(as);

    /* Check for optional start address */
    int ch = lex_skipspace(as);
    u16 start_addr = 0;
    u8 start_seg = 0;
    u8 has_start = 0;

    if (ch != 0x0D && ch != ';') {
        lex_pushback(as);
        u16 saved_lp = as->label_ptr;
        expr_evaluate(as);
        as->label_ptr = saved_lp;
        start_addr = as->expr_saved;
        start_seg = as->expr_seg_type & 3;
        has_start = 1;
    } else {
        lex_pushback(as);
    }

    if (!as->pass2) {
        /* ---- End of Pass 1 ----
         * Generate module header in REL bitstream:
         *   1. Program name
         *   2. PUBLIC entry symbols
         *   3. Common block sizes
         *   4. Data size
         *   5. Code size
         * This is written at the start of the REL file for pass 2.
         * We need to remember these values for pass 2.
         */

        /* Build module name from ASM filename if not set by NAME directive */
        if (as->module_name[0] == 0) {
            /* Extract basename from asm_filename */
            const char *p = as->asm_filename;
            const char *base = p;
            while (*p) {
                if (*p == '/' || *p == '\\') base = p + 1;
                p++;
            }
            int i = 0;
            while (base[i] && base[i] != '.' && i < 6) {
                u8 c = (u8)base[i];
                if (c >= 'a' && c <= 'z') c -= 0x20;
                as->module_name[i] = c;
                i++;
            }
            as->module_name[i] = 0;
        }

        /* Save start address for pass 2 */
        as->expr_saved = start_addr;
        as->expr_seg_type = start_seg;
    } else {
        /* ---- End of Pass 2 ----
         * After all code output, write:
         * 1. chain external (item 6) for each EXTRN symbol
         * 2. define entry point (item 7) for each PUBLIC symbol
         * 3. end program (item 14) with optional entry point
         * 4. end file (item 15)
         */

        /* Scan symbol table for EXTERN symbols → chain external (item 6)
         * The chain address in entry[6,7] was set by expr_evaluate
         * during pass 2 when the EXTRN symbol was referenced. */
        {
            int h;
            for (h = 0; h < 33; h++) {
                u16 ptr = as->sym_lookup1[h];
                while (ptr != 0) {
                    u8 *entry = &as->memory[ptr];
                    u8 attr = entry[5];
                    if (attr & SYM_EXTERN) {
                        u16 save_lp = as->label_ptr;
                        as->label_ptr = ptr;
                        u16 val = (u16)entry[6] | ((u16)entry[7] << 8);
                        rel_put_spec_item(as, 6, SEG_CSEG, val);
                        as->label_ptr = save_lp;
                    }
                    ptr = (u16)entry[0] | ((u16)entry[1] << 8);
                }
            }
        }

        /* Scan for PUBLIC symbols → define entry point (item 7)
         * Only locally-defined PUBLIC symbols (not extern). */
        {
            int h;
            for (h = 0; h < 33; h++) {
                u16 ptr = as->sym_lookup1[h];
                while (ptr != 0) {
                    u8 *entry = &as->memory[ptr];
                    u8 attr = entry[5];
                    if ((attr & SYM_PUBLIC) && (attr & SYM_DEFINED) &&
                        !(attr & SYM_EXTERN)) {
                        u16 save_lp = as->label_ptr;
                        as->label_ptr = ptr;
                        u16 val = (u16)entry[6] | ((u16)entry[7] << 8);
                        u8 seg = attr & 3;
                        rel_put_spec_item(as, 7, seg, val);
                        as->label_ptr = save_lp;
                    }
                    ptr = (u16)entry[0] | ((u16)entry[1] << 8);
                }
            }
        }

        /* End program (item 14) with optional entry point */
        rel_put_spec_item(as, 14, start_seg,
                          has_start ? start_addr : 0);

        /* Finalize REL file */
        rel_finalize(as);
    }
}

/* ----------------------------------------------------------------
 *  INCLUDE directive
 *  INCLUDE filename
 * ---------------------------------------------------------------- */

void dir_do_include(AsmState *as)
{
    int ch = lex_skipspace(as);
    char filename[MAX_PATH_LEN];
    int i = 0;

    /* Handle quoted filename */
    if (ch == '\'' || ch == '"') {
        int quote = ch;
        for (;;) {
            ch = lex_nextchar(as);
            if (ch == quote || ch == 0x0D) break;
            if (i < MAX_PATH_LEN - 1) {
                filename[i++] = (char)ch;
            }
        }
    } else {
        /* Unquoted filename — read until space/EOL */
        if (ch != 0x0D && ch != ';') {
            filename[i++] = (char)ch;
        }
        while (i < MAX_PATH_LEN - 1) {
            ch = lex_nextchar(as);
            if (ch == 0x0D || ch == ';' || ch == ' ' || ch == '\t') {
                lex_pushback(as);
                break;
            }
            filename[i++] = (char)ch;
        }
    }
    filename[i] = 0;

    if (i == 0) {
        err_syntax(as);
        return;
    }

    /* Open include file */
    if (io_open_include(as, filename) != 0) {
        err_report(as, 'F', "Include file not found");
        return;
    }

    as->include_active = 0xFF;
}

/* ----------------------------------------------------------------
 *  IF / ELSE / ENDIF directives
 * ---------------------------------------------------------------- */

static void dir_do_if(AsmState *as)
{
    u16 val = expr_eval_simple(as);

    if (as->cond_depth >= MAX_COND_DEPTH) {
        err_report(as, 'N', "IF nesting too deep");
        return;
    }

    as->cond_stack[as->cond_depth] = as->cond_state;
    as->cond_depth++;

    if (val == 0) {
        /* Condition false */
        as->cond_false_depth++;
        as->asm_enabled = 0;
    }
    as->cond_state = (val != 0) ? 1 : 0;
}

static void dir_do_else(AsmState *as)
{
    if (as->cond_depth == 0) {
        err_report(as, 'N', "ELSE without IF");
        return;
    }

    if (as->cond_state) {
        /* Was true, now false */
        as->cond_false_depth++;
        as->asm_enabled = 0;
        as->cond_state = 0;
    } else {
        /* Was false, now true (if not nested in another false) */
        if (as->cond_false_depth > 0) {
            as->cond_false_depth--;
        }
        as->asm_enabled = (as->cond_false_depth == 0) ? 1 : 0;
        as->cond_state = 1;
    }
}

static void dir_do_endif(AsmState *as)
{
    if (as->cond_depth == 0) {
        err_report(as, 'N', "ENDIF without IF");
        return;
    }

    as->cond_depth--;
    if (!as->cond_state && as->cond_false_depth > 0) {
        as->cond_false_depth--;
    }
    as->cond_state = as->cond_stack[as->cond_depth];
    as->asm_enabled = (as->cond_false_depth == 0) ? 1 : 0;
}

/* ----------------------------------------------------------------
 *  MACRO / ENDM / REPT / IRP / IRPC / EXITM / LOCAL
 *  TODO: Full macro support requires complex state management
 *  matching the original macro expansion engine.
 * ---------------------------------------------------------------- */

static void dir_do_macro(AsmState *as)
{
    macro_define(as);
}

static void dir_do_endm(AsmState *as)
{
    /* ENDM outside macro expansion — error */
    err_report(as, 'N', "ENDM without MACRO");
    (void)as;
}

static void dir_do_rept(AsmState *as)
{
    macro_rept(as);
}

static void dir_do_irp(AsmState *as)
{
    macro_irp(as);
}

static void dir_do_irpc(AsmState *as)
{
    macro_irpc(as);
}

static void dir_do_exitm(AsmState *as)
{
    macro_exitm(as);
}

static void dir_do_local(AsmState *as)
{
    /* LOCAL is handled inside macro_read_line during expansion.
     * If we get here, we're outside a macro. */
    err_report(as, 'N', "LOCAL outside macro");
    (void)as;
}

/* ----------------------------------------------------------------
 *  .PHASE / .DEPHASE directives
 * ---------------------------------------------------------------- */

static void dir_do_phase(AsmState *as)
{
    u16 val = expr_eval_simple(as);

    as->phase_active = 1;
    as->phase_offset = val - as->org_counter;
    as->phase_seg = as->expr_seg_type;
}

static void dir_do_dephase(AsmState *as)
{
    as->phase_active = 0;
    as->phase_offset = 0;
}

/* ----------------------------------------------------------------
 *  .RADIX directive
 *  .RADIX n (set default number base: 2, 8, 10, 16)
 * ---------------------------------------------------------------- */

static void dir_do_radix(AsmState *as)
{
    /* Parse radix value — always in decimal regardless of current radix */
    u8 saved = as->radix;
    as->radix = 10;
    u16 val = expr_eval_simple(as);
    as->radix = saved;

    if (val == 2 || val == 8 || val == 10 || val == 16) {
        as->radix = (u8)val;
    } else {
        err_value(as);
    }
}

/* ----------------------------------------------------------------
 *  SET directive (re-definable equate)
 *  label SET expression (like DEFL)
 * ---------------------------------------------------------------- */

static void dir_do_set(AsmState *as)
{
    if (as->label_ptr == 0) {
        err_report(as, 'Q', "SET without label");
        return;
    }

    u16 val = expr_eval_simple(as);

    u8 *entry = &as->memory[as->label_ptr];
    entry[5] |= SYM_DEFINED;
    entry[5] = (entry[5] & ~0x07) | (as->expr_seg_type & 0x07);
    entry[6] = val & 0xFF;
    entry[7] = (val >> 8) & 0xFF;
}

/* ----------------------------------------------------------------
 *  Listing directives (.PAGE, .TITLE, .SUBTTL, .LIST, .XLIST,
 *  .COND, .NOCOND) — no-ops for cross-assembler
 * ---------------------------------------------------------------- */

static void dir_do_nop(AsmState *as)
{
    /* Skip to end of line */
    (void)as;
}

/* ----------------------------------------------------------------
 *  Directive dispatch
 * ---------------------------------------------------------------- */

void dir_process(AsmState *as, u8 directive_code)
{
    switch (directive_code) {
        case DIR_ORG:     dir_do_org(as);     break;
        case DIR_EQU:     dir_do_equ(as);     break;
        case DIR_DEFL:    dir_do_set(as);     break;  /* DEFL = SET */
        case DIR_DB:      dir_do_db(as);      break;
        case DIR_DW:      dir_do_dw(as);      break;
        case DIR_DS:      dir_do_ds(as);      break;
        case DIR_DC:      dir_do_dc(as);      break;
        case DIR_ASEG:    dir_do_aseg(as);    break;
        case DIR_CSEG:    dir_do_cseg(as);    break;
        case DIR_DSEG:    dir_do_dseg(as);    break;
        case DIR_COMMON:  dir_do_common(as);  break;
        case DIR_PUBLIC:  dir_do_public(as);  break;
        case DIR_EXTERN:  dir_do_extern(as);  break;
        case DIR_ENTRY:   dir_do_public(as);  break;  /* ENTRY = PUBLIC */
        case DIR_EXT:     dir_do_extern(as);  break;  /* EXT = EXTERN */
        case DIR_NAME:    dir_do_name(as);    break;
        case DIR_END:     dir_do_end(as);     break;
        case DIR_IF:      dir_do_if(as);      break;
        case DIR_ELSE:    dir_do_else(as);    break;
        case DIR_ENDIF:   dir_do_endif(as);   break;
        case DIR_MACRO:   dir_do_macro(as);   break;
        case DIR_ENDM:    dir_do_endm(as);    break;
        case DIR_REPT:    dir_do_rept(as);    break;
        case DIR_IRP:     dir_do_irp(as);     break;
        case DIR_IRPC:    dir_do_irpc(as);    break;
        case DIR_EXITM:   dir_do_exitm(as);   break;
        case DIR_LOCAL:   dir_do_local(as);   break;
        case DIR_PHASE:   dir_do_phase(as);   break;
        case DIR_DEPHASE: dir_do_dephase(as); break;
        case DIR_RADIX:   dir_do_radix(as);   break;
        case DIR_INCLUDE: dir_do_include(as); break;
        case DIR_SET:     dir_do_set(as);     break;

        /* Listing directives — no-ops */
        case DIR_PAGE:
        case DIR_TITLE:
        case DIR_SUBTTL:
        case DIR_COND:
        case DIR_NOCOND:
        case DIR_LIST:
        case DIR_XLIST:
            dir_do_nop(as);
            break;

        default:
            err_report(as, 'N', "Unknown directive");
            break;
    }
}
