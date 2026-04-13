/*
 * as_instr.c — Z80 instruction encoding
 *
 * Contains handlers for all Z80 instructions. The dispatch is via
 * the L0B52/L0B96 tables in ASM1.ASM.
 *
 * Each handler parses operands, validates register/addressing mode
 * combinations, and emits machine code bytes via rel_output_code_byte().
 *
 * The dispatch codes match those defined in as_symtab.c.
 */

#include "as_defs.h"

/* ----------------------------------------------------------------
 *  Forward declarations for instruction handlers
 * ---------------------------------------------------------------- */

static void instr_ld(AsmState *as);
static void instr_inc_dec(AsmState *as, u8 base_opcode);
static void instr_alu_reg(AsmState *as, u8 base_opcode);
static void instr_jp(AsmState *as);
static void instr_jr(AsmState *as);
static void instr_call(AsmState *as);
static void instr_ret(AsmState *as);
static void instr_rst(AsmState *as);
static void instr_push_pop(AsmState *as, u8 base_opcode);
static void instr_ex(AsmState *as);
static void instr_in(AsmState *as);
static void instr_out(AsmState *as);
static void instr_djnz(AsmState *as);
static void instr_bit_res_set(AsmState *as, u8 cb_base);
static void instr_rotate(AsmState *as, u8 cb_base);
static void instr_im(AsmState *as);
static void instr_add_16(AsmState *as);
static void instr_adc_16(AsmState *as);
static void instr_sbc_16(AsmState *as);
static void instr_simple(AsmState *as, u8 opcode);

/* ----------------------------------------------------------------
 *  Operand parsing helpers
 * ---------------------------------------------------------------- */

/* Register code constants for operand parsing */
#define OP_REG_B     0x00
#define OP_REG_C     0x01
#define OP_REG_D     0x02
#define OP_REG_E     0x03
#define OP_REG_H     0x04
#define OP_REG_L     0x05
#define OP_REG_M     0x06  /* (HL) */
#define OP_REG_A     0x07
#define OP_REG_I     0x08
#define OP_REG_R     0x09
#define OP_REG_BC    0x10
#define OP_REG_DE    0x11
#define OP_REG_HL    0x12
#define OP_REG_SP    0x13
#define OP_REG_AF    0x14
#define OP_REG_IX    0x15
#define OP_REG_IY    0x16
#define OP_REG_IXH   0x17
#define OP_REG_IXL   0x18
#define OP_REG_IYH   0x19
#define OP_REG_IYL   0x1A

/* Operand types */
#define OPND_NONE    0x00
#define OPND_REG8    0x01  /* 8-bit register */
#define OPND_REG16   0x02  /* 16-bit register */
#define OPND_IMM8    0x03  /* immediate byte */
#define OPND_IMM16   0x04  /* immediate word */
#define OPND_INDIRECT 0x05 /* (expr) or (reg) */
#define OPND_IXIY_D  0x06  /* (IX+d) or (IY+d) */
#define OPND_COND    0x07  /* condition code */
#define OPND_EXPR    0x08  /* expression value */

/* Parsed operand */
typedef struct {
    u8  type;       /* OPND_xxx */
    u8  reg;        /* register code if applicable */
    u8  prefix;     /* DD/FD prefix if IX/IY involved */
    u16 value;      /* immediate/displacement value */
    u8  seg_type;   /* segment type of value */
    u8  flags;      /* expression flags */
    u8  indirect;   /* 1 if parenthesized */
} Operand;

/* Parse a single operand from the line buffer.
 * Returns the operand info in *op.
 * TODO: This needs detailed implementation matching L13CB operand parsing. */
