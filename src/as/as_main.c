/*
 * as_main.c — Entry point for the Z80 cross-assembler
 *
 * Command-line parsing and program flow:
 *   -t : truncate symbols to 6 characters
 *   -x : extended REL format (30-char symbols)
 *   -z : zero-fill DS areas
 *
 * Usage: as [-t] [-x] [-z] filename[.asm]
 *
 * Based on "Macro Assembler v1.5 (c) 1995, SOLiD"
 */

#include "as_defs.h"

/* Memory pool size: 64KB for symbol table + macro storage */
#define MEMORY_POOL_SIZE  65536

/* ----------------------------------------------------------------
 *  Error reporting functions
 * ---------------------------------------------------------------- */

void err_report(AsmState *as, char code, const char *msg)
{
    if (as->error_char == ' ') {
        as->error_char = (u8)code;
        as->error_msg_str = msg;
    }
    /* Note: error_count is incremented at end-of-line in pass_run,
     * not here. This matches the original A053F behavior. */
}

void err_out_of_range(AsmState *as)
{
    err_report(as, 'V', "Value out of range");
}

void err_syntax(AsmState *as)
{
    err_report(as, 'S', "Syntax error");
}

void err_undefined(AsmState *as)
{
    err_report(as, 'U', "Undefined symbol");
}

void err_duplicate(AsmState *as)
{
    err_report(as, 'M', "Multiply defined symbol");
}

void err_phase(AsmState *as)
{
    err_report(as, 'P', "Phase error");
}

void err_relocatable(AsmState *as)
{
    err_report(as, 'R', "Illegal relocation");
}

void err_external(AsmState *as)
{
    err_report(as, 'E', "Illegal external reference");
}

void err_number(AsmState *as)
{
    err_report(as, 'N', "Invalid number");
}

void err_value(AsmState *as)
{
    err_report(as, 'V', "Invalid value");
}

void err_warning(AsmState *as)
{
    as->warning_count++;
}

void err_mistake(AsmState *as)
{
    err_report(as, 'Q', "Mistake");
}

void err_divide_zero(AsmState *as)
{
    err_report(as, 'V', "Division by zero");
}

/* ----------------------------------------------------------------
 *  Fatal error — print message and exit
 * ---------------------------------------------------------------- */

void fatal_error(AsmState *as, const char *msg)
{
    (void)as;
    io_print_str("\r\nFatal: ");
    io_print_str(msg);
    io_newline();
    exit(0xFF);
}

/* ----------------------------------------------------------------
 *  Print decimal number (utility)
 * ---------------------------------------------------------------- */

void print_decimal(u16 value)
{
    char buf[8];
    int i = 0;

    if (value == 0) {
        io_print_char('0');
        return;
    }

    while (value > 0 && i < 7) {
        buf[i++] = '0' + (value % 10);
        value /= 10;
    }

    /* Print in reverse */
    while (i > 0) {
        io_print_char(buf[--i]);
    }
}

/* ----------------------------------------------------------------
 *  Build output filename (.asm -> .rel)
 * ---------------------------------------------------------------- */

static void build_rel_filename(AsmState *as)
{
    int i;
    int dot_pos = -1;

    /* Find last dot in filename */
    for (i = 0; as->asm_filename[i] && i < MAX_PATH_LEN; i++) {
        if (as->asm_filename[i] == '.') dot_pos = i;
    }

    if (dot_pos < 0) dot_pos = i; /* no extension */

    /* Copy base name */
    for (i = 0; i < dot_pos && i < MAX_PATH_LEN - 5; i++) {
        as->rel_filename[i] = as->asm_filename[i];
    }

    /* Add .rel extension */
    as->rel_filename[i++] = '.';
    as->rel_filename[i++] = 'r';
    as->rel_filename[i++] = 'e';
    as->rel_filename[i++] = 'l';
    as->rel_filename[i]   = 0;
}

/* ----------------------------------------------------------------
 *  Parse command-line arguments
 * ---------------------------------------------------------------- */

