/*
 * as_expr.c — Expression evaluator
 *
 * Stack-based operator precedence expression parser.
 * Handles arithmetic, logical, comparison operators,
 * string/numeric literals, symbol references, and
 * relocatable tracking.
 *
 * Ported from ASM1.ASM expression evaluator (A1F49 priority table).
 *
 * Operator precedence (low to high):
 *   OR, XOR
 *   AND
 *   NOT (unary)
 *   EQ, NE, LT, LE, GT, GE
 *   +, -
 *   *, /, MOD, SHL, SHR
 *   unary +, unary -, HIGH, LOW
 *   NUL, TYPE
 */

#include "as_defs.h"

/* ----------------------------------------------------------------
 *  Operator codes (internal to expression evaluator)
 * ---------------------------------------------------------------- */

#define EXP_OP_NONE    0x00
#define EXP_OP_ADD     0x01
#define EXP_OP_SUB     0x02
#define EXP_OP_MUL     0x03
#define EXP_OP_DIV     0x04
#define EXP_OP_MOD     0x05
#define EXP_OP_SHL     0x06
#define EXP_OP_SHR     0x07
#define EXP_OP_AND     0x08
#define EXP_OP_OR      0x09
#define EXP_OP_XOR     0x0A
#define EXP_OP_NOT     0x0B  /* unary */
#define EXP_OP_HIGH    0x0C  /* unary */
#define EXP_OP_LOW     0x0D  /* unary */
#define EXP_OP_EQ      0x0E
#define EXP_OP_NE      0x0F
#define EXP_OP_LT      0x10
#define EXP_OP_LE      0x11
#define EXP_OP_GT      0x12
#define EXP_OP_GE      0x13
#define EXP_OP_UPLUS   0x14  /* unary + */
#define EXP_OP_UMINUS  0x15  /* unary - */
#define EXP_OP_NUL     0x16
#define EXP_OP_TYPE    0x17

/* Operator priority table (A1F49 equivalent).
 * Higher number = higher priority (binds tighter). */
static const u8 op_priority[] = {
    /* NONE */  0,
    /* ADD  */  4,
    /* SUB  */  4,
    /* MUL  */  5,
    /* DIV  */  5,
    /* MOD  */  5,
    /* SHL  */  5,
    /* SHR  */  5,
    /* AND  */  2,
    /* OR   */  1,
    /* XOR  */  1,
    /* NOT  */  3,
    /* HIGH */  6,
    /* LOW  */  6,
    /* EQ   */  3,
    /* NE   */  3,
    /* LT   */  3,
    /* LE   */  3,
    /* GT   */  3,
    /* GE   */  3,
    /* UPLUS */ 6,
    /* UMINUS*/  6,
    /* NUL  */  7,
    /* TYPE */  7,
};

/* ----------------------------------------------------------------
 *  Number parsing
 * ---------------------------------------------------------------- */

/* Check if character is a valid digit in the given base */
static int is_digit_in_base(int ch, int base)
{
    if (ch >= '0' && ch <= '9') return (ch - '0') < base;
    if (ch >= 'A' && ch <= 'F') return (ch - 'A' + 10) < base;
    return 0;
}

static int digit_value(int ch)
{
    if (ch >= '0' && ch <= '9') return ch - '0';
    if (ch >= 'A' && ch <= 'F') return ch - 'A' + 10;
    return 0;
}

/* Parse a number from the line buffer.
 * Handles decimal, hex (suffix H), octal (suffix O/Q), binary (suffix B).
 * Returns the parsed value. Sets *valid to 1 on success, 0 on error.
 *
 * The first character has already been read and is in as->idname[0..idlen-1].
 * We re-scan from the line buffer for number parsing. */
