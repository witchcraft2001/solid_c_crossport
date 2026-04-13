; Test 3: Directives, EQU, IF/ELSE/ENDIF, expressions
	cseg

CONST1	equ	42h
CONST2	equ	CONST1+10h

	ld	a,CONST1
	ld	b,CONST2

; ORG test
	org	100h
start:	nop

; DS test
	ds	5
	ds	3,0FFh

; Expressions with operators
val1	equ	10+20
val2	equ	100-50
val3	equ	3*4
val4	equ	100/10

	ld	hl,val1
	ld	de,val2
	ld	bc,val3

; IF/ELSE/ENDIF
flag	equ	1

	if	flag
	ld	a,1
	else
	ld	a,0
	endif

	if	0
	ld	b,99h
	endif

; PUBLIC / EXTERN
	public	start
	extern	extfunc

	call	extfunc

; DB with expressions
data:	db	1,2,3,CONST1
	dw	CONST2,start

	end	start