static void parse_operand(AsmState *as, Operand *op)
{
    int ch;

    memset(op, 0, sizeof(Operand));

    ch = lex_skipspace(as);

    if (ch == 0x0D || ch == ';') {
        lex_pushback(as);
        op->type = OPND_NONE;
        return;
    }

    /* Check for indirect addressing: (xxx) */
    if (ch == '(') {
        op->indirect = 1;

        /* Look at what's inside the parens */
        int tok = lex_token_copy(as);

        if (as->idlen > 0 && sym_search_keyword(as)) {
            if (as->op_type == 0x10) { /* KW_REGISTER */
                op->reg = as->op_reg;
                op->prefix = as->op_prefix;

                /* Check for (IX+d) / (IY+d) */
                if (op->reg == OP_REG_IX || op->reg == OP_REG_IY) {
                    ch = lex_skipspace(as);
                    if (ch == '+' || ch == '-') {
                        lex_pushback(as);
                        expr_evaluate(as);
                        op->value = as->expr_saved;
                        op->seg_type = as->expr_seg_type;
                        op->type = OPND_IXIY_D;
                    } else {
                        lex_pushback(as);
                        op->type = OPND_IXIY_D;
                        op->value = 0;
                    }
                } else if (op->reg == OP_REG_HL) {
                    op->type = OPND_REG8;
                    op->reg = OP_REG_M; /* (HL) = M */
                } else if (op->reg == OP_REG_BC || op->reg == OP_REG_DE ||
                           op->reg == OP_REG_SP) {
                    op->type = OPND_INDIRECT;
                } else if (op->reg == OP_REG_C) {
                    /* (C) for IN/OUT */
                    op->type = OPND_INDIRECT;
                } else {
                    op->type = OPND_INDIRECT;
                }

                /* Expect closing paren */
                ch = lex_skipspace(as);
                if (ch != ')') {
                    err_syntax(as);
                    lex_pushback(as);
                }
                return;
            }
        }

        /* Not a register — must be an address expression: (nn) */
        /* Push back and parse expression */
        /* The token_copy already consumed the identifier, so we need
         * to handle this carefully */
        lex_pushback(as);
        /* Re-parse: the identifier is already in idname.
         * For now, evaluate expression from current position */
        expr_evaluate(as);
        op->value = as->expr_saved;
        op->seg_type = as->expr_seg_type;
        op->flags = as->expr_flags;
        op->type = OPND_INDIRECT; /* (nn) */

        ch = lex_skipspace(as);
        if (ch != ')') {
            err_syntax(as);
            lex_pushback(as);
        }
        return;
    }

    /* Try identifier */
    lex_pushback(as);
    {
        int tok = lex_token_copy(as);
        (void)tok;
    }

    if (as->idlen > 0) {
        /* Check if it's a keyword (register or condition) */
        if (sym_search_keyword(as)) {
            if (as->op_type == 0x10) { /* KW_REGISTER */
                op->reg = as->op_reg;
                op->prefix = as->op_prefix;
                if (op->reg <= OP_REG_A || op->reg == OP_REG_IXH ||
                    op->reg == OP_REG_IXL || op->reg == OP_REG_IYH ||
                    op->reg == OP_REG_IYL) {
                    op->type = OPND_REG8;
                } else {
                    op->type = OPND_REG16;
                }
                return;
            }
            if (as->op_type == 0x18) { /* KW_CONDITION */
                op->type = OPND_COND;
                op->reg = as->op_reg;
                return;
            }
        }

        /* Not a keyword — try as number or symbol via expression */
        /* Push back and evaluate as expression */
        /* The token is already consumed; we need to evaluate it.
         * Since token_copy already read it, we handle it via
         * the expression evaluator which will re-read. */
        /* TODO: Proper integration with expression evaluator for
         * tokens already parsed. For now, attempt number parse. */
        int valid = 0;
        /* Try parsing idname as a number */
        u8 first = as->idname[0];
        if (first >= '0' && first <= '9') {
            /* Looks like a number — use expression evaluator from
             * the position before the token. We'll re-scan. */
        }

        /* Fall back to expression evaluation */
        /* Rewind line position past the token and evaluate */
        {
            u16 saved_pos = as->line_pos;
            /* We already consumed the token. Evaluate it. */
            /* For a simple identifier, look up in symbol table */
            if (sym_search_user(as)) {
                u8 *entry = &as->memory[as->label_ptr];
                op->value = (u16)entry[6] | ((u16)entry[7] << 8);
                op->seg_type = entry[5] & 0x07;
            } else {
                /* Undefined — try as number from idname */
                /* parse_number is in as_expr.c, we call expr_evaluate */
                /* For now, set value to 0 */
                op->value = 0;
                if (as->pass2) err_undefined(as);
            }
            (void)saved_pos;
            (void)valid;
        }

        /* Determine if it's 8-bit or 16-bit based on context */
        op->type = OPND_EXPR;
        return;
    }

    /* Single character that's not an identifier start */
    ch = lex_nextchar(as);
    if (ch == '$') {
        op->value = sym_get_pc(as);
        op->seg_type = sym_get_seg_type(as);
        op->type = OPND_EXPR;
        return;
    }

    /* Try expression */
    lex_pushback(as);
    expr_evaluate(as);
    op->value = as->expr_saved;
    op->seg_type = as->expr_seg_type;
    op->flags = as->expr_flags;
    op->type = OPND_EXPR;
}

/* Expect and consume a comma. Report error if missing. */
static int expect_comma(AsmState *as)
{
    int ch = lex_skipspace(as);
    if (ch != ',') {
        err_syntax(as);
        lex_pushback(as);
        return 0;
    }
    return 1;
}

/* Emit an IX/IY prefix byte if needed */
static void emit_prefix(AsmState *as, u8 prefix)
{
    if (prefix == 0xDD || prefix == 0xFD) {
        rel_output_code_byte(as, prefix);
    }
}

/* Get the 3-bit register encoding for 8-bit registers */
static u8 reg8_code(u8 reg)
{
    switch (reg) {
        case OP_REG_B:   return 0;
        case OP_REG_C:   return 1;
        case OP_REG_D:   return 2;
        case OP_REG_E:   return 3;
        case OP_REG_H:   return 4;
        case OP_REG_IXH: return 4;
        case OP_REG_IYH: return 4;
        case OP_REG_L:   return 5;
        case OP_REG_IXL: return 5;
        case OP_REG_IYL: return 5;
        case OP_REG_M:   return 6;
        case OP_REG_A:   return 7;
        default:         return 0;
    }
}

/* Get the 2-bit register pair encoding */
static u8 reg16_code(u8 reg)
{
    switch (reg) {
        case OP_REG_BC: return 0;
        case OP_REG_DE: return 1;
        case OP_REG_HL: return 2;
        case OP_REG_IX: return 2;
        case OP_REG_IY: return 2;
        case OP_REG_SP: return 3;
        case OP_REG_AF: return 3;
        default:        return 0;
    }
}

