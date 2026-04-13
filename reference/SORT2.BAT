@echo off
cc1 -m sort2.c
cc2 sort2.tmc
as sort2.asm
ld sort2,clib/l/gXMAIN /x
;del sort2.rel
;del sort2.asm
