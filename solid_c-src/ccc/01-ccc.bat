@echo off
..\z80asm.exe CCC.ASM -o ccc.bin -l pr.lst
if errorlevel 1 goto ERR
rem del ccc.bin
echo Ok!
goto END

:ERR
pause
echo ошибки компиляции...

:END
