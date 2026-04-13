; Отладочный загрузчик ассемблера.
; Грузит не упакованный код.
;



; описание ds xx
%imacro ds 1
times %1 db 0
%endmacro



; данные файла "asm1.bin"
dss_page equ	83ACh			; адрес ячейки "block"


; порты страниц
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
	; выделить 2 стр. памяти
	ld	bc,023Dh
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
	; загрузить в page0 блок 4000..7FFF файла
	ld	a,(page0)
	out	(PAGE_3),a
	ld	hl,0C000h
	ld	de,4000h		; длина блока
	ld	a,(hFile)
	ld	c,13h
	rst	10h
	jp	c,disk_error
	; загрузить остаток файла в эту страницу
	ld	hl,8000h
	ld	de,(endmod-module)-4000h	; размер остатка
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
	out	(PAGE_1),a		; блок 4000..7FFF
	ld	a,(page1)
	out	(PAGE_3),a		; страницу в 0C000h
	; скопир. хэндлы страниц
	ld	hl,block
	ld	de,dss_page		; адрес ячейки block в "asm1.bin"
	ld	bc,7
	ldir
	; перейти на программу
L0080:	ld	hl,0			; адрес ком. строки
	jp	4000h



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
block:	db	-1			; дескриптор выдел. блока памяти
	;
page0:	db	-1
page1:	db	-1
	db	-1
	;
port89:	db	-1
portA2:	db	-1
portE2:	db	-1




Title:	db	"Macro Assembler v0.01b  Ported by Vasil Ivanov.",0Dh,0Ah
	db	"Based on Macro Assembler v1.5 (c) 1995, SOLiD",0Dh,0Ah,0


no_space:
	db	"Not enough memory to load program !",0Dh,0Ah,0

load_err:
	db	"Disk loading error !",0Dh,0Ah,0

; конец загрузчика
end_loader:



module:
	incbin "as1.bin"
endmod:
