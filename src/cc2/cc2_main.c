/*
 * cc2_main.c — Entry point for CC2 Code Generator
 *
 * Mirrors: start label + AA05D in CCC.ASM
 * Usage: cc2 [options] <filename.tmc>
 */

#include "cc2_defs.h"

void cc2_fatal(Cc2State *cc, const char *msg)
{
    fprintf(stderr, "cc2: %s\n", msg);
    io_close_input(cc);
    io_close_output(cc);
    exit(1);
}

/* ----------------------------------------------------------------
 *  Build filename with default extension
 *  Mirrors: A9E9F in CCC.ASM
 * ---------------------------------------------------------------- */
static void build_filename(const char *input, const char *default_ext,
                           char *output, int maxlen)
{
    int len = (int)strlen(input);
    int has_dot = 0;
    int i;

    for (i = 0; i < len; i++) {
        if (input[i] == '.') { has_dot = 1; break; }
    }

    if (has_dot) {
        strncpy(output, input, maxlen - 1);
        output[maxlen - 1] = '\0';
    } else {
        snprintf(output, maxlen, "%s%s", input, default_ext);
    }
}

/* ----------------------------------------------------------------
 *  Build ASM filename from TMC filename
 *  Replace .TMC with .ASM (or add .ASM)
 * ---------------------------------------------------------------- */
static void build_asm_filename(const char *tmc_name, char *asm_name, int maxlen)
{
    int len = (int)strlen(tmc_name);
    int dot_pos = -1;
    int i;

    for (i = len - 1; i >= 0; i--) {
        if (tmc_name[i] == '.') { dot_pos = i; break; }
        if (tmc_name[i] == '/' || tmc_name[i] == '\\') break;
    }

    if (dot_pos >= 0) {
        /* Copy up to dot, add .ASM */
        int copylen = dot_pos;
        if (copylen >= maxlen - 5) copylen = maxlen - 5;
        memcpy(asm_name, tmc_name, copylen);
        strcpy(asm_name + copylen, ".ASM");
    } else {
        snprintf(asm_name, maxlen, "%s.ASM", tmc_name);
    }
}

int main(int argc, char **argv)
{
    Cc2State cc;
    memset(&cc, 0, sizeof(cc));

    /* Defaults */
    cc.underscore_char = '_';
    cc.str_label = STRING_LABEL_START;
    cc.cur_seg = -1;
    cc.func_name_pos = -1;

    /* Parse command line */
    const char *input_file = NULL;
    int explicit_output = 0;
    int i;

    for (i = 1; i < argc; i++) {
        if (argv[i][0] == '-') {
            switch (argv[i][1]) {
                case 'k': case 'K':
                    cc.opt_keep_tmc = 1;
                    break;
                case 'q': case 'Q':
                    cc.opt_quiet = 1;
                    break;
                case 'o': case 'O':
                    strncpy(cc.asm_filename, argv[i] + 2, MAX_FILENAME - 1);
                    explicit_output = 1;
                    break;
                case 'r': case 'R':
                    cc.table_size = atoi(argv[i] + 2);
                    break;
                case 'u': case 'U':
                    cc.underscore_char = argv[i][2];
                    break;
                default:
                    fprintf(stderr, "cc2: bad option: %c\n", argv[i][1]);
                    break;
            }
        } else {
            input_file = argv[i];
        }
    }

    if (!input_file) {
        fprintf(stderr,
            "syntax: cc2 [options] <filename>\n"
            "options:\n"
            "\t-k         don't delete *.tmc file\n"
            "\t-o<name>   set explicit output name\n"
            "\t-r<number> set symbol table size\n"
            "\t-u<char>   set character to replace underscore\n"
            "\t-q         quiet mode, no progress indicator\n");
        return 0xFF;
    }

    /* Build TMC filename (add .TMC if no extension) */
    build_filename(input_file, ".TMC", cc.tmc_filename, MAX_FILENAME);

    /* Build ASM filename if not specified */
    if (!explicit_output) {
        build_asm_filename(cc.tmc_filename, cc.asm_filename, MAX_FILENAME);
    }

    /* Open TMC input */
    if (io_open_input(&cc, cc.tmc_filename) < 0) {
        fprintf(stderr, "cc2: can't open: %s\n", cc.tmc_filename);
        return 0xFF;
    }

    /* Create ASM output */
    if (io_create_output(&cc, cc.asm_filename) < 0) {
        fprintf(stderr, "cc2: can't create: %s\n", cc.asm_filename);
        io_close_input(&cc);
        return 0xFF;
    }

    /* Process file */
    gen_process_file(&cc);

    /* Close files */
    io_close_input(&cc);
    io_close_output(&cc);

    return 0;
}
