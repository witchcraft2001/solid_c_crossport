	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	cseg
sample_:
	db	84
	db	104
	db	105
	db	115
	db	32
	db	105
	db	115
	db	32
	db	97
	db	32
	db	99
	db	111
	db	109
	db	112
	db	105
	db	108
	db	101
	db	45
	db	116
	db	105
	db	109
	db	101
	db	32
	db	116
	db	101
	db	120
	db	116
	db	32
	db	98
	db	108
	db	111
	db	99
	db	107
	db	32
	db	117
	db	115
	db	101
	db	100
	db	32
	db	105
	db	110
	db	115
	db	116
	db	101
	db	97
	db	100
	db	32
	db	111
	db	102
	db	32
	db	102
	db	105
	db	108
	db	101
	db	32
	db	73
	db	47
	db	79
	db	46
	db	0
?63999:
	db	70,73,76,69,84,69,83,84,32,114
	db	101,112,108,97,99,101,109,101,110,116
	db	32,40,110,111,32,115,116,100,105,111
	db	46,104,41,10,0
?63998:
	db	70,105,114,115,116,32,49,48,32,99
	db	104,97,114,115,32,97,115,32,99,111
	db	100,101,115,58,10,0
?63997:
	db	37,100,32,0
?63996:
	db	10,84,101,120,116,32,112,114,101,118
	db	105,101,119,58,10,0
?63995:
	db	10,0
;{
main_:
	ld	hl,?63999
	call	cputs_
	ld	hl,?63998
	call	cputs_
	ld	bc,0
@1:
	ld	l,c
	ld	h,b
	ld	de,10
	call	?cpshd
	jp	nc,@0
	ld	hl,sample_
	add	hl,bc
	ld	a,(hl)
	or	a
	jp	z,@0
	ld	hl,sample_
	add	hl,bc
	ld	l,(hl)
	push	bc
	push	hl
	ld	bc,?63997
	push	bc
	ld	hl,2
	call	cprintf_
	pop	bc
	pop	bc
	pop	bc
	inc	bc
	jp	@1
@0:
	ld	hl,?63996
	call	cputs_
	ld	hl,sample_
	call	cputs_
	ld	hl,?63995
	call	cputs_
	ret
;}


	public	sample_
	public	main_
	extrn	cputs_
	extrn	cprintf_
	extrn	?cpshd

	end
