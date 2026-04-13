; Библиотекарь OL.EXE
;
;  ДОС функции
;





; вывод "a" на экран
A02D6:	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	ld	c,5Bh
	rst	10h
	pop	iy
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret


;A02ED:	xor	a
;	ld	(D0D20),a
; на новую строку
nline:	ld	a,0Dh
	call	A02D6			; вывод "a" на экран
	ld	a,0Ah
	jp	A02D6			; вывод "a" на экран


; вывод строки на экран
A02FB:	push	af
	push	bc
	push	de
	push	ix
	push	iy
	ld	c,5Ch			; вывод строки
	rst	10h
	pop	iy
	pop	ix
	pop	de
	pop	bc
	pop	af
	ret


; вывод строки на экран, "b" счетчик
A0305:	ld	a,(hl)
	cp	" ";
	jr	nc,A0306;
	ld	a,".";
A0306:	call	A02D6			; вывод "a" на экран
	inc	hl
	djnz	A0305
	ret




; Найти файл
; вх: hl=имя файла (диск+путь)
found_first:
	push	hl
	push	de
	ld	de,f_path		; рабочий буфер 65 байт
	ld	bc,0119h		; DSS формат
	ld	a,20h			; "архивный"
	rst	10h
	pop	de
	pop	hl
	ret


; Прочитать 1024 байт из файла
read_file:
	ld	hl,A0DFF		; 1024 буфер
	push	hl
	ld	de,1024			; число чит. байт
	ld	a,(T0D90)		; дескриптор
	ld	c,13h			; чтение файла
	rst	10h
	pop	hl
	add	hl,de
	ld	(hl),-1
	ld	hl,0			; сбр. полож. в буфере
	ld	(D1201),hl
	ret


; Записать блок файла
A01EB:	ld	de,(D1203)		; число запис. байт
	ld	hl,0			; сбр. число запис. байт
	ld	(D1203),hl
	ld	hl,A1000		; 1024 буфер
	ld	a,(T0DB5)		; дескриптор
	ld	c,14h			; запись файла
	rst	10h
	ret	nc			; без ошибок
	call	A0236			; дописать и закрыть файл библы
	jp	A0C90			; "Library write error" и abort


; Дописать и закрыть файл библы
A0236:	ld	hl,(D1203)		; число запис. байт
	ld	a,h
	or	l
	call	nz,A01EB		; дописать файл
	ld	a,(T0DB5)		; дескриптор
	ld	c,12h			; закрыть файл
	rst	10h
	ret


; Закрыть файл
close_file:
	ld	a,(T0D90)		; дескриптор
	ld	c,12h			; закрыть файл
	rst	10h
	ret


; Удалить файл
; вход: hl=имя файла
del_file:
	ld	c,0Eh			; удалить файл
	rst	10h
	ret


; Переименовать файл
; вход: hl=старое имя файла
;       de=новое имя
rename_file:
	ld	c,10h			; переименовать файл
	rst	10h
	ret


; Открыть файл
; вход: hl=имя файла
open_file:
	ld	a,4			; ст.байт 1024-х
	ld	(D1201+1),a
	call	found_first		; найти файл
	ld	a,1			; на чтение
	ld	c,11h			; открыть файл
	rst	10h
	ld	b,a
	ld	a,-1
	ret	c			; ошибка
	ld	a,b
	ld	(T0D90),a		; сохр. дескриптор
	xor	a
	ret


; Создать файл
; вход: hl=имя файла
create_file:
	ld	c,0Ah			; создать файл
	ld	a,20h			; атрибут "архивный"
	rst	10h
	ld	b,a
	ld	a,-1
	ret	c			; ошибка
	ld	a,b
	ld	(T0DB5),a		; сохр. дескриптор
	xor	a
	ret


; Перемещение указателя в файле
; вход: hl=мл. адрес полож. указателя
move_pointer:
	push	hl
	pop	ix			; мл.разряд
	ld	hl,0			; ст.разряд
	ld	a,(T0D90)		; дескриптор
	ld	bc,0015h		; перем. указателя от начала файла
	rst	10h
	ld	a,4			; ст.байт 1024-х
	ld	(D1201+1),a
	ld	hl,0FF00h
	ld	(D0D1E),hl
	ret


	; Выход в ДОС
