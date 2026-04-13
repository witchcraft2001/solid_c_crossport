; Компилятор SOLID C  1-й проход
;
;  ДОС функции
;





; Вызов dss-функций
int10:	ld	(save_stack),sp
	ld	sp,stack1
	ex	af,af'
	in	a,(PAGE_0)
	push	af
	ld	a,(page_dss)
	out	(PAGE_0),a
	ex	af,af'
	push	ix
	push	iy
	ei
	rst	10h
	di
	pop	iy
	pop	ix
	ex	af,af'
	pop	af
	out	(PAGE_0),a
	ld	a,0C0h
	out	(89h),a			; закрыть порт 89h
	ex	af,af'
	ld	sp,(save_stack)
	ret



; порядок ячеек не менять
page_dss:
	db	-1			; сохр. номер страницы Estex

block:	db	-1			; дескриптор выдел. блока памяти

page0:	db	-1			; 0 стр.
page1:	db	-1			; 1 стр.
page3:	db	-1			; 3 стр.
	db	-1


port89:	db	-1
portA2:	db	-1
portE2:	db	-1

L0080:	dw	0			; адрес ком-строки


	ds	80
stack1:	db	0			; адрес стека при вызове DSS

save_stack:
	dw	0			; сохр. тек. стек



; расш. файлов по-умолчанию
T7E66:	db	".C",0
T7E6B:	db	".TMC",0		; коррект. также на ".tco"
T7E72:	db	".ERR",0




; Вывод "a" на экран
A015E:	cp	0Ah			; unix-концовка строки
	jr	nz,A016B
	ld	a,0Dh
	ld	c,5Bh
	call	int10
	ld	a,0Ah
A016B:	ld	c,5Bh			; вывод символа на экран
	jp	int10



; Вывод строки на экран
A0170:	ld	a,(hl)
	or	a
	ret	z
	inc	hl
	push	hl
	call	A015E			; вывод "a" на экран
	pop	hl
	jr	A0170



;mess_abort:
;	db	0Dh,0Ah,9
;	db	"Pause... <Esc> to Quit or <AnyKey> to Continue",0Ah,0

; Убрана из-за некорректного порядка закрытия файлов
; Проверка на нажатие <Esc>
;test_Esc:
;	push	bc
;	push	de
;	call	_esc
;	pop	de
;	pop	bc
;	ret

;_esc:	ld	c,31h			; опрос клавиатуры без ожидания
;	call	int10
;	ret	z			; клавиша не нажата
;	bit	7,d			; нажата одна клавиша ?
;	ret	nz			; нет
;	ld	hl,mess_abort
;	ld	c,5Ch
;	call	int10
;	ld	c,30h			; ожидание ввода символа
;	call	int10
;	ld	hl,011Bh		; позиц. и ascii код клавиши <Еsc>
;	and	a
;	sbc	hl,de			; Esc ?
;	ret	nz
;	jp	abort			; закрыть все файлы и выйти в ДОС



	; Выход в ДОС
Exit:	push	bc
	call	restore_path		; восст. тек. путь
	pop	bc
	ld	a,(page_dss)
	out	(PAGE_0),a
	ld	a,(portA2)
	out	(PAGE_1),a
	ld	a,(portE2)
	out	(PAGE_3),a
	ld	a,(port89)
	out	(89h),a
	ld	sp,0BFFFh
	ei
	push	bc
	; освоб. выделенный блок памяти
	ld	a,(block)
	ld	c,3Eh
	rst	10h
	; очистить буфер клавы
	ld	bc,3135h
	rst	10h
	pop	bc
	ld	c,41h
	rst	10h
	ret


; Сохр. тек. путь
save_path:
	ld	c,2			; узнать тек. диск
	call	int10
	ld	(disk),a
	ld	hl,dir
	ld	c,1Eh			; узнать тек. каталог
	jp	int10


; Восст. тек. путь
restore_path:
	ld	a,(disk)
	ld	c,1			; уст. диск
	call	int10
	ld	hl,dir
	ld	c,1Dh			; уст. каталог
	jp	int10




; Найти файл
; вх: hl=имя файла (диск+путь)
found_first:
	push	hl
	push	de
	ld	de,f_path		; рабочий буфер 65 байт
	ld	bc,0119h		; DSS формат
	ld	a,20h			; "архивный"
	call	int10
	pop	de
	pop	hl
	ret



; Открыть входной файл
; вход: de=индекс в таблице "L064E" описателя (FCB) файла
;       hl=адрес имени файла
open_file:
	push	hl
	ex	de,hl
	ld	(indx1+1),hl
	add	hl,hl			;1+1=2
	add	hl,hl			;2+2=4
	add	hl,hl			;4+4=8
	ld	bc,L064E		; таблица буферов и FCB файлов
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			; de=описатель файла
	pop	hl			; имя файла
	;call	PR1			; выв. имя файла
	; версия ос
	push	de			; de=L75B6 для .c файла
	call	found_first		; найти файл
	ld	a,1			; на чтение
	ld	c,11h			; открыть файл
	call	int10
