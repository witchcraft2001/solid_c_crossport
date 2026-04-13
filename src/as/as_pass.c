/*
 * as_pass.c — Two-pass assembly processing
 *
 * Main loop for both passes. Reads lines, parses labels,
 * dispatches to instruction/directive handlers.
 *
 * Pass 1: define symbols, compute sizes
 * Pass 2: generate code, output REL file
 */

#include "as_defs.h"

/* Keyword type constants — must match as_symtab.c */
#define KW_INSTRUCTION  0x00
#define KW_DIRECTIVE    0x08
#define KW_REGISTER     0x10
#define KW_CONDITION    0x18
#define KW_OPERATOR     0x20

/* Directive code for END */
#define DIR_END_CODE    0x11

/* ----------------------------------------------------------------
 *  Initialize state for a pass
 * ---------------------------------------------------------------- */

void pass_init(AsmState *as)
{
    as->line_number = 0;
    as->error_char = ' ';
    as->error_msg_ptr = 0;
    as->error_msg_str = NULL;

    as->org_counter = 0;
    as->seg_type = SEG_CSEG;  /* default segment */

    if (!as->pass2) {
        /* Only reset sizes on pass 1 */
        as->aseg_size = 0;
        as->cseg_size = 0;
        as->dseg_size = 0;
        as->common_size = 0;
    }

    as->cond_depth = 0;
    as->cond_false_depth = 0;
    as->cond_state = 1;
    as->asm_enabled = 1;

    as->phase_active = 0;
    as->phase_offset = 0;

    as->include_active = 0;
    as->label_ptr = 0;

    as->org_flag = 0;
    as->radix = 10;

    /* File will be opened by pass_run */
}

/* ----------------------------------------------------------------
 *  Process a single source line
 *
 *  Line format:
 *    [label[:]]  [opcode  [operands]]  [;comment]
 *
 *  Steps:
 *  1. Check for label in column 1
 *  2. Parse opcode (instruction or directive keyword)
 *  3. Dispatch to handler
 * ---------------------------------------------------------------- */

void pass_process_line(AsmState *as)
{
    int ch;
    u8 saved_dispatch = 0;
    u8 saved_kw_type = 0;
    u8 saved_prefix = 0;
    int has_label = 0; (void)has_label;

    as->error_char = ' ';
    as->label_ptr = 0;

    /* Step 1: Check for label (starts in column 1, non-space) */
    ch = as->linebuf[0];

    if (ch == 0x0D || ch == ';' || ch == '*') {
        /* Empty line or comment — skip */
        return;
    }

    if (ch != ' ' && ch != '\t') {
        /* Potential label */
        as->line_pos = 0;
        {
            int tok = lex_token_copy(as);
            (void)tok;
        }

        if (as->idlen > 0) {
            /* Check for colon after label */
            ch = lex_nextchar(as);
            if (ch == ':') {
                /* Label with colon — skip it */
            } else {
                lex_pushback(as);
            }

            has_label = 1; /* used for future listing support */

            /* Look up or create the label in symbol table */
            if (!sym_search_user(as)) {
                sym_add_entry(as, 0);
            }

            /* Check if next token is EQU/SET/DEFL — those define the label differently */
            /* Save label info for now */
            u16 label_ptr_save = as->label_ptr;

            /* Peek at next token */
            u8 saved_idlen = as->idlen;
            u8 saved_idname[MAX_ID_LEN + 2];
            memcpy(saved_idname, as->idname, MAX_ID_LEN + 2);
            u16 saved_line_pos = as->line_pos;

            {
                int tok = lex_token_copy(as);
                (void)tok;
            }

            if (as->idlen > 0 && sym_search_keyword(as)) {
                if (as->op_type == KW_DIRECTIVE &&
                    (as->op_reg == 0x02 || as->op_reg == 0x03 ||
                     as->op_reg == 0x27)) {
                    /* EQU (0x02), DEFL (0x03), or SET (0x27) */
                    /* Don't define label as normal — the directive handles it */
                    as->label_ptr = label_ptr_save;
                    saved_dispatch = as->op_reg;
                    saved_kw_type = as->op_type;
                    saved_prefix = as->op_prefix;

                    /* Dispatch directive */
                    if (as->asm_enabled) {
                        dir_process(as, saved_dispatch);
                    }
                    return;
                }
            }

            /* Restore token state and define label at current PC */
            as->line_pos = saved_line_pos;
            as->idlen = saved_idlen;
            memcpy(as->idname, saved_idname, MAX_ID_LEN + 2);
            as->label_ptr = label_ptr_save;

            /* Define label at current location counter */
            if (as->asm_enabled) {
                sym_define_label(as, as->seg_type);
            }
        }
    } else {
        /* No label — position past leading whitespace */
        as->line_pos = 0;
    }

    /* Step 2: Parse opcode */
    {
        int tok = lex_token_copy(as);
        (void)tok;
    }

    if (as->idlen == 0) {
        /* No opcode on this line */
        return;
    }

    /* Step 3: Look up keyword and dispatch */
    if (sym_search_keyword(as)) {
        saved_kw_type = as->op_type;
        saved_dispatch = as->op_reg;
        saved_prefix = as->op_prefix;

        if (!as->asm_enabled) {
            /* Inside false conditional — only process IF/ELSE/ENDIF */
            if (saved_kw_type == KW_DIRECTIVE) {
                if (saved_dispatch == 0x12 || /* IF */
                    saved_dispatch == 0x13 || /* ELSE */
                    saved_dispatch == 0x14) { /* ENDIF */
                    dir_process(as, saved_dispatch);
                }
            }
            return;
        }

        switch (saved_kw_type) {
            case KW_INSTRUCTION:
                as->op_reg = saved_dispatch;
                as->op_prefix = saved_prefix;
                instr_process(as);
                break;

            case KW_DIRECTIVE:
                dir_process(as, saved_dispatch);
                break;

            default:
                /* Register name or condition code as opcode — error */
                err_syntax(as);
                break;
        }
    } else {
        /* Not a keyword — check if it's a macro call */
        if (as->asm_enabled && macro_is_defined(as)) {
            macro_expand(as);
        } else if (as->asm_enabled) {
            err_report(as, 'O', "Unknown opcode");
        }
    }
}

