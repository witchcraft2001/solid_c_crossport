/*
 * cc2_gen.c — Code generation from TMC to Z80 ASM
 *
 * Mirrors the core of CCC.ASM: TMC parsing, expression evaluation,
 * code generation, and ASM output.
 *
 * Processes TMC intermediate code and generates Z80 assembly.
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

/* ================================================================
 *  String constant storage
 * ================================================================ */
#define MAX_STRINGS 256
#define MAX_STR_DATA 65536

typedef struct {
    int  label;             /* label number (63999, 63998, ...) */
    int  data_offset;       /* offset into str_data[] */
    int  data_len;          /* number of byte values */
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

/* TMC body buffer will be added when two-pass optimization is implemented */

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
        out_set_cseg(cc);
        out_str_label(cc, str_consts[i].label);
        cc->db_count = 0;
        int off = str_consts[i].data_offset;
        int len = str_consts[i].data_len;
        for (j = 0; j < len; j++) {
            out_db_byte(cc, str_data[off + j]);
        }
        out_db_finish(cc);
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

static void flush_instructions(Cc2State *cc)
{
    int i;
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
            ch = tmc_read_char(cc);
            ExprVal *top = eval_pop();
            if (top && nargs < MAX_ARGS) {
                args[nargs] = *top;
                args[nargs].needs_push = 1;
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
        snprintf(buf, sizeof(buf), "hl,(%s)", v->sym);
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
        snprintf(buf, sizeof(buf), "a,%d", v->value & 0xFF);
        emit_instr(cc, "ld", buf);
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
        snprintf(buf, sizeof(buf), "de,(%s)", v->sym);
        /* Z80 doesn't have ld de,(nn) directly, use ld hl,(nn) then ex */
        emit_instr(cc, "ld", buf); /* assembler pseudo-op or we need different approach */
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
    default:
        break;
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
    if (ch == '.' || ch == '\'' || ch == 'a' || ch == 'n') {
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
        /* Address-of for arrays/pointers */
        VVal *top = vtop();
        if (top) top->is_addr = 1;
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
                if (lv->reg != VK_NONE) {
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
        case '#': {
            /* Immediate constant or #S<n> or #C */
            int val;
            if (tok[1] == 'S') {
                val = lookup_struct_size(cc, atoi(tok + 2));
            } else if (tok[1] == 'C') {
                val = 1; /* sizeof(char) */
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
            /* Address-of */
            VVal *top = vtop();
            if (top) top->is_addr = 1;
            break;
        }
        case ':': {
            /* Assignment: :C, :N, :I */
            char type = tok[1];
            VVal *value = vpop();
            VVal *dest = vpop();
            if (value && dest) {
                if (type == 'C') {
                    gen_load_a(cc, value);
                    gen_store_a(cc, dest);
                    vpush(VK_A, NULL, 0, 'C');
                } else {
                    gen_load_hl(cc, value);
                    gen_store_hl(cc, dest);
                    vpush(VK_HL, NULL, 0, type);
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
                    if (b->kind == VK_IMM && a->kind == VK_HL) {
                        /* HL already has a, just add immediate */
                        char buf[32];
                        snprintf(buf, sizeof(buf), "de,%d", b->value & 0xFFFF);
                        emit_instr(cc, "ld", buf);
                        emit_instr(cc, "add", "hl,de");
                    } else {
                        gen_load_hl(cc, a);
                        emit_instr(cc, "push", "hl");
                        gen_load_hl(cc, b);
                        emit_instr(cc, "pop", "de");
                        emit_instr(cc, "ex", "de,hl");
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
                if (type == 'C') {
                    gen_load_a(cc, b);
                    emit_instr(cc, "ld", "e,a");
                    gen_load_a(cc, a);
                    emit_instr(cc, "sub", "e");
                    vpush(VK_A, NULL, 0, 'C');
                } else {
                    gen_load_hl(cc, b);
                    emit_instr(cc, "ex", "de,hl");
                    gen_load_hl(cc, a);
                    emit_instr(cc, "or", "a");
                    emit_instr(cc, "sbc", "hl,de");
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
                if (type == 'R') {
                    /* Array element size multiply */
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
                    gen_load_hl(cc, a);
                    emit_instr(cc, "push", "hl");
                    gen_load_hl(cc, b);
                    emit_instr(cc, "pop", "de");
                    emit_instr(cc, "ex", "de,hl");
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
                gen_load_hl(cc, b);
                emit_instr(cc, "ex", "de,hl");
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
                gen_load_hl(cc, b);
                emit_instr(cc, "ex", "de,hl");
                gen_load_hl(cc, a);
                if (type == 'I') {
                    decl_add("?dvihd", 0);
                    emit_instr(cc, "call", "?dvihd");
                } else {
                    decl_add("?dvnhd", 0);
                    emit_instr(cc, "call", "?dvnhd");
                }
                /* Remainder is in DE after division */
                emit_instr(cc, "ex", "de,hl");
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
                if (type == 'C') {
                    gen_load_a(cc, b);
                    emit_instr(cc, "ld", "e,a");
                    gen_load_a(cc, a);
                    emit_instr(cc, "cp", "e");
                } else {
                    gen_load_hl(cc, b);
                    emit_instr(cc, "ex", "de,hl");
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
                gen_load_hl(cc, b);
                emit_instr(cc, "ex", "de,hl");
                gen_load_hl(cc, a);
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
                gen_load_hl(cc, b);
                emit_instr(cc, "ex", "de,hl");
                gen_load_hl(cc, a);
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
        case 'R': {
            /* Array element: R<type> pops index and base */
            /* RN/RI/RC → pop index, pop base global, push combined */
            VVal *idx = vpop();
            VVal *base = vpop();
            if (base && idx) {
                /* base should be global, idx is the index value */
                /* Result: base_addr + idx (will be multiplied by *R later) */
                gen_load_hl(cc, idx);
                if (base->kind == VK_GLOBAL) {
                    char buf[128];
                    snprintf(buf, sizeof(buf), "de,%s", base->sym);
                    /* For array access, we need: HL = base + index */
                    /* But multiply by element size happens with *R next */
                    /* For now, just push both for *R to handle */
                    vpush(VK_HL, base->sym, 0, tok[1]);
                } else {
                    vpush(VK_HL, NULL, 0, tok[1]);
                }
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
                    if (top->kind != VK_A) {
                        gen_load_hl(cc, top); vsp--;
                        emit_instr(cc, "ld", "a,l");
                        vpush(VK_A, NULL, 0, 'C');
                    } else { top->type = 'C'; }
                } else if ((from == 'C' && to == 'N') ||
                           (from == 'C' && to == 'I')) {
                    if (top->kind == VK_A) {
                        vsp--;
                        emit_instr(cc, "ld", "l,a");
                        emit_instr(cc, "ld", "h,0");
                        vpush(VK_HL, NULL, 0, to);
                    } else if (top->kind != VK_HL) {
                        gen_load_a(cc, top); vsp--;
                        emit_instr(cc, "ld", "l,a");
                        emit_instr(cc, "ld", "h,0");
                        vpush(VK_HL, NULL, 0, to);
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
                }
            }
            break;
        }
        case 'X': {
            /* Function call within expression */
            char fname[128];
            strncpy(fname, tok + 1, sizeof(fname) - 1);
            fname[sizeof(fname) - 1] = '\0';
            /* Use parse_func_call for the rest of the line */
            /* But we need to handle the result */
            parse_func_call(cc, fname);
            /* Result is in HL (for int) or A (for char) */
            vpush(VK_HL, NULL, 0, 'N');
            break; /* parse_func_call already consumed the line */
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
            /* This is handled by parse_func_call */
            break;
        }
        case 'c': {
            /* Return type for function call */
            break;
        }
        case 'F': case 'U': {
            /* Call type - handled by parse_func_call */
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
                if (lv->reg != VK_NONE)
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
        case '#': {
            int val;
            if (tok[1] == 'S') val = lookup_struct_size(cc, atoi(tok + 2));
            else if (tok[1] == 'C') val = 1;
            else val = atoi(tok + 1);
            vpush(VK_IMM, NULL, val, 'N');
            break;
        }
        case '<': case '>': case '=': case '!':
        case '[': case ']': {
            cmp_op = first;
            cmp_type = tok[1];
            VVal *b = vpop();
            VVal *a = vpop();
            if (a && b) {
                if (cmp_type == 'C') {
                    gen_load_a(cc, b);
                    emit_instr(cc, "ld", "e,a");
                    gen_load_a(cc, a);
                    emit_instr(cc, "cp", "e");
                } else {
                    gen_load_hl(cc, b);
                    emit_instr(cc, "ex", "de,hl");
                    gen_load_hl(cc, a);
                    decl_add("?cpshd", 0);
                    emit_instr(cc, "call", "?cpshd");
                }
            }
            break;
        }
        /* Handle type conversions and other ops in jump expressions */
        case 'N': case 'C': case 'I': {
            char from = tok[0], to = tok[1];
            VVal *top = vtop();
            if (top) {
                if (from == 'N' && to == 'I') top->type = 'I';
                else if (from == 'I' && to == 'N') top->type = 'N';
                else if (from == 'C' && to == 'I') {
                    gen_load_a(cc, top); vsp--;
                    emit_instr(cc, "ld", "l,a");
                    emit_instr(cc, "ld", "h,0");
                    vpush(VK_HL, NULL, 0, 'I');
                } else if (from == 'N' && to == 'C') {
                    gen_load_hl(cc, top); vsp--;
                    emit_instr(cc, "ld", "a,l");
                    vpush(VK_A, NULL, 0, 'C');
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
                    gen_load_hl(cc, a);
                    emit_instr(cc, "push", "hl");
                    gen_load_hl(cc, b);
                    emit_instr(cc, "pop", "de");
                    emit_instr(cc, "ex", "de,hl");
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
            VVal *top = vtop();
            if (top) top->is_addr = 1;
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
                    gen_load_hl(cc, b);
                    emit_instr(cc, "ex", "de,hl");
                    gen_load_hl(cc, a);
                    if (first == '+') emit_instr(cc, "add", "hl,de");
                    else { emit_instr(cc, "or", "a"); emit_instr(cc, "sbc", "hl,de"); }
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
    int is_simple = body_is_simple(cc);

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

            if (ch == 'X' && is_simple) {
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
                /* Conditional jump: j\tL<n>\t<expr>\tn */
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
                /* Function call within complex body */
                char func_name[128];
                tmc_read_token(cc, func_name, sizeof(func_name));
                /* For now, use simple func call parser */
                parse_func_call(cc, func_name);
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
 *  Parse T (typedef)
 * ================================================================ */
static void parse_typedef(Cc2State *cc)
{
    tmc_skip_line(cc);
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
        /* Auto locals get negative IX offsets */
        for (i = 0; i < local_count; i++) {
            if (locals[i].prefix == 'A') {
                offset += locals[i].size;
                locals[i].ix_offset = -offset;
                func_has_locals = 1;
            }
        }
        func_frame_bytes = offset;
        /* Parameters for F1 are in HL, saved to stack */
        for (i = 0; i < local_count; i++) {
            if (locals[i].prefix == 'P') {
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

    /* Parse function body - collects string constants and instructions */
    parse_function_body(cc);

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

        /* Allocate stack space for locals */
        if (func_frame_bytes <= 12) {
            /* Small frames: use push bc (2 bytes per push) */
            int pushes = (func_frame_bytes + 1) / 2;
            int i;
            for (i = 0; i < pushes; i++) {
                out_instruction(cc, "push", "bc");
            }
        } else {
            /* Large frames: use ld hl,65536-N / add hl,sp / ld sp,hl */
            char buf[32];
            snprintf(buf, sizeof(buf), "hl,%d", (65536 - func_frame_bytes) & 0xFFFF);
            out_instruction(cc, "ld", buf);
            out_instruction(cc, "add", "hl,sp");
            out_instruction(cc, "ld", "sp,hl");
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

    /* Emit function footer */
    out_comment(cc, "}");


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
