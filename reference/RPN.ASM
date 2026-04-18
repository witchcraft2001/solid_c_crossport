	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	dseg
line_:	ds	42
sp_:	ds	2
stack_:	ds	80
pos_:	ds	2
num_:	ds	2
	cseg
;{
is_digit_:
	ld	de,48
	call	?cpshd
	jp	c,@0
	ex	de,hl
	ld	hl,57
	call	?cpshd
	jp	c,@0
	ld	hl,1
	ret
@0:
	ld	hl,0
	ret
;}

?63999:
	db	83,116,97,99,107,32,102,117,108,108
	db	10,0
;{
push_:
	ld	de,40
	ld	c,l
	ld	b,h
	ld	hl,(sp_)
	call	?cpshd
	jp	nc,@1
	push	bc
	ld	hl,(sp_)
	inc	hl
	ld	(sp_),hl
	add	hl,hl
	ld	bc,stack_-2
	add	hl,bc
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ret
@1:
	ld	hl,?63999
	call	cputs_
	ret
;}

?63998:
	db	83,116,97,99,107,32,101,109,112,116
	db	121,10,0
;{
pop_:
	ld	hl,(sp_)
	ex	de,hl
	ld	hl,0
	call	?cpshd
	jp	nc,@2
	ld	hl,(sp_)
	dec	hl
	ld	(sp_),hl
	add	hl,hl
	ld	bc,stack_
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret
@2:
	ld	hl,?63998
	call	cputs_
	ld	hl,0
	ret
;}

;{
top_:
	ld	hl,(sp_)
	ex	de,hl
	ld	hl,0
	call	?cpshd
	jp	nc,@3
	ld	hl,(sp_)
	add	hl,hl
	ld	bc,stack_-2
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret
@3:
	ld	hl,0
	ret
;}

;{
read_op_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	ld	hl,(pos_)
	ld	a,l
	or	h
	jp	nz,@4
	ld	a,40
	ld	(line_),a
	xor	a
	ld	(line_+1),a
	ld	hl,line_
	call	cgets_
	ld	a,l
	or	h
	jp	nz,@4
	ld	hl,0
	jp	@5
@4:
	ld	hl,(pos_)
	ld	bc,line_+2
	add	hl,bc
	ld	a,(hl)
	cp	32
	jp	z,@6
	ld	hl,(pos_)
	ld	bc,line_+2
	add	hl,bc
	ld	a,(hl)
	cp	9
	jp	nz,@7
@6:
	ld	hl,(pos_)
	inc	hl
	ld	(pos_),hl
	jp	@4
@7:
	ld	hl,(pos_)
	ld	bc,line_+2
	add	hl,bc
	ld	a,(hl)
	or	a
	jp	nz,@8
	ld	hl,0
	ld	(pos_),hl
	ld	hl,10
	jp	@5
@8:
	ld	hl,(pos_)
	ld	bc,line_+2
	add	hl,bc
	ld	l,(hl)
	ld	h,0
	ld	(ix-2),l
	ld	(ix-1),h
	call	is_digit_
	ld	a,l
	or	h
	jp	nz,@9
	ld	hl,(pos_)
	inc	hl
	ld	(pos_),hl
	ld	l,(ix-2)
	ld	h,(ix-1)
	jp	@5
@9:
	ld	hl,0
	ld	(num_),hl
@11:
	ld	hl,(pos_)
	ld	bc,line_+2
	add	hl,bc
	ld	a,(hl)
	call	is_digit_
	ld	a,l
	or	h
	jp	z,@10
	ld	hl,(pos_)
	ld	bc,line_+2
	add	hl,bc
	ld	a,(hl)
	sub	48
	ld	e,a
	ld	d,0
	ld	hl,(num_)
	add	hl,hl
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	(num_),hl
	ld	hl,(pos_)
	inc	hl
	ld	(pos_),hl
	jp	@11
@10:
	ld	hl,48
@5:
	ld	sp,ix
	pop	ix
	ret
;}

?63997:
	db	82,80,78,32,99,97,108,99,117,108
	db	97,116,111,114,32,40,39,46,39,32
	db	116,111,32,101,120,105,116,41,10,0
?63996:
	db	68,105,118,105,100,101,32,98,121,32
	db	122,101,114,111,10,0
?63995:
	db	61,61,62,32,37,100,10,0
?63994:
	db	85,110,107,110,111,119,110,32,116,111
	db	107,101,110,58,32,37,99,10,0
;{
main_:
	ld	hl,?63997
	call	cputs_
	ld	hl,0
	ld	(sp_),hl
	ld	hl,0
	ld	(pos_),hl
@19:
	call	read_op_
	ld	a,l
	or	h
	ret	z
	ld	a,l
	sub	48
	or	h
	jp	z,@12
	ld	a,l
	sub	43
	or	h
	jp	z,@13
	ld	a,l
	sub	42
	or	h
	jp	z,@14
	ld	a,l
	sub	45
	or	h
	jp	z,@15
	ld	a,l
	sub	47
	or	h
	jp	z,@16
	ld	a,l
	sub	46
	or	h
	ret	z
	ld	a,l
	sub	10
	or	h
	jp	z,@17
	jp	@18
@12:
	ld	hl,(num_)
	call	push_
	jp	@19
@13:
	call	pop_
	push	hl
	call	pop_
	pop	de
	add	hl,de
	call	push_
	jp	@19
@14:
	call	pop_
	push	hl
	call	pop_
	pop	de
	call	?mulhd
	call	push_
	jp	@19
@15:
	call	pop_
	push	hl
	call	pop_
	pop	de
	or	a
	sbc	hl,de
	call	push_
	jp	@19
@16:
	call	pop_
	ld	a,l
	or	h
	jp	nz,@20
	ld	hl,?63996
	call	cputs_
	jp	@19
@20:
	push	hl
	call	pop_
	pop	de
	call	?dvihd
	call	push_
	jp	@19
@17:
	call	top_
	push	hl
	ld	bc,?63995
	push	bc
	ld	hl,2
	call	cprintf_
	pop	bc
	pop	bc
	jp	@19
@18:
	push	hl
	ld	bc,?63994
	push	bc
	ld	hl,2
	call	cprintf_
	pop	bc
	pop	bc
	jp	@19
;}


	public	line_
	public	sp_
	public	stack_
	public	pos_
	public	num_
	public	is_digit_
	extrn	?cpshd
	public	push_
	extrn	cputs_
	public	pop_
	public	top_
	public	read_op_
	extrn	cgets_
	public	main_
	extrn	cprintf_
	extrn	?mulhd
	extrn	?dvihd

	end
