/*
 * as_rel.c — REL file output generation
 *
 * The REL format is a bitstream. Data bytes are prefixed by a "0" bit
 * (absolute byte), while special link items start with "1 00" bits.
 *
 * Key routines ported from ASM1.ASM:
 *   putbit (A1938)  - write single bit to bitstream
 *   A1900           - write 9 bits (0-prefix + 8 data bits)
 *   A1904           - write 8 data bits
 *   A192F           - write "1 00" special item header
 *   put_spec_item   - write complete special link item
 */

#include "as_defs.h"

/* Write a single bit to the REL bitstream.
 * Mirrors: putbit at A1938 in ASM1.ASM */
void rel_putbit(AsmState *as, int bit)
{
    /* Rotate bit into rel_byte via carry (rl (hl)) */
    as->rel_byte = (as->rel_byte << 1) | (bit ? 1 : 0);
    as->rel_bitcount++;

    if (as->rel_bitcount == 0) {
        /* Byte is complete (8 bits collected), flush it */
        io_write_rel_byte(as, as->rel_byte);
        as->rel_bitcount = 0xF8; /* reset: need 8 more bits */
    }
}

/* Write 8 data bits (1 byte) to bitstream. MSB first.
 * Mirrors: A1904 in ASM1.ASM */
static void rel_put_8bits(AsmState *as, u8 byte)
{
    int i;
    for (i = 7; i >= 0; i--) {
        rel_putbit(as, (byte >> i) & 1);
    }
}

/* Write absolute byte: "0" prefix + 8 data bits = 9 bits.
 * Mirrors: A1900 in ASM1.ASM */
void rel_put_absolute_byte(AsmState *as, u8 byte)
{
    rel_putbit(as, 0); /* absolute marker */
    rel_put_8bits(as, byte);
}

/* Write special item header: "1 00" (3 bits).
 * seg_type bits are shifted into the two "0" positions.
 * Mirrors: A192F in ASM1.ASM */
void rel_put_special_header(AsmState *as, u8 seg_type)
{
    rel_putbit(as, 1); /* special marker */
    /* Two bits of segment type, LSB first as in original */
    rel_putbit(as, (seg_type >> 1) & 1);
    rel_putbit(as, seg_type & 1);
}

/* Write a 4-bit item code.
 * Mirrors the part of put_spec_item that outputs the item nibble. */
static void rel_put_item_code(AsmState *as, u8 item)
{
    u8 shifted = item << 4;
    int i;
    for (i = 0; i < 4; i++) {
        rel_putbit(as, (shifted >> 7) & 1);
        shifted <<= 1;
    }
}

/* Write symbol name length (3 bits for standard, 5 for extended).
 * Mirrors: putlensym / ext_putlensym in ASM1.ASM */
static void rel_put_sym_length(AsmState *as, u8 len)
{
    if (as->opt_extended_rel) {
        /* Extended: 5-bit length, max 30 */
        if (len > 30) len = 30;
        u8 shifted = len << 3; /* shift left 3 to put MSB at bit 7 */
        int i;
        for (i = 0; i < 5; i++) {
            rel_putbit(as, (shifted >> 7) & 1);
            shifted <<= 1;
        }
    } else {
        /* Standard: 3-bit length, max 6 (or 8 with -t truncation) */
        u8 maxlen = as->opt_truncate6 ? 6 : 8;
        if (len > maxlen) len = maxlen;
        u8 val = len & 7;
        rel_putbit(as, (val >> 2) & 1);
        rel_putbit(as, (val >> 1) & 1);
        rel_putbit(as, val & 1);
    }
}

/* Write a complete special LINK item to the REL bitstream.
 * Mirrors: put_spec_item in ASM1.ASM
 *
 * item: item code (0-15)
 * seg_type: segment type (bits 0-1 of 'b' register)
 * value: 16-bit value (in 'de')
 *
 * Format depends on item type:
 *   Items 0-4: have B-field (symbol name)
 *   Items 5-7: have A-field (seg+value) + B-field (symbol name)
 *   Items 8+:  have A-field only
 *   Item 15:   end of file marker (no fields)
 */
void rel_put_spec_item(AsmState *as, u8 item, u8 seg_type, u16 value)
{
    /* Write "1 00" header with seg_type=0 */
    rel_put_special_header(as, 0);

    /* Write 4-bit item code */
    rel_put_item_code(as, item);

    if (item >= 5 && item != 15) {
        /* A-field: 2-bit segment type + 16-bit value */
        rel_putbit(as, (seg_type >> 1) & 1);
        rel_putbit(as, seg_type & 1);
        rel_put_8bits(as, value & 0xFF);
        rel_put_8bits(as, (value >> 8) & 0xFF);

        /* Extended REL: extra 2 zero bytes */
        if (as->opt_extended_rel) {
            rel_put_8bits(as, 0);
            rel_put_8bits(as, 0);
        }

        if (item >= 8) return; /* A-field only items */
    }

    if (item == 15) return; /* end file - no fields */

    /* B-field: symbol name */
    /* Get symbol name from as->label_ptr area in memory */
    u16 sym_addr = as->label_ptr;
    if (sym_addr == 0) return;

    /* Symbol entry: namelen at offset 4, name at offset 10 */
    u8 *entry = &as->memory[sym_addr];
    u8 namelen = entry[4]; /* SYM_ENTRY: namelen */

    /* Write name length */
    rel_put_sym_length(as, namelen);

    /* Write name characters */
    u8 limit = namelen;
    if (!as->opt_extended_rel) {
        u8 maxlen = as->opt_truncate6 ? 6 : 8;
        if (limit > maxlen) limit = maxlen;
    } else {
        if (limit > 30) limit = 30;
    }

    int i;
    for (i = 0; i < limit; i++) {
        u8 ch = entry[10 + i];
        if (item != 4) ch &= 0x7F; /* strip high bit except for item 4 */
        rel_put_8bits(as, ch);
    }
}

