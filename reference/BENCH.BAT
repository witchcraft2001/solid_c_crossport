echo === Building bench (SOLID C) ===
cc1 -m bench.c
;exit
cc2 bench.tmc
as bench.asm
ld bench,clib/l/gXMAIN /x
echo === Built: bench.exe ===