/* ----------------------------------------------------------------
 *  Instruction dispatch table (L0AD6 equivalent)
 *
 *  Maps dispatch codes to handler functions.
 * ---------------------------------------------------------------- */

/* Dispatch codes 0x00..0x21 and 0x40 (INSTR_SIMPLE) */

#define INSTR_SIMPLE_CODE  0x40

void instr_dispatch(AsmState *as, u8 dispatch_code, u8 prefix)
{
    /* Save prefix for later use */
    as->op_prefix = prefix;

    if (dispatch_code >= INSTR_SIMPLE_CODE) {
        /* Simple instruction — prefix byte is the opcode */
        instr_simple(as, prefix);
        return;
    }

    switch (dispatch_code) {
        case 0x00: /* NOP — should not reach here, handled as simple */
            rel_output_code_byte(as, 0x00);
            break;
        case 0x01: instr_ld(as);                  break;
        case 0x02: instr_inc_dec(as, 0x04);        break; /* INC: base 04h */
        case 0x03: instr_inc_dec(as, 0x05);        break; /* DEC: base 05h */
        case 0x04: instr_add_16(as);               break; /* ADD */
        case 0x05: instr_adc_16(as);               break; /* ADC */
        case 0x06: instr_alu_reg(as, 0x90);        break; /* SUB */
        case 0x07: instr_sbc_16(as);               break; /* SBC */
        case 0x08: instr_alu_reg(as, 0xA0);        break; /* AND */
        case 0x09: instr_alu_reg(as, 0xA8);        break; /* XOR */
        case 0x0A: instr_alu_reg(as, 0xB0);        break; /* OR */
        case 0x0B: instr_alu_reg(as, 0xB8);        break; /* CP */
        case 0x0C: instr_jp(as);                   break;
        case 0x0D: instr_jr(as);                   break;
        case 0x0E: instr_call(as);                 break;
        case 0x0F: instr_ret(as);                  break;
        case 0x10: instr_rst(as);                  break;
        case 0x11: instr_push_pop(as, 0xC5);       break; /* PUSH */
        case 0x12: instr_push_pop(as, 0xC1);       break; /* POP */
        case 0x13: instr_ex(as);                   break;
        case 0x14: instr_in(as);                   break;
        case 0x15: instr_out(as);                  break;
        case 0x16: instr_djnz(as);                break;
        case 0x17: instr_bit_res_set(as, 0x40);   break; /* BIT */
        case 0x18: instr_bit_res_set(as, 0x80);   break; /* RES */
        case 0x19: instr_bit_res_set(as, 0xC0);   break; /* SET */
        case 0x1A: instr_rotate(as, 0x00);         break; /* RLC */
        case 0x1B: instr_rotate(as, 0x08);         break; /* RRC */
        case 0x1C: instr_rotate(as, 0x10);         break; /* RL */
        case 0x1D: instr_rotate(as, 0x18);         break; /* RR */
        case 0x1E: instr_rotate(as, 0x20);         break; /* SLA */
        case 0x1F: instr_rotate(as, 0x28);         break; /* SRA */
        case 0x20: instr_rotate(as, 0x38);         break; /* SRL */
        case 0x21: instr_im(as);                   break;
        default:
            err_syntax(as);
            break;
    }
}

/* ----------------------------------------------------------------
 *  Simple instructions (no operands)
 *  The opcode byte is in 'prefix' parameter from dispatch.
 * ---------------------------------------------------------------- */

static void instr_simple(AsmState *as, u8 opcode)
{
    /* ED-prefixed simple instructions.
     * Opcodes >= 0x40 in the ED page need ED prefix. */
    if (opcode >= 0x40 && opcode != 0x76 && opcode != 0xD9 &&
        opcode != 0xF3 && opcode != 0xFB) {
        rel_output_code_byte(as, 0xED);
    }
    rel_output_code_byte(as, opcode);
}

/* ----------------------------------------------------------------
 *  LD instruction handler (L13CB equivalent)
 *
 *  The most complex instruction — handles all LD variants:
 *  LD r,r'  LD r,n  LD r,(HL)  LD r,(IX+d)  LD r,(IY+d)
 *  LD (HL),r  LD (IX+d),r  LD (IY+d),r  LD (HL),n  etc.
 *  LD A,(BC) LD A,(DE) LD (BC),A LD (DE),A
 *  LD A,(nn) LD (nn),A LD A,I LD A,R LD I,A LD R,A
 *  LD rr,nn  LD rr,(nn)  LD (nn),rr  LD SP,HL  etc.
 *
 *  TODO: Full implementation requires detailed operand mode analysis
 *  matching the original L13CB..L15C2 code. This is a structural
 *  stub that handles the most common cases.
 * ---------------------------------------------------------------- */

