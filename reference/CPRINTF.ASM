	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	cseg
?63999:
	db	72,101,108,108,111,44,32,119,111,114
	db	108,100,33,10,0
;{
main_:
	ld	bc,?63999
	push	bc
	ld	hl,1
	call	cprintf_
	pop	bc
	ret
;}


	public	main_
	extrn	cprintf_

	end
