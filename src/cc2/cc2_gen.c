/*
 * cc2_gen.c — Code generation from TMC to Z80 ASM
 *
 * Mirrors the core of CCC.ASM: TMC parsing, expression evaluation,
 * code generation, and ASM output.
 *
 * Processes TMC intermediate code and generates Z80 assembly.
 *
 * Original architecture (CCC.ASM, for future porting reference):
 * ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 * A19FB  — expression evaluator: TMC → tree of 21-byte nodes
 * A3A5B  — optimizer phase 1: variable counting, basic block analysis
 * A6131  — optimizer phase 2: register allocation, code emission
 * A6225  — ASM template engine (char-code dispatch from 'A','R','P',...)
 * T8BF0  — operation-code dispatch table → template pointer
 * L8F40  — inline 16-bit equality template: ld a,<lo>/cp <lo>/jr nz,$+4/
 *                                            ld a,<hi>/cp <hi>
 * L8FD7  — cpshd template: <?cpshd> (library call)
 * L8FB9  — 16-bit subtract via A: ld a,<lo>/sub <lo>/ld a,<hi>/sbc a,<hi>
 * L926D  — function prologue: push ix / ld ix,0 / add ix,sp
 * L9288  — function epilogue: ld sp,ix / pop ix
 * cpshd  — at 19190: signed 16-bit compare (sets Z and C flags)
 *
 * The ref compiler builds a code tree from TMC expressions, runs two
 * optimizer passes, then emits ASM via template dispatch (T8BF0). Each
 * TMC op-code indexes into T8BF0 to pick a template (L****). Templates
 * are byte arrays: 0x94 = \n\t (new asm line), 0x80-0x8F = operand
 * placeholders (register/immediate byte slots), 0xFF = end.
 *
 * Our cc2 bypasses the template engine and emits instructions directly
 * via emit_instr(). This produces valid Z80 code but not byte-identical
 * in many cases (different instruction scheduling, register usage, and
 * variable-slot allocation). The passing tests (CPRINTF, CPUTS, HELLO)
 * match because their patterns are simple enough that both approaches
 * converge. Programs with structs (BENCH), loops and locals (SORT2),
 * and multi-arg calls (HOBCRC/BIN2TRD/LZH3) diverge.
 */

#include "cc2_defs.h"

/* ================================================================
 *  Forward declarations
 * ================================================================ */
static void parse_struct(Cc2State *cc, int is_union);
static void parse_global(Cc2State *cc);
static void parse_varsize(Cc2State *cc);
static void parse_function(Cc2State *cc);
static void parse_typedef(Cc2State *cc);
static int expr_read_tok(Cc2State *cc, char *tok, int maxlen);

/* ================================================================
 *  String constant storage
 * ================================================================ */
#define MAX_STRINGS 256
#define MAX_STR_DATA 65536

typedef struct {
    int  label;             /* label number (63999, 63998, ...) */
    int  data_offset;       /* offset into str_data[] */
    int  data_len;          /* number of byte values */
    int  emitted;           /* 1 if already output to ASM */
} StrConst;

static StrConst str_consts[MAX_STRINGS];
static int      str_const_count;
static int      str_data[MAX_STR_DATA]; /* byte values */
static int      str_data_pos;

/* ================================================================
 *  Instruction list for current function
 * ================================================================ */
#define MAX_INSTR 8192
#define INSTR_BUF 128

typedef struct {
    int  type;              /* instruction type */
    char text[INSTR_BUF];  /* formatted instruction text */
} Instr;

/* Instruction types */
#define INSTR_RAW       0   /* raw output (already formatted) */
#define INSTR_INST      1   /* \t<mnemonic>\t<operands>\r\n */
#define INSTR_LABEL     2   /* <label>:\r\n */
#define INSTR_COMMENT   3   /* ;<text>\r\n */

static Instr instr_list[MAX_INSTR];
static int   instr_count;

/* ================================================================
 *  TMC function body buffer (for two-pass optimization)
 * ================================================================ */
#define MAX_BODY_BUF 65536
static char body_buf[MAX_BODY_BUF];
static int  body_buf_len;

/* ================================================================
 *  Code Tree — intermediate representation for optimizer
 *
 *  Built during TMC parsing (Phase 1), analyzed (Phase 2),
 *  used for register allocation (Phase 3).
 *  Mirrors CCC.ASM's 21-byte node pool + A3A5B/A6131 optimizer.
 * ================================================================ */
#define CT_MAX_NODES    4096
#define CT_MAX_STMTS    1024

/* Node kinds (what this node represents) */
#define CT_CONST    1   /* immediate constant: value = number */
#define CT_VAR      2   /* variable reference: value = local id, sym = name */
#define CT_GLOBAL   3   /* global variable: sym = asm name */
#define CT_STRING   4   /* string constant: value = str index */
#define CT_UNARY    5   /* unary op: op, left = operand */
#define CT_BINARY   6   /* binary op: op, left/right = operands */
#define CT_ASSIGN   7   /* assignment: op = type, left = dest, right = value */
#define CT_CALL     8   /* function call: sym = func, children = args */
#define CT_DEREF    9   /* dereference (') */
#define CT_ADDR     10  /* address-of (@) */
#define CT_CAST     11  /* type cast: op = from, type = to */
#define CT_MEMBER   12  /* struct member: value = member id */
#define CT_SUBSCR   13  /* array subscript (R) */
#define CT_LABEL    14  /* label reference */
#define CT_JUMP     15  /* conditional jump */
#define CT_LOOP     16  /* loop start (d) */
#define CT_BREAK    17  /* loop end (b) */
#define CT_RETURN   18  /* return (y) */
#define CT_COMMA    19  /* comma operator (,) */
#define CT_STATIC   20  /* static local (T-type) */

typedef struct {
    u8   kind;          /* CT_xxx node kind */
    u8   op;            /* operator char (+, -, *, etc.) */
    char type;          /* result type: C, N, I, R */
    int  value;         /* immediate value, var id, label, etc. */
    char sym[48];       /* symbol name (for globals, funcs) */
    int  left;          /* left child index (-1 = none) */
    int  right;         /* right child index (-1 = none) */

    /* Analysis fields (filled by tree walker) */
    int  depth;         /* loop nesting depth at this node */
    int  ref_count;     /* how many times this var is referenced */
} CTNode;

/* Statement in the function body */
typedef struct {
    int  kind;          /* 'e'=expr, 'j'=jump, 'd'=loop, 'b'=break, 'y'=return */
    int  root;          /* root node index in ct_nodes[] */
    int  label;         /* for 'j': target label; for 'd': loop label */
    int  negate;        /* for 'j': condition negated */
} CTStmt;

static CTNode ct_nodes[CT_MAX_NODES];
static int    ct_node_count;

static CTStmt ct_stmts[CT_MAX_STMTS];
static int    ct_stmt_count;

/* Tree-building variable usage counters (for Phase 2 analysis) */
#define CT_MAX_VARS 128
typedef struct {
    int  id;            /* local var id (A<n> or P<n>) */
    char prefix;        /* 'A' or 'P' */
    int  total_refs;    /* total reference count */
    int  loop_refs;     /* references inside loops (weighted) */
    int  max_depth;     /* max loop nesting depth of any reference */
    int  crosses_call;  /* referenced both before and after a function call */
    int  is_array_base; /* used as base pointer for array subscript */
} CTVarInfo;

static CTVarInfo ct_vars[CT_MAX_VARS];
static int       ct_var_count;

static int ct_alloc_node(void)
{
    if (ct_node_count >= CT_MAX_NODES) return -1;
    int idx = ct_node_count++;
    memset(&ct_nodes[idx], 0, sizeof(CTNode));
    ct_nodes[idx].left = -1;
    ct_nodes[idx].right = -1;
    return idx;
}

/* ================================================================
 *  Name table: stores identifier strings, referenced by index
 * ================================================================ */
#define MAX_NAMES 4096
#define NAME_BUF_SIZE 65536

static char name_buf[NAME_BUF_SIZE];
static int  name_buf_pos;

typedef struct {
    int offset;
    int len;
} NameEntry;

static NameEntry names[MAX_NAMES];
static int name_count;

/* Symbol tracking for extrn/public output */
#define MAX_DECLS 512

typedef struct {
    char name[64];          /* symbol name with underscore */
    int  is_public;         /* 1=public, 0=extrn */
    int  order;             /* insertion order */
} DeclEntry;

static DeclEntry decl_list[MAX_DECLS];
static int       decl_count;

/* ================================================================
 *  Struct member tracking (for . operator)
 * ================================================================ */
#define MAX_MEMBERS 1024

typedef struct {
    int struct_num;         /* parent struct/union number */
    int member_num;         /* member TMC id (M<n>) */
    int offset;             /* byte offset within struct */
    int size;               /* member size in bytes */
    char type;              /* member type char */
    int type_num;           /* struct/union num if type is S/U */
} MemberInfo;

static MemberInfo member_list[MAX_MEMBERS];
static int member_count;

/* ================================================================
 *  Parameter/local variable info
 * ================================================================ */
#define MAX_LOCALS 128

typedef struct {
    char prefix;        /* 'P' for param, 'A' for auto/local */
    int  id;            /* TMC id number */
    char type;          /* type char: N, I, C, R, etc. */
    int  struct_num;    /* struct number if type is 'S' */
    int  size;          /* size in bytes */
    int  ix_offset;     /* offset from IX (negative for locals) */
    int  reg;           /* VK_NONE=on stack, VK_A/VK_HL=in register */
} LocalVar;

static LocalVar locals[MAX_LOCALS];
static int local_count;
static int param_count;

/* ================================================================
 *  Label mapping: TMC label numbers → @N output labels
 * ================================================================ */
#define MAX_LABELS 2048

static int label_map[MAX_LABELS]; /* -1 = not yet assigned */

/* ================================================================
 *  Loop stack for d...b
 * ================================================================ */
#define MAX_LOOP_DEPTH 64

static int loop_labels[MAX_LOOP_DEPTH]; /* @N label for loop start */
static int loop_depth;

/* ================================================================
 *  Per-function state
 * ================================================================ */
static int   func_has_locals;   /* has locals requiring stack frame */
static int   func_frame_bytes;  /* total stack bytes for locals */
static char  func_ret_type;     /* return type char */
static int   func_has_return;   /* has explicit return statement */
static int   func_epilogue_label; /* @N label for shared epilogue (-1 if none) */
static int   func_is_simple;   /* 1 if simple function (no locals/params) */
static int   hl_spilled;      /* 1 if HL-allocated param was pushed to hardware stack */
static int   de_spilled;      /* 1 if DE-allocated param was pushed to hardware stack */

/* ================================================================
 *  Array subscript base tracking (for R....*R...' pattern)
 * ================================================================ */
static int   rbase_active;      /* 1 = pending R base to add after *R */
static int   rbase_kind;        /* VK_LOCAL, VK_GLOBAL, VK_DE, etc. */
static int   rbase_value;       /* ix_offset for local */
static char  rbase_sym[64];     /* symbol for global */
static int   rbase_is_addr;     /* base had is_addr set */

/* ================================================================
 *  Value stack for expression evaluation (code-generating)
 * ================================================================ */
#define VSTACK_MAX 64

#define VK_NONE     0
#define VK_IMM      1   /* immediate constant */
#define VK_GLOBAL   2   /* global variable in memory */
#define VK_LOCAL    3   /* local variable (IX-relative) */
#define VK_HL       4   /* value currently in HL */
#define VK_DE       5   /* value currently in DE */
#define VK_A        6   /* value currently in A register */
#define VK_STRING   7   /* string constant label */
#define VK_MEMBER   8   /* struct member ref (value = member num) */
#define VK_RESULT   9   /* function call result (in HL or A) */
#define VK_BC       10  /* value currently in BC */
#define VK_STACK    11  /* value pushed on hardware stack */
#define VK_ADDR_HL  12  /* HL holds address of variable */

typedef struct {
    int  kind;
    char sym[64];       /* for VK_GLOBAL: asm name */
    int  value;         /* for VK_IMM: constant; VK_LOCAL: ix offset */
    char type;          /* N, I, C, R */
    int  is_addr;       /* 1 = address (not dereferenced) */
    int  str_idx;       /* for VK_STRING */
} VVal;

static VVal vstack[VSTACK_MAX];
static int  vsp;

/* ================================================================
 *  Inline function call state (for calls within gen_expr_stmt)
 * ================================================================ */
#define ICALL_MAX_ARGS 16
static char  icall_name[128];       /* function name (before asm conversion) */
static int   icall_active;          /* 1 = currently collecting call args */
static VVal  icall_args[ICALL_MAX_ARGS]; /* collected arguments */
static char  icall_arg_types[ICALL_MAX_ARGS]; /* arg push types: R, I, C, N */
static int   icall_nargs;           /* number of args collected */
static char  icall_ret_type;        /* return type from c<type> */

/* ================================================================
 *  Name table operations
 * ================================================================ */
static int name_add(const char *s, int len)
{
    int id = name_count;
    if (id >= MAX_NAMES) return -1;
    names[id].offset = name_buf_pos;
    names[id].len = len;
    memcpy(name_buf + name_buf_pos, s, len);
    name_buf[name_buf_pos + len] = '\0';
    name_buf_pos += len + 1;
    name_count++;
    return id;
}

static const char *name_get(int id)
{
    if (id < 0 || id >= name_count) return "";
    return name_buf + names[id].offset;
}

/* ================================================================
 *  Declaration tracking
 * ================================================================ */
static void decl_add(const char *name, int is_public)
{
    int i;
    for (i = 0; i < decl_count; i++) {
        if (strcmp(decl_list[i].name, name) == 0) {
            if (is_public && !decl_list[i].is_public) {
                decl_list[i].is_public = 1;
            }
            return;
        }
    }
    if (decl_count >= MAX_DECLS) return;
    strncpy(decl_list[decl_count].name, name, 63);
    decl_list[decl_count].name[63] = '\0';
    decl_list[decl_count].is_public = is_public;
    decl_list[decl_count].order = decl_count;
    decl_count++;
}

/* ================================================================
 *  String constant operations
 * ================================================================ */
static int str_const_new(Cc2State *cc)
{
    int idx = str_const_count++;
    str_consts[idx].label = cc->str_label--;
    str_consts[idx].data_offset = str_data_pos;
    str_consts[idx].data_len = 0;
    str_consts[idx].emitted = 0;
    return idx;
}

static int parse_string_const(Cc2State *cc)
{
    int idx = str_const_new(cc);
    int ch;
    for (;;) {
        int val = 0;
        ch = tmc_read_char(cc);
        while (ch >= '0' && ch <= '9') {
            val = val * 10 + (ch - '0');
            ch = tmc_read_char(cc);
        }
        str_data[str_data_pos++] = val;
        str_consts[idx].data_len++;
        if (ch == '"') break;
    }
    return idx;
}

static void emit_string_consts(Cc2State *cc)
{
    int i, j;
    for (i = 0; i < str_const_count; i++) {
        if (str_consts[i].emitted) continue;
        out_set_cseg(cc);
        out_str_label(cc, str_consts[i].label);
        cc->db_count = 0;
        int off = str_consts[i].data_offset;
        int len = str_consts[i].data_len;
        for (j = 0; j < len; j++) {
            out_db_byte(cc, str_data[off + j]);
        }
        out_db_finish(cc);
        str_consts[i].emitted = 1;
    }
}

/* ================================================================
 *  Instruction list operations
 * ================================================================ */
static void emit_instr(Cc2State *cc, const char *mnemonic, const char *operands)
{
    (void)cc;
    if (instr_count >= MAX_INSTR) return;
    Instr *ins = &instr_list[instr_count++];
    ins->type = INSTR_INST;
    if (operands && operands[0]) {
        snprintf(ins->text, INSTR_BUF, "%s\t%s", mnemonic, operands);
    } else {
        snprintf(ins->text, INSTR_BUF, "%s", mnemonic);
    }
}

static void emit_label_instr(const char *label)
{
    if (instr_count >= MAX_INSTR) return;
    Instr *ins = &instr_list[instr_count++];
    ins->type = INSTR_LABEL;
    snprintf(ins->text, INSTR_BUF, "%s", label);
}

static void emit_comment_instr(const char *text)
{
    if (instr_count >= MAX_INSTR) return;
    Instr *ins = &instr_list[instr_count++];
    ins->type = INSTR_COMMENT;
    snprintf(ins->text, INSTR_BUF, "%s", text);
}

/* ================================================================
 *  ASM template engine — ported 1-to-1 from A6225 in CCC.ASM
 *
 *  Processes template strings character-by-character. Each character
 *  is either a literal to emit, a mnemonic keyword ('A'=add, 'Z'=ld,
 *  'N'=newline+tab), or an operand directive that consumes one value
 *  from the operands[] array:
 *    'R'  — 8-bit register letter ("bcdehlma"[v&7]) or "(hl)" if 'm'
 *    'P'  — 16-bit register pair from "bcdehlsp"
 *    'D'  — unsigned 16-bit decimal number
 *    'L'  — low byte decimal (0..255)
 *    'H'  — high byte decimal (0..255)
 *    'C'  — single character
 *    'X'  — "inc hl" (conditional in ref; unconditional here)
 *    'Y'  — "dec hl" (conditional in ref; unconditional here)
 *  In the original, each directive advances IX by 2 over a stack-of-
 *  operands area. We use a plain array indexed by consumption count.
 *
 *  The template is appended to instr_list one INSTR_INST per "\n\t"
 *  boundary (matching how our emit_instr emits tab-prefixed lines).
 *
 *  Not yet ported: 'S' (string ref), 'M' (variable name) — these
 *  require the code-tree node structure from A19FB. They are not
 *  used by the numeric/register templates we need first.
 * ================================================================ */

/* T6467: 8-bit register name list. 'm' means "(hl)" (memory). */
static const char A6225_R8_NAMES[]  = "bcdehlma";
/* T6470: 16-bit register-pair name list (pairs of 2 chars). */
static const char A6225_R16_NAMES[] = "bcdehlsp";

/* D9BE6 in CCC.ASM: underscore suffix char for asm-label (default '_') */
#define A6225_ID_SUFFIX '_'

/* Template operand: value and/or string (S/M directives use str, rest use val).
 * Mirrors how the ref compiler reads pairs of bytes at IX — one slot per op. */
typedef struct {
    int         val;
    const char *str;
} TmplOp;

/* Emit a literal instruction to instr_list. The text may contain
 * tabs but must not contain newlines — callers split on 'N'/'Z'/'A'. */
static void tmpl_emit_line(const char *text)
{
    if (instr_count >= MAX_INSTR) return;
    if (!text[0]) return;
    Instr *ins = &instr_list[instr_count++];
    ins->type = INSTR_INST;
    snprintf(ins->text, INSTR_BUF, "%s", text);
}

/* Mirrors A6225 'M' name emission (A62F6..A631A): walk the name string,
 * substituting '_' with the suffix char. After the name, if the first
 * char was not '?' (locally-scoped label), append the suffix char. */
static void tmpl_emit_name(char *buf, int *blen_p, const char *name)
{
    int blen = *blen_p;
    char first = name[0];
    const char *p;
    for (p = name; *p; p++) {
        char c = *p;
        if (c == '_') c = A6225_ID_SUFFIX;
        if (blen < INSTR_BUF - 1) buf[blen++] = c;
    }
    if (first != '?') {
        if (blen < INSTR_BUF - 1) buf[blen++] = A6225_ID_SUFFIX;
    }
    *blen_p = blen;
}

/* Mirrors A6225 main dispatch loop.
 * tmpl: template string (0-terminated, uses directive chars above).
 * operands: array of operand values (val+str); consumed left-to-right.
 * The template may emit multiple instructions separated by N/Z/A markers.
 *
 * Implementation detail: we accumulate characters into a buffer, and
 * each N/Z/A marker flushes the previous buffer as a new instruction
 * and starts a new buffer for the next one. */
static void emit_template(const char *tmpl, const int *operands, int nops)
{
    char buf[INSTR_BUF];
    int  blen = 0;
    int  opi = 0;

    (void)nops;

#define TMPL_FLUSH() do { \
        buf[blen] = '\0'; \
        if (blen > 0) tmpl_emit_line(buf); \
        blen = 0; \
    } while (0)

#define TMPL_PUT(c) do { \
        if (blen < INSTR_BUF - 1) buf[blen++] = (char)(c); \
    } while (0)

#define TMPL_PUTS(s) do { \
        const char *_p = (s); \
        while (*_p && blen < INSTR_BUF - 1) buf[blen++] = *_p++; \
    } while (0)

    while (*tmpl) {
        unsigned char ch = (unsigned char)*tmpl++;
        switch (ch) {
        case 'N':  /* A6336: newline + tab → start new instruction */
            TMPL_FLUSH();
            break;
        case 'Z':  /* A6344: "\n\tld\t" */
            TMPL_FLUSH();
            TMPL_PUTS("ld\t");
            break;
        case 'A':  /* A6352: "\n\tadd\t" */
            TMPL_FLUSH();
            TMPL_PUTS("add\t");
            break;
        case 'X':  /* A6360 X-branch: "\n\tinc\thl" */
            TMPL_FLUSH();
            TMPL_PUTS("inc\thl");
            if (opi < nops) opi++;  /* ref advances IX even on X/Y */
            break;
        case 'Y':  /* A6360 Y-branch: "\n\tdec\thl" */
            TMPL_FLUSH();
            TMPL_PUTS("dec\thl");
            if (opi < nops) opi++;
            break;
        case 'R': { /* A627D: 8-bit register letter */
            int v = (opi < nops) ? operands[opi++] : 0;
            char r = A6225_R8_NAMES[v & 7];
            if (r == 'm') TMPL_PUTS("(hl)");
            else TMPL_PUT(r);
            break;
        }
        case 'P': { /* A62A4: 16-bit register pair */
            int v = (opi < nops) ? operands[opi++] : 0;
            int idx = v & 6;
            TMPL_PUT(A6225_R16_NAMES[idx]);
            TMPL_PUT(A6225_R16_NAMES[idx + 1]);
            break;
        }
        case 'D': { /* A62C0: full 16-bit decimal */
            int v = (opi < nops) ? operands[opi++] : 0;
            char num[16];
            snprintf(num, sizeof(num), "%u", (unsigned)(v & 0xFFFF));
            TMPL_PUTS(num);
            break;
        }
        case 'L': { /* A62CE: low-byte decimal */
            int v = (opi < nops) ? operands[opi++] : 0;
            char num[8];
            snprintf(num, sizeof(num), "%u", (unsigned)(v & 0xFF));
            TMPL_PUTS(num);
            break;
        }
        case 'H': { /* A62DB: high-byte decimal */
            int v = (opi < nops) ? operands[opi++] : 0;
            char num[8];
            snprintf(num, sizeof(num), "%u", (unsigned)((v >> 8) & 0xFF));
            TMPL_PUTS(num);
            break;
        }
        case 'C': { /* A632B: single char */
            int v = (opi < nops) ? operands[opi++] : 0;
            TMPL_PUT(v & 0xFF);
            break;
        }
        default:  /* A63A8: literal char */
            TMPL_PUT(ch);
            break;
        }
    }
    TMPL_FLUSH();

#undef TMPL_FLUSH
#undef TMPL_PUT
#undef TMPL_PUTS
}

/* Extended template emitter supporting S (string) and M (name) directives.
 * Each TmplOp carries both numeric value and optional string pointer.
 * - S: emit op.str verbatim (A62E8)
 * - M: emit op.str with '_' suffix handling (A62F6..A631A)
 * Otherwise same as emit_template. */
static void emit_template_ops(const char *tmpl, const TmplOp *ops, int nops)
{
    char buf[INSTR_BUF];
    int  blen = 0;
    int  opi = 0;

    (void)nops;

#define TMPL_FLUSH() do { \
        buf[blen] = '\0'; \
        if (blen > 0) tmpl_emit_line(buf); \
        blen = 0; \
    } while (0)

#define TMPL_PUT(c) do { \
        if (blen < INSTR_BUF - 1) buf[blen++] = (char)(c); \
    } while (0)

#define TMPL_PUTS(s) do { \
        const char *_p = (s); \
        while (*_p && blen < INSTR_BUF - 1) buf[blen++] = *_p++; \
    } while (0)

    while (*tmpl) {
        unsigned char ch = (unsigned char)*tmpl++;
        switch (ch) {
        case 'N': TMPL_FLUSH(); break;
        case 'Z': TMPL_FLUSH(); TMPL_PUTS("ld\t"); break;
        case 'A': TMPL_FLUSH(); TMPL_PUTS("add\t"); break;
        case 'X': TMPL_FLUSH(); TMPL_PUTS("inc\thl");
                  if (opi < nops) opi++; break;
        case 'Y': TMPL_FLUSH(); TMPL_PUTS("dec\thl");
                  if (opi < nops) opi++; break;
        case 'R': {
            int v = (opi < nops) ? ops[opi++].val : 0;
            char r = A6225_R8_NAMES[v & 7];
            if (r == 'm') TMPL_PUTS("(hl)");
            else TMPL_PUT(r);
            break;
        }
        case 'P': {
            int v = (opi < nops) ? ops[opi++].val : 0;
            int idx = v & 6;
            TMPL_PUT(A6225_R16_NAMES[idx]);
            TMPL_PUT(A6225_R16_NAMES[idx + 1]);
            break;
        }
        case 'D': {
            int v = (opi < nops) ? ops[opi++].val : 0;
            char num[16];
            snprintf(num, sizeof(num), "%u", (unsigned)(v & 0xFFFF));
            TMPL_PUTS(num);
            break;
        }
        case 'L': {
            int v = (opi < nops) ? ops[opi++].val : 0;
            char num[8];
            snprintf(num, sizeof(num), "%u", (unsigned)(v & 0xFF));
            TMPL_PUTS(num);
            break;
        }
        case 'H': {
            int v = (opi < nops) ? ops[opi++].val : 0;
            char num[8];
            snprintf(num, sizeof(num), "%u", (unsigned)((v >> 8) & 0xFF));
            TMPL_PUTS(num);
            break;
        }
        case 'C': {
            int v = (opi < nops) ? ops[opi++].val : 0;
            TMPL_PUT(v & 0xFF);
            break;
        }
        case 'S': {  /* A62E8: emit string verbatim */
            const char *s = (opi < nops) ? ops[opi++].str : NULL;
            if (s) TMPL_PUTS(s);
            break;
        }
        case 'M': {  /* A62F6: emit variable name with '_' suffix */
            const char *s = (opi < nops) ? ops[opi++].str : NULL;
            if (s) tmpl_emit_name(buf, &blen, s);
            break;
        }
        default:
            TMPL_PUT(ch);
            break;
        }
    }
    TMPL_FLUSH();

#undef TMPL_FLUSH
#undef TMPL_PUT
#undef TMPL_PUTS
}

/* Convenience wrappers: ported templates from CCC.ASM T63BD..T645C.
 * Each corresponds to a named template used by the ref compiler. */
/* T6403: "ZR,R" — ld <r8>,<r8> */
static const char A6225_T_LD_R_R[]       = "ZR,R";
/* T6408: "Ninc\ta" — inc a */
static const char A6225_T_INC_A[]        = "Ninc\ta";
/* T640F: "Ndec\ta" — dec a */
static const char A6225_T_DEC_A[]        = "Ndec\ta";
/* T6416: "Ninc\tR" — inc <r8> */
static const char A6225_T_INC_R[]        = "Ninc\tR";
/* T641D: "Ndec\tR" — dec <r8> */
static const char A6225_T_DEC_R[]        = "Ndec\tR";
/* T6424: "Za,R" — ld a,<r8> */
static const char A6225_T_LD_A_R[]       = "Za,R";
/* T6429: "ZR,a" — ld <r8>,a */
static const char A6225_T_LD_R_A[]       = "ZR,a";
/* T642E: "Nand\tL" — and <lo-byte> */
static const char A6225_T_AND_L[]        = "Nand\tL";
/* T6435: "Aa,L" — add a,<lo-byte> */
static const char A6225_T_ADD_A_L[]      = "Aa,L";
/* T643A: "Nsub\tL" — sub <lo-byte> */
static const char A6225_T_SUB_L[]        = "Nsub\tL";
/* T6441: "Aa,a" — add a,a */
static const char A6225_T_ADD_A_A[]      = "Aa,a";
/* T6446: "Ahl,hl" — add hl,hl */
static const char A6225_T_ADD_HL_HL[]    = "Ahl,hl";
/* T6456: "Nrrca" — rrca */
static const char A6225_T_RRCA[]         = "Nrrca";
/* T645C: "Nxor\ta" — xor a */
static const char A6225_T_XOR_A[]        = "Nxor\ta";

/* Peephole optimizer: remove redundant instruction sequences */
/* Check whether a given label name is referenced by any jp/jr/call
 * in the current instr_list (other than its own definition). */
static int peephole_label_referenced(const char *label_name)
{
    int k;
    for (k = 0; k < instr_count; k++) {
        Instr *ins = &instr_list[k];
        if (ins->type != INSTR_INST) continue;
        if (strstr(ins->text, label_name) != NULL) {
            /* Rough check — verify it's actually a label ref */
            const char *p = strstr(ins->text, label_name);
            /* Must be a full word: preceded by ',' or tab, followed by
             * end/whitespace/nothing (no trailing digits). */
            char prev = (p > ins->text) ? p[-1] : ' ';
            size_t len = strlen(label_name);
            char next = p[len];
            if ((prev == ',' || prev == '\t' || prev == ' ') &&
                (next == '\0' || next == ' ' || next == '\t' ||
                 next == ',' || next == '\n')) {
                return 1;
            }
        }
    }
    return 0;
}

