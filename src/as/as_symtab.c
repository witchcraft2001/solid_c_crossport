/*
 * as_symtab.c — Symbol table management
 *
 * Keyword hash table (26 buckets A-Z), keyword lookup,
 * user symbol search and creation.
 *
 * Based on T06C8 hash table and T39A3 register table in ASM1.ASM.
 *
 * Keyword entry format (original Z80):
 *   byte 0: (length & 7) | (flags << 3)
 *   byte 1: dispatch code
 *   byte 2: prefix byte
 *   bytes 3+: remaining characters (after first letter)
 *   terminated by entry with byte0 == 0
 */

#include "as_defs.h"

/* ----------------------------------------------------------------
 *  Keyword type flags (upper bits of byte 0)
 * ---------------------------------------------------------------- */

#define KW_INSTRUCTION  0x00   /* Z80 instruction */
#define KW_DIRECTIVE    0x08   /* assembler directive */
#define KW_REGISTER     0x10   /* register name */
#define KW_CONDITION    0x18   /* condition code */
#define KW_OPERATOR     0x20   /* expression operator (AND, OR, etc.) */

/* ----------------------------------------------------------------
 *  Dispatch codes for directives
 * ---------------------------------------------------------------- */

#define DIR_ORG     0x01
#define DIR_EQU     0x02
#define DIR_DEFL    0x03
#define DIR_DB      0x04
#define DIR_DW      0x05
#define DIR_DS      0x06
#define DIR_DC      0x07
#define DIR_ASEG    0x08
#define DIR_CSEG    0x09
#define DIR_DSEG    0x0A
#define DIR_COMMON  0x0B
#define DIR_PUBLIC  0x0C
#define DIR_EXTERN  0x0D
#define DIR_ENTRY   0x0E
#define DIR_EXT     0x0F
#define DIR_NAME    0x10
#define DIR_END     0x11
#define DIR_IF      0x12
#define DIR_ELSE    0x13
#define DIR_ENDIF   0x14
#define DIR_MACRO   0x15
#define DIR_ENDM    0x16
#define DIR_REPT    0x17
#define DIR_IRP     0x18
#define DIR_IRPC    0x19
#define DIR_EXITM   0x1A
#define DIR_LOCAL   0x1B
#define DIR_PHASE   0x1C
#define DIR_DEPHASE 0x1D
#define DIR_RADIX   0x1E
#define DIR_PAGE    0x1F
#define DIR_TITLE   0x20
#define DIR_SUBTTL  0x21
#define DIR_INCLUDE 0x22
#define DIR_COND    0x23  /* .COND */
#define DIR_NOCOND  0x24  /* .NOCOND */
#define DIR_LIST    0x25
#define DIR_XLIST   0x26
#define DIR_SET     0x27

/* ----------------------------------------------------------------
 *  Register codes (dispatch byte for register keywords)
 * ---------------------------------------------------------------- */

#define REG_B     0x00
#define REG_C     0x01
#define REG_D     0x02
#define REG_E     0x03
#define REG_H     0x04
#define REG_L     0x05
#define REG_M     0x06   /* (HL) */
#define REG_A     0x07
#define REG_I     0x08
#define REG_R     0x09
#define REG_BC    0x10
#define REG_DE    0x11
#define REG_HL    0x12
#define REG_SP    0x13
#define REG_AF    0x14
#define REG_IX    0x15
#define REG_IY    0x16
#define REG_IXH   0x17
#define REG_IXL   0x18
#define REG_IYH   0x19
#define REG_IYL   0x1A

/* Condition codes */
#define CC_NZ     0x00
#define CC_Z      0x01
#define CC_NC     0x02
#define CC_C      0x03
#define CC_PO     0x04
#define CC_PE     0x05
#define CC_P      0x06
#define CC_M      0x07

/* ----------------------------------------------------------------
 *  Expression operator codes
 * ---------------------------------------------------------------- */

#define OP_NOT    0x01
#define OP_HIGH   0x02
#define OP_LOW    0x03
#define OP_MOD    0x04
#define OP_SHL    0x05
#define OP_SHR    0x06
#define OP_AND    0x07
#define OP_OR     0x08
#define OP_XOR    0x09
#define OP_EQ     0x0A
#define OP_NE     0x0B
#define OP_LT     0x0C
#define OP_LE     0x0D
#define OP_GT     0x0E
#define OP_GE     0x0F
#define OP_NUL    0x10
#define OP_TYPE   0x11

