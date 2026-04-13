/*
 * ol_rel.c — REL bitstream reader and writer
 *
 * Reader mirrors: A0AD9, A0AEE, A0AF0, A0AFC, A0B18, A0B69, A0B7E, A0D02
 * Writer mirrors: A09B3, A09BE, A09C2, A09CF, A09DB, A0C17, A0C3F, A0C59, put_item
 */

#include "ol_defs.h"

/* ================================================================
 *  REL BITSTREAM READER
 * ================================================================ */

/* Read one bit from REL bitstream.
 * Mirrors: A0AD9 in OL1.ASM
 *
 * The bit counter starts at 0xF8 and increments to 0x00 (8 bits).
 * When counter wraps to 0, a new byte is read from the file.
 */
int rel_read_bit(OlState *ol)
{
    u8 *byte_p = &ol->rd.cur_byte;
    ol->rd.bit_count++;

    if (ol->rd.bit_count == 0) {
        /* Need fresh byte from file */
        *byte_p = io_read_byte(ol);
        ol->rd.bit_count = 0xF8;
    }

    /* Shift left and return the carry (bit 7) */
    int bit = (*byte_p >> 7) & 1;
    *byte_p <<= 1;
    return bit;
}

/* Read N bits from bitstream, MSB first.
 * Mirrors: A0AF0 in OL1.ASM */
u8 rel_read_bits(OlState *ol, int count)
{
    u8 val = 0;
    int i;
    for (i = 0; i < count; i++) {
        val = (val << 1) | rel_read_bit(ol);
    }
    return val;
}

/* Read 8 bits (1 byte) from bitstream.
 * Mirrors: A0AEE in OL1.ASM */
u8 rel_read_byte(OlState *ol)
{
    return rel_read_bits(ol, 8);
}

/* Read 2 bytes (16-bit value) from bitstream.
 * Mirrors: A0B7E in OL1.ASM
 * Stores seg type, returns value in little-endian order. */
u16 rel_read_value(OlState *ol)
{
    u8 lo = rel_read_byte(ol);
    u8 hi = rel_read_byte(ol);
    return (u16)lo | ((u16)hi << 8);
}

/* Read name length from bitstream.
 * Mirrors: A0B69 in OL1.ASM
 * Standard: 3 bits, 0 means 8.
 * Extended: 5 bits. */
int rel_read_name_length(OlState *ol)
{
    if (ol->extnd_rel) {
        return rel_read_bits(ol, 5);
    } else {
        int len = rel_read_bits(ol, 3);
        if (len == 0) len = 8;
        return len;
    }
}

/* Read one complete item from REL bitstream.
 * Mirrors: A0AFC + A0D02 in OL1.ASM
 *
 * Returns:
 *   ITEM_BYTE    — absolute byte in item->byte_val
 *   ITEM_WORD    — relocatable word in item->word_val, item->seg_type
 *   ITEM_SPECIAL — special item in item->item_code, item->seg_type,
 *                  item->word_val (A-field), item->field_b (B-field)
 */
