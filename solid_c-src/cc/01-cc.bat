@echo off
..\z80asm.exe cc1.asm -o cc.bin -l pr.lst
if errorlevel 1 goto ERR
echo Ok!
goto END

:ERR
pause
echo ошибки компиляции...

:END
