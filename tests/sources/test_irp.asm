; Test: IRP and IRPC directives
	cseg

; REPT with body
	rept	4
	nop
	endm

; IRP - iterate over list
	irp	reg,<b,c,d,e>
	inc	reg
	endm

; IRPC - iterate over characters
	irpc	ch,ABCD
	db	'&ch'
	endm

; Macro with LOCAL
genlbl	macro
	local	skip
	jr	skip
	nop
skip:	nop
	endm

	genlbl
	genlbl

	end