int rel_read_item(OlState *ol, RelItem *item)
{
    memset(item, 0, sizeof(*item));

    /* Read first bit: 0=absolute byte, 1=relocatable/special */
    int bit = rel_read_bit(ol);

    if (bit == 0) {
        /* Absolute byte */
        item->type = ITEM_BYTE;
        item->byte_val = rel_read_byte(ol);
        return ITEM_BYTE;
    }

    /* Read 2-bit segment type */
    u8 seg = rel_read_bits(ol, 2);

    if (seg != 0) {
        /* Relocatable word: seg=1(cseg), 2(dseg), 3(common) */
        item->type = ITEM_WORD;
        item->seg_type = seg;
        ol->type_seg = seg;
        item->word_val = rel_read_value(ol);

        /* Extended REL: skip extra 2 bytes */
        if (ol->extnd_rel) {
            rel_read_byte(ol);
            rel_read_byte(ol);
        }
        return ITEM_WORD;
    }

    /* Special item: seg=0, read 4-bit item code */
    u8 code = rel_read_bits(ol, 4);
    item->type = ITEM_SPECIAL;
    item->item_code = code;
    item->seg_type = 0;

    /* A-field present for items 5-14 */
    if (code >= 5 && code != 15) {
        u8 a_seg = rel_read_bits(ol, 2);
        item->seg_type = a_seg;
        ol->type_seg = a_seg;
        item->word_val = rel_read_value(ol);

        /* Extended REL: skip extra 2 bytes */
        if (ol->extnd_rel) {
            rel_read_byte(ol);
            rel_read_byte(ol);
        }

        /* Items 9-14 have A-field only (no B-field) */
        if (code >= 9) {
            /* Item 14: end of program module - reset to force fresh byte read.
             * Mirrors: A0B55..A0B60: ld hl,0FF00h; ld (D0D1E),hl */
            if (code == 14) {
                ol->rd.cur_byte = 0;
                ol->rd.bit_count = 0xFF;
            }
            goto check_item4;
        }
    }

    if (code == 15) {
        /* End of file — no fields */
        goto check_item4;
    }

    /* B-field: name (items 0-8 except 8+) */
    {
        int namelen = rel_read_name_length(ol);
        item->field_b_len = (u8)namelen;

        int i;
        for (i = 0; i < namelen; i++) {
            item->field_b[i] = rel_read_byte(ol);
        }

        /* Also store in OlState for other routines */
        ol->field_b_len = item->field_b_len;
        memcpy(ol->field_b, item->field_b, namelen);
    }

check_item4:
    /* Check for extended REL format marker (item 4, name byte = 0xFE)
     * Mirrors: A0D02..A0D1C */
    if (code == 4) {
        if (item->field_b_len > 0 && (item->field_b[0] & 0xFC) == 0xFC) {
            ol->extnd_rel = 1;
        }
    }

    /* Store item value for external use */
    ol->item_value = item->word_val;
    ol->type_seg = item->seg_type;

    return ITEM_SPECIAL;
}


/* ================================================================
 *  REL BITSTREAM WRITER
 * ================================================================ */

/* Write one bit to REL output bitstream.
 * Mirrors: A09DB in OL1.ASM */
void rel_write_bit(OlState *ol, int bit)
{
    ol->wr.cur_byte = (ol->wr.cur_byte << 1) | (bit ? 1 : 0);
    ol->wr.bit_count++;

    if (ol->wr.bit_count == 0) {
        /* Byte complete, flush */
        io_write_byte(ol, ol->wr.cur_byte);
        ol->wr.cur_byte = 0;
        ol->wr.bit_count = 0xF8;
    }
}

/* Write 8 bits (1 byte) MSB first.
 * Mirrors: A09C2 in OL1.ASM */
void rel_write_byte_bits(OlState *ol, u8 byte)
{
    int i;
    for (i = 7; i >= 0; i--) {
        rel_write_bit(ol, (byte >> i) & 1);
    }
}

/* Write N bits from val, MSB first.
 * Mirrors: A0C59 in OL1.ASM
 * val is pre-rotated: bits are in positions [7..7-nbits+1] */
void rel_write_value_bits(OlState *ol, u8 val, int nbits)
{
    /* Rotate val right by nbits to align, then shift out MSB first */
    u8 d = val;
    int i;
    /* Pre-rotate: rrc d, nbits times */
    for (i = 0; i < nbits; i++) {
        int lsb = d & 1;
        d = (d >> 1) | (lsb << 7);
    }
    /* Now shift out MSB first, nbits times */
    for (i = 0; i < nbits; i++) {
        int msb = (d >> 7) & 1;
        d <<= 1;
        rel_write_bit(ol, msb);
    }
}

/* Write absolute byte: "0" + 8 data bits.
 * Mirrors: A09BE in OL1.ASM */
void rel_write_abs_byte(OlState *ol, u8 byte)
{
    rel_write_bit(ol, 0);
    rel_write_byte_bits(ol, byte);
}

