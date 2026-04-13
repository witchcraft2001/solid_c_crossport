	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	dseg
errno_:	ds	1
	cseg
?63999:
	db	69,82,82,79,82,32,40,70,105,108
	db	101,61,34,37,115,34,41,10,0
?63998:
	db	70,73,76,69,32,69,82,82,79,82
	db	0
?63997:
	db	32,32,78,97,109,101,61,34,37,115
	db	37,99,34,32,76,101,110,61,37,48
	db	53,117,32,83,116,97,114,116,61,37
	db	48,53,117,32,66,108,107,61,37,48
	db	51,117,32,67,114,99,61,37,48,53
	db	117,10,0
?63996:
	db	10,73,108,108,101,103,97,108,32,99
	db	104,101,99,107,115,117,109,32,105,110
	db	32,104,101,97,100,101,114,32,111,102
	db	32,104,111,98,101,116,97,33,10,87
	db	97,115,58,32,32,37,48,53,117,10
	db	82,101,97,108,58,32,37,48,53,117
	db	10,10,0
?63995:
	db	10,79,107,33,10,10,0
;{
check_hobeta_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	hl
	ld	hl,65500
	add	hl,sp
	ld	sp,hl
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	de,2
	ld	(ix-2),l
	ld	(ix-1),h
	call	open_
	push	hl
	ld	e,(ix-2)
	ld	d,(ix-1)
	ld	a,l
	and	h
	inc	a
	jp	nz,@0
	push	de
	ld	bc,?63999
	push	bc
	ld	hl,2
	call	printf_
	pop	bc
	pop	bc
	ld	hl,?63998
	call	perror_
	ld	hl,65535
	call	exit_
@0:
	pop	hl
	push	hl
	ld	hl,20
	add	hl,sp
	ex	de,hl
	ld	bc,17
	pop	hl
	push	hl
	call	read_
	pop	hl
	call	close_
	ld	de,0
@2:
	ld	a,e
	sub	8
	ld	a,d
	sbc	a,0
	jp	nc,@1
	ld	hl,18
	add	hl,sp
	add	hl,de
	ld	a,(hl)
	ld	hl,2
	add	hl,sp
	add	hl,de
	ld	(hl),a
	inc	de
	jp	@2
@1:
	ld	hl,10
	add	hl,sp
	ld	(hl),0
	ld	hl,26
	add	hl,sp
	ld	a,(hl)
	ld	hl,28
	add	hl,sp
	ld	b,(hl)
	ld	c,0
	ld	hl,27
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	add	hl,bc
	ld	(ix-27),a
	ld	(ix-26),l
	ld	(ix-25),h
	ld	hl,30
	add	hl,sp
	ld	b,(hl)
	ld	c,0
	ld	hl,29
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	add	hl,bc
	ld	(ix-22),l
	ld	(ix-21),h
	ld	hl,32
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	ld	(ix-24),l
	ld	(ix-23),h
	ld	hl,34
	add	hl,sp
	ld	b,(hl)
	ld	c,0
	ld	hl,33
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	add	hl,bc
	ld	de,0
	push	hl
	ld	(ix-38),l
	ld	(ix-37),h
	ld	hl,0
@4:
	ld	a,e
	sub	15
	ld	a,d
	sbc	a,0
	jp	nc,@3
	push	hl
	ld	hl,22
	add	hl,sp
	add	hl,de
	ld	l,(hl)
	ld	h,0
	ld	c,l
	ld	b,h
	ld	h,l
	ld	l,0
	add	hl,bc
	add	hl,de
	pop	bc
	add	hl,bc
	inc	de
	jp	@4
@3:
	push	hl
	ld	l,(ix-38)
	ld	h,(ix-37)
	push	hl
	ld	l,(ix-24)
	ld	h,(ix-23)
	push	hl
	ld	l,(ix-26)
	ld	h,(ix-25)
	push	hl
	ld	l,(ix-22)
	ld	h,(ix-21)
	push	hl
	ld	c,(ix-27)
	push	bc
	ld	hl,16
	add	hl,sp
	push	hl
	ld	bc,?63997
	push	bc
	ld	hl,7
	call	printf_
	ex	de,hl
	ld	hl,14
	add	hl,sp
	ld	sp,hl
	ex	de,hl
	pop	bc
	pop	hl
	ld	a,c
	cp	l
	jr	nz,$+4
	ld	a,b
	cp	h
	jp	z,@5
	push	bc
	push	hl
	ld	bc,?63996
	push	bc
	ld	hl,3
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	ld	a,255
	jp	@6
@5:
	ld	bc,?63995
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	xor	a
@6:
	ld	sp,ix
	pop	ix
	ret
;}

?63994:
	db	10,72,111,98,101,116,97,67,114,99
	db	32,118,46,48,46,49,0
?63993:
	db	10,67,104,101,99,107,105,110,103,32
	db	99,104,101,99,107,115,117,109,32,105
	db	110,32,72,111,98,101,116,97,32,102
	db	105,108,101,115,0
?63992:
	db	10,98,121,32,68,109,105,116,114,121
	db	32,77,105,107,104,97,108,116,99,104
	db	101,110,107,111,118,32,60,109,105,107
	db	104,97,108,116,99,104,101,110,107,111
	db	118,64,103,109,97,105,108,46,99,111
	db	109,62,10,10,0
?63991:
	db	32,32,32,85,115,97,103,101,58,10
	db	9,104,111,98,99,114,99,32,60,102
	db	105,108,101,110,97,109,101,62,10,10
	db	0
;{
main_:
	ld	bc,?63994
	push	de
	push	hl
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	bc,?63993
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	bc,?63992
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	pop	hl
	pop	de
	ld	a,l
	dec	a
	or	h
	jp	nz,@7
	ld	bc,?63991
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	hl,65535
	ret
@7:
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	check_hobeta_
	ld	l,a
	ld	h,0
	ret
;}


	public	errno_
	public	check_hobeta_
	extrn	open_
	extrn	printf_
	extrn	perror_
	extrn	exit_
	extrn	read_
	extrn	close_
	public	main_

	end