static u16 parse_number(AsmState *as, int *valid)
{
    /* Numbers are parsed from idname which contains the token.
     * Determine base from suffix character. */
    *valid = 1;

    if (as->idlen == 0) {
        *valid = 0;
        return 0;
    }

    u8 last_ch = as->idname[as->idlen - 1];
    int base = as->radix; /* default base */
    int end = as->idlen;

    /* Check suffix */
    switch (last_ch) {
        case 'H':
            base = 16;
            end--;
            break;
        case 'O':
        case 'Q':
            base = 8;
            end--;
            break;
        case 'B':
            /* Could be hex digit or binary suffix.
             * Binary suffix if all preceding chars are 0/1. */
            {
                int all_binary = 1;
                int i;
                for (i = 0; i < end - 1; i++) {
                    if (as->idname[i] != '0' && as->idname[i] != '1') {
                        all_binary = 0;
                        break;
                    }
                }
                if (all_binary && end > 1) {
                    base = 2;
                    end--;
                }
            }
            break;
        case 'D':
            /* Could be hex digit or decimal suffix */
            if (base == 10) {
                /* Treat as decimal suffix only if all preceding are decimal digits */
                int all_dec = 1;
                int i;
                for (i = 0; i < end - 1; i++) {
                    if (as->idname[i] < '0' || as->idname[i] > '9') {
                        all_dec = 0;
                        break;
                    }
                }
                if (all_dec && end > 1) {
                    base = 10;
                    end--;
                }
            }
            break;
    }

    /* First char must be a digit (0-9) for it to be a number */
    if (as->idname[0] < '0' || as->idname[0] > '9') {
        *valid = 0;
        return 0;
    }

    /* Parse digits */
    unsigned long result = 0;
    int i;
    for (i = 0; i < end; i++) {
        u8 ch = as->idname[i];
        if (!is_digit_in_base(ch, base)) {
            *valid = 0;
            err_number(as);
            return 0;
        }
        result = result * (unsigned long)base + (unsigned long)digit_value(ch);
    }

    /* Check 16-bit overflow */
    if (result > 0xFFFF) {
        err_value(as);
        return (u16)(result & 0xFFFF);
    }

    return (u16)result;
}

/* Parse a character constant: 'x' or "xy"
 * Returns the value. */
static u16 parse_string_constant(AsmState *as, int quote_char)
{
    u16 value = 0;
    int count = 0;
    int ch;

    for (;;) {
        ch = lex_nextchar(as);
        if (ch == 0x0D || ch == 0) {
            err_syntax(as);
            return value;
        }
        if (ch == quote_char) {
            /* Check for doubled quote (escape) */
            int next = lex_nextchar(as);
            if (next != quote_char) {
                lex_pushback(as);
                break;
            }
        }
        /* Accumulate: shift left 8 and add new char */
        value = (value << 8) | (u8)ch;
        count++;
        if (count > 2) {
            /* Only first 2 chars are kept for numeric value */
        }
    }

    return value;
}

/* ----------------------------------------------------------------
 *  Expression evaluator stack
 * ---------------------------------------------------------------- */

#define EXPR_STACK_SIZE 32

typedef struct {
    u16 value;
    u8  seg_type;  /* segment type of value */
    u8  flags;     /* relocation flags */
} ExprValue;

typedef struct {
    u8  op;
    u8  priority;
} ExprOp;

static ExprValue val_stack[EXPR_STACK_SIZE];
static ExprOp    op_stack[EXPR_STACK_SIZE];
static int       val_sp;
static int       op_sp;

static void push_value(u16 v, u8 seg, u8 flags)
{
    if (val_sp < EXPR_STACK_SIZE) {
        val_stack[val_sp].value = v;
        val_stack[val_sp].seg_type = seg;
        val_stack[val_sp].flags = flags;
        val_sp++;
    }
}

static ExprValue pop_value(void)
{
    ExprValue ev = {0, 0, 0};
    if (val_sp > 0) {
        val_sp--;
        ev = val_stack[val_sp];
    }
    return ev;
}

