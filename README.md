# Solid C Cross-Compiler

Cross-platform port of the **Solid C** compiler toolchain, originally developed for the ZX Spectrum Sprinter (ESTEX OS). Produces byte-identical output to the original Z80-native tools.

## Toolchain

| Stage | Tool | Input | Output | Status |
|-------|------|-------|--------|--------|
| 1 | **CC1** | `.c` | `.tmc` | Planned |
| 2 | **CC2** | `.tmc` | `.asm` | Planned |
| 3 | **AS** | `.asm` | `.rel` | In progress |
| 4 | **OL** | `.rel` | `.exe` | Planned |

## Building

```sh
mkdir build && cd build
cmake ..
make
```

Requires CMake 3.10+ and a C99 compiler (GCC, Clang, or MSVC).

## Usage

```sh
# Assemble a Z80 source file
./as [-t] [-x] [-z] filename[.asm]
```

### AS options

| Flag | Description |
|------|-------------|
| `-t` | Truncate global symbol names to 6 characters (Link-80 compatible) |
| `-x` | Extended REL output format (up to 30-character symbol names) |
| `-z` | Zero-fill `DS` memory areas |

## Original

Based on **Macro Assembler v1.5 (c) 1995, SOLiD**, ported by Vasil Ivanov for ESTEX/Sprinter. Documentation: `SolidC.pdf`.