static void instr_ld(AsmState *as)
{
    Operand dst, src;

    parse_operand(as, &dst);
    if (!expect_comma(as)) return;
    parse_operand(as, &src);

    /* LD r8, r8 */
    if (dst.type == OPND_REG8 && src.type == OPND_REG8) {
        u8 prefix_byte = dst.prefix ? dst.prefix : src.prefix;
        emit_prefix(as, prefix_byte);
        u8 opcode = 0x40 | (reg8_code(dst.reg) << 3) | reg8_code(src.reg);
        rel_output_code_byte(as, opcode);
        /* Emit displacement for (IX+d)/(IY+d) if needed */
        return;
    }

    /* LD r8, imm8 */
    if (dst.type == OPND_REG8 && (src.type == OPND_EXPR || src.type == OPND_IMM8)) {
        emit_prefix(as, dst.prefix);
        u8 opcode = 0x06 | (reg8_code(dst.reg) << 3);
        rel_output_code_byte(as, opcode);
        if (dst.type == OPND_IXIY_D) {
            rel_output_code_byte(as, (u8)dst.value);
        }
        rel_output_code_byte(as, (u8)(src.value & 0xFF));
        return;
    }

    /* LD (IX+d)/r8, src — with displacement */
    if (dst.type == OPND_IXIY_D && src.type == OPND_REG8) {
        emit_prefix(as, dst.prefix);
        u8 opcode = 0x70 | reg8_code(src.reg);
        rel_output_code_byte(as, opcode);
        rel_output_code_byte(as, (u8)dst.value);
        return;
    }

    if (dst.type == OPND_REG8 && src.type == OPND_IXIY_D) {
        emit_prefix(as, src.prefix);
        u8 opcode = 0x46 | (reg8_code(dst.reg) << 3);
        rel_output_code_byte(as, opcode);
        rel_output_code_byte(as, (u8)src.value);
        return;
    }

    /* LD rr, imm16 */
    if (dst.type == OPND_REG16 && (src.type == OPND_EXPR || src.type == OPND_IMM16)) {
        emit_prefix(as, dst.prefix);
        u8 opcode = 0x01 | (reg16_code(dst.reg) << 4);
        rel_output_code_byte(as, opcode);
        rel_put_word(as, src.value, src.seg_type);
        return;
    }

    /* LD rr, (nn) */
    if (dst.type == OPND_REG16 && src.type == OPND_INDIRECT && src.reg == 0) {
        if (dst.reg == OP_REG_HL && dst.prefix == 0) {
            rel_output_code_byte(as, 0x2A);
        } else {
            emit_prefix(as, dst.prefix);
            rel_output_code_byte(as, 0xED);
            rel_output_code_byte(as, 0x4B | (reg16_code(dst.reg) << 4));
        }
        rel_put_word(as, src.value, src.seg_type);
        return;
    }

    /* LD (nn), rr */
    if (dst.type == OPND_INDIRECT && dst.reg == 0 && src.type == OPND_REG16) {
        if (src.reg == OP_REG_HL && src.prefix == 0) {
            rel_output_code_byte(as, 0x22);
        } else {
            emit_prefix(as, src.prefix);
            rel_output_code_byte(as, 0xED);
            rel_output_code_byte(as, 0x43 | (reg16_code(src.reg) << 4));
        }
        rel_put_word(as, dst.value, dst.seg_type);
        return;
    }

    /* LD A, (BC)/(DE) */
    if (dst.type == OPND_REG8 && dst.reg == OP_REG_A &&
        src.type == OPND_INDIRECT) {
        if (src.reg == OP_REG_BC) {
            rel_output_code_byte(as, 0x0A);
            return;
        }
        if (src.reg == OP_REG_DE) {
            rel_output_code_byte(as, 0x1A);
            return;
        }
        /* LD A, (nn) */
        if (src.reg == 0) {
            rel_output_code_byte(as, 0x3A);
            rel_put_word(as, src.value, src.seg_type);
            return;
        }
    }

    /* LD (BC),A / LD (DE),A */
    if (dst.type == OPND_INDIRECT && src.type == OPND_REG8 &&
        src.reg == OP_REG_A) {
        if (dst.reg == OP_REG_BC) {
            rel_output_code_byte(as, 0x02);
            return;
        }
        if (dst.reg == OP_REG_DE) {
            rel_output_code_byte(as, 0x12);
            return;
        }
        /* LD (nn), A */
        if (dst.reg == 0) {
            rel_output_code_byte(as, 0x32);
            rel_put_word(as, dst.value, dst.seg_type);
            return;
        }
    }

    /* LD SP, HL/IX/IY */
    if (dst.type == OPND_REG16 && dst.reg == OP_REG_SP &&
        src.type == OPND_REG16 &&
        (src.reg == OP_REG_HL || src.reg == OP_REG_IX || src.reg == OP_REG_IY)) {
        emit_prefix(as, src.prefix);
        rel_output_code_byte(as, 0xF9);
        return;
    }

    /* LD A,I / LD A,R / LD I,A / LD R,A */
    if (dst.type == OPND_REG8 && src.type == OPND_REG8) {
        if (dst.reg == OP_REG_A && src.reg == OP_REG_I) {
            rel_output_code_byte(as, 0xED);
            rel_output_code_byte(as, 0x57);
            return;
        }
        if (dst.reg == OP_REG_A && src.reg == OP_REG_R) {
            rel_output_code_byte(as, 0xED);
            rel_output_code_byte(as, 0x5F);
            return;
        }
        if (dst.reg == OP_REG_I && src.reg == OP_REG_A) {
            rel_output_code_byte(as, 0xED);
            rel_output_code_byte(as, 0x47);
            return;
        }
        if (dst.reg == OP_REG_R && src.reg == OP_REG_A) {
            rel_output_code_byte(as, 0xED);
            rel_output_code_byte(as, 0x4F);
            return;
        }
    }

    /* LD (IX+d),n / LD (IY+d),n */
    if (dst.type == OPND_IXIY_D && (src.type == OPND_EXPR || src.type == OPND_IMM8)) {
        emit_prefix(as, dst.prefix);
        rel_output_code_byte(as, 0x36);
        rel_output_code_byte(as, (u8)dst.value);
        rel_output_code_byte(as, (u8)(src.value & 0xFF));
        return;
    }

    /* TODO: Remaining LD variants need implementation matching L13CB.
     * The above covers the most common cases. */
    err_syntax(as);
}

