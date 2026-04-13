echo === Building hobcrc (SOLID C) ===
cc1 -m hobcrc.c
;exit
cc2 hobcrc.tmc
as hobcrc.asm
ld hobcrc,clib/l/gXMAIN /x
echo === Built: hobcrc.exe ===

