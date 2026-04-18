# SolidC K&R Example Ports

This directory contains non-trivial ports from `z88dk/examples` adapted to plain K&R C for SolidC.

All sources are written to compile without `stdio.h` and use `#include <conio.h>` plus K&R-style declarations.

Each example has:

- a `.C` source file
- a `.BAT` build script with a single `set PROG=...` line to pick the source

Build scripts follow the Solid batch flow:

- `cc1 -m %PROG%.C`
- `cc2 %PROG%.tmc`
- `as %PROG%.asm`
- `ld %PROG%,clib/l/gXMAIN /x`

Ported set:

- `CUBE` (algorithm inspired by `z88/cube.c`, text output variant)
- `DSTAR` (logic inspired by `sam/dstar.c`, text mode)
- `FARDEMO` (from `z88/farmalloc.c`, heap/string stress variant)
- `OTHELLO` (from `othello.c`, full text game with AI move selection)
- `USELESS` (from `z88/useless.c`, command/menu flow demo)
- `ENIGMA` (from `sam/enigma.c`)
- `FILETEST` (from `z88/filetest.c`)
- `MANDEL` (from `sam/mandel.c`, fixed-point text variant)
- `RPN` (from `z88/rpn.c`)
- `STATICS` (from `z88/define.c`)
- `VIEWER` (from `z88/app/viewer.c`)
- `WORDCNT` (from `z88/wc.c`)
