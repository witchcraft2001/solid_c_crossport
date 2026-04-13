; Компилятор SOLID C  2-й проход
;
;  ДОС функции
;






	ds	80
stack1:	db	0			; адрес стека при вызове DSS


; вызов функций DSS
int10:	ld	(save_stack),sp
	ld	sp,stack1
	ex	af,af'
	in	a,(PAGE_0)
	push	af
	ld	a,(page_dss)
	out	(PAGE_0),a
	ex	af,af'
	ei
	rst	10h
	di
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
	;
block:	db	-1			; дескриптор выдел. блока памяти
	;
page0:	db	-1			; 0 стр.
page1:	db	-1			; 1 стр.
page3:	db	-1			; 3 стр.
	db	-1
	;
port89:	db	-1
portA2:	db	-1
portE2:	db	-1


L0080:	dw	0			; адрес ком-строки

save_stack:
	dw	0			; сохр. тек. стек



; вывод символа на экран
A0109:	cp	0Ah			; unix-концовка строки
	jr	nz,A0116
	ld	a,0Dh
	ld	c,5Bh
	call	int10
	ld	a,0Ah
A0116:	ld	c,5Bh			; вывод символа на экран
	jp	int10


; вывод строки на экран
A011E:	ld	a,(hl)
	or	a
	ret	z
	inc	hl
	push	hl
	call	A0109
	pop	hl
	jr	A011E


mess_abort:
	db	0Dh,0Ah,9
	db	"Pause... <Esc> to Quit or <AnyKey> to Continue",0Ah,0

; Проверка на нажатие <Esc>
test_Esc:
	ld	c,31h			; опрос клавиатуры без ожидания
	call	int10
	ret	z			; клавиша не нажата
	bit	7,d			; нажата одна клавиша ?
	ret	nz			; нет
	ld	hl,mess_abort
	ld	c,5Ch
	call	int10
	ld	c,30h			; ожидание ввода символа
	call	int10
	ld	hl,011Bh		; позиц. и ascii код клавиши <Еsc>
	and	a
	sbc	hl,de			; Esc ?
	ret	nz
	;
abort:	ld	sp,0BFFFh
	ld	a,(page_dss)
	out	(PAGE_0),a
	; закрыть выходной файл
	ld	a,(asm_handle)		; дескриптор asm-файла
	ld	c,12h
	rst	10h
	; удалить вых. файл
abort2:	ld	hl,asm_filename		; имя файла
	ld	a,20h			; атрибут "архивный"
	ld	c,0Eh
	rst	10h
abort1:	ld	b,-1			; возвр. код ошибки
	;
	; Выйти в ДОС
Exit:	ld	a,(page_dss)
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
	; закрыть .tmc файл
	ld	a,(tmc_handle)		; дескриптор tmc-файла
	ld	c,12h
	rst	10h
	; восст. тек. путь
	ld	a,(disk)
	ld	c,1			; уст. диск
	rst	10h
	ld	hl,dir
	ld	c,1Dh			; уст. каталог
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
;restore_path:
;	ld	a,(disk)
;	ld	c,1			; уст. диск
;	call	int10
;	ld	hl,dir
;	ld	c,1Dh			; уст. каталог
;	jp	int10





; Получить байт из буфера вход. файла
; (использует докачку из файла)
; выход: a=байт
read_byte:
	ld	a,(D99AA+1)		; ст.байт числа блока 512 байт
	bit	1,a			; уст. 1-й бит ?
	call	nz,read_block		; прочитать блок 512 байт
	ld	hl,T95A9		; 513, буфер для *.TMC файла
	ld	de,(D99AA)		; число байт для чтения
	add	hl,de			; hl+макс.512
	ld	a,(hl)
	inc	de
	ld	(D99AA),de		; число байт для чтения
	cp	0Dh			; конец строки в tmc-файле
	jr	z,read_byte
	ret
	;
read_block:
	ld	a,(tmc_handle)		; дескриптор .TMC файла
	ld	hl,T95A9		; 513, буфер для *.TMC файла
	ld	de,512			; 512 число чит. байт
	ld	c,13h			; чтение файла
	call	int10
	ld	hl,T95A9		; 513, буфер для *.TMC файла
	add	hl,de
	ld	(hl),1Ah		; отметить конец файла
	ld	hl,0
	ld	(D99AA),hl		; обнулить число байт для чтения
	ret



; Записать данные в буфер .asm файла.
; Если буфер заполнен - записать на диск.
; вход: a=запис. байт
write_byte:
	push	af
	ld	a,(D99AC+1)		; ст.байт
	bit	1,a			; уже 512 ?
	call	nz,write_block		; да, записать блок на диск
	pop	af
	ld	hl,T97AA		; 512, буфер для *.ASM файла
	ld	de,(D99AC)		; число байт для записи
	add	hl,de
	ld	(hl),a
	inc	de
	ld	(D99AC),de		; число байт для записи
	ret
	;
write_block:
	ld	a,(asm_handle)		; дескр. ASM файла
	ld	de,(D99AC)		; число запис. байт
	ld	hl,0
	ld	(D99AC),hl		; обнулить число запис. байт
	ld	hl,T97AA		; 512, буфер для *.ASM файла
	ld	c,14h			; запись файла
	call	int10
	ret	nc
	; ошибка записи
	push	af
	call	A02A2			; дозапись и закрытие asm-файла
	pop	af
	ld	hl,disk_full
	cp	0Ah			; код ошибки "disk full"
	jr	z,_full
	ld	hl,write_error
_full:	call	A011E			; вывод строки на экран
	jp	abort2			; выход в ДОС

disk_full:
	db	0Ah,"Disk full !",0Ah,0
write_error:
	db	0Ah,"Write error !",0Ah,0


; дозапись и закрытие asm-файла
A02A2:	ld	hl,(D99AC)		; число байт для записи
	ld	a,h
	or	l
	call	nz,write_block		; записать блок
	ld	a,(asm_handle)		; дескр. ASM файла
	ld	c,12h			; закрыть файл
	jp	int10



; Удалить файл т-кода
; вх: hl=имя файла (диск+путь)
del_tcode:
	ld	hl,tmc_filename		; имя tmc-файла   65 байт
	ld	c,0Eh			; удалить файл
	jp	int10



; Открыть .TMC файл
; вх: hl=имя файла (диск+путь)
open_file:
	ld	a,2			; ст.байт 512 (и уст. 1-го бита)
	ld	(D99AA+1),a		; число байт для чтения
	call	found_first		; найти файл
	ld	a,1			; на чтение
	ld	c,11h			; открыть файл
	call	int10
	jr	c,opn_err
	ld	(tmc_handle),a		; сохр. дескр. TMC-файл
	xor	a
	ret
opn_err:xor	a
	dec	a
	ret


; найти файл
; вх: hl=имя файла (диск+путь)
found_first:
	push	hl
	ld	de,f_path		; буфер 256 байт
	ld	bc,0119h
	ld	a,20h			; "архивный"
	call	int10
	pop	hl
	ret



; Создать .ASM файл
; вх: hl=имя файла (диск+путь)
create_file:
	ld	c,0Ah			; создать файл
	ld	a,20h			; атрибут "архивный"
	call	int10
	jr	c,crt_err
	ld	(asm_handle),a		; сохр. дескр. ASM файла
	xor	a
	ret
crt_err:xor	a
	dec	a
	ret






%if .comment
PR:	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	call	A011E
	;call	HEXHL
	call	NewLine
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

HEXA:	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	call	HEX1
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


NewLine:push	af
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
