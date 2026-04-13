; Релизный загрузчик компилятора.
; Грузит упакованный код компилятора.
;



; описание ds xx
%imacro ds 1
times %1 db 0
%endmacro



; данные файла "cc.bin"
dss_page equ	802Ah			; адрес ячейки page_dss


; порты страниц
PAGE_0	equ	82h
PAGE_1	equ	0A2h
PAGE_3	equ	0E2h



	org	0A200h

	db	"EXE"			; exe ID
	db	0			; exe версия
	dw	512			; 512, мл. смещ. кода
	dw	0			; ст. смещ. кода
	dw	end_loader - entry	; end-beg, первичный загрузчик
	dw	0,0,0			; резерв
	dw	entry			; адрес загрузки кода
	dw	entry			; адрес передачи управления
	dw	0BF00h			; адрес стека
	ds	490


entry:	; очистить буфер клавы
	ld	bc,3135h
	rst	10h
	; сохр. номер страницы DSS
	in	a,(PAGE_0)
	ld	(_dss),a
	in	a,(PAGE_1)
	ld	(portA2),a
	in	a,(PAGE_3)
	ld	(portE2),a
	in	a,(89h)
	ld	(port89),a
	;
	ld	(L0080+1),ix		; сохр. адрес ком-строки
	ld	a,(ix-3)
	ld	(hFile),a		; сохр. тек. дескриптор
	ld	hl,Title		; титл программы
	ld	c,5Ch
	rst	10h
	; выделить 3 стр. памяти
	ld	bc,033Dh
	rst	10h
	jr	nc,next1		; Ok
no_mem:	ld	hl,no_space		; нет памяти
	ld	c,5Ch
	rst	10h
	ld	bc,0FF41h		; exit
	rst	10h

next1:	ld	(block),a		; хэндл выдел. блока памяти
	; получить список страниц
	ld	hl,page0
	ld	c,0C5h
	rst	08h
	;
	; выделить 1 стр. памяти
	ld	bc,013Dh
	rst	10h
	jr	c,no_mem		; нет памяти
	ld	(tmp_page),a
	; подкл. ее в #C000
	out	(PAGE_3),a
	;
	; закрыть порт #89
	ld	a,0C0h
	out	(89h),a
	;------------------------- 1 -----------------------------------
	; загрузить 1-ю часть
	ld	hl,0C000h		; куда
	ld	de,part2-part1		; длина блока
	ld	a,(hFile)
	ld	c,13h			; чтение файла
	rst	10h
	jp	c,disk_error
	; подкл. 0 стр. в #4000
	ld	a,(page0)
	out	(PAGE_1),a
	; очистить область #0000..#0100
	ld	hl,4000h
loop:	xor	a
	ld	(hl),a
	inc	hl
	ld	a,h
	cp	41h
	jr	nz,loop
	;
	ld	hl,4DEDh		; "reti"
	;ld	hl,00C9h		; "ret"
	ld	(4038h),hl
	; распаковать 1-ю часть
	ld	hl,0C000h		; откуда
	ld	de,4100h		; куда
	call	dehrust
	;------------------------- 2 -----------------------------------
	ld	hl,0C000h		; куда
	ld	de,part3-part2		; длина блока
	ld	a,(hFile)
	ld	c,13h			; чтение файла
	rst	10h
	jp	c,disk_error
	; подкл. 1 стр. в #4000
	ld	a,(page1)
	out	(PAGE_1),a
	; распаковать 2-ю часть
	ld	hl,0C000h		; откуда
	ld	de,4000h		; куда
	call	dehrust
	;------------------------- 3 -----------------------------------
	ld	hl,0C000h		; куда
	ld	de,endpart-part3	; длина блока
	ld	a,(hFile)
	ld	c,13h			; чтение файла
	rst	10h
	jp	c,disk_error
	; распаковать 3-ю часть (остаток файла)
	ld	hl,0C000h		; откуда
	ld	de,8000h		; куда
	call	dehrust

	; закрыть файл
	ld	a,(hFile)
	ld	c,12h
	rst	10h
	; освоб. врем. страницу
	ld	a,(tmp_page)
	ld	c,3Eh
	rst	10h
	di
	; подкл. страницы
	ld	a,(page0)
	out	(PAGE_0),a		; блок 0100..3FFF
	ld	a,(page1)
	out	(PAGE_1),a		; блок 4000..7FFF
	ld	a,(page2)
	out	(PAGE_3),a		; страницу в 0C000h
	; скопир. хэндлы страниц
	ld	hl,_dss
	ld	de,dss_page		; адрес ячейки page_dss в "ccc.bin"
	ld	bc,9
	ldir
	; перейти на программу
L0080:	ld	hl,0			; адрес ком. строки
	jp	0100h


disk_error:
	ld	a,(block)
	ld	c,3Eh			; освоб. выдел. блок памяти
	rst	10h
	ld	a,(hFile)
	ld	c,12h			; закрыть файл
	rst	10h
	ld	hl,load_err
	ld	c,5Ch
	rst	10h
	ld	bc,0FF41h
	rst	10h			; exit


