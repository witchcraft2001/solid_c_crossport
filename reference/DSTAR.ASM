	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	dseg
board_:	ds	144
ball_pos_:	ds	2
box_pos_:	ds	2
mode_box_:	ds	2
	cseg
;{
init_level_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	ld	hl,0
	ld	(ix-4),l
	ld	(ix-3),h
@6:
	ld	de,12
	call	?cpshd
	jp	nc,@0
	ld	bc,0
	push	hl
@5:
	ld	l,c
	ld	h,b
	ld	de,12
	call	?cpshd
	jp	nc,@1
	push	bc
	ld	l,(ix-4)
	ld	h,(ix-3)
	ld	(ix-4),l
	ld	(ix-3),h
	add	hl,hl
	add	hl,hl
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,bc
	pop	bc
	add	hl,bc
	ld	(ix-2),l
	ld	(ix-1),h
	push	bc
	ld	l,(ix-4)
	ld	h,(ix-3)
	ld	a,c
	or	b
	jp	z,@2
	ld	a,l
	or	h
	jp	z,@2
	ld	a,c
	sub	11
	or	b
	jp	z,@2
	ld	a,l
	sub	11
	or	h
	jp	nz,@3
@2:
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	bc,board_
	add	hl,bc
	ld	(hl),35
	jp	@4
@3:
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	bc,board_
	add	hl,bc
	ld	(hl),46
@4:
	pop	bc
	inc	bc
	jp	@5
@1:
	pop	hl
	inc	hl
	ld	(ix-4),l
	ld	(ix-3),h
	jp	@6
@0:
	ld	a,42
	ld	(board_+39),a
	ld	a,42
	ld	(board_+44),a
	ld	a,42
	ld	(board_+98),a
	ld	a,42
	ld	(board_+105),a
	ld	a,42
	ld	(board_+66),a
	ld	hl,13
	ld	(ball_pos_),hl
	ld	hl,130
	ld	(box_pos_),hl
	ld	sp,ix
	pop	ix
	ret
;}

;{
remaining_gems_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	ld	hl,0
	ld	(ix-2),l
	ld	(ix-1),h
	ld	hl,0
@9:
	ld	de,144
	call	?cpshd
	jp	nc,@7
	push	hl
	ld	bc,board_
	add	hl,bc
	ld	a,(hl)
	cp	42
	jp	nz,@8
	ld	l,(ix-2)
	ld	h,(ix-1)
	inc	hl
	ld	(ix-2),l
	ld	(ix-1),h
@8:
	pop	hl
	inc	hl
	jp	@9
@7:
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	sp,ix
	pop	ix
	ret
;}

?63999:
	db	71,101,109,115,32,108,101,102,116,58
	db	32,37,100,10,0
?63998:
	db	77,111,100,101,58,32,37,115,10,0
?63997:
	db	66,79,88,0
?63996:
	db	66,65,76,76,0
?63995:
	db	77,111,118,101,58,32,87,65,83,68
	db	44,32,115,112,97,99,101,61,115,119
	db	105,116,99,104,44,32,114,61,114,101
	db	115,101,116,44,32,113,61,113,117,105
	db	116,10,0
;{
draw_board_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	ld	a,10
	call	putc_
	ld	hl,0
	ld	(ix-2),l
	ld	(ix-1),h
@16:
	ld	de,12
	call	?cpshd
	jp	nc,@10
	push	hl
	ld	hl,0
@15:
	ld	de,12
	call	?cpshd
	jp	nc,@11
	push	hl
	ld	l,(ix-2)
	ld	h,(ix-1)
	add	hl,hl
	add	hl,hl
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,bc
	pop	bc
	add	hl,bc
	ex	de,hl
	ld	hl,(ball_pos_)
	push	bc
	ld	a,e
	cp	l
	jr	nz,$+4
	ld	a,d
	cp	h
	jp	nz,@12
	ld	a,111
	call	putc_
	jp	@13
@12:
	ld	hl,(box_pos_)
	ld	a,e
	cp	l
	jr	nz,$+4
	ld	a,d
	cp	h
	jp	nz,@14
	ld	a,88
	call	putc_
	jp	@13
@14:
	ld	hl,board_
	add	hl,de
	ld	a,(hl)
	call	putc_
@13:
	pop	hl
	inc	hl
	jp	@15
@11:
	ld	a,10
	call	putc_
	pop	hl
	inc	hl
	ld	(ix-2),l
	ld	(ix-1),h
	jp	@16
@10:
	call	remaining_gems_
	push	hl
	ld	bc,?63999
	push	bc
	ld	hl,2
	call	cprintf_
	pop	bc
	pop	bc
	ld	hl,(mode_box_)
	ld	a,l
	or	h
	jp	z,@17
	ld	hl,?63997
	jp	@18
@17:
	ld	hl,?63996
@18:
	push	hl
	ld	bc,?63998
	push	bc
	ld	hl,2
	call	cprintf_
	pop	bc
	pop	bc
	ld	hl,?63995
	call	cputs_
	ld	sp,ix
	pop	ix
	ret
;}

