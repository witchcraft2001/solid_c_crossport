; Test 2: Various Z80 instructions
	cseg

; Basic loads
	ld	a,0FFh
	ld	b,10
	ld	c,d
	ld	(hl),a
	ld	a,(hl)
	ld	hl,1234h
	ld	de,5678h
	ld	bc,0
	ld	sp,0FFFFh

; Arithmetic
	add	a,b
	adc	a,c
	sub	d
	sbc	a,e
	and	h
	or	l
	xor	a
	cp	0

; Jumps and calls
label1:	jp	label1
	jr	label1
	call	label1
	ret
	ret	z
	ret	nz

; Stack
	push	af
	push	bc
	push	de
	push	hl
	pop	af
	pop	bc
	pop	de
	pop	hl

; Simple instructions
	nop
	halt
	di
	ei
	scf
	ccf
	cpl
	daa
	exx
	rlca
	rrca
	rla
	rra

; CB-prefix
	rl	b
	rr	c
	rlc	d
	rrc	e
	sla	h
	sra	l
	srl	a

; Bit ops
	bit	0,a
	bit	7,b
	res	3,c
	set	5,d

; Block instructions
	ldir
	lddr
	cpir
	cpdr

; INC/DEC
	inc	a
	inc	b
	inc	hl
	inc	de
	dec	a
	dec	b
	dec	sp

; DJNZ
	djnz	label1

; RST
	rst	0
	rst	8
	rst	38h

; IM
	im	0
	im	1
	im	2

; Data
msg:	db	"Test",0
val:	dw	1234h

	end