static void peephole_optimize(void)
{
    int i, j;
    /* Pass: eliminate redundant patterns */
    for (i = 0; i < instr_count - 1; i++) {
        Instr *a = &instr_list[i];
        Instr *b = &instr_list[i + 1];

        /* ex de,hl / ex de,hl → remove both (double swap = no-op) */
        if (a->type == INSTR_INST && b->type == INSTR_INST &&
            strcmp(a->text, "ex\tde,hl") == 0 &&
            strcmp(b->text, "ex\tde,hl") == 0) {
            /* Remove both by shifting remaining instructions */
            for (j = i; j < instr_count - 2; j++)
                instr_list[j] = instr_list[j + 2];
            instr_count -= 2;
            i--; /* re-check at this position */
            continue;
        }

        /* @N: / @N: → remove one (duplicate label definition).
         * Can happen when two code paths emit the same target label
         * (e.g., loop exit coinciding with epilogue). */
        if (a->type == INSTR_LABEL && b->type == INSTR_LABEL &&
            strcmp(a->text, b->text) == 0) {
            for (j = i; j < instr_count - 1; j++)
                instr_list[j] = instr_list[j + 1];
            instr_count--;
            i--;
            continue;
        }

        /* @N: / @M: → remove @N: if not referenced (dead label before
         * another label). Common when our switch code emits redundant
         * labels that no jump targets. */
        if (a->type == INSTR_LABEL && b->type == INSTR_LABEL) {
            char label_ref[40];
            snprintf(label_ref, sizeof(label_ref), "%s", a->text);
            if (!peephole_label_referenced(label_ref)) {
                for (j = i; j < instr_count - 1; j++)
                    instr_list[j] = instr_list[j + 1];
                instr_count--;
                i--;
                continue;
            }
        }

        /* ld l,a / ld a,l → remove ld a,l (redundant reload) */
        if (a->type == INSTR_INST && b->type == INSTR_INST &&
            strcmp(a->text, "ld\tl,a") == 0 &&
            strcmp(b->text, "ld\ta,l") == 0) {
            for (j = i + 1; j < instr_count - 1; j++)
                instr_list[j] = instr_list[j + 1];
            instr_count--;
            continue;
        }

        /* ld a,l / ld l,a → remove ld l,a (redundant store-back) */
        if (a->type == INSTR_INST && b->type == INSTR_INST &&
            strcmp(a->text, "ld\ta,l") == 0 &&
            strcmp(b->text, "ld\tl,a") == 0) {
            for (j = i + 1; j < instr_count - 1; j++)
                instr_list[j] = instr_list[j + 1];
            instr_count--;
            continue;
        }

        /* jp @N / @N: → remove jp (jump to next instruction) */
        if (a->type == INSTR_INST && b->type == INSTR_LABEL) {
            /* Check if jp targets the next label */
            char expected[32];
            snprintf(expected, sizeof(expected), "%s", b->text);
            char jp_target[64];
            snprintf(jp_target, sizeof(jp_target), "%s", a->text);
            /* jp_target is like "@4" and expected is "@4" */
            if (strcmp(jp_target, expected) == 0) {
                /* Remove the jp */
                for (j = i; j < instr_count - 1; j++)
                    instr_list[j] = instr_list[j + 1];
                instr_count--;
                i--;
                continue;
            }
        }

        /* jp cc,@N / jp @M / @N: → jp !cc,@M (condition inversion)
         * Also: jp cc,@N / jp @N → jp @N (both go same place) */
        if (i + 2 < instr_count && a->type == INSTR_INST &&
            b->type == INSTR_INST && instr_list[i+2].type == INSTR_LABEL) {
            /* Check pattern: jp <cond>,@N / jp @M / @N: */
            char cond[16], target1[32], target2[32];
            if (sscanf(a->text, "jp\t%[^,],@%31s", cond, target1) == 2 &&
                sscanf(b->text, "jp\t@%31s", target2) == 1) {
                /* a = jp cond,@target1  b = jp @target2  c = @target1: */
                char expected[32];
                snprintf(expected, sizeof(expected), "@%s", target1);
                if (strcmp(instr_list[i+2].text, expected) == 0) {
                    /* Invert condition and remove extra jump */
                    const char *inv = NULL;
                    if (strcmp(cond, "z") == 0) inv = "nz";
                    else if (strcmp(cond, "nz") == 0) inv = "z";
                    else if (strcmp(cond, "c") == 0) inv = "nc";
                    else if (strcmp(cond, "nc") == 0) inv = "c";
                    if (inv) {
                        snprintf(a->text, INSTR_BUF, "jp\t%s,@%s", inv, target2);
                        /* Remove b (the unconditional jp) */
                        for (j = i + 1; j < instr_count - 1; j++)
                            instr_list[j] = instr_list[j + 1];
                        instr_count--;
                        i--;
                        continue;
                    }
                }
            }
        }
        /* jp cc,@N / jp @N → jp @N (redundant condition, both go same place) */
        if (a->type == INSTR_INST && b->type == INSTR_INST) {
            char cond[16], target1[32], target2[32];
            if (sscanf(a->text, "jp\t%[^,],@%31s", cond, target1) == 2 &&
                sscanf(b->text, "jp\t@%31s", target2) == 1 &&
                strcmp(target1, target2) == 0) {
                /* Remove the conditional jp (the unconditional one covers it) */
                for (j = i; j < instr_count - 1; j++)
                    instr_list[j] = instr_list[j + 1];
                instr_count--;
                i--;
                continue;
            }
        }

        /* pop de / ex de,hl / add hl,de → pop de / add hl,de
         * (commutative: popped + HL = HL + popped, skip the swap) */
        if (i + 2 < instr_count && a->type == INSTR_INST &&
            b->type == INSTR_INST && instr_list[i+2].type == INSTR_INST &&
            strcmp(a->text, "pop\tde") == 0 &&
            strcmp(b->text, "ex\tde,hl") == 0 &&
            strcmp(instr_list[i+2].text, "add\thl,de") == 0) {
            /* Remove the ex de,hl */
            for (j = i + 1; j < instr_count - 1; j++)
                instr_list[j] = instr_list[j + 1];
            instr_count--;
            i--;
            continue;
        }

        /* pop de / ex de,hl → pop hl (if DE's old value isn't needed after) */
        if (a->type == INSTR_INST && b->type == INSTR_INST &&
            strcmp(a->text, "pop\tde") == 0 &&
            strcmp(b->text, "ex\tde,hl") == 0) {
            int de_used = 0;
            if (i + 2 < instr_count) {
                Instr *c = &instr_list[i + 2];
                if (c->type == INSTR_INST &&
                    (strstr(c->text, ",de") || strstr(c->text, ",d") ||
                     strstr(c->text, ",e") || strstr(c->text, "de,") ||
                     strstr(c->text, "d,") || strstr(c->text, "e,")))
                    de_used = 1;
            }
            if (!de_used) {
                snprintf(a->text, INSTR_BUF, "pop\thl");
                for (j = i + 1; j < instr_count - 1; j++)
                    instr_list[j] = instr_list[j + 1];
                instr_count--;
                i--;
                continue;
            }
        }

        /* pop hl / ex de,hl → pop de (if HL's old value isn't needed after).
         * Common after VK_ADDR_HL save/restore where we need the popped
         * value in DE, not HL. */
        if (a->type == INSTR_INST && b->type == INSTR_INST &&
            strcmp(a->text, "pop\thl") == 0 &&
            strcmp(b->text, "ex\tde,hl") == 0) {
            int hl_used = 0;
            if (i + 2 < instr_count) {
                Instr *c = &instr_list[i + 2];
                if (c->type == INSTR_INST &&
                    (strstr(c->text, ",hl") || strstr(c->text, ",h") ||
                     strstr(c->text, ",l") || strstr(c->text, "hl,") ||
                     strstr(c->text, "h,") || strstr(c->text, "l,") ||
                     strstr(c->text, "(hl)")))
                    hl_used = 1;
            }
            if (!hl_used) {
                snprintf(a->text, INSTR_BUF, "pop\tde");
                for (j = i + 1; j < instr_count - 1; j++)
                    instr_list[j] = instr_list[j + 1];
                instr_count--;
                i--;
                continue;
            }
        }

        /* push hl / pop de → ex de,hl (register transfer) */
        if (a->type == INSTR_INST && b->type == INSTR_INST &&
            strcmp(a->text, "push\thl") == 0 &&
            strcmp(b->text, "pop\tde") == 0) {
            snprintf(a->text, INSTR_BUF, "ex\tde,hl");
            for (j = i + 1; j < instr_count - 1; j++)
                instr_list[j] = instr_list[j + 1];
            instr_count--;
            i--;
            continue;
        }

        /* ld de,0 / add hl,de → remove both (adding 0 is no-op) */
        if (a->type == INSTR_INST && b->type == INSTR_INST &&
            strcmp(a->text, "ld\tde,0") == 0 &&
            strcmp(b->text, "add\thl,de") == 0) {
            for (j = i; j < instr_count - 2; j++)
                instr_list[j] = instr_list[j + 2];
            instr_count -= 2;
            i--;
            continue;
        }

        /* 3-instruction patterns */
        if (i < instr_count - 2) {
            Instr *c = &instr_list[i + 2];

            /* ld l,(ix+N) / ld h,(ix+M) / ex de,hl → ld e,(ix+N) / ld d,(ix+M) */
            if (a->type == INSTR_INST && b->type == INSTR_INST &&
                c->type == INSTR_INST &&
                strncmp(a->text, "ld\tl,(ix", 8) == 0 &&
                strncmp(b->text, "ld\th,(ix", 8) == 0 &&
                strcmp(c->text, "ex\tde,hl") == 0) {
                /* Replace: l→e, h→d, remove ex */
                a->text[3] = 'e'; /* ld l → ld e */
                b->text[3] = 'd'; /* ld h → ld d */
                for (j = i + 2; j < instr_count - 1; j++)
                    instr_list[j] = instr_list[j + 1];
                instr_count--;
                i--;
                continue;
            }

            /* ld l,a / ld h,0 / ld a,l → ld l,a / ld h,0
             * (widening then immediately extracting byte = redundant) */
            if (a->type == INSTR_INST && b->type == INSTR_INST &&
                c->type == INSTR_INST &&
                strcmp(a->text, "ld\tl,a") == 0 &&
                strcmp(b->text, "ld\th,0") == 0 &&
                strcmp(c->text, "ld\ta,l") == 0) {
                for (j = i + 2; j < instr_count - 1; j++)
                    instr_list[j] = instr_list[j + 1];
                instr_count--;
                continue;
            }

            /* ex de,hl / call ?cpshd / jp z/nz →
             * Remove ex (equality is symmetric, Z flag same either way) */
            if (a->type == INSTR_INST && b->type == INSTR_INST &&
                c->type == INSTR_INST &&
                strcmp(a->text, "ex\tde,hl") == 0 &&
                strcmp(b->text, "call\t?cpshd") == 0 &&
                (strncmp(c->text, "jp\tz,", 5) == 0 ||
                 strncmp(c->text, "jp\tnz,", 6) == 0)) {
                for (j = i; j < instr_count - 1; j++)
                    instr_list[j] = instr_list[j + 1];
                instr_count--;
                i--;
                continue;
            }

            /* ld a,(hl) / ld l,a / ld h,0 → ld l,(hl) / ld h,0
             * (direct byte load without going through A) */
            if (a->type == INSTR_INST && b->type == INSTR_INST &&
                c->type == INSTR_INST &&
                strcmp(a->text, "ld\ta,(hl)") == 0 &&
                strcmp(b->text, "ld\tl,a") == 0 &&
                strcmp(c->text, "ld\th,0") == 0) {
                snprintf(a->text, INSTR_BUF, "ld\tl,(hl)");
                /* Remove b (ld l,a) */
                for (j = i + 1; j < instr_count - 1; j++)
                    instr_list[j] = instr_list[j + 1];
                instr_count--;
                i--;
                continue;
            }

            /* ld h,0 / ld a,l / ld h,0 → ld h,0 / ld a,l
             * (redundant second ld h,0) */
            if (a->type == INSTR_INST && b->type == INSTR_INST &&
                c->type == INSTR_INST &&
                strcmp(a->text, "ld\th,0") == 0 &&
                strcmp(b->text, "ld\ta,l") == 0 &&
                strcmp(c->text, "ld\th,0") == 0) {
                for (j = i + 2; j < instr_count - 1; j++)
                    instr_list[j] = instr_list[j + 1];
                instr_count--;
                continue;
            }

            /* 4-instruction: store+reload elimination
             * ld (ix+N),l / ld (ix+M),h / ld l,(ix+N) / ld h,(ix+M) →
             * ld (ix+N),l / ld (ix+M),h (remove redundant reload) */
            if (i + 3 < instr_count) {
                Instr *d = &instr_list[i + 3];
                if (a->type == INSTR_INST && b->type == INSTR_INST &&
                    c->type == INSTR_INST && d->type == INSTR_INST &&
                    strncmp(a->text, "ld\t(ix", 6) == 0 && strstr(a->text, "),l") &&
                    strncmp(b->text, "ld\t(ix", 6) == 0 && strstr(b->text, "),h") &&
                    strncmp(c->text, "ld\tl,(ix", 8) == 0 &&
                    strncmp(d->text, "ld\th,(ix", 8) == 0) {
                    /* Check that the offsets match */
                    char off1[16] = "", off2[16] = "", off3[16] = "", off4[16] = "";
                    sscanf(a->text, "ld\t(ix%15[^)]),l", off1);
                    sscanf(b->text, "ld\t(ix%15[^)]),h", off2);
                    sscanf(c->text, "ld\tl,(ix%15[^)])", off3);
                    sscanf(d->text, "ld\th,(ix%15[^)])", off4);
                    if (strcmp(off1, off3) == 0 && strcmp(off2, off4) == 0) {
                        /* Remove the reload (c and d) */
                        for (j = i + 2; j < instr_count - 2; j++)
                            instr_list[j] = instr_list[j + 2];
                        instr_count -= 2;
                        continue;
                    }
                }
            }
        }
    }
}

/* Emit any labels that are referenced by a jp but never defined.
 * Prevents assembler errors when codegen allocates a label and then
 * drops its definition (e.g. missing L<n> TMC line handling). */
static void emit_dangling_labels(void)
{
    int i, j;
    int seen[MAX_LABELS];
    int refd[MAX_LABELS];
    int k;
    for (k = 0; k < MAX_LABELS; k++) { seen[k] = 0; refd[k] = 0; }

    for (i = 0; i < instr_count; i++) {
        Instr *ins = &instr_list[i];
        if (ins->type == INSTR_LABEL) {
            int n = -1;
            if (sscanf(ins->text, "@%d", &n) == 1 && n >= 0 && n < MAX_LABELS)
                seen[n] = 1;
        } else if (ins->type == INSTR_INST) {
            const char *p = ins->text;
            while ((p = strchr(p, '@')) != NULL) {
                p++;
                if (*p >= '0' && *p <= '9') {
                    int n = 0;
                    while (*p >= '0' && *p <= '9') { n = n*10 + (*p - '0'); p++; }
                    if (n >= 0 && n < MAX_LABELS) refd[n] = 1;
                }
            }
        }
    }
    /* Epilogue label is emitted AFTER flush_instructions (direct file
     * write), so mark it as "seen" to avoid duplicate definition. */
    if (func_epilogue_label >= 0 && func_epilogue_label < MAX_LABELS)
        seen[func_epilogue_label] = 1;
    for (j = 0; j < MAX_LABELS; j++) {
        if (refd[j] && !seen[j] && instr_count < MAX_INSTR) {
            Instr *ins = &instr_list[instr_count++];
            ins->type = INSTR_LABEL;
            snprintf(ins->text, INSTR_BUF, "@%d", j);
        }
    }
}

static void flush_instructions(Cc2State *cc)
{
    int i;
    peephole_optimize();
    emit_dangling_labels();
    for (i = 0; i < instr_count; i++) {
        Instr *ins = &instr_list[i];
        switch (ins->type) {
            case INSTR_INST:
                io_write_byte(cc, '\t');
                io_write_str(cc, ins->text);
                io_write_newline(cc);
                break;
            case INSTR_LABEL:
                io_write_str(cc, ins->text);
                io_write_byte(cc, ':');
                io_write_newline(cc);
                break;
            case INSTR_COMMENT:
                io_write_byte(cc, ';');
                io_write_str(cc, ins->text);
                io_write_newline(cc);
                break;
            case INSTR_RAW:
                io_write_str(cc, ins->text);
                break;
        }
    }
    instr_count = 0;
}

/* ================================================================
 *  Global variable name with underscore suffix
 * ================================================================ */
static void make_asm_name(const char *cname, char *asmname, int maxlen)
{
    int len = (int)strlen(cname);
    if (len >= maxlen - 2) len = maxlen - 2;
    memcpy(asmname, cname, len);
    asmname[len] = '_';
    asmname[len + 1] = '\0';
}

/* ================================================================
 *  Struct size and member offset lookup
 * ================================================================ */
static int lookup_struct_size(Cc2State *cc, int struct_num)
{
    int i;
    for (i = 0; i < cc->sym_count; i++) {
        if ((cc->sym[i].type == SYM_STRUCT || cc->sym[i].type == SYM_UNION) &&
            cc->sym[i].name == (u16)struct_num) {
            return cc->sym[i].value;
        }
    }
    return 2;
}

static int lookup_member_offset(int member_num)
{
    int i;
    for (i = 0; i < member_count; i++) {
        if (member_list[i].member_num == member_num) {
            return member_list[i].offset;
        }
    }
    return 0;
}

static int lookup_member_size(int member_num)
{
    int i;
    for (i = 0; i < member_count; i++) {
        if (member_list[i].member_num == member_num) {
            return member_list[i].size;
        }
    }
    return 1;
}

static char lookup_member_type(int member_num)
{
    int i;
    for (i = 0; i < member_count; i++) {
        if (member_list[i].member_num == member_num) {
            return member_list[i].type;
        }
    }
    return 'C';
}

/* ================================================================
 *  Local variable lookup by TMC id
 * ================================================================ */
static LocalVar *find_local(int id)
{
    int i;
    for (i = 0; i < local_count; i++) {
        if (locals[i].id == id) return &locals[i];
    }
    return NULL;
}

/* ================================================================
 *  Body capture: read function body TMC into body_buf
 * ================================================================ */
static void body_capture(Cc2State *cc)
{
    body_buf_len = 0;
    int ch;
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == 0x1A) break;
        if (body_buf_len < MAX_BODY_BUF)
            body_buf[body_buf_len++] = (char)ch;
        if (ch == '}') {
            /* Capture rest of line after } */
            for (;;) {
                ch = tmc_read_char(cc);
                if (ch == '\n' || ch == 0x1A) {
                    if (body_buf_len < MAX_BODY_BUF)
                        body_buf[body_buf_len++] = '\n';
                    break;
                }
                if (body_buf_len < MAX_BODY_BUF)
                    body_buf[body_buf_len++] = (char)ch;
            }
            break;
        }
    }
}

/* Start replay of captured body */
static void body_start_replay(Cc2State *cc)
{
    cc->replay_buf = body_buf;
    cc->replay_pos = 0;
    cc->replay_len = body_buf_len;
    cc->pushback_count = 0;
}

static void body_stop_replay(Cc2State *cc)
{
    cc->replay_buf = NULL;
}

/* ================================================================
 *  Variable usage counting (pre-scan of body_buf)
 *
 *  Scans body_buf for A<n>/P<n> references and counts them.
 *  Also detects address-taken variables (a/@ after variable ref).
 * ================================================================ */
#define MAX_VAR_USAGE 128

typedef struct {
    int id;
    int count;         /* how many times referenced */
    int addr_taken;    /* 1 if address is taken ('a' or '@' after ref) */
    int assigned;      /* 1 if used as assignment target (:C/:N/:I) */
} VarUsage;

static VarUsage var_usage[MAX_VAR_USAGE];
static int var_usage_count;
static int body_has_calls;      /* 1 if body contains X (function calls) */
static int param_used_after_call; /* 1 if a P<n> ref appears after first X call */

static VarUsage *find_var_usage(int id)
{
    int i;
    for (i = 0; i < var_usage_count; i++) {
        if (var_usage[i].id == id) return &var_usage[i];
    }
    return NULL;
}

static void body_count_usage(void)
{
    int pos = 0;
    var_usage_count = 0;
    body_has_calls = 0;
    param_used_after_call = 0;

    /* First pass: find if there are any X (function call) tokens */
    {
        int p = 0;
        int seen_call = 0;
        while (p < body_buf_len) {
            int c = (u8)body_buf[p];
            if (c == 'X' && p > 0 && body_buf[p-1] == '\t') {
                body_has_calls = 1;
                seen_call = 1;
            }
            if (c == 'P' && seen_call && p + 1 < body_buf_len) {
                int nx = (u8)body_buf[p + 1];
                if (nx >= '0' && nx <= '9') {
                    param_used_after_call = 1;
                }
            }
            p++;
        }
    }

    while (pos < body_buf_len) {
        int ch = (u8)body_buf[pos];
        if ((ch == 'A' || ch == 'P') && pos + 1 < body_buf_len) {
            int next = (u8)body_buf[pos + 1];
            if (next >= '0' && next <= '9') {
                int num = 0;
                int p = pos + 1;
                while (p < body_buf_len && (u8)body_buf[p] >= '0' &&
                       (u8)body_buf[p] <= '9') {
                    num = num * 10 + ((u8)body_buf[p] - '0');
                    p++;
                }
                /* Valid token if followed by tab/newline */
                if (p >= body_buf_len || body_buf[p] == '\t' ||
                    body_buf[p] == '\n') {
                    VarUsage *vu = find_var_usage(num);
                    if (!vu && var_usage_count < MAX_VAR_USAGE) {
                        vu = &var_usage[var_usage_count++];
                        vu->id = num;
                        vu->count = 0;
                        vu->addr_taken = 0;
                        vu->assigned = 0;
                    }
                    if (vu) {
                        vu->count++;
                        /* Check if followed by 'a' (address-of operator).
                         * Note: '@' is array subscript, NOT address-of. */
                        if (p + 1 < body_buf_len &&
                            body_buf[p] == '\t' &&
                            body_buf[p + 1] == 'a') {
                            /* 'a' followed by tab means address-of */
                            if (p + 2 < body_buf_len &&
                                (body_buf[p + 2] == '\t' || body_buf[p + 2] == '\n'))
                                vu->addr_taken = 1;
                        }
                    }
                }
                pos = p;
                continue;
            }
        }
        pos++;
    }
}

/* ================================================================
 *  Code Tree Builder — Phase 1
 *
 *  Parses body_buf into tree nodes. Runs during the capture pass
 *  (alongside body_count_usage), does NOT emit any code.
 *  The tree will be used for enhanced variable analysis.
 * ================================================================ */

/* Tree-builder expression stack (parallel to gen_expr_stmt's vstack) */
static int ct_estack[VSTACK_MAX]; /* node indices */
static int ct_esp;

static void ct_push(int node_idx) {
    if (ct_esp < VSTACK_MAX) ct_estack[ct_esp++] = node_idx;
}

static int ct_pop(void) {
    if (ct_esp > 0) return ct_estack[--ct_esp];
    return -1;
}

static int ct_top(void) {
    if (ct_esp > 0) return ct_estack[ct_esp - 1];
    return -1;
}

/* Build a leaf node */
static int ct_make_const(int value, char type) {
    int n = ct_alloc_node();
    if (n < 0) return -1;
    ct_nodes[n].kind = CT_CONST;
    ct_nodes[n].type = type;
    ct_nodes[n].value = value;
    return n;
}

static int ct_make_var(int id, char prefix, char type) {
    int n = ct_alloc_node();
    if (n < 0) return -1;
    ct_nodes[n].kind = CT_VAR;
    ct_nodes[n].type = type;
    ct_nodes[n].value = id;
    ct_nodes[n].op = (u8)prefix; /* 'A' or 'P' */
    return n;
}

static int ct_make_global(const char *sym) {
    int n = ct_alloc_node();
    if (n < 0) return -1;
    ct_nodes[n].kind = CT_GLOBAL;
    ct_nodes[n].type = 'N';
    strncpy(ct_nodes[n].sym, sym, sizeof(ct_nodes[n].sym) - 1);
    return n;
}

/* Build an operator node linking children */
static int ct_make_unary(u8 op, char type, int child) {
    int n = ct_alloc_node();
    if (n < 0) return -1;
    ct_nodes[n].kind = CT_UNARY;
    ct_nodes[n].op = op;
    ct_nodes[n].type = type;
    ct_nodes[n].left = child;
    return n;
}

static int ct_make_binary(u8 op, char type, int left, int right) {
    int n = ct_alloc_node();
    if (n < 0) return -1;
    ct_nodes[n].kind = CT_BINARY;
    ct_nodes[n].op = op;
    ct_nodes[n].type = type;
    ct_nodes[n].left = left;
    ct_nodes[n].right = right;
    return n;
}

/* Build expression tree from one TMC expression line.
 * Uses the same token reading as gen_expr_stmt.
 * Returns root node index, or -1 on error/empty. */
static int ct_build_expr(Cc2State *cc)
{
    char tok[256];
    ct_esp = 0;

    for (;;) {
        int first = expr_read_tok(cc, tok, sizeof(tok));
        if (first == 0) break;

        switch (first) {
        case 'A': case 'P': {
            int id = atoi(tok + 1);
            int n = ct_make_var(id, (char)first, 'N');
            ct_push(n);
            break;
        }
        case 'G': {
            /* Store raw name — asm name conversion done later */
            int n = ct_make_global(tok + 1);
            ct_push(n);
            break;
        }
        case 'T': {
            /* Static local: T62 → ?62 */
            char asmn[128];
            snprintf(asmn, sizeof(asmn), "?%s", tok + 1);
            int n = ct_make_global(asmn);
            ct_push(n);
            break;
        }
        case '#': {
            int val;
            if (tok[1] == 'C') val = 1;
            else if (tok[1] == 'R' || tok[1] == 'N' || tok[1] == 'I') val = 2;
            else if (tok[1] == 'S') val = 2; /* struct size — approximate */
            else if (tok[1] == 'V') {
                int vnum = atoi(tok + 2); val = 0;
                int vi; for (vi = 0; vi < cc->sym_count; vi++)
                    if (cc->sym[vi].type == SYM_VAR && cc->sym[vi].name == (u16)vnum)
                        { val = cc->sym[vi].value; break; }
                if (val == 0) val = 2;
            } else val = atoi(tok + 1);
            int n = ct_make_const(val, 'N');
            ct_push(n);
            break;
        }
        case '"': {
            /* String constant — skip content, don't call parse_string_const
             * (that would allocate string labels prematurely) */
            { int sc; for (;;) { sc = tmc_read_char(cc); if (sc == '"' || sc == 0x1A) break; } }
            int n = ct_alloc_node();
            if (n >= 0) {
                ct_nodes[n].kind = CT_STRING;
                ct_nodes[n].value = 0;
                ct_nodes[n].type = 'R';
            }
            ct_push(n);
            break;
        }
        case '_': {
            /* Negate */
            int child = ct_pop();
            int n = ct_make_unary('_', tok[1], child);
            ct_push(n);
            break;
        }
        case '+': case '-': case '*': case '/': case '%':
        case '|': case '&': case '^': case 'l': case 'r': {
            int right = ct_pop();
            int left = ct_pop();
            int n = ct_make_binary((u8)first, tok[1], left, right);
            ct_push(n);
            break;
        }
        case '=': case '!': case '<': case '>': case '[': case ']': {
            /* Comparison */
            int right = ct_pop();
            int left = ct_pop();
            int n = ct_make_binary((u8)first, tok[1], left, right);
            ct_push(n);
            break;
        }
        case '?': {
            /* Ternary: cond ? true_val : false_val */
            int false_val = ct_pop();
            int true_val = ct_pop();
            int cond = ct_pop();
            int n = ct_alloc_node();
            if (n >= 0) {
                ct_nodes[n].kind = CT_BINARY;
                ct_nodes[n].op = '?';
                ct_nodes[n].type = tok[1];
                ct_nodes[n].left = true_val;
                ct_nodes[n].right = false_val;
                /* cond is implicit — it was already evaluated */
            }
            ct_push(n);
            break;
        }
        case ':': {
            /* Assignment: :C, :N, :I, :+C, :-N, etc. */
            int val = ct_pop();
            int dest = ct_pop();
            int n = ct_alloc_node();
            if (n >= 0) {
                ct_nodes[n].kind = CT_ASSIGN;
                ct_nodes[n].op = (u8)tok[1]; /* type or compound op */
                ct_nodes[n].type = tok[2] ? tok[2] : tok[1];
                ct_nodes[n].left = dest;
                ct_nodes[n].right = val;
            }
            ct_push(n);
            break;
        }
        case '\'': {
            /* Dereference */
            int child = ct_pop();
            int n = ct_make_unary('\'', 'N', child);
            ct_push(n);
            break;
        }
        case '@': {
            /* Address-of or array subscript pointer */
            int child = ct_pop();
            int n = ct_make_unary('@', 'R', child);
            ct_push(n);
            break;
        }
        case 'R': {
            /* Array subscript: pops index and base */
            int idx = ct_pop();
            int base = ct_pop();
            int n = ct_alloc_node();
            if (n >= 0) {
                ct_nodes[n].kind = CT_SUBSCR;
                ct_nodes[n].op = 'R';
                ct_nodes[n].type = tok[1];
                ct_nodes[n].left = base;
                ct_nodes[n].right = idx;
            }
            ct_push(n);
            break;
        }
        case 'N': case 'C': case 'I': {
            /* Type cast */
            int child = ct_top();
            if (child >= 0) {
                /* Just update type on existing node */
                ct_nodes[child].type = tok[1];
            }
            break;
        }
        case 'M': {
            /* Struct member */
            int mnum = atoi(tok + 1);
            int n = ct_alloc_node();
            if (n >= 0) {
                ct_nodes[n].kind = CT_MEMBER;
                ct_nodes[n].value = mnum;
                ct_nodes[n].type = 'N';
            }
            ct_push(n);
            break;
        }
        case '.': {
            /* Member access: pops struct and member */
            int member = ct_pop();
            int base = ct_pop();
            int n = ct_make_binary('.', 'N', base, member);
            ct_push(n);
            break;
        }
        case 'a': {
            /* Address-of (result is pointer) */
            int child = ct_pop();
            int n = ct_make_unary('a', 'R', child);
            ct_push(n);
            break;
        }
        case ';': {
            /* Compound inc/dec: ;+N, ;-N */
            int child = ct_pop();
            int n = ct_make_unary(';', tok[2], child);
            ct_nodes[n].op = (u8)tok[1]; /* + or - */
            ct_push(n);
            break;
        }
        case ',': {
            /* Comma: push count for function call */
            int n = ct_alloc_node();
            if (n >= 0) {
                ct_nodes[n].kind = CT_COMMA;
                ct_nodes[n].type = 'N';
            }
            ct_push(n);
            break;
        }
        case 'X': case 'Y': {
            /* Function call — record name + placeholder node.
             * Args follow (pushed to stack, consumed by 'p' directives).
             * Mirrors the ASM tree builder's CALL node creation. */
            int n = ct_alloc_node();
            if (n >= 0) {
                ct_nodes[n].kind = CT_CALL;
                strncpy(ct_nodes[n].sym, tok + 1, sizeof(ct_nodes[n].sym) - 1);
                ct_nodes[n].type = 'N';
            }
            ct_push(n);
            break;
        }
        case 'p': {
            /* Push arg — pop top value, attach as child of pending CT_CALL
             * (the topmost CT_CALL node on the stack). This preserves var
             * references inside args so they get counted in analysis. */
            int arg = ct_pop();
            int ci;
            for (ci = ct_esp - 1; ci >= 0; ci--) {
                int ni = ct_estack[ci];
                if (ni >= 0 && ni < ct_node_count &&
                    ct_nodes[ni].kind == CT_CALL) {
                    if (ct_nodes[ni].left < 0) {
                        ct_nodes[ni].left = arg;
                    } else if (ct_nodes[ni].right < 0) {
                        ct_nodes[ni].right = arg;
                    } else {
                        /* Chain further args through a CT_COMMA node */
                        int combo = ct_alloc_node();
                        if (combo >= 0) {
                            ct_nodes[combo].kind = CT_COMMA;
                            ct_nodes[combo].left = ct_nodes[ni].right;
                            ct_nodes[combo].right = arg;
                            ct_nodes[ni].right = combo;
                        }
                    }
                    break;
                }
            }
            break;
        }
        case 'c':
            /* Return type marker — no-op for tree build */
            break;
        case 'F': case 'U':
            /* Finalize call — args already attached, CT_CALL on stack */
            break;
        default:
            /* Unknown token — skip */
            break;
        }
    }

    /* Root is whatever's left on stack */
    return ct_pop();
}

