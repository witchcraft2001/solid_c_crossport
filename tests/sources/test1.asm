; Simple test file for AS cross-assembler
	cseg

start:	ld	hl,1234h
	ld	a,0
	ld	b,c
	inc	hl
	dec	a
	push	hl
	pop	de
	add	a,b
	sub	c
	and	0FFh
	or	a
	xor	b
	cp	0
	ret	nz
	jp	start
	call	start
	ret

msg:	db	"Hello",0
val:	dw	1234h
buf:	ds	10

	end	start