/* ----------------------------------------------------------------
 *  Run one complete pass over the source
 * ---------------------------------------------------------------- */

void pass_run(AsmState *as)
{
    int end_seen = 0;

    pass_init(as);

    /* Open source file */
    if (io_open_asm(as) != 0) {
        fatal_error(as, "Cannot open source file");
        return;
    }

    /* Pass 2: create REL file and write header */
    if (as->pass2) {
        if (io_create_rel(as) != 0) {
            fatal_error(as, "Cannot create REL file");
            io_close_asm(as);
            return;
        }

        /* Initialize REL bitstream */
        /* rel_init is in as_rel.c but not declared in as_defs.h.
         * We initialize manually. */
        as->rel_byte = 0;
        as->rel_bitcount = 0xF8;
        as->rel_ptr = 0;

        /* Write module name as first special item */
        /* TODO: Output module header item */
    }

    /* Reset macro state for this pass */
    macro_reset();

    /* Main assembly loop */
    while (!end_seen) {
        /* Read next line: from macro expansion or from file */
        if (macro_is_active()) {
            if (!macro_get_line(as)) {
                /* Macro ended, read from file */
                if (lex_read_line(as) < 0) {
                    err_report(as, 'N', "Missing END directive");
                    dir_do_end(as);
                    break;
                }
            }
        } else {
            if (lex_read_line(as) < 0) {
                err_report(as, 'N', "Missing END directive");
                dir_do_end(as);
                break;
            }
        }

        pass_process_line(as);

        /* Check if END directive was processed */
        /* After dir_do_end, we should stop */
        /* We detect this by checking if the line had END */
        {
            /* Peek at the line for END — a simple heuristic */
            /* In practice, dir_do_end sets up finalization,
             * and we detect end_seen by checking a flag.
             * For now, scan the linebuf. */
            u16 pos = 0;
            /* Skip leading spaces */
            while (as->linebuf[pos] == ' ' || as->linebuf[pos] == '\t')
                pos++;
            /* Skip label if present */
            if (as->linebuf[pos] != ' ' && as->linebuf[pos] != '\t' &&
                as->linebuf[pos] != 0x0D && as->linebuf[pos] != ';') {
                while (as->linebuf[pos] != ' ' && as->linebuf[pos] != '\t' &&
                       as->linebuf[pos] != ':' && as->linebuf[pos] != 0x0D)
                    pos++;
                if (as->linebuf[pos] == ':') pos++;
                while (as->linebuf[pos] == ' ' || as->linebuf[pos] == '\t')
                    pos++;
            }
            /* Check for END keyword */
            if ((as->linebuf[pos] == 'E' || as->linebuf[pos] == 'e') &&
                (as->linebuf[pos+1] == 'N' || as->linebuf[pos+1] == 'n') &&
                (as->linebuf[pos+2] == 'D' || as->linebuf[pos+2] == 'd')) {
                u8 next = as->linebuf[pos+3];
                if (next == ' ' || next == '\t' || next == 0x0D || next == ';') {
                    end_seen = 1;
                }
            }
        }

        /* Count and report errors for this line (mirrors A17FA) */
        if (as->error_char != ' ') {
            if (as->error_char == 'Q') {
                /* Warning */
                as->warning_count++;
            } else {
                /* Error */
                as->error_count++;
            }

            /* Print error on pass 2 */
            if (as->pass2) {
                io_print_str("line [");
                print_decimal(as->line_number);
                io_print_str("]: ?");
                io_print_char(as->error_char);
                io_print_char('\t');
                /* Print the source line */
                {
                    int k = 0;
                    while (as->linebuf[k] != 0x0D && k < LINE_BUF_SIZE) {
                        io_print_char(as->linebuf[k]);
                        k++;
                    }
                }
                io_newline();
                if (as->error_msg_str) {
                    io_print_str("      ");
                    io_print_str(as->error_msg_str);
                    io_newline();
                }
            }
        }
    }

    /* Clean up */
    io_close_asm(as);

    if (as->pass2) {
        io_close_rel(as);
    }

    /* Save segment sizes after pass */
    switch (as->seg_type) {
        case SEG_ASEG:  as->aseg_size = as->org_counter; break;
        case SEG_CSEG:  as->cseg_size = as->org_counter; break;
        case SEG_DSEG:  as->dseg_size = as->org_counter; break;
    }
}