/* ----------------------------------------------------------------
 *  INC / DEC
 *  INC r / INC (HL) / INC (IX+d) / INC rr
 * ---------------------------------------------------------------- */

static void instr_inc_dec(AsmState *as, u8 base_opcode)
{
    Operand op;
    parse_operand(as, &op);

    if (op.type == OPND_REG8) {
        emit_prefix(as, op.prefix);
        u8 opcode = (base_opcode == 0x04) ?
            (0x04 | (reg8_code(op.reg) << 3)) :  /* INC */
            (0x05 | (reg8_code(op.reg) << 3));    /* DEC */
        rel_output_code_byte(as, opcode);
        return;
    }

    if (op.type == OPND_IXIY_D) {
        emit_prefix(as, op.prefix);
        u8 opcode = (base_opcode == 0x04) ? 0x34 : 0x35;
        rel_output_code_byte(as, opcode);
        rel_output_code_byte(as, (u8)op.value);
        return;
    }

    if (op.type == OPND_REG16) {
        emit_prefix(as, op.prefix);
        u8 opcode = (base_opcode == 0x04) ?
            (0x03 | (reg16_code(op.reg) << 4)) :  /* INC rr */
            (0x0B | (reg16_code(op.reg) << 4));    /* DEC rr */
        rel_output_code_byte(as, opcode);
        return;
    }

    err_syntax(as);
}

/* ----------------------------------------------------------------
 *  ALU operations: ADD/ADC/SUB/SBC/AND/XOR/OR/CP r/n/(HL)/(IX+d)
 *  base_opcode: 0x80=ADD, 0x88=ADC, 0x90=SUB, 0x98=SBC,
 *               0xA0=AND, 0xA8=XOR, 0xB0=OR, 0xB8=CP
 *
 *  For ADD/ADC/SBC, the first operand may be A (8-bit) or HL (16-bit).
 * ---------------------------------------------------------------- */

static void instr_alu_reg(AsmState *as, u8 base_opcode)
{
    Operand op;
    parse_operand(as, &op);

    /* Check for "ADD A,x" form */
    if (op.type == OPND_REG8 && op.reg == OP_REG_A) {
        int ch = lex_skipspace(as);
        if (ch == ',') {
            /* ADD A, src */
            parse_operand(as, &op);
        } else {
            lex_pushback(as);
            /* ADD A (no second operand) — error or A is the operand */
        }
    }

    if (op.type == OPND_REG8) {
        emit_prefix(as, op.prefix);
        u8 opcode = base_opcode | reg8_code(op.reg);
        rel_output_code_byte(as, opcode);
        return;
    }

    if (op.type == OPND_IXIY_D) {
        emit_prefix(as, op.prefix);
        u8 opcode = base_opcode | 0x06; /* (HL)/(IX+d)/(IY+d) */
        rel_output_code_byte(as, opcode);
        rel_output_code_byte(as, (u8)op.value);
        return;
    }

    if (op.type == OPND_EXPR || op.type == OPND_IMM8) {
        /* Immediate: base + 0x46, then immediate byte */
        u8 opcode = base_opcode | 0x46;
        /* Actually: the immediate form is base_opcode - 0x40 + 0xC6
         * ADD A,n = C6, ADC A,n = CE, SUB n = D6, etc. */
        opcode = (base_opcode - 0x80) + 0xC6;
        rel_output_code_byte(as, opcode);
        rel_output_code_byte(as, (u8)(op.value & 0xFF));
        return;
    }

    err_syntax(as);
}

/* ----------------------------------------------------------------
 *  ADD HL/IX/IY, rr (16-bit add)
 * ---------------------------------------------------------------- */

static void instr_add_16(AsmState *as)
{
    Operand dst, src;
    parse_operand(as, &dst);

    /* Check for ADD A,x (8-bit) vs ADD HL,rr (16-bit) */
    if (dst.type == OPND_REG8 && dst.reg == OP_REG_A) {
        int ch = lex_skipspace(as);
        if (ch == ',') {
            /* ADD A, src */
            Operand op2;
            parse_operand(as, &op2);

            if (op2.type == OPND_REG8) {
                emit_prefix(as, op2.prefix);
                rel_output_code_byte(as, 0x80 | reg8_code(op2.reg));
                return;
            }
            if (op2.type == OPND_IXIY_D) {
                emit_prefix(as, op2.prefix);
                rel_output_code_byte(as, 0x86);
                rel_output_code_byte(as, (u8)op2.value);
                return;
            }
            if (op2.type == OPND_EXPR) {
                rel_output_code_byte(as, 0xC6);
                rel_output_code_byte(as, (u8)(op2.value & 0xFF));
                return;
            }
            err_syntax(as);
            return;
        }
        lex_pushback(as);
        /* ADD A with no comma — treat A as sole operand */
        rel_output_code_byte(as, 0x87); /* ADD A,A */
        return;
    }

    if (dst.type == OPND_REG16 &&
        (dst.reg == OP_REG_HL || dst.reg == OP_REG_IX || dst.reg == OP_REG_IY)) {
        if (!expect_comma(as)) return;
        parse_operand(as, &src);

        if (src.type == OPND_REG16) {
            emit_prefix(as, dst.prefix);
            u8 opcode = 0x09 | (reg16_code(src.reg) << 4);
            rel_output_code_byte(as, opcode);
            return;
        }
    }

    /* Fallback: treat as 8-bit ADD */
    instr_alu_reg(as, 0x80);
}

