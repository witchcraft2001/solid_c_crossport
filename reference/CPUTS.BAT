@echo off   
set PROG=cputs
cc1 -m %PROG%.c
cc2 %PROG%.tmc
as %PROG%.asm
ld %PROG%,clib/l/gXMAIN /x

