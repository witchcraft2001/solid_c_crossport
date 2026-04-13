#ifndef AS_DEFS_H
#define AS_DEFS_H

#include "../common/types.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <ctype.h>

/*
 * Solid C Macro Assembler - Z80 cross-assembler port.
 * Based on "Macro Assembler v1.5 (c) 1995, SOLiD"
 * Ported by Vasil Ivanov, cross-compiled port to C.
 *
 * This is a byte-exact port: output .rel files must be
 * identical to the original Sprinter assembler.
 */

#define TRUE  1
#define FALSE 0

/* Limits */
#define MAX_ID_LEN       30    /* max identifier length (extended REL) */
#define LINE_BUF_SIZE   257    /* line buffer size */
#define ASM_BUF_SIZE   1025    /* asm file read buffer (1024+1) */
#define REL_BUF_SIZE    512    /* rel output buffer */
#define INCL_BUF_SIZE    65    /* include file read buffer */
#define MAX_PATH_LEN     65    /* max path length + null */
#define MAX_COND_DEPTH   50    /* max conditional nesting */

/* Segment types */
#define SEG_ASEG    0
#define SEG_CSEG    1
#define SEG_DSEG    2
#define SEG_COMMON  3

/* ----------------------------------------------------------------
 *  Symbol table entry layout (mirrors original Z80 memory layout)
 *
 *  The symbol table is a set of hash chains (one per first letter).
 *  Each entry:
 *    +0,+1  : next pointer (u16) — 0 = end of chain
 *    +2,+3  : secondary pointer (u16)
 *    +4     : name length (1..30)
 *    +5     : attribute byte
 *             bit 7: defined
 *             bit 6: public/global
 *             bit 5: label defined in pass1
 *             bit 4: multiply defined
 *             bit 3: unused
 *             bits 2..0: segment type (0=aseg,1=cseg,2=dseg,3=common)
 *    +6,+7  : value (u16)
 *    +8,+9  : common size / extra (u16)
 *    +10... : name characters (up to 30 bytes)
 * ---------------------------------------------------------------- */

/* Symbol attribute bits (byte +5 = attr) */
#define SYM_DEFINED   0x80
#define SYM_PUBLIC    0x40
#define SYM_PASS1DEF  0x20
#define SYM_MULDEF    0x10
#define SYM_EXTERN    0x80  /* in byte +0 original */

/* Symbol table entry — we use a flat byte array approach for
   byte-exact compatibility, but wrap access in helpers. */

#define SYM_ENTRY_OVERHEAD 10  /* bytes before name */

typedef struct {
    u16 next;       /* offset to next in chain (0=end) */
    u16 secondary;  /* secondary link */
    u8  namelen;    /* 1..30 */
    u8  attr;       /* attribute byte */
    u16 value;      /* symbol value */
    u16 extra;      /* common size or extra data */
    u8  name[MAX_ID_LEN]; /* symbol name */
} SymEntry;

/* ----------------------------------------------------------------
 *  Keyword table entry (mirrors T39A3 register table & T06C8 hash)
 * ---------------------------------------------------------------- */

/* Keyword entry in hash list:
   byte 0: (length & 7) | (flags << 3)
   byte 1: dispatch code / opcode
   byte 2: prefix byte
   bytes 3..N: remaining characters of keyword (after first letter)
   terminated by entry with byte0 == 0
*/

/* ----------------------------------------------------------------
 *  Global assembler state
 * ---------------------------------------------------------------- */

