; Test: Macro system
	cseg

; Simple macro without parameters
pushall	macro
	push	af
	push	bc
	push	de
	push	hl
	endm

popall	macro
	pop	hl
	pop	de
	pop	bc
	pop	af
	endm

; Use macros
	pushall
	popall

; Macro with parameters
load	macro	reg,val
	ld	reg,val
	endm

	load	a,42h
	load	hl,1234h
	load	b,0

; Macro with multiple uses
clrreg	macro	r
	xor	a
	ld	r,a
	endm

	clrreg	b
	clrreg	c
	clrreg	d

; REPT directive
	rept	3
	nop
	endm

; REPT with counter-like pattern
count	equ	5
	rept	count
	inc	a
	endm

; Nested macro calls
save_load macro	reg,val
	push	af
	ld	reg,val
	endm

	save_load	a,0FFh
	save_load	b,10

	end
