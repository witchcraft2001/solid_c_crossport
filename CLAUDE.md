# Solid C Cross-Compiler Port

Port of the Solid C compiler toolchain (originally for Sprinter/Z80) to a cross-compiler in C99 for Linux/macOS/Windows. Goal: **byte-identical output** matching the original Sprinter tools.

## Project Structure

```
solid_c_port/
  CMakeLists.txt          — build system (cmake, C99)
  src/
    common/
      types.h             — shared type definitions (u8, u16, etc.)
    as/                   — Z80 Assembler (AS) — COMPLETE
      as_main.c           — entry point, CLI argument parsing
      as_lexer.c          — tokenizer for Z80 assembly
      as_symtab.c         — symbol table management
      as_expr.c           — expression evaluator
      as_instr.c          — Z80 instruction encoding
      as_directives.c     — assembler directives (db, dw, ds, org, etc.)
      as_rel.c            — REL object file output
      as_pass.c           — two-pass assembly driver
      as_io.c             — file I/O with buffering
      as_macro.c          — macro expansion
      as_defs.h           — shared definitions
    ol/                   — Object Librarian (OL) — COMPLETE
      ol_main.c           — entry point, CLI argument parsing
      ol_io.c             — file I/O
      ol_rel.c            — REL file parsing
      ol_ops.c            — library operations (A/D/E/L/R/T)
      ol_defs.h           — shared definitions
    cc2/                  — Code Generator (CC2) — IN PROGRESS
      cc2_main.c          — entry point, CLI argument parsing
      cc2_io.c            — file I/O with buffering
      cc2_tmc.c           — TMC intermediate format parser
      cc2_sym.c           — symbol table, type sizes
      cc2_gen.c           — code generation (TMC → Z80 ASM)
      cc2_out.c           — ASM output formatting
      cc2_defs.h          — shared definitions, Cc2State struct
  reference/              — reference files from original Sprinter compiler (READ-ONLY)
  solid_c-src/            — original Z80 source code of Solid C (CCC.ASM etc.)
  tests/                  — test scripts and data
  tools/                  — helper scripts (compare.sh, rel_decode.py)
  doc/                    — documentation (SolidC.pdf)
```

## Toolchain Pipeline

```
.C → CC1 (parser) → .TMC → CC2 (codegen) → .ASM → AS (assembler) → .REL → OL (librarian)
```

## Build

```sh
mkdir -p build && cd build && cmake .. && make
```

Produces: `build/as`, `build/ol`, `build/cc2`

## Rules

### Reference Directory (CRITICAL)

**NEVER modify files in `reference/`**. This directory contains the canonical output from the original Sprinter compiler tools. These files are the byte-identical reference for verifying our code generation.

- `reference/*.ASM` — reference assembler output from original CC2
- `reference/*.REL` — reference object files from original AS
- `reference/*.TMC` — intermediate code from original CC1
- `reference/*.C` — original C source files
- `reference/*.EXE` — original linked executables
- `reference/*.BAT` — original build scripts

When testing cc2, **copy reference files to a temp location** before running:

```sh
# CORRECT: copy to temp, run cc2, compare
cp reference/FOO.ASM /tmp/FOO_ref.ASM
cp reference/FOO.TMC /tmp/FOO.TMC
./build/cc2 /tmp/FOO.TMC
diff /tmp/FOO_ref.ASM /tmp/FOO.ASM
```

**NEVER** run `cc2` directly on `reference/*.TMC` — cc2 overwrites the `.ASM` file in the same directory as the input `.TMC`.

### Code Style

- C99, compiles with `-Wall -Wextra -Wpedantic`
- No dynamic memory allocation (all static buffers)
- Prefix conventions: `as_` for assembler, `ol_` for librarian, `cc2_` for codegen
- Mirror original CCC.ASM structure where possible, with comments referencing original addresses

### Testing

Compare output byte-for-byte with reference files. Current status:
- AS: all 6 reference programs BYTE-IDENTICAL
- OL: all 6 operations working, roundtrip BYTE-IDENTICAL
- CC2: 3/8 programs BYTE-IDENTICAL (CPRINTF, CPUTS, HELLO)

### Original Source Reference

The original compiler source is at `solid_c-src/ccc/CCC.ASM` (~20K lines Z80 ASM). Key addresses:
- `A12BC` — top-level dispatch
- `A19FB` — expression evaluator (TMC → code tree)
- `A3A5B` — optimizer phase 1 (basic blocks, variable counting)
- `A6131` — optimizer phase 2 (register allocation, code emission)
- `A6225` — ASM template output engine
