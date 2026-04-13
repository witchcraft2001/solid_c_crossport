@echo off
rem release (cmain.asm)
rem ..\z80asm.exe cmain.asm -o CC2.EXE
rem debug (dmain.asm)
..\z80asm.exe dmain.asm -o CC2.EXE
if errorlevel 1 goto ERR
rem del ccc1.b
rem del ccc2.b
rem del ccc3.b
rem del ccc.bin
rem del pr.lst
echo Ok!
goto END

:ERR
pause
echo ошибки компиляции...

:END
