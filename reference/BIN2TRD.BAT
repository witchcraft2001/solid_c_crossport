set PROG=bin2trd
;set PREFIX=C:\SRC\%PROG%
REM SolidC EXE files must be in PATH
;cls 2
del %PROG%.exe
cc1 -m %PROG%
cc2 %PROG%
as %PROG%
REM LD filename length is limited to 12 characters!
ld /R6DF0 /P6E00 %PROG%,clib/l/gXMAIN /x
REM %PREFIX%\ld %PROG%,clib/l/gXMAIN /x
REM del %PROG%.tmc
REM del %PROG%.rel
REM del %PROG%.asm