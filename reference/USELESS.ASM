	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	cseg
?63999:
	db	45,45,45,45,45,45,45,45,45,45
	db	45,45,45,45,45,45,45,45,45,45
	db	45,45,45,45,45,45,45,45,45,45
	db	45,45,45,45,45,45,45,45,45,45
	db	10,0
?63998:
	db	32,32,65,32,115,105,108,108,121,44
	db	32,112,111,105,110,116,108,101,115,115
	db	32,100,101,109,111,32,102,111,114,32
	db	97,112,112,32,102,108,111,119,32,32
	db	10,0
?63997:
	db	45,45,45,45,45,45,45,45,45,45
	db	45,45,45,45,45,45,45,45,45,45
	db	45,45,45,45,45,45,45,45,45,45
	db	45,45,45,45,45,45,45,45,45,45
	db	10,0
?63996:
	db	67,111,109,109,97,110,100,115,58,32
	db	101,61,101,97,116,32,100,61,100,114
	db	105,110,107,32,115,61,115,108,101,101
	db	112,32,113,61,113,117,105,116,10,0
;{
redrawscreen_:
	ld	hl,?63999
	call	cputs_
	ld	hl,?63998
	call	cputs_
	ld	hl,?63997
	call	cputs_
	ld	hl,?63996
	call	cputs_
	ret
;}

?63995:
	db	83,111,32,121,111,117,32,119,97,110
	db	116,32,116,111,46,46,46,32,101,97
	db	116,10,0
?63994:
	db	83,111,32,121,111,117,32,119,97,110
	db	116,32,116,111,46,46,46,32,100,114
	db	105,110,107,10,0
?63993:
	db	83,111,32,121,111,117,32,119,97,110
	db	116,32,116,111,46,46,46,32,115,108
	db	101,101,112,10,0
?63992:
	db	85,110,107,110,111,119,110,32,99,111
	db	109,109,97,110,100,10,0
;{
handlecmd_:
	ld	a,l
	sub	101
	or	h
	jp	z,@0
	ld	a,l
	sub	69
	or	h
	jp	nz,@1
@0:
	ld	hl,?63995
	call	cputs_
	ret
@1:
	ld	a,l
	sub	100
	or	h
	jp	z,@2
	ld	a,l
	sub	68
	or	h
	jp	nz,@3
@2:
	ld	hl,?63994
	call	cputs_
	ret
@3:
	ld	a,l
	sub	115
	or	h
	jp	z,@4
	ld	a,l
	sub	83
	or	h
	jp	nz,@5
@4:
	ld	hl,?63993
	call	cputs_
	ret
@5:
	ld	a,l
	sub	113
	or	h
	ret	z
	ld	a,l
	sub	81
	or	h
	jp	nz,@6
	ret
@6:
	ld	hl,?63992
	call	cputs_
	ret
;}

;{
main_:
	call	redrawscreen_
@7:
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
	sub	10
	or	h
	jp	z,@7
	ld	a,l
	sub	13
	or	h
	jp	z,@7
	call	handlecmd_
	jp	@7
;}


	public	redrawscreen_
	extrn	cputs_
	public	handlecmd_
	public	main_
	extrn	getc_

	end
