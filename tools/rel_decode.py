#!/usr/bin/env python3
"""
Decode a Z80 .REL file bitstream.

REL format: MSB-first bitstream where:
  0 + 8 bits = absolute byte
  1 00 + 4-bit item + fields = special link item
  1 01 + 16 bits = code-relative word
  1 10 + 16 bits = data-relative word
  1 11 + 16 bits = common-relative word
"""

import sys

ITEM_NAMES = {
    0: "entry symbol",
    1: "select common block",
    2: "program name",
    3: "request library search",
    4: "extension link",
    5: "define common size",
    6: "chain external",
    7: "define entry point",
    8: "(reserved 8)",
    9: "external+offset",
    10: "define data size",
    11: "set location counter",
    12: "chain address",
    13: "define program size",
    14: "end program",
    15: "end file",
}

SEG_NAMES = ["abs", "code", "data", "common"]

class BitReader:
    def __init__(self, data):
        self.data = data
        self.byte_pos = 0
        self.bit_pos = 7  # MSB first

    def get_bit(self):
        if self.byte_pos >= len(self.data):
            raise StopIteration
        bit = (self.data[self.byte_pos] >> self.bit_pos) & 1
        self.bit_pos -= 1
        if self.bit_pos < 0:
            self.bit_pos = 7
            self.byte_pos += 1
        return bit

    def get_bits(self, n):
        val = 0
        for _ in range(n):
            val = (val << 1) | self.get_bit()
        return val

    def get_byte(self):
        return self.get_bits(8)

    def position(self):
        return f"byte {self.byte_pos}, bit {7 - self.bit_pos}"


def decode_rel(data, label=""):
    br = BitReader(data)
    pc = 0

    if label:
        print(f"=== {label} ({len(data)} bytes) ===")

    try:
        while True:
            bit = br.get_bit()

            if bit == 0:
                # Absolute byte
                byte = br.get_byte()
                ch = chr(byte) if 32 <= byte < 127 else '.'
                print(f"  [{pc:04X}] ABS  {byte:02X}  ({ch})")
                pc += 1
            else:
                # 1 + 2 bits
                seg = br.get_bits(2)

                if seg != 0:
                    # Relocatable word: seg=1(code), 2(data), 3(common)
                    lo = br.get_byte()
                    hi = br.get_byte()
                    val = lo | (hi << 8)
                    print(f"  [{pc:04X}] REL  {val:04X}  seg={SEG_NAMES[seg]}")
                    pc += 2
                else:
                    # Special link item: 1 00 + 4-bit item code
                    item = br.get_bits(4)
                    name = ITEM_NAMES.get(item, f"?{item}")

                    if item == 15:
                        print(f"  [LINK] END FILE")
                        break

                    # Items 5..14 have A-field (2-bit seg + 16-bit value)
                    if item >= 5:
                        a_seg = br.get_bits(2)
                        a_lo = br.get_byte()
                        a_hi = br.get_byte()
                        a_val = a_lo | (a_hi << 8)
                        a_seg_name = SEG_NAMES[a_seg]

                        if item >= 8:
                            # A-field only items (no B-field)
                            print(f"  [LINK] {name}: seg={a_seg_name} val={a_val:04X}")
                            continue
                        else:
                            # Has both A-field and B-field
                            sym_len = br.get_bits(3)
                            if sym_len == 0: sym_len = 8  # 0 means 8 in M80 REL
                            sym = ""
                            for _ in range(sym_len):
                                ch = br.get_byte()
                                sym += chr(ch & 0x7F)
                            print(f"  [LINK] {name}: seg={a_seg_name} val={a_val:04X} name='{sym}'")
                            continue
                    else:
                        # Items 0..4: B-field only (symbol name)
                        sym_len = br.get_bits(3)
                        if sym_len == 0: sym_len = 8  # 0 means 8 in M80 REL
                        sym = ""
                        for _ in range(sym_len):
                            ch = br.get_byte()
                            sym += chr(ch & 0x7F)
                        print(f"  [LINK] {name}: name='{sym}'")

    except StopIteration:
        print(f"  [END] bitstream exhausted at PC={pc:04X}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} file.rel [file2.rel ...]")
        sys.exit(1)

    for fname in sys.argv[1:]:
        with open(fname, "rb") as f:
            data = list(f.read())
        decode_rel(data, fname)
        print()