/* Build code tree for entire function body from body_buf.
 * Called after body_capture(), runs in parallel with body_count_usage(). */
static void ct_build_body(Cc2State *cc)
{
    ct_node_count = 0;
    ct_stmt_count = 0;
    ct_var_count = 0;

    /* Save existing replay state */
    const char *saved_replay = cc->replay_buf;
    int saved_pos = cc->replay_pos;
    int saved_len = cc->replay_len;
    int saved_pb = cc->pushback_count;

    /* Setup replay from body_buf */
    cc->replay_buf = body_buf;
    cc->replay_pos = 0;
    cc->replay_len = body_buf_len;
    cc->pushback_count = 0;

    int loop_depth = 0;
    int ch;

    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == '}' || ch == 0x1A) break;

        if (ch == 'L') {
            /* Label definition */
            int lnum = tmc_read_number(cc);
            tmc_skip_line(cc);
            /* Record as a label statement */
            if (ct_stmt_count < CT_MAX_STMTS) {
                ct_stmts[ct_stmt_count].kind = 'L';
                ct_stmts[ct_stmt_count].label = lnum;
                ct_stmts[ct_stmt_count].root = -1;
                ct_stmt_count++;
            }
            continue;
        }

        if (ch == '\t') {
            ch = tmc_read_char(cc);

            if (ch == 'd') {
                /* Loop start */
                tmc_skip_line(cc);
                if (ct_stmt_count < CT_MAX_STMTS) {
                    ct_stmts[ct_stmt_count].kind = 'd';
                    ct_stmts[ct_stmt_count].root = -1;
                    ct_stmt_count++;
                }
                loop_depth++;
                continue;
            }

            if (ch == 'b') {
                /* Loop end */
                tmc_skip_line(cc);
                if (ct_stmt_count < CT_MAX_STMTS) {
                    ct_stmts[ct_stmt_count].kind = 'b';
                    ct_stmts[ct_stmt_count].root = -1;
                    ct_stmt_count++;
                }
                if (loop_depth > 0) loop_depth--;
                continue;
            }

            if (ch == 'j') {
                /* Conditional jump */
                tmc_expect_tab(cc);
                ch = tmc_read_char(cc); /* 'L' */
                int lnum = tmc_read_number(cc);
                tmc_expect_tab(cc);
                /* Build expression tree for the condition */
                int root = ct_build_expr(cc);
                if (ct_stmt_count < CT_MAX_STMTS) {
                    ct_stmts[ct_stmt_count].kind = 'j';
                    ct_stmts[ct_stmt_count].label = lnum;
                    ct_stmts[ct_stmt_count].root = root;
                    ct_stmt_count++;
                }
                continue;
            }

            if (ch == 'y') {
                /* Return */
                char rtype = (char)tmc_read_char(cc);
                int root = ct_build_expr(cc);
                if (ct_stmt_count < CT_MAX_STMTS) {
                    ct_stmts[ct_stmt_count].kind = 'y';
                    ct_stmts[ct_stmt_count].root = root;
                    ct_stmt_count++;
                }
                (void)rtype;
                continue;
            }

            if (ch == 'e') {
                /* Switch expression — tree form: statement kind 'e'
                 * with root = expression tree for switch value. */
                int etype = tmc_read_char(cc);
                tmc_expect_tab(cc);
                int root = ct_build_expr(cc);
                if (ct_stmt_count < CT_MAX_STMTS) {
                    ct_stmts[ct_stmt_count].kind = 's'; /* 's' = switch expr */
                    ct_stmts[ct_stmt_count].label = etype; /* C/I/N */
                    ct_stmts[ct_stmt_count].root = root;
                    ct_stmt_count++;
                }
                continue;
            }

            if (ch == 'w') {
                /* Switch case entry: w\tL<n>\t#<val> */
                tmc_expect_tab(cc);
                tmc_read_char(cc); /* 'L' */
                int lnum = tmc_read_number(cc);
                tmc_expect_tab(cc);
                tmc_read_char(cc); /* '#' */
                int cval = tmc_read_number(cc);
                tmc_skip_line(cc);
                if (ct_stmt_count < CT_MAX_STMTS) {
                    ct_stmts[ct_stmt_count].kind = 'w';
                    ct_stmts[ct_stmt_count].label = lnum;
                    ct_stmts[ct_stmt_count].negate = cval; /* case value */
                    ct_stmts[ct_stmt_count].root = -1;
                    ct_stmt_count++;
                }
                continue;
            }

            if (ch == 'f') {
                /* Switch default: f\tL<n> */
                tmc_expect_tab(cc);
                tmc_read_char(cc); /* 'L' */
                int lnum = tmc_read_number(cc);
                tmc_skip_line(cc);
                if (ct_stmt_count < CT_MAX_STMTS) {
                    ct_stmts[ct_stmt_count].kind = 'f';
                    ct_stmts[ct_stmt_count].label = lnum;
                    ct_stmts[ct_stmt_count].root = -1;
                    ct_stmt_count++;
                }
                continue;
            }

            /* Expression statement (including function calls) */
            tmc_pushback(cc, ch);
            int root = ct_build_expr(cc);
            if (ct_stmt_count < CT_MAX_STMTS) {
                ct_stmts[ct_stmt_count].kind = 'e';
                ct_stmts[ct_stmt_count].root = root;
                ct_stmt_count++;
            }
            continue;
        }

        /* Skip other characters */
    }

    /* Restore previous replay state */
    cc->replay_buf = saved_replay;
    cc->replay_pos = saved_pos;
    cc->replay_len = saved_len;
    cc->pushback_count = saved_pb;
}

/* ================================================================
 *  Phase 2: Analyze code tree — count variable references
 *
 *  Walk all tree nodes and count how many times each variable
 *  is referenced, at what loop depth, and whether it's used
 *  as an array base.
 * ================================================================ */
static CTVarInfo *ct_find_var(int id) {
    int i;
    for (i = 0; i < ct_var_count; i++)
        if (ct_vars[i].id == id) return &ct_vars[i];
    return NULL;
}

static void ct_count_node(int idx, int depth) {
    if (idx < 0 || idx >= ct_node_count) return;
    CTNode *n = &ct_nodes[idx];

    if (n->kind == CT_VAR) {
        CTVarInfo *v = ct_find_var(n->value);
        if (!v && ct_var_count < CT_MAX_VARS) {
            v = &ct_vars[ct_var_count++];
            memset(v, 0, sizeof(*v));
            v->id = n->value;
            v->prefix = (char)n->op;
        }
        if (v) {
            v->total_refs++;
            v->loop_refs += depth;
            if (depth > v->max_depth) v->max_depth = depth;
        }
    }

    /* Recurse into children */
    ct_count_node(n->left, depth);
    ct_count_node(n->right, depth);
}

/* Check if a tree contains any CT_CALL node. */
static int ct_tree_has_call(int idx)
{
    if (idx < 0 || idx >= ct_node_count) return 0;
    CTNode *n = &ct_nodes[idx];
    if (n->kind == CT_CALL) return 1;
    if (ct_tree_has_call(n->left)) return 1;
    if (ct_tree_has_call(n->right)) return 1;
    return 0;
}

static void ct_analyze_body(void) {
    ct_var_count = 0;
    int depth = 0;
    int i;
    /* First pass: count refs */
    for (i = 0; i < ct_stmt_count; i++) {
        CTStmt *s = &ct_stmts[i];
        if (s->kind == 'd') depth++;
        else if (s->kind == 'b') { if (depth > 0) depth--; }
        if (s->root >= 0) {
            ct_count_node(s->root, depth);
        }
    }

    /* Second pass: detect crosses_call using statement-range analysis.
     * For each variable, find first_stmt and last_stmt indices. If any
     * statement index in [first_stmt, last_stmt] contains a function
     * call (CT_CALL node), mark crosses_call. This is conservative but
     * correct: a variable whose live range (first-to-last ref) spans a
     * call can have its register value clobbered by that call. */
    {
        int first_stmt[CT_MAX_VARS];
        int last_stmt[CT_MAX_VARS];
        int k;
        for (k = 0; k < ct_var_count; k++) {
            first_stmt[k] = -1;
            last_stmt[k] = -1;
        }
        for (i = 0; i < ct_stmt_count; i++) {
            CTStmt *s = &ct_stmts[i];
            if (s->root < 0) continue;
            /* Collect unique var refs in this statement (iterative walk) */
            int stmt_vars[CT_MAX_VARS];
            int sv_count = 0;
            int stack[CT_MAX_NODES];
            int sp = 0;
            stack[sp++] = s->root;
            while (sp > 0) {
                int idx = stack[--sp];
                if (idx < 0 || idx >= ct_node_count) continue;
                CTNode *n = &ct_nodes[idx];
                if (n->kind == CT_VAR) {
                    int j;
                    int found = 0;
                    for (j = 0; j < sv_count; j++)
                        if (stmt_vars[j] == n->value) { found = 1; break; }
                    if (!found && sv_count < CT_MAX_VARS)
                        stmt_vars[sv_count++] = n->value;
                }
                if (n->left >= 0 && sp < CT_MAX_NODES) stack[sp++] = n->left;
                if (n->right >= 0 && sp < CT_MAX_NODES) stack[sp++] = n->right;
            }
            int j;
            for (j = 0; j < sv_count; j++) {
                int vid = stmt_vars[j];
                int vi;
                for (vi = 0; vi < ct_var_count; vi++) {
                    if (ct_vars[vi].id == vid) {
                        if (first_stmt[vi] < 0) first_stmt[vi] = i;
                        last_stmt[vi] = i;
                        break;
                    }
                }
            }
        }
        for (k = 0; k < ct_var_count; k++) {
            if (first_stmt[k] < 0 || first_stmt[k] == last_stmt[k]) continue;
            int ci;
            for (ci = first_stmt[k]; ci <= last_stmt[k]; ci++) {
                if (ci < 0 || ci >= ct_stmt_count) continue;
                CTStmt *s = &ct_stmts[ci];
                if (s->root >= 0 && ct_tree_has_call(s->root)) {
                    ct_vars[k].crosses_call = 1;
                    break;
                }
            }
        }
    }
}

/* ================================================================
 *  Tree-walking emitter — port of A19FB/A7374 in CCC.ASM
 *
 *  Walks the ct_nodes/ct_stmts code tree in evaluation order and
 *  emits Z80 instructions via the existing emit_instr/vstack
 *  infrastructure. The key advantage over streaming emission
 *  (gen_expr_stmt) is REORDERING: for an assignment whose RHS
 *  contains a function call that would clobber HL used for the
 *  LHS address, the tree walker evaluates RHS first, then LHS,
 *  matching the reference compiler's output.
 *
 *  Status: EARLY STAGE. Handles constants, globals, simple
 *  assignments. Falls back to direct emission via the 'ct_fallback'
 *  flag for unsupported node kinds. Gated behind env var
 *  CC2_TREE_EMIT=1 so existing output is preserved until the
 *  tree emitter reaches parity.
 *
 *  Mirrors CCC.ASM entry points:
 *    A19FB — recursive expression walker
 *    A7374 — main body iterator
 *    T8BF0 — op-code dispatch table (partially covered)
 * ================================================================ */

/* Forward decls — the emitter uses these helpers defined below */
static void vpush(int kind, const char *sym, int value, char type);
static VVal *vpop(void);
static VVal *vtop(void);
static void gen_load_hl(Cc2State *cc, VVal *v);
static void gen_load_de(Cc2State *cc, VVal *v);
static void gen_load_a(Cc2State *cc, VVal *v);
static void gen_load_bc(Cc2State *cc, VVal *v);
static void gen_store_hl(Cc2State *cc, VVal *dest);
static void gen_store_a(Cc2State *cc, VVal *dest);

/* Returns 1 if env var CC2_TREE_EMIT=1 — enables the new emitter. */
static int ct_emit_enabled(void)
{
    static int cached = -1;
    if (cached < 0) {
        const char *e = getenv("CC2_TREE_EMIT");
        cached = (e && e[0] == '1') ? 1 : 0;
    }
    return cached;
}

/* Set when ct_emit_node can't handle a subtree — caller should fall
 * back to direct TMC-streaming emission for that statement. */
static int ct_fallback;

/* Forward decl */
static void ct_emit_node(Cc2State *cc, int idx);

/* Check if a subtree contains a CT_CALL that would clobber HL. */
static int ct_subtree_has_call_local(int idx)
{
    if (idx < 0 || idx >= ct_node_count) return 0;
    CTNode *n = &ct_nodes[idx];
    if (n->kind == CT_CALL) return 1;
    if (ct_subtree_has_call_local(n->left)) return 1;
    if (ct_subtree_has_call_local(n->right)) return 1;
    return 0;
}

/* Emit code for a tree node. Result left on vstack.
 * Sets ct_fallback=1 if encountering an unhandled kind. */
static void ct_emit_node(Cc2State *cc, int idx)
{
    if (idx < 0 || idx >= ct_node_count) return;
    CTNode *n = &ct_nodes[idx];

    switch (n->kind) {
    case CT_CONST:
        vpush(VK_IMM, NULL, n->value, n->type ? n->type : 'N');
        break;
    case CT_GLOBAL: {
        /* Push as VK_GLOBAL; asm-name conversion already applied at build */
        char asmn[128];
        make_asm_name(n->sym, asmn, sizeof(asmn));
        vpush(VK_GLOBAL, asmn, 0, n->type ? n->type : 'N');
        /* Record extrn declaration if not already public */
        int found = 0, j;
        for (j = 0; j < decl_count; j++)
            if (strcmp(decl_list[j].name, asmn) == 0) { found = 1; break; }
        if (!found) decl_add(asmn, 0);
        break;
    }
    case CT_VAR: {
        LocalVar *lv = find_local(n->value);
        if (lv) {
            if (lv->reg != VK_NONE)
                vpush(lv->reg, NULL, 0, lv->type);
            else
                vpush(VK_LOCAL, NULL, lv->ix_offset, lv->type);
        } else {
            ct_fallback = 1;
        }
        break;
    }
    case CT_ASSIGN: {
        /* KEY REORDERING: evaluate RHS (right) first if it contains
         * a call — this is the critical fix for Mass[i] = rand() / K
         * patterns. LHS address is computed AFTER RHS to avoid HL
         * clobber. */
        int lhs = n->left;
        int rhs = n->right;
        char atype = (char)n->op; /* :C/:N/:I/:R */
        int rhs_has_call = ct_subtree_has_call_local(rhs);
        int lhs_is_addr_hl = 0;
        /* LHS "needs HL" if it's a DEREF (simple var goes to VK_LOCAL/
         * VK_GLOBAL and doesn't need HL for the store). */
        if (lhs >= 0 && lhs < ct_node_count) {
            CTNode *ln = &ct_nodes[lhs];
            if (ln->kind == CT_DEREF || ln->kind == CT_SUBSCR ||
                (ln->kind == CT_UNARY && ln->op == '\''))
                lhs_is_addr_hl = 1;
        }
        if (rhs_has_call && lhs_is_addr_hl) {
            /* Evaluate RHS first, preserve in DE; then compute LHS
             * address into HL; then store via (hl). */
            ct_emit_node(cc, rhs);
            if (ct_fallback) break;
            /* Result on vstack. Move to DE (for word) or A (for byte). */
            if (atype == 'C') {
                VVal *r = vtop();
                if (r) gen_load_a(cc, r);
                vsp--;
                ct_emit_node(cc, lhs);
                if (ct_fallback) break;
                /* LHS should now be VK_ADDR_HL */
                emit_instr(cc, "ld", "(hl),a");
                vpush(VK_A, NULL, 0, 'C');
            } else {
                VVal *r = vtop();
                if (r) gen_load_de(cc, r);
                vsp--;
                ct_emit_node(cc, lhs);
                if (ct_fallback) break;
                emit_instr(cc, "ld", "(hl),e");
                emit_instr(cc, "inc", "hl");
                emit_instr(cc, "ld", "(hl),d");
                vpush(VK_DE, NULL, 0, atype);
            }
        } else {
            /* Standard order: LHS, RHS, store via existing :I/:N/:C
             * logic. Emit both onto vstack, then simulate the :
             * dispatch to reuse existing code paths. */
            ct_emit_node(cc, lhs);
            if (ct_fallback) break;
            ct_emit_node(cc, rhs);
            if (ct_fallback) break;
            /* At this point vstack has [dest, value]. Fallback: mark
             * for streaming emitter to finish (rare in practice since
             * non-call RHS works fine streaming). */
            ct_fallback = 1;
        }
        break;
    }
    default:
        /* Unhandled node kind — fall back to streaming emitter */
        ct_fallback = 1;
        break;
    }
}

/* Attempt to emit a single statement from the tree. Returns 1 if
 * successfully emitted, 0 if fallback required. */
static int ct_emit_stmt(Cc2State *cc, int stmt_idx)
{
    if (stmt_idx < 0 || stmt_idx >= ct_stmt_count) return 0;
    CTStmt *s = &ct_stmts[stmt_idx];
    ct_fallback = 0;
    int saved_vsp = vsp;

    switch (s->kind) {
    case 'e':
        if (s->root < 0) return 1;
        ct_emit_node(cc, s->root);
        break;
    default:
        ct_fallback = 1;
        break;
    }

    if (ct_fallback) {
        /* Unwind vstack to saved depth — caller will re-emit via stream. */
        vsp = saved_vsp;
        return 0;
    }
    return 1;
}

/* ================================================================
 *  Register allocator — mirrors CCC.ASM optimizer phase 2
 *
 *  For frameless functions: all vars in registers, no IX frame.
 *  For framed functions: assign DE (and optionally BC) to the
 *  most-used scalar auto variables. Arrays/structs/addr-taken vars
 *  stay on stack. Parameters stay on stack (saved via push hl).
 *
 *  Modifies locals[].reg field.
 * ================================================================ */
static void try_register_allocate(void)
{
    int i;
    int auto_count = local_count - param_count;

    /* Already handled: trivial functions (0 autos, ≤1 param) */
    if (auto_count == 0 && param_count <= 1) return;

    /* === CASE 1: All vars fit in registers (frameless) === */
    {
        int all_scalar = 1;
        int used_count = 0;
        for (i = 0; i < local_count; i++) {
            if (locals[i].size > 2 || locals[i].type == 'S' ||
                locals[i].type == 'U') {
                all_scalar = 0;
                break;
            }
            VarUsage *vu = find_var_usage(locals[i].id);
            if (vu && vu->addr_taken) { all_scalar = 0; break; }
            if (vu && vu->count > 0) used_count++;
        }

        if (all_scalar && used_count <= 3) {
            /* Assign registers: params first, then autos */
            int pidx = 0;
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'P') {
                    VarUsage *vu = find_var_usage(locals[i].id);
                    if (vu && vu->count > 0) {
                        if (pidx == 0)
                            locals[i].reg = (locals[i].type == 'C') ? VK_A : VK_HL;
                        else if (pidx == 1)
                            locals[i].reg = VK_DE;
                        else goto partial; /* too many params */
                    }
                    pidx++;
                }
            }
            {
                int reg_order[] = { VK_DE, VK_BC, VK_HL };
                int reg_idx = 0;
                for (i = 0; i < local_count; i++) {
                    if (locals[i].prefix == 'A' && locals[i].reg == VK_NONE) {
                        VarUsage *vu = find_var_usage(locals[i].id);
                        if (!vu || vu->count == 0) continue;
                        int assigned = 0;
                        while (reg_idx < 3) {
                            int candidate = reg_order[reg_idx];
                            int taken = 0;
                            int j;
                            for (j = 0; j < local_count; j++) {
                                if (locals[j].reg == candidate) { taken = 1; break; }
                            }
                            reg_idx++;
                            if (!taken) {
                                locals[i].reg = candidate;
                                assigned = 1;
                                break;
                            }
                        }
                        if (!assigned) goto partial;
                    }
                }
            }
            /* All used vars register-allocated → eliminate frame */
            func_has_locals = 0;
            func_frame_bytes = 0;
            return;
        }
    }

partial:
    /* === CASE 2: Partial register allocation (framed function) ===
     * Assign DE to the most-used 2-byte scalar auto variable.
     * Parameters stay on stack (saved via push hl).
     * Arrays, structs, addr-taken stay on stack. */
    {
        /* Reset any partial assignments from case 1 attempt */
        for (i = 0; i < local_count; i++)
            locals[i].reg = VK_NONE;

        /* Find the most-used scalar auto variable → assign to DE.
         * Use code tree analysis (ct_vars) for scoring if available,
         * falling back to text-based var_usage. */
        int best_idx = -1;
        int best_score = 0;
        for (i = 0; i < local_count; i++) {
            if (locals[i].prefix != 'A') continue;
            if (locals[i].size > 2) continue;
            if (locals[i].type == 'S' || locals[i].type == 'U') continue;
            VarUsage *vu = find_var_usage(locals[i].id);
            if (!vu || vu->count == 0) continue;
            if (vu->addr_taken) continue;

            /* Score: use tree analysis for loop-weighted scoring */
            int score = vu->count;
            {
                CTVarInfo *cv = ct_find_var(locals[i].id);
                if (cv) {
                    /* Weight loop references more heavily */
                    score = cv->total_refs + cv->loop_refs * 3;
                }
            }
            if (score > best_score) {
                best_score = score;
                best_idx = i;
            }
        }

        if (best_idx >= 0) {
            locals[best_idx].reg = VK_DE;

            /* Try to assign BC to second most-used variable.
             * Only for 2-byte scalar autos that aren't address-taken. */
            {
                int bc_idx = -1;
                int bc_count = 0;
                for (i = 0; i < local_count; i++) {
                    if (i == best_idx) continue;
                    if (locals[i].prefix != 'A') continue;
                    if (locals[i].size != 2) continue;
                    if (locals[i].type == 'S' || locals[i].type == 'U') continue;
                    if (locals[i].type == 'C') continue; /* BC not good for char */
                    VarUsage *vu = find_var_usage(locals[i].id);
                    if (!vu || vu->count < 3) continue; /* only if well-used */
                    if (vu->addr_taken) continue;
                    if (vu->count > bc_count) {
                        bc_count = vu->count;
                        bc_idx = i;
                    }
                }
                if (bc_idx >= 0) {
                    locals[bc_idx].reg = VK_BC;
                }
            }

            /* Recalculate frame: params + scalars + structs deepest.
             * Same layout rule as the main allocator. */
            int offset = 0;
            func_has_locals = 0;
            /* Parameters first (closest to IX) */
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'P') {
                    offset += locals[i].size;
                    locals[i].ix_offset = -offset;
                    func_has_locals = 1;
                }
            }
            /* Scalars in declaration order */
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'A' &&
                    locals[i].type != 'S' && locals[i].type != 'U') {
                    if (locals[i].reg != VK_NONE) continue;
                    VarUsage *vu = find_var_usage(locals[i].id);
                    if (!vu || vu->count == 0) continue;
                    offset += locals[i].size;
                    locals[i].ix_offset = -offset;
                    func_has_locals = 1;
                }
            }
            /* Structs/unions at DEEPEST offsets. If the cumulative offset
             * before structs is odd (e.g. char scalar made it odd), pad so
             * struct bases align with SP after push-bc allocation. */
            int has_struct = 0;
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'A' &&
                    (locals[i].type == 'S' || locals[i].type == 'U')) {
                    if (locals[i].reg == VK_NONE) {
                        VarUsage *vu = find_var_usage(locals[i].id);
                        if (vu && vu->count > 0) { has_struct = 1; break; }
                    }
                }
            }
            if (has_struct && (offset & 1)) offset++;  /* pad before struct */
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'A' &&
                    (locals[i].type == 'S' || locals[i].type == 'U')) {
                    if (locals[i].reg != VK_NONE) continue;
                    VarUsage *vu = find_var_usage(locals[i].id);
                    if (!vu || vu->count == 0) continue;
                    offset += locals[i].size;
                    locals[i].ix_offset = -offset;
                    func_has_locals = 1;
                }
            }
            /* Round frame to even (push-bc = 2-byte alloc units) */
            if (offset & 1) offset++;
            func_frame_bytes = offset;
        }
    }
}

/* ================================================================
 *  Label management
 * ================================================================ */
static int get_label(Cc2State *cc, int tmc_label)
{
    if (tmc_label < 0 || tmc_label >= MAX_LABELS) return cc->local_label++;
    if (label_map[tmc_label] < 0) {
        label_map[tmc_label] = cc->local_label++;
    }
    return label_map[tmc_label];
}

static void emit_at_label(Cc2State *cc, int tmc_label)
{
    char buf[32];
    int n = get_label(cc, tmc_label);
    snprintf(buf, sizeof(buf), "@%d", n);
    emit_label_instr(buf);
}

/* ================================================================
 *  Symbolic expression evaluator for function call arguments
 *  (used for simple programs: CPRINTF, CPUTS, HELLO)
 * ================================================================ */
#define MAX_ARGS 16
#define ARG_BUF 128
#define EVAL_STACK_MAX 32

typedef struct {
    char sym[64];
    int  offset;
    int  is_string;
    int  str_idx;
    int  is_addr;
    int  is_deref;
    int  needs_push;
} ExprVal;

static ExprVal eval_stack[EVAL_STACK_MAX];
static int eval_sp;

static void eval_push(ExprVal *v)
{
    if (eval_sp < EVAL_STACK_MAX) eval_stack[eval_sp++] = *v;
}

static ExprVal *eval_pop(void)
{
    if (eval_sp > 0) return &eval_stack[--eval_sp];
    return NULL;
}

static ExprVal *eval_top(void)
{
    if (eval_sp > 0) return &eval_stack[eval_sp - 1];
    return NULL;
}

static void eval_format(ExprVal *v, char *buf, int maxlen, int use_hl)
{
    const char *reg = use_hl ? "hl" : "bc";
    if (v->is_deref) {
        if (v->sym[0]) {
            if (v->offset != 0)
                snprintf(buf, maxlen, "%s,(%s%+d)", reg, v->sym, v->offset);
            else
                snprintf(buf, maxlen, "%s,(%s)", reg, v->sym);
        } else {
            snprintf(buf, maxlen, "%s,(%d)", reg, v->offset);
        }
    } else if (v->sym[0]) {
        if (v->offset != 0)
            snprintf(buf, maxlen, "%s,%s%+d", reg, v->sym, v->offset);
        else
            snprintf(buf, maxlen, "%s,%s", reg, v->sym);
    } else {
        snprintf(buf, maxlen, "%s,%d", reg, v->offset & 0xFFFF);
    }
}

/* ================================================================
 *  Parse function call (for simple programs)
 *  Kept from original for CPRINTF/CPUTS/HELLO compatibility
 * ================================================================ */
