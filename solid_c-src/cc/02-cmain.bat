@echo off
rem release (cmain.asm)
rem ..\z80asm.exe cmain.asm -o CC1.EXE
rem debug (dmain.asm)
..\z80asm.exe dmain.asm -o CC1.EXE
if errorlevel 1 goto ERR
rem del cc1
rem del cc2
rem del cc3
rem del cc.bin
rem del pr.lst
echo Ok!
goto END

:ERR
pause
echo ошибки компиляции...

:END