/* Write relocatable word: "1" + 2-bit seg + 16-bit value.
 * Mirrors: A09B3 + A09CF in OL1.ASM */
void rel_write_rel_word(OlState *ol, u16 val, u8 seg)
{
    /* Write "1 XX" header (3 bits) */
    rel_write_bit(ol, 1);
    rel_write_bit(ol, (seg >> 1) & 1);
    rel_write_bit(ol, seg & 1);
    /* 16-bit value, low byte first */
    rel_write_byte_bits(ol, val & 0xFF);
    rel_write_byte_bits(ol, (val >> 8) & 0xFF);
}

/* Write special item header "1 00" with seg=0.
 * Mirrors: A09CF with b=0 */
void rel_write_special_header(OlState *ol, u8 seg)
{
    rel_write_bit(ol, 1);
    rel_write_bit(ol, (seg >> 1) & 1);
    rel_write_bit(ol, seg & 1);
}

/* Pad to byte boundary with 0-bits.
 * For item 14 end-of-program padding. */
void rel_write_pad_to_boundary(OlState *ol)
{
    while (ol->wr.bit_count != 0xF8) {
        rel_write_bit(ol, 0);
    }
}

/* Write a complete special item to REL output.
 * Mirrors: put_item in OL1.ASM
 *
 * Reconstructs the item from the parsed RelItem structure.
 */
void rel_write_item(OlState *ol, const RelItem *item)
{
    u8 code = item->item_code;

    /* "1 00" header */
    rel_write_special_header(ol, 0);

    /* 4-bit item code */
    rel_write_value_bits(ol, code, 4);

    /* A-field for items 5-14 */
    if (code >= 5 && code != 15) {
        /* 2-bit segment type */
        rel_write_value_bits(ol, item->seg_type, 2);
        /* 16-bit value, low byte first */
        rel_write_byte_bits(ol, item->word_val & 0xFF);
        rel_write_byte_bits(ol, (item->word_val >> 8) & 0xFF);
        /* Extended: extra 2 zero bytes */
        if (ol->extnd_rel) {
            rel_write_byte_bits(ol, 0);
            rel_write_byte_bits(ol, 0);
        }

        /* Item 14 (end program): pad to byte boundary + reset extnd_rel */
        if (code == 14) {
            rel_write_pad_to_boundary(ol);
            ol->extnd_rel = 0;
            return;
        }

        /* Items 9+ have A-field only */
        if (code >= 9) return;
    }

    /* End of file (item 15): no fields */
    if (code == 15) return;

    /* B-field: name length + name bytes */
    {
        u8 namelen = item->field_b_len;

        if (ol->extnd_rel) {
            /* 5-bit length */
            rel_write_value_bits(ol, namelen, 5);
        } else {
            /* 3-bit length (0 encodes 8) */
            u8 enc = namelen & 7;
            rel_write_value_bits(ol, enc, 3);
        }

        /* Name characters */
        u8 limit = namelen;
        if (!ol->extnd_rel) {
            if (limit > 8) limit = 8;
        } else {
            if (limit > 30) limit = 30;
        }

        int i;
        for (i = 0; i < limit; i++) {
            rel_write_byte_bits(ol, item->field_b[i]);
        }
    }
}

/* Finalize REL output: pad + item 15 + pad + 0xFF.
 * Mirrors: rel_finalize in as_rel.c / A28FE in ASM1.ASM */
void rel_write_finalize(OlState *ol)
{
    /* Pad to byte boundary */
    rel_write_pad_to_boundary(ol);

    /* End file marker (item 15): 1 00 1111 */
    RelItem eof;
    memset(&eof, 0, sizeof(eof));
    eof.item_code = 15;
    rel_write_item(ol, &eof);

    /* Pad to byte boundary */
    rel_write_pad_to_boundary(ol);

    /* 0xFF terminator */
    io_write_byte(ol, 0xFF);
}
