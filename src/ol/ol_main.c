/*
 * ol_main.c — Object Librarian entry point
 *
 * Port of OL1.ASM entry/start/command parsing.
 *
 * Usage: ol <option> <library-file> [<module-file> ...]
 * Options:
 *   A  - add modules to library
 *   D  - dump contents of library
 *   E  - extract modules from library
 *   L  - list library
 *   R  - reindex library
 *   T  - test unresolved externals
 */

#include "ol_defs.h"

static const char *title =
    "Object LIBRARIAN v0.02  Cross Port\n"
    "Based on OL version 1.00  (c) 1995, SOLiD Inc.\n";

static const char *usage_text =
    "Syntax: ol <option> <library-file> [<module-file> ...]\n"
    "options:\n"
    "\tA  - add modules to library\n"
    "\tD  - dump contents of library\n"
    "\tE  - extract modules from library\n"
    "\tL  - list library\n"
    "\tR  - reindex library\n"
    "\tT  - test unresolved externals\n";

void ol_fatal(OlState *ol, const char *msg)
{
    fprintf(stderr, "%s\n", msg);
    io_close_input(ol);
    io_close_output(ol);
    exit(1);
}

int main(int argc, char *argv[])
{
    OlState ol;
    memset(&ol, 0, sizeof(ol));

    printf("%s", title);

    if (argc < 3) {
        printf("%s", usage_text);
        return 1;
    }

    /* Parse option (first arg, single letter) */
    char opt = argv[1][0];
    if (opt >= 'a' && opt <= 'z') opt -= 0x20;

    if (opt != 'A' && opt != 'D' && opt != 'E' &&
        opt != 'L' && opt != 'R' && opt != 'T') {
        printf("%s", usage_text);
        return 1;
    }

    ol.option = opt;

    /* Library filename (second arg) */
    strncpy(ol.lib_filename, argv[2], MAX_FILENAME - 1);
    ol.lib_filename[MAX_FILENAME - 1] = 0;

    /* Module filenames (remaining args) */
    ol.module_count = 0;
    int i;
    for (i = 3; i < argc && ol.module_count < MAX_MODULES; i++) {
        ol.module_files[ol.module_count++] = argv[i];
    }

    /* Dispatch */
    switch (ol.option) {
        case 'A': op_add_modules(&ol);      break;
        case 'D': op_dump_library(&ol);      break;
        case 'E': op_extract_modules(&ol);   break;
        case 'L': op_list_modules(&ol);      break;
        case 'R': op_reindex(&ol);           break;
        case 'T': op_test_externals(&ol);    break;
    }

    return 0;
}