static void parse_func_call(Cc2State *cc, const char *func_name)
{
    char asmname[128];
    make_asm_name(func_name, asmname, sizeof(asmname));

    ExprVal args[MAX_ARGS];
    int nargs = 0;
    int call_type = 0;
    int arg_count = 0;
    int ch;

    eval_sp = 0;

    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == '\n' || ch == 0x1A) break;
        if (ch == '\t') continue;

        if (ch == '"') {
            int sidx = parse_string_const(cc);
            ExprVal v;
            memset(&v, 0, sizeof(v));
            v.is_string = 1;
            v.str_idx = sidx;
            snprintf(v.sym, sizeof(v.sym), "?%d", str_consts[sidx].label);
            v.is_addr = 1;
            eval_push(&v);
        } else if (ch == 'a') {
            ExprVal *top = eval_top();
            if (top) top->is_addr = 1;
        } else if (ch == 'p') {
            int ptype = tmc_read_char(cc); /* R, I, N, C */
            ExprVal *top = eval_pop();
            if (top && nargs < MAX_ARGS) {
                args[nargs] = *top;
                args[nargs].needs_push = 1;
                /* For value types (I, N, C), dereference global symbols */
                if ((ptype == 'I' || ptype == 'N' || ptype == 'C')
                    && args[nargs].sym[0] && !args[nargs].is_addr)
                    args[nargs].is_deref = 1;
                nargs++;
            }
        } else if (ch == 'c') {
            tmc_read_char(cc);
        } else if (ch == 'U') {
            char buf[32];
            tmc_read_token(cc, buf, sizeof(buf));
            call_type = 'U';
            arg_count = atoi(buf);
            break;
        } else if (ch == 'F') {
            char buf[32];
            tmc_read_token(cc, buf, sizeof(buf));
            call_type = 'F';
            arg_count = atoi(buf);
            break;
        } else if (ch == 'G') {
            char buf[128];
            tmc_read_token(cc, buf, sizeof(buf));
            ExprVal v;
            memset(&v, 0, sizeof(v));
            make_asm_name(buf, v.sym, sizeof(v.sym));
            eval_push(&v);
        } else if (ch == '#') {
            char buf[128];
            tmc_read_token(cc, buf, sizeof(buf));
            ExprVal v;
            memset(&v, 0, sizeof(v));
            if (buf[0] == 'S') {
                int snum = atoi(buf + 1);
                v.offset = lookup_struct_size(cc, snum);
            } else if (buf[0] == 'V') {
                int vnum = atoi(buf + 1); v.offset = 0;
                int vi; for (vi = 0; vi < cc->sym_count; vi++)
                    if (cc->sym[vi].type == SYM_VAR && cc->sym[vi].name == (u16)vnum)
                        { v.offset = cc->sym[vi].value; break; }
                if (v.offset == 0) v.offset = 2;
            } else if (buf[0] == 'C') {
                v.offset = 1;
            } else if (buf[0] == 'R' || buf[0] == 'N' || buf[0] == 'I') {
                v.offset = 2;
            } else {
                v.offset = atoi(buf);
            }
            eval_push(&v);
        } else if (ch == '_') {
            tmc_read_char(cc);
            ExprVal *top = eval_top();
            if (top) top->offset = -top->offset;
        } else if (ch == '*') {
            tmc_read_char(cc);
            ExprVal *b = eval_pop();
            ExprVal *a = eval_pop();
            if (a && b) {
                if (a->sym[0] && !b->sym[0]) {
                    a->offset *= b->offset;
                    eval_push(a);
                } else if (!a->sym[0] && b->sym[0]) {
                    b->offset *= a->offset;
                    eval_push(b);
                } else if (!a->sym[0] && !b->sym[0]) {
                    a->offset *= b->offset;
                    eval_push(a);
                } else {
                    eval_push(a);
                }
            }
        } else if (ch == 'R') {
            tmc_read_char(cc);
            ExprVal *idx = eval_pop();
            ExprVal *base = eval_pop();
            if (base && idx) {
                ExprVal result;
                memset(&result, 0, sizeof(result));
                strcpy(result.sym, base->sym);
                result.offset = idx->offset;
                eval_push(&result);
            }
        } else if (ch == '\'') {
            ExprVal *top = eval_top();
            if (top) top->is_addr = 1;
        } else if (ch == '+') {
            tmc_read_char(cc);
            ExprVal *b = eval_pop();
            ExprVal *a = eval_pop();
            if (a && b) {
                if (a->sym[0] && !b->sym[0]) {
                    a->offset += b->offset;
                    eval_push(a);
                } else if (!a->sym[0] && b->sym[0]) {
                    b->offset += a->offset;
                    eval_push(b);
                } else {
                    a->offset += b->offset;
                    eval_push(a);
                }
            }
        } else if (ch == '-') {
            tmc_read_char(cc);
            ExprVal *b = eval_pop();
            ExprVal *a = eval_pop();
            if (a && b) {
                a->offset -= b->offset;
                eval_push(a);
            }
        } else if (ch == 'A' || ch == 'P') {
            /* Local/param variable reference in func call arg */
            char buf[128];
            tmc_read_token(cc, buf, sizeof(buf));
            int id = atoi(buf);
            LocalVar *lv = find_local(id);
            ExprVal v;
            memset(&v, 0, sizeof(v));
            if (lv) {
                /* Will need IX-relative addressing */
                v.offset = lv->ix_offset;
                v.is_deref = 0;
                /* For now, mark as needing special handling */
            }
            eval_push(&v);
        } else if (ch == 'N' || ch == 'I' || ch == 'C') {
            /* Type conversion token — read the second char */
            int ch2 = tmc_read_char(cc);
            (void)ch2;
            /* For symbolic evaluation, type conversions are no-ops */
        } else {
            char buf[128];
            buf[0] = (char)ch;
            int len = 1;
            for (;;) {
                ch = tmc_read_char(cc);
                if (ch == '\t' || ch == '\n' || ch == 0x1A) {
                    tmc_pushback(cc, ch);
                    break;
                }
                if (len < 126) buf[len++] = (char)ch;
            }
            buf[len] = '\0';
        }
    }

    /* Add extrn for called function first */
    decl_add(asmname, 0);

    /* Add extrn for global symbols in args */
    {
        int i;
        for (i = 0; i < nargs; i++) {
            if (args[i].sym[0] && !args[i].is_string && args[i].sym[0] != '?') {
                int j, found = 0;
                for (j = 0; j < decl_count; j++) {
                    if (strcmp(decl_list[j].name, args[i].sym) == 0) {
                        found = 1; break;
                    }
                }
                if (!found) decl_add(args[i].sym, 0);
            }
        }
    }

    /* Generate code */
    if (call_type == 'U') {
        int pushes = 0;
        int i;
        for (i = nargs - 1; i >= 0; i--) {
            if (args[i].needs_push) {
                char operand[128];
                /* Reference: strings/addresses → ld bc,?N / push bc
                 *            dereferenced values → ld hl,(sym) / push hl */
                if (args[i].is_string || !args[i].is_deref) {
                    eval_format(&args[i], operand, sizeof(operand), 0);
                    emit_instr(cc, "ld", operand);
                    emit_instr(cc, "push", "bc");
                } else {
                    eval_format(&args[i], operand, sizeof(operand), 1);
                    emit_instr(cc, "ld", operand);
                    emit_instr(cc, "push", "hl");
                }
                pushes++;
            }
        }
        char buf[32];
        snprintf(buf, sizeof(buf), "hl,%d", arg_count);
        emit_instr(cc, "ld", buf);
        emit_instr(cc, "call", asmname);
        int i2;
        for (i2 = 0; i2 < pushes; i2++)
            emit_instr(cc, "pop", "bc");
    } else if (call_type == 'F') {
        if (arg_count == 0) {
            emit_instr(cc, "call", asmname);
        } else if (arg_count == 1 && nargs > 0) {
            char operand[128];
            if (args[0].is_deref || (!args[0].is_addr && !args[0].is_string &&
                args[0].sym[0] && args[0].offset == 0)) {
                args[0].is_deref = 1;
                eval_format(&args[0], operand, sizeof(operand), 1);
            } else {
                eval_format(&args[0], operand, sizeof(operand), 1);
            }
            emit_instr(cc, "ld", operand);
            emit_instr(cc, "call", asmname);
        } else if (arg_count == 2 && nargs >= 2) {
            /* F2: args[1] → DE, args[0] → HL
             * Reference: ld hl,(arg1); ex de,hl; ld hl,arg0; call */
            char operand[128];
            eval_format(&args[1], operand, sizeof(operand), 1);
            emit_instr(cc, "ld", operand);
            emit_instr(cc, "ex", "de,hl");
            eval_format(&args[0], operand, sizeof(operand), 1);
            emit_instr(cc, "ld", operand);
            emit_instr(cc, "call", asmname);
        } else if (arg_count == 3 && nargs >= 3) {
            /* F3 reference order: DE first, BC second, HL third.
             * ld hl,arg1; ex de,hl; ld bc,arg2; ld hl,arg0; call */
            char operand[128];
            eval_format(&args[1], operand, sizeof(operand), 1);
            emit_instr(cc, "ld", operand);
            emit_instr(cc, "ex", "de,hl");
            eval_format(&args[2], operand, sizeof(operand), 0); /* bc */
            emit_instr(cc, "ld", operand);
            eval_format(&args[0], operand, sizeof(operand), 1);
            emit_instr(cc, "ld", operand);
            emit_instr(cc, "call", asmname);
        } else {
            int pushes = 0;
            int i;
            for (i = 0; i < nargs; i++) {
                if (args[i].needs_push) {
                    char operand[128];
                    eval_format(&args[i], operand, sizeof(operand), 0);
                    emit_instr(cc, "ld", operand);
                    emit_instr(cc, "push", "bc");
                    pushes++;
                }
            }
            char buf[32];
            snprintf(buf, sizeof(buf), "hl,%d", arg_count);
            emit_instr(cc, "ld", buf);
            emit_instr(cc, "call", asmname);
            int i2;
            for (i2 = 0; i2 < pushes; i2++)
                emit_instr(cc, "pop", "bc");
        }
    }
}

/* ================================================================
 *  Code-generating expression evaluator
 *
 *  Reads TMC postfix expression tokens and generates Z80 instructions
 *  into instr_list[]. Tracks value locations on vstack[].
 * ================================================================ */
static void vpush(int kind, const char *sym, int value, char type)
{
    if (vsp >= VSTACK_MAX) return;
    VVal *v = &vstack[vsp++];
    v->kind = kind;
    v->value = value;
    v->type = type;
    v->is_addr = 0;
    v->str_idx = -1;
    if (sym) {
        /* Copy to temp first to handle overlapping src/dest */
        char tmp[64];
        memcpy(tmp, sym, 64);
        memcpy(v->sym, tmp, 64);
    } else {
        v->sym[0] = '\0';
    }
}

static VVal *vpop(void)
{
    if (vsp > 0) return &vstack[--vsp];
    return NULL;
}

static VVal *vtop(void)
{
    if (vsp > 0) return &vstack[vsp - 1];
    return NULL;
}

/* Emit: ld hl,<16-bit value from VVal> */
static void gen_load_hl(Cc2State *cc, VVal *v)
{
    char buf[128];
    switch (v->kind) {
    case VK_IMM:
        snprintf(buf, sizeof(buf), "hl,%d", v->value & 0xFFFF);
        emit_instr(cc, "ld", buf);
        break;
    case VK_GLOBAL:
        if (v->is_addr) {
            /* Address of global: ld hl,name (not ld hl,(name)) */
            snprintf(buf, sizeof(buf), "hl,%s", v->sym);
        } else {
            snprintf(buf, sizeof(buf), "hl,(%s)", v->sym);
        }
        emit_instr(cc, "ld", buf);
        break;
    case VK_LOCAL:
        snprintf(buf, sizeof(buf), "l,(ix%+d)", v->value);
        emit_instr(cc, "ld", buf);
        snprintf(buf, sizeof(buf), "h,(ix%+d)", v->value + 1);
        emit_instr(cc, "ld", buf);
        break;
    case VK_HL:
        break; /* already in HL */
    case VK_DE:
        emit_instr(cc, "ex", "de,hl");
        break;
    case VK_BC:
        emit_instr(cc, "ld", "l,c");
        emit_instr(cc, "ld", "h,b");
        break;
    case VK_A:
        emit_instr(cc, "ld", "l,a");
        emit_instr(cc, "ld", "h,0");
        break;
    case VK_STRING:
        snprintf(buf, sizeof(buf), "hl,?%d",
                 str_consts[v->str_idx].label);
        emit_instr(cc, "ld", buf);
        break;
    case VK_ADDR_HL:
        /* HL holds an address — dereference to get 16-bit value */
        emit_instr(cc, "ld", "a,(hl)");
        emit_instr(cc, "inc", "hl");
        emit_instr(cc, "ld", "h,(hl)");
        emit_instr(cc, "ld", "l,a");
        break;
    default:
        snprintf(buf, sizeof(buf), "hl,0");
        emit_instr(cc, "ld", buf);
        break;
    }
}

/* Emit: ld a,<8-bit char value from VVal> */
static void gen_load_a(Cc2State *cc, VVal *v)
{
    char buf[128];
    switch (v->kind) {
    case VK_IMM:
        if ((v->value & 0xFF) == 0) {
            /* T645C: "Nxor\ta" — port via emit_template */
            emit_template(A6225_T_XOR_A, NULL, 0);
        } else {
            snprintf(buf, sizeof(buf), "a,%d", v->value & 0xFF);
            emit_instr(cc, "ld", buf);
        }
        break;
    case VK_GLOBAL:
        snprintf(buf, sizeof(buf), "a,(%s)", v->sym);
        emit_instr(cc, "ld", buf);
        break;
    case VK_LOCAL:
        snprintf(buf, sizeof(buf), "a,(ix%+d)", v->value);
        emit_instr(cc, "ld", buf);
        break;
    case VK_A:
        break;
    case VK_HL:
        emit_instr(cc, "ld", "a,l");
        break;
    case VK_DE:
        emit_instr(cc, "ld", "a,e");
        break;
    case VK_BC:
        emit_instr(cc, "ld", "a,c");
        break;
    case VK_ADDR_HL:
        /* HL holds address — dereference to get byte */
        emit_instr(cc, "ld", "a,(hl)");
        break;
    default:
        emit_instr(cc, "xor", "a");
        break;
    }
}

/* Emit: ld de,<16-bit value from VVal> */
static void gen_load_de(Cc2State *cc, VVal *v)
{
    char buf[128];
    switch (v->kind) {
    case VK_IMM:
        snprintf(buf, sizeof(buf), "de,%d", v->value & 0xFFFF);
        emit_instr(cc, "ld", buf);
        break;
    case VK_GLOBAL:
        if (v->is_addr) {
            snprintf(buf, sizeof(buf), "de,%s", v->sym);
            emit_instr(cc, "ld", buf);
        } else {
            /* Reference always uses ld hl,(sym); ex de,hl — not ld de,(sym) */
            snprintf(buf, sizeof(buf), "hl,(%s)", v->sym);
            emit_instr(cc, "ld", buf);
            emit_instr(cc, "ex", "de,hl");
        }
        break;
    case VK_LOCAL:
        snprintf(buf, sizeof(buf), "e,(ix%+d)", v->value);
        emit_instr(cc, "ld", buf);
        snprintf(buf, sizeof(buf), "d,(ix%+d)", v->value + 1);
        emit_instr(cc, "ld", buf);
        break;
    case VK_DE:
        break;
    case VK_HL:
        emit_instr(cc, "ex", "de,hl");
        break;
    case VK_BC:
        emit_instr(cc, "ld", "e,c");
        emit_instr(cc, "ld", "d,b");
        break;
    default:
        emit_instr(cc, "ld", "de,0");
        break;
    }
}

/* Store HL to destination */
static void gen_store_hl(Cc2State *cc, VVal *dest)
{
    char buf[128];
    switch (dest->kind) {
    case VK_GLOBAL:
        snprintf(buf, sizeof(buf), "(%s),hl", dest->sym);
        emit_instr(cc, "ld", buf);
        break;
    case VK_LOCAL:
        snprintf(buf, sizeof(buf), "(ix%+d),l", dest->value);
        emit_instr(cc, "ld", buf);
        snprintf(buf, sizeof(buf), "(ix%+d),h", dest->value + 1);
        emit_instr(cc, "ld", buf);
        break;
    case VK_DE:
        emit_instr(cc, "ex", "de,hl");
        break;
    case VK_BC:
        emit_instr(cc, "ld", "c,l");
        emit_instr(cc, "ld", "b,h");
        break;
    case VK_HL:
        break; /* already in HL */
    default:
        break;
    }
}

/* Store A to destination */
static void gen_store_a(Cc2State *cc, VVal *dest)
{
    char buf[128];
    switch (dest->kind) {
    case VK_GLOBAL:
        snprintf(buf, sizeof(buf), "(%s),a", dest->sym);
        emit_instr(cc, "ld", buf);
        break;
    case VK_LOCAL:
        snprintf(buf, sizeof(buf), "(ix%+d),a", dest->value);
        emit_instr(cc, "ld", buf);
        break;
    case VK_DE:
        emit_instr(cc, "ld", "e,a");
        break;
    case VK_BC:
        emit_instr(cc, "ld", "c,a");
        break;
    case VK_A:
        break; /* already in A */
    default:
        break;
    }
}

/* Emit: ld bc,<16-bit value from VVal> */
static void gen_load_bc(Cc2State *cc, VVal *v)
{
    char buf[128];
    switch (v->kind) {
    case VK_IMM:
        snprintf(buf, sizeof(buf), "bc,%d", v->value & 0xFFFF);
        emit_instr(cc, "ld", buf);
        break;
    case VK_LOCAL:
        snprintf(buf, sizeof(buf), "c,(ix%+d)", v->value);
        emit_instr(cc, "ld", buf);
        snprintf(buf, sizeof(buf), "b,(ix%+d)", v->value + 1);
        emit_instr(cc, "ld", buf);
        break;
    case VK_BC:
        break;
    case VK_HL:
        emit_instr(cc, "ld", "c,l");
        emit_instr(cc, "ld", "b,h");
        break;
    case VK_DE:
        emit_instr(cc, "ld", "c,e");
        emit_instr(cc, "ld", "b,d");
        break;
    case VK_GLOBAL:
        if (v->is_addr) {
            snprintf(buf, sizeof(buf), "bc,%s", v->sym);
            emit_instr(cc, "ld", buf);
            break;
        }
        /* Z80 has no ld bc,(nn) — load via HL */
        snprintf(buf, sizeof(buf), "hl,(%s)", v->sym);
        emit_instr(cc, "ld", buf);
        emit_instr(cc, "ld", "c,l");
        emit_instr(cc, "ld", "b,h");
        break;
    case VK_STRING:
        snprintf(buf, sizeof(buf), "bc,?%d", str_consts[v->str_idx].label);
        emit_instr(cc, "ld", buf);
        break;
    default:
        emit_instr(cc, "ld", "bc,0");
        break;
    }
}

/* Compute SP-relative offset for a local variable */
static int sp_relative_offset(int ix_offset, int extra_pushes)
{
    /* After prologue: SP = IX - func_frame_bytes
     * Variable at IX + ix_offset → SP + (func_frame_bytes + ix_offset)
     * Each pending push adds 2 to the adjustment */
    return func_frame_bytes + ix_offset + extra_pushes * 2;
}

/* ================================================================
 *  Inline function call code generation
 *
 *  Generates Z80 code for a function call collected by gen_expr_stmt.
 *  Handles U-type (varargs) and F-type (register args) calls.
 * ================================================================ */
/* Check if any register-allocated variables need saving across a call.
 * Returns a bitmask: bit 0 = save DE, bit 1 = save HL, bit 2 = save BC */
static int regs_to_save_across_call(void)
{
    int save = 0;
    int i;
    for (i = 0; i < local_count; i++) {
        if (locals[i].reg == VK_DE) save |= 1;
        else if (locals[i].reg == VK_HL) save |= 2;
        else if (locals[i].reg == VK_BC) save |= 4;
    }
    return save;
}

/* Emit push instructions to save register-allocated variables.
 * Returns number of pushes emitted. Order: DE first, then HL. */
static int emit_reg_saves(Cc2State *cc, int save_mask)
{
    int count = 0;
    if (save_mask & 1) { emit_instr(cc, "push", "de"); count++; }
    if (save_mask & 2) { emit_instr(cc, "push", "hl"); count++; }
    /* Note: BC is typically not saved (used as temp for args) */
    return count;
}

/* Emit pop instructions to restore register-allocated variables.
 * Reverse order of saves. */
static void emit_reg_restores(Cc2State *cc, int save_mask)
{
    if (save_mask & 2) emit_instr(cc, "pop", "hl");
    if (save_mask & 1) emit_instr(cc, "pop", "de");
}

static void gen_inline_call(Cc2State *cc, const char *asmname, int call_type, int arg_count)
{
    int i;

    /* Emit register saves for frameless functions.
     * hl_spilled/de_spilled: 1=needs saving, 2=already saved on stack.
     * Save before first call, restore on next param reference. */
    /* Push DE first so HL ends up on top (HL is popped first) */
    if (de_spilled == 1) {
        emit_instr(cc, "push", "de");
        de_spilled = 2;
    }
    if (hl_spilled == 1) {
        emit_instr(cc, "push", "hl");
        hl_spilled = 2;
    }
    (void)regs_to_save_across_call;
    (void)emit_reg_saves;
    (void)emit_reg_restores;

    if (call_type == 'U') {
        /* Varargs: push args in reverse, HL = count, call, pop */
        int pushes = 0;
        for (i = icall_nargs - 1; i >= 0; i--) {
            VVal *arg = &icall_args[i];
            char atype = icall_arg_types[i];

            if (arg->is_addr && arg->kind == VK_LOCAL) {
                /* Address of local array: ld hl,<sp_off> / add hl,sp / push hl */
                int sp_off = sp_relative_offset(arg->value, pushes);
                char buf[32];
                snprintf(buf, sizeof(buf), "hl,%d", sp_off);
                emit_instr(cc, "ld", buf);
                emit_instr(cc, "add", "hl,sp");
                emit_instr(cc, "push", "hl");
                pushes++;
            } else if (arg->is_addr && arg->kind == VK_STRING) {
                /* String address: ld bc,?label / push bc */
                char buf[128];
                snprintf(buf, sizeof(buf), "bc,?%d", str_consts[arg->str_idx].label);
                emit_instr(cc, "ld", buf);
                emit_instr(cc, "push", "bc");
                pushes++;
            } else if (atype == 'C') {
                /* Char arg: load byte, push as 16-bit */
                if (arg->kind == VK_LOCAL) {
                    char buf[32];
                    snprintf(buf, sizeof(buf), "c,(ix%+d)", arg->value);
                    emit_instr(cc, "ld", buf);
                } else {
                    gen_load_a(cc, arg);
                    emit_instr(cc, "ld", "c,a");
                }
                emit_instr(cc, "push", "bc");
                pushes++;
            } else if (arg->kind == VK_GLOBAL) {
                /* Global: ld hl,(name) or ld hl,name (address) / push hl */
                char buf[128];
                if (arg->is_addr)
                    snprintf(buf, sizeof(buf), "hl,%s", arg->sym);
                else
                    snprintf(buf, sizeof(buf), "hl,(%s)", arg->sym);
                emit_instr(cc, "ld", buf);
                emit_instr(cc, "push", "hl");
                pushes++;
            } else if (arg->kind == VK_HL) {
                /* Already in HL: just push hl */
                emit_instr(cc, "push", "hl");
                pushes++;
            } else if (arg->kind == VK_DE) {
                /* In DE: push de */
                emit_instr(cc, "push", "de");
                pushes++;
            } else {
                /* 16-bit value: load into bc, push */
                gen_load_bc(cc, arg);
                emit_instr(cc, "push", "bc");
                pushes++;
            }
        }
        {
            char buf[32];
            snprintf(buf, sizeof(buf), "hl,%d", arg_count);
            emit_instr(cc, "ld", buf);
        }
        emit_instr(cc, "call", asmname);
        /* Clean up pushed args */
        if (pushes >= 5) {
            /* Bulk SP adjustment: save result, adjust SP, restore */
            emit_instr(cc, "ex", "de,hl");
            {
                char buf[32];
                snprintf(buf, sizeof(buf), "hl,%d", pushes * 2);
                emit_instr(cc, "ld", buf);
            }
            emit_instr(cc, "add", "hl,sp");
            emit_instr(cc, "ld", "sp,hl");
            emit_instr(cc, "ex", "de,hl");
        } else {
            for (i = 0; i < pushes; i++) {
                emit_instr(cc, "pop", "bc");
            }
        }
    } else { /* F-type */
        if (arg_count == 0) {
            emit_instr(cc, "call", asmname);
        } else if (arg_count == 1 && icall_nargs >= 1) {
            VVal *a0 = &icall_args[0];
            if (icall_arg_types[0] == 'C') {
                gen_load_a(cc, a0);
            } else if (a0->is_addr && a0->kind == VK_LOCAL) {
                /* Address of local: ld hl,sp_off / add hl,sp */
                int sp_off = sp_relative_offset(a0->value, 0);
                char buf[32];
                snprintf(buf, sizeof(buf), "hl,%d", sp_off);
                emit_instr(cc, "ld", buf);
                emit_instr(cc, "add", "hl,sp");
            } else {
                gen_load_hl(cc, a0);
            }
            emit_instr(cc, "call", asmname);
        } else if (arg_count == 2 && icall_nargs >= 2) {
            VVal *a0 = &icall_args[0];
            VVal *a1 = &icall_args[1];
            /* Load second arg into DE first (so HL is free for first) */
            gen_load_de(cc, a1);
            gen_load_hl(cc, a0);
            emit_instr(cc, "call", asmname);
        } else if (arg_count == 3 && icall_nargs >= 3) {
            VVal *a0 = &icall_args[0];
            VVal *a1 = &icall_args[1];
            VVal *a2 = &icall_args[2];
            /* Load in order: BC (3rd), DE (2nd), HL (1st) */
            gen_load_bc(cc, a2);
            if (a1->is_addr && a1->kind == VK_LOCAL) {
                int sp_off = sp_relative_offset(a1->value, 0);
                char buf[32];
                snprintf(buf, sizeof(buf), "hl,%d", sp_off);
                emit_instr(cc, "ld", buf);
                emit_instr(cc, "add", "hl,sp");
                emit_instr(cc, "ex", "de,hl");
            } else {
                gen_load_de(cc, a1);
            }
            gen_load_hl(cc, a0);
            emit_instr(cc, "call", asmname);
        } else {
            /* Fallback: just call */
            emit_instr(cc, "call", asmname);
        }
    }
}

/* Check if function body has only simple function calls (no expressions) */
static int body_is_simple(Cc2State *cc)
{
    (void)cc;
    int i;
    for (i = param_count; i < local_count; i++) return 0;
    if (param_count > 0) return 0;
    return 1;
}

/* ================================================================
 *  Code-generating expression evaluator
 *
 *  Reads one expression statement from TMC (tab-separated postfix)
 *  and generates Z80 instructions into instr_list[].
 *
 *  Uses vstack[] to track where values currently reside.
 * ================================================================ */

/* Read a TMC expression token, return first char (0 on end-of-line) */
static int expr_read_tok(Cc2State *cc, char *buf, int maxlen)
{
    int ch = tmc_read_char(cc);
    if (ch == '\n' || ch == 0x1A) return 0;
    if (ch == '\t') {
        ch = tmc_read_char(cc);
        if (ch == '\n' || ch == 0x1A) return 0;
    }
    buf[0] = (char)ch;
    /* Some tokens are single char */
    if (ch == '.' || ch == '\'' || ch == 'a' || ch == 'n' || ch == '"' || ch == '@') {
        buf[1] = '\0';
        return ch;
    }
    /* Read rest of token until tab/newline */
    int len = 1;
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == '\t' || ch == '\n' || ch == 0x1A) {
            tmc_pushback(cc, ch);
            break;
        }
        if (len < maxlen - 1) buf[len++] = (char)ch;
    }
    buf[len] = '\0';
    return (u8)buf[0];
}

/* ================================================================
 *  Unified expression token handler
 *  Processes one TMC expression token and updates vstack[].
 *  Returns the first char, or 0 if it consumed the rest of line
 *  (e.g. function call via parse_func_call).
 * ================================================================ */
static int eval_one_token(Cc2State *cc, int first, const char *tok)
{
    switch (first) {
    case '_': {
        /* Negate: _I, _N */
        VVal *top = vtop();
        if (top) {
            if (top->kind == VK_IMM) {
                top->value = -top->value;
            } else {
                gen_load_hl(cc, top); vsp--;
                emit_instr(cc, "ex", "de,hl");
                emit_instr(cc, "ld", "hl,0");
                emit_instr(cc, "or", "a");
                emit_instr(cc, "sbc", "hl,de");
                vpush(VK_HL, NULL, 0, tok[1]);
            }
        }
        break;
    }
    case '@': {
        /* Dereference pointer or address-of array.
         * For VK_GLOBAL (pointer variable): load pointer → VK_ADDR_HL.
         * For VK_LOCAL (pointer variable): load pointer → VK_ADDR_HL.
         * For register-allocated pointer (DE/BC): transfer to HL → VK_ADDR_HL.
         * For arrays/other: mark as address. */
        VVal *top = vtop();
        if (top) {
            if (top->kind == VK_GLOBAL && !top->is_addr) {
                char buf[128];
                snprintf(buf, sizeof(buf), "hl,(%s)", top->sym);
                emit_instr(cc, "ld", buf);
                vsp--;
                vpush(VK_ADDR_HL, NULL, 0, top->type);
            } else if (top->kind == VK_LOCAL && !top->is_addr &&
                       top->type != 'S' && top->type != 'U') {
                /* Load pointer from local */
                char buf[32];
                snprintf(buf, sizeof(buf), "l,(ix%+d)", top->value);
                emit_instr(cc, "ld", buf);
                snprintf(buf, sizeof(buf), "h,(ix%+d)", top->value + 1);
                emit_instr(cc, "ld", buf);
                vsp--;
                vpush(VK_ADDR_HL, NULL, 0, top->type);
            } else if (top->kind == VK_DE && !top->is_addr &&
                       top->type == 'R') {
                /* Pointer in DE (register-allocated R-type auto) —
                 * transfer to HL for indirect memory access. Needed for
                 * LZH3's *A7++ = val pattern where A7 is register-
                 * allocated pointer. */
                emit_instr(cc, "ex", "de,hl");
                vsp--;
                vpush(VK_ADDR_HL, NULL, 0, top->type);
            } else if (top->kind == VK_BC && !top->is_addr &&
                       top->type == 'R') {
                emit_instr(cc, "ld", "l,c");
                emit_instr(cc, "ld", "h,b");
                vsp--;
                vpush(VK_ADDR_HL, NULL, 0, top->type);
            } else if (top->kind == VK_HL && !top->is_addr &&
                       top->type == 'R') {
                vsp--;
                vpush(VK_ADDR_HL, NULL, 0, top->type);
            } else {
                top->is_addr = 1;
            }
        }
        break;
    }
    default:
        return -1; /* not handled here */
    }
    return first;
}

/* Generate code for one expression statement line.
 * Called when the first non-tab char of the statement is already pushed back.
 * Reads to end of line. */