/* ----------------------------------------------------------------
 *  Instruction dispatch codes (L0AD6 / L0B52 equivalent)
 * ---------------------------------------------------------------- */

#define INSTR_NOP     0x00
#define INSTR_LD      0x01
#define INSTR_INC     0x02
#define INSTR_DEC     0x03
#define INSTR_ADD     0x04
#define INSTR_ADC     0x05
#define INSTR_SUB     0x06
#define INSTR_SBC     0x07
#define INSTR_AND     0x08
#define INSTR_XOR     0x09
#define INSTR_OR      0x0A
#define INSTR_CP      0x0B
#define INSTR_JP      0x0C
#define INSTR_JR      0x0D
#define INSTR_CALL    0x0E
#define INSTR_RET     0x0F
#define INSTR_RST     0x10
#define INSTR_PUSH    0x11
#define INSTR_POP     0x12
#define INSTR_EX      0x13
#define INSTR_IN      0x14
#define INSTR_OUT     0x15
#define INSTR_DJNZ    0x16
#define INSTR_BIT     0x17
#define INSTR_RES     0x18
#define INSTR_SET     0x19
#define INSTR_RLC     0x1A
#define INSTR_RRC     0x1B
#define INSTR_RL      0x1C
#define INSTR_RR      0x1D
#define INSTR_SLA     0x1E
#define INSTR_SRA     0x1F
#define INSTR_SRL     0x20
#define INSTR_IM      0x21
/* Simple (no operand) instructions — dispatch code is the opcode itself */
#define INSTR_SIMPLE  0x40

/* ----------------------------------------------------------------
 *  Keyword definition structure
 * ---------------------------------------------------------------- */

typedef struct {
    const char *name;       /* full keyword name (uppercase) */
    u8  kw_type;            /* KW_INSTRUCTION, KW_DIRECTIVE, etc. */
    u8  dispatch;           /* dispatch code or opcode */
    u8  prefix;             /* prefix byte (0xCB, 0xED, or 0x00) */
} KeywordDef;

/* ----------------------------------------------------------------
 *  Runtime keyword entry in hash chain
 * ---------------------------------------------------------------- */

typedef struct KwEntry {
    struct KwEntry *next;
    const char *name;
    u8  namelen;
    u8  kw_type;
    u8  dispatch;
    u8  prefix;
} KwEntry;

/* 26 hash buckets, indexed by first letter A=0 .. Z=25 */
static KwEntry *kw_hash[26];

/* ----------------------------------------------------------------
 *  Complete keyword table
 * ---------------------------------------------------------------- */