/* ----------------------------------------------------------------
 *  ADC HL, rr (16-bit)
 * ---------------------------------------------------------------- */

static void instr_adc_16(AsmState *as)
{
    Operand dst;
    parse_operand(as, &dst);

    if (dst.type == OPND_REG8 && dst.reg == OP_REG_A) {
        int ch = lex_skipspace(as);
        if (ch == ',') {
            Operand src;
            parse_operand(as, &src);
            if (src.type == OPND_REG8) {
                emit_prefix(as, src.prefix);
                rel_output_code_byte(as, 0x88 | reg8_code(src.reg));
                return;
            }
            if (src.type == OPND_EXPR) {
                rel_output_code_byte(as, 0xCE);
                rel_output_code_byte(as, (u8)(src.value & 0xFF));
                return;
            }
            err_syntax(as);
            return;
        }
        lex_pushback(as);
    }

    if (dst.type == OPND_REG16 && dst.reg == OP_REG_HL) {
        if (!expect_comma(as)) return;
        Operand src;
        parse_operand(as, &src);
        if (src.type == OPND_REG16) {
            rel_output_code_byte(as, 0xED);
            rel_output_code_byte(as, 0x4A | (reg16_code(src.reg) << 4));
            return;
        }
    }

    err_syntax(as);
}

/* ----------------------------------------------------------------
 *  SBC HL, rr (16-bit)
 * ---------------------------------------------------------------- */

static void instr_sbc_16(AsmState *as)
{
    Operand dst;
    parse_operand(as, &dst);

    if (dst.type == OPND_REG8 && dst.reg == OP_REG_A) {
        int ch = lex_skipspace(as);
        if (ch == ',') {
            Operand src;
            parse_operand(as, &src);
            if (src.type == OPND_REG8) {
                emit_prefix(as, src.prefix);
                rel_output_code_byte(as, 0x98 | reg8_code(src.reg));
                return;
            }
            if (src.type == OPND_EXPR) {
                rel_output_code_byte(as, 0xDE);
                rel_output_code_byte(as, (u8)(src.value & 0xFF));
                return;
            }
            err_syntax(as);
            return;
        }
        lex_pushback(as);
    }

    if (dst.type == OPND_REG16 && dst.reg == OP_REG_HL) {
        if (!expect_comma(as)) return;
        Operand src;
        parse_operand(as, &src);
        if (src.type == OPND_REG16) {
            rel_output_code_byte(as, 0xED);
            rel_output_code_byte(as, 0x42 | (reg16_code(src.reg) << 4));
            return;
        }
    }

    err_syntax(as);
}

/* ----------------------------------------------------------------
 *  JP instruction
 *  JP nn / JP cc,nn / JP (HL) / JP (IX) / JP (IY)
 * ---------------------------------------------------------------- */

static void instr_jp(AsmState *as)
{
    Operand op;
    parse_operand(as, &op);

    /* JP (HL) / JP (IX) / JP (IY) */
    if (op.type == OPND_INDIRECT &&
        (op.reg == OP_REG_HL || op.reg == OP_REG_IX || op.reg == OP_REG_IY)) {
        emit_prefix(as, op.prefix);
        rel_output_code_byte(as, 0xE9);
        return;
    }
    if (op.type == OPND_REG8 && op.reg == OP_REG_M) {
        /* JP (HL) parsed as M */
        rel_output_code_byte(as, 0xE9);
        return;
    }

    /* JP cc, nn */
    if (op.type == OPND_COND) {
        if (!expect_comma(as)) return;
        expr_evaluate(as);
        u8 opcode = 0xC2 | (op.reg << 3);
        rel_output_code_byte(as, opcode);
        rel_put_word(as, as->expr_saved, as->expr_seg_type);
        return;
    }

    /* JP nn — the operand might already be an expression */
    if (op.type == OPND_EXPR || op.type == OPND_IMM16) {
        rel_output_code_byte(as, 0xC3);
        rel_put_word(as, op.value, op.seg_type);
        return;
    }

    /* Try evaluating as expression */
    rel_output_code_byte(as, 0xC3);
    rel_put_word(as, op.value, op.seg_type);
}

/* ----------------------------------------------------------------
 *  JR instruction
 *  JR e / JR cc,e (cc = NZ/Z/NC/C only)
 * ---------------------------------------------------------------- */

