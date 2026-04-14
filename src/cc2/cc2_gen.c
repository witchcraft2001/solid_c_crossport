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

/* ================================================================
 *  TMC function body buffer (for two-pass optimization)
 * ================================================================ */
#define MAX_BODY_BUF 65536
static char body_buf[MAX_BODY_BUF];
static int  body_buf_len;

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
 *  Simple register allocator
 *
 *  For functions where all variables are ≤2 bytes, not address-taken,
 *  and can fit in 3 register pairs (BC, DE, HL).
 *
 *  Assigns registers based on usage priority.
 *  Modifies locals[].reg field.
 * ================================================================ */
static void try_register_allocate(void)
{
    int i;
    int auto_count = local_count - param_count;

    /* Already handled: trivial functions (0 autos, ≤1 param) */
    if (auto_count == 0 && param_count <= 1) return;

    /* Check all variables: must be ≤2 bytes, not address-taken, no structs */
    for (i = 0; i < local_count; i++) {
        if (locals[i].size > 2) return;
        if (locals[i].type == 'S' || locals[i].type == 'U') return;
        VarUsage *vu = find_var_usage(locals[i].id);
        if (vu && vu->addr_taken) return;
    }

    /* All vars are register candidates. Check count fits. */
    int used_count = 0;
    for (i = 0; i < local_count; i++) {
        VarUsage *vu = find_var_usage(locals[i].id);
        if (vu && vu->count > 0) used_count++;
    }

    /* For now, only handle cases where all used vars fit in registers */
    if (used_count > 3) return; /* BC, DE, HL = 3 pairs */

    /* Assign registers to parameters based on calling convention:
     * F1: 1st param in HL (char in A)
     * F2+: 1st param in HL, 2nd param in DE */
    {
        int pidx = 0;
        for (i = 0; i < local_count; i++) {
            if (locals[i].prefix == 'P') {
                VarUsage *vu = find_var_usage(locals[i].id);
                if (vu && vu->count > 0) {
                    if (pidx == 0) {
                        /* First param: HL (or A for char) */
                        locals[i].reg = (locals[i].type == 'C') ? VK_A : VK_HL;
                    } else if (pidx == 1) {
                        /* Second param: DE */
                        locals[i].reg = VK_DE;
                    } else {
                        return; /* 3+ used params: can't register-allocate */
                    }
                }
                pidx++;
            }
        }
    }
    /* Then assign autos to remaining registers */
    {
        int reg_order[] = { VK_DE, VK_BC, VK_HL };
        int reg_idx = 0;
        for (i = 0; i < local_count; i++) {
            if (locals[i].prefix == 'A' && locals[i].reg == VK_NONE) {
                VarUsage *vu = find_var_usage(locals[i].id);
                if (!vu || vu->count == 0) continue; /* unused var */
                /* Find next available register */
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
                if (!assigned) return; /* ran out of registers */
            }
        }
    }

    /* If all used vars are register-allocated, eliminate frame */
    /* All used vars are register-allocated */
    func_has_locals = 0;
    func_frame_bytes = 0;
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
static void gen_inline_call(Cc2State *cc, const char *asmname, int call_type, int arg_count)
{
    int i;

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
        for (i = 0; i < pushes; i++) {
            emit_instr(cc, "pop", "bc");
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
    if (ch == '.' || ch == '\'' || ch == 'a' || ch == 'n' || ch == '"') {
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
            /* Immediate constant or type size: #C=1, #R=2, #N=2, #I=2, #S<n>=struct size */
            int val;
            if (tok[1] == 'S') {
                val = lookup_struct_size(cc, atoi(tok + 2));
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
            /* Dereference/address marker.
             * For VK_ADDR_HL: HL already holds the computed address.
             * For other kinds: mark as "address" (lvalue for assignment). */
            VVal *top = vtop();
            if (top) {
                if (top->kind == VK_ADDR_HL) {
                    /* Already an address in HL — keep as VK_ADDR_HL.
                     * The consumer (:C, :N, pR, etc.) will handle load/store. */
                } else {
                    top->is_addr = 1;
                }
            }
            break;
        }
        case ':': {
            /* Assignment: :C, :N, :I
             * Handles VK_ADDR_HL (indirect memory access) for both src and dest. */
            char type = tok[1];
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
                        gen_load_a(cc, value);
                        emit_instr(cc, "ld", "(hl),a");
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
                        gen_load_de(cc, value);
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

                    if (b->kind == VK_IMM && b->value == 1) {
                        /* Element size 1: just use index as-is */
                        gen_load_hl(cc, a);
                    } else {
                        /* Multiply index by element size */
                        gen_load_hl(cc, a);
                        emit_instr(cc, "push", "hl");
                        gen_load_hl(cc, b);
                        emit_instr(cc, "pop", "de");
                        emit_instr(cc, "ex", "de,hl");
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
                        char buf[128];
                        snprintf(buf, sizeof(buf), "de,%s", rbase_sym);
                        emit_instr(cc, "ld", buf);
                        emit_instr(cc, "add", "hl,de");
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
            if (func_is_simple) {
                /* Simple function: use symbolic evaluator */
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
            else if (tok[1] == 'R' || tok[1] == 'N' || tok[1] == 'I') val = 2;
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

    /* Two-pass optimization for non-trivial functions:
     * Pass 1: capture body TMC, count variable usage
     * Pass 2: replay body with register allocation decisions */
    if (func_has_locals && func_frame_bytes > 0) {
        /* Capture body into buffer */
        body_capture(cc);

        /* Count variable usage */
        body_count_usage();

        /* Try to allocate variables to registers */
        try_register_allocate();

        /* Replay body through code generator */
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