typedef struct {
    /* Files */
    FILE *f_asm;            /* input .asm file */
    FILE *f_rel;            /* output .rel file */
    FILE *f_incl;           /* include file */

    /* File names */
    char asm_filename[MAX_PATH_LEN];
    char rel_filename[MAX_PATH_LEN];
    char incl_filename[MAX_PATH_LEN];

    /* ASM input buffering */
    u8   asm_buf[ASM_BUF_SIZE];   /* D3C8D: 1024+1 byte read buffer */
    u16  asm_ptr;                  /* current position in asm_buf */

    /* Include input buffering */
    u8   incl_buf[INCL_BUF_SIZE]; /* T4314: 65 bytes */
    u8   incl_counter;            /* D4311: read counter */
    u16  incl_ptr;                /* D4312: current position */

    /* REL output buffering */
    u8   outrel[REL_BUF_SIZE];    /* 512-byte output buffer */
    u16  rel_ptr;                 /* bytes written to current block */

    /* REL bitstream state */
    u8   rel_byte;           /* D383B: byte being assembled bit-by-bit */
    u8   rel_bitcount;       /* outrem: bits remaining (0xF8 = empty) */

    /* Line buffer */
    u8   linebuf[LINE_BUF_SIZE];  /* D36B3: 257-byte line buffer */
    u16  line_pos;                 /* D36B1: current position in linebuf */

    /* Current line number */
    u16  line_number;        /* D3661 */

    /* Token / identifier */
    u8   idlen;              /* length of current identifier */
    u8   idname[MAX_ID_LEN + 2]; /* current identifier name */

    /* Backup token */
    u8   bak_idlen;          /* T37F4 backup */
    u8   bak_idname[MAX_ID_LEN + 2];

    /* Pass control */
    u8   pass2;              /* 0=pass1, 1=pass2 */

    /* Error tracking */
    u16  error_count;        /* D366B */
    u16  warning_count;      /* D366D */
    u8   error_char;         /* D3815: current error symbol ' '=none */
    u16  error_msg_ptr;      /* D3663: pointer to error message string */

    /* Number base */
    u8   radix;              /* D366F: default number base (10) */

    /* Conditional assembly */
    u8   cond_depth;         /* D3671 */
    u8   cond_false_depth;   /* D3672 */
    u8   cond_state;         /* D3673 */
    u8   cond_stack[MAX_COND_DEPTH]; /* T3674 */

    /* Assembly state */
    u8   asm_enabled;        /* D36A6: 0=disabled (inside false cond), 1=enabled */
    u8   asm_flag_A7;        /* D36A7 */
    u8   include_active;     /* D36A8: 0=main, FF=include */
    u8   label_seg;          /* D36A9 */
    u16  label_ptr;          /* D36AA: pointer to current label in symtab */
    u16  symtab_free;        /* D36AC: next free position in symbol table */
    u16  current_label;      /* D36AE: current label address */

    /* Segment state */
    u8   seg_type;           /* D37BB: current segment type (0-3) */
    u16  org_counter;        /* D37BC: location counter (PC) */
    u16  aseg_size;          /* D37BE: absolute segment size */
    u16  cseg_size;          /* D37C0: code segment size */
    u16  dseg_size;          /* D37C2: data segment size */
    u16  common_ptr;         /* D37C4: common block pointer */
    u16  common_prev;        /* D37C6 */
    u16  common_size;        /* D37C8 */
    u16  common_saved;       /* D37CA */

    /* Phase state */
    u8   phase_active;       /* D37CE */
    u16  phase_offset;       /* D37CF */
    u8   phase_seg;          /* D37D1 */
    u8   org_flag;           /* D37D2 */

    /* Operand parsing state */
    u8   op_type;            /* D3666 */
    u8   op_reg;             /* D3667 */
    u8   op_indirect;        /* D3668 */
    u8   op_xor_flag;        /* D3669 */
    u8   first_char;         /* D3665 */
    u8   op_prefix;          /* D160C: LD prefix byte */

    /* Expression evaluator state */
    u8   expr_flags;         /* D384C */
    u8   expr_items[64];     /* D384D */
    u8   expr_item_count;    /* embedded in D384D[0] */
    u8   expr_ext_type;      /* D3835 */
    u8   expr_ext_seg;       /* D3836 */
    u16  expr_ext_ptr;       /* D3837 */
    u8   expr_seg_type;      /* D3839 */
    u8   expr_had_value;     /* D383A */
    u8   expr_op;            /* D383E */
    u8   expr_auto_comma;    /* D383F */
    u16  expr_saved;         /* D3842 */
    u8   expr_link_item[8];  /* D3844..D384B */
    u8   expr_result_cf;     /* D38CF */
    u8   expr_op2;           /* D38D0 */
    u16  expr_ret_addr;      /* D38D1 */
    u8   seg_change_flag;    /* D38D3 */
    u8   temp_byte;          /* D37CC */
    u8   temp_name_buf;      /* T37CD */

    /* Saved stack pointer for expression evaluator */
    u16  save_stack;

    /* Swap buffers for operand context */
    u8   swap_buf[65];       /* T388D */

    /* Module name */
    u8   module_name[10];    /* T38D5: name('...') */
    u8   module_name_hdr;    /* T38CE */

    /* Binary search tree helpers */
    u8   tree_buf1[3];       /* T38DF */
    u8   tree_buf2[3];       /* T38E2 */
    u8   tree_flag;          /* D38E5 */
    u16  tree_ptr;           /* D38E6 */
    u16  tree_hash_ptr;      /* D38E8 */

    /* Lookup tables for user-defined symbols */
    u16  sym_lookup1[33];    /* T38EA: 66 bytes */
    u16  sym_lookup2[33];    /* T392C: 66 bytes */

    /* Macro state */
    u16  macro_entry;        /* D396E */
    u16  macro_body_ptr;     /* D3970 */
    u8   macro_depth;        /* D3972 */
    u8   macro_state;        /* D3973 */
    u8   macro_ampersand;    /* D3974 */
    u16  macro_repeat_cnt;   /* D3975 */
    u16  macro_ret_addr;     /* D3977 */
    u16  macro_saved1;       /* D3979 */
    u16  macro_saved2;       /* D397B */
    u8   macro_nest;         /* D397D */
    u8   macro_exitm;        /* D397E */
    u16  macro_params;       /* D397F */
    u16  macro_body;         /* D3981 */
    u16  macro_current;      /* D3983 */
    u8   macro_comment_ch;   /* D3985 */
    u8   macro_angle_flag;   /* D3986 */
    u8   macro_flag1;        /* D3987 */
    u8   macro_flag2;        /* D3988 */
    u16  macro_local_start;  /* D3989 */
    u16  macro_local_ptr;    /* D398B */
    u8   macro_local_count;  /* D398D */
    u16  macro_counter;      /* D398E */
    u16  macro_label;        /* D3990 */
    u8   macro_nargs;        /* D3992 */

    /* Memory management */
    u16  mem_chain_ptr;      /* D3993 */
    u16  mem_pool_start;     /* D3995 */
    u16  mem_pool_end;       /* D3997 */
    u16  mem_free_chain;     /* D3999 */
    u16  mem_alloc_base;     /* D399B */
    u16  mem_alloc_ptr;      /* D399D */
    u16  mem_top;            /* D399F */
    u16  mem_stack_limit;    /* D39A1 */

    /* Large memory pool for symbol table + macro storage.
       In original: 4000h..FFFFh address space.
       We use a flat byte array. */
    u8  *memory;           /* dynamically allocated, 64KB */
    int  memory_size;

    /* Command-line options */
    u8   opt_zero_ds;        /* D3A2C: -z flag */
    u8   opt_truncate6;      /* D3A2D: -t flag */
    u8   opt_extended_rel;   /* extended_rel_mode: -x flag */

    /* Temp working area */
    u8   temp_area[8];       /* T37B4: ds 7 */
    u16  temp_ptr;           /* D365F */
    u8   radix_override;     /* D3670 */

    /* Error message string pointer for display */
    const char *error_msg_str;

} AsmState;

