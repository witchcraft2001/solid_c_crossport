@echo off
..\z80asm.exe asm1.asm -o as1.bin -l pr.lst
if errorlevel 1 goto ERR
rem del as1.bin
echo Ok!
goto END

:ERR
echo ошибки компиляции...
pause

:END
