; Отладочный загрузчик компилятора.
; Грузит не упакованный код компилятора.
;



; описание ds xx
%imacro ds 1
times %1 db 0
%endmacro



; данные файла "cc.bin"
dss_page equ	802Ah			; адрес ячейки "page_dss"
_size	 equ	1006h			; остаток файла: файл - (3F00h+4000h)


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
	ld	(page_dss),a
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
	ld	hl,no_space		; нет памяти
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
	ld	a,(page0)
	out	(PAGE_3),a
	;
	; очистить область #0000..#0100
	ld	hl,0C000h
loop:	xor	a
	ld	(hl),a
	inc	hl
	ld	a,h
	cp	0C1h
	jr	nz,loop
	;
	ld	hl,4DEDh		; "reti"
	;ld	hl,00C9h		; "ret"
	ld	(0C038h),hl
	; загрузить в page0 блок 0100..3FFF файла
	ld	hl,0C100h
	ld	de,3F00h		; длина блока
	ld	a,(hFile)
	ld	c,13h			; чтение файла
	rst	10h
	jp	c,disk_error
	; загрузить в page1 блок 4000..7FFF файла
	ld	a,(page1)
	out	(PAGE_3),a
	ld	hl,0C000h
	ld	de,4000h		; длина блока
	ld	a,(hFile)
	ld	c,13h
	rst	10h
	jp	c,disk_error
	; загрузить остаток файла в эту страницу
	ld	hl,8000h
	ld	de,_size		; размер остатка
	ld	a,(hFile)
	ld	c,13h
	rst	10h
	jp	c,disk_error
	; закрыть файл
	ld	a,(hFile)
	ld	c,12h
	rst	10h
	di
	; закрыть порт 89h
	ld	a,0C0h
	out	(89h),a
	; подкл. страницы
	ld	a,(page0)
	out	(PAGE_0),a		; блок 0100..3FFF
	ld	a,(page1)
	out	(PAGE_1),a		; блок 4000..7FFF
	ld	a,(page2)
	out	(PAGE_3),a		; страницу в 0C000h
	; скопир. хэндлы страниц
	ld	hl,page_dss
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


; порядок ячеек не менять
page_dss:
	db	-1			; сохр. номер страницы Estex
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
	db	"Based on SOLiD C compiler v1.00  (c) 1995 SolidSoft Inc."
	db	0Dh,0Ah,0Ah,0

no_space:
	db	"Not enough memory to load program !",0Dh,0Ah,0

load_err:
	db	"Disk loading error !",0Dh,0Ah,0

; конец загрузчика
end_loader:



module:
	incbin "cc.bin"