/* ----------------------------------------------------------------
 *  Function declarations
 * ---------------------------------------------------------------- */

/* as_main.c */
int main(int argc, char **argv);

/* as_io.c */
int  io_open_asm(AsmState *as);
void io_close_asm(AsmState *as);
int  io_create_rel(AsmState *as);
void io_close_rel(AsmState *as);
int  io_read_asm_byte(AsmState *as);
int  io_open_include(AsmState *as, const char *name);
int  io_read_include_byte(AsmState *as);
void io_close_include(AsmState *as);
void io_write_rel_byte(AsmState *as, u8 byte);
void io_flush_rel(AsmState *as);
void io_print_str(const char *str);
void io_print_char(char c);
void io_newline(void);

/* as_lexer.c */
int  lex_nextchar(AsmState *as);
int  lex_skipspace(AsmState *as);
void lex_pushback(AsmState *as);
void lex_advance(AsmState *as);
int  lex_token_copy(AsmState *as);
int  lex_get_next_char(AsmState *as);
void lex_swap_tokens(AsmState *as);
int  lex_read_line(AsmState *as);

/* as_symtab.c */
int  sym_search_keyword(AsmState *as);
int  sym_search_user(AsmState *as);
void sym_add_entry(AsmState *as, int carry_flag);
void sym_define_label(AsmState *as, u8 attr);
void sym_init_keywords(AsmState *as);
u16  sym_get_pc(AsmState *as);
u8   sym_get_seg_type(AsmState *as);

/* as_expr.c */
void expr_evaluate(AsmState *as);
u16  expr_eval_simple(AsmState *as);
int  expr_get_byte(AsmState *as);

/* as_instr.c */
void instr_dispatch(AsmState *as, u8 dispatch_code, u8 prefix);
void instr_process(AsmState *as);

/* as_directives.c */
void dir_process(AsmState *as, u8 directive_code);
void dir_do_end(AsmState *as);
void dir_do_org(AsmState *as);
void dir_do_equ(AsmState *as);
void dir_do_db(AsmState *as);
void dir_do_dw(AsmState *as);
void dir_do_ds(AsmState *as);
void dir_do_include(AsmState *as);

/* as_rel.c */
void rel_putbit(AsmState *as, int bit);
void rel_put_byte(AsmState *as, u8 byte);
void rel_put_absolute_byte(AsmState *as, u8 byte);
void rel_put_special_header(AsmState *as, u8 seg_type);
void rel_put_spec_item(AsmState *as, u8 item, u8 seg_type, u16 value);
void rel_put_symbol_name(AsmState *as, int extended);
void rel_put_word(AsmState *as, u16 value, u8 seg_type);
void rel_output_code_byte(AsmState *as, u8 byte);
void rel_output_data_byte(AsmState *as, u8 byte);
void rel_finalize(AsmState *as);

/* as_pass.c */
void pass_init(AsmState *as);
void pass_run(AsmState *as);
void pass_process_line(AsmState *as);

/* Error handlers */
void err_report(AsmState *as, char code, const char *msg);
void err_out_of_range(AsmState *as);
void err_syntax(AsmState *as);
void err_undefined(AsmState *as);
void err_duplicate(AsmState *as);
void err_phase(AsmState *as);
void err_relocatable(AsmState *as);
void err_external(AsmState *as);
void err_number(AsmState *as);
void err_value(AsmState *as);
void err_warning(AsmState *as);
void err_mistake(AsmState *as);
void err_divide_zero(AsmState *as);

/* Utility */
void fatal_error(AsmState *as, const char *msg);
void print_decimal(u16 value);

#endif /* AS_DEFS_H */
