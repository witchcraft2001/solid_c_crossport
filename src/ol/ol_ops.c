/*
 * ol_ops.c — Library operations for Object Librarian
 *
 * Implements all 6 modes: Add, Dump, Extract, List, Reindex, Test
 *
 * Ported from OL1.ASM routines:
 *   add_module, dump_library, extracting_module,
 *   list_modules, reindexing, test_extrn_missing
 */

#include "ol_defs.h"

/* ----------------------------------------------------------------
 *  Helper: open input file, trying .IRL then .REL extension
 *  Mirrors: A03FB in OL1.ASM
 *
 *  The original code:
 *  1. Copies filename, uppercasing and finding the dot position
 *  2. If no extension given, tries .IRL first, then .REL
 *  3. For IRL files, reads the 2-byte header to find the REL data offset
 *  4. For REL files, offset is 0
 *
 *  Returns 0 on success, -1 on failure.
 *  Sets ol->fp_input ready to read REL bitstream.
 * ---------------------------------------------------------------- */
static int open_rel_file(OlState *ol, const char *filename)
{
    char buf[MAX_FILENAME];
    char *dot = NULL;
    int i;
    int is_irl_candidate = 0;

    /* Copy filename (preserve case for filesystem), find dot */
    for (i = 0; filename[i] && i < MAX_FILENAME - 5; i++) {
        buf[i] = filename[i];
        if (buf[i] == '.') dot = &buf[i];
    }
    buf[i] = 0;

    if (dot == NULL) {
        /* No extension — try .IRL first, then .REL */
        dot = &buf[i];

        strcpy(dot, ".IRL");
        if (io_open_input(ol, buf) == 0) {
            is_irl_candidate = 1;
            goto detect_format;
        }

        strcpy(dot, ".REL");
        if (io_open_input(ol, buf) == 0) {
            is_irl_candidate = 0;
            goto detect_format;
        }

        return -1;
    }

    /* Extension given — open directly */
    if (io_open_input(ol, buf) != 0) return -1;

    /* Check if it might be IRL based on extension */
    {
        char ext[8];
        int j;
        for (j = 0; dot[j] && j < 7; j++) {
            ext[j] = dot[j];
            if (ext[j] >= 'a' && ext[j] <= 'z') ext[j] -= 0x20;
        }
        ext[j] = 0;
        is_irl_candidate = (strcmp(ext, ".IRL") == 0);
    }

detect_format:
    /* Detect file format by reading first byte.
     * REL files: first bit = 1 (special item header for program name).
     * IRL files: first byte has bit 7 = 0 (index header).
     * Mirrors: A0429..A043C in OL1.ASM */
    {
        u8 first = io_read_byte(ol);
        long offset = 0;

        if ((first & 0x80) == 0) {
            /* Looks like IRL header (or REL starting with abs byte).
             * For IRL: second byte gives offset. */
            u8 second = io_read_byte(ol);
            /* Original: ld h,a; ld l,0; srl h; rr l → hl = second*128 */
            offset = (long)second * 128;
        }
        /* else: bit 7 = 1, this is REL data starting at offset 0 */

        /* Seek to REL data start (resets read buffer + bit state) */
        io_seek_input(ol, offset);
    }

    return 0;
}

/* ----------------------------------------------------------------
 *  Helper: copy entire REL stream from input to output
 *  Mirrors: A06A6 in OL1.ASM
 * ---------------------------------------------------------------- */
static void copy_rel_stream(OlState *ol)
{
    RelItem item;

    for (;;) {
        int type = rel_read_item(ol, &item);

        if (type == ITEM_BYTE) {
            /* Absolute byte */
            rel_write_abs_byte(ol, item.byte_val);
        } else if (type == ITEM_WORD) {
            /* Relocatable word */
            rel_write_rel_word(ol, item.word_val, item.seg_type);
        } else {
            /* Special item */
            if (item.item_code == 15) {
                /* End of file — stop copying */
                return;
            }
            rel_write_item(ol, &item);
        }
    }
}

/* ----------------------------------------------------------------
 *  Helper: print name from field_b
 * ---------------------------------------------------------------- */
static void print_field_b(const RelItem *item)
{
    int i;
    for (i = 0; i < item->field_b_len; i++) {
        char c = item->field_b[i] & 0x7F;
        if (c >= ' ') putchar(c);
        else putchar('.');
    }
}

/* ----------------------------------------------------------------
 *  Helper: print segment letter + hex value
 *  Mirrors: A0BBF in OL1.ASM
 * ---------------------------------------------------------------- */
static void print_seg_value(u8 seg, u16 val)
{
    static const char seg_letters[] = " PDC";
    if (seg > 0 && seg <= 3) {
        printf("%c:", seg_letters[seg]);
    }
    printf("%04Xh", val);
}

/* ----------------------------------------------------------------
 *  Helper: match module name against wildcard pattern
 *  Mirrors: compare in OL1.ASM
 * ---------------------------------------------------------------- */
static int match_name(const char *pattern, const u8 *name, int namelen)
{
    int i;
    for (i = 0; i < namelen && pattern[i]; i++) {
        if (pattern[i] == '*') return 1;  /* wildcard match */
        if (pattern[i] == '?') continue;  /* single char wildcard */
        char a = pattern[i];
        char b = name[i] & 0x7F;
        if (a >= 'a' && a <= 'z') a -= 0x20;
        if (b >= 'a' && b <= 'z') b -= 0x20;
        if (a != b) return 0;
    }
    /* If pattern is shorter than name, no match (unless ended with *) */
    if (pattern[i] == '*') return 1;
    return (i == namelen);
}


/* ================================================================
 *  T — Test for unresolved externals
 *  Mirrors: test_extrn_missing in OL1.ASM
 * ================================================================ */
void op_test_externals(OlState *ol)
{
    if (open_rel_file(ol, ol->lib_filename) != 0) {
        ol_fatal(ol, "File not found");
        return;
    }

    ol->ext_missing_flag = 0;
    RelItem item;

    for (;;) {
        int type = rel_read_item(ol, &item);
        if (type == ITEM_BYTE || type == ITEM_WORD) continue;

        /* Special items */
        if (item.item_code == 6) continue;  /* chain external — skip */
        if (item.item_code == 7) continue;  /* define entry — skip */
        if (item.item_code == 15) break;    /* end of file */
        /* All other items: continue */
    }

    if (ol->ext_missing_flag) {
        printf("Externals missing:\n");
        /* TODO: collect and print missing externals */
    }

    io_close_input(ol);
}


/* ================================================================
 *  A — Add modules to library
 *  Mirrors: add_module in OL1.ASM
 * ================================================================ */
void op_add_modules(OlState *ol)
{
    if (ol->module_count == 0) {
        fprintf(stderr, "No module files specified\n");
        return;
    }

    /* Create temporary output file */
    char tmpname[MAX_FILENAME];
    snprintf(tmpname, sizeof(tmpname), "%s.tmp", ol->lib_filename);

    if (io_create_output(ol, tmpname) != 0) {
        ol_fatal(ol, "Cannot create temp file");
        return;
    }

    /* Try to open existing library */
    int lib_exists = (open_rel_file(ol, ol->lib_filename) == 0);

    if (lib_exists) {
        printf("Updating library: %s\n", ol->lib_filename);
        /* Copy existing content (all modules) */
        copy_rel_stream(ol);
        io_close_input(ol);
    } else {
        printf("Creating new library: %s\n", ol->lib_filename);
    }

    /* Add each new module */
    int i;
    for (i = 0; i < ol->module_count; i++) {
        if (open_rel_file(ol, ol->module_files[i]) != 0) {
            fprintf(stderr, "%s : file not found\n", ol->module_files[i]);
            io_close_output(ol);
            remove(tmpname);
            return;
        }

        printf("Adding: %s\n", ol->module_files[i]);
        copy_rel_stream(ol);
        io_close_input(ol);
    }

    /* Write end-of-file markers (item 15, twice) */
    {
        rel_write_finalize(ol);
    }

    io_close_output(ol);

    /* Replace library with temp file */
    /* Build proper library filename with .IRL extension */
    {
        char libname[MAX_FILENAME];
        strncpy(libname, ol->lib_filename, sizeof(libname) - 1);
        libname[sizeof(libname) - 1] = 0;

        /* Add .IRL extension if none */
        char *dot = strrchr(libname, '.');
        if (dot == NULL) {
            strncat(libname, ".IRL", sizeof(libname) - strlen(libname) - 1);
        }

        remove(libname);
        rename(tmpname, libname);
    }

    /* Reindex the library */
    printf("Reindexing...");
    op_reindex(ol);
    printf(" complete\n\n");
}