static int parse_args(AsmState *as, int argc, char **argv)
{
    int i;
    int got_filename = 0;

    for (i = 1; i < argc; i++) {
        if (argv[i][0] == '-') {
            switch (argv[i][1]) {
                case 't':
                case 'T':
                    as->opt_truncate6 = 1;
                    break;
                case 'x':
                case 'X':
                    as->opt_extended_rel = 1;
                    break;
                case 'z':
                case 'Z':
                    as->opt_zero_ds = 1;
                    break;
                default:
                    io_print_str("Unknown option: ");
                    io_print_str(argv[i]);
                    io_newline();
                    return -1;
            }
        } else {
            /* Filename */
            if (got_filename) {
                io_print_str("Too many filenames\r\n");
                return -1;
            }
            strncpy(as->asm_filename, argv[i], MAX_PATH_LEN - 1);
            as->asm_filename[MAX_PATH_LEN - 1] = 0;
            got_filename = 1;
        }
    }

    if (!got_filename) {
        io_print_str("Usage: as [-t] [-x] [-z] filename[.asm]\r\n");
        return -1;
    }

    /* Add .asm extension if missing */
    {
        int has_ext = 0;
        int len = (int)strlen(as->asm_filename);
        for (i = 0; i < len; i++) {
            if (as->asm_filename[i] == '.') has_ext = 1;
        }
        if (!has_ext && len < MAX_PATH_LEN - 5) {
            as->asm_filename[len++] = '.';
            as->asm_filename[len++] = 'a';
            as->asm_filename[len++] = 's';
            as->asm_filename[len++] = 'm';
            as->asm_filename[len]   = 0;
        }
    }

    return 0;
}

/* ----------------------------------------------------------------
 *  Main entry point
 * ---------------------------------------------------------------- */

int main(int argc, char **argv)
{
    AsmState as_state;
    AsmState *as = &as_state;

    /* Clear all state */
    memset(as, 0, sizeof(AsmState));

    /* Set defaults */
    as->radix = 10;
    as->asm_enabled = 1;
    as->cond_state = 1;

    /* Print banner */
    io_print_str("Solid C Macro Assembler v1.5 - Z80 Cross Port\r\n");

    /* Parse command line */
    if (parse_args(as, argc, argv) != 0) {
        return 0xFF;
    }

    /* Build output filename */
    build_rel_filename(as);

    /* Allocate memory pool */
    as->memory = (u8 *)malloc(MEMORY_POOL_SIZE);
    if (!as->memory) {
        io_print_str("Out of memory !\r\n");
        return 0xFF;
    }
    as->memory_size = MEMORY_POOL_SIZE;
    memset(as->memory, 0, MEMORY_POOL_SIZE);

    /* Initialize keyword tables */
    sym_init_keywords(as);

    /* Print filenames */
    io_print_str("Source: ");
    io_print_str(as->asm_filename);
    io_newline();
    io_print_str("Output: ");
    io_print_str(as->rel_filename);
    io_newline();

    /* ---- Pass 1 ---- */
    io_print_str("Pass 1...\r\n");
    as->pass2 = 0;
    as->error_count = 0;
    as->warning_count = 0;
    pass_run(as);

    io_print_str("Pass 1 complete: ");
    print_decimal(as->error_count);
    io_print_str(" errors\r\n");

    /* ---- Pass 2 ---- */
    io_print_str("Pass 2...\r\n");
    as->pass2 = 1;
    as->error_count = 0;
    as->warning_count = 0;
    pass_run(as);

    /* Print summary */
    io_newline();
    print_decimal(as->error_count);
    io_print_str(" error(s)");
    if (as->warning_count > 0) {
        io_print_str(", ");
        print_decimal(as->warning_count);
        io_print_str(" warning(s)");
    }
    io_newline();

    /* Print segment sizes */
    if (as->cseg_size > 0) {
        io_print_str("Code size: ");
        print_decimal(as->cseg_size);
        io_print_str(" bytes\r\n");
    }
    if (as->dseg_size > 0) {
        io_print_str("Data size: ");
        print_decimal(as->dseg_size);
        io_print_str(" bytes\r\n");
    }

    /* Clean up */
    free(as->memory);

    /* Exit code: 0 = success, 0xFF = errors */
    return (as->error_count > 0) ? 0xFF : 0;
}
