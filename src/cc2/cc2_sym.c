/*
 * cc2_sym.c — Symbol table management for CC2
 *
 * Mirrors: A0685, A0622, symbol table operations in CCC.ASM
 * Symbol table entries are 6 bytes each, matching Z80 layout.
 */

#include "cc2_defs.h"

/* Type size table (mirrors T9ED5 in CCC.ASM) */
int type_size(int type_char)
{
    switch (type_char) {
        case 'I': return 2;
        case 'N': return 2;
        case 'R': return 2;
        case 'B': return 1;
        case 'C': return 1;
        case 'Z': return 4;
        case 'W': return 4;
        case 'Q': return 4;
        case 'H': return 8;
        default:  return 2;
    }
}

/* ----------------------------------------------------------------
 *  Initialize symbol table
 * ---------------------------------------------------------------- */
void sym_init(Cc2State *cc)
{
    memset(cc->sym, 0, sizeof(cc->sym));
    cc->sym_count = 0;
    cc->sym_ptr = 0;
}

/* ----------------------------------------------------------------
 *  Add entry to symbol table
 *  Mirrors: A0685 in CCC.ASM
 *  Returns index of new entry, or -1 on overflow
 * ---------------------------------------------------------------- */
int sym_add(Cc2State *cc, u8 type, u16 value, u16 name_id, u8 attr)
{
    if (cc->sym_count >= MAX_SYMTAB) return -1;

    int idx = cc->sym_count++;
    cc->sym[idx].type = type;
    cc->sym[idx].value = value;
    cc->sym[idx].name = name_id;
    cc->sym[idx].attr = attr;

    return idx;
}

/* ----------------------------------------------------------------
 *  Get symbol entry by index
 * ---------------------------------------------------------------- */
SymEntry *sym_get(Cc2State *cc, int index)
{
    if (index < 0 || index >= cc->sym_count) return NULL;
    return &cc->sym[index];
}

/* ----------------------------------------------------------------
 *  Find symbol by name_id
 * ---------------------------------------------------------------- */
int sym_find_by_name(Cc2State *cc, u16 name_id)
{
    int i;
    for (i = 0; i < cc->sym_count; i++) {
        if (cc->sym[i].name == name_id) return i;
    }
    return -1;
}