/* ================================================================
 *  R — Reindex library
 *  Mirrors: reindexing in OL1.ASM
 *
 *  Builds an IRL index: for each module, stores the offset to
 *  its REL data and the entry symbol names.
 *  Format: 128-byte index header + symbol entries + REL data.
 * ================================================================ */
void op_reindex(OlState *ol)
{
    if (open_rel_file(ol, ol->lib_filename) != 0) {
        ol_fatal(ol, "File not found");
        return;
    }

    /* Initialize index area */
    memset(ol->symtab, 0, IRL_INDEX_SIZE);
    ol->symtab_pos = IRL_INDEX_SIZE;
    ol->rel_size = 0;
    memset(ol->rel_offset, 0, 3);
    ol->extnd_rel = 0;

    /* Scan REL stream, collecting entry symbols and module boundaries */
    RelItem item;
    for (;;) {
        int type = rel_read_item(ol, &item);
        if (type == ITEM_BYTE || type == ITEM_WORD) continue;

        if (item.item_code == 0) {
            /* Entry symbol (item 0): store in symtab
             * Format: 3 bytes offset + name bytes + 0xFE terminator */
            ol->symtab[ol->symtab_pos++] = ol->rel_offset[0];
            ol->symtab[ol->symtab_pos++] = ol->rel_offset[1];
            ol->symtab[ol->symtab_pos++] = ol->rel_offset[2];

            int j;
            for (j = 0; j < item.field_b_len; j++) {
                ol->symtab[ol->symtab_pos++] = item.field_b[j];
            }
            ol->symtab[ol->symtab_pos++] = 0xFE;  /* terminator */
        } else if (item.item_code == 14) {
            /* End of program module: compute offset for next module
             * Mirrors: A0665 in OL1.ASM */
            u16 sz = ol->rel_size;
            /* Convert to 3-byte offset (matching original algorithm):
             * xor a; add hl,hl; rla; rl h; rla; srl h; srl l */
            uint32_t off = (uint32_t)sz;
            off <<= 1;
            u8 hi = (off >> 16) & 0xFF;
            /* After rl h; rla; srl h; srl l: */
            ol->rel_offset[0] = hi;
            ol->rel_offset[1] = (off >> 8) & 0xFF;
            ol->rel_offset[2] = off & 0xFF;
        } else if (item.item_code == 15) {
            /* End of file */
            break;
        }
    }

    /* Add sentinel to symtab */
    ol->symtab[ol->symtab_pos++] = 0x00;
    ol->symtab[ol->symtab_pos++] = 0x00;
    ol->symtab[ol->symtab_pos++] = 0x00;
    ol->symtab[ol->symtab_pos++] = 0xFF;  /* end marker */

    /* Pad symtab to 128-byte boundary */
    while ((ol->symtab_pos % 128) != 0) {
        ol->symtab[ol->symtab_pos++] = 0;
    }

    /* Calculate REL data offset = symtab_pos * 2 (in 256-byte pages)
     * First byte of IRL file encodes this offset */
    int index_size = ol->symtab_pos;
    u8 offset_byte = (u8)(index_size / 128);  /* header byte */

    /* Create temp output file */
    char tmpname[MAX_FILENAME];
    snprintf(tmpname, sizeof(tmpname), "%s.tmp2", ol->lib_filename);

    if (io_create_output(ol, tmpname) != 0) {
        ol_fatal(ol, "Cannot create temp file");
        io_close_input(ol);
        return;
    }

    /* Write index header: the symtab data
     * IRL format: byte[0]=0 (data, bit7=0 for IRL detection),
     *             byte[1]=page offset (index_size/128)
     * Mirrors: ld (start),a where start=L1296+1 */
    ol->symtab[0] = 0;
    ol->symtab[1] = offset_byte;

    int k;
    for (k = 0; k < index_size; k++) {
        io_write_byte(ol, ol->symtab[k]);
    }

    /* Now copy the REL data from the original file */
    /* Seek back to start of REL data */
    io_close_input(ol);
    if (open_rel_file(ol, ol->lib_filename) != 0) {
        ol_fatal(ol, "Cannot reopen library");
        io_close_output(ol);
        remove(tmpname);
        return;
    }

    /* Reset writer state for raw copy */
    ol->wr.cur_byte = 0;
    ol->wr.bit_count = 0xF8;

    copy_rel_stream(ol);

    /* Write end-of-file markers */
    {
        rel_write_finalize(ol);
    }

    io_close_input(ol);
    io_close_output(ol);

    /* Replace original with reindexed version */
    {
        char libname[MAX_FILENAME];
        strncpy(libname, ol->lib_filename, sizeof(libname) - 1);
        libname[sizeof(libname) - 1] = 0;
        char *dot = strrchr(libname, '.');
        if (dot == NULL) {
            strncat(libname, ".IRL", sizeof(libname) - strlen(libname) - 1);
        }
        remove(libname);
        rename(tmpname, libname);
    }
}