static const KeywordDef keyword_table[] = {
    /* Z80 instructions — simple (no operands) */
    {"NOP",    KW_INSTRUCTION, INSTR_SIMPLE, 0x00},
    {"RLCA",   KW_INSTRUCTION, INSTR_SIMPLE, 0x07},
    {"RRCA",   KW_INSTRUCTION, INSTR_SIMPLE, 0x0F},
    {"RLA",    KW_INSTRUCTION, INSTR_SIMPLE, 0x17},
    {"RRA",    KW_INSTRUCTION, INSTR_SIMPLE, 0x1F},
    {"DAA",    KW_INSTRUCTION, INSTR_SIMPLE, 0x27},
    {"CPL",    KW_INSTRUCTION, INSTR_SIMPLE, 0x2F},
    {"SCF",    KW_INSTRUCTION, INSTR_SIMPLE, 0x37},
    {"CCF",    KW_INSTRUCTION, INSTR_SIMPLE, 0x3F},
    {"HALT",   KW_INSTRUCTION, INSTR_SIMPLE, 0x76},
    {"EXX",    KW_INSTRUCTION, INSTR_SIMPLE, 0xD9},
    {"DI",     KW_INSTRUCTION, INSTR_SIMPLE, 0xF3},
    {"EI",     KW_INSTRUCTION, INSTR_SIMPLE, 0xFB},

    /* ED-prefixed simple instructions */
    {"NEG",    KW_INSTRUCTION, INSTR_SIMPLE, 0x44},  /* ED prefix handled separately */
    {"RETN",   KW_INSTRUCTION, INSTR_SIMPLE, 0x45},
    {"RETI",   KW_INSTRUCTION, INSTR_SIMPLE, 0x4D},
    {"RRD",    KW_INSTRUCTION, INSTR_SIMPLE, 0x67},
    {"RLD",    KW_INSTRUCTION, INSTR_SIMPLE, 0x6F},
    {"LDI",    KW_INSTRUCTION, INSTR_SIMPLE, 0xA0},
    {"CPI",    KW_INSTRUCTION, INSTR_SIMPLE, 0xA1},
    {"INI",    KW_INSTRUCTION, INSTR_SIMPLE, 0xA2},
    {"OUTI",   KW_INSTRUCTION, INSTR_SIMPLE, 0xA3},
    {"LDD",    KW_INSTRUCTION, INSTR_SIMPLE, 0xA8},
    {"CPD",    KW_INSTRUCTION, INSTR_SIMPLE, 0xA9},
    {"IND",    KW_INSTRUCTION, INSTR_SIMPLE, 0xAA},
    {"OUTD",   KW_INSTRUCTION, INSTR_SIMPLE, 0xAB},
    {"LDIR",   KW_INSTRUCTION, INSTR_SIMPLE, 0xB0},
    {"CPIR",   KW_INSTRUCTION, INSTR_SIMPLE, 0xB1},
    {"INIR",   KW_INSTRUCTION, INSTR_SIMPLE, 0xB2},
    {"OTIR",   KW_INSTRUCTION, INSTR_SIMPLE, 0xB3},
    {"LDDR",   KW_INSTRUCTION, INSTR_SIMPLE, 0xB8},
    {"CPDR",   KW_INSTRUCTION, INSTR_SIMPLE, 0xB9},
    {"INDR",   KW_INSTRUCTION, INSTR_SIMPLE, 0xBA},
    {"OTDR",   KW_INSTRUCTION, INSTR_SIMPLE, 0xBB},

    /* Z80 instructions — with operands */
    {"LD",     KW_INSTRUCTION, INSTR_LD,     0x00},
    {"INC",    KW_INSTRUCTION, INSTR_INC,    0x00},
    {"DEC",    KW_INSTRUCTION, INSTR_DEC,    0x00},
    {"ADD",    KW_INSTRUCTION, INSTR_ADD,    0x00},
    {"ADC",    KW_INSTRUCTION, INSTR_ADC,    0x00},
    {"SUB",    KW_INSTRUCTION, INSTR_SUB,    0x00},
    {"SBC",    KW_INSTRUCTION, INSTR_SBC,    0x00},
    {"AND",    KW_INSTRUCTION, INSTR_AND,    0x00},
    {"XOR",    KW_INSTRUCTION, INSTR_XOR,    0x00},
    {"OR",     KW_INSTRUCTION, INSTR_OR,     0x00},
    {"CP",     KW_INSTRUCTION, INSTR_CP,     0x00},
    {"JP",     KW_INSTRUCTION, INSTR_JP,     0x00},
    {"JR",     KW_INSTRUCTION, INSTR_JR,     0x00},
    {"CALL",   KW_INSTRUCTION, INSTR_CALL,   0x00},
    {"RET",    KW_INSTRUCTION, INSTR_RET,    0x00},
    {"RST",    KW_INSTRUCTION, INSTR_RST,    0x00},
    {"PUSH",   KW_INSTRUCTION, INSTR_PUSH,   0x00},
    {"POP",    KW_INSTRUCTION, INSTR_POP,    0x00},
    {"EX",     KW_INSTRUCTION, INSTR_EX,     0x00},
    {"IN",     KW_INSTRUCTION, INSTR_IN,     0x00},
    {"OUT",    KW_INSTRUCTION, INSTR_OUT,    0x00},
    {"DJNZ",   KW_INSTRUCTION, INSTR_DJNZ,  0x00},
    {"BIT",    KW_INSTRUCTION, INSTR_BIT,    0x00},
    {"RES",    KW_INSTRUCTION, INSTR_RES,    0x00},
    {"SET",    KW_INSTRUCTION, INSTR_SET,    0x00},
    {"RLC",    KW_INSTRUCTION, INSTR_RLC,    0x00},
    {"RRC",    KW_INSTRUCTION, INSTR_RRC,    0x00},
    {"RL",     KW_INSTRUCTION, INSTR_RL,     0x00},
    {"RR",     KW_INSTRUCTION, INSTR_RR,     0x00},
    {"SLA",    KW_INSTRUCTION, INSTR_SLA,    0x00},
    {"SRA",    KW_INSTRUCTION, INSTR_SRA,    0x00},
    {"SRL",    KW_INSTRUCTION, INSTR_SRL,    0x00},
    {"IM",     KW_INSTRUCTION, INSTR_IM,     0x00},

    /* Assembler directives */
    {"ORG",     KW_DIRECTIVE, DIR_ORG,     0x00},
    {"EQU",     KW_DIRECTIVE, DIR_EQU,     0x00},
    {"DEFL",    KW_DIRECTIVE, DIR_DEFL,    0x00},
    {"DB",      KW_DIRECTIVE, DIR_DB,      0x00},
    {"DW",      KW_DIRECTIVE, DIR_DW,      0x00},
    {"DS",      KW_DIRECTIVE, DIR_DS,      0x00},
    {"DC",      KW_DIRECTIVE, DIR_DC,      0x00},
    {"DEFB",    KW_DIRECTIVE, DIR_DB,      0x00},
    {"DEFW",    KW_DIRECTIVE, DIR_DW,      0x00},
    {"DEFS",    KW_DIRECTIVE, DIR_DS,      0x00},
    {"ASEG",    KW_DIRECTIVE, DIR_ASEG,    0x00},
    {"CSEG",    KW_DIRECTIVE, DIR_CSEG,    0x00},
    {"DSEG",    KW_DIRECTIVE, DIR_DSEG,    0x00},
    {"COMMON",  KW_DIRECTIVE, DIR_COMMON,  0x00},
    {"PUBLIC",  KW_DIRECTIVE, DIR_PUBLIC,  0x00},
    {"GLOBAL",  KW_DIRECTIVE, DIR_PUBLIC,  0x00},
    {"EXTERN",  KW_DIRECTIVE, DIR_EXTERN,  0x00},
    {"EXTRN",   KW_DIRECTIVE, DIR_EXTERN,  0x00},
    {"ENTRY",   KW_DIRECTIVE, DIR_ENTRY,   0x00},
    {"EXT",     KW_DIRECTIVE, DIR_EXT,     0x00},
    {"NAME",    KW_DIRECTIVE, DIR_NAME,    0x00},
    {"END",     KW_DIRECTIVE, DIR_END,     0x00},
    {"IF",      KW_DIRECTIVE, DIR_IF,      0x00},
    {"ELSE",    KW_DIRECTIVE, DIR_ELSE,    0x00},
    {"ENDIF",   KW_DIRECTIVE, DIR_ENDIF,   0x00},
    {"MACRO",   KW_DIRECTIVE, DIR_MACRO,   0x00},
    {"ENDM",    KW_DIRECTIVE, DIR_ENDM,    0x00},
    {"REPT",    KW_DIRECTIVE, DIR_REPT,    0x00},
    {"IRP",     KW_DIRECTIVE, DIR_IRP,     0x00},
    {"IRPC",    KW_DIRECTIVE, DIR_IRPC,    0x00},
    {"EXITM",   KW_DIRECTIVE, DIR_EXITM,   0x00},
    {"LOCAL",   KW_DIRECTIVE, DIR_LOCAL,   0x00},
    {"INCLUDE", KW_DIRECTIVE, DIR_INCLUDE, 0x00},
    /* Note: SET is both a Z80 instruction (SET bit,reg) and a
     * re-definable equate (label SET expr). The Z80 instruction
     * is handled above as INSTR_SET. The directive form is
     * detected in pass_process_line when preceded by a label. */

    /* Dot-prefixed directives (handled as keywords with '.' prefix removed) */
    {".PHASE",   KW_DIRECTIVE, DIR_PHASE,   0x00},
    {".DEPHASE", KW_DIRECTIVE, DIR_DEPHASE, 0x00},
    {".RADIX",   KW_DIRECTIVE, DIR_RADIX,   0x00},
    {".PAGE",    KW_DIRECTIVE, DIR_PAGE,    0x00},
    {".TITLE",   KW_DIRECTIVE, DIR_TITLE,   0x00},
    {".SUBTTL",  KW_DIRECTIVE, DIR_SUBTTL,  0x00},
    {".COND",    KW_DIRECTIVE, DIR_COND,    0x00},
    {".NOCOND",  KW_DIRECTIVE, DIR_NOCOND,  0x00},
    {".LIST",    KW_DIRECTIVE, DIR_LIST,    0x00},
    {".XLIST",   KW_DIRECTIVE, DIR_XLIST,   0x00},

    /* Register names (T39A3) */
    {"A",   KW_REGISTER, REG_A,   0x00},
    {"B",   KW_REGISTER, REG_B,   0x00},
    {"C",   KW_REGISTER, REG_C,   0x00},
    {"D",   KW_REGISTER, REG_D,   0x00},
    {"E",   KW_REGISTER, REG_E,   0x00},
    {"H",   KW_REGISTER, REG_H,   0x00},
    {"L",   KW_REGISTER, REG_L,   0x00},
    {"M",   KW_REGISTER, REG_M,   0x00},
    {"I",   KW_REGISTER, REG_I,   0x00},
    {"R",   KW_REGISTER, REG_R,   0x00},
    {"BC",  KW_REGISTER, REG_BC,  0x00},
    {"DE",  KW_REGISTER, REG_DE,  0x00},
    {"HL",  KW_REGISTER, REG_HL,  0x00},
    {"SP",  KW_REGISTER, REG_SP,  0x00},
    {"AF",  KW_REGISTER, REG_AF,  0x00},
    {"IX",  KW_REGISTER, REG_IX,  0xDD},
    {"IY",  KW_REGISTER, REG_IY,  0xFD},

    /* Undocumented register halves */
    {"IXH",  KW_REGISTER, REG_IXH, 0xDD},
    {"IYH",  KW_REGISTER, REG_IYH, 0xFD},
    {"IXL",  KW_REGISTER, REG_IXL, 0xDD},
    {"IYL",  KW_REGISTER, REG_IYL, 0xFD},
    {"HX",   KW_REGISTER, REG_IXH, 0xDD},
    {"HY",   KW_REGISTER, REG_IYH, 0xFD},
    {"LX",   KW_REGISTER, REG_IXL, 0xDD},
    {"LY",   KW_REGISTER, REG_IYL, 0xFD},
    {"XH",   KW_REGISTER, REG_IXH, 0xDD},
    {"YH",   KW_REGISTER, REG_IYH, 0xFD},
    {"XL",   KW_REGISTER, REG_IXL, 0xDD},
    {"YL",   KW_REGISTER, REG_IYL, 0xFD},

    /* Condition codes */
    {"NZ",  KW_CONDITION, CC_NZ,  0x00},
    {"Z",   KW_CONDITION, CC_Z,   0x00},
    {"NC",  KW_CONDITION, CC_NC,  0x00},
    {"PO",  KW_CONDITION, CC_PO,  0x00},
    {"PE",  KW_CONDITION, CC_PE,  0x00},
    {"P",   KW_CONDITION, CC_P,   0x00},
    {"M",   KW_CONDITION, CC_M,   0x00},

    /* Expression operator keywords
     * Note: AND, OR, XOR are handled as Z80 instructions above.
     * The expression evaluator handles them specially when parsing
     * expressions. They are NOT duplicated here to avoid hash collisions. */
    {"NOT",  KW_OPERATOR, OP_NOT,  0x00},
    {"HIGH", KW_OPERATOR, OP_HIGH, 0x00},
    {"LOW",  KW_OPERATOR, OP_LOW,  0x00},
    {"MOD",  KW_OPERATOR, OP_MOD,  0x00},
    {"SHL",  KW_OPERATOR, OP_SHL,  0x00},
    {"SHR",  KW_OPERATOR, OP_SHR,  0x00},
    {"EQ",   KW_OPERATOR, OP_EQ,   0x00},
    {"NE",   KW_OPERATOR, OP_NE,   0x00},
    {"LT",   KW_OPERATOR, OP_LT,   0x00},
    {"LE",   KW_OPERATOR, OP_LE,   0x00},
    {"GT",   KW_OPERATOR, OP_GT,   0x00},
    {"GE",   KW_OPERATOR, OP_GE,   0x00},
    {"NUL",  KW_OPERATOR, OP_NUL,  0x00},
    {"TYPE", KW_OPERATOR, OP_TYPE, 0x00},

    {NULL, 0, 0, 0}  /* sentinel */
};

/* ----------------------------------------------------------------
 *  Initialize keyword hash table
 * ---------------------------------------------------------------- */

void sym_init_keywords(AsmState *as)
{
    int i;
    const KeywordDef *kd;

    /* Clear hash buckets */
    for (i = 0; i < 26; i++) {
        kw_hash[i] = NULL;
    }

    /* Insert all keywords */
    for (kd = keyword_table; kd->name != NULL; kd++) {
        const char *name = kd->name;
        int bucket;

        /* Handle dot-prefixed names: hash by second character */
        if (name[0] == '.') {
            if (name[1] >= 'A' && name[1] <= 'Z')
                bucket = name[1] - 'A';
            else
                continue; /* skip invalid */
        } else {
            if (name[0] >= 'A' && name[0] <= 'Z')
                bucket = name[0] - 'A';
            else
                continue; /* skip invalid */
        }

        KwEntry *entry = (KwEntry *)malloc(sizeof(KwEntry));
        if (!entry) {
            fatal_error(as, "Out of memory for keyword table");
            return;
        }
        entry->name = name;
        entry->namelen = (u8)strlen(name);
        entry->kw_type = kd->kw_type;
        entry->dispatch = kd->dispatch;
        entry->prefix = kd->prefix;

        /* Insert at head of chain */
        entry->next = kw_hash[bucket];
        kw_hash[bucket] = entry;
    }

    /* Initialize user symbol hash tables */
    for (i = 0; i < 33; i++) {
        as->sym_lookup1[i] = 0;
        as->sym_lookup2[i] = 0;
    }

    as->symtab_free = 0x100; /* start of user symbol area in memory[] */

    (void)as; /* used for error reporting */
}

/* ----------------------------------------------------------------
 *  Search keyword hash table
 *
 *  Looks up as->idname[0..idlen-1] in the keyword table.
 *  Returns 1 if found, 0 if not found.
 *  On match, sets:
 *    as->op_type = kw_type
 *    as->op_reg  = dispatch code
 *    as->op_prefix = prefix
 * ---------------------------------------------------------------- */

int sym_search_keyword(AsmState *as)
{
    if (as->idlen == 0) return 0;

    u8 first = as->idname[0];
    int bucket;

    if (first == '.') {
        /* Dot-prefixed directive: hash by second char */
        if (as->idlen < 2) return 0;
        u8 second = as->idname[1];
        if (second < 'A' || second > 'Z') return 0;
        bucket = second - 'A';
    } else {
        if (first < 'A' || first > 'Z') return 0;
        bucket = first - 'A';
    }

    KwEntry *entry = kw_hash[bucket];
    while (entry) {
        if (entry->namelen == as->idlen) {
            /* Compare names */
            int match = 1;
            int i;
            for (i = 0; i < as->idlen; i++) {
                u8 c1 = as->idname[i];
                u8 c2 = (u8)entry->name[i];
                if (c1 != c2) { match = 0; break; }
            }
            if (match) {
                as->op_type = entry->kw_type;
                as->op_reg = entry->dispatch;
                as->op_prefix = entry->prefix;
                return 1;
            }
        }
        entry = entry->next;
    }

    return 0;
}

/* ----------------------------------------------------------------
 *  User symbol table operations
 *
 *  Symbols are stored in as->memory[] starting at offset 0x100.
 *  Each entry layout:
 *    +0,+1: next pointer (u16, 0=end)
 *    +2,+3: secondary pointer (u16)
 *    +4:    name length
 *    +5:    attribute byte
 *    +6,+7: value (u16)
 *    +8,+9: extra (u16)
 *    +10..: name characters
 *
 *  Hash chains use sym_lookup1[0..32] indexed by
 *  a simple hash of the symbol name.
 * ---------------------------------------------------------------- */

/* Compute hash index for user symbol (0..32) */
static int sym_hash(AsmState *as)
{
    if (as->idlen == 0) return 0;
    /* Hash based on first character and length, matching original */
    int h = (as->idname[0] - 'A' + 1) & 0x1F;
    if (h < 0) h = 0;
    if (h > 32) h = 32;
    return h;
}

/* Read a u16 from memory[] at offset */
static u16 mem_read16(AsmState *as, u16 offset)
{
    return (u16)as->memory[offset] | ((u16)as->memory[offset + 1] << 8);
}

/* Write a u16 to memory[] at offset */
static void mem_write16(AsmState *as, u16 offset, u16 val)
{
    as->memory[offset]     = val & 0xFF;
    as->memory[offset + 1] = (val >> 8) & 0xFF;
}

