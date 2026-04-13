@echo off
rem release (amain.asm)
rem ..\z80asm.exe amain.asm -o AS.EXE
rem debug (dmain.asm)
..\z80asm.exe dmain.asm -o AS.EXE
if errorlevel 1 goto ERR
rem del asm1
rem del asm2
rem del as1.bin
del pr.lst
echo Ok!
goto END

:ERR
echo ошибки компиляции...
pause

:END