/* ================================================================
 *  D — Dump library contents (detailed)
 *  Mirrors: dump_library in OL1.ASM
 * ================================================================ */
void op_dump_library(OlState *ol)
{
    if (open_rel_file(ol, ol->lib_filename) != 0) {
        ol_fatal(ol, "File not found");
        return;
    }

    /* Item description strings matching T0849 table */
    static const char *item_names[] = {
        "Entry symbol: ",               /* 0 */
        "Select COMMON: ",              /* 1 */
        "Start module: ",               /* 2 */
        "Search library: ",             /* 3 */
        "Reserved item: ",              /* 4 */
        "Set COMMON size to ",          /* 5 */
        "External chain at ",           /* 6 */
        "Define ",                      /* 7 */
        "External - offset ",           /* 8 */
        "External + offset ",           /* 9 */
        "DSEG length = ",               /* 10 */
        "ORG ",                         /* 11 */
        "Address chain at ",            /* 12 */
        "CSEG length = ",               /* 13 */
        "Module end, run address: ",    /* 14 */
    };

    RelItem item;

    for (;;) {
        int type = rel_read_item(ol, &item);

        if (type == ITEM_BYTE) {
            printf("Byte=%02Xh\n", item.byte_val);
            continue;
        }

        if (type == ITEM_WORD) {
            printf("Address=");
            print_seg_value(item.seg_type, item.word_val);
            printf("\n");
            continue;
        }

        /* Special item */
        if (item.item_code == 15) {
            printf("End of library.\n\n");
            break;
        }

        if (item.item_code <= 14) {
            printf("%s", item_names[item.item_code]);
        }

        /* Print A-field value for items that have it */
        if (item.item_code >= 5 && item.item_code <= 14) {
            if (item.item_code == 7) {
                /* "Define NAME as seg:VALUE" */
                print_field_b(&item);
                printf(" as ");
                print_seg_value(item.seg_type, item.word_val);
            } else if (item.item_code == 6) {
                /* "External chain at VALUE for NAME" */
                print_seg_value(item.seg_type, item.word_val);
                printf(" for ");
                print_field_b(&item);
            } else if (item.item_code == 10 || item.item_code == 13) {
                /* Size in decimal */
                printf("%u byte(s)", item.word_val);
            } else {
                print_seg_value(item.seg_type, item.word_val);
            }
        }

        /* Print B-field for items 0-4 (that don't have A-field) */
        if (item.item_code < 5) {
            print_field_b(&item);
        }

        printf("\n");

        if (item.item_code == 14) {
            printf("\n");
        }
    }

    io_close_input(ol);
}


/* ================================================================
 *  L — List modules in library
 *  Mirrors: list_modules in OL1.ASM
 * ================================================================ */