exit:	xor	a			; возвр. код (Ok)
abort:	ld	b,a
	push	bc
	; восст. тек. путь
	ld	a,(disk)
	ld	c,1			; уст. диск
	rst	10h
	ld	hl,dir
	ld	c,1Dh			; уст. каталог
	rst	10h
	; освоб. выделенный блок памяти
	ld	a,(block)
	ld	c,3Eh
	rst	10h
	ld	a,(portE2)
	out	(PAGE_3),a
	; очистить буфер клавы
	ld	bc,3135h
	rst	10h
	pop	bc
	ld	c,41h
	rst	10h
	ret



block:	db	-1			; дескриптор выдел. блока памяти
portE2:	db	-1			; сохр. значение

L0080:	dw	0			; адрес ком. строки




_irl:	db	".IRL",0		; расш. библиотеки
_rel:	db	".REL",0		; расш. модулей (добавл. файлов)

tmp_name1:
	db	"OLTMP1.$$$",0		; имя библы до ре-индексации
tmp_name2:
	db	"OLTMP2.$$$",0		; имя библы при ре-индексации



T04A3:	db	"Externals missing:",0Dh,0Ah,0

T0552:	db	"Creating new library: ",0
T0569:	db	"Updating library: ",0
T057C:	db	"Adding: ",0

T068B:	db	0Dh,0Ah,"Reindexing...",0
T069B:	db	" complete",0Dh,0Ah,0Ah,0


T0797:	db	"Module Skipped: ",0
T07A8:	db	"Extracting module: ",0

T07BC:	db	"*",0			; мета-символ


T0A82:	db	0Dh,0Ah,"Module name: ",0
T0A95:	db	"external ",0
T0A9F:	db	"public   ",0
reqname:db	"request  ",0
T0AA9:	db	"End of library.",0Dh,0Ah,0Ah,0
T0AB9:	db	"Code size: ",0
T0AC8:	db	",  Data size: ",0
T0AD5:	db	" = ",0


T0C96:	db	"File read error",0
T0CA6:	db	" : file not found",0
T0CC8:	db	"Library write error",0


; Индексированный список для функции вывода
; дампа библы (опция "d").
L0867:	db	"Entry symbol: &",0			; 0  имя метки (на которую имеется ссылка)
L088A:	db	"Select /&/ COMMON",0			; 1  имя common-блока
L089C:	db	"Start module: &",0			; 2  имя модуля
L08AD:	db	"Search library: &",0			; 3  request-имя файла
L08BE:	db	"Reserved item: &(0%h)",0			; 4  элемент расширения
L08CF:	db	"Set /&/ size to #",0			; 5  размер Common-блока
L08E1:	db	"External chain at # for &",0		; 6  внешнее имя
L08FD:	db	"Define & as #",0			; 7  метка: имя, адрес
L090D:	db	"External - # offset",0			; 8
L0921:	db	"External + # offset",0			; 9
L0935:	db	"DSEG length = $ byte(s)",0		; 10
L0945:	db	"ORG #",0				; 11  ORG сегмента cseg, dseg
L094B:	db	"Address chain at #",0			; 12
L095E:	db	"CSEG length = $ byte(s)",0		; 13
L096E:	db	"Module end, run address: #",0Dh,0Ah,0	; 14


; для функции вывода дампа библы (опция "d")
T083A:	db	"Byte=",0
T0840:	db	"Address=",0






/*
PR:	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	call	A02FB
	;call	HEXHL
	call	newline
	;call	HEXHL
	;ld	a," "
	;call	SYMB
	pop	iy
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

PR2:	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	push	de
	call	A02FB
	ld	a," "
	call	SYMB
	pop	hl
	call	A02FB
	ld	a,"*"
	call	SYMB
	call	newline
	pop	iy
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret


HEXA:	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	push	af
	call	HEX1
	call	newline
	pop	af
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	ret

HEXHL:	ld	a,h
	push	hl
	call	HEX1
	pop	hl
	ld	a,l
HEX1:	push	af
	rra
	rra
	rra
	rra
	call	HEX2
	pop	af
HEX2:	and	0Fh
	add	a,90h
	daa
	adc	a,40h
	daa
SYMB:	ld	c,5Bh			; вывод символа на экран
	rst	10h
	ret


newline:push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	ld	a,0Dh
	call	SYMB
	ld	a,0Ah
	call	SYMB
	pop	iy
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret
*/