static void gen_expr_stmt(Cc2State *cc)
{
    char tok[128];
    vsp = 0;

    for (;;) {
        int first = expr_read_tok(cc, tok, sizeof(tok));
        if (first == 0) break;

        switch (first) {
        case 'A': case 'P': {
            /* Local/param variable reference */
            int id = atoi(tok + 1);
            LocalVar *lv = find_local(id);
            if (lv) {
                if (lv->reg == VK_HL && hl_spilled == 2) {
                    /* HL param was pushed to stack — pop to restore */
                    emit_instr(cc, "pop", "hl");
                    hl_spilled = 0; /* restored — don't save again unless needed */
                    vpush(VK_HL, NULL, 0, lv->type);
                } else if (lv->reg == VK_DE && de_spilled == 2) {
                    emit_instr(cc, "pop", "de");
                    de_spilled = 0;
                    vpush(VK_DE, NULL, 0, lv->type);
                } else if (lv->reg != VK_NONE) {
                    vpush(lv->reg, NULL, 0, lv->type);
                } else {
                    vpush(VK_LOCAL, NULL, lv->ix_offset, lv->type);
                }
            } else {
                vpush(VK_IMM, NULL, 0, 'N');
            }
            break;
        }
        case 'G': {
            /* Global variable reference */
            char asmn[128];
            make_asm_name(tok + 1, asmn, sizeof(asmn));
            vpush(VK_GLOBAL, asmn, 0, 'N');
            /* Ensure extrn declared (may be upgraded to public later) */
            int found = 0, j;
            for (j = 0; j < decl_count; j++) {
                if (strcmp(decl_list[j].name, asmn) == 0) { found = 1; break; }
            }
            if (!found) decl_add(asmn, 0);
            break;
        }
        case 'T': {
            /* Static local variable reference: T62 → ?62 */
            char asmn[128];
            snprintf(asmn, sizeof(asmn), "?%s", tok + 1);
            vpush(VK_GLOBAL, asmn, 0, 'N');
            break;
        }
        case '#': {
            /* Immediate constant or type size:
             * #C=1, #R=2, #N=2, #I=2, #S<n>=struct size, #V<n>=var size */
            int val;
            if (tok[1] == 'S') {
                val = lookup_struct_size(cc, atoi(tok + 2));
            } else if (tok[1] == 'V') {
                /* Variable-size type: look up total byte size from symbol table */
                int vnum = atoi(tok + 2);
                val = 0;
                {
                    int vi;
                    for (vi = 0; vi < cc->sym_count; vi++) {
                        if (cc->sym[vi].type == SYM_VAR &&
                            cc->sym[vi].name == (u16)vnum) {
                            val = cc->sym[vi].value; /* already: count * type_size */
                            break;
                        }
                    }
                }
                if (val == 0) val = 2; /* fallback */
            } else if (tok[1] == 'C') {
                val = 1; /* sizeof(char) */
            } else if (tok[1] == 'R' || tok[1] == 'N' || tok[1] == 'I') {
                val = 2; /* sizeof(int/ptr) = 2 bytes on Z80 */
            } else {
                val = atoi(tok + 1);
            }
            vpush(VK_IMM, NULL, val, 'N');
            break;
        }
        case 'M': {
            /* Struct member ref */
            int mnum = atoi(tok + 1);
            vpush(VK_MEMBER, NULL, mnum, 'N');
            break;
        }
        case '.': {
            /* Struct member access: pop member, modify base */
            VVal *member = vpop();
            VVal *base = vtop();
            if (member && base && member->kind == VK_MEMBER) {
                int off = lookup_member_offset(member->value);
                char mtype = lookup_member_type(member->value);
                if (base->kind == VK_LOCAL) {
                    base->value += off;
                    base->type = mtype;
                } else if (base->kind == VK_ADDR_HL) {
                    if (off > 0) {
                        char buf[32];
                        snprintf(buf, sizeof(buf), "hl,%d", off);
                        emit_instr(cc, "ld", buf);
                        emit_instr(cc, "add", "hl,sp");
                    }
                    base->type = mtype;
                }
            }
            break;
        }
        case '\'': {
            /* Dereference: load pointer and mark as indirect memory access.
             * For VK_ADDR_HL: already an address in HL — keep as-is.
             * For VK_GLOBAL: load pointer from global into HL → VK_ADDR_HL.
             * For VK_LOCAL: similar — load pointer from IX-relative.
             * For others: mark as "address" (lvalue for assignment). */
            VVal *top = vtop();
            if (top) {
                if (top->kind == VK_ADDR_HL) {
                    /* Already an address in HL — keep as VK_ADDR_HL */
                } else if (top->kind == VK_GLOBAL && !top->is_addr) {
                    /* Global pointer: load pointer value into HL */
                    char buf[128];
                    snprintf(buf, sizeof(buf), "hl,(%s)", top->sym);
                    emit_instr(cc, "ld", buf);
                    vsp--;
                    vpush(VK_ADDR_HL, NULL, 0, top->type);
                } else if (top->kind == VK_LOCAL && !top->is_addr) {
                    /* Local pointer: load from IX-relative into HL */
                    char buf[32];
                    snprintf(buf, sizeof(buf), "l,(ix%+d)", top->value);
                    emit_instr(cc, "ld", buf);
                    snprintf(buf, sizeof(buf), "h,(ix%+d)", top->value + 1);
                    emit_instr(cc, "ld", buf);
                    vsp--;
                    vpush(VK_ADDR_HL, NULL, 0, top->type);
                } else if (top->kind == VK_HL && !top->is_addr) {
                    /* HL has a pointer value — mark as address */
                    top->kind = VK_ADDR_HL;
                } else {
                    top->is_addr = 1;
                }
            }
            break;
        }
        case ':': {
            /* Assignment: :C, :N, :I, and compound :+C, :+N, :+I
             * Handles VK_ADDR_HL (indirect memory access) for both src and dest. */
            char type = tok[1];
            /* Compound assignment: :+N, :-N, :lN (shift-assign), :|N (OR-assign) */
            if (type == 'l') {
                /* Left-shift-assign: var <<= delta */
                char ctype = tok[2];
                VVal *delta = vpop();
                VVal *var = vpop();
                if (var && delta) {
                    gen_load_hl(cc, var);
                    if (delta->kind == VK_IMM && delta->value <= 7) {
                        int n;
                        for (n = 0; n < delta->value; n++)
                            emit_instr(cc, "add", "hl,hl");
                    } else if (delta->kind == VK_IMM && delta->value == 8) {
                        emit_instr(cc, "ld", "h,l");
                        emit_instr(cc, "ld", "l,0");
                    } else {
                        gen_load_a(cc, delta);
                        emit_instr(cc, "ld", "b,a");
                        decl_add("?slnhb", 0);
                        emit_instr(cc, "call", "?slnhb");
                    }
                    gen_store_hl(cc, var);
                    vpush(VK_HL, NULL, 0, ctype);
                }
                break;
            }
            if (type == '|') {
                /* OR-assign: var |= delta */
                char ctype = tok[2];
                VVal *delta = vpop();
                VVal *var = vpop();
                if (var && delta) {
                    gen_load_de(cc, delta);
                    gen_load_hl(cc, var);
                    emit_instr(cc, "ld", "a,l");
                    emit_instr(cc, "or", "e");
                    emit_instr(cc, "ld", "l,a");
                    emit_instr(cc, "ld", "a,h");
                    emit_instr(cc, "or", "d");
                    emit_instr(cc, "ld", "h,a");
                    gen_store_hl(cc, var);
                    vpush(VK_HL, NULL, 0, ctype);
                }
                break;
            }
            if (type == 'r') {
                /* Right-shift-assign: var >>= delta */
                char ctype = tok[2];
                VVal *delta = vpop();
                VVal *var = vpop();
                if (var && delta) {
                    gen_load_hl(cc, var);
                    if (delta->kind == VK_IMM && delta->value <= 7) {
                        int n;
                        for (n = 0; n < delta->value; n++) {
                            emit_instr(cc, "srl", "h");
                            emit_instr(cc, "rr", "l");
                        }
                    } else {
                        gen_load_a(cc, delta);
                        emit_instr(cc, "ld", "b,a");
                        decl_add("?srnhb", 0);
                        emit_instr(cc, "call", "?srnhb");
                    }
                    gen_store_hl(cc, var);
                    vpush(VK_HL, NULL, 0, ctype);
                }
                break;
            }
            if (type == '&') {
                /* AND-assign: var &= delta */
                char ctype = tok[2];
                VVal *delta = vpop();
                VVal *var = vpop();
                if (var && delta) {
                    gen_load_de(cc, delta);
                    gen_load_hl(cc, var);
                    emit_instr(cc, "ld", "a,l");
                    emit_instr(cc, "and", "e");
                    emit_instr(cc, "ld", "l,a");
                    emit_instr(cc, "ld", "a,h");
                    emit_instr(cc, "and", "d");
                    emit_instr(cc, "ld", "h,a");
                    gen_store_hl(cc, var);
                    vpush(VK_HL, NULL, 0, ctype);
                }
                break;
            }
            if (type == '+' || type == '-') {
                char ctype = tok[2]; /* actual type: N, C, I */
                VVal *delta = vpop();
                VVal *var = vpop();
                if (var && delta) {
                    if (ctype == 'C') {
                        gen_load_a(cc, var);
                        if (type == '+') {
                            if (delta->kind == VK_IMM && delta->value == 1)
                                emit_instr(cc, "inc", "a");
                            else {
                                emit_instr(cc, "ld", "e,a");
                                gen_load_a(cc, delta);
                                emit_instr(cc, "add", "a,e");
                            }
                        } else {
                            if (delta->kind == VK_IMM && delta->value == 1)
                                emit_instr(cc, "dec", "a");
                            else {
                                emit_instr(cc, "ld", "e,a");
                                gen_load_a(cc, delta);
                                emit_instr(cc, "sub", "e");
                            }
                        }
                        gen_store_a(cc, var);
                        vpush(VK_A, NULL, 0, 'C');
                    } else {
                        /* Optimized: inc/dec for register pairs */
                        if (var->kind == VK_DE && delta->kind == VK_IMM && delta->value == 1) {
                            emit_instr(cc, type == '+' ? "inc" : "dec", "de");
                            vpush(VK_DE, NULL, 0, ctype);
                            break;
                        }
                        gen_load_hl(cc, var);
                        if (type == '+') {
                            if (delta->kind == VK_IMM && delta->value == 1)
                                emit_instr(cc, "inc", "hl");
                            else if (delta->kind == VK_IMM) {
                                char buf[32];
                                snprintf(buf, sizeof(buf), "de,%d", delta->value & 0xFFFF);
                                emit_instr(cc, "ld", buf);
                                emit_instr(cc, "add", "hl,de");
                            } else {
                                emit_instr(cc, "push", "hl");
                                gen_load_hl(cc, delta);
                                emit_instr(cc, "pop", "de");
                                emit_instr(cc, "ex", "de,hl");
                                emit_instr(cc, "add", "hl,de");
                            }
                        } else {
                            if (delta->kind == VK_IMM && delta->value == 1) {
                                emit_instr(cc, "dec", "hl");
                            } else if (delta->kind == VK_IMM) {
                                /* Subtract constant: add two's complement */
                                int neg = (-delta->value) & 0xFFFF;
                                char buf[32];
                                snprintf(buf, sizeof(buf), "de,%d", neg);
                                emit_instr(cc, "ld", buf);
                                emit_instr(cc, "add", "hl,de");
                            } else {
                                emit_instr(cc, "push", "hl");
                                gen_load_hl(cc, delta);
                                emit_instr(cc, "pop", "de");
                                emit_instr(cc, "ex", "de,hl");
                                emit_instr(cc, "or", "a");
                                emit_instr(cc, "sbc", "hl,de");
                            }
                        }
                        gen_store_hl(cc, var);
                        vpush(VK_HL, NULL, 0, ctype);
                    }
                }
                break;
            }
            VVal *value = vpop();
            VVal *dest = vpop();
            if (value && dest) {
                if (type == 'C') {
                    /* Char assignment */
                    if (value->kind == VK_ADDR_HL && dest->kind == VK_STACK) {
                        /* RHS addr in HL, LHS addr saved on hardware stack */
                        emit_instr(cc, "ld", "a,(hl)");  /* load src byte */
                        emit_instr(cc, "pop", "hl");      /* restore dest addr */
                        emit_instr(cc, "ld", "(hl),a");   /* store */
                        vpush(VK_A, NULL, 0, 'C');
                    } else if (value->kind == VK_ADDR_HL && dest->kind == VK_ADDR_HL) {
                        /* Both in HL — shouldn't happen with save logic, but handle */
                        emit_instr(cc, "ld", "a,(hl)");
                        vpush(VK_A, NULL, 0, 'C');
                    } else if (value->kind == VK_ADDR_HL) {
                        /* Source is indirect: load byte from (HL) */
                        emit_instr(cc, "ld", "a,(hl)");
                        gen_store_a(cc, dest);
                        vpush(VK_A, NULL, 0, 'C');
                    } else if (dest->kind == VK_ADDR_HL) {
                        /* Dest is indirect: store byte to (HL) */
                        if (value->kind == VK_IMM) {
                            char ibuf[32];
                            snprintf(ibuf, sizeof(ibuf), "(hl),%d", value->value & 0xFF);
                            emit_instr(cc, "ld", ibuf);
                        } else {
                            gen_load_a(cc, value);
                            emit_instr(cc, "ld", "(hl),a");
                        }
                        vpush(VK_A, NULL, 0, 'C');
                    } else {
                        gen_load_a(cc, value);
                        gen_store_a(cc, dest);
                        vpush(VK_A, NULL, 0, 'C');
                    }
                } else {
                    /* 16-bit assignment */
                    if (value->kind == VK_ADDR_HL && dest->kind == VK_ADDR_HL) {
                        /* Both indirect — complex case */
                        emit_instr(cc, "ld", "a,(hl)");
                        emit_instr(cc, "inc", "hl");
                        emit_instr(cc, "ld", "h,(hl)");
                        emit_instr(cc, "ld", "l,a");
                        /* value now in HL, dest address lost — need to handle */
                        vpush(VK_HL, NULL, 0, type);
                    } else if (value->kind == VK_ADDR_HL && value->is_addr) {
                        /* Source has address-of applied ('a' after '):
                         * HL already holds the address itself (pointer value),
                         * no deref — just store HL to dest. */
                        gen_store_hl(cc, dest);
                        vpush(VK_HL, NULL, 0, type);
                    } else if (value->kind == VK_ADDR_HL) {
                        /* Source is indirect: load 16-bit from (HL) */
                        emit_instr(cc, "ld", "a,(hl)");
                        emit_instr(cc, "inc", "hl");
                        emit_instr(cc, "ld", "h,(hl)");
                        emit_instr(cc, "ld", "l,a");
                        gen_store_hl(cc, dest);
                        vpush(VK_HL, NULL, 0, type);
                    } else if (dest->kind == VK_ADDR_HL) {
                        /* Dest is indirect: store 16-bit to (HL) */
                        if (value->kind == VK_IMM) {
                            int lo = value->value & 0xFF;
                            int hi = (value->value >> 8) & 0xFF;
                            char buf[32];
                            snprintf(buf, sizeof(buf), "(hl),%d", lo);
                            emit_instr(cc, "ld", buf);
                            emit_instr(cc, "inc", "hl");
                            snprintf(buf, sizeof(buf), "(hl),%d", hi);
                            emit_instr(cc, "ld", buf);
                        } else {
                            gen_load_de(cc, value);
                            emit_instr(cc, "ld", "(hl),e");
                            emit_instr(cc, "inc", "hl");
                            emit_instr(cc, "ld", "(hl),d");
                        }
                        vpush(VK_DE, NULL, 0, type);
                    } else if (dest->kind == VK_DE) {
                        /* Store to DE register: load directly */
                        gen_load_de(cc, value);
                        vpush(VK_DE, NULL, 0, type);
                    } else if (dest->kind == VK_BC) {
                        gen_load_bc(cc, value);
                        vpush(VK_BC, NULL, 0, type);
                    } else if (dest->kind == VK_STACK) {
                        /* LHS address was saved on hardware stack across a
                         * function call. Load value into DE, pop address
                         * into HL, store via HL (matches ASM pattern when
                         * VK_ADDR_HL spills). */
                        gen_load_de(cc, value);
                        emit_instr(cc, "pop", "hl");
                        emit_instr(cc, "ld", "(hl),e");
                        emit_instr(cc, "inc", "hl");
                        emit_instr(cc, "ld", "(hl),d");
                        vpush(VK_DE, NULL, 0, type);
                    } else {
                        gen_load_hl(cc, value);
                        gen_store_hl(cc, dest);
                        vpush(VK_HL, NULL, 0, type);
                    }
                }
            }
            break;
        }
        case '+': {
            /* Addition: +C, +N, +I */
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                /* Constant folding */
                if (a->kind == VK_IMM && b->kind == VK_IMM) {
                    vpush(VK_IMM, NULL, (a->value + b->value) & 0xFFFF, type);
                    break;
                }
                if (type == 'C') {
                    if (b->kind == VK_IMM && b->value == 1) {
                        gen_load_a(cc, a);
                        emit_instr(cc, "inc", "a");
                    } else if (b->kind == VK_IMM) {
                        gen_load_a(cc, a);
                        char buf[32];
                        snprintf(buf, sizeof(buf), "a,%d", b->value & 0xFF);
                        emit_instr(cc, "add", buf);
                    } else {
                        /* Save a, load b, add */
                        gen_load_a(cc, a);
                        emit_instr(cc, "push", "af");
                        gen_load_a(cc, b);
                        emit_instr(cc, "ld", "e,a");
                        emit_instr(cc, "pop", "af");
                        emit_instr(cc, "add", "a,e");
                    }
                    vpush(VK_A, NULL, 0, 'C');
                } else {
                    if (b->kind == VK_IMM && b->value == 1) {
                        /* +1: inc hl */
                        gen_load_hl(cc, a);
                        emit_instr(cc, "inc", "hl");
                    } else if (a->kind == VK_IMM && a->value == 1) {
                        /* 1+b: inc hl */
                        gen_load_hl(cc, b);
                        emit_instr(cc, "inc", "hl");
                    } else if (b->kind == VK_IMM && a->kind == VK_DE) {
                        /* a in DE, b constant → load b to HL, add (commutative) */
                        gen_load_hl(cc, b);
                        emit_instr(cc, "add", "hl,de");
                    } else if (a->kind == VK_IMM && b->kind == VK_DE) {
                        gen_load_hl(cc, a);
                        emit_instr(cc, "add", "hl,de");
                    } else if (b->kind == VK_IMM) {
                        gen_load_hl(cc, a);
                        gen_load_de(cc, b);
                        emit_instr(cc, "add", "hl,de");
                    } else if (a->kind == VK_IMM) {
                        gen_load_hl(cc, b);
                        gen_load_de(cc, a);
                        emit_instr(cc, "add", "hl,de");
                    } else if (a->kind == VK_DE) {
                        /* a in DE, b needs loading → load b to HL */
                        gen_load_hl(cc, b);
                        emit_instr(cc, "add", "hl,de");
                    } else if (b->kind == VK_DE) {
                        gen_load_hl(cc, a);
                        emit_instr(cc, "add", "hl,de");
                    } else if (a->kind == VK_BC) {
                        /* a in BC → load b to HL, add hl,bc */
                        gen_load_hl(cc, b);
                        emit_instr(cc, "add", "hl,bc");
                    } else if (b->kind == VK_BC) {
                        gen_load_hl(cc, a);
                        emit_instr(cc, "add", "hl,bc");
                    } else if (b->kind == VK_HL) {
                        /* b already in HL — load a into DE (commutative) */
                        gen_load_de(cc, a);
                        emit_instr(cc, "add", "hl,de");
                    } else {
                        gen_load_de(cc, b);
                        gen_load_hl(cc, a);
                        emit_instr(cc, "add", "hl,de");
                    }
                    vpush(VK_HL, NULL, 0, type);
                }
            }
            break;
        }
        case '-': {
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                /* Constant folding */
                if (a->kind == VK_IMM && b->kind == VK_IMM) {
                    vpush(VK_IMM, NULL, (a->value - b->value) & 0xFFFF, type);
                    break;
                }
                if (type == 'C') {
                    gen_load_a(cc, b);
                    emit_instr(cc, "ld", "e,a");
                    gen_load_a(cc, a);
                    emit_instr(cc, "sub", "e");
                    vpush(VK_A, NULL, 0, 'C');
                } else if (b->kind == VK_IMM && b->value == 1) {
                    /* -1: dec hl */
                    gen_load_hl(cc, a);
                    emit_instr(cc, "dec", "hl");
                    vpush(VK_HL, NULL, 0, type);
                } else if (b->kind == VK_IMM) {
                    /* Subtract constant: add two's complement
                     * ld de,<-val> / add hl,de avoids or a / sbc */
                    gen_load_hl(cc, a);
                    int neg = (-b->value) & 0xFFFF;
                    char buf[32];
                    snprintf(buf, sizeof(buf), "de,%d", neg);
                    emit_instr(cc, "ld", buf);
                    emit_instr(cc, "add", "hl,de");
                    vpush(VK_HL, NULL, 0, type);
                } else {
                    /* a - b: DE=a, HL=b, then ld a,e/sub l/ld l,a/ld a,d/sbc a,h/ld h,a */
                    gen_load_de(cc, a);
                    gen_load_hl(cc, b);
                    emit_instr(cc, "ld", "a,e");
                    emit_instr(cc, "sub", "l");
                    emit_instr(cc, "ld", "l,a");
                    emit_instr(cc, "ld", "a,d");
                    emit_instr(cc, "sbc", "a,h");
                    emit_instr(cc, "ld", "h,a");
                    vpush(VK_HL, NULL, 0, type);
                }
            }
            break;
        }
        case '*': {
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                /* Constant folding (not for *R with base tracking) */
                if (a->kind == VK_IMM && b->kind == VK_IMM && !(type == 'R' && rbase_active)) {
                    vpush(VK_IMM, NULL, (a->value * b->value) & 0xFFFF, type);
                    break;
                }
                if (type == 'R' && rbase_active) {
                    /* Array subscript: index * element_size + base
                     * a = index, b = element size, rbase_* = saved base */
                    int need_add_base = 1;
                    int sp_push_adj = 0;

                    /* Save any existing VK_ADDR_HL on vstack to hardware stack
                     * (happens when LHS array addr is computed before RHS) */
                    {
                        int k;
                        for (k = 0; k < vsp; k++) {
                            if (vstack[k].kind == VK_ADDR_HL) {
                                emit_instr(cc, "push", "hl");
                                vstack[k].kind = VK_STACK;
                                sp_push_adj = 1;
                                break;
                            }
                        }
                    }

                    if (a->kind == VK_IMM && b->kind == VK_IMM) {
                        /* Constant folding: both index and element size are constants.
                         * Compute index * size at compile time. */
                        int offset = a->value * b->value;
                        if (rbase_kind == VK_LOCAL) {
                            /* Local array: sp_offset + index*size */
                            int sp_off = sp_relative_offset(rbase_value, sp_push_adj);
                            int combined = sp_off + offset;
                            char buf[32];
                            snprintf(buf, sizeof(buf), "hl,%d", combined);
                            emit_instr(cc, "ld", buf);
                            emit_instr(cc, "add", "hl,sp");
                        } else if (rbase_kind == VK_DE) {
                            /* Register base: ld hl,<offset> / add hl,de */
                            char buf[32];
                            snprintf(buf, sizeof(buf), "hl,%d", offset);
                            emit_instr(cc, "ld", buf);
                            emit_instr(cc, "add", "hl,de");
                        } else if (rbase_kind == VK_HL) {
                            char buf[32];
                            snprintf(buf, sizeof(buf), "de,%d", offset);
                            emit_instr(cc, "ld", buf);
                            emit_instr(cc, "add", "hl,de");
                        } else if (rbase_kind == VK_GLOBAL) {
                            char buf[128];
                            snprintf(buf, sizeof(buf), "hl,%s+%d", rbase_sym, offset);
                            emit_instr(cc, "ld", buf);
                        } else {
                            /* Generic: load offset, add base */
                            char buf[32];
                            snprintf(buf, sizeof(buf), "hl,%d", offset);
                            emit_instr(cc, "ld", buf);
                        }
                        rbase_active = 0;
                        vpush(VK_ADDR_HL, NULL, 0, b->value == 1 ? 'C' : 'N');
                        (void)need_add_base;
                        break;
                    } else if (b->kind == VK_IMM && b->value == 1 &&
                        rbase_kind == VK_LOCAL && a->kind == VK_DE) {
                        /* Optimized: element size 1, index in DE, base is local.
                         * Compute base addr into HL, then add hl,de.
                         * Matches CCC.ASM pattern: ld hl,N / add hl,sp / add hl,de */
                        int sp_off = sp_relative_offset(rbase_value, sp_push_adj);
                        {
                            char buf[32];
                            snprintf(buf, sizeof(buf), "hl,%d", sp_off);
                            emit_instr(cc, "ld", buf);
                        }
                        emit_instr(cc, "add", "hl,sp");
                        emit_instr(cc, "add", "hl,de");
                        rbase_active = 0;
                        vpush(VK_ADDR_HL, NULL, 0, (b->kind == VK_IMM && b->value == 1) ? 'C' : 'N');
                        (void)need_add_base;
                        break; /* skip the generic base-add code below */
                    } else if (b->kind == VK_IMM && b->value == 1) {
                        /* Element size 1: just use index as-is */
                        /* Special case: index in DE or BC + global base → ld hl,sym; add hl,reg */
                        if ((a->kind == VK_DE || a->kind == VK_BC) && rbase_kind == VK_GLOBAL) {
                            char buf[128];
                            const char *addreg = (a->kind == VK_DE) ? "de" : "bc";
                            snprintf(buf, sizeof(buf), "hl,%s", rbase_sym);
                            emit_instr(cc, "ld", buf);
                            snprintf(buf, sizeof(buf), "hl,%s", addreg);
                            emit_instr(cc, "add", buf);
                            rbase_active = 0;
                            vpush(VK_ADDR_HL, NULL, 0, 'R');
                            (void)need_add_base;
                            break;
                        }
                        gen_load_hl(cc, a);
                    } else if (b->kind == VK_IMM && b->value == 2) {
                        /* Element size 2: add hl,hl (shift left 1) */
                        gen_load_hl(cc, a);
                        emit_instr(cc, "add", "hl,hl");
                    } else {
                        /* Multiply index by element size */
                        gen_load_hl(cc, a);
                        gen_load_de(cc, b);
                        decl_add("?mulhd", 0);
                        emit_instr(cc, "call", "?mulhd");
                    }

                    /* Now add the base address */
                    if (rbase_kind == VK_LOCAL) {
                        /* Local array: compute SP-relative address */
                        int sp_off = sp_relative_offset(rbase_value, sp_push_adj);
                        emit_instr(cc, "push", "hl");
                        {
                            char buf[32];
                            snprintf(buf, sizeof(buf), "hl,%d", sp_off + 2); /* +2 for our push */
                            emit_instr(cc, "ld", buf);
                        }
                        emit_instr(cc, "add", "hl,sp");
                        emit_instr(cc, "pop", "de");
                        emit_instr(cc, "add", "hl,de");
                        need_add_base = 0;
                    } else if (rbase_kind == VK_DE) {
                        emit_instr(cc, "add", "hl,de");
                        need_add_base = 0;
                    } else if (rbase_kind == VK_HL) {
                        /* HL conflict: save index, load base, add */
                        emit_instr(cc, "ex", "de,hl");
                        /* base was in HL but we overwrote it... need different strategy */
                        /* For now, just add DE (the index) */
                        emit_instr(cc, "add", "hl,de");
                        need_add_base = 0;
                    } else if (rbase_kind == VK_GLOBAL) {
                        /* Reference uses ld bc,sym / add hl,bc to preserve DE loop counter */
                        char buf[128];
                        snprintf(buf, sizeof(buf), "bc,%s", rbase_sym);
                        emit_instr(cc, "ld", buf);
                        emit_instr(cc, "add", "hl,bc");
                        need_add_base = 0;
                    } else if (rbase_kind == VK_BC) {
                        emit_instr(cc, "add", "hl,bc");
                        need_add_base = 0;
                    }

                    rbase_active = 0;
                    vpush(VK_ADDR_HL, NULL, 0, 'R');
                    (void)need_add_base;
                } else if (type == 'R') {
                    /* Fallback: plain *R without base tracking */
                    if (b->kind == VK_IMM && b->value == 1) {
                        vstack[vsp++] = *a;
                    } else {
                        gen_load_hl(cc, a);
                        emit_instr(cc, "push", "hl");
                        gen_load_hl(cc, b);
                        emit_instr(cc, "pop", "de");
                        emit_instr(cc, "ex", "de,hl");
                        decl_add("?mulhd", 0);
                        emit_instr(cc, "call", "?mulhd");
                        vpush(VK_HL, NULL, 0, 'R');
                    }
                } else if (type == 'C') {
                    /* Char multiply */
                    gen_load_a(cc, a);
                    if (b->kind == VK_IMM) {
                        int mul = b->value;
                        /* Strength reduction for small constants */
                        if (mul == 2) {
                            emit_instr(cc, "add", "a,a");
                        } else if (mul == 3) {
                            emit_instr(cc, "ld", "b,a");
                            emit_instr(cc, "add", "a,a");
                            emit_instr(cc, "add", "a,b");
                        } else if (mul == 5) {
                            emit_instr(cc, "ld", "b,a");
                            emit_instr(cc, "add", "a,a");
                            emit_instr(cc, "add", "a,a");
                            emit_instr(cc, "add", "a,b");
                        } else {
                            emit_instr(cc, "ld", "e,a");
                            gen_load_a(cc, b);
                            emit_instr(cc, "ld", "b,a");
                            emit_instr(cc, "ld", "a,e");
                            /* TODO: proper 8-bit multiply */
                        }
                    }
                    vpush(VK_A, NULL, 0, 'C');
                } else {
                    /* 16-bit multiply: strength reduction for small constants */
                    int mul_val = 0;
                    VVal *var_op = NULL;
                    if (b->kind == VK_IMM) { mul_val = b->value; var_op = a; }
                    else if (a->kind == VK_IMM) { mul_val = a->value; var_op = b; }

                    if (mul_val == 256 && var_op) {
                        /* *256 = shift left 8 */
                        if (var_op->kind == VK_A) {
                            /* Byte in A: ld h,a / ld l,0 */
                            emit_instr(cc, "ld", "h,a");
                            emit_instr(cc, "ld", "l,0");
                        } else {
                            gen_load_hl(cc, var_op);
                            emit_instr(cc, "ld", "h,l");
                            emit_instr(cc, "ld", "l,0");
                        }
                        vpush(VK_HL, NULL, 0, type);
                        break;
                    } else if (mul_val == 257 && var_op) {
                        /* *257 = val*256 + val: ld c,l / ld b,h / ld h,l / ld l,0 / add hl,bc */
                        gen_load_hl(cc, var_op);
                        emit_instr(cc, "ld", "c,l");
                        emit_instr(cc, "ld", "b,h");
                        emit_instr(cc, "ld", "h,l");
                        emit_instr(cc, "ld", "l,0");
                        emit_instr(cc, "add", "hl,bc");
                        vpush(VK_HL, NULL, 0, type);
                        break;
                    } else if (mul_val == 2 && var_op) {
                        /* *2 = add hl,hl */
                        gen_load_hl(cc, var_op);
                        emit_instr(cc, "add", "hl,hl");
                        vpush(VK_HL, NULL, 0, type);
                        break;
                    } else if (mul_val == 4 && var_op) {
                        /* *4 = add hl,hl / add hl,hl */
                        gen_load_hl(cc, var_op);
                        emit_instr(cc, "add", "hl,hl");
                        emit_instr(cc, "add", "hl,hl");
                        vpush(VK_HL, NULL, 0, type);
                        break;
                    } else if (mul_val == 8 && var_op) {
                        /* *8 = add hl,hl x3 */
                        gen_load_hl(cc, var_op);
                        emit_instr(cc, "add", "hl,hl");
                        emit_instr(cc, "add", "hl,hl");
                        emit_instr(cc, "add", "hl,hl");
                        vpush(VK_HL, NULL, 0, type);
                        break;
                    } else if (mul_val == 16 && var_op) {
                        /* *16 = add hl,hl x4 */
                        gen_load_hl(cc, var_op);
                        emit_instr(cc, "add", "hl,hl");
                        emit_instr(cc, "add", "hl,hl");
                        emit_instr(cc, "add", "hl,hl");
                        emit_instr(cc, "add", "hl,hl");
                        vpush(VK_HL, NULL, 0, type);
                        break;
                    } else if (mul_val == 10 && var_op) {
                        /* *10 = (*8 + *2): HL*2 → DE, HL*8 via 2 more shifts, add DE */
                        gen_load_hl(cc, var_op);
                        emit_instr(cc, "add", "hl,hl"); /* *2 */
                        emit_instr(cc, "ld", "d,h");
                        emit_instr(cc, "ld", "e,l");    /* DE = HL*2 */
                        emit_instr(cc, "add", "hl,hl"); /* *4 */
                        emit_instr(cc, "add", "hl,hl"); /* *8 */
                        emit_instr(cc, "add", "hl,de"); /* *8 + *2 = *10 */
                        vpush(VK_HL, NULL, 0, type);
                        break;
                    } else if (mul_val == 3 && var_op) {
                        /* *3 = HL*2 + HL, uses BC (not DE) to avoid clobbering loop counter */
                        gen_load_hl(cc, var_op);
                        emit_instr(cc, "ld", "c,l");
                        emit_instr(cc, "ld", "b,h");
                        emit_instr(cc, "add", "hl,hl");
                        emit_instr(cc, "add", "hl,bc");
                        vpush(VK_HL, NULL, 0, type);
                        break;
                    } else if (mul_val == 7 && var_op) {
                        /* *7 = *4 + *2 + *1, ported from ref BENCH rc4:
                         *   ld c,l; ld b,h     ; BC = x
                         *   add hl,hl          ; HL = x*2
                         *   ld e,l; ld d,h     ; DE = x*2
                         *   add hl,hl          ; HL = x*4
                         *   add hl,bc          ; HL = x*5
                         *   add hl,de          ; HL = x*7 */
                        gen_load_hl(cc, var_op);
                        emit_instr(cc, "ld", "c,l");
                        emit_instr(cc, "ld", "b,h");
                        emit_instr(cc, "add", "hl,hl");
                        emit_instr(cc, "ld", "e,l");
                        emit_instr(cc, "ld", "d,h");
                        emit_instr(cc, "add", "hl,hl");
                        emit_instr(cc, "add", "hl,bc");
                        emit_instr(cc, "add", "hl,de");
                        vpush(VK_HL, NULL, 0, type);
                        break;
                    }

                    /* General case: HL * DE → call ?mulhd (commutative) */
                    if (b->kind == VK_IMM && a->kind == VK_DE) {
                        /* a in DE, b constant → load b to HL, keep DE */
                        gen_load_hl(cc, b);
                    } else if (a->kind == VK_IMM && b->kind == VK_DE) {
                        gen_load_hl(cc, a);
                    } else if (b->kind == VK_IMM) {
                        gen_load_hl(cc, a);
                        gen_load_de(cc, b);
                    } else if (a->kind == VK_IMM) {
                        gen_load_hl(cc, b);
                        gen_load_de(cc, a);
                    } else if (b->kind == VK_HL) {
                        gen_load_de(cc, a);
                    } else if (a->kind == VK_HL) {
                        gen_load_de(cc, b);
                    } else if (a->kind == VK_DE) {
                        gen_load_hl(cc, b);
                    } else if (b->kind == VK_DE) {
                        gen_load_hl(cc, a);
                    } else {
                        gen_load_de(cc, b);
                        gen_load_hl(cc, a);
                    }
                    decl_add("?mulhd", 0);
                    emit_instr(cc, "call", "?mulhd");
                    vpush(VK_HL, NULL, 0, type);
                }
            }
            break;
        }
        case '/': {
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                /* Constant folding: both operands known at compile time */
                if (a->kind == VK_IMM && b->kind == VK_IMM && b->value != 0) {
                    int result;
                    if (type == 'I') result = (int16_t)a->value / (int16_t)b->value;
                    else result = (u16)a->value / (u16)b->value;
                    vpush(VK_IMM, NULL, result, type);
                    break;
                }
                /* Load divisor first, then save HL param if needed */
                gen_load_de(cc, b);
                if (a->kind == VK_HL && !func_has_locals) {
                    emit_instr(cc, "push", "hl");
                    hl_spilled = 2; /* already saved on stack */
                }
                gen_load_hl(cc, a);
                if (type == 'I') {
                    decl_add("?dvihd", 0);
                    emit_instr(cc, "call", "?dvihd");
                } else {
                    decl_add("?dvnhd", 0);
                    emit_instr(cc, "call", "?dvnhd");
                }
                vpush(VK_HL, NULL, 0, type);
            }
            break;
        }
        case '%': {
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                /* Constant folding */
                if (a->kind == VK_IMM && b->kind == VK_IMM && b->value != 0) {
                    int result;
                    if (type == 'I') result = (int16_t)a->value % (int16_t)b->value;
                    else result = (u16)a->value % (u16)b->value;
                    vpush(VK_IMM, NULL, result, type);
                    break;
                }
                gen_load_de(cc, b);
                gen_load_hl(cc, a);
                if (type == 'I') {
                    decl_add("?dvihd", 0);
                    emit_instr(cc, "call", "?dvihd");
                } else {
                    decl_add("?dvnhd", 0);
                    emit_instr(cc, "call", "?dvnhd");
                }
                /* Remainder is in DE after division — keep it there */
                vpush(VK_DE, NULL, 0, type);
            }
            break;
        }
        case '|': {
            /* Bitwise OR: |C, |N, |I */
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                if (a->kind == VK_IMM && b->kind == VK_IMM) {
                    vpush(VK_IMM, NULL, (a->value | b->value) & 0xFFFF, type);
                    break;
                }
                if (b->kind == VK_HL) gen_load_de(cc, a);
                else if (a->kind == VK_HL) gen_load_de(cc, b);
                else if (a->kind == VK_DE) gen_load_hl(cc, b);
                else if (b->kind == VK_DE) gen_load_hl(cc, a);
                else { gen_load_de(cc, b); gen_load_hl(cc, a); }
                emit_instr(cc, "ld", "a,l");
                emit_instr(cc, "or", "e");
                emit_instr(cc, "ld", "l,a");
                emit_instr(cc, "ld", "a,h");
                emit_instr(cc, "or", "d");
                emit_instr(cc, "ld", "h,a");
                vpush(VK_HL, NULL, 0, type);
            }
            break;
        }
        case '?': {
            /* Ternary: condition true_val false_val ?<type> */
            char type = tok[1];
            VVal *false_val = vpop();
            VVal *true_val = vpop();
            VVal *cond = vpop();
            if (cond && true_val && false_val) {
                if (cond->kind == VK_IMM) {
                    if (cond->value)
                        vstack[vsp++] = *true_val;
                    else
                        vstack[vsp++] = *false_val;
                    break;
                }
                /* Runtime branch: flags set by previous comparison */
                int lbl_f = cc->local_label++;
                int lbl_e = cc->local_label++;
                {
                    char buf[32];
                    snprintf(buf, sizeof(buf), "z,@%d", lbl_f);
                    emit_instr(cc, "jp", buf);
                }
                gen_load_hl(cc, true_val);
                {
                    char buf[32];
                    snprintf(buf, sizeof(buf), "@%d", lbl_e);
                    emit_instr(cc, "jp", buf);
                    snprintf(buf, sizeof(buf), "@%d", lbl_f);
                    emit_label_instr(buf);
                }
                gen_load_hl(cc, false_val);
                {
                    char buf[32];
                    snprintf(buf, sizeof(buf), "@%d", lbl_e);
                    emit_label_instr(buf);
                }
                vpush(VK_HL, NULL, 0, type);
            }
            break;
        }
        case '<': case '>': case '=': case '!':
        case '[': case ']': {
            /* Comparison operators — push result for conditional jump */
            /* These are usually consumed by the j (jump) handler */
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                if (type == 'C' && b->kind == VK_IMM) {
                    /* Compare char with immediate: cp N or or a for 0 */
                    gen_load_a(cc, a);
                    if ((b->value & 0xFF) == 0 && (first == '!' || first == '=')) {
                        emit_instr(cc, "or", "a");
                    } else {
                        char buf[32];
                        snprintf(buf, sizeof(buf), "%d", b->value & 0xFF);
                        emit_instr(cc, "cp", buf);
                    }
                } else if (type == 'C') {
                    gen_load_a(cc, b);
                    emit_instr(cc, "ld", "e,a");
                    gen_load_a(cc, a);
                    emit_instr(cc, "cp", "e");
                } else {
                    gen_load_de(cc, b);
                    gen_load_hl(cc, a);
                    decl_add("?cpshd", 0);
                    emit_instr(cc, "call", "?cpshd");
                }
                /* Push a comparison result marker */
                VVal cmp;
                memset(&cmp, 0, sizeof(cmp));
                cmp.kind = VK_HL;
                cmp.type = type;
                cmp.value = first; /* store comparison operator */
                vstack[vsp++] = cmp;
            }
            break;
        }
        case '^': {
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                /* XOR is commutative — avoid register swaps */
                if (b->kind == VK_HL) {
                    gen_load_de(cc, a);
                } else if (a->kind == VK_HL) {
                    gen_load_de(cc, b);
                } else if (a->kind == VK_DE) {
                    gen_load_hl(cc, b);
                } else if (b->kind == VK_DE) {
                    gen_load_hl(cc, a);
                } else {
                    gen_load_de(cc, b);
                    gen_load_hl(cc, a);
                }
                emit_instr(cc, "ld", "a,l");
                emit_instr(cc, "xor", "e");
                emit_instr(cc, "ld", "l,a");
                emit_instr(cc, "ld", "a,h");
                emit_instr(cc, "xor", "d");
                emit_instr(cc, "ld", "h,a");
                vpush(VK_HL, NULL, 0, type);
            }
            break;
        }
        case '&': {
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                /* AND is commutative — avoid register swaps */
                if (b->kind == VK_HL) {
                    gen_load_de(cc, a);
                } else if (a->kind == VK_HL) {
                    gen_load_de(cc, b);
                } else if (a->kind == VK_DE) {
                    gen_load_hl(cc, b);
                } else if (b->kind == VK_DE) {
                    gen_load_hl(cc, a);
                } else {
                    gen_load_de(cc, b);
                    gen_load_hl(cc, a);
                }
                emit_instr(cc, "ld", "a,l");
                emit_instr(cc, "and", "e");
                emit_instr(cc, "ld", "l,a");
                emit_instr(cc, "ld", "a,h");
                emit_instr(cc, "and", "d");
                emit_instr(cc, "ld", "h,a");
                vpush(VK_HL, NULL, 0, type);
            }
            break;
        }
        case 'r': {
            /* Right shift: rN, rC */
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                if (type == 'C') {
                    gen_load_a(cc, b);
                    emit_instr(cc, "ld", "b,a");
                    gen_load_a(cc, a);
                    emit_instr(cc, "rrca", "");
                    emit_instr(cc, "and", "127");
                    vpush(VK_A, NULL, 0, 'C');
                } else {
                    gen_load_hl(cc, a);
                    gen_load_a(cc, b);
                    emit_instr(cc, "ld", "b,a");
                    decl_add("?srnhb", 0);
                    emit_instr(cc, "call", "?srnhb");
                    vpush(VK_HL, NULL, 0, type);
                }
            }
            break;
        }
        case 'l': {
            /* Left shift: lN, lC, lI */
            char type = tok[1];
            VVal *b = vpop();  /* shift count */
            VVal *a = vpop();  /* value to shift */
            if (a && b) {
                /* Constant folding */
                if (a->kind == VK_IMM && b->kind == VK_IMM) {
                    vpush(VK_IMM, NULL, (a->value << b->value) & 0xFFFF, type);
                    break;
                }
                if (type == 'C') {
                    /* 8-bit left shift */
                    gen_load_a(cc, a);
                    if (b->kind == VK_IMM) {
                        int n;
                        for (n = 0; n < b->value && n < 8; n++)
                            emit_instr(cc, "add", "a,a");
                    } else {
                        gen_load_a(cc, b);
                        emit_instr(cc, "ld", "b,a");
                        gen_load_a(cc, a);
                        decl_add("?slnab", 0);
                        emit_instr(cc, "call", "?slnab");
                    }
                    vpush(VK_A, NULL, 0, 'C');
                } else {
                    /* 16-bit left shift */
                    gen_load_hl(cc, a);
                    if (b->kind == VK_IMM && b->value <= 7) {
                        int n;
                        for (n = 0; n < b->value; n++)
                            emit_instr(cc, "add", "hl,hl");
                    } else if (b->kind == VK_IMM && b->value == 8) {
                        emit_instr(cc, "ld", "h,l");
                        emit_instr(cc, "ld", "l,0");
                    } else {
                        gen_load_a(cc, b);
                        emit_instr(cc, "ld", "b,a");
                        decl_add("?slnhb", 0);
                        emit_instr(cc, "call", "?slnhb");
                    }
                    vpush(VK_HL, NULL, 0, type);
                }
            }
            break;
        }
        case 'R': {
            /* Array subscript: pops index and base, saves base for *R to add later.
             * The pattern is: base index R<type> #<size> *R ['] */
            VVal *idx = vpop();
            VVal *base = vpop();
            if (base && idx) {
                /* Save base info for the upcoming *R handler */
                rbase_active = 1;
                rbase_kind = base->kind;
                rbase_value = base->value;
                rbase_is_addr = base->is_addr;
                if (base->sym[0])
                    strncpy(rbase_sym, base->sym, sizeof(rbase_sym) - 1);
                else
                    rbase_sym[0] = '\0';
                /* Push index value (will be multiplied by *R) */
                vstack[vsp++] = *idx;
            }
            break;
        }
        case 'N': case 'C': case 'I': {
            /* Type conversion: NI, NC, CI, CN, IN, etc. */
            char from = tok[0];
            char to = tok[1];
            VVal *top = vtop();
            if (top) {
                /* For immediates, just update type - no code needed */
                if (top->kind == VK_IMM) {
                    top->type = to;
                    break;
                }
                if (from == 'N' && to == 'C') {
                    if (top->kind == VK_ADDR_HL && top->type == 'C') {
                        /* Char-width address: just load byte */
                        vsp--;
                        emit_instr(cc, "ld", "a,(hl)");
                        vpush(VK_A, NULL, 0, 'C');
                    } else if (top->kind == VK_ADDR_HL) {
                        /* Non-char address: load 16-bit, extract byte */
                        gen_load_hl(cc, top); vsp--;
                        emit_instr(cc, "ld", "a,l");
                        vpush(VK_A, NULL, 0, 'C');
                    } else if (top->kind == VK_LOCAL && top->type == 'C') {
                        /* Char-typed struct member access at ix+offset:
                         * read just the byte, not a word */
                        char buf[32];
                        int ioff = top->value;
                        vsp--;
                        snprintf(buf, sizeof(buf), "a,(ix%+d)", ioff);
                        emit_instr(cc, "ld", buf);
                        vpush(VK_A, NULL, 0, 'C');
                    } else if (top->kind != VK_A) {
                        gen_load_hl(cc, top); vsp--;
                        emit_instr(cc, "ld", "a,l");
                        vpush(VK_A, NULL, 0, 'C');
                    } else { top->type = 'C'; }
                } else if ((from == 'C' && to == 'N') ||
                           (from == 'C' && to == 'I')) {
                    if (top->kind == VK_ADDR_HL && top->type == 'C') {
                        /* Char-width address: ld l,(hl) / ld h,0 */
                        vsp--;
                        emit_instr(cc, "ld", "l,(hl)");
                        emit_instr(cc, "ld", "h,0");
                        vpush(VK_HL, NULL, 0, to);
                    } else if (top->kind == VK_A) {
                        /* Check if VK_ADDR_HL is below us on vstack —
                         * if so, don't widen (it would clobber the address).
                         * The :C handler will use A directly. */
                        int addr_below = 0;
                        if (vsp >= 2 && vstack[vsp-2].kind == VK_ADDR_HL)
                            addr_below = 1;
                        if (addr_below) {
                            /* Keep as VK_A, just update type */
                            top->type = to;
                        } else {
                            vsp--;
                            emit_instr(cc, "ld", "l,a");
                            emit_instr(cc, "ld", "h,0");
                            vpush(VK_HL, NULL, 0, to);
                        }
                    } else if (top->kind != VK_HL) {
                        /* If VK_ADDR_HL is below, don't widen — keep as VK_A */
                        if (vsp >= 2 && vstack[vsp-2].kind == VK_ADDR_HL) {
                            gen_load_a(cc, top); vsp--;
                            vpush(VK_A, NULL, 0, to);
                        } else {
                            gen_load_a(cc, top); vsp--;
                            emit_instr(cc, "ld", "l,a");
                            emit_instr(cc, "ld", "h,0");
                            vpush(VK_HL, NULL, 0, to);
                        }
                    } else { top->type = to; }
                } else if ((from == 'N' && to == 'I') ||
                           (from == 'I' && to == 'N')) {
                    top->type = to;
                }
            }
            break;
        }
        case ';': {
            /* Increment/decrement: ;+N, ;-N, ;+I, ;+C, etc. */
            char op = tok[1]; /* + or - */
            char type = tok[2];
            VVal *delta = vpop();
            VVal *var = vpop();
            if (var && delta) {
                if (type == 'C') {
                    gen_load_a(cc, var);
                    if (op == '+') {
                        if (delta->kind == VK_IMM && delta->value == 1)
                            emit_instr(cc, "inc", "a");
                        else {
                            emit_instr(cc, "ld", "e,a");
                            gen_load_a(cc, delta);
                            emit_instr(cc, "add", "a,e");
                        }
                    } else {
                        if (delta->kind == VK_IMM && delta->value == 1)
                            emit_instr(cc, "dec", "a");
                        else {
                            emit_instr(cc, "ld", "e,a");
                            gen_load_a(cc, delta);
                            emit_instr(cc, "ld", "b,a");
                            emit_instr(cc, "ld", "a,e");
                            emit_instr(cc, "sub", "b");
                        }
                    }
                    gen_store_a(cc, var);
                } else {
                    /* Optimized: inc/dec for register-allocated vars.
                     * After dec/inc, the result (post-op value) must be
                     * pushed onto vstack for use by following comparison. */
                    if (var->kind == VK_DE && delta->kind == VK_IMM && delta->value == 1) {
                        emit_instr(cc, op == '+' ? "inc" : "dec", "de");
                        vpush(VK_DE, NULL, 0, type);
                        break;
                    }
                    if (var->kind == VK_BC && delta->kind == VK_IMM && delta->value == 1) {
                        emit_instr(cc, op == '+' ? "inc" : "dec", "bc");
                        vpush(VK_BC, NULL, 0, type);
                        break;
                    }
                    gen_load_hl(cc, var);
                    if (op == '+') {
                        if (delta->kind == VK_IMM && delta->value == 1)
                            emit_instr(cc, "inc", "hl");
                        else {
                            emit_instr(cc, "push", "hl");
                            gen_load_hl(cc, delta);
                            emit_instr(cc, "pop", "de");
                            emit_instr(cc, "ex", "de,hl");
                            emit_instr(cc, "add", "hl,de");
                        }
                    } else {
                        emit_instr(cc, "push", "hl");
                        gen_load_hl(cc, delta);
                        emit_instr(cc, "pop", "de");
                        emit_instr(cc, "ex", "de,hl");
                        emit_instr(cc, "or", "a");
                        emit_instr(cc, "sbc", "hl,de");
                    }
                    gen_store_hl(cc, var);
                    vpush(VK_HL, NULL, 0, type);
                }
            }
            break;
        }
        case 'X': {
            /* Function call within expression */
            if (func_is_simple) {
                /* Simple function: use symbolic evaluator.
                 *
                 * Before the call, spill any live VK_ADDR_HL on vstack to
                 * the hardware stack — the call will clobber HL. Convert
                 * to VK_STACK so the later :I/:N/:C assignment recovers
                 * the address via pop hl. This matches the ASM compiler's
                 * approach to preserve destination addresses across calls. */
                int k;
                for (k = 0; k < vsp; k++) {
                    if (vstack[k].kind == VK_ADDR_HL) {
                        emit_instr(cc, "push", "hl");
                        vstack[k].kind = VK_STACK;
                        break; /* only one HL value is live at a time */
                    }
                }
                char fname[128];
                strncpy(fname, tok + 1, sizeof(fname) - 1);
                fname[sizeof(fname) - 1] = '\0';
                parse_func_call(cc, fname);
                vpush(VK_HL, NULL, 0, 'N');
            } else {
                /* Complex function: handle inline using vstack */
                strncpy(icall_name, tok + 1, sizeof(icall_name) - 1);
                icall_name[sizeof(icall_name) - 1] = '\0';
                icall_active = 1;
                icall_nargs = 0;
                icall_ret_type = 'I';
                /* Don't push result yet — F/U handler will do it */
            }
            break;
        }
        case '"': {
            /* String constant */
            int sidx = parse_string_const(cc);
            VVal v;
            memset(&v, 0, sizeof(v));
            v.kind = VK_STRING;
            v.str_idx = sidx;
            snprintf(v.sym, sizeof(v.sym), "?%d", str_consts[sidx].label);
            v.type = 'R';
            v.is_addr = 1;
            vstack[vsp++] = v;
            break;
        }
        case 'a': {
            /* Address mode */
            VVal *top = vtop();
            if (top) top->is_addr = 1;
            break;
        }
        case 'p': {
            /* Push for function arg: pR, pI, pC, pN */
            if (icall_active) {
                VVal *val = vpop();
                if (val && icall_nargs < ICALL_MAX_ARGS) {
                    icall_args[icall_nargs] = *val;
                    icall_arg_types[icall_nargs] = tok[1];
                    icall_nargs++;
                }
            }
            break;
        }
        case 'c': {
            /* Return type for function call */
            if (icall_active) {
                icall_ret_type = tok[1];
            }
            break;
        }
        case 'F': case 'U': {
            /* Generate function call */
            if (icall_active) {
                int ac = atoi(tok + 1);
                char asmname[128];
                make_asm_name(icall_name, asmname, sizeof(asmname));
                decl_add(asmname, 0);
                gen_inline_call(cc, asmname, first, ac);
                /* Push result on vstack */
                if (icall_ret_type == 'C') {
                    vpush(VK_A, NULL, 0, 'C');
                } else {
                    vpush(VK_HL, NULL, 0, icall_ret_type);
                }
                icall_active = 0;
            }
            break;
        }
        default:
            /* Try unified handler for _, @, etc. */
            eval_one_token(cc, first, tok);
            break;
        }
    }
}

