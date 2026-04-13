@echo off
rem ..\z80asm.exe ol1.asm -o OL.EXE
..\asmplus.exe ol1.asm OL.EXE
if errorlevel 1 goto ERR
echo Ok!
goto END

:ERR
pause
echo ошибки компиляции...

:END
del ol1.lst
