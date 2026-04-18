@echo off
set PROG=USELESS
cc1 -m %PROG%.C
cc2 %PROG%.tmc
as %PROG%.asm
ld %PROG%,clib/l/gXMAIN /x