/* Generate conditional jump expression.
 * Format: j\tL<target>\t<expr tokens>\tn
 * The leading \tj has been consumed; we need to read L<n>, expression, and 'n'. */
static void gen_cond_jump(Cc2State *cc)
{
    int or_skip_label = -1; /* for logical OR short-circuit */

    /* Read target label */
    int ch = tmc_read_char(cc);
    if (ch == '\t') ch = tmc_read_char(cc);
    if (ch != 'L') {
        tmc_skip_line(cc);
        return;
    }
    int target = tmc_read_number(cc);
    int target_label = get_label(cc, target);

    /* Evaluate expression (reads tokens until 'n' at end) */
    vsp = 0;
    char tok[128];
    int negate = 0;
    int cmp_op = 0;
    char cmp_type = 'N';
    /* AND/OR-pattern tracking: when a second comparison is seen, save the split
     * position so m/s can insert the first condition's jump retroactively.
     * pending_split_pos is updated at the END of each comparison emission
     * (so it points to the gap between cond1 and cond2 when cond2 starts). */
    int and_split_pos = -1;
    int and_prev_cmp_op = 0;
    int pending_split_pos = -1;

    for (;;) {
        int first = expr_read_tok(cc, tok, sizeof(tok));
        if (first == 0) break;
        if (first == 'n') { negate = 1; continue; }

        /* Reuse expression evaluation logic */
        switch (first) {
        case 'A': case 'P': {
            int id = atoi(tok + 1);
            LocalVar *lv = find_local(id);
            if (lv) {
                if (lv->reg == VK_HL && hl_spilled == 2) {
                    emit_instr(cc, "pop", "hl");
                    hl_spilled = 0;
                    vpush(VK_HL, NULL, 0, lv->type);
                } else if (lv->reg == VK_DE && de_spilled == 2) {
                    emit_instr(cc, "pop", "de");
                    de_spilled = 0;
                    vpush(VK_DE, NULL, 0, lv->type);
                } else if (lv->reg != VK_NONE)
                    vpush(lv->reg, NULL, 0, lv->type);
                else
                    vpush(VK_LOCAL, NULL, lv->ix_offset, lv->type);
            } else vpush(VK_IMM, NULL, 0, 'N');
            break;
        }
        case 'G': {
            char asmn[128];
            make_asm_name(tok + 1, asmn, sizeof(asmn));
            vpush(VK_GLOBAL, asmn, 0, 'N');
            int found = 0, j;
            for (j = 0; j < decl_count; j++) {
                if (strcmp(decl_list[j].name, asmn) == 0) { found = 1; break; }
            }
            if (!found) decl_add(asmn, 0);
            break;
        }
        case 'T': {
            /* Static local variable reference: T62 → ?62 */
            char asmn[128];
            snprintf(asmn, sizeof(asmn), "?%s", tok + 1);
            vpush(VK_GLOBAL, asmn, 0, 'N');
            break;
        }
        case '#': {
            int val;
            if (tok[1] == 'S') val = lookup_struct_size(cc, atoi(tok + 2));
            else if (tok[1] == 'V') {
                int vnum = atoi(tok + 2); val = 0;
                int vi; for (vi = 0; vi < cc->sym_count; vi++)
                    if (cc->sym[vi].type == SYM_VAR && cc->sym[vi].name == (u16)vnum)
                        { val = cc->sym[vi].value; break; }
                if (val == 0) val = 2;
            }
            else if (tok[1] == 'C') val = 1;
            else if (tok[1] == 'R' || tok[1] == 'N' || tok[1] == 'I') val = 2;
            else val = atoi(tok + 1);
            vpush(VK_IMM, NULL, val, 'N');
            break;
        }
        case '<': case '>': case '=': case '!':
        case '[': case ']': {
            /* Track AND/OR split point: if a previous comparison is pending,
             * snapshot its end position (from pending_split_pos, which was
             * recorded at the end of that comparison's emission) so m/s can
             * insert the first jump retroactively between cond1 and cond2. */
            if (cmp_op != 0 && pending_split_pos >= 0) {
                and_prev_cmp_op = cmp_op;
                and_split_pos = pending_split_pos;
            }
            cmp_op = first;
            cmp_type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                if (cmp_type == 'C' && b->kind == VK_IMM) {
                    /* Char comparison with immediate: cp N.
                     * [C (<=): use cp N+1 so carry=1 iff A<=N, set cmp_op='<' */
                    gen_load_a(cc, a);
                    if ((b->value & 0xFF) == 0 && (first == '!' || first == '=')) {
                        emit_instr(cc, "or", "a");
                    } else {
                        char buf[32];
                        int cval = b->value & 0xFF;
                        if (first == '[') { cval = (cval + 1) & 0xFF; cmp_op = '<'; }
                        snprintf(buf, sizeof(buf), "%d", cval);
                        emit_instr(cc, "cp", buf);
                    }
                } else if (cmp_type == 'C') {
                    gen_load_a(cc, b);
                    emit_instr(cc, "ld", "e,a");
                    gen_load_a(cc, a);
                    emit_instr(cc, "cp", "e");
                } else if (cmp_type == 'N' && b->kind == VK_IMM && b->value >= 0
                           && (first == '<' || first == '[')) {
                    /* Inline unsigned comparison for any 16-bit constant.
                     * Only for unsigned (N) type — signed (I) uses call ?cpshd.
                     * [N (<=c) treated as <N (c+1): adjust constant, set cmp_op to '<' */
                    int cval = b->value;
                    if (first == '[') { cval++; cmp_op = '<'; }
                    {
                        char buf[32];
                        int lo = cval & 0xFF;
                        int hi = (cval >> 8) & 0xFF;
                        gen_load_de(cc, a);
                        if (lo == 0) {
                            /* sub 0 just clears carry: skip it, use sub hi directly */
                            emit_instr(cc, "ld", "a,d");
                            snprintf(buf, sizeof(buf), "%d", hi);
                            emit_instr(cc, "sub", buf);
                        } else {
                            emit_instr(cc, "ld", "a,e");
                            snprintf(buf, sizeof(buf), "%d", lo);
                            emit_instr(cc, "sub", buf);
                            emit_instr(cc, "ld", "a,d");
                            snprintf(buf, sizeof(buf), "a,%d", hi);
                            emit_instr(cc, "sbc", buf);
                        }
                    }
                } else if (b->kind == VK_IMM && b->value == 0
                           && (first == '=' || first == '!')) {
                    /* Equality with 0: ld a,l / or h
                     * Z flag set means HL == 0 */
                    gen_load_hl(cc, a);
                    emit_instr(cc, "ld", "a,l");
                    emit_instr(cc, "or", "h");
                } else if (b->kind == VK_IMM && b->value == 1
                           && (first == '=' || first == '!')) {
                    /* Equality with 1: ld a,l / dec a / or h */
                    gen_load_hl(cc, a);
                    emit_instr(cc, "ld", "a,l");
                    emit_instr(cc, "dec", "a");
                    emit_instr(cc, "or", "h");
                } else if (b->kind == VK_IMM &&
                           (b->value == -1 || b->value == 65535) &&
                           (first == '=' || first == '!')) {
                    /* Equality with -1: ld a,l / and h / inc a */
                    gen_load_hl(cc, a);
                    emit_instr(cc, "ld", "a,l");
                    emit_instr(cc, "and", "h");
                    emit_instr(cc, "inc", "a");
                } else if ((first == '!' || first == '=') &&
                           (cmp_type == 'N' || cmp_type == 'I')) {
                    /* Inline 16-bit equality — port of L8F40 in CCC.ASM.
                     * Template: "Za,RNcp\tRNjr\tnz,$+4Za,RNcp\tR"
                     * operands = [a_lo, b_lo, a_hi, b_hi] as "bcdehlma" indices.
                     * When one operand is already in BC or DE register, we
                     * emit inline instead of calling ?cpshd. The other side
                     * is loaded into HL. This matches the reference pattern
                     * in HOBCRC/BENCH for register-register equality checks.
                     *
                     * "bcdehlma" indices: b=0 c=1 d=2 e=3 h=4 l=5 a=7 */
                    int a_kind = a->kind, b_kind = b->kind;
                    int use_inline = 0;
                    int a_lo = 0, a_hi = 0, b_lo = 0, b_hi = 0;
                    if (a_kind == VK_BC && b_kind != VK_BC) {
                        gen_load_hl(cc, b);
                        a_lo = 1; a_hi = 0; b_lo = 5; b_hi = 4;
                        use_inline = 1;
                    } else if (b_kind == VK_BC && a_kind != VK_BC) {
                        gen_load_hl(cc, a);
                        a_lo = 5; a_hi = 4; b_lo = 1; b_hi = 0;
                        use_inline = 1;
                    }
                    /* VK_DE case removed: reference uses ?cpshd for DE vs HL */
                    if (use_inline) {
                        int ops[4] = { a_lo, b_lo, a_hi, b_hi };
                        emit_template("Za,RNcp\tRNjr\tnz,$+4Za,RNcp\tR",
                                      ops, 4);
                    } else {
                        /* Both operands need HL/DE via memory: use ?cpshd */
                        gen_load_de(cc, b);
                        gen_load_hl(cc, a);
                        decl_add("?cpshd", 0);
                        emit_instr(cc, "call", "?cpshd");
                    }
                } else if (cmp_type == 'N' && (first == '<' || first == ']')) {
                    /* Inline 16-bit unsigned less-than — port of L8FB9:
                     *   ld a,<a_lo>   (= e)
                     *   sub <b_lo>    (= l)
                     *   ld a,<a_hi>   (= d)
                     *   sbc a,<b_hi>  (= h)
                     * Carry set iff a < b. Template:
                     *   "Za,RNsub\tRNZa,RNsbc\ta,R"
                     * Operands = [a_lo=e(3), b_lo=l(5), a_hi=d(2), b_hi=h(4)] */
                    gen_load_de(cc, a);
                    gen_load_hl(cc, b);
                    int ops[4] = { 3, 5, 2, 4 };
                    emit_template("Za,RNsub\tRNZa,RNsbc\ta,R", ops, 4);
                } else {
                    /* Signed or complex comparison: use ?cpshd library call.
                     * Reference pattern for globals: ld hl,(b); ex de,hl; ld hl,(a); call
                     * For simple global-global case, load b (→DE) first then a (→HL) */
                    if (a->kind == VK_GLOBAL && b->kind == VK_GLOBAL &&
                        !a->is_addr && !b->is_addr) {
                        gen_load_de(cc, b);
                        gen_load_hl(cc, a);
                    } else {
                        gen_load_hl(cc, a);
                        gen_load_de(cc, b);
                    }
                    decl_add("?cpshd", 0);
                    emit_instr(cc, "call", "?cpshd");
                }
            }
            /* Record end of this comparison's emission for retroactive
             * insertion of cond1's jump if an s/m follows after cond2. */
            pending_split_pos = instr_count;
            break;
        }
        /* Handle type conversions and other ops in jump expressions */
        case 'N': case 'C': case 'I': {
            char from = tok[0], to = tok[1];
            VVal *top = vtop();
            if (top) {
                /* Constants: just update type, no code needed */
                if (top->kind == VK_IMM) {
                    top->type = to;
                    break;
                }
                if (from == 'N' && to == 'I') top->type = 'I';
                else if (from == 'I' && to == 'N') top->type = 'N';
                else if (from == 'C' && to == 'I') {
                    if (top->kind == VK_ADDR_HL && top->type == 'C') {
                        vsp--;
                        emit_instr(cc, "ld", "l,(hl)");
                        emit_instr(cc, "ld", "h,0");
                        vpush(VK_HL, NULL, 0, 'I');
                    } else {
                        gen_load_a(cc, top); vsp--;
                        emit_instr(cc, "ld", "l,a");
                        emit_instr(cc, "ld", "h,0");
                        vpush(VK_HL, NULL, 0, 'I');
                    }
                } else if (from == 'N' && to == 'C') {
                    if (top->kind == VK_ADDR_HL && top->type == 'C') {
                        vsp--;
                        emit_instr(cc, "ld", "a,(hl)");
                        vpush(VK_A, NULL, 0, 'C');
                    } else {
                        gen_load_hl(cc, top); vsp--;
                        emit_instr(cc, "ld", "a,l");
                        vpush(VK_A, NULL, 0, 'C');
                    }
                } else if (from == 'C' && to == 'N') {
                    gen_load_a(cc, top); vsp--;
                    emit_instr(cc, "ld", "l,a");
                    emit_instr(cc, "ld", "h,0");
                    vpush(VK_HL, NULL, 0, 'N');
                }
            }
            break;
        }
        case 'R': {
            VVal *idx = vpop();
            VVal *base = vpop();
            if (base && idx) {
                gen_load_hl(cc, idx);
                vpush(VK_HL, base ? base->sym : NULL, 0, tok[1]);
            }
            break;
        }
        case '*': {
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                if (tok[1] == 'R' && b->kind == VK_IMM && b->value == 1) {
                    vstack[vsp++] = *a;
                } else {
                    /* Constant folding */
                    if (a->kind == VK_IMM && b->kind == VK_IMM) {
                        vpush(VK_IMM, NULL, (a->value * b->value) & 0xFFFF, tok[1]);
                        break;
                    }
                    /* Strength reduction */
                    int mv = 0; VVal *vo = NULL;
                    if (b->kind == VK_IMM) { mv = b->value; vo = a; }
                    else if (a->kind == VK_IMM) { mv = a->value; vo = b; }
                    if (mv == 2 && vo) {
                        gen_load_hl(cc, vo);
                        emit_instr(cc, "add", "hl,hl");
                        vpush(VK_HL, NULL, 0, tok[1]);
                        break;
                    } else if (mv == 4 && vo) {
                        gen_load_hl(cc, vo);
                        emit_instr(cc, "add", "hl,hl");
                        emit_instr(cc, "add", "hl,hl");
                        vpush(VK_HL, NULL, 0, tok[1]);
                        break;
                    } else if (mv == 256 && vo) {
                        gen_load_hl(cc, vo);
                        emit_instr(cc, "ld", "h,l");
                        emit_instr(cc, "ld", "l,0");
                        vpush(VK_HL, NULL, 0, tok[1]);
                        break;
                    }
                    /* General: call ?mulhd */
                    if (b->kind == VK_IMM) {
                        gen_load_hl(cc, a);
                        gen_load_de(cc, b);
                    } else if (a->kind == VK_IMM) {
                        gen_load_hl(cc, b);
                        gen_load_de(cc, a);
                    } else if (b->kind == VK_HL) {
                        gen_load_de(cc, a);
                    } else if (a->kind == VK_HL) {
                        gen_load_de(cc, b);
                    } else {
                        gen_load_de(cc, b);
                        gen_load_hl(cc, a);
                    }
                    decl_add("?mulhd", 0);
                    emit_instr(cc, "call", "?mulhd");
                    vpush(VK_HL, NULL, 0, tok[1]);
                }
            }
            break;
        }
        case '.': {
            VVal *member = vpop();
            VVal *base = vtop();
            if (member && base && member->kind == VK_MEMBER) {
                int off = lookup_member_offset(member->value);
                if (base->kind == VK_LOCAL) {
                    base->value += off;
                    base->type = lookup_member_type(member->value);
                }
            }
            break;
        }
        case '\'': {
            /* Dereference pointer */
            VVal *top = vtop();
            if (top) {
                if (top->kind == VK_ADDR_HL) {
                    /* Already an address */
                } else if (top->kind == VK_GLOBAL && !top->is_addr) {
                    char buf[128];
                    snprintf(buf, sizeof(buf), "hl,(%s)", top->sym);
                    emit_instr(cc, "ld", buf);
                    vsp--;
                    vpush(VK_ADDR_HL, NULL, 0, top->type);
                } else if (top->kind == VK_HL && !top->is_addr) {
                    top->kind = VK_ADDR_HL;
                } else {
                    top->is_addr = 1;
                }
            }
            break;
        }
        case '+': case '-': {
            char type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                if (type == 'C') {
                    gen_load_a(cc, a);
                    emit_instr(cc, "ld", "e,a");
                    gen_load_a(cc, b);
                    if (first == '+') emit_instr(cc, "add", "a,e");
                    else emit_instr(cc, "sub", "e"); /* actually ld a,e then sub */
                    vpush(VK_A, NULL, 0, 'C');
                } else {
                    /* Constant folding */
                    if (a->kind == VK_IMM && b->kind == VK_IMM) {
                        int r = (first == '+') ? a->value + b->value : a->value - b->value;
                        vpush(VK_IMM, NULL, r & 0xFFFF, type);
                        break;
                    }
                    /* Special cases for ±1 */
                    if (b->kind == VK_IMM && b->value == 1) {
                        gen_load_hl(cc, a);
                        emit_instr(cc, first == '+' ? "inc" : "dec", "hl");
                    } else if (first == '+' && a->kind == VK_IMM && a->value == 1) {
                        gen_load_hl(cc, b);
                        emit_instr(cc, "inc", "hl");
                    /* Commutative optimization for + */
                    } else if (first == '+' && b->kind == VK_HL) {
                        gen_load_de(cc, a);
                        emit_instr(cc, "add", "hl,de");
                    } else if (first == '+' && (a->kind == VK_BC || b->kind == VK_BC)) {
                        /* BC operand: load other to HL, add hl,bc */
                        if (a->kind == VK_BC) gen_load_hl(cc, b);
                        else gen_load_hl(cc, a);
                        emit_instr(cc, "add", "hl,bc");
                    } else if (first == '+' && b->kind == VK_IMM) {
                        gen_load_hl(cc, a);
                        gen_load_de(cc, b);
                        emit_instr(cc, "add", "hl,de");
                    } else if (first == '-' && b->kind == VK_IMM) {
                        /* Subtract constant: add two's complement */
                        gen_load_hl(cc, a);
                        int neg = (-b->value) & 0xFFFF;
                        char buf[32];
                        snprintf(buf, sizeof(buf), "de,%d", neg);
                        emit_instr(cc, "ld", buf);
                        emit_instr(cc, "add", "hl,de");
                    } else {
                        if (first == '+') {
                            gen_load_de(cc, b);
                            gen_load_hl(cc, a);
                            emit_instr(cc, "add", "hl,de");
                        } else {
                            /* a - b: DE=a, HL=b */
                            gen_load_de(cc, a);
                            gen_load_hl(cc, b);
                            emit_instr(cc, "ld", "a,e");
                            emit_instr(cc, "sub", "l");
                            emit_instr(cc, "ld", "l,a");
                            emit_instr(cc, "ld", "a,d");
                            emit_instr(cc, "sbc", "a,h");
                            emit_instr(cc, "ld", "h,a");
                        }
                    }
                    vpush(VK_HL, NULL, 0, type);
                }
            }
            break;
        }
        case 'M': {
            int mnum = atoi(tok + 1);
            vpush(VK_MEMBER, NULL, mnum, 'N');
            break;
        }
        case '_': {
            /* Negate: _I, _N */
            VVal *top = vtop();
            if (top) {
                if (top->kind == VK_IMM) {
                    top->value = -top->value;
                } else {
                    gen_load_hl(cc, top); vsp--;
                    emit_instr(cc, "ex", "de,hl");
                    emit_instr(cc, "ld", "hl,0");
                    emit_instr(cc, "or", "a");
                    emit_instr(cc, "sbc", "hl,de");
                    vpush(VK_HL, NULL, 0, tok[1]);
                }
            }
            break;
        }
        case '@': {
            /* Dereference pointer (same as ' for globals) */
            VVal *top = vtop();
            if (top) {
                if (top->kind == VK_GLOBAL && !top->is_addr) {
                    char buf[128];
                    snprintf(buf, sizeof(buf), "hl,(%s)", top->sym);
                    emit_instr(cc, "ld", buf);
                    vsp--;
                    vpush(VK_ADDR_HL, NULL, 0, top->type);
                } else if (top->kind == VK_LOCAL && !top->is_addr &&
                           top->type != 'S' && top->type != 'U') {
                    char buf[32];
                    snprintf(buf, sizeof(buf), "l,(ix%+d)", top->value);
                    emit_instr(cc, "ld", buf);
                    snprintf(buf, sizeof(buf), "h,(ix%+d)", top->value + 1);
                    emit_instr(cc, "ld", buf);
                    vsp--;
                    vpush(VK_ADDR_HL, NULL, 0, top->type);
                } else {
                    top->is_addr = 1;
                }
            }
            break;
        }
        case 's': {
            /* Logical OR in jump condition (short-circuit).
             * For `cond1 cond2 s n` → jump to target if NEITHER is true.
             * If cond1 is true, skip past the exit jump (to @skip — the
             * fallthrough past the enclosing j-statement's jump).
             *
             * Both conds have been evaluated by the time we see 's'.
             * To emit short-circuit properly, we insert the jp for cond1
             * retroactively BEFORE cond2's instructions, using the same
             * split-position mechanism as the AND ('m') handler.
             * and_split_pos was recorded when cond2 started a new
             * comparison while cond1's cmp_op was pending. */
            if (and_split_pos >= 0 && and_prev_cmp_op != 0) {
                int skip = cc->local_label++;
                char jbuf2[64];
                /* True-case jump for cond1: z for '=' (eq), nz for '!',
                 * c for '<' (unsigned lt), nc for ']' (unsigned gte). */
                switch (and_prev_cmp_op) {
                case '=': snprintf(jbuf2, sizeof(jbuf2), "z,@%d", skip); break;
                case '!': snprintf(jbuf2, sizeof(jbuf2), "nz,@%d", skip); break;
                case '<': snprintf(jbuf2, sizeof(jbuf2), "c,@%d", skip); break;
                case ']': snprintf(jbuf2, sizeof(jbuf2), "nc,@%d", skip); break;
                default:  snprintf(jbuf2, sizeof(jbuf2), "z,@%d", skip); break;
                }
                if (and_split_pos < instr_count && instr_count < MAX_INSTR) {
                    int k;
                    instr_count++;
                    for (k = instr_count - 1; k > and_split_pos; k--)
                        instr_list[k] = instr_list[k - 1];
                    instr_list[and_split_pos].type = INSTR_INST;
                    snprintf(instr_list[and_split_pos].text, INSTR_BUF,
                             "jp\t%s", jbuf2);
                    if (pending_split_pos > and_split_pos) pending_split_pos++;
                }
                and_split_pos = -1;
                and_prev_cmp_op = 0;
                or_skip_label = skip;
                /* cmp_op (cond2) stays for the final branch. */
            } else if (cmp_op) {
                /* Single-comparison before s (unusual) — emit jp now. */
                int skip = cc->local_label++;
                char jbuf2[64];
                switch (cmp_op) {
                case '=': snprintf(jbuf2, sizeof(jbuf2), "z,@%d", skip); break;
                case '!': snprintf(jbuf2, sizeof(jbuf2), "nz,@%d", skip); break;
                case '<': snprintf(jbuf2, sizeof(jbuf2), "c,@%d", skip); break;
                case ']': snprintf(jbuf2, sizeof(jbuf2), "nc,@%d", skip); break;
                default:  snprintf(jbuf2, sizeof(jbuf2), "z,@%d", skip); break;
                }
                emit_instr(cc, "jp", jbuf2);
                cmp_op = 0;
                or_skip_label = skip;
            }
            break;
        }
        case 'm': {
            /* Logical AND: NOT(cond1 AND cond2) = jump if cond1 fails OR cond2 fails.
             * If we have an and_split_pos (two comparisons were evaluated), insert
             * the first jump retroactively before cond2's instructions, then let
             * the final branch handle cond2.
             * Otherwise (single condition before m), emit the current jump. */
            if (and_split_pos >= 0 && and_prev_cmp_op != 0) {
                /* Two-condition AND: insert jp for cond1 at split point */
                char jbuf2[64];
                switch (and_prev_cmp_op) {
                case '=':  snprintf(jbuf2, sizeof(jbuf2), "nz,@%d", target_label); break;
                case '!':  snprintf(jbuf2, sizeof(jbuf2), "z,@%d", target_label); break;
                case '<':  snprintf(jbuf2, sizeof(jbuf2), "nc,@%d", target_label); break;
                case ']':  snprintf(jbuf2, sizeof(jbuf2), "c,@%d", target_label); break;
                default:   snprintf(jbuf2, sizeof(jbuf2), "nz,@%d", target_label); break;
                }
                /* Insert instruction at and_split_pos by shifting subsequent instrs */
                if (and_split_pos < instr_count && instr_count < MAX_INSTR) {
                    int k;
                    instr_count++;
                    for (k = instr_count - 1; k > and_split_pos; k--)
                        instr_list[k] = instr_list[k - 1];
                    instr_list[and_split_pos].type = INSTR_INST;
                    snprintf(instr_list[and_split_pos].text, INSTR_BUF, "jp\t%s", jbuf2);
                    /* pending_split_pos was recorded at end of cond2;
                     * it must shift by +1 since an instr was inserted
                     * before it. Needed for 3+-way AND/OR chains. */
                    if (pending_split_pos > and_split_pos) pending_split_pos++;
                }
                and_split_pos = -1;
                and_prev_cmp_op = 0;
                /* cmp_op (cond2) stays for final branch */
            } else if (cmp_op) {
                /* Single comparison before m: emit its jump now */
                char jbuf2[64];
                switch (cmp_op) {
                case '=':  snprintf(jbuf2, sizeof(jbuf2), "nz,@%d", target_label); break;
                case '!':  snprintf(jbuf2, sizeof(jbuf2), "z,@%d", target_label); break;
                case '<':  snprintf(jbuf2, sizeof(jbuf2), "nc,@%d", target_label); break;
                case ']':  snprintf(jbuf2, sizeof(jbuf2), "c,@%d", target_label); break;
                default:   snprintf(jbuf2, sizeof(jbuf2), "nz,@%d", target_label); break;
                }
                emit_instr(cc, "jp", jbuf2);
                cmp_op = 0;
            }
            break;
        }
        case 'X': {
            /* Function call within condition expression.
             * Set up icall machinery (same as gen_expr_stmt case 'X') */
            strncpy(icall_name, tok + 1, sizeof(icall_name) - 1);
            icall_name[sizeof(icall_name) - 1] = '\0';
            icall_active = 1;
            icall_nargs = 0;
            icall_ret_type = 'C'; /* default, overridden by 'c' token */
            break;
        }
        case 'a': {
            VVal *top = vtop();
            if (top) top->is_addr = 1;
            break;
        }
        case ';': {
            /* Compound inc/dec inside conditional jump expression.
             * Token format: ;<op><type> where op='+'/'-', type='N'/'I'/'C'/'R'.
             * Mirrors the ;-handler in gen_expr_stmt: decrement/increment
             * the variable and leave the post-op value on vstack for
             * the following comparison. Needed for TMC patterns like
             *   j L A8 #1 ;-I #0 !I n   (while (--A8) ...) */
            char op = tok[1];
            char type = tok[2];
            VVal *delta = vpop();
            VVal *var = vpop();
            if (var && delta) {
                if (type == 'C') {
                    gen_load_a(cc, var);
                    if (op == '+') {
                        if (delta->kind == VK_IMM && delta->value == 1)
                            emit_instr(cc, "inc", "a");
                        else {
                            emit_instr(cc, "ld", "e,a");
                            gen_load_a(cc, delta);
                            emit_instr(cc, "add", "a,e");
                        }
                    } else {
                        if (delta->kind == VK_IMM && delta->value == 1)
                            emit_instr(cc, "dec", "a");
                        else {
                            emit_instr(cc, "ld", "e,a");
                            gen_load_a(cc, delta);
                            emit_instr(cc, "ld", "b,a");
                            emit_instr(cc, "ld", "a,e");
                            emit_instr(cc, "sub", "b");
                        }
                    }
                    gen_store_a(cc, var);
                    vpush(VK_A, NULL, 0, 'C');
                } else {
                    /* Register-allocated fast path for ±1 */
                    if (var->kind == VK_DE &&
                        delta->kind == VK_IMM && delta->value == 1) {
                        emit_instr(cc, op == '+' ? "inc" : "dec", "de");
                        vpush(VK_DE, NULL, 0, type);
                        break;
                    }
                    if (var->kind == VK_BC &&
                        delta->kind == VK_IMM && delta->value == 1) {
                        emit_instr(cc, op == '+' ? "inc" : "dec", "bc");
                        vpush(VK_BC, NULL, 0, type);
                        break;
                    }
                    gen_load_hl(cc, var);
                    if (op == '+') {
                        if (delta->kind == VK_IMM && delta->value == 1)
                            emit_instr(cc, "inc", "hl");
                        else if (delta->kind == VK_IMM) {
                            char buf[32];
                            snprintf(buf, sizeof(buf), "de,%d",
                                     delta->value & 0xFFFF);
                            emit_instr(cc, "ld", buf);
                            emit_instr(cc, "add", "hl,de");
                        }
                    } else {
                        if (delta->kind == VK_IMM && delta->value == 1)
                            emit_instr(cc, "dec", "hl");
                        else if (delta->kind == VK_IMM) {
                            int neg = (-delta->value) & 0xFFFF;
                            char buf[32];
                            snprintf(buf, sizeof(buf), "de,%d", neg);
                            emit_instr(cc, "ld", buf);
                            emit_instr(cc, "add", "hl,de");
                        }
                    }
                    gen_store_hl(cc, var);
                    vpush(VK_HL, NULL, 0, type);
                }
            }
            break;
        }
        case 'p': {
            /* Push arg for pending function call */
            if (icall_active) {
                VVal *val = vpop();
                if (val && icall_nargs < ICALL_MAX_ARGS) {
                    icall_args[icall_nargs] = *val;
                    icall_arg_types[icall_nargs] = tok[1];
                    icall_nargs++;
                }
            }
            break;
        }
        case 'c': {
            /* Call convention type: 'c' followed by type char */
            if (icall_active) icall_ret_type = tok[1];
            break;
        }
        case 'F': {
            /* Function call dispatch: F0, F1, F2, F3 */
            if (icall_active) {
                int arg_count = atoi(tok + 1);
                char asmname[128];
                make_asm_name(icall_name, asmname, sizeof(asmname));
                decl_add(asmname, 0);
                gen_inline_call(cc, asmname, 'F', arg_count);
                icall_active = 0;
                /* Result in HL (or A for char) */
                if (icall_ret_type == 'C')
                    vpush(VK_A, NULL, 0, 'C');
                else
                    vpush(VK_HL, NULL, 0, icall_ret_type);
            }
            break;
        }
        case 'U': {
            /* Function call via push stack: U1, U2, ... */
            if (icall_active) {
                int arg_count = atoi(tok + 1);
                char asmname[128];
                make_asm_name(icall_name, asmname, sizeof(asmname));
                decl_add(asmname, 0);
                gen_inline_call(cc, asmname, 'U', arg_count);
                icall_active = 0;
                vpush(VK_HL, NULL, 0, icall_ret_type);
            }
            break;
        }
        case ':': {
            /* Assignment in condition: :C, :N, :I, :R
             * Stores top-of-stack value to second-from-top destination */
            char atype = tok[1];
            VVal *val = vpop();
            VVal *dest = vpop();
            if (val && dest) {
                if (dest->kind == VK_GLOBAL) {
                    /* Store to global */
                    if (atype == 'C') {
                        /* char: use A register path */
                        gen_load_a(cc, val);
                        char buf[128];
                        snprintf(buf, sizeof(buf), "(%s),a", dest->sym);
                        emit_instr(cc, "ld", buf);
                        vpush(VK_A, NULL, 0, 'C');
                    } else {
                        gen_load_hl(cc, val);
                        char buf[128];
                        snprintf(buf, sizeof(buf), "(%s),hl", dest->sym);
                        emit_instr(cc, "ld", buf);
                        vpush(VK_HL, NULL, 0, atype);
                    }
                } else {
                    /* Other destination: push result back */
                    vstack[vsp++] = *val;
                }
            }
            break;
        }
        default:
            break;
        }
    }

    /* Generate conditional jump based on comparison.
     * After ?cpshd: carry set if HL < DE.
     * After cp: carry set if A < operand, zero if equal.
     * 'n' at end means "jump if NOT condition".
     * So `j L<n> <expr> <cmp> n` = jump to L<n> if comparison is FALSE.
     *
     * Comparison semantics with n (negate):
     *   <  + n = jump if NOT less = jump if >= → jp nc
     *   >  + n = jump if NOT greater = jump if <= → jp nc (swapped operands)
     *   =  + n = jump if NOT equal → jp nz
     *   !  + n = jump if NOT not-equal = jump if equal → jp z
     *   [  + n = jump if NOT less-equal = jump if > → jp nc then jp nz (or c for >)
     *   ]  + n = jump if NOT greater-equal = jump if < → jp c
     */
    char jbuf[64];
    if (negate) {
        switch (cmp_op) {
        case '<':
            snprintf(jbuf, sizeof(jbuf), "nc,@%d", target_label);
            break;
        case '>':
            /* After ?cpshd with swapped args or after cp */
            snprintf(jbuf, sizeof(jbuf), "nc,@%d", target_label);
            break;
        case '=':
            if (cmp_type == 'C')
                snprintf(jbuf, sizeof(jbuf), "nz,@%d", target_label);
            else
                snprintf(jbuf, sizeof(jbuf), "nz,@%d", target_label);
            break;
        case '!':
            if (cmp_type == 'C')
                snprintf(jbuf, sizeof(jbuf), "z,@%d", target_label);
            else
                snprintf(jbuf, sizeof(jbuf), "z,@%d", target_label);
            break;
        case '[': /* <= + n = > */
            snprintf(jbuf, sizeof(jbuf), "nc,@%d", target_label);
            break;
        case ']': /* >= + n = < */
            snprintf(jbuf, sizeof(jbuf), "c,@%d", target_label);
            break;
        default:
            snprintf(jbuf, sizeof(jbuf), "@%d", target_label);
            break;
        }
    } else {
        switch (cmp_op) {
        case '<':
            snprintf(jbuf, sizeof(jbuf), "c,@%d", target_label);
            break;
        case ']':
            /* >= (unsigned): carry clear means A >= B → jp nc */
            snprintf(jbuf, sizeof(jbuf), "nc,@%d", target_label);
            break;
        case '=':
            snprintf(jbuf, sizeof(jbuf), "z,@%d", target_label);
            break;
        case '!':
            snprintf(jbuf, sizeof(jbuf), "nz,@%d", target_label);
            break;
        default:
            snprintf(jbuf, sizeof(jbuf), "@%d", target_label);
            break;
        }
    }
    emit_instr(cc, "jp", jbuf);

    /* Emit OR-skip label after the final jump (for logical OR short-circuit) */
    if (or_skip_label >= 0) {
        char buf[32];
        snprintf(buf, sizeof(buf), "@%d", or_skip_label);
        emit_label_instr(buf);
    }
}

