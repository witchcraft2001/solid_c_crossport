	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	dseg
errno_:	ds	1
	cseg
?63999:
	db	10,72,101,108,108,111,32,119,111,114
	db	108,100,32,33,10,0
?63998:
	db	143,224,168,162,165,226,32,172,168,224
	db	32,33,10,0
;{
main_:
	ld	bc,?63999
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	bc,?63998
	push	bc
	ld	bc,_iob_-14
	push	bc
	ld	hl,2
	call	fprintf_
	pop	bc
	pop	bc
	ret
;}


	public	errno_
	public	main_
	extrn	printf_
	extrn	fprintf_
	extrn	_iob_

	end