static void instr_jr(AsmState *as)
{
    Operand op;
    parse_operand(as, &op);

    u8 base_opcode = 0x18; /* JR e */

    if (op.type == OPND_COND) {
        /* Only NZ, Z, NC, C are valid for JR */
        if (op.reg > 3) {
            err_syntax(as);
            return;
        }
        base_opcode = 0x20 | (op.reg << 3);
        if (!expect_comma(as)) return;
        expr_evaluate(as);
    } else if (op.type == OPND_EXPR) {
        as->expr_saved = op.value;
        as->expr_seg_type = op.seg_type;
    } else {
        /* Evaluate expression */
        expr_evaluate(as);
    }

    /* Calculate relative displacement */
    u16 target = as->expr_saved;
    u16 pc = as->org_counter + 2;
    i16 disp = (i16)(target - pc);

    if (as->pass2 && (disp < -128 || disp > 127)) {
        err_out_of_range(as);
    }

    rel_output_code_byte(as, base_opcode);
    rel_output_code_byte(as, (u8)(disp & 0xFF));
}

/* ----------------------------------------------------------------
 *  CALL instruction
 *  CALL nn / CALL cc,nn
 * ---------------------------------------------------------------- */

static void instr_call(AsmState *as)
{
    Operand op;
    parse_operand(as, &op);

    if (op.type == OPND_COND) {
        if (!expect_comma(as)) return;
        expr_evaluate(as);
        u8 opcode = 0xC4 | (op.reg << 3);
        rel_output_code_byte(as, opcode);
        rel_put_word(as, as->expr_saved, as->expr_seg_type);
        return;
    }

    /* CALL nn */
    rel_output_code_byte(as, 0xCD);
    if (op.type == OPND_EXPR || op.type == OPND_IMM16) {
        rel_put_word(as, op.value, op.seg_type);
    } else {
        rel_put_word(as, op.value, op.seg_type);
    }
}

/* ----------------------------------------------------------------
 *  RET instruction
 *  RET / RET cc
 * ---------------------------------------------------------------- */

static void instr_ret(AsmState *as)
{
    int ch = lex_skipspace(as);
    lex_pushback(as);

    if (ch == 0x0D || ch == ';') {
        /* RET (no condition) */
        rel_output_code_byte(as, 0xC9);
        return;
    }

    Operand op;
    parse_operand(as, &op);

    if (op.type == OPND_COND) {
        u8 opcode = 0xC0 | (op.reg << 3);
        rel_output_code_byte(as, opcode);
        return;
    }

    /* No condition — just RET */
    rel_output_code_byte(as, 0xC9);
}

/* ----------------------------------------------------------------
 *  RST instruction
 *  RST n (n = 0, 8, 16, 24, 32, 40, 48, 56)
 * ---------------------------------------------------------------- */

static void instr_rst(AsmState *as)
{
    expr_evaluate(as);
    u16 val = as->expr_saved;

    if (val > 0x38 || (val & 0x07) != 0) {
        err_out_of_range(as);
    }

    rel_output_code_byte(as, (u8)(0xC7 | (val & 0x38)));
}

/* ----------------------------------------------------------------
 *  PUSH / POP
 *  PUSH rr / POP rr (rr = BC,DE,HL,AF,IX,IY)
 * ---------------------------------------------------------------- */

static void instr_push_pop(AsmState *as, u8 base_opcode)
{
    Operand op;
    parse_operand(as, &op);

    if (op.type != OPND_REG16) {
        err_syntax(as);
        return;
    }

    emit_prefix(as, op.prefix);

    /* AF uses the same slot as SP (code 3) for PUSH/POP */
    u8 code = reg16_code(op.reg);
    u8 opcode = base_opcode | (code << 4);
    rel_output_code_byte(as, opcode);
}

/* ----------------------------------------------------------------
 *  EX instruction
 *  EX DE,HL / EX AF,AF' / EX (SP),HL / EX (SP),IX / EX (SP),IY
 * ---------------------------------------------------------------- */

static void instr_ex(AsmState *as)
{
    Operand dst, src;
    parse_operand(as, &dst);
    if (!expect_comma(as)) return;
    parse_operand(as, &src);

    /* EX DE,HL */
    if (dst.type == OPND_REG16 && dst.reg == OP_REG_DE &&
        src.type == OPND_REG16 && src.reg == OP_REG_HL) {
        rel_output_code_byte(as, 0xEB);
        return;
    }

    /* EX AF,AF' */
    if (dst.type == OPND_REG16 && dst.reg == OP_REG_AF) {
        rel_output_code_byte(as, 0x08);
        return;
    }

    /* EX (SP),HL / EX (SP),IX / EX (SP),IY */
    if (dst.type == OPND_INDIRECT && dst.reg == OP_REG_SP &&
        src.type == OPND_REG16) {
        emit_prefix(as, src.prefix);
        rel_output_code_byte(as, 0xE3);
        return;
    }

    err_syntax(as);
}

/* ----------------------------------------------------------------
 *  IN instruction
 *  IN A,(n) / IN r,(C)
 * ---------------------------------------------------------------- */

static void instr_in(AsmState *as)
{
    Operand dst;
    parse_operand(as, &dst);
    if (!expect_comma(as)) return;

    Operand src;
    parse_operand(as, &src);

    /* IN A,(n) */
    if (dst.type == OPND_REG8 && dst.reg == OP_REG_A &&
        src.type == OPND_INDIRECT && src.reg == 0) {
        rel_output_code_byte(as, 0xDB);
        rel_output_code_byte(as, (u8)(src.value & 0xFF));
        return;
    }

    /* IN r,(C) */
    if (dst.type == OPND_REG8 && src.type == OPND_INDIRECT &&
        src.reg == OP_REG_C) {
        rel_output_code_byte(as, 0xED);
        rel_output_code_byte(as, 0x40 | (reg8_code(dst.reg) << 3));
        return;
    }

    err_syntax(as);
}

