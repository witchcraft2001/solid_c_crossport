/*
 * cc2_defs.h — CC2 Code Generator definitions
 *
 * Port of CCC.ASM + IO2.ASM from Z80 to C99.
 * CC2 reads .TMC intermediate files and produces .ASM output.
 */

#ifndef CC2_DEFS_H
#define CC2_DEFS_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef uint8_t  u8;
typedef uint16_t u16;
typedef int8_t   i8;
typedef int16_t  i16;

/* ----------------------------------------------------------------
 *  Constants
 * ---------------------------------------------------------------- */
#define MAX_FILENAME    256
#define IO_BUF_SIZE     512
#define MAX_LINE        1024
#define MAX_TOKEN       256
#define MAX_SYMTAB      8192    /* symbol table entries (6 bytes each) */
#define MAX_TREE        65536   /* code tree area (21-byte nodes) */
#define MAX_STACK       4096    /* expression/code stack */
#define STACK_ADDR      0xFFF0  /* original stack address */
#define STRING_LABEL_START 63999 /* string constant labels start here, decrement */
#define TREE_NODE_SIZE  21      /* bytes per code tree node */

/* Symbol table entry types (stored at offset 0) */
#define SYM_STRUCT  'S'  /* struct definition */
#define SYM_UNION   'U'  /* union definition */
#define SYM_MEMBER  'M'  /* struct/union member */
#define SYM_GLOBAL  'G'  /* global variable */
#define SYM_EXTERN  'X'  /* external function/variable */
#define SYM_STATIC  'Y'  /* static function */
#define SYM_PARAM   'P'  /* function parameter */
#define SYM_AUTO    'A'  /* local (auto) variable */
#define SYM_EXTERN_REF 'E' /* external reference (register-allocated) */
#define SYM_VAR     'V'  /* variable/constant size */
#define SYM_TYPEDEF 'T'  /* typedef */
#define SYM_CODE    'p'  /* code item (internal) */

/* Type codes used in TMC */
#define TYPE_N  'N'  /* native/int (16-bit) */
#define TYPE_I  'I'  /* integer */
#define TYPE_C  'C'  /* char (8-bit) */
#define TYPE_R  'R'  /* reference/pointer */
#define TYPE_B  'B'  /* byte? */
#define TYPE_Z  'Z'  /* long? (4 bytes) */
#define TYPE_W  'W'  /* word? (4 bytes) */
#define TYPE_Q  'Q'  /* quad? (4 bytes) */
#define TYPE_H  'H'  /* huge? (8 bytes) */
#define TYPE_F  'F'  /* function */

/* Type sizes (from T9ED5 table) */
#define SIZEOF_I  2   /* int = 2 bytes */
#define SIZEOF_N  2   /* native = 2 bytes */
#define SIZEOF_R  2   /* pointer = 2 bytes */
#define SIZEOF_B  1   /* byte/char = 1 byte */
#define SIZEOF_C  1   /* char = 1 byte */
#define SIZEOF_Z  4   /* long = 4 bytes */
#define SIZEOF_W  4   /* word = 4 bytes */
#define SIZEOF_Q  4   /* quad = 4 bytes */
#define SIZEOF_H  8   /* huge = 8 bytes */

/* ----------------------------------------------------------------
 *  Symbol table entry (6 bytes, mirrors Z80 layout)
 * ---------------------------------------------------------------- */
typedef struct {
    u8  type;       /* offset 0: symbol type */
    u16 value;      /* offset 1-2: value */
    u16 name;       /* offset 3-4: name id/pointer */
    u8  attr;       /* offset 5: additional attribute */
} SymEntry;

/* ----------------------------------------------------------------
 *  Code tree node (21 bytes)
 * ---------------------------------------------------------------- */
typedef struct {
    u16 link;       /* offset 0-1: link to next node */
    u8  opcode;     /* offset 2: operation code */
    u16 operand1;   /* offset 3-4: first operand */
    u8  operand2;   /* offset 5: second operand */
    u8  data[15];   /* offset 6-20: additional data */
} TreeNode;

/* ----------------------------------------------------------------
 *  Main CC2 state
 * ---------------------------------------------------------------- */
