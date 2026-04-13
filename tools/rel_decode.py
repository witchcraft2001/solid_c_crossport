#!/usr/bin/env python3
"""
Decode a Z80 .REL file bitstream for debugging.

REL format: bitstream where:
  0 + 8 bits = absolute byte
  1 00 + 4 bits item + fields = special link item

Special link items (4-bit code):
  0 = entry symbol
  1 = select common block
  2 = program name
  3 = request library search
  4 = extension link item (chain external)
  5 = define common size
  6 = chain external
  7 = define entry point
  8 = unused
  9 = external + offset
  10 = define data size
  11 = set loading counter
  12 = chain address
  13 = define program size
  14 = end program (entry point)
  15 = end file
"""

import sys

def read_bits(data):
    """Generator: yields individual bits from byte array"""
    for byte in data:
        for i in range(7, -1, -1):
            yield (byte >> i) & 1

def get_bits(bits, n):
    """Read n bits, return value"""
    val = 0
    for _ in range(n):
        val = (val << 1) | next(bits)
    return val

def get_byte(bits):
    return get_bits(bits, 8)

ITEM_NAMES = {
    0: "entry symbol",
    1: "select common block",
    2: "program name",
    3: "request library search",
    4: "extension link",
    5: "define common size",
    6: "chain external",
    7: "define entry point",
    8: "unused",
    9: "external+offset",
    10: "define data size",
    11: "set location counter",
    12: "chain address",
    13: "define program size",
    14: "end program",
    15: "end file",
}

def decode_rel(data, label=""):
    bits = read_bits(data)
    pc = 0

    if label:
        print(f"=== {label} ({len(data)} bytes) ===")

    try:
        while True:
            bit = next(bits)

            if bit == 0:
                # Absolute byte
                byte = get_byte(bits)
                print(f"  [{pc:04X}] ABS byte: {byte:02X}  ({chr(byte) if 32 <= byte < 127 else '.'})")
                pc += 1
            else:
                # Special link item
                seg_bits = get_bits(bits, 2)  # 2 bits of segment type

                if seg_bits == 0:
                    # Special item: 1 00 + 4-bit item code
                    item_code = get_bits(bits, 4)
                    item_name = ITEM_NAMES.get(item_code, f"unknown({item_code})")

                    if item_code == 15:
                        # End file
                        print(f"  [SPEC] END FILE")
                        break
                    elif item_code >= 5 and item_code != 15:
                        # Has A-field: 2-bit seg type + 16-bit value
                        a_seg = get_bits(bits, 2)
                        a_lo = get_byte(bits)
                        a_hi = get_byte(bits)
                        a_val = a_lo | (a_hi << 8)
                        seg_names = ["abs", "code", "data", "common"]
                        print(f"  [SPEC] {item_name}: seg={seg_names[a_seg]} val={a_val:04X}", end="")

                        if item_code < 8:
                            # Also has B-field (symbol name)
                            name_len = get_bits(bits, 3)
                            name = ""
                            for _ in range(name_len):
                                ch = get_byte(bits)
                                name += chr(ch & 0x7F)
                            print(f" name='{name}'", end="")
                        print()
                    elif item_code < 5:
                        # B-field only (symbol name)
                        name_len = get_bits(bits, 3)
                        name = ""
                        for _ in range(name_len):
                            ch = get_byte(bits)
                            name += chr(ch & 0x7F)
                        print(f"  [SPEC] {item_name}: name='{name}'")
                    else:
                        print(f"  [SPEC] {item_name}")
                else:
                    # Relocatable byte: seg_bits + 16-bit value
                    seg_names = ["abs", "code", "data", "common"]
                    lo = get_byte(bits)
                    hi = get_byte(bits)
                    val = lo | (hi << 8)
                    print(f"  [{pc:04X}] REL word: {val:04X} seg={seg_names[seg_bits]}")
                    pc += 2
    except StopIteration:
        print(f"  [END] bitstream exhausted at PC={pc:04X}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} file.rel [file2.rel ...]")
        sys.exit(1)

    for fname in sys.argv[1:]:
        with open(fname, "rb") as f:
            data = f.read()

        # Strip trailing 0xFF and 0x00 padding
        while data and data[-1] in (0xFF, 0x00):
            data = data[:-1]

        decode_rel(data, fname)
        print()