/* Generate return value: y<type>\t<expr>
 * Reuses the same expression dispatch as gen_expr_stmt. */
static void gen_return_stmt(Cc2State *cc)
{
    char rtype = (char)tmc_read_char(cc);
    /* Use gen_expr_stmt to evaluate the expression */
    gen_expr_stmt(cc);

    /* Load result into return register */
    if (vsp > 0) {
        VVal *result = &vstack[vsp - 1];
        if (rtype == 'C') {
            gen_load_a(cc, result);
        } else {
            gen_load_hl(cc, result);
        }
    }
    func_has_return = 1;
}

/* ================================================================
 *  Parse function body — handles ALL statement types
 *
 *  After "{" is consumed, reads statements until "}"
 * ================================================================ */
static void parse_function_body(Cc2State *cc)
{
    int ch;
    func_is_simple = body_is_simple(cc);

    for (;;) {
        ch = tmc_read_char(cc);

        if (ch == '}' || ch == 0x1A) {
            tmc_skip_line(cc);
            break;
        }

        if (ch == 'L') {
            /* Label definition: L<n> */
            int lnum = tmc_read_number(cc);
            tmc_skip_line(cc);
            emit_at_label(cc, lnum);
            continue;
        }

        if (ch == '\t') {
            ch = tmc_read_char(cc);

            if (ch == 'X' && func_is_simple) {
                /* Function call — use simple symbolic evaluator */
                char func_name[128];
                tmc_read_token(cc, func_name, sizeof(func_name));
                parse_func_call(cc, func_name);
                continue;
            }

            if (ch == 'd') {
                /* Loop start */
                tmc_skip_line(cc);
                int lbl = cc->local_label++;
                if (loop_depth < MAX_LOOP_DEPTH) {
                    loop_labels[loop_depth++] = lbl;
                }
                char buf[32];
                snprintf(buf, sizeof(buf), "@%d", lbl);
                emit_label_instr(buf);
                continue;
            }

            if (ch == 'b') {
                /* Branch back to loop start */
                tmc_skip_line(cc);
                if (loop_depth > 0) {
                    char buf[32];
                    snprintf(buf, sizeof(buf), "@%d", loop_labels[loop_depth - 1]);
                    emit_instr(cc, "jp", buf);
                    loop_depth--;
                }
                continue;
            }

            if (ch == 'j') {
                /* Conditional jump: j\tL<n>\t<expr>\tn
                 *
                 * Loop inversion: if j is followed by [labels +] b (loop-back),
                 * invert the condition and jump to loop start instead.
                 * This transforms: jp nz,@exit / jp @loop → jp z,@loop
                 * Matching the CCC.ASM optimizer behavior. */
                int saved_instr_count = instr_count;
                gen_cond_jump(cc);
                continue;
            }

            if (ch == 'y') {
                /* Return statement: y<type>\t<expr> */
                gen_return_stmt(cc);
                /* Emit early return: jp to epilogue or ret */
                if (func_has_locals && func_frame_bytes > 0) {
                    if (func_epilogue_label < 0)
                        func_epilogue_label = cc->local_label++;
                    char buf[32];
                    snprintf(buf, sizeof(buf), "@%d", func_epilogue_label);
                    emit_instr(cc, "jp", buf);
                } else {
                    emit_instr(cc, "ret", "");
                }
                continue;
            }

            if (ch == 'X') {
                if (func_is_simple) {
                    /* Simple: use symbolic evaluator */
                    char func_name[128];
                    tmc_read_token(cc, func_name, sizeof(func_name));
                    parse_func_call(cc, func_name);
                } else {
                    /* Complex: route through gen_expr_stmt for inline handling */
                    tmc_pushback(cc, ch);
                    gen_expr_stmt(cc);
                }
                continue;
            }

            if (ch == 'e') {
                /* Switch expression — port of A0D91 in CCC.ASM.
                 * TMC: e<type>\t<expr>   (type C/I/N; expr = G/A/P/X... F)
                 * Emits: load switch expression into A (for char) or HL (for int). */
                int etype = tmc_read_char(cc);
                tmc_expect_tab(cc);
                int echar = tmc_read_char(cc);
                if (echar == 'G') {
                    char gname[128];
                    tmc_read_token(cc, gname, sizeof(gname));
                    char asmn[128];
                    make_asm_name(gname, asmn, sizeof(asmn));
                    char buf[128];
                    if (etype == 'C') {
                        snprintf(buf, sizeof(buf), "a,(%s)", asmn);
                        emit_instr(cc, "ld", buf);
                    } else {
                        snprintf(buf, sizeof(buf), "hl,(%s)", asmn);
                        emit_instr(cc, "ld", buf);
                    }
                    tmc_skip_line(cc);
                } else if (echar == 'A' || echar == 'P') {
                    int id = tmc_read_number(cc);
                    LocalVar *lv = find_local(id);
                    tmc_skip_line(cc);
                    if (lv) {
                        char buf[128];
                        if (etype == 'C') {
                            if (lv->reg == VK_A) {
                                /* already in A */
                            } else if (lv->reg != VK_NONE) {
                                const char *reg_low = "e";
                                if (lv->reg == VK_BC) reg_low = "c";
                                else if (lv->reg == VK_HL) reg_low = "l";
                                snprintf(buf, sizeof(buf), "a,%s", reg_low);
                                emit_instr(cc, "ld", buf);
                            } else {
                                snprintf(buf, sizeof(buf), "a,(ix%+d)", lv->ix_offset);
                                emit_instr(cc, "ld", buf);
                            }
                        } else {
                            if (lv->reg == VK_HL) {
                                /* already in HL */
                            } else if (lv->reg == VK_DE) {
                                emit_instr(cc, "ex", "de,hl");
                            } else if (lv->reg == VK_BC) {
                                emit_instr(cc, "ld", "l,c");
                                emit_instr(cc, "ld", "h,b");
                            } else {
                                snprintf(buf, sizeof(buf), "l,(ix%+d)", lv->ix_offset);
                                emit_instr(cc, "ld", buf);
                                snprintf(buf, sizeof(buf), "h,(ix%+d)", lv->ix_offset + 1);
                                emit_instr(cc, "ld", buf);
                            }
                        }
                    }
                } else if (echar == 'X') {
                    /* Complex switch expression — function call.
                     * Push back X and use gen_expr_stmt's machinery to
                     * evaluate. Result ends up in A (char) or HL (int). */
                    tmc_pushback(cc, echar);
                    /* parse_func_call reads until newline, leaves result in HL */
                    if (func_is_simple) {
                        char func_name[128];
                        tmc_read_char(cc); /* consume X */
                        tmc_read_token(cc, func_name, sizeof(func_name));
                        parse_func_call(cc, func_name);
                        if (etype == 'C') emit_instr(cc, "ld", "a,l");
                    } else {
                        gen_expr_stmt(cc);
                        /* Result is on vstack top; ensure in A or HL */
                        if (vsp > 0) {
                            VVal *r = &vstack[vsp - 1];
                            if (etype == 'C') gen_load_a(cc, r);
                            else gen_load_hl(cc, r);
                            vsp--;
                        }
                    }
                } else {
                    tmc_skip_line(cc);
                }
                continue;
            }

            if (ch == 'w') {
                /* Switch case entry — port of A0DB7 in CCC.ASM.
                 * TMC: w\tL<n>\t#<val>
                 * Emits: cp <val>; jp z,@<label(L<n>)> */
                tmc_expect_tab(cc);
                int dch = tmc_read_char(cc);
                if (dch != 'L') { tmc_skip_line(cc); continue; }
                int tmc_label = tmc_read_number(cc);
                int target = get_label(cc, tmc_label);
                tmc_expect_tab(cc);
                dch = tmc_read_char(cc);
                if (dch != '#') { tmc_skip_line(cc); continue; }
                int cval = tmc_read_number(cc);
                tmc_skip_line(cc);
                char buf[32];
                snprintf(buf, sizeof(buf), "%d", cval & 0xFF);
                emit_instr(cc, "cp", buf);
                snprintf(buf, sizeof(buf), "z,@%d", target);
                emit_instr(cc, "jp", buf);
                continue;
            }

            if (ch == 'f') {
                /* Switch default — port of A0E41 in CCC.ASM.
                 * TMC: f\tL<n>
                 * Emits: jp @<label(L<n>)> */
                tmc_expect_tab(cc);
                int dch = tmc_read_char(cc);
                if (dch != 'L') { tmc_skip_line(cc); continue; }
                int tmc_label = tmc_read_number(cc);
                int target = get_label(cc, tmc_label);
                tmc_skip_line(cc);
                char buf[32];
                snprintf(buf, sizeof(buf), "@%d", target);
                emit_instr(cc, "jp", buf);
                continue;
            }

            /* Expression statement: starts with A<n>, G<name>, etc. */
            tmc_pushback(cc, ch);
            gen_expr_stmt(cc);
            continue;
        }

        if (ch == '\n') continue;

        /* Unexpected */
        tmc_skip_line(cc);
    }
}