/* ----------------------------------------------------------------
 *  OUT instruction
 *  OUT (n),A / OUT (C),r
 * ---------------------------------------------------------------- */

static void instr_out(AsmState *as)
{
    Operand dst;
    parse_operand(as, &dst);
    if (!expect_comma(as)) return;

    Operand src;
    parse_operand(as, &src);

    /* OUT (n),A */
    if (dst.type == OPND_INDIRECT && dst.reg == 0 &&
        src.type == OPND_REG8 && src.reg == OP_REG_A) {
        rel_output_code_byte(as, 0xD3);
        rel_output_code_byte(as, (u8)(dst.value & 0xFF));
        return;
    }

    /* OUT (C),r */
    if (dst.type == OPND_INDIRECT && dst.reg == OP_REG_C &&
        src.type == OPND_REG8) {
        rel_output_code_byte(as, 0xED);
        rel_output_code_byte(as, 0x41 | (reg8_code(src.reg) << 3));
        return;
    }

    err_syntax(as);
}

/* ----------------------------------------------------------------
 *  DJNZ instruction
 *  DJNZ e (relative jump)
 * ---------------------------------------------------------------- */

static void instr_djnz(AsmState *as)
{
    expr_evaluate(as);

    u16 target = as->expr_saved;
    u16 pc = as->org_counter + 2;
    i16 disp = (i16)(target - pc);

    if (as->pass2 && (disp < -128 || disp > 127)) {
        err_out_of_range(as);
    }

    rel_output_code_byte(as, 0x10);
    rel_output_code_byte(as, (u8)(disp & 0xFF));
}

/* ----------------------------------------------------------------
 *  BIT / RES / SET instructions
 *  BIT b,r / BIT b,(HL) / BIT b,(IX+d) etc.
 *  cb_base: 0x40=BIT, 0x80=RES, 0xC0=SET
 * ---------------------------------------------------------------- */

static void instr_bit_res_set(AsmState *as, u8 cb_base)
{
    /* Parse bit number */
    expr_evaluate(as);
    u16 bit = as->expr_saved;
    if (bit > 7) {
        err_out_of_range(as);
        bit &= 7;
    }

    if (!expect_comma(as)) return;

    Operand op;
    parse_operand(as, &op);

    if (op.type == OPND_REG8) {
        emit_prefix(as, op.prefix);
        rel_output_code_byte(as, 0xCB);
        rel_output_code_byte(as, cb_base | ((u8)bit << 3) | reg8_code(op.reg));
        return;
    }

    if (op.type == OPND_IXIY_D) {
        emit_prefix(as, op.prefix);
        rel_output_code_byte(as, 0xCB);
        rel_output_code_byte(as, (u8)op.value); /* displacement */
        rel_output_code_byte(as, cb_base | ((u8)bit << 3) | 0x06);
        return;
    }

    err_syntax(as);
}

/* ----------------------------------------------------------------
 *  Rotate/shift instructions
 *  RLC/RRC/RL/RR/SLA/SRA/SRL r/(HL)/(IX+d)
 *  cb_base: 0x00=RLC, 0x08=RRC, 0x10=RL, 0x18=RR,
 *           0x20=SLA, 0x28=SRA, 0x38=SRL
 * ---------------------------------------------------------------- */

static void instr_rotate(AsmState *as, u8 cb_base)
{
    Operand op;
    parse_operand(as, &op);

    if (op.type == OPND_REG8) {
        emit_prefix(as, op.prefix);
        rel_output_code_byte(as, 0xCB);
        rel_output_code_byte(as, cb_base | reg8_code(op.reg));
        return;
    }

    if (op.type == OPND_IXIY_D) {
        emit_prefix(as, op.prefix);
        rel_output_code_byte(as, 0xCB);
        rel_output_code_byte(as, (u8)op.value); /* displacement */
        rel_output_code_byte(as, cb_base | 0x06);
        return;
    }

    err_syntax(as);
}

/* ----------------------------------------------------------------
 *  IM instruction
 *  IM 0 / IM 1 / IM 2
 * ---------------------------------------------------------------- */

static void instr_im(AsmState *as)
{
    expr_evaluate(as);
    u16 mode = as->expr_saved;

    rel_output_code_byte(as, 0xED);

    switch (mode) {
        case 0: rel_output_code_byte(as, 0x46); break;
        case 1: rel_output_code_byte(as, 0x56); break;
        case 2: rel_output_code_byte(as, 0x5E); break;
        default:
            err_out_of_range(as);
            rel_output_code_byte(as, 0x46);
            break;
    }
}

/* ----------------------------------------------------------------
 *  Process an instruction (called from pass after keyword lookup)
 *  Dispatches based on op_type and op_reg set by keyword search.
 * ---------------------------------------------------------------- */

void instr_process(AsmState *as)
{
    u8 dispatch = as->op_reg;
    u8 prefix = as->op_prefix;

    instr_dispatch(as, dispatch, prefix);
}