;{
can_enter_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	hl
	push	de
	ex	de,hl
	ld	(ix-2),e
	ld	(ix-1),d
	ld	hl,board_
	add	hl,de
	ld	a,(hl)
	pop	de
	cp	35
	jp	nz,@19
	ld	hl,0
	jp	@20
@19:
	ld	a,e
	or	d
	jp	nz,@21
	ld	e,(ix-2)
	ld	d,(ix-1)
	ld	hl,board_
	add	hl,de
	ld	a,(hl)
	cp	42
	jp	nz,@21
	ld	hl,0
	jp	@20
@21:
	ld	hl,1
@20:
	ld	sp,ix
	pop	ix
	ret
;}

;{
slide_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	hl
	push	bc
	push	bc
	ld	(ix-2),l
	ld	(ix-1),h
	ld	hl,(mode_box_)
	ld	a,l
	or	h
	jp	z,@22
	ld	hl,box_pos_
	jp	@23
@22:
	ld	hl,ball_pos_
@23:
	ld	(ix-6),l
	ld	(ix-5),h
	ld	hl,(mode_box_)
	ld	a,l
	or	h
	jp	z,@24
	ld	hl,0
	jp	@25
@24:
	ld	hl,1
@25:
	ld	c,l
	ld	b,h
	ld	(ix-4),c
	ld	(ix-3),b
@29:
	ld	l,(ix-6)
	ld	h,(ix-5)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	e,(ix-2)
	ld	d,(ix-1)
	add	hl,de
	ld	e,c
	ld	d,b
	push	hl
	call	can_enter_
	pop	de
	ld	a,l
	or	h
	jp	z,@26
	ld	hl,(mode_box_)
	ld	a,l
	or	h
	jp	z,@27
	ld	hl,(ball_pos_)
	jp	@28
@27:
	ld	hl,(box_pos_)
@28:
	ld	a,e
	cp	l
	jr	nz,$+4
	ld	a,d
	cp	h
	jp	z,@26
	ld	l,(ix-6)
	ld	h,(ix-5)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	c,(ix-4)
	ld	b,(ix-3)
	ld	a,c
	or	b
	jp	z,@29
	ld	hl,board_
	add	hl,de
	ld	a,(hl)
	cp	42
	jp	nz,@29
	ld	hl,board_
	add	hl,de
	ld	(hl),46
	jp	@29
@26:
	ld	sp,ix
	pop	ix
	ret
;}

?63994:
	db	89,111,117,32,119,105,110,33,10,0
;{
main_:
	call	init_level_
	ld	hl,0
	ld	(mode_box_),hl
@33:
	call	draw_board_
	call	remaining_gems_
	ld	a,l
	or	h
	jp	nz,@30
	ld	hl,?63994
	call	cputs_
	ret
@30:
	call	getc_
	ld	a,l
	sub	113
	or	h
	ret	z
	ld	a,l
	sub	81
	or	h
	ret	z
	ld	a,l
	sub	114
	or	h
	jp	z,@31
	ld	a,l
	sub	82
	or	h
	jp	nz,@32
@31:
	call	init_level_
	ld	hl,0
	ld	(mode_box_),hl
	jp	@33
@32:
	ld	a,l
	sub	32
	or	h
	jp	nz,@34
	ld	hl,(mode_box_)
	ld	a,l
	xor	1
	ld	l,a
	ld	(mode_box_),hl
	jp	@33
@34:
	ld	a,l
	sub	119
	or	h
	jp	z,@35
	ld	a,l
	sub	87
	or	h
	jp	nz,@36
@35:
	ld	hl,65524
	call	slide_
	jp	@33
@36:
	ld	a,l
	sub	115
	or	h
	jp	z,@37
	ld	a,l
	sub	83
	or	h
	jp	nz,@38
@37:
	ld	hl,12
	call	slide_
	jp	@33
@38:
	ld	a,l
	sub	97
	or	h
	jp	z,@39
	ld	a,l
	sub	65
	or	h
	jp	nz,@40
@39:
	ld	hl,65535
	call	slide_
	jp	@33
@40:
	ld	a,l
	sub	100
	or	h
	jp	z,@41
	ld	a,l
	sub	68
	or	h
	jp	nz,@33
@41:
	ld	hl,1
	call	slide_
	jp	@33
;}


	public	board_
	public	ball_pos_
	public	box_pos_
	public	mode_box_
	public	init_level_
	extrn	?cpshd
	public	remaining_gems_
	public	draw_board_
	extrn	putc_
	extrn	cprintf_
	extrn	cputs_
	public	can_enter_
	public	slide_
	public	main_
	extrn	getc_

	end
