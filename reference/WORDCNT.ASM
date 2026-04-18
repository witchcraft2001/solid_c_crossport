	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	cseg
text_:
	db	83
	db	111
	db	108
	db	105
	db	100
	db	67
	db	32
	db	119
	db	111
	db	114
	db	100
	db	32
	db	99
	db	111
	db	117
	db	110
	db	116
	db	32
	db	100
	db	101
	db	109
	db	111
	db	46
	db	10
	db	84
	db	104
	db	105
	db	115
	db	32
	db	101
	db	120
	db	97
	db	109
	db	112
	db	108
	db	101
	db	32
	db	97
	db	118
	db	111
	db	105
	db	100
	db	115
	db	32
	db	115
	db	116
	db	100
	db	105
	db	111
	db	32
	db	104
	db	101
	db	97
	db	100
	db	101
	db	114
	db	115
	db	32
	db	98
	db	117
	db	116
	db	32
	db	115
	db	116
	db	105
	db	108
	db	108
	db	10
	db	116
	db	101
	db	115
	db	116
	db	115
	db	32
	db	99
	db	104
	db	97
	db	114
	db	97
	db	99
	db	116
	db	101
	db	114
	db	32
	db	99
	db	108
	db	97
	db	115
	db	115
	db	105
	db	102
	db	105
	db	99
	db	97
	db	116
	db	105
	db	111
	db	110
	db	32
	db	97
	db	110
	db	100
	db	32
	db	99
	db	111
	db	117
	db	110
	db	116
	db	101
	db	114
	db	115
	db	46
	db	10
	db	78
	db	117
	db	109
	db	98
	db	101
	db	114
	db	115
	db	58
	db	32
	db	49
	db	50
	db	51
	db	52
	db	53
	db	46
	db	32
	db	83
	db	121
	db	109
	db	98
	db	111
	db	108
	db	115
	db	58
	db	32
	db	42
	db	38
	db	94
	db	37
	db	46
	db	10
	db	0
;{
is_space_:
	ld	a,l
	sub	32
	or	h
	jp	z,@0
	ld	a,l
	sub	9
	or	h
	jp	z,@0
	ld	a,l
	sub	10
	or	h
	jp	z,@0
	ld	a,l
	sub	13
	or	h
	jp	z,@0
	ld	a,l
	sub	12
	or	h
	jp	nz,@1
@0:
	ld	hl,1
	ret
@1:
	ld	hl,0
	ret
;}

?63999:
	db	87,79,82,68,67,78,84,32,115,97
	db	109,112,108,101,32,115,116,97,116,115
	db	10,0
?63998:
	db	76,105,110,101,115,61,37,100,32,87
	db	111,114,100,115,61,37,100,32,67,104
	db	97,114,115,61,37,100,10,0
;{
main_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	push	bc
	ld	hl,0
	ld	(ix-6),l
	ld	(ix-5),h
	ld	hl,0
	ld	(ix-4),l
	ld	(ix-3),h
	ld	hl,0
	ld	(ix-2),l
	ld	(ix-1),h
	ld	bc,0
	ld	de,0
@7:
	ld	hl,text_
	add	hl,de
	ld	a,(hl)
	or	a
	jp	z,@2
	ld	hl,text_
	add	hl,de
	ld	l,(hl)
	ld	h,0
	push	de
	push	bc
	ex	de,hl
	ld	l,(ix-2)
	ld	h,(ix-1)
	inc	hl
	ld	(ix-2),l
	ld	(ix-1),h
	ld	a,e
	sub	10
	or	d
	jp	nz,@3
	ld	l,(ix-6)
	ld	h,(ix-5)
	inc	hl
	ld	(ix-6),l
	ld	(ix-5),h
@3:
	ex	de,hl
	call	is_space_
	pop	bc
	ld	a,l
	or	h
	jp	z,@4
	ld	a,c
	or	b
	jp	z,@5
	ld	l,(ix-4)
	ld	h,(ix-3)
	inc	hl
	ld	(ix-4),l
	ld	(ix-3),h
@5:
	ld	bc,0
	jp	@6
@4:
	ld	bc,1
@6:
	pop	de
	inc	de
	jp	@7
@2:
	ld	a,c
	or	b
	jp	z,@8
	ld	l,(ix-4)
	ld	h,(ix-3)
	inc	hl
	ld	(ix-4),l
	ld	(ix-3),h
@8:
	ld	hl,?63999
	call	cputs_
	ld	l,(ix-2)
	ld	h,(ix-1)
	push	hl
	ld	l,(ix-4)
	ld	h,(ix-3)
	push	hl
	ld	l,(ix-6)
	ld	h,(ix-5)
	push	hl
	ld	bc,?63998
	push	bc
	ld	hl,4
	call	cprintf_
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	sp,ix
	pop	ix
	ret
;}


	public	text_
	public	is_space_
	public	main_
	extrn	cputs_
	extrn	cprintf_

	end
