@echo off   
set PROG=lzh3
cc1 -m %PROG%.c
cc2 %PROG%.tmc
as %PROG%.asm
ld %PROG%,clib/l/gXMAIN /x

