	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	cseg
shade_:
	db	32
	db	46
	db	58
	db	45
	db	61
	db	43
	db	42
	db	35
	db	37
	db	64
	db	0
?63999:
	db	77,65,78,68,69,76,32,102,105,120
	db	101,100,45,112,111,105,110,116,10,0
;{
main_:
	push	ix
	ld	ix,0
	add	ix,sp
	ld	hl,65524
	add	hl,sp
	ld	sp,hl
	ld	hl,?63999
	call	cputs_
	ld	hl,0
@7:
	ld	de,32
	call	?cpshd
	jp	nc,@0
	push	hl
	ld	h,l
	ld	l,0
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,bc
	ld	de,32
	call	?dvihd
	ld	bc,65152
	add	hl,bc
	ld	(ix-10),l
	ld	(ix-9),h
	ld	hl,0
@6:
	ld	de,64
	call	?cpshd
	jp	nc,@1
	push	hl
	ld	h,l
	ld	l,0
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,bc
	ld	de,64
	call	?dvihd
	dec	h
	dec	h
	ld	(ix-12),l
	ld	(ix-11),h
	ld	hl,0
	ld	(ix-8),l
	ld	(ix-7),h
	ld	hl,0
	ld	(ix-6),l
	ld	(ix-5),h
	ld	hl,0
	ld	(ix-2),l
	ld	(ix-1),h
@3:
	ld	de,32
	call	?cpshd
	jp	nc,@2
	ld	l,(ix-8)
	ld	h,(ix-7)
	ld	e,l
	ld	d,h
	call	?mulhd
	ld	de,256
	call	?dvihd
	ld	(ix-4),l
	ld	(ix-3),h
	push	hl
	ld	l,(ix-6)
	ld	h,(ix-5)
	ld	e,l
	ld	d,h
	call	?mulhd
	ld	de,256
	call	?dvihd
	ex	de,hl
	pop	hl
	add	hl,de
	ld	c,e
	ld	b,d
	ex	de,hl
	ld	hl,1024
	call	?cpshd
	jp	c,@2
	push	bc
	ld	l,(ix-6)
	ld	h,(ix-5)
	ex	de,hl
	ld	l,(ix-8)
	ld	h,(ix-7)
	add	hl,hl
	call	?mulhd
	ld	de,256
	call	?dvihd
	ld	e,(ix-10)
	ld	d,(ix-9)
	add	hl,de
	ld	(ix-6),l
	ld	(ix-5),h
	pop	bc
	ld	l,(ix-4)
	ld	h,(ix-3)
	or	a
	sbc	hl,bc
	ld	e,(ix-12)
	ld	d,(ix-11)
	add	hl,de
	ld	(ix-8),l
	ld	(ix-7),h
	ld	l,(ix-2)
	ld	h,(ix-1)
	inc	hl
	ld	(ix-2),l
	ld	(ix-1),h
	jp	@3
@2:
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	de,32
	call	?dvihd
	ex	de,hl
	inc	d
	dec	d
	jp	p,@4
	ld	de,0
@4:
	ld	hl,9
	call	?cpshd
	jp	nc,@5
	ld	de,9
@5:
	ld	hl,shade_
	add	hl,de
	ld	a,(hl)
	call	putc_
	pop	hl
	inc	hl
	jp	@6
@1:
	ld	a,10
	call	putc_
	pop	hl
	inc	hl
	jp	@7
@0:
	ld	sp,ix
	pop	ix
	ret
;}


	public	shade_
	public	main_
	extrn	cputs_
	extrn	putc_
	extrn	?cpshd
	extrn	?dvihd
	extrn	?mulhd

	end