typedef struct {
    /* Command line */
    char tmc_filename[MAX_FILENAME];
    char asm_filename[MAX_FILENAME];
    int  opt_keep_tmc;      /* -k: don't delete TMC */
    int  opt_quiet;         /* -q: quiet mode */
    char underscore_char;   /* -u: prefix char (default '_') */
    int  table_size;        /* -r: symbol table size */

    /* I/O */
    FILE *fp_input;         /* TMC file */
    FILE *fp_output;        /* ASM file */

    u8   inbuf[IO_BUF_SIZE + 2];  /* TMC input buffer */
    int  in_pos;
    int  in_filled;
    int  in_eof;            /* EOF flag for TMC */

    u8   outbuf[IO_BUF_SIZE + 2]; /* ASM output buffer */
    int  out_pos;

    /* TMC reader state */
    int  tmc_line;          /* current line number in TMC */
    int  tmc_col;           /* current column */

    /* Token buffer / pushback */
    char tokbuf[MAX_TOKEN]; /* accumulated token string */
    int  toklen;
    int  pushback_count;    /* number of pushed-back chars */
    char pushback[16];      /* pushed-back characters */

    /* Symbol table */
    SymEntry sym[MAX_SYMTAB];
    int  sym_count;         /* current number of entries */
    int  sym_limit;         /* max entries (from table_size) */

    /* Pointers into symbol table (mirrors D9CF0..D9CF6) */
    int  sym_ptr;           /* D9CF0: current write position */
    int  sym_end;           /* D9CF4: end of table */

    /* Code tree (allocated top-down from D9CFC) */
    u8   tree[MAX_TREE];
    int  tree_ptr;          /* D9CFC: current allocation pointer (grows down) */
    int  tree_limit;        /* D9CF6: limit */
    int  tree_top;          /* top of tree area */

    /* String constant counter */
    int  str_label;         /* starts at 63999, decrements */

    /* Segment state */
    int  cur_seg;           /* -1=unset, 0=cseg, 1=dseg */

    /* Function state */
    int  in_function;       /* currently inside a function body */
    int  local_label;       /* local label counter (@0, @1, ...) */
    u16  frame_size;        /* local variable frame size */

    /* Code generation state */
    int  warnings;          /* warning flag */
    int  opt_level;         /* optimization flags */
    u8   code_type;         /* D9CC6: current code type */
    int  d9ccd;             /* D9CCD flag */
    int  d9cce;             /* D9CCE flag */

    /* Expression stack */
    u16  expr_stack[MAX_STACK];
    int  expr_sp;

    /* Register tracking */
    u8   reg_table[76];     /* T9C79: register allocation table */
    u16  reg_pair;          /* T9C75 */
    u8   reg_byte1;         /* T9C77 */
    u8   reg_byte2;         /* T9C78 */

    /* Misc state from CCC.ASM */
    u16  d9ce1;             /* function-related */
    u16  d9ce3;             /* function-related */
    u16  d9ce5;             /* function-related */
    u16  d9ce7;             /* function-related */
    u16  d9cdf;             /* function-related */
    u16  d9cdd;             /* local frame size accumulator */
    u16  d9cee;             /* pointer into tree */
    u16  d9cf8;             /* pointer into tree */
    u16  d9cfa;             /* tree-related */
    u16  d9ccf;             /* tree node counter */
    u16  d9cca;             /* counter */

    /* String constant data tracking */
    int  in_string_data;    /* D0AC2: inside string data block */
    u16  str_data_ptr;      /* pointer for string data storage */

    /* DB output state */
    int  db_count;          /* D9A3A: count of db values on current line (reset at 10) */

    /* Function name buffer for <...> handling */
    char func_name_buf[64]; /* T9C4D: function name during <...> */
    int  func_name_pos;     /* position in func_name_buf, -1 if not active */

    /* TMC body replay (for two-pass optimization) */
    const char *replay_buf; /* NULL = normal mode, non-NULL = replay from buffer */
    int  replay_pos;
    int  replay_len;

} Cc2State;


/* ---- cc2_io.c ---- */
int   io_open_input(Cc2State *cc, const char *filename);
void  io_close_input(Cc2State *cc);
int   io_create_output(Cc2State *cc, const char *filename);
void  io_flush_output(Cc2State *cc);
void  io_close_output(Cc2State *cc);
int   io_read_byte(Cc2State *cc);
void  io_write_byte(Cc2State *cc, u8 byte);
void  io_write_char(Cc2State *cc, char ch);
void  io_write_str(Cc2State *cc, const char *s);
void  io_write_newline(Cc2State *cc);
void  io_write_decimal(Cc2State *cc, int val);

/* ---- cc2_tmc.c ---- */
int   tmc_read_char(Cc2State *cc);
void  tmc_pushback(Cc2State *cc, int ch);
void  tmc_skip_line(Cc2State *cc);
void  tmc_expect_tab(Cc2State *cc);
int   tmc_read_token(Cc2State *cc, char *buf, int maxlen);
int   tmc_read_number(Cc2State *cc);
int   tmc_peek_char(Cc2State *cc);

/* ---- cc2_sym.c ---- */
void  sym_init(Cc2State *cc);
int   sym_add(Cc2State *cc, u8 type, u16 value, u16 name_id, u8 attr);
SymEntry *sym_get(Cc2State *cc, int index);
int   sym_find_by_name(Cc2State *cc, u16 name_id);
int   type_size(int type_char);

/* ---- cc2_gen.c ---- */
void  gen_process_file(Cc2State *cc);

/* ---- cc2_out.c ---- */
void  out_set_cseg(Cc2State *cc);
void  out_set_dseg(Cc2State *cc);
void  out_asm_template(Cc2State *cc, const char *fmt, ...);
void  out_label(Cc2State *cc, const char *name);
void  out_str_label(Cc2State *cc, int num);
void  out_db_byte(Cc2State *cc, int val);
void  out_db_finish(Cc2State *cc);
void  out_instruction(Cc2State *cc, const char *mnemonic, const char *operands);
void  out_comment(Cc2State *cc, const char *text);
void  out_public(Cc2State *cc, const char *name);
void  out_extrn(Cc2State *cc, const char *name);
void  out_end(Cc2State *cc);
void  out_raw(Cc2State *cc, const char *text);

/* ---- cc2_main.c ---- */
void  cc2_fatal(Cc2State *cc, const char *msg);

#endif /* CC2_DEFS_H */
