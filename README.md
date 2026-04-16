# Solid C Cross-Compiler

Cross-platform port of the **Solid C** compiler toolchain, originally developed for the ZX Spectrum Sprinter (ESTEX OS). Goal: **byte-identical output** matching the original Z80-native tools.

Based on **Solid C (c) 1995, SOLiD**, ported by Vasil Ivanov for ESTEX/Sprinter. Documentation: `doc/SolidC.pdf`.

## Toolchain

```
.C → CC1 (parser) → .TMC → CC2 (codegen) → .ASM → AS (assembler) → .REL → OL (librarian)
```

| Stage | Tool | Input | Output | Status |
|-------|------|-------|--------|--------|
| 1 | **CC1** | `.c` | `.tmc` | Planned |
| 2 | **CC2** | `.tmc` | `.asm` | In progress |
| 3 | **AS** | `.asm` | `.rel` | **Complete** |
| 4 | **OL** | `.rel` | `.exe` | **Complete** |

### AS — Z80 Assembler

Complete. All 8 reference programs produce **byte-identical** output.

```sh
./build/as [-t] [-x] [-z] filename[.asm]
```

| Flag | Description |
|------|-------------|
| `-t` | Truncate global symbol names to 6 characters (Link-80 compatible) |
| `-x` | Extended REL output format (up to 30-character symbol names) |
| `-z` | Zero-fill `DS` memory areas |

### OL — Object Librarian

Complete. All 6 library operations (A/D/E/L/R/T) produce **byte-identical** output.

```sh
./build/ol <operation> library.lib [modules...]
```

### CC2 — Code Generator (TMC → Z80 ASM)

In progress. Ports `solid_c-src/ccc/CCC.ASM` (~20K lines Z80 ASM).

**Current status (2026-04):**

| Program | Status |
|---------|--------|
| CPRINTF | Byte-identical |
| CPUTS   | Byte-identical |
| HELLO   | Byte-identical |
| BENCH   | ~1725 diff lines remaining |
| BIN2TRD | ~2450 diff lines remaining |
| HOBCRC  | ~615 diff lines remaining |
| LZH3    | ~3257 diff lines remaining |
| SORT2   | ~2731 diff lines remaining |

**Implemented features:**
- Frame layout: param-first (push hl → IX-2), partial register allocation (DE for loop counter, BC for second most-used variable)
- Constant folding: arithmetic (+,-,*,/,%), bitwise (|,&,^), `#V` sizes
- Type system: char-width propagation, immediate folding in conditional jumps
- Comparisons: inline sub/sbc for `<N`; `or h` for `==0`; `dec/or` for `==1`; `and h/inc` for `==-1`; `cp N` for char; `or a` for char `==0`; signed comparisons via `?cpshd`
- Strength reduction: `*2`→`add hl,hl`; `*4`; `*8`; `*10`; `*16`; `*256`→`h,l/l,0`; `*257`; `+1`→`inc hl`; `-1`→`dec hl`; constant subtract via two's complement
- Arrays: element size 1/2 special cases; constant-folded index*size; base register tracking
- Operators: shift, OR, AND, ternary, all compound assignments
- Pointers: dereference and address-of on globals/locals
- Function calls: F1/F2/F3 register conventions; direct push for HL/DE/global args; bulk SP cleanup (≥5 args)
- Static data: T-type dseg locals, initialized tables (db/dw), G-type integer initializers
- Strings: deduplication via emitted flag; global label counter
- Peephole optimizations: ~15 patterns (dead jumps, redundant loads, condition inversion, etc.)

**Remaining blockers (require full code-tree architecture):**
- Push/pop for temp register saves (reference uses push hl/pop hl; current uses IX-relative)
- Local-to-global promotion (LZH3: A7 locals → dseg globals)
- IX frame decisions (some functions missing IX frame or have extra IX setup)
- Instruction ordering (arg preloading before push sequences)
- Full code-tree optimizer: 24-byte nodes → phases A3A5B/A6131 → template output A6225

## Building

```sh
mkdir -p build && cd build
cmake ..
make
```

Requires CMake 3.10+ and a C99 compiler (GCC, Clang, or MSVC).

Produces: `build/as`, `build/ol`, `build/cc2`

## Testing

```sh
# Copy reference files to temp, run cc2, compare
cp reference/FOO.TMC /tmp/FOO.TMC
cp reference/FOO.ASM /tmp/FOO_ref.ASM
./build/cc2 /tmp/FOO.TMC
diff /tmp/FOO_ref.ASM /tmp/FOO.ASM
```

Reference files in `reference/` are **read-only** — never run tools directly on them.

## Project Structure

```
src/
  common/types.h        — shared types (u8, u16, etc.)
  as/                   — Z80 assembler (COMPLETE)
  ol/                   — object librarian (COMPLETE)
  cc2/                  — code generator (IN PROGRESS)
    cc2_gen.c           — main codegen (TMC → Z80 ASM)
    cc2_tmc.c           — TMC format parser
    cc2_sym.c           — symbol table, type sizes
    cc2_out.c           — ASM output formatting
reference/              — canonical output from original Sprinter tools (READ-ONLY)
solid_c-src/ccc/CCC.ASM — original Z80 source of Solid C (~20K lines)
tests/                  — test scripts
tools/                  — helper scripts (compare.sh, rel_decode.py)
doc/SolidC.pdf          — language documentation
```