void op_list_modules(OlState *ol)
{
    if (open_rel_file(ol, ol->lib_filename) != 0) {
        ol_fatal(ol, "File not found");
        return;
    }

    ol->code_size = 0;
    ol->data_size = 0;

    RelItem item;

    for (;;) {
        int type = rel_read_item(ol, &item);
        if (type == ITEM_BYTE || type == ITEM_WORD) continue;

        switch (item.item_code) {
            case 2:  /* Program name */
                printf("\nModule name: ");
                print_field_b(&item);
                printf("\n");
                break;

            case 3:  /* Search library (request) */
                printf("request  ");
                print_field_b(&item);
                printf("\n");
                break;

            case 6:  /* External chain */
                printf("external ");
                print_field_b(&item);
                printf("\n");
                break;

            case 7:  /* Define entry point (PUBLIC) */
                printf("public   ");
                print_seg_value(item.seg_type, item.word_val);
                printf(" = ");
                print_field_b(&item);
                printf("\n");
                break;

            case 10: /* Data segment size */
                ol->data_size = item.word_val;
                break;

            case 13: /* Code segment size */
                ol->code_size = item.word_val;
                break;

            case 14: /* End of program module */
                printf("Code size: %u,  Data size: %u\n",
                       ol->code_size, ol->data_size);
                ol->code_size = 0;
                ol->data_size = 0;
                break;

            case 15: /* End of file */
                printf("End of library.\n\n");
                goto done;

            default:
                break;
        }
    }

done:
    io_close_input(ol);
}


/* ================================================================
 *  E — Extract modules from library
 *  Mirrors: extracting_module in OL1.ASM
 * ================================================================ */
void op_extract_modules(OlState *ol)
{
    if (open_rel_file(ol, ol->lib_filename) != 0) {
        ol_fatal(ol, "File not found");
        return;
    }

    /* If no module names given, extract all (*) */
    int extract_all = (ol->module_count == 0);

    RelItem item;
    int found_module = 0;

    for (;;) {
        int type = rel_read_item(ol, &item);
        if (type == ITEM_BYTE || type == ITEM_WORD) continue;

        if (item.item_code == 15) {
            printf("End of library.\n\n");
            break;
        }

        if (item.item_code != 2) continue;  /* wait for program name (item 2) */

        /* Check if this module should be extracted */
        int should_extract = extract_all;
        if (!should_extract) {
            int m;
            for (m = 0; m < ol->module_count; m++) {
                if (match_name(ol->module_files[m], item.field_b,
                               item.field_b_len)) {
                    should_extract = 1;
                    break;
                }
            }
        }

        if (!should_extract) {
            /* Skip this module */
            printf("Module Skipped: ");
            print_field_b(&item);
            printf("\n");

            /* Read until end of program module (item 14) */
            for (;;) {
                type = rel_read_item(ol, &item);
                if (type == ITEM_SPECIAL && item.item_code == 14) break;
                if (type == ITEM_SPECIAL && item.item_code == 15) goto done;
            }
            continue;
        }

        /* Extract this module */
        printf("Extracting module: ");
        print_field_b(&item);
        printf("\n");

        /* Build output filename from module name */
        char outname[MAX_FILENAME];
        {
            int j;
            int namelen = item.field_b_len;
            for (j = 0; j < namelen && j < MAX_FILENAME - 5; j++) {
                outname[j] = item.field_b[j] & 0x7F;
            }
            outname[j] = 0;
            strcat(outname, ".REL");
        }

        if (io_create_output(ol, outname) != 0) {
            fprintf(stderr, "Cannot create %s\n", outname);
            break;
        }

        found_module = 1;
        int saved_extnd = ol->extnd_rel;

        /* Write program name (item 2) first */
        ol->extnd_rel = 0;  /* output in standard format initially */
        rel_write_item(ol, &item);

        /* If source was extended format, write extension marker */
        if (saved_extnd) {
            RelItem ext_item;
            memset(&ext_item, 0, sizeof(ext_item));
            ext_item.item_code = 4;
            ext_item.field_b_len = 1;
            ext_item.field_b[0] = 0xFE;
            rel_write_item(ol, &ext_item);
            ol->extnd_rel = 1;
        }

        /* Copy module contents until end of program (item 14) */
        for (;;) {
            type = rel_read_item(ol, &item);

            if (type == ITEM_BYTE) {
                rel_write_abs_byte(ol, item.byte_val);
            } else if (type == ITEM_WORD) {
                rel_write_rel_word(ol, item.word_val, item.seg_type);
            } else {
                rel_write_item(ol, &item);
                if (item.item_code == 14) {
                    /* Finalize: pad + item 15 + pad + 0xFF */
                    rel_write_finalize(ol);
                    break;
                }
                if (item.item_code == 15) {
                    goto done;
                }
            }
        }

        io_close_output(ol);
    }

done:
    io_close_input(ol);
    if (found_module) {
        io_close_output(ol);
    }
}