/* ================================================================
 *  Parse struct/union definition
 *  Format: S<n>\t(\nM<n>\t<type>\n...\n)\n
 *  Now also tracks member offsets for the . operator
 * ================================================================ */
static void parse_struct(Cc2State *cc, int is_union)
{
    int num = tmc_read_number(cc);
    tmc_skip_line(cc);

    int total_size = 0;
    int max_size = 0;
    int ch;

    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == ')') {
            tmc_skip_line(cc);
            break;
        }
        if (ch == 'M') {
            int mnum = tmc_read_number(cc);
            tmc_expect_tab(cc);
            char type_buf[32];
            tmc_read_token(cc, type_buf, sizeof(type_buf));

            int sz;
            int type_num = 0;
            if (type_buf[0] == 'S' || type_buf[0] == 'U') {
                type_num = atoi(type_buf + 1);
                sz = lookup_struct_size(cc, type_num);
            } else if (type_buf[0] == 'V') {
                int vnum = atoi(type_buf + 1);
                sz = 0;
                int i;
                for (i = 0; i < cc->sym_count; i++) {
                    if (cc->sym[i].type == SYM_VAR && cc->sym[i].name == (u16)vnum) {
                        sz = cc->sym[i].value;
                        break;
                    }
                }
                if (sz == 0) sz = 1;
            } else {
                sz = type_size(type_buf[0]);
            }

            /* Record member info */
            if (member_count < MAX_MEMBERS) {
                member_list[member_count].struct_num = num;
                member_list[member_count].member_num = mnum;
                member_list[member_count].offset = is_union ? 0 : total_size;
                member_list[member_count].size = sz;
                member_list[member_count].type = type_buf[0];
                member_list[member_count].type_num = type_num;
                member_count++;
            }

            if (is_union) {
                if (sz > max_size) max_size = sz;
            } else {
                total_size += sz;
            }
        }
        tmc_skip_line(cc);
    }

    if (is_union) total_size = max_size;

    int name_id = name_add("", 0);
    sym_add(cc, is_union ? SYM_UNION : SYM_STRUCT,
            (u16)total_size, (u16)num, 0);
    (void)name_id;
}

/* ================================================================
 *  Parse global variable
 * ================================================================ */
static void parse_global(Cc2State *cc)
{
    char name[128];
    tmc_read_token(cc, name, sizeof(name));
    tmc_expect_tab(cc);

    char asmname[128];
    make_asm_name(name, asmname, sizeof(asmname));

    int ch = tmc_read_char(cc);

    if (ch == '(') {
        tmc_skip_line(cc);
        out_set_cseg(cc);
        io_write_str(cc, asmname);
        io_write_str(cc, ":\n");

        for (;;) {
            ch = tmc_read_char(cc);
            if (ch == ')') { tmc_skip_line(cc); break; }
            if (ch == '\t') {
                ch = tmc_read_char(cc);
                if (ch == 'R') {
                    tmc_expect_tab(cc);
                    ch = tmc_read_char(cc);
                    if (ch == '"') {
                        int sidx = parse_string_const(cc);
                        char buf[32];
                        snprintf(buf, sizeof(buf), "?%d", str_consts[sidx].label);
                        out_instruction(cc, "dw", buf);
                    }
                    tmc_skip_line(cc);
                } else if (ch == 'I' || ch == 'N' || ch == 'C') {
                    /* Integer/numeric initializer: I #0, I #1_I, etc. */
                    tmc_expect_tab(cc);
                    ch = tmc_read_char(cc); /* skip '#' */
                    int val = tmc_read_number(cc);
                    /* Check for _I (negate) suffix */
                    /* Check for _I (negate): may be immediately after number
                     * or after a tab separator */
                    ch = tmc_read_char(cc);
                    if (ch == '\t') ch = tmc_read_char(cc); /* skip tab */
                    if (ch == '_') {
                        tmc_read_char(cc); /* skip type char */
                        val = -val;
                        ch = tmc_read_char(cc);
                    }
                    /* Emit dw */
                    char buf[32];
                    int v = val;
                    if (v < 0) v = 65536 + v;
                    snprintf(buf, sizeof(buf), "%d", v);
                    out_instruction(cc, "dw", buf);
                    /* Skip rest of line */
                    while (ch != '\n' && ch != 0x1A) ch = tmc_read_char(cc);
                } else {
                    tmc_skip_line(cc);
                }
            } else {
                tmc_skip_line(cc);
            }
        }

        emit_string_consts(cc);
        str_const_count = 0;
        str_data_pos = 0;
        decl_add(asmname, 1);

    } else {
        char type_buf[32];
        type_buf[0] = (char)ch;
        int len = 1;
        for (;;) {
            ch = tmc_read_char(cc);
            if (ch == '\n' || ch == '\t' || ch == 0x1A) break;
            if (len < 30) type_buf[len++] = (char)ch;
        }
        type_buf[len] = '\0';

        int sz;
        if (type_buf[0] == 'V') {
            int vnum = atoi(type_buf + 1);
            sz = 0;
            int i;
            for (i = 0; i < cc->sym_count; i++) {
                if (cc->sym[i].type == SYM_VAR && cc->sym[i].name == (u16)vnum) {
                    sz = cc->sym[i].value;
                    break;
                }
            }
            if (sz == 0) sz = 2;
        } else {
            sz = type_size(type_buf[0]);
        }

        out_set_dseg(cc);
        char buf[256];
        snprintf(buf, sizeof(buf), "%s:\tds\t%d", asmname, sz);
        io_write_str(cc, buf);
        io_write_newline(cc);

        decl_add(asmname, 1);

        if (ch == '\t' || ch == 0x1A) tmc_skip_line(cc);
    }
}

/* ================================================================
 *  Parse V (variable size constant)
 * ================================================================ */
static void parse_varsize(Cc2State *cc)
{
    int num = tmc_read_number(cc);
    tmc_expect_tab(cc);
    char type_buf[32];
    tmc_read_token(cc, type_buf, sizeof(type_buf));
    tmc_expect_tab(cc);
    int ch = tmc_read_char(cc);
    (void)ch;
    int val = tmc_read_number(cc);
    int sz = type_size(type_buf[0]);
    int total = sz * val;
    sym_add(cc, SYM_VAR, (u16)total, (u16)num, 0);
    tmc_skip_line(cc);
}

/* ================================================================
 *  Parse T (typedef / static local / initialized table)
 *
 *  Three forms in TMC:
 *    T2 I         — typedef (abstract type alias), ignored
 *    T62 N        — static local variable, emits dseg ?62: ds 2
 *    T52 (        — initialized table, emits cseg ?52: db ...
 * ================================================================ */
static void parse_typedef(Cc2State *cc)
{
    int num = tmc_read_number(cc);
    tmc_expect_tab(cc);

    int ch = tmc_read_char(cc);

    if (ch == '(') {
        /* Initialized table: T52 ( C #3 CI ... ) */
        tmc_skip_line(cc); /* skip rest of opening line */

        /* Determine element type from first data line */
        /* Read all entries */
        int values[4096];
        int count = 0;
        char elem_type = 'C'; /* default to byte */

        for (;;) {
            ch = tmc_read_char(cc);
            if (ch == ')') { tmc_skip_line(cc); break; }
            if (ch == '\t') {
                /* Read element type */
                char etype = (char)tmc_read_char(cc);
                if (count == 0) elem_type = etype;
                tmc_expect_tab(cc);
                /* Read value: #N or #N_I (negative) */
                ch = tmc_read_char(cc); /* skip '#' */
                int val = tmc_read_number(cc);
                /* Check for CI (char→int cast) or _I (negate) suffix */
                ch = tmc_read_char(cc);
                if (ch == '\t') ch = tmc_read_char(cc); /* skip tab */
                if (ch == '_') {
                    /* _I = negate */
                    tmc_read_char(cc); /* skip 'I' */
                    val = -val;
                }
                /* Skip rest of line (CI suffix etc.) */
                while (ch != '\n' && ch != 0x1A) ch = tmc_read_char(cc);

                if (count < 4096) values[count++] = val;
            } else {
                tmc_skip_line(cc);
            }
        }

        /* Emit table in cseg */
        out_set_cseg(cc);
        char label[32];
        snprintf(label, sizeof(label), "?%d", num);
        io_write_str(cc, label);
        io_write_str(cc, ":\n");

        if (elem_type == 'C') {
            /* Byte table: one db per element (matches original) */
            int i;
            for (i = 0; i < count; i++) {
                char buf[32];
                snprintf(buf, sizeof(buf), "%d", values[i] & 0xFF);
                out_instruction(cc, "db", buf);
            }
        } else {
            /* Word table: dw values */
            int i;
            for (i = 0; i < count; i++) {
                char buf[32];
                int v = values[i];
                if (v < 0) v = 65536 + v; /* two's complement */
                snprintf(buf, sizeof(buf), "%d", v);
                out_instruction(cc, "dw", buf);
            }
        }
    } else if (ch >= 'A' && ch <= 'Z') {
        /* Type-only declaration: could be typedef or static local */
        char type_ch = (char)ch;
        tmc_skip_line(cc);

        /* Check if this T-number is referenced in function bodies.
         * Static locals use T<n> directly in expressions.
         * Typedefs are only referenced as type annotations.
         * Heuristic: N, I, C, R types used between functions = static locals.
         * Complex types (referenced as struct etc.) = typedefs. */
        if (type_ch == 'N' || type_ch == 'I' || type_ch == 'C' || type_ch == 'R') {
            /* Emit as static local in dseg */
            int sz = type_size(type_ch);
            out_set_dseg(cc);
            char buf[64];
            snprintf(buf, sizeof(buf), "?%d:\tds\t%d", num, sz);
            io_write_str(cc, buf);
            io_write_newline(cc);
        }
        /* Otherwise: typedef, ignored */
    } else {
        tmc_skip_line(cc);
    }
}

/* ================================================================
 *  Parse function definition and body
 * ================================================================ */
static void parse_function(Cc2State *cc)
{
    char name[128];
    tmc_read_token(cc, name, sizeof(name));

    char asmname[128];
    make_asm_name(name, asmname, sizeof(asmname));

    /* Read function attributes: <rettype> F [E] */
    int is_extern = 0;
    char ret_type = 'I';
    int ch;
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == '\n' || ch == 0x1A) break;
        if (ch == '\t') continue;
        if (ch == 'E') is_extern = 1;
        else if (ch == 'F') { /* function marker */ }
        else {
            ret_type = (char)ch;
            char buf[32];
            int len = 0;
            for (;;) {
                ch = tmc_read_char(cc);
                if (ch == '\t' || ch == '\n' || ch == 0x1A) {
                    tmc_pushback(cc, ch);
                    break;
                }
                if (len < 30) buf[len++] = (char)ch;
            }
        }
    }

    /* Read parameters until '{' */
    local_count = 0;
    param_count = 0;
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == '{') { tmc_skip_line(cc); break; }
        if (ch == 'P') {
            int id = tmc_read_number(cc);
            tmc_expect_tab(cc);
            char type_buf[32];
            tmc_read_token(cc, type_buf, sizeof(type_buf));
            tmc_skip_line(cc);
            if (local_count < MAX_LOCALS) {
                locals[local_count].prefix = 'P';
                locals[local_count].id = id;
                locals[local_count].type = type_buf[0];
                locals[local_count].struct_num = 0;
                if (type_buf[0] == 'S') {
                    locals[local_count].struct_num = atoi(type_buf + 1);
                    locals[local_count].size = lookup_struct_size(cc, locals[local_count].struct_num);
                } else {
                    locals[local_count].size = type_size(type_buf[0]);
                }
                locals[local_count].ix_offset = 0; /* computed later */
                local_count++;
                param_count++;
            }
        } else if (ch == '\n') {
            continue;
        } else if (ch == 0x1A) {
            break;
        } else {
            tmc_pushback(cc, ch);
            tmc_skip_line(cc);
        }
    }

    /* Reset per-function state */
    str_const_count = 0;
    str_data_pos = 0;
    instr_count = 0;
    loop_depth = 0;
    hl_spilled = 0;
    de_spilled = 0;
    func_ret_type = ret_type;
    func_has_return = 0;
    func_epilogue_label = -1;
    memset(label_map, -1, sizeof(label_map));

    /* Read local variable declarations (A<n> at start of body) */
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == 'A') {
            int id = tmc_read_number(cc);
            int next = tmc_read_char(cc);
            if (next == '\t') {
                int peek = tmc_peek_char(cc);
                if (peek == 'S' || peek == 'N' || peek == 'I' ||
                    peek == 'C' || peek == 'R' || peek == 'U' ||
                    peek == 'V') {
                    char type_buf[32];
                    tmc_read_token(cc, type_buf, sizeof(type_buf));
                    tmc_skip_line(cc);
                    if (local_count < MAX_LOCALS) {
                        locals[local_count].prefix = 'A';
                        locals[local_count].id = id;
                        locals[local_count].type = type_buf[0];
                        locals[local_count].struct_num = 0;
                        if (type_buf[0] == 'S') {
                            locals[local_count].struct_num = atoi(type_buf + 1);
                            locals[local_count].size = lookup_struct_size(cc, locals[local_count].struct_num);
                        } else if (type_buf[0] == 'V') {
                            int vnum = atoi(type_buf + 1);
                            int sz = 0, vi;
                            for (vi = 0; vi < cc->sym_count; vi++) {
                                if (cc->sym[vi].type == SYM_VAR &&
                                    cc->sym[vi].name == (u16)vnum) {
                                    sz = cc->sym[vi].value;
                                    break;
                                }
                            }
                            locals[local_count].size = sz > 0 ? sz : 2;
                        } else {
                            locals[local_count].size = type_size(type_buf[0]);
                        }
                        locals[local_count].ix_offset = 0;
                        local_count++;
                    }
                    continue;
                }
            }
            /* Not a declaration - push back */
            tmc_pushback(cc, next);
            {
                char id_str[32];
                snprintf(id_str, sizeof(id_str), "%d", id);
                int k;
                for (k = (int)strlen(id_str) - 1; k >= 0; k--)
                    tmc_pushback(cc, id_str[k]);
            }
            tmc_pushback(cc, 'A');
            break;
        } else if (ch == 'V') {
            /* V declaration inside function body — parse it */
            parse_varsize(cc);
            continue;
        } else if (ch == '\t' || ch == '}' || ch == 'L' || ch == 'd') {
            tmc_pushback(cc, ch);
            break;
        } else if (ch == '\n') {
            continue;
        } else {
            tmc_pushback(cc, ch);
            break;
        }
    }

    /* Initialize reg field */
    {
        int i;
        for (i = 0; i < local_count; i++)
            locals[i].reg = VK_NONE;
    }

    /* Count auto locals (non-params) */
    int auto_count = local_count - param_count;

    /* Compute local variable frame layout */
    func_frame_bytes = 0;
    func_has_locals = 0;

    /* Try register allocation for simple functions:
     * F1 with 1 param and no auto locals → param stays in register */
    if (auto_count == 0 && param_count == 1) {
        /* Single param, no locals → keep param in register, no frame */
        if (locals[0].type == 'C') {
            locals[0].reg = VK_A;  /* char param stays in A */
        } else {
            locals[0].reg = VK_HL; /* int/ptr param stays in HL */
        }
        /* No frame needed */
    } else if (auto_count == 0 && param_count == 0) {
        /* No params, no locals → no frame */
    } else {
        int i;
        int offset = 0;
        /* Param-first layout (matches CCC.ASM):
         * First param saved via push hl → IX-2/-1
         * Then auto locals follow at IX-4, IX-6, etc. */

        /* Parameters first: saved via push hl in prologue */
        for (i = 0; i < local_count; i++) {
            if (locals[i].prefix == 'P') {
                offset += locals[i].size;
                locals[i].ix_offset = -offset;
                func_has_locals = 1;
            }
        }
        /* Auto locals follow after parameters */
        for (i = 0; i < local_count; i++) {
            if (locals[i].prefix == 'A') {
                offset += locals[i].size;
                locals[i].ix_offset = -offset;
                func_has_locals = 1;
            }
        }
        func_frame_bytes = offset;
    }

    /* Add public declaration BEFORE body parsing (so it comes before extrns) */
    if (is_extern) {
        decl_add(asmname, 1);
    }

    /* Two-pass optimization for non-trivial functions:
     * Pass 1: capture body TMC, count variable usage
     * Pass 2: replay body with register allocation decisions */
    if (func_has_locals && func_frame_bytes > 0) {
        /* Capture body into buffer */
        body_capture(cc);

        /* Count variable usage */
        body_count_usage();

        /* Build code tree (parallel analysis — does not affect code generation) */
        ct_build_body(cc);
        ct_analyze_body();

        /* Frame layout — port of A0A62/A6131 behavior from CCC.ASM.
         *
         * Rule derived from studying the ASM (A0A62 pushes to D9CDD; ref
         * output for timer_start shows A64 struct at deepest positions
         * and scalars ordered so that declared-1st scalar ends up at the
         * TOP of frame closest to IX):
         *
         *   1. Parameters first (saved via push hl at IX-2..IX-1).
         *   2. Composite locals (struct/union) at DEEPEST offsets,
         *      in declaration order, accessed via SP-relative + offset.
         *   3. Scalar locals at TOP (closest to IX), in REVERSE declaration
         *      order so that declared-1st scalar gets the lowest |ix_offset|.
         *
         * Implementation: build frame offset_in_frame from 0 (deepest) to
         * frame_size (top). Then ix_offset = -(frame_size - offset_in_frame).
         */
        {
            int i;
            int offset = 0;
            func_has_locals = 0;
            /* Parameters first (saved via push hl) */
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'P') {
                    offset += locals[i].size;
                    locals[i].ix_offset = -offset;
                    func_has_locals = 1;
                }
            }
            /* Structs/unions at deepest remaining offsets, declaration order */
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'A' &&
                    (locals[i].type == 'S' || locals[i].type == 'U')) {
                    VarUsage *vu = find_var_usage(locals[i].id);
                    if (vu && vu->count > 0) {
                        offset += locals[i].size;
                        locals[i].ix_offset = -offset;
                        func_has_locals = 1;
                    } else {
                        locals[i].ix_offset = 0;
                    }
                }
            }
            /* Scalars: allocate in REVERSE declaration order so first-declared
             * ends up at top of frame (lowest |ix_offset|) */
            for (i = local_count - 1; i >= 0; i--) {
                if (locals[i].prefix == 'A' &&
                    locals[i].type != 'S' && locals[i].type != 'U') {
                    VarUsage *vu = find_var_usage(locals[i].id);
                    if (vu && vu->count > 0) {
                        offset += locals[i].size;
                        locals[i].ix_offset = -offset;
                        func_has_locals = 1;
                    } else {
                        locals[i].ix_offset = 0;
                    }
                }
            }
            func_frame_bytes = offset;
            /* Recompute ix_offset as -(frame_size - var_offset_in_frame).
             * The loops above accumulated offset going "down" (each var at
             * ix_offset = -running_total), which gives declared-1st scalar
             * at DEEPEST. We want reverse: declared-1st scalar at SHALLOWEST.
             * The reverse loop above already reversed scalars, so the layout
             * is now: params (shallowest), scalars (reverse order, top), then
             * structs (deepest). Let me re-invert ix_offsets:
             *
             * Actually the current loops produce the right layout. Verify:
             * For timer_start (no params, A64 struct, A65/A66 scalars):
             *   offset=0 start
             *   A64 struct: offset=4, ix=-4     ← NOT what we want
             *   A66 (rev scalar): offset=6, ix=-6
             *   A65 (rev scalar): offset=8, ix=-8
             *
             * That gives A64 at (ix-4..ix-1) — declared FIRST at TOP. Wrong.
             *
             * We need: structs at DEEPEST (ix_offset = -frame_size+0).
             * That means structs should be allocated LAST in the offset
             * accumulation. Swap the order: scalars first (top), then
             * structs (deepest). Also scalars in reverse. */
        }

        /* Allocation order derived from studying timer_start in ref:
         *   1. Params (closest to IX, first to be placed)
         *   2. Scalars in DECLARATION ORDER (first-declared at top)
         *   3. Structs/unions at DEEPEST (last)
         * ix_offset increases (in magnitude) with each placement. */
        {
            int i;
            int offset = 0;
            func_has_locals = 0;
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'P') {
                    offset += locals[i].size;
                    locals[i].ix_offset = -offset;
                    func_has_locals = 1;
                }
            }
            /* Scalars in declaration order (top-to-bottom of scalar region) */
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'A' &&
                    locals[i].type != 'S' && locals[i].type != 'U') {
                    VarUsage *vu = find_var_usage(locals[i].id);
                    if (vu && vu->count > 0) {
                        offset += locals[i].size;
                        locals[i].ix_offset = -offset;
                        func_has_locals = 1;
                    } else {
                        locals[i].ix_offset = 0;
                    }
                }
            }
            /* Structs/unions: deepest */
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'A' &&
                    (locals[i].type == 'S' || locals[i].type == 'U')) {
                    VarUsage *vu = find_var_usage(locals[i].id);
                    if (vu && vu->count > 0) {
                        offset += locals[i].size;
                        locals[i].ix_offset = -offset;
                        func_has_locals = 1;
                    } else {
                        locals[i].ix_offset = 0;
                    }
                }
            }
            func_frame_bytes = offset;
        }

        /* Try to allocate variables to registers */
        try_register_allocate();

        /* For frameless functions where register params are used after
         * function calls, pre-set spill flags so the body generator
         * knows to emit push (on first call) and pop (on next param ref) */
        if (!func_has_locals && func_frame_bytes == 0 && param_used_after_call) {
            int i;
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'P' && locals[i].reg == VK_HL)
                    hl_spilled = 1;  /* will trigger push on first call, pop on next ref */
                if (locals[i].prefix == 'P' && locals[i].reg == VK_DE)
                    de_spilled = 1;
            }
        }

        /* Replay body through code generator */
        body_start_replay(cc);
        parse_function_body(cc);
        body_stop_replay(cc);
    } else if (param_count > 0 && auto_count == 0) {
        /* Frameless function with register params:
         * Do lightweight body scan for spill analysis, then single-pass */
        body_capture(cc);
        body_count_usage(); /* sets param_used_after_call */
        ct_build_body(cc);
        ct_analyze_body();
        if (param_used_after_call) {
            int i;
            for (i = 0; i < local_count; i++) {
                if (locals[i].prefix == 'P' && locals[i].reg == VK_HL)
                    hl_spilled = 1;
                if (locals[i].prefix == 'P' && locals[i].reg == VK_DE)
                    de_spilled = 1;
            }
        }
        body_start_replay(cc);
        parse_function_body(cc);
        body_stop_replay(cc);
    } else {
        /* Simple functions: single-pass */
        parse_function_body(cc);
    }

    /* Emit string constants (before function code) */
    emit_string_consts(cc);

    /* Emit function header */
    out_set_cseg(cc);
    out_comment(cc, "{");

    /* Function label */
    io_write_str(cc, asmname);
    io_write_byte(cc, ':');
    io_write_newline(cc);

    /* Prologue: only if function has locals/params */
    if (func_has_locals && func_frame_bytes > 0) {
        out_instruction(cc, "push", "ix");
        out_instruction(cc, "ld", "ix,0");
        out_instruction(cc, "add", "ix,sp");

        /* Save first parameter via push hl (puts it at IX-2/-1)
         * This matches the CCC.ASM behavior: param is saved first,
         * then the remaining frame is allocated for locals */
        int param_push_bytes = 0;
        if (param_count > 0) {
            out_instruction(cc, "push", "hl");
            param_push_bytes = 2;  /* push hl = 2 bytes */
        }

        /* Allocate remaining stack space for auto locals */
        int alloc_bytes = func_frame_bytes - param_push_bytes;
        if (alloc_bytes > 0) {
            if (alloc_bytes <= 12) {
                int pushes = (alloc_bytes + 1) / 2;
                int i;
                for (i = 0; i < pushes; i++) {
                    out_instruction(cc, "push", "bc");
                }
            } else {
                char buf[32];
                snprintf(buf, sizeof(buf), "hl,%d", (65536 - alloc_bytes) & 0xFFFF);
                out_instruction(cc, "ld", buf);
                out_instruction(cc, "add", "hl,sp");
                out_instruction(cc, "ld", "sp,hl");
            }
        }
    }

    /* Remove trailing jp to epilogue (it falls through naturally) */
    if (func_epilogue_label >= 0 && instr_count > 0) {
        Instr *last = &instr_list[instr_count - 1];
        if (last->type == INSTR_INST) {
            char target[32];
            snprintf(target, sizeof(target), "jp\t@%d", func_epilogue_label);
            if (strcmp(last->text, target) == 0) {
                instr_count--; /* remove the jp */
            }
        }
    }

    /* Run peephole optimizer now (before ret-cc pass) so that patterns like
     * jp cc,@N / jp @M / @N: → jp !cc,@M are already resolved, making
     * the ret-cc pass more effective. */
    peephole_optimize();

    /* ret-cc peephole: for frameless functions, if the instruction list ends
     * with one or more @N: labels (the implicit ret will be emitted by
     * !func_has_return afterward), and no unconditional jp @N exists,
     * replace all "jp cc,@N" → "ret cc" and drop the trailing labels.
     * When the instruction before the tail label is an unconditional jp,
     * the function has no fallthrough path, so the implicit ret is suppressed.
     * Mirrors the optimization in CCC.ASM where frameless functions use ret cc
     * for early conditional returns instead of jumping to a shared epilogue. */
    if (!(func_has_locals && func_frame_bytes > 0) && !func_has_return) {
        /* Find the first trailing label at the end of instr_list */
        int tail_start = instr_count;
        while (tail_start > 0 &&
               instr_list[tail_start - 1].type == INSTR_LABEL)
            tail_start--;

        if (tail_start < instr_count) {
            int i, j;
            /* Try each trailing label */
            for (j = tail_start; j < instr_count; j++) {
                int tail_lnum = -1;
                if (sscanf(instr_list[j].text, "@%d", &tail_lnum) != 1)
                    continue;

                /* Check: no unconditional jp @N exists */
                char uncond[32];
                snprintf(uncond, sizeof(uncond), "jp\t@%d", tail_lnum);
                int has_uncond = 0;
                for (i = 0; i < tail_start; i++) {
                    if (instr_list[i].type == INSTR_INST &&
                        strcmp(instr_list[i].text, uncond) == 0) {
                        has_uncond = 1;
                        break;
                    }
                }
                if (has_uncond) continue;

                /* Replace all jp cc,@N with ret cc */
                char cond_jp[48], cond_str[16];
                int replaced = 0;
                for (i = 0; i < tail_start; i++) {
                    if (instr_list[i].type != INSTR_INST) continue;
                    if (sscanf(instr_list[i].text, "jp\t%15[^,],@%*d", cond_str) != 1)
                        continue;
                    snprintf(cond_jp, sizeof(cond_jp), "jp\t%s,@%d", cond_str, tail_lnum);
                    if (strcmp(instr_list[i].text, cond_jp) == 0) {
                        snprintf(instr_list[i].text, INSTR_BUF, "ret\t%s", cond_str);
                        replaced++;
                    }
                }
                if (replaced > 0) {
                    /* Remove this label from the tail (and all after it) */
                    instr_count = j; /* truncate at this label */
                    /* If the last remaining instruction is an unconditional jp,
                     * the function has no fallthrough — suppress the implicit ret */
                    if (instr_count > 0 &&
                        instr_list[instr_count - 1].type == INSTR_INST) {
                        char tmp[32];
                        if (sscanf(instr_list[instr_count-1].text,
                                   "jp\t@%31s", tmp) == 1) {
                            func_has_return = 1; /* suppress trailing ret */
                        }
                    }
                    break; /* only optimize one label per pass */
                }
            }
        }
    }

    /* Emit generated instructions */
    flush_instructions(cc);

    /* Epilogue label (shared target for early returns) */
    if (func_epilogue_label >= 0) {
        char lbuf[32];
        snprintf(lbuf, sizeof(lbuf), "@%d", func_epilogue_label);
        io_write_str(cc, lbuf);
        io_write_byte(cc, ':');
        io_write_newline(cc);
    }

    /* Epilogue + return */
    if (func_has_locals && func_frame_bytes > 0) {
        out_instruction(cc, "ld", "sp,ix");
        out_instruction(cc, "pop", "ix");
        out_instruction(cc, "ret", "");
    } else if (!func_has_return) {
        /* Only emit ret if no explicit return was generated */
        out_instruction(cc, "ret", "");
    }

    /* Emit function footer: original T7453 = 0Ah,";}",0Ah (trailing newline
     * creates blank line before next function/dseg, as A7441 in CCC.ASM) */
    out_comment(cc, "}");
    io_write_newline(cc);

    (void)ret_type;
}

/* ================================================================
 *  Main file processing loop
 *  Mirrors: A12BC dispatch loop in CCC.ASM
 * ================================================================ */
void gen_process_file(Cc2State *cc)
{
    /* Reset global state */
    name_count = 0;
    name_buf_pos = 0;
    decl_count = 0;
    str_const_count = 0;
    str_data_pos = 0;
    instr_count = 0;
    member_count = 0;

    /* Write ASM file header */
    io_write_str(cc, "\t.z80\n");
    io_write_str(cc, ";\tSOLID C Compiler ver 1.00 (pass 2)\n");
    io_write_str(cc, "\n");

    cc->cur_seg = -1;
    cc->local_label = 0;

    sym_init(cc);

    int ch;
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == 0x1A) break;
        if (ch == '\n') continue;

        switch (ch) {
            case 'S': parse_struct(cc, 0); break;
            case 'U': parse_struct(cc, 1); break;
            case 'V': parse_varsize(cc); break;
            case 'G': parse_global(cc); break;
            case 'X':
            case 'Y': parse_function(cc); break;
            case 'T': parse_typedef(cc); break;
            case '$': tmc_skip_line(cc); break;
            default:  tmc_skip_line(cc); break;
        }
    }

    /* Output declarations */
    io_write_newline(cc);

    {
        int i;
        for (i = 0; i < decl_count; i++) {
            if (decl_list[i].is_public)
                out_public(cc, decl_list[i].name);
            else
                out_extrn(cc, decl_list[i].name);
        }
    }

    out_end(cc);
}
