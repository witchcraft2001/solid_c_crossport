/*
 * cc2_gen.c — Code generation from TMC to Z80 ASM
 *
 * Mirrors the core of CCC.ASM: TMC parsing, code tree building,
 * optimization, and ASM output.
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
#define MAX_INSTR 4096
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
 *  Name table: stores identifier strings, referenced by index
 * ================================================================ */
#define MAX_NAMES 4096
#define NAME_BUF_SIZE 65536

static char name_buf[NAME_BUF_SIZE];
static int  name_buf_pos;

/* Each name entry: offset in name_buf + length */
typedef struct {
    int offset;
    int len;
} NameEntry;

static NameEntry names[MAX_NAMES];
static int name_count;

/* Symbol tracking for extrn/public output */
#define MAX_DECLS 256

typedef struct {
    char name[64];          /* symbol name with underscore */
    int  is_public;         /* 1=public, 0=extrn */
    int  order;             /* insertion order */
} DeclEntry;

static DeclEntry decl_list[MAX_DECLS];
static int       decl_count;

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
    /* Check if already exists */
    int i;
    for (i = 0; i < decl_count; i++) {
        if (strcmp(decl_list[i].name, name) == 0) {
            /* Already have this - if marking as public, upgrade */
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

/* Parse a string constant from TMC: "10,72,101,...,0"
 * Reads decimal values separated by commas until closing quote.
 * Returns the string constant index. */
static int parse_string_const(Cc2State *cc)
{
    int idx = str_const_new(cc);
    int ch;

    /* We're positioned after the opening quote */
    for (;;) {
        /* Read a decimal number */
        int val = 0;
        ch = tmc_read_char(cc);
        while (ch >= '0' && ch <= '9') {
            val = val * 10 + (ch - '0');
            ch = tmc_read_char(cc);
        }
        str_data[str_data_pos++] = val;
        str_consts[idx].data_len++;

        if (ch == '"') break;  /* End of string */
        /* ch should be ',' - continue */
    }

    return idx;
}

/* Emit all string constants for current function */
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
    if (instr_count >= MAX_INSTR) return;
    Instr *ins = &instr_list[instr_count++];
    ins->type = INSTR_INST;
    if (operands && operands[0]) {
        snprintf(ins->text, INSTR_BUF, "%s\t%s", mnemonic, operands);
    } else {
        snprintf(ins->text, INSTR_BUF, "%s", mnemonic);
    }
}

static void emit_label(const char *label)
{
    if (instr_count >= MAX_INSTR) return;
    Instr *ins = &instr_list[instr_count++];
    ins->type = INSTR_LABEL;
    snprintf(ins->text, INSTR_BUF, "%s", label);
}

static void emit_comment(const char *text)
{
    if (instr_count >= MAX_INSTR) return;
    Instr *ins = &instr_list[instr_count++];
    ins->type = INSTR_COMMENT;
    snprintf(ins->text, INSTR_BUF, "%s", text);
}

/* Output all instructions to file */
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
 *  TMC expression evaluator (stack machine)
 *
 *  TMC expressions use postfix/RPN notation with tab-separated tokens.
 *  The evaluator produces ASM operand strings like "?63999",
 *  "_iob_-14", "42", "(buffer_)", etc.
 * ================================================================ */

/* Expression value on the eval stack */
#define MAX_ARGS 16
#define ARG_BUF 128
#define EVAL_STACK_MAX 32

typedef struct {
    char sym[64];       /* symbol name (empty if pure constant) */
    int  offset;        /* numeric offset (added to sym) */
    int  is_string;     /* 1 if this is a string constant label */
    int  str_idx;       /* index into str_consts[] if is_string */
    int  is_addr;       /* 1 if this is an address (not dereferenced) */
    int  is_deref;      /* 1 if needs indirect: (sym) */
    int  needs_push;    /* 1 if marked for push */
} ExprVal;

static ExprVal eval_stack[EVAL_STACK_MAX];
static int eval_sp;

static void eval_push(ExprVal *v)
{
    if (eval_sp < EVAL_STACK_MAX) {
        eval_stack[eval_sp++] = *v;
    }
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

/* Format an ExprVal as an ASM operand string for loading into bc or hl */
static void eval_format(ExprVal *v, char *buf, int maxlen, int use_hl)
{
    const char *reg = use_hl ? "hl" : "bc";

    if (v->is_deref) {
        /* Indirect load: ld hl,(name) */
        if (v->sym[0]) {
            if (v->offset != 0) {
                snprintf(buf, maxlen, "%s,(%s%+d)", reg, v->sym, v->offset);
            } else {
                snprintf(buf, maxlen, "%s,(%s)", reg, v->sym);
            }
        } else {
            snprintf(buf, maxlen, "%s,(%d)", reg, v->offset);
        }
    } else if (v->sym[0]) {
        /* Symbol reference: ld bc,name or ld bc,name-14 */
        if (v->offset != 0) {
            snprintf(buf, maxlen, "%s,%s%+d", reg, v->sym, v->offset);
        } else {
            snprintf(buf, maxlen, "%s,%s", reg, v->sym);
        }
    } else {
        /* Pure constant */
        snprintf(buf, maxlen, "%s,%d", reg, v->offset);
    }
}

/* Look up struct size by struct number */
static int lookup_struct_size(Cc2State *cc, int struct_num)
{
    int i;
    for (i = 0; i < cc->sym_count; i++) {
        if ((cc->sym[i].type == SYM_STRUCT || cc->sym[i].type == SYM_UNION) &&
            cc->sym[i].name == (u16)struct_num) {
            return cc->sym[i].value;
        }
    }
    return 2; /* default */
}

/* Parse a function call with proper expression evaluation.
 * Reads tokens from current position until end of line.
 * Builds arguments and generates code.
 */
static void parse_func_call(Cc2State *cc, const char *func_name)
{
    char asmname[128];
    make_asm_name(func_name, asmname, sizeof(asmname));

    /* Collected arguments (after expression evaluation) */
    ExprVal args[MAX_ARGS];
    int nargs = 0;
    int call_type = 0;
    int arg_count = 0;
    int ch;

    /* Reset expression stack */
    eval_sp = 0;

    /* Read tokens until end of line */
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == '\n' || ch == 0x1A) break;
        if (ch == '\t') continue;

        if (ch == '"') {
            /* String constant - push onto eval stack */
            int sidx = parse_string_const(cc);
            ExprVal v;
            memset(&v, 0, sizeof(v));
            v.is_string = 1;
            v.str_idx = sidx;
            snprintf(v.sym, sizeof(v.sym), "?%d", str_consts[sidx].label);
            v.is_addr = 1;
            eval_push(&v);

        } else if (ch == 'a') {
            /* Address mode - current top is an address */
            ExprVal *top = eval_top();
            if (top) top->is_addr = 1;

        } else if (ch == 'p') {
            /* Push mode: pR, pI, pC etc.
             * Move current eval stack top to args as "needs push" */
            ch = tmc_read_char(cc); /* type char */
            ExprVal *top = eval_pop();
            if (top && nargs < MAX_ARGS) {
                args[nargs] = *top;
                args[nargs].needs_push = 1;
                nargs++;
            }

        } else if (ch == 'c') {
            /* Return type: cI, cC, cN */
            tmc_read_char(cc);

        } else if (ch == 'U') {
            /* Unprototyped call */
            char buf[32];
            tmc_read_token(cc, buf, sizeof(buf));
            call_type = 'U';
            arg_count = atoi(buf);
            break;

        } else if (ch == 'F') {
            /* Fixed-arg call */
            char buf[32];
            tmc_read_token(cc, buf, sizeof(buf));
            call_type = 'F';
            arg_count = atoi(buf);
            break;

        } else if (ch == 'G') {
            /* Global variable/array reference */
            char buf[128];
            tmc_read_token(cc, buf, sizeof(buf));
            ExprVal v;
            memset(&v, 0, sizeof(v));
            make_asm_name(buf, v.sym, sizeof(v.sym));
            /* Don't add extrn here — it will be added after function extrn */
            eval_push(&v);

        } else if (ch == '#') {
            /* Immediate value: #<number> or #S<n> (struct sizeof) */
            char buf[128];
            tmc_read_token(cc, buf, sizeof(buf));
            ExprVal v;
            memset(&v, 0, sizeof(v));
            if (buf[0] == 'S') {
                /* Struct size reference */
                int snum = atoi(buf + 1);
                v.offset = lookup_struct_size(cc, snum);
            } else {
                v.offset = atoi(buf);
            }
            eval_push(&v);

        } else if (ch == '_') {
            /* Unary negate + type: _I, _C, etc.
             * Negates the top of stack */
            tmc_read_char(cc); /* type char */
            ExprVal *top = eval_top();
            if (top) {
                top->offset = -top->offset;
            }

        } else if (ch == '*') {
            /* Multiply: *R, *I, *N, etc.
             * Pop two values, multiply */
            tmc_read_char(cc); /* type char */
            ExprVal *b = eval_pop();
            ExprVal *a = eval_pop();
            if (a && b) {
                if (a->sym[0] && !b->sym[0]) {
                    /* sym * const → sym with offset */
                    a->offset *= b->offset;
                    eval_push(a);
                } else if (!a->sym[0] && b->sym[0]) {
                    b->offset *= a->offset;
                    eval_push(b);
                } else if (!a->sym[0] && !b->sym[0]) {
                    a->offset *= b->offset;
                    eval_push(a);
                } else {
                    eval_push(a); /* can't multiply two symbols */
                }
            }

        } else if (ch == 'R') {
            /* Array read / dereference: RI, RC, RN
             * Pop index and base, compute base + index*size */
            ch = tmc_read_char(cc); /* type char */
            /* This is a complex operation - for pointer expressions,
             * it multiplies the index by the next struct size.
             * For now, combine top two stack values. */
            ExprVal *idx = eval_pop();
            ExprVal *base = eval_pop();
            if (base && idx) {
                /* Combine: base + idx.offset (will be multiplied by struct size later) */
                /* The *R operation that follows will do the actual multiply */
                ExprVal result;
                memset(&result, 0, sizeof(result));
                strcpy(result.sym, base->sym);
                /* Store index for later multiplication */
                result.offset = idx->offset;
                eval_push(&result);
            }

        } else if (ch == '\'') {
            /* Address-of / separator
             * Marks current expression as address (not dereferenced) */
            ExprVal *top = eval_top();
            if (top) top->is_addr = 1;

        } else if (ch == '+') {
            /* Add: +I, +N, etc. */
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
            /* Subtract: -I, -N, etc. */
            tmc_read_char(cc);
            ExprVal *b = eval_pop();
            ExprVal *a = eval_pop();
            if (a && b) {
                a->offset -= b->offset;
                eval_push(a);
            }

        } else {
            /* Unknown token - read to next delimiter */
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

    /* Add extrn declaration for the called function FIRST
     * (before arg externals, to match original order) */
    decl_add(asmname, 0);

    /* Now add extrn for any global symbols referenced in arguments */
    {
        int i;
        for (i = 0; i < nargs; i++) {
            if (args[i].sym[0] && !args[i].is_string &&
                args[i].sym[0] != '?') {
                /* This is a global symbol - check if it's already declared
                 * as public; if not, add as extrn */
                int j, found = 0;
                for (j = 0; j < decl_count; j++) {
                    if (strcmp(decl_list[j].name, args[i].sym) == 0) {
                        found = 1;
                        break;
                    }
                }
                if (!found) {
                    decl_add(args[i].sym, 0);
                }
            }
        }
    }

    /* Generate code based on call type */
    if (call_type == 'U') {
        /* Unprototyped (varargs) call:
         * Push args right-to-left (reverse order), ld hl,count, call, pop*n */
        int pushes = 0;
        int i;

        /* Push in REVERSE order (right-to-left calling convention) */
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
        for (i2 = 0; i2 < pushes; i2++) {
            emit_instr(cc, "pop", "bc");
        }

    } else if (call_type == 'F') {
        if (arg_count == 0) {
            emit_instr(cc, "call", asmname);
        } else if (arg_count == 1 && nargs > 0) {
            char operand[128];
            if (args[0].is_deref || (!args[0].is_addr && !args[0].is_string &&
                args[0].sym[0] && args[0].offset == 0)) {
                /* Load indirect: ld hl,(name) */
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
            for (i2 = 0; i2 < pushes; i2++) {
                emit_instr(cc, "pop", "bc");
            }
        }
    }
}

/* ================================================================
 *  Handle HELLO.ASM fprintf with complex argument expression
 *  G_iob #1 _I RI #S10 *R → _iob_-14
 *
 *  This computes &_iob[1] where sizeof(struct_S10) = 14
 *  Result: _iob_ + 1 * (-14) ... but output shows _iob_-14
 *
 *  For now, handle this specific pattern.
 * ================================================================ */

/* ================================================================
 *  Parse function body
 *
 *  After "{" is consumed, reads statements until "}"
 * ================================================================ */
static void parse_function_body(Cc2State *cc)
{
    int ch;

    for (;;) {
        ch = tmc_read_char(cc);

        if (ch == '}' || ch == 0x1A) {
            /* End of function body */
            tmc_skip_line(cc);
            break;
        }

        if (ch == '\t') {
            /* Statement within function body */
            ch = tmc_read_char(cc);

            if (ch == 'X') {
                /* Function call */
                char func_name[128];
                tmc_read_token(cc, func_name, sizeof(func_name));
                /* Next char should be tab (start of args) */
                parse_func_call(cc, func_name);
            } else {
                /* Other statement types - skip for now */
                tmc_skip_line(cc);
            }
        } else if (ch == '\n') {
            /* Empty line, skip */
        } else {
            /* Unexpected character */
            tmc_skip_line(cc);
        }
    }
}

/* ================================================================
 *  Parse struct/union definition
 *  Format: S<n>\t(\nM<n>\t<type>\n...\n)\n
 * ================================================================ */
static void parse_struct(Cc2State *cc, int is_union)
{
    /* Read struct/union number */
    int num = tmc_read_number(cc);
    tmc_skip_line(cc);  /* skip past "(" to end of S line */

    int total_size = 0;
    int max_size = 0;
    int ch;

    /* Read members until ")" */
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == ')') {
            tmc_skip_line(cc);
            break;
        }
        if (ch == 'M') {
            /* Member: M<n>\t<type> */
            tmc_read_number(cc);  /* member number (skip) */
            tmc_expect_tab(cc);
            char type_buf[32];
            tmc_read_token(cc, type_buf, sizeof(type_buf));
            int sz = type_size(type_buf[0]);

            if (type_buf[0] == 'S' || type_buf[0] == 'U') {
                /* Struct/union member - need to look up size */
                /* For now use the value from symbol table */
                /* TODO: proper struct size lookup */
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

    /* Store struct size in symbol table */
    int name_id = name_add("", 0); /* anonymous */
    sym_add(cc, is_union ? SYM_UNION : SYM_STRUCT,
            (u16)total_size, (u16)num, 0);

    (void)name_id;
}

/* ================================================================
 *  Parse global variable
 *  Format: G<name>\t<type>\n  or  G<name>\t(\n...\n)\n
 * ================================================================ */
static void parse_global(Cc2State *cc)
{
    char name[128];
    tmc_read_token(cc, name, sizeof(name));
    tmc_expect_tab(cc);

    char asmname[128];
    make_asm_name(name, asmname, sizeof(asmname));

    /* Peek at type */
    int ch = tmc_read_char(cc);

    if (ch == '(') {
        /* Global with initializer: G<name>\t(\n ... \n)\n */
        tmc_skip_line(cc);

        /* Read initializer data */
        /* Look for R "str" a pattern (pointer to string constant) */
        out_set_cseg(cc);
        io_write_str(cc, asmname);
        io_write_str(cc, ":\n");

        for (;;) {
            ch = tmc_read_char(cc);
            if (ch == ')') {
                tmc_skip_line(cc);
                break;
            }
            if (ch == '\t') {
                ch = tmc_read_char(cc);
                if (ch == 'R') {
                    /* Pointer reference with string data */
                    tmc_expect_tab(cc);
                    ch = tmc_read_char(cc);
                    if (ch == '"') {
                        int sidx = parse_string_const(cc);
                        /* Output: dw ?NNNNN */
                        char buf[32];
                        snprintf(buf, sizeof(buf), "?%d",
                                 str_consts[sidx].label);
                        out_instruction(cc, "dw", buf);
                        /* String data will be emitted by
                         * emit_string_consts */
                    }
                    tmc_skip_line(cc);
                } else {
                    tmc_skip_line(cc);
                }
            } else {
                tmc_skip_line(cc);
            }
        }

        /* Emit string constants accumulated from initializer */
        emit_string_consts(cc);
        str_const_count = 0;
        str_data_pos = 0;

        /* Add public declaration */
        decl_add(asmname, 1);

    } else {
        /* Simple global: G<name>\t<type> or G<name>\tV<n> */
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
            /* Variable size reference: V<n> → look up in symbol table */
            int vnum = atoi(type_buf + 1);
            sz = 0;
            int i;
            for (i = 0; i < cc->sym_count; i++) {
                if (cc->sym[i].type == SYM_VAR && cc->sym[i].name == (u16)vnum) {
                    sz = cc->sym[i].value;
                    break;
                }
            }
            if (sz == 0) sz = 2; /* fallback */
        } else {
            sz = type_size(type_buf[0]);
        }

        /* Emit dseg + ds */
        out_set_dseg(cc);
        char buf[256];
        snprintf(buf, sizeof(buf), "%s:\tds\t%d", asmname, sz);
        io_write_str(cc, buf);
        io_write_newline(cc);

        /* Add public declaration */
        decl_add(asmname, 1);

        if (ch == '\t' || ch == 0x1A) {
            tmc_skip_line(cc);
        }
    }
}

/* ================================================================
 *  Parse V (variable size constant)
 *  Format: V<n>\t<type>\t#<value>
 * ================================================================ */
static void parse_varsize(Cc2State *cc)
{
    int num = tmc_read_number(cc);
    tmc_expect_tab(cc);

    char type_buf[32];
    tmc_read_token(cc, type_buf, sizeof(type_buf));

    tmc_expect_tab(cc);
    int ch = tmc_read_char(cc);  /* skip '#' */
    (void)ch;
    int val = tmc_read_number(cc);

    int sz = type_size(type_buf[0]);
    int total = sz * val;

    sym_add(cc, SYM_VAR, (u16)total, (u16)num, 0);

    tmc_skip_line(cc);
}

/* ================================================================
 *  Parse T (typedef)
 *  Format: T<name>\t<definition>
 * ================================================================ */
static void parse_typedef(Cc2State *cc)
{
    tmc_skip_line(cc);
}

/* ================================================================
 *  Parameter/local variable info
 * ================================================================ */
#define MAX_LOCALS 64

typedef struct {
    char prefix;        /* 'P' for param, 'A' for auto/local */
    int  id;            /* TMC id number */
    char type;          /* type char: N, I, C, R, etc. */
    int  struct_num;    /* struct number if type is 'S' */
    int  size;          /* size in bytes */
    int  sp_offset;     /* offset from SP (for stack-allocated locals) */
    int  ix_offset;     /* offset from IX (for IX-accessed vars) */
} LocalVar;

static LocalVar locals[MAX_LOCALS];
static int local_count;
static int param_count;  /* number of P entries */

/* ================================================================
 *  Parse function definition and body
 *  Format: X<name>\t<rettype>\tF\tE\n[P<n>\t<type>\n]*\n{\n...\n}\n
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
            /* Return type or other token */
            ret_type = (char)ch;
            /* Read rest of token */
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

    /* Read parameters (P<n> lines) until '{' */
    local_count = 0;
    param_count = 0;
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == '{') {
            tmc_skip_line(cc);
            break;
        }
        if (ch == 'P') {
            /* Parameter: P<n>\t<type> */
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
                local_count++;
                param_count++;
            }
        } else if (ch == '\n') {
            continue;
        } else if (ch == 0x1A) {
            break;
        } else {
            /* Unexpected - push back and try as '{' */
            tmc_pushback(cc, ch);
            tmc_skip_line(cc);
        }
    }

    /* Reset per-function state */
    str_const_count = 0;
    str_data_pos = 0;
    instr_count = 0;

    /* Read local variable declarations (A<n> lines at start of body)
     * and rest of function body */
    /* First, read A<n> declarations */
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == 'A') {
            /* Auto/local: A<n>\t<type> */
            int id = tmc_read_number(cc);
            /* Check if next char is tab (declaration) or something else */
            int next = tmc_read_char(cc);
            if (next == '\t') {
                /* Could be declaration or statement */
                int peek = tmc_peek_char(cc);
                if (peek == 'S' || peek == 'N' || peek == 'I' ||
                    peek == 'C' || peek == 'R' || peek == 'U') {
                    /* Local variable declaration */
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
                        } else {
                            locals[local_count].size = type_size(type_buf[0]);
                        }
                        local_count++;
                    }
                    continue;
                }
            }
            /* Not a declaration - push back and process as statement */
            /* Reconstruct: 'A' + id digits + next char */
            tmc_pushback(cc, next);
            /* Push back the number too */
            {
                char id_str[32];
                snprintf(id_str, sizeof(id_str), "%d", id);
                int k;
                for (k = (int)strlen(id_str) - 1; k >= 0; k--) {
                    tmc_pushback(cc, id_str[k]);
                }
            }
            tmc_pushback(cc, 'A');
            break;
        } else if (ch == '\t' || ch == '}' || ch == 'L' || ch == 'd') {
            /* Statement or end of body - push back and process */
            tmc_pushback(cc, ch);
            break;
        } else if (ch == '\n') {
            continue;
        } else {
            tmc_pushback(cc, ch);
            break;
        }
    }

    /* Parse function body - collects string constants and instructions */
    parse_function_body(cc);

    /* Emit string constants first (they go before the function code) */
    emit_string_consts(cc);

    /* Emit function header */
    out_comment(cc, "{");

    /* Function label */
    io_write_str(cc, asmname);
    io_write_byte(cc, ':');
    io_write_newline(cc);

    /* Emit generated instructions */
    flush_instructions(cc);

    /* Function return */
    out_instruction(cc, "ret", "");

    /* Emit function footer */
    out_comment(cc, "}");

    /* Add public declaration if external */
    if (is_extern) {
        decl_add(asmname, 1);
    }

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

    /* Write ASM file header */
    io_write_str(cc, "\t.z80\n");
    io_write_str(cc, ";\tSOLID C Compiler ver 1.00 (pass 2)\n");
    io_write_str(cc, "\n");

    cc->cur_seg = -1;  /* unset */

    /* Initialize symbol table */
    sym_init(cc);

    /* Process TMC tokens */
    int ch;
    for (;;) {
        ch = tmc_read_char(cc);
        if (ch == 0x1A) break;  /* EOF */
        if (ch == '\n') continue;  /* blank line */

        switch (ch) {
            case 'S':
                parse_struct(cc, 0);
                break;
            case 'U':
                parse_struct(cc, 1);
                break;
            case 'V':
                parse_varsize(cc);
                break;
            case 'G':
                parse_global(cc);
                break;
            case 'X':
            case 'Y':
                parse_function(cc);
                break;
            case 'T':
                parse_typedef(cc);
                break;
            case '$':
                /* Preprocessor directive - skip */
                tmc_skip_line(cc);
                break;
            default:
                tmc_skip_line(cc);
                break;
        }
    }

    /* Output declarations section */
    io_write_newline(cc);  /* blank line */
    io_write_newline(cc);  /* blank line */

    /* Output public declarations first, then extrn, in order */
    {
        int i;
        /* Public declarations */
        for (i = 0; i < decl_count; i++) {
            if (decl_list[i].is_public) {
                out_public(cc, decl_list[i].name);
            }
        }
        /* Extrn declarations */
        for (i = 0; i < decl_count; i++) {
            if (!decl_list[i].is_public) {
                out_extrn(cc, decl_list[i].name);
            }
        }
    }

    /* Output end */
    out_end(cc);
}