open1:	pop	de
	ld	b,a
	ld	a,-1
	ret	c			; ошибка
	ld	a,b
	ld	(de),a			; сохр. дескриптор
	;
indx1:	ld	hl,0
	ld	bc,dirs			; начало буферов
	add	hl,hl		;1+1=2
	ld	e,l
	ld	d,h
	add	hl,hl		;2+2=4
	add	hl,hl		;4+4=8
	add	hl,hl		;8+8=16
	add	hl,hl		;16+16=32
	add	hl,hl		;32+32=64
	add	hl,de		;64+2=66
	add	hl,bc
	push	hl
	ld	c,2			; узнать тек. диск
	call	int10
	ld	(hl),a			; номер диска
	pop	hl
	inc	hl			; hl=строка пути
	ld	c,1Eh			; узнать тек. каталог
	call	int10
	call	restore_path		; восст. тек. путь
	xor	a
	ret




; Создать .tmc (.err) файл
;
; вход: hl=имя файла
;       de=индекс в таблице "L064E" описателя (FCB) файла
;       (5 для *.tmc, 6 для *.err)
create_file:
	push	hl
	ex	de,hl
	ld	(indx1+1),hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,L064E		; таблица буферов и FCB файлов
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			; de=описатель файла
	pop	hl			; имя файла
	;call	PR1			; выв. имя файла
	; версия ос
	push	de
	ld	c,0Ah			; создать файл
	ld	a,20h			; атрибут "архивный"
	call	int10
	jr	open1




; Закрыть файл
; вход: hl=индекс в таблице "L064E" описателя (FCB) файла
close_file:
	push	hl
	call	set_path
	pop	hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,L064E		; таблица буферов и FCB файлов
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			; de=описатель файла
	; версия ос
	ld	a,(de)			; дескр. файла
	ld	c,12h			; закрыть файл
	call	int10
	ld	a,-1			; ошибка
	ret	c
	xor	a
	ret

set_path:
	add	hl,hl		;1+1=2
	ld	e,l
	ld	d,h
	add	hl,hl		;2+2=4
	add	hl,hl		;4+4=8
	add	hl,hl		;8+8=16
	add	hl,hl		;16+16=32
	add	hl,hl		;32+32=64
	add	hl,de		;64+2=66
	ld	de,dirs			; начало буферов
	add	hl,de
	push	hl
	ld	a,(hl)			; номер диска
	ld	c,1			; уст. диск
	call	int10
	pop	hl
	inc	hl			; hl=строка пути
	ld	c,1Dh			; уст. каталог
	jp	int10




; Прочитать блок из файла
; вход: hl=индекс в таблице "L064E" описателя (FCB) файла
;       bc=число байт
;       de=адрес буфера
read_file:
	push	bc
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,L064E		; таблица буферов и FCB файлов
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)			; bc=описатель файла
	ex	de,hl			; hl=буфер для *.TMC файла
	pop	de			; de=число чит. байт
	; версия ос
	ld	a,(bc)			; дескр. файла
	ld	c,13h			; чтение файла
	call	int10
	ex	de,hl			; hl=число прочит. байт
	ret




; Записать блок в файл
; вход: hl=индекс в таблице "L064E" описателя (FCB) файла
;       bc=число байт
;       de=адрес буфера
write_file:
	push	bc
	ld	(indx2+1),hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,L064E		; таблица буферов и FCB файлов
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)			; bc=описатель файла
	ex	de,hl			; hl=буфер данных
	pop	de			; de=число запис. байт
	; версия ос
	ld	a,(bc)			; дескр. файла
	push	bc
	ld	c,14h			; запись файла
	call	int10
	pop	bc
	ret	nc
	; ошибка записи
	push	af
	push	bc
indx2:	ld	hl,0
	call	set_path
	pop	bc
	ld	a,(bc)			; дескр. файла
	ld	c,12h			; закрыть файл
	call	int10
	pop	af
	ld	hl,disk_full
	cp	0Ah			; код ошибки "disk full"
	jr	z,_full
	ld	hl,write_error
_full:	call	A0170			; вывод строки на экран
	ld	b,-1			; код ошибки
	jp	Exit			; выход в ДОС

disk_full:
	db	0Ah,"Disk full !",0Ah,0
write_error:
	db	0Ah,"Write error !",0Ah,0











%if .comment
PR:	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	;call	HEXHL
	push	hl
	ld	a,(hl)
	add	a,"A"
	call	SYMB
	pop	hl
	inc	hl
	call	A0170			; вывод строки
	ld	a,"-"
	call	SYMB
	call	nline
	pop	iy
	pop	ix
	pop	hl
	pop	de
	pop	bc
	pop	af
	ret

PR1:	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	ld	a,(hl)
	cp	" "
	jr	nc,.loc1
	ld	a,"#"
	call	SYMB
.loc1:	call	A0170			; вывод строки
	call	nline
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
	call	nline
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
	jp	int10


nline:	push	af
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
%endif