/* Apply a binary operator */
static ExprValue apply_binop(u8 op, ExprValue left, ExprValue right, AsmState *as)
{
    ExprValue result;
    result.seg_type = 0; /* absolute by default */
    result.flags = 0;
    result.value = 0;

    u16 a = left.value;
    u16 b = right.value;

    switch (op) {
        case EXP_OP_ADD:
            result.value = a + b;
            /* If one side is relocatable, result is relocatable */
            if (left.seg_type != 0 && right.seg_type != 0) {
                err_relocatable(as);
            } else if (left.seg_type != 0) {
                result.seg_type = left.seg_type;
            } else {
                result.seg_type = right.seg_type;
            }
            break;
        case EXP_OP_SUB:
            result.value = a - b;
            if (left.seg_type == right.seg_type) {
                result.seg_type = 0; /* same segment: absolute */
            } else if (right.seg_type != 0) {
                err_relocatable(as);
            } else {
                result.seg_type = left.seg_type;
            }
            break;
        case EXP_OP_MUL:
            if (left.seg_type != 0 || right.seg_type != 0)
                err_relocatable(as);
            result.value = a * b;
            break;
        case EXP_OP_DIV:
            if (left.seg_type != 0 || right.seg_type != 0)
                err_relocatable(as);
            if (b == 0) {
                err_divide_zero(as);
                result.value = 0;
            } else {
                result.value = a / b;
            }
            break;
        case EXP_OP_MOD:
            if (left.seg_type != 0 || right.seg_type != 0)
                err_relocatable(as);
            if (b == 0) {
                err_divide_zero(as);
                result.value = 0;
            } else {
                result.value = a % b;
            }
            break;
        case EXP_OP_SHL:
            if (left.seg_type != 0 || right.seg_type != 0)
                err_relocatable(as);
            result.value = a << (b & 0x0F);
            break;
        case EXP_OP_SHR:
            if (left.seg_type != 0 || right.seg_type != 0)
                err_relocatable(as);
            result.value = a >> (b & 0x0F);
            break;
        case EXP_OP_AND:
            if (left.seg_type != 0 || right.seg_type != 0)
                err_relocatable(as);
            result.value = a & b;
            break;
        case EXP_OP_OR:
            if (left.seg_type != 0 || right.seg_type != 0)
                err_relocatable(as);
            result.value = a | b;
            break;
        case EXP_OP_XOR:
            if (left.seg_type != 0 || right.seg_type != 0)
                err_relocatable(as);
            result.value = a ^ b;
            break;
        case EXP_OP_EQ:
            result.value = (a == b) ? 0xFFFF : 0x0000;
            break;
        case EXP_OP_NE:
            result.value = (a != b) ? 0xFFFF : 0x0000;
            break;
        case EXP_OP_LT:
            result.value = ((i16)a < (i16)b) ? 0xFFFF : 0x0000;
            break;
        case EXP_OP_LE:
            result.value = ((i16)a <= (i16)b) ? 0xFFFF : 0x0000;
            break;
        case EXP_OP_GT:
            result.value = ((i16)a > (i16)b) ? 0xFFFF : 0x0000;
            break;
        case EXP_OP_GE:
            result.value = ((i16)a >= (i16)b) ? 0xFFFF : 0x0000;
            break;
        default:
            err_syntax(as);
            break;
    }

    return result;
}

/* Apply a unary operator */
static ExprValue apply_unary(u8 op, ExprValue operand, AsmState *as)
{
    ExprValue result;
    result.seg_type = 0;
    result.flags = 0;

    switch (op) {
        case EXP_OP_UMINUS:
            if (operand.seg_type != 0) err_relocatable(as);
            result.value = (u16)(-(i16)operand.value);
            break;
        case EXP_OP_UPLUS:
            result = operand;
            break;
        case EXP_OP_NOT:
            if (operand.seg_type != 0) err_relocatable(as);
            result.value = ~operand.value;
            break;
        case EXP_OP_HIGH:
            if (operand.seg_type != 0) err_relocatable(as);
            result.value = (operand.value >> 8) & 0xFF;
            break;
        case EXP_OP_LOW:
            if (operand.seg_type != 0) err_relocatable(as);
            result.value = operand.value & 0xFF;
            break;
        default:
            result.value = operand.value;
            break;
    }

    return result;
}

/* Check if the current identifier is an operator keyword.
 * Returns the operator code, or 0 if not an operator. */
static u8 check_operator_keyword(AsmState *as)
{
    if (as->idlen == 0) return 0;

    /* Save and search */
    u8 saved_type = as->op_type;
    u8 saved_reg = as->op_reg;
    u8 saved_prefix = as->op_prefix;

    if (sym_search_keyword(as)) {
        if (as->op_type == 0x20) { /* KW_OPERATOR */
            u8 code = as->op_reg;
            /* Map operator dispatch to internal code */
            switch (code) {
                case 0x01: return EXP_OP_NOT;
                case 0x02: return EXP_OP_HIGH;
                case 0x03: return EXP_OP_LOW;
                case 0x04: return EXP_OP_MOD;
                case 0x05: return EXP_OP_SHL;
                case 0x06: return EXP_OP_SHR;
                case 0x07: return EXP_OP_AND;
                case 0x08: return EXP_OP_OR;
                case 0x09: return EXP_OP_XOR;
                case 0x0A: return EXP_OP_EQ;
                case 0x0B: return EXP_OP_NE;
                case 0x0C: return EXP_OP_LT;
                case 0x0D: return EXP_OP_LE;
                case 0x0E: return EXP_OP_GT;
                case 0x0F: return EXP_OP_GE;
                case 0x10: return EXP_OP_NUL;
                case 0x11: return EXP_OP_TYPE;
            }
        }
    }

    /* Restore */
    as->op_type = saved_type;
    as->op_reg = saved_reg;
    as->op_prefix = saved_prefix;
    return 0;
}

/* Map a single-character operator to internal code */
static u8 char_to_op(int ch)
{
    switch (ch) {
        case '+': return EXP_OP_ADD;
        case '-': return EXP_OP_SUB;
        case '*': return EXP_OP_MUL;
        case '/': return EXP_OP_DIV;
        default:  return EXP_OP_NONE;
    }
}

/* Is operator unary? */
static int is_unary(u8 op)
{
    return (op == EXP_OP_NOT || op == EXP_OP_HIGH || op == EXP_OP_LOW ||
            op == EXP_OP_UPLUS || op == EXP_OP_UMINUS ||
            op == EXP_OP_NUL || op == EXP_OP_TYPE);
}

/* ----------------------------------------------------------------
 *  Main expression evaluator
 *
 *  expr_evaluate() - main entry point.
 *  Evaluates expression starting at current line position.
 *  Results stored in:
 *    as->expr_saved = result value
 *    as->expr_seg_type = segment type of result
 *    as->expr_flags = relocation flags
 * ---------------------------------------------------------------- */

void expr_evaluate(AsmState *as)
{
    val_sp = 0;
    op_sp = 0;
    as->expr_flags = 0;
    as->expr_seg_type = 0;
    as->expr_had_value = 0;
    as->expr_ext_ptr = 0;
    as->expr_ext_type = 0;

    int expect_operand = 1; /* 1 = expecting operand, 0 = expecting operator */

    for (;;) {
        int ch = lex_skipspace(as);

        if (ch == 0x0D || ch == ';' || ch == ',') {
            /* End of expression */
            lex_pushback(as);
            break;
        }

        if (ch == ')') {
            lex_pushback(as);
            break;
        }

        if (expect_operand) {
            /* --- Parse an operand --- */

            if (ch == '(') {
                /* Parenthesized sub-expression */
                expr_evaluate(as);  /* recursive */
                /* Expect closing paren */
                ch = lex_skipspace(as);
                if (ch != ')') {
                    err_syntax(as);
                    lex_pushback(as);
                }
                push_value(as->expr_saved, as->expr_seg_type, as->expr_flags);
                expect_operand = 0;
                continue;
            }

            if (ch == '$') {
                /* Current PC */
                push_value(sym_get_pc(as), sym_get_seg_type(as), 0);
                as->expr_had_value = 1;
                expect_operand = 0;
                continue;
            }

            if (ch == '\'' || ch == '"') {
                /* String constant */
                u16 val = parse_string_constant(as, ch);
                push_value(val, 0, 0);
                as->expr_had_value = 1;
                expect_operand = 0;
                continue;
            }

            if (ch == '+' || ch == '-') {
                /* Unary plus/minus */
                u8 uop = (ch == '+') ? EXP_OP_UPLUS : EXP_OP_UMINUS;
                if (op_sp < EXPR_STACK_SIZE) {
                    op_stack[op_sp].op = uop;
                    op_stack[op_sp].priority = op_priority[uop];
                    op_sp++;
                }
                continue; /* still expecting operand */
            }

            /* Try identifier (number, symbol, or keyword operator) */
            lex_pushback(as);
            int tok = lex_token_copy(as);

            if (as->idlen > 0) {
                /* Check if it's a unary operator keyword */
                u8 kw_op = check_operator_keyword(as);
                if (kw_op != 0 && is_unary(kw_op)) {
                    if (op_sp < EXPR_STACK_SIZE) {
                        op_stack[op_sp].op = kw_op;
                        op_stack[op_sp].priority = op_priority[kw_op];
                        op_sp++;
                    }
                    continue; /* still expecting operand */
                }

                /* Try as number */
                int valid = 0;
                u16 num = parse_number(as, &valid);
                if (valid) {
                    push_value(num, 0, 0);
                    as->expr_had_value = 1;
                    expect_operand = 0;
                    continue;
                }

                /* Try as user symbol */
                if (sym_search_user(as)) {
                    u8 *entry = &as->memory[as->label_ptr];
                    u16 val = (u16)entry[6] | ((u16)entry[7] << 8);
                    u8 seg = entry[5] & 0x07;
                    u8 attr = entry[5];

                    if (attr & SYM_EXTERN) {
                        /* External symbol: value is 0 (placeholder).
                         * Chain address will be recorded later in rel_put_word. */
                        push_value(0, 0, 0x80); /* flag=0x80 means external */
                        as->expr_ext_type = attr;
                        as->expr_ext_ptr = as->label_ptr;
                        as->expr_had_value = 1;
                        expect_operand = 0;
                        continue;
                    }

                    if (!(attr & SYM_DEFINED) && as->pass2) {
                        err_undefined(as);
                    }
                    push_value(val, seg, 0);
                    as->expr_had_value = 1;
                    expect_operand = 0;
                    continue;
                }

                /* Undefined symbol — add to table */
                sym_add_entry(as, 0);
                if (as->pass2) {
                    err_undefined(as);
                }
                push_value(0, 0, 0);
                as->expr_had_value = 1;
                expect_operand = 0;
                continue;
            }

            /* Not a recognized operand */
            err_syntax(as);
            push_value(0, 0, 0);
            expect_operand = 0;
            break;

        } else {
            /* --- Parse an operator --- */

            u8 op_code = char_to_op(ch);
            if (op_code == EXP_OP_NONE) {
                /* Try keyword operator */
                lex_pushback(as);
                int tok = lex_token_copy(as);
                (void)tok;
                if (as->idlen > 0) {
                    op_code = check_operator_keyword(as);
                }
                if (op_code == EXP_OP_NONE) {
                    /* End of expression */
                    /* Push back whatever we read */
                    break;
                }
            }

            u8 pri = (op_code < sizeof(op_priority)) ? op_priority[op_code] : 0;

            /* Pop and apply higher-priority operators from stack */
            while (op_sp > 0 && op_stack[op_sp - 1].priority >= pri) {
                op_sp--;
                u8 sop = op_stack[op_sp].op;
                if (is_unary(sop)) {
                    ExprValue operand = pop_value();
                    ExprValue result = apply_unary(sop, operand, as);
                    push_value(result.value, result.seg_type, result.flags);
                } else {
                    ExprValue right = pop_value();
                    ExprValue left = pop_value();
                    ExprValue result = apply_binop(sop, left, right, as);
                    push_value(result.value, result.seg_type, result.flags);
                }
            }

            /* Push new operator */
            if (op_sp < EXPR_STACK_SIZE) {
                op_stack[op_sp].op = op_code;
                op_stack[op_sp].priority = pri;
                op_sp++;
            }

            expect_operand = 1;
        }
    }

    /* Apply remaining operators */
    while (op_sp > 0) {
        op_sp--;
        u8 sop = op_stack[op_sp].op;
        if (is_unary(sop)) {
            ExprValue operand = pop_value();
            ExprValue result = apply_unary(sop, operand, as);
            push_value(result.value, result.seg_type, result.flags);
        } else {
            ExprValue right = pop_value();
            ExprValue left = pop_value();
            ExprValue result = apply_binop(sop, left, right, as);
            push_value(result.value, result.seg_type, result.flags);
        }
    }

    /* Get final result */
    if (val_sp > 0) {
        ExprValue final_val = pop_value();
        as->expr_saved = final_val.value;
        as->expr_seg_type = final_val.seg_type;
        /* Propagate relocation flags */
        if (final_val.seg_type != 0) {
            as->expr_flags |= 0x80; /* relocatable */
        }
    } else {
        as->expr_saved = 0;
        as->expr_seg_type = 0;
    }
}

/* Simplified expression evaluation for EQU and similar.
 * Returns the 16-bit result directly. */
u16 expr_eval_simple(AsmState *as)
{
    expr_evaluate(as);
    return as->expr_saved;
}

/* Evaluate expression and check result fits in a byte (0..255).
 * Returns the byte value. Reports error if out of range. */
int expr_get_byte(AsmState *as)
{
    expr_evaluate(as);
    u16 val = as->expr_saved;

    /* Allow -128..+255 for byte range */
    if (val > 0xFF && val < 0xFF80) {
        err_out_of_range(as);
    }

    return (int)(val & 0xFF);
}
