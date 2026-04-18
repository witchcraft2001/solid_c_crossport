	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	cseg
s1_:
	db	84
	db	104
	db	105
	db	115
	db	32
	db	105
	db	115
	db	32
	db	115
	db	116
	db	114
	db	105
	db	110
	db	103
	db	32
	db	49
	db	46
	db	46
	db	100
	db	117
	db	108
	db	108
	db	32
	db	97
	db	115
	db	32
	db	104
	db	101
	db	108
	db	108
	db	0
s2_:
	db	65
	db	66
	db	67
	db	68
	db	69
	db	70
	db	71
	db	72
	db	73
	db	74
	db	75
	db	76
	db	77
	db	78
	db	79
	db	80
	db	81
	db	82
	db	83
	db	84
	db	85
	db	86
	db	87
	db	88
	db	89
	db	90
	db	0
s3_:
	db	84
	db	104
	db	101
	db	32
	db	113
	db	117
	db	105
	db	99
	db	107
	db	32
	db	98
	db	114
	db	111
	db	119
	db	110
	db	32
	db	102
	db	111
	db	120
	db	32
	db	0
s4_:
	db	106
	db	117
	db	109
	db	112
	db	101
	db	100
	db	32
	db	111
	db	118
	db	101
	db	114
	db	32
	db	116
	db	104
	db	101
	db	32
	db	108
	db	97
	db	122
	db	121
	db	32
	db	100
	db	111
	db	103
	db	0
	dseg
a_:	ds	256
b_:	ds	256
	cseg
;{
mycpy_:
@0:
	ld	a,(de)
	inc	de
	ld	(hl),a
	inc	hl
	or	a
	jp	nz,@0
	ret
;}

;{
mycat_:
@2:
	ld	a,(hl)
	or	a
	jp	z,@1
	inc	hl
	jp	@2
@1:
	ld	a,(de)
	inc	de
	ld	(hl),a
	inc	hl
	or	a
	jp	nz,@1
	ret
;}

;{
to_upper_:
@4:
	ld	a,(hl)
	or	a
	ret	z
	ld	a,(hl)
	cp	97
	jp	c,@3
	ld	a,(hl)
	cp	123
	jp	nc,@3
	ld	a,(hl)
	sub	32
	ld	(hl),a
@3:
	inc	hl
	jp	@4
;}

;{
to_lower_:
@6:
	ld	a,(hl)
	or	a
	ret	z
	ld	a,(hl)
	cp	65
	jp	c,@5
	ld	a,(hl)
	cp	91
	jp	nc,@5
	ld	a,(hl)
	add	a,32
	ld	(hl),a
@5:
	inc	hl
	jp	@6
;}

?63999:
	db	70,65,82,68,69,77,79,32,115,116
	db	114,105,110,103,32,115,116,114,101,115
	db	115,32,40,83,111,108,105,100,67,45
	db	115,97,102,101,41,10,0
?63998:
	db	67,111,112,121,32,49,58,32,0
?63997:
	db	10,0
?63996:
	db	67,111,110,99,97,116,58,32,0
?63995:
	db	10,0
?63994:
	db	32,58,58,32,0
?63993:
	db	77,101,114,103,101,100,58,32,0
?63992:
	db	10,0
?63991:
	db	85,112,112,101,114,32,58,32,0
?63990:
	db	10,0
?63989:
	db	76,111,119,101,114,32,58,32,0
?63988:
	db	10,0
;{
main_:
	ld	hl,?63999
	call	cputs_
	ld	de,s2_
	ld	hl,a_
	call	mycpy_
	ld	hl,?63998
	call	cputs_
	ld	hl,a_
	call	cputs_
	ld	hl,?63997
	call	cputs_
	ld	de,s3_
	ld	hl,a_
	call	mycpy_
	ld	de,s4_
	ld	hl,a_
	call	mycat_
	ld	hl,?63996
	call	cputs_
	ld	hl,a_
	call	cputs_
	ld	hl,?63995
	call	cputs_
	ld	de,s1_
	ld	hl,b_
	call	mycpy_
	ld	de,?63994
	ld	hl,b_
	call	mycat_
	ld	de,a_
	ld	hl,b_
	call	mycat_
	ld	hl,?63993
	call	cputs_
	ld	hl,b_
	call	cputs_
	ld	hl,?63992
	call	cputs_
	ld	hl,b_
	call	to_upper_
	ld	hl,?63991
	call	cputs_
	ld	hl,b_
	call	cputs_
	ld	hl,?63990
	call	cputs_
	ld	hl,b_
	call	to_lower_
	ld	hl,?63989
	call	cputs_
	ld	hl,b_
	call	cputs_
	ld	hl,?63988
	call	cputs_
	ret
;}


	public	s1_
	public	s2_
	public	s3_
	public	s4_
	public	a_
	public	b_
	public	mycpy_
	public	mycat_
	public	to_upper_
	public	to_lower_
	public	main_
	extrn	cputs_

	end
