; Test 4: IX/IY addressing, IN/OUT, misc
	cseg

; IX/IY loads
	ld	ix,1000h
	ld	iy,2000h
	ld	(ix+5),a
	ld	a,(ix+0)
	ld	(iy-1),b
	ld	b,(iy+10)

; IX/IY arithmetic
	add	a,(ix+0)
	sub	(iy+3)
	inc	ix
	dec	iy

; IN/OUT
	in	a,(80h)
	out	(80h),a

; EX
	ex	de,hl
	ex	af,af'
	ex	(sp),hl

; Nested EQU expressions
BASE	equ	100h
OFFSET	equ	20h
ADDR	equ	BASE+OFFSET
SIZE	equ	ADDR-BASE
HALF	equ	SIZE/2

	ld	hl,ADDR
	ld	a,HALF

; DS with fill
	ds	10,0FFh

; Multiple DB
	db	1,2,3,4,5
	db	"ABCDE"
	dw	0,1234h,0ABCDh

	end
