@echo off
cc1 -m hello.c
cc2 hello.tmc
as hello.asm
ld hello,clib/l/gXMAIN /x
;del hello.rel
;del hello.asm
