@echo off
;set SOLIDC=%BOOTDSK%\DEV\SOLIDC
set PROG=cprintf
cc1 -m %PROG%.c
cc2 %PROG%.tmc
as %PROG%.asm
ld %PROG%,clib/l/gXMAIN /x

