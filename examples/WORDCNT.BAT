@echo off
SET SRC=WORDCNT.C
SET NAME=%SRC:.C=%
cc1 -m %SRC%
cc2 %NAME%.tmc
as %NAME%.asm
ld %NAME%,clib/l/gXMAIN /x
del %NAME%.rel
del %NAME%.asm
