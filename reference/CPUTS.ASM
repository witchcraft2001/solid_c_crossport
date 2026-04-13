	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	cseg
buffer_:
	dw	?63999
?63999:
	db	73,110,115,101,114,116,32,100,97,116
	db	97,32,100,105,115,107,32,105,110,32
	db	100,114,105,118,101,32,65,58,10,0
;{
main_:
	ld	hl,(buffer_)
	call	cputs_
	ret
;}


	public	buffer_
	public	main_
	extrn	cputs_

	end