/* Search user symbol table for as->idname.
 * Returns 1 if found, 0 if not found.
 * Sets as->label_ptr to the entry offset on success.
 * Sets as->tree_hash_ptr to the hash chain head pointer location. */
int sym_search_user(AsmState *as)
{
    int h = sym_hash(as);
    as->tree_hash_ptr = (u16)(h * 2); /* index into sym_lookup1 */

    u16 ptr = as->sym_lookup1[h];
    while (ptr != 0) {
        u8 *entry = &as->memory[ptr];
        u8 namelen = entry[4];

        if (namelen == as->idlen) {
            int match = 1;
            int i;
            for (i = 0; i < namelen && i < MAX_ID_LEN; i++) {
                if (entry[10 + i] != as->idname[i]) {
                    match = 0;
                    break;
                }
            }
            if (match) {
                as->label_ptr = ptr;
                return 1;
            }
        }

        /* Follow chain */
        ptr = mem_read16(as, ptr); /* next pointer at +0 */
    }

    return 0;
}

/* Add a new symbol entry to the user symbol table.
 * Uses as->idname/idlen for the name.
 * carry_flag: if nonzero, mark as external.
 * Sets as->label_ptr to the new entry. */
void sym_add_entry(AsmState *as, int carry_flag)
{
    u16 free = as->symtab_free;
    int entry_size = SYM_ENTRY_OVERHEAD + as->idlen;

    /* Check if we have room */
    if (free + entry_size >= (u16)(as->memory_size - 256)) {
        fatal_error(as, "Symbol table full");
        return;
    }

    u8 *entry = &as->memory[free];

    /* Clear entry */
    memset(entry, 0, entry_size);

    /* Set name */
    entry[4] = as->idlen;
    memcpy(&entry[10], as->idname, as->idlen);

    /* Set attribute */
    if (carry_flag) {
        entry[5] = SYM_EXTERN; /* external */
    }

    /* Link into hash chain */
    int h = sym_hash(as);
    u16 old_head = as->sym_lookup1[h];
    mem_write16(as, free, old_head);     /* next = old head */
    as->sym_lookup1[h] = free;

    as->label_ptr = free;
    as->symtab_free = free + (u16)entry_size;
}

/* Define a label at current location.
 * attr: attribute bits to set (typically SYM_DEFINED | segment).
 * Checks for redefinition and phase errors. */
void sym_define_label(AsmState *as, u8 attr)
{
    u16 ptr = as->label_ptr;
    if (ptr == 0) return;

    u8 *entry = &as->memory[ptr];
    u8 old_attr = entry[5];
    u16 old_value = mem_read16(as, ptr + 6);

    if (as->pass2) {
        /* Pass 2: check for phase error */
        if ((old_attr & SYM_DEFINED) &&
            old_value != as->org_counter) {
            err_phase(as);
        }
        /* Update value */
        mem_write16(as, ptr + 6, as->org_counter);
        return;
    }

    /* Pass 1 */
    if (old_attr & SYM_DEFINED) {
        /* Already defined — multiply defined */
        if (old_attr & SYM_PASS1DEF) {
            entry[5] |= SYM_MULDEF;
            err_duplicate(as);
            return;
        }
    }

    /* Mark as defined in pass 1 */
    entry[5] = (old_attr & ~0x07) | attr | SYM_DEFINED | SYM_PASS1DEF;
    entry[5] = (entry[5] & ~0x07) | (as->seg_type & 0x07);
    mem_write16(as, ptr + 6, as->org_counter);
}

/* Get current PC (program counter / location counter) */
u16 sym_get_pc(AsmState *as)
{
    if (as->phase_active) {
        return as->org_counter + as->phase_offset;
    }
    return as->org_counter;
}

/* Get current segment type */
u8 sym_get_seg_type(AsmState *as)
{
    if (as->phase_active) {
        return as->phase_seg;
    }
    return as->seg_type;
}
