# SolidC K&R Example Ports

This directory contains ten non-trivial ports from `z88dk/examples` adapted to plain K&R C for SolidC.

Each example has:

- a `.C` source file
- a `.BAT` build script with a single `SET SRC=...` line to pick the source

Build scripts follow the Solid batch flow:

- `cc1 -m %SRC%`
- `cc2 %NAME%.tmc`
- `as %NAME%.asm`
- `ld %NAME%,clib/l/gXMAIN /x`

Ported set:

- `ANSITEST` (from `z88/ansitest.c`)
- `CUBE` (algorithm inspired by `z88/cube.c`, text output variant)
- `DSTAR` (logic inspired by `sam/dstar.c`, text mode)
- `ENIGMA` (from `sam/enigma.c`)
- `FILETEST` (from `z88/filetest.c`)
- `MANDEL` (from `sam/mandel.c`, fixed-point text variant)
- `RPN` (from `z88/rpn.c`)
- `STATICS` (from `z88/define.c`)
- `VIEWER` (from `z88/app/viewer.c`)
- `WORDCNT` (from `z88/wc.c`)