/* Output a code byte during pass 2.
 * If in pass 1, just increment PC.
 * Mirrors: A1631 in ASM1.ASM */
void rel_output_code_byte(AsmState *as, u8 byte)
{
    as->org_counter++;
    if (!as->pass2) return;
    rel_put_absolute_byte(as, byte);
}

/* Output a relocatable data byte (for expressions with relocatable refs).
 * Mirrors: A1643 + A1665 in ASM1.ASM */
void rel_output_data_byte(AsmState *as, u8 byte)
{
    as->expr_flags |= 0x40;
    as->org_counter++;
    if (!as->pass2) return;

    /* Check for invalid external usage */
    if (as->expr_flags & 0x10) {
        err_external(as);
        if (!(as->expr_flags & 0x40)) {
            rel_put_absolute_byte(as, 0);
        }
        return;
    }

    /* Check for relocatable reference */
    if (as->expr_flags & 0xA0) {
        /* Complex expression with relocatable parts — output link items */
        /* This is handled by the expression evaluator chain */
        /* For now, output the byte */
    }

    rel_put_absolute_byte(as, byte);
}

/* Output a 16-bit word with relocation info.
 * Mirrors: A1735 in ASM1.ASM */
void rel_put_word(AsmState *as, u16 value, u8 seg_type)
{
    /* Record the address where this word starts (for chain external) */
    u16 word_addr = as->org_counter;

    as->org_counter += 2;
    if (!as->pass2) return;

    u8 stype = seg_type & 3;

    /* Check if expression referenced an external symbol */
    if (as->expr_ext_ptr != 0) {
        /* External reference: output absolute placeholder bytes,
         * and record the chain address in the external symbol entry */
        u8 *ext_entry = &as->memory[as->expr_ext_ptr];
        /* Store chain address: where the linker should patch */
        ext_entry[6] = word_addr & 0xFF;
        ext_entry[7] = (word_addr >> 8) & 0xFF;
        /* Output placeholder (absolute 00 00) */
        rel_put_absolute_byte(as, value & 0xFF);
        rel_put_absolute_byte(as, (value >> 8) & 0xFF);
        as->expr_ext_ptr = 0; /* consumed */
        return;
    }

    if (stype == 0) {
        /* Absolute value — output two absolute bytes */
        rel_put_absolute_byte(as, value & 0xFF);
        rel_put_absolute_byte(as, (value >> 8) & 0xFF);
    } else {
        /* Relocatable value — output with relocation record */
        rel_put_special_header(as, stype);
        rel_put_8bits(as, value & 0xFF);
        rel_put_8bits(as, (value >> 8) & 0xFF);

        if (as->opt_extended_rel) {
            rel_put_8bits(as, 0);
            rel_put_8bits(as, 0);
        }
    }
}

/* Write extended REL header bytes at start of file.
 * Mirrors: A4194 in ASM1.ASM */
static void rel_write_extended_header(AsmState *as)
{
    rel_putbit(as, 1); /* "1" bit */
    /* Write 0x21 as absolute byte (9 bits) */
    rel_put_absolute_byte(as, 0x21);
    /* Write 0xFE marker */
    rel_put_8bits(as, 0xFE);
}

/* Finalize REL output: pad to byte boundary, write end markers.
 * Mirrors: A28FE..A290C in ASM1.ASM */
void rel_finalize(AsmState *as)
{
    /* Pad current byte to boundary with zero bits.
     * Mirrors A28FE: loop putting 0-bits until byte complete. */
    while (as->rel_bitcount != 0xF8) {
        rel_putbit(as, 0);
    }

    /* Write "end file" special item (item 15): 1 00 1111 = 7 bits */
    rel_put_spec_item(as, 15, 0, 0);

    /* Pad remaining bits to byte boundary with zeros */
    while (as->rel_bitcount != 0xF8) {
        rel_putbit(as, 0);
    }

    /* Write 0xFF terminator and flush */
    io_write_rel_byte(as, 0xFF);
    io_flush_rel(as);
}

/* Initialize REL output state */
void rel_init(AsmState *as)
{
    as->rel_byte = 0;
    as->rel_bitcount = 0xF8;
    as->rel_ptr = 0;
    memset(as->outrel, 0, REL_BUF_SIZE);

    if (as->opt_extended_rel) {
        rel_write_extended_header(as);
    }
}