hFile:	db	0			; дескр. файла

tmp_page:
	db	-1			; страница для упак. частей файла


; порядок ячеек не менять
_dss:	db	-1			; сохр. номер страницы Estex
block:	db	-1			; дескриптор выдел. блока памяти
	;
page0:	db	-1
page1:	db	-1
page2:	db	-1
	db	-1
	;
port89:	db	-1
portA2:	db	-1
portE2:	db	-1



Title:	db	"SOLID C Optimizing Compiler v0.01b (pass 1)  Ported by Vasil Ivanov",0Dh,0Ah
	db	"Based on SOLiD C compiler v1.00  Copyright (c) 1995 SolidSoft "
	db	"Inc.",0Dh,0Ah,0Ah,0

no_space:
	db	"Not enough memory to load program !",0Dh,0Ah,0

load_err:
	db	"Disk loading error !",0Dh,0Ah,0



; Формат упак. файла:
;  +0 (word) "HR" - сигнатура
;  +2 (word) - длина исходного файла
;  +4 (word) - длина упакованного файла
;
; Распаковщик
;  hl=откуда
;  de=куда
dehrust:
	ld	ix,-12
	add	ix,sp
	push	de
	ld	sp,hl
	pop	bc
	ex	de,hl
	pop	bc
	dec	bc
	add	hl,bc
	ex	de,hl
	pop	bc
	dec	bc
	add	hl,bc
	sbc	hl,de
	add	hl,de
	jr	c,loc1
	ld	d,h
	ld	e,l
loc1:	lddr
	ex	de,hl
	ld	d,(ix+11)
	ld	e,(ix+10)
	ld	sp,hl
	pop	hl
	pop	hl
	pop	hl
	ld	b,6
loc2:	dec	sp
	pop	af
	ld	(ix+6),a
	inc	ix
	djnz	loc2
	exx
	ld	d,0BFh
	ld	bc,1010h
	pop	hl
loc3:	dec	sp
	pop	af
	exx
loc4:	ld	(de),a
	inc	de
loc5:	exx
loc6:	add	hl,hl
	djnz	loc7
	pop	hl
	ld	b,c
loc7:	jr	c,loc3
	ld	e,1
loc8:	ld	a,80h
loc9:	add	hl,hl
	djnz	loc10
	pop	hl
	ld	b,c
loc10:	rla
	jr	c,loc9
	cp	3
	jr	c,loc11
	add	a,e
	ld	e,a
	xor	c
	jr	nz,loc8
loc11:	add	a,e
	cp	4
	jr	z,loc26
	adc	a,0FFh
	cp	2
	exx
loc12:	ld	c,a
loc13:	exx
	ld	a,0BFh
	jr	c,loc17
loc14:	add	hl,hl
	djnz	loc15
	pop	hl
	ld	b,c
loc15:	rla
	jr	c,loc14
	jr	z,loc16
	inc	a
	add	a,d
	jr	nc,loc18
	sub	d
loc16:	inc	a
	jr	nz,loc20
	ld	a,0EFh
loc17:	rrca
	cp	a
loc18:	add	hl,hl
	djnz	loc19
	pop	hl
	ld	b,c
loc19:	rla
	jr	c,loc18
loc20:	exx
	ld	h,0FFh
	jr	z,loc21
	ld	h,a
	dec	sp
	inc	a
	jr	z,loc24
	pop	af
loc21:	ld	l,a
	add	hl,de
	ldir
loc22:	jr	loc5
	;
loc23:	exx
	rrc	d
	jr	loc6
	;
loc24:	pop	af
	cp	0E0h
	jr	c,loc21
	rlca
	xor	c
	inc	a
	jr	z,loc23
	sub	10h
loc25:	ld	l,a
	ld	c,a
	ld	h,0FFh
	add	hl,de
	ldi
	dec	sp
	pop	af
	ld	(de),a
	inc	hl
	inc	de
	ld	a,(hl)
	jr	loc4
	;
loc26:	ld	a,80h
loc27:	add	hl,hl
	djnz	loc28
	pop	hl
	ld	b,c
loc28:	adc	a,a
	jr	nz,loc31
	jr	c,loc27
	ld	a,0FCh
	jr	loc32
	;
loc29:	dec	sp
	pop	bc
	ld	c,b
	ld	b,a
	ccf
	jr	loc13
	;
loc30:	cp	0Fh
	jr	c,loc29
	jr	nz,loc12
	add	a,0F4h
	ld	sp,ix
	jr	loc34
	;
loc31:	sbc	a,a
	ld	a,0EFh
loc32:	add	hl,hl
	djnz	loc33
	pop	hl
	ld	b,c
loc33:	rla
	jr	c,loc32
	exx
	jr	nz,loc25
	bit	7,a
	jr	z,loc30
	sub	0EAh
loc34:	ex	de,hl
loc35:	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	dec	a
	jr	nz,loc35
	ex	de,hl
	jr	nc,loc22
	ret

; конец загрузчика
end_loader:



; Упакованные части программы
part1:
	incbin "cc1"
part2:
	incbin "cc2"
part3:
	incbin "cc3"
endpart:
