/*
 * ol_defs.h — Object Librarian definitions
 *
 * Port of OL1.ASM + IO.ASM from Z80 to C99.
 * OL is a library manager for .REL/.IRL files.
 */

#ifndef OL_DEFS_H
#define OL_DEFS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

/* Types matching assembler project */
typedef uint8_t  u8;
typedef uint16_t u16;
typedef int8_t   i8;
typedef int16_t  i16;

/* Constants */
#define MAX_FIELD_B     34      /* 1 byte length + 33 bytes name */
#define MAX_FILENAME    256
#define IO_BUF_SIZE     1024
#define MAX_MODULES     256     /* max module filenames on command line */
#define MAX_SYMTAB      65536   /* symbol table / index area */

/* IRL index entry: 3 bytes offset + N bytes name + 0xFE terminator */
#define IRL_INDEX_SIZE  128     /* initial index size */

/* Segment types */
#define SEG_ASEG   0
#define SEG_CSEG   1
#define SEG_DSEG   2
#define SEG_COMMON 3

/* ----------------------------------------------------------------
 *  REL bitstream reader state
 * ---------------------------------------------------------------- */
typedef struct {
    u8  cur_byte;       /* current byte being shifted (D0D1E) */
    u8  bit_count;      /* bits remaining in cur_byte (D0D1E+1), 0xF8 = need new byte */
} RelReadState;

/* ----------------------------------------------------------------
 *  REL bitstream writer state
 * ---------------------------------------------------------------- */
typedef struct {
    u8  cur_byte;       /* byte being built (D0D24) */
    u8  bit_count;      /* bits written, 0xF8 = boundary (D0D25) */
} RelWriteState;

/* ----------------------------------------------------------------
 *  Parsed special item result from REL reader
 * ---------------------------------------------------------------- */
typedef struct {
    int  type;          /* 0=byte, 1=word, 2=special item */
    u8   byte_val;      /* for type=0: the absolute byte */
    u16  word_val;      /* for type=1: the relocatable word */
    u8   seg_type;      /* for type=1,2: segment type */
    u8   item_code;     /* for type=2: special item code (0-15) */
    u8   field_b_len;   /* B-field: name length */
    u8   field_b[34];   /* B-field: name bytes */
} RelItem;

/* Result types for rel_read_item */
#define ITEM_BYTE     0
#define ITEM_WORD     1
#define ITEM_SPECIAL  2

/* ----------------------------------------------------------------
 *  Main OL state
 * ---------------------------------------------------------------- */
typedef struct {
    /* Command line */
    char  option;                           /* A/D/E/L/R/T */
    char  lib_filename[MAX_FILENAME];       /* library file */
    char *module_files[MAX_MODULES];        /* module filenames (pointers into argv) */
    int   module_count;

    /* I/O */
    FILE *fp_input;                         /* input file (reading) */
    FILE *fp_output;                        /* output file (writing) */

    u8    inbuf[IO_BUF_SIZE + 1];           /* input buffer (A0DFF) */
    int   in_pos;                           /* current position in inbuf */
    int   in_filled;                        /* bytes filled in inbuf */

    u8    outbuf[IO_BUF_SIZE + 1];          /* output buffer (A1000) */
    int   out_pos;                          /* current position in outbuf */

    /* REL bitstream */
    RelReadState  rd;                       /* reader state */
    RelWriteState wr;                       /* writer state */

    /* Extended REL format flag */
    int   extnd_rel;                        /* true if extended REL format */

    /* Current parsed item fields */
    u8    field_b_len;                      /* B-field name length */
    u8    field_b[34];                      /* B-field name data */
    u8    type_seg;                         /* current segment type */
    u16   item_value;                       /* A-field value (de register) */

    /* REL stream size tracking (for reindexing) */
    u16   rel_size;                         /* D128F: rel data size in bits/bytes */

    /* For list mode */
    u16   code_size;                        /* D128B */
    u16   data_size;                        /* D128D */

    /* Reindex state */
    u8    symtab[MAX_SYMTAB];              /* symbol table + index area (L1296+) */
    int   symtab_pos;                       /* current write position in symtab */

    /* Reindex offset tracking */
    u8    rel_offset[3];                    /* D1291-D1293: 3-byte offset */

    /* Externals missing flag */
    int   ext_missing_flag;                /* D0D23 */

    /* Module name matching (for extract) */
    char *extract_names[MAX_MODULES];       /* names to extract */
    int   extract_count;
} OlState;


/* ---- ol_io.c ---- */
int   io_open_input(OlState *ol, const char *filename);
void  io_close_input(OlState *ol);
int   io_create_output(OlState *ol, const char *filename);
void  io_flush_output(OlState *ol);
void  io_close_output(OlState *ol);
u8    io_read_byte(OlState *ol);
void  io_write_byte(OlState *ol, u8 byte);
void  io_seek_input(OlState *ol, long offset);

/* ---- ol_rel.c ---- */
/* Reader */
int   rel_read_bit(OlState *ol);
u8    rel_read_bits(OlState *ol, int count);
u8    rel_read_byte(OlState *ol);
u16   rel_read_value(OlState *ol);
int   rel_read_name_length(OlState *ol);
int   rel_read_item(OlState *ol, RelItem *item);

/* Writer */
void  rel_write_bit(OlState *ol, int bit);
void  rel_write_byte_bits(OlState *ol, u8 byte);
void  rel_write_value_bits(OlState *ol, u8 val, int nbits);
void  rel_write_abs_byte(OlState *ol, u8 byte);
void  rel_write_rel_word(OlState *ol, u16 val, u8 seg);
void  rel_write_special_header(OlState *ol, u8 seg);
void  rel_write_item(OlState *ol, const RelItem *item);
void  rel_write_pad_to_boundary(OlState *ol);
void  rel_write_finalize(OlState *ol);

/* ---- ol_ops.c ---- */
void  op_add_modules(OlState *ol);
void  op_dump_library(OlState *ol);
void  op_extract_modules(OlState *ol);
void  op_list_modules(OlState *ol);
void  op_reindex(OlState *ol);
void  op_test_externals(OlState *ol);

/* ---- ol_main.c ---- */
void  ol_fatal(OlState *ol, const char *msg);

#endif /* OL_DEFS_H */
