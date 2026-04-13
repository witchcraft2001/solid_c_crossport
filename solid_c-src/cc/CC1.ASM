; Последняя редакция  20.01.2004
;


; описание ds xx
%imacro ds 1
times %1 db 0
%endmacro

; описание ds xx,yy
%imacro ds 2
times %1 db %2
%endmacro

; описание комментария
%idefine .comment  0

%idefine yes	1
%idefine no	0



;
; Компилятор SOLID C  1-й проход (генератор т-кода)
;
;
;
; Примечания по компилятору:
; ~~~~~~~~~~~~~~~~~~~~~~~~~~
;  ■  При компиляции "чужих" исходников ставить опцию -k.
;
;  ■  В опциях: -dNAME, -jN, -oNAME и -rP:S:H пробелы не допускаются.
;
;  ■  80 символов - макс. длина полного пути (disk+path+file.ext) файлов.
;     Для тек.пути, пути include-файлов, для функции "found_first"
;     буферы по 256 байт. Переполнения не отслеживаются.
;
;  ■  Файл "file.err" создается всегда в текущем пути входного .c файла.
;
;  ■  Убрана опция "-iPATH". Формат записи include-файлов только как:
;        #include <file.ext>  - поиск ведется только в папке .\INCLUDE
;                               расположения компилятора.
;        #include "file.ext"  - поиск ведется только в папке расположения
;                               входного .c файла.
;     Задание пути в имени файла не допускается !. Имя папки "INCLUDE"
;     зарезервировано.
;
;  √  4 - макс. число одновременно открытых include-файлов.
;  √  Переделаны вызовы "call" A4F02 на "jp".
;  √  Переделаны вызовы "call" A06C7 на "jp".
;  √  Переделаны вызовы "call" A4F27 на "jp".
;  √  Поставил один флаг "mode", вместо "mode1" и "mode2".
;  -  Убрана "test_Esc" из-за траблы с закрытием файлов (потому, что
;     ячейка "D76C1" используется для .c и для include-файлов).
;
;
; Коды возврата компилятора:
;   00h  - Ok
;   0FFh - были errors/warnings, ошибки выделения памяти или работы с файлами.
;



; Что делают макросы ?:
;  __SOLIDC__, __Z80__, _CHAR_UNSIGNED, MSXDOS, __LINE__, __FILE__
;







true	equ	1
false	equ	0

; порты страниц
PAGE_0	equ	82h
PAGE_1	equ	0A2h
PAGE_3	equ	0E2h

Stack	equ	0FFF0h			; начало стека



; константы ?
L0000	equ	0000h
L0029	equ	0029h
L0032	equ	0032h
L0033	equ	0033h
L003D	equ	003Dh
L0040	equ	0040h
L0098	equ	0098h



	org	100h

	jp	start


; сравнение строк hl,de
A0103:	ld	c,(hl)
	inc	hl
	ld	a,(de)
	inc	de
	cp	c
	jr	nz,.loc1
	inc	c
	dec	c
	jr	nz,A0103
	ld	a,true
	ret
.loc1:	xor	a			; false
	ret


isupper:cp	"A"
	jr	c,.loc1
	cp	"Z"+1
	jr	nc,.loc1
	ld	a,true
	ret
.loc1:	xor	a			; false
	ret


islower:cp	"a"
	jr	c,.loc1
	cp	"z"+1
	jr	nc,.loc1
	ld	a,true
	ret
.loc1:	xor	a			; false
	ret


toupper:cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	sub	20h
	ret


A0136:	ld	c,a
	call	isupper
	or	a
	ret	nz			; true, выйти
	ld	a,c
	jp	islower


isdigit:cp	"0"
	jr	c,.loc1
	cp	"9"+1
	jr	nc,.loc1
	ld	a,true
	ret
.loc1:	xor	a			; false
	ret


; neg hl
A014D:	inc	h
	dec	h
	ret	p
	ld	a,l
	cpl
	ld	l,a
	ld	a,h
	cpl
	ld	h,a
	inc	hl
	ret


;6
; ix=описатель файла
A03B0:	ld	(ix+4),0		; сбр. число прочит. байт
	ld	(ix+5),0
	bit	2,(ix+1)		; 1024 ?
	jr	z,A03C2			; нет
	ld	a,-1
	ret
A03C2:	ld	c,(ix+10)
	ld	b,(ix+11)		; bc=число байт для чтения
	ld	e,(ix+6)
	ld	d,(ix+7)		; de=адрес буфера
	ld	l,(ix+8)
	ld	h,(ix+9)		; hl=индекс в таблице "L064E" описателя (FCB) файла
	push	ix
	call	read_file		; прочитать блок из файла
	pop	ix
	ld	(ix+4),l		; hl=число прочит. байт
	ld	(ix+5),h
	ld	a,l
	or	h
	jr	nz,A03ED		; Ok
	set	2,(ix+1)		; ошибка, уст. 2-й бит (т.е.1024)
	ld	a,-1
	ret
A03ED:	xor	a
	jp	A04F7


A03F1:	ld	c,(ix+10)		; число байт для записи
	ld	b,(ix+11)
	jp	A04D8			; записать в файл


;7
; Открыть или создать файл
; вход:
;   hl=адрес имени файла
;   ;de=адрес строки "r" или "w"
;   a="R"/"W" соотв. чтение или запись файла
;   bc=индекс (в таблице L064E):
;        0 - для .c файла
;     1..4 - для include-файлов
;        5 - для .tmc файла
;        6 - для .err файла
;
A03FA:	;ld	(D75AC),hl
	ld	(A0445+1),hl
	ld	l,c
	ld	h,b
	;ld	(D75AE),hl		; индекс в таблице "L064E"
	ld	(A0442+1),hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,L064E		; таблица адресов буферов
	add	hl,bc
	;ld	(D75B0),hl
	ld	(A04AC+1),hl
	push	hl
	inc	hl
	inc	hl
	;ld	(D75B2),de		; сохр. адрес "r/w"
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	af,af'
	xor	a
	ld	(de),a
	ex	af,af'
	pop	hl
	push	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,6
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	;ld	hl,(D75B2)		; адрес "r" или "w"
	;ld	a,(hl)
	;call	toupper
	pop	hl
	cp	"R"			; файл на чтение
	jr	z,A0441
	cp	"W"			; файл на запись
	jr	z,A0467
	jr	A04A1
	;
	; файл на чтение
A0441:	push	de
A0442:	ld	de,0			; индекс в таблице "L064E"
	;ld	de,(D75AE)
A0445:	ld	hl,0			; адрес имени файла 8.3
	;ld	hl,(D75AC)
	call	open_file		; открыть файл
	pop	de
	inc	a
	jr	nz,A0455		; Ok
	ld	hl,0			; ошибка
	ret
	;
A0455:	ld	hl,1
	add	hl,de
	ld	(hl),1			; ст.байт 256-ти ?
	ld	hl,4
	add	hl,de
	ld	(hl),0
	inc	hl
	ld	(hl),0
	jr	A04A1
	;
	; создать файл на запись
A0467:	push	hl
	push	de
	;ld	de,(D75AE)		; индекс в таблице "L064E"
	ld	de,(A0442+1)
	;ld	hl,(D75AC)
	ld	hl,(A0445+1)		; адрес имени файла
	call	create_file		; создать .tmc (.err) файл
	pop	de
	pop	hl
	inc	a
	jr	nz,A047D		; Ok
	ld	hl,0			; ошибка
	ret
	;
A047D:	push	hl
	ld	hl,1
	add	hl,de
	ld	(hl),2			; ст.байт 512-ти ?
	pop	hl
	ld	bc,6
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,4
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,6
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,2
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	;
A04A1:	ld	hl,8
	add	hl,de
;*	push	de
	;ld	de,(D75AE)		; индекс в таблице "L064E"
	ld	bc,(A0442+1)
	ld	(hl),c
	inc	hl
	ld	(hl),b
A04AC:	ld	hl,0
	;ld	hl,(D75B0)
	ld	bc,6
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
;*	pop	de
	ld	hl,10
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ex	de,hl
	ret


; записать блок файла
; вход: ix-описатель файла
A04C2:	ld	a,(ix+0)
	or	a
	ret	nz
	ld	c,(ix+4)		; число записанных байт
	ld	b,(ix+5)
	ld	l,(ix+10)		; число байт для записи
	ld	h,(ix+11)
	or	a
	sbc	hl,bc
	ld	c,l			; bc=число байт для записи
	ld	b,h
A04D8:	ld	l,(ix+8)		; hl=индекс в таблице "L064E" описателя (FCB) файла
	ld	h,(ix+9)
	ld	e,(ix+6)		; de=адрес буфера
	ld	d,(ix+7)
	push	ix
	call	write_file		; записать блок в файл
	pop	ix
	ld	c,(ix+10)		; число байт для записи
	ld	b,(ix+11)
	ld	(ix+4),c		; число записанных байт
	ld	(ix+5),b
A04F7:	ld	c,(ix+6)		; de=адрес буфера
	ld	b,(ix+7)
	ld	(ix+2),c
	ld	(ix+3),b
	ret


; Записать посл. блок (если надо) и закрыть файл
A0504:	ld	a,l
	or	h
	jr	nz,A050B
	xor	a
	ret
A050B:	ld	e,0
	ld	a,(hl)
	push	hl
	or	a
	jr	nz,A0528
	pop	ix
	push	ix
	bit	1,(ix+1)		; 512 ?
	call	nz,A04C2		; да, записать блок в файл
	ld	l,(ix+8)
	ld	h,(ix+9)		; hl=индекс в таблице "L064E" описателя (FCB) файла
	call	close_file		; закрыть файл
	ld	e,a
A0528:	pop	hl
	inc	hl
	ld	(hl),0			; сбр. ст.байт (ix+1)
	ld	a,e
	ret


A052E:	ld	a,(hl)
	inc	hl
	or	a
	ret	z
	push	hl
	push	de
	call	A0572
	pop	de
	pop	hl
	jr	A052E


; вход: hl-описатель файла
A053C:	push	hl
	pop	ix
	ld	a,(ix+4)		; число чит. байт ?
	or	(ix+5)			;
	jr	nz,A0553
	call	A03B0			; чтение блока файла
	inc	a
	jr	nz,A0553
	ld	hl,-1
	ret
A0553:	ld	l,(ix+4)
	ld	h,(ix+5)
	dec	hl
	ld	(ix+4),l
	ld	(ix+5),h
	ld	l,(ix+2)		; тек. указатель в блоке
	ld	h,(ix+3)
	ld	a,(hl)			; получить байт из блока
	inc	hl
	ld	(ix+2),l
	ld	(ix+3),h
	ld	l,a
	ld	h,0
	ret


; вход: de=?  (также описатель файла)
A0572:	cp	0Ah
	jr	nz,A057F
	push	de
	ld	a,0Dh
	call	A0572
	pop	de
	ld	a,0Ah
A057F:	;ld	(D75A9),a
	ld	(A05A9+1),a;
	ld	a,(de)
	or	a
	jr	z,A058C
	dec	a
	jr	z,A05B7
	ret
A058C:	push	de
	pop	ix
	ld	a,(ix+4)
	or	(ix+5)
	call	z,A03F1			; записать блок файла
	ld	l,(ix+4)
	ld	h,(ix+5)
	dec	hl
	ld	(ix+4),l
	ld	(ix+5),h
	ld	l,(ix+2)
	ld	h,(ix+3)
A05A9:	ld	a," "
	;ld	a,(D75A9)
	ld	(hl),a
	inc	hl
	ld	(ix+2),l
	ld	(ix+3),h
	ret
A05B7:	ld	a,(A05A9+1)
	;ld	a,(D75A9)
	cp	0Dh
	ret	z
	jp	A015E			; вывод "a" на экран


; Вывод строки (для fprintf)
A05C0:	ld	de,L0642		; также описатель .err файла
	jp	A052E			; записать строку "hl" в файл


; Вывод "a" (для fprintf)
A05C6:	ld	de,L0642		; также описатель .err файла
	jp	A0572			; записать блок в файл




; не станд. выход в ДОС
abort:	ld	b,-1			; код ошибки
; станд. выход в ДОС
A05E2:	push	bc			; сохр. код возврата
	ld	a,0Dh
	call	A015E			; вывод "a" на экран
	;
	ld	hl,(D76C1)		; файл *.c     =L05FA
	call	A0504			; закрыть файл
	;
	ld	hl,(D76C3)		; файл *.tmc   =L0636
	call	A0504			; записать посл. блок (если надо) и закрыть файл
	;
	ld	hl,(D76C5)		; файл *.err   =L0642
	call	A0504			; записать посл. блок (если надо) и закрыть файл
	pop	bc			; восст. код возврата
	jp	Exit


; Таблица 6-ти описателей файлов (72 байта)
; ...



A0686:	call	L18A7
	call	A1651
	call	A5790
	ld	a,(D76CE)		; false/true displays memory usage statistics
	or	a
	call	nz,info			; вывести статистику по занятости таблиц
	ld	a,(D76C7)		; false/true флаг наличия ошибок компиляции
	or	a
	jr	z,A06A5
	ld	hl,T06AE		; "errors detected"
	call	A0170			; вывод строки на экран
	jp	abort			; выход в ДОС
	;
A06A5:	ld	hl,T06BE		; "complete"
	call	A0170			; вывод строки на экран
	ld	b,0			; код ошибки (Ok)
	jp	A05E2			; закрыть файлы и выйти в ДОС



A06C7:	push	de
	call	A0170			; вывод строки на экран
	pop	hl
	call	A0170
	ld	a,"]"
	call	A015E			; вывод "a" на экран
	jp	abort			; выход в ДОС



A06E6:	push	af
	call	A0136
	pop	bc
	or	a
	ret	nz
	ld	a,b
	cp	"_"			; 5Fh
	jr	nz,A06E4
	ld	a,true
	ret
A06E4:	xor	a			; false
	ret


A06F5:	cp	"\"			; 5Ch
	ret	nz
	call	A0E3E
	ld	(D77D2),a
	call	isdigit
	or	a
	jr	z,A0737
	ld	a,(D77D2)
	sub	"0"
	ld	(D77D3),a
	ld	b,2
A070E:	push	bc
	call	A0E3E
	pop	bc
	ld	(D77D2),a
	sub	"0"
	jr	c,A072E
	cp	8
	jr	nc,A072E
	ld	c,a
	ld	a,(D77D3)
	add	a,a
	add	a,a
	add	a,a
	add	a,c
	ld	(D77D3),a
	djnz	A070E
	jp	A07B9
	;
A072E:	ld	a,(D77D2)
	call	A0F0F
	jp	A07B9
	;
A0737:	ld	a,(D77D2)
	ld	hl,T074B
	ld	bc,9
	cpir
	ret	nz
	add	hl,bc
	add	hl,bc
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jp	(hl)


T074B:	db	"ntbrfvaxX"
	;
	dw	L077B			; X
	dw	L077B			; x
	dw	L0775			; a
	dw	L0772			; v
	dw	L076F			; f
	dw	L0769			; r
	dw	L076C			; b
	dw	L0778			; t
	dw	L0766			; n


L0766:	ld	a,0Ah
	ret

L0769:	ld	a,0Dh
	ret

L076C:	ld	a,8
	ret

L076F:	ld	a,0Ch
	ret

L0772:	ld	a,0Bh
	ret

L0775:	ld	a,7
	ret

L0778:	ld	a,9
	ret

L077B:	call	A0E3E
	ld	(D77D2),a
	xor	a
	ld	(D77D3),a
	ld	b,2
A0787:	push	bc
	ld	a,(D77D2)
	call	toupper
	pop	bc
	sub	"0"
	jr	c,A07B3
	cp	9+1
	jr	c,A079D
	sub	7
	cp	10h
	jr	nc,A07B3
A079D:	ld	c,a
	ld	a,(D77D3)
	add	a,a		;1+1=2
	add	a,a		;2+2=4
	add	a,a		;4+4=8
	add	a,a		;8+8=16
	add	a,c		;16+1=17
	ld	(D77D3),a
	push	bc
	call	A0E3E
	pop	bc
	ld	(D77D2),a
	djnz	A0787
A07B3:	ld	a,(D77D2)
	call	A0F0F
A07B9:	ld	a,(D77D3)
	ret


A07BD:	ld	l,a
	ld	a,e
	cp	0FBh
	jr	nz,A07C7
	ld	a,true
	ret
	;
A07C7:	ld	a,e
	cp	0FAh
	jr	nz,A07E4
	ld	a,l
	push	hl
	call	A06E6
	pop	hl
	or	a
	jr	nz,A07E2
	ld	a,l
	call	isdigit
	or	a
	jr	nz,A07E2
	ld	a,true
	ret
A07E2:	xor	a			; false
	ret
A07E4:	ld	a,l
	cp	e
	jr	nz,A07EC		; соптимизировать
	ld	a,true
	ret
A07EC:	xor	a			; false
	ret


A07EE:	ex	de,hl
	ld	hl,0
A07F2:	ld	a,(de)
	or	a
	ret	z
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	inc	de
	ld	c,a
	ld	b,0
	add	hl,bc
	jr	A07F2
	;
A0802:	ld	(D77D5),hl
	push	hl
	ld	hl,(D77D7)
	ld	(D77D9),hl
	pop	hl
	call	A07EE
	ld	de,(D77D7)
	call	A750B
	ld	(D77DB),de
A081D:	ex	de,hl
	add	hl,hl
	add	hl,hl
	ex	de,hl
	ld	hl,(D77DD)
	add	hl,de
	ld	a,(hl)
	inc	hl
	or	(hl)
	dec	hl
	ret	z
	push	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D77D5)
	call	A0103			; сравнение строк hl/de
	pop	hl
	or	a
	ret	nz			; true
	ld	hl,(D77D9)
	dec	hl
	ld	(D77D9),hl
	ld	a,l
	or	h
	ld	a,0			; индекс строки "hash table"
	jp	z,A4F02			; abort
	ld	de,(D77D7)
	ld	hl,(D77DB)
	ld	c,l
	ld	b,h
	ld	hl,5
	add	hl,bc
	call	A750B
	ld	(D77DB),de
	jr	A081D


A085F:	push	de
	ld	de,(D77E7)
	ld	hl,(D77E9)
	scf
	sbc	hl,de
	jr	c,A08A8
	ld	(de),a
	inc	de
	pop	hl
A0870:	ld	(D77ED),hl
	ld	hl,(D77E9)
	scf
	sbc	hl,de
	jr	c,A08A8
	ld	hl,(D77ED)
	ld	a,(hl)
	inc	hl
	ld	(de),a
	inc	de
	or	a
	jr	nz,A0870
	ld	hl,(D77E7)
	push	de
	call	A0802
	pop	de
	ld	a,(hl)
	inc	hl
	or	(hl)
	dec	hl
	ret	nz
	push	hl
	ld	bc,(D77E7)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	(D77E7),de
	pop	hl
	ret
A08A8:	ld	a,1			; индекс строки "pool"
	jp	A4F02			; abort


A08AD:	ld	(D77EF),a
	xor	a
	ld	(D77F0),a
	ld	hl,(D77E7)
	ld	(D77F1),hl
A08BA:	ld	hl,(D77E9)
	ld	de,(D77F1)
	scf
	sbc	hl,de
	jp	c,A08A8			; вверх
	ld	a,(D77F0)
	inc	a
	cp	" "			; 20h
	jr	nc,A08DC
	ld	(D77F0),a
	ld	a,(D77EF)
	ld	(de),a
	inc	de
	ld	(D77F1),de
A08DC:	call	A0E3E
	ld	(D77EF),a
	cp	"_"			; 5Fh
	jr	z,A08BA
	cp	"0"
	jr	c,A08FE
	cp	"9"+1
	jr	c,A08BA
	cp	"A"
	jr	c,A08FE
	cp	"Z"+1
	jr	c,A08BA
	cp	"a"
	jr	c,A08FE
	cp	"z"+1
	jr	c,A08BA
A08FE:	call	A0F0F
	xor	a
	ld	hl,(D77F1)
	ld	(hl),a
	inc	hl
	ld	(D77F1),hl
D090A:	ld	hl,(D77E7)
	call	A0802
	ld	(D77FD),hl
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	nz,A0928
	ld	de,(D77E7)
	ld	hl,(D77FD)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D77F1)
	ld	(D77E7),hl
A0928:	ld	a,true
	ret



A0934:	ld	hl,D78A8
	ld	(hl),0
	ld	hl,A7880
	ld	(hl),a
	inc	hl
	ld	(hl),0
	cp	"0"
	jr	nz,A095D
	push	hl
	call	A0E3E
	ld	(D77D2),a
	pop	hl
	cp	"."
	jp	z,A09F1
	cp	"X"
	jr	z,A0959
	cp	"x"
	jr	nz,A0962
A0959:	ld	a,"X"
	ld	(hl),a
	inc	hl
A095D:	push	hl
	call	A0E3E
	pop	hl
A0962:	ld	(D77D2),a
	cp	"0"
	jr	c,A0988
	cp	"9"+1
	jr	c,A0983
	ld	c,a
	ld	a,(A7880+1)
	cp	"X"
	jr	nz,A0988
	ld	a,c
	call	toupper
	cp	"A"
	jr	c,A0988
	cp	"F"+1
	jr	nc,A0988
	sub	7
A0983:	ld	(hl),a
	inc	hl
	jr	A095D
	;
A0988:	ld	a,(D77D2)
	cp	"."
	jr	z,A09F1
	push	hl
	call	A0136
	pop	hl
	or	a
	jr	nz,A09A4
	ld	a,(D77D2)
	push	hl
	call	A0F0F
	pop	hl
	xor	a
	jp	A0A6A
	;
A09A4:	ld	a,(D77D2)
	call	toupper
	cp	"U"
	jr	z,A09BB
	cp	"E"
	jr	z,A0A0D
	ld	a,(D77D2)
	push	hl
	call	A0F0F
	pop	hl
A09BB:	push	hl
	call	A0E3E
	pop	hl
	cp	"L"
	jp	z,A0A6A
	cp	"l"
	jp	z,A0A6A
	push	hl
	call	A0136
	pop	hl
	or	a
	jp	z,A0A6A
	call	A0F0F
A09D6:	ld	hl,(D77CC)		; номер колонки
	push	hl
	ld	hl,(D77CA)		; номер строки
	push	hl
	ld	hl,T092B		; "XBnumber"
	push	hl
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,0
	ld	(D77FD),hl
	ld	a,2
	ret
A09F1:	ld	(hl),a
	inc	hl
	push	hl
	call	A0E3E
	ld	(D77D2),a
	pop	hl
	cp	"0"
	jr	c,A0A2D
	cp	"9"+1
	jr	c,A09F1
	cp	"E"
	jr	z,A0A0D
	cp	"e"
	jr	nz,A0A2D
A0A0D:	ld	a,"E"
	ld	(hl),a
	inc	hl
	push	hl
	call	A0E3E
	pop	hl
	cp	"+"
	jr	z,A0A1E
	cp	"-"
	jr	nz,A0A25
A0A1E:	ld	(hl),a
	inc	hl
	push	hl
	call	A0E3E
	pop	hl
A0A25:	cp	"0"
	jr	c,A0A2D
	cp	"9"+1
	jr	c,A0A1E
A0A2D:	ld	(hl),0
	call	A0F0F
	ld	a,(A7880+1)
	cp	"X"
	;jr	z,A09D6
	jr	A09D6
	; ??
;	ld	hl,A7880		; !  ds 40
;	ld	de,LF586		; !
;	ld	bc,40
;	ldir
	;
;	call	LF560			; !  п/п из T0B3E, 50 байт, не перенесено
;	ld	de,(D77E7)
;	push	de
;	ld	a,(LF663)		; ! 0C41
;	ld	c,a
;	cp	8
;	ld	a,23h			; "#"
;	jr	nz,A0A59
;	ld	a,21h			; "!"
;A0A59:	ld	(de),a
;	inc	de
;	ld	b,0			; +c=счетчик
;	ldir
;	ld	(D77E7),de
;	pop	hl
;	ld	(D77FD),hl
;	ld	a,3
;	ret

A0A6A:	and	5Fh
	ld	(D78A8),a
	ld	(hl),0
	ld	hl,A7880
	ld	de,0
	exx
	ld	hl,0
	exx
	ld	a,(hl)
	cp	"0"
	jr	nz,A0AB1
	inc	hl
	ld	a,(hl)
	cp	"X"
	jr	z,A0AE6
A0A89:	ld	a,(hl)
	sub	"0"
	jp	c,A0B0E
	cp	8
	jp	nc,A0B0E
	inc	hl
	ex	de,hl
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	ld	c,a
	ld	b,0
	add	hl,bc
	jr	nc,A0AAE
	exx
	inc	hl
	exx
A0AAE:	ex	de,hl
	jr	A0A89
	;
A0AB1:	sub	"0"
	ld	e,a
A0AB4:	inc	hl
	ld	a,(hl)
	sub	"0"
	jp	c,A0B0E
	cp	0Ah
	jp	nc,A0B0E
	ex	de,hl
	ld	c,l
	ld	b,h
	add	hl,hl
	exx
	ld	c,l
	ld	b,h
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,bc
	exx
	adc	hl,bc
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	ld	b,0
	ld	c,a
	add	hl,bc
	jr	nc,A0AE2
	exx
	inc	hl
	exx
A0AE2:	ex	de,hl
	jr	A0AB4
	;
A0AE6:	inc	hl
	ld	a,(hl)
	sub	"0"
	jr	c,A0B0E
	ex	de,hl
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	add	hl,hl
	exx
	adc	hl,hl
	exx
	ld	c,a
	ld	b,0
	add	hl,bc
	jr	nc,A0B0B
	exx
	inc	hl
	exx
A0B0B:	ex	de,hl
	jr	A0AE6
	;
A0B0E:	ex	de,hl
	ld	(D77FD),hl
	exx
	ld	a,h
	or	l
	ld	(D77FF),hl
	jr	nz,A0B22
	ld	a,(D78A8)
	cp	"L"			; 4Ch
	ld	a,2
	ret	nz
A0B22:	ld	de,(D77E7)
	ld	hl,D77FD
	push	de
	ld	a,"%"			; 25h
	ld	(de),a
	inc	de
	ld	bc,4
	ldir
	ld	(D77E7),de
	pop	hl
	ld	(D77FD),hl
	ld	a,3
	ret



A0B6D:	call	A4F68
A0B70:	call	A0E3E
	cp	22h			; "
	jr	z,A0B88
	cp	0Ah
	jr	z,A0B88
	cp	1Ah
	jr	z,A0B88
	call	A06F5
	call	A4F87
	jr	A0B70
	;
A0B88:	cp	22h			; "
	jr	z,A0BA1
	call	A0F0F
	ld	hl,(D77CC)		; номер колонки
	push	hl
	ld	hl,(D77CA)		; номер строки
	push	hl
	ld	bc,T0B65
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A0BA1:	xor	a
	call	A4F87
	call	A4FC2
	ld	(D77FD),hl
	ld	a,5
	ret


A0BC6:	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T0BAE
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jp	abort			; выход в ДОС


A0BF3:	ld	de,(D77E9)
	ld	hl,(D77EB)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A0C2D
	ld	hl,(D77E9)
	ld	a,(hl)
	inc	hl
	inc	hl
	inc	hl
	ld	(D77E9),hl
	push	af
	dec	hl
	ld	a,(hl)
	dec	hl
	ld	l,(hl)
	ld	h,a
	ld	(D77FD),hl
	pop	af
	cp	0C9h
	ret	nz
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T0BDB
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A0BF3
	;
A0C2D:	call	A0E3E
	ld	(D78AA),a
	cp	" "
	jr	z,A0C2D
	cp	9			; Tab
	jr	z,A0C2D
	ld	hl,(D77CA)
	ld	(D77F9),hl		; номер строки
	ld	hl,(D77CC)
	ld	(D77F7),hl		; номер колонки
	call	A06E6
	or	a
	jr	z,A0C56
	ld	a,(D78AA)
	jp	A08AD
	;
A0C56:	ld	a,(D78AA)
	call	isdigit
	or	a
	jr	z,A0C66
	ld	a,(D78AA)
	jp	A0934
	;
A0C66:	ld	a,(D78AA)
	cp	27h			; '
	jr	nz,A0C9A
	call	A0E3E
	call	A06F5
	ld	l,a
	ld	h,0
	ld	(D77FD),hl
	call	A0E3E
	cp	27h			; '
	jr	z,A0C97
	call	A0F0F
	ld	hl,(D77CC)		; номер колонки
	push	hl
	ld	hl,(D77CA)		; номер строки
	push	hl
	ld	bc,T0BDF
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A0C97:	ld	a,4
	ret
A0C9A:	cp	22h			; "
	jr	nz,A0CA2
	jp	A0B6D
	;
A0CA2:	cp	"."
	jr	nz,A0CC6
	call	A0E3E
	cp	"0"
	jr	c,A0CBE
	cp	"9"+1
	jr	nc,A0CBE
	call	A0F0F
	ld	a,"."
	call	A0F0F
	ld	a,"0"
	jp	A0934
	;
A0CBE:	call	A0F0F
	ld	a,"."
	ld	(D78AA),a
A0CC6:	cp	1Ah
	jr	nz,A0CCE
	ld	a,0FAh			; токен ?
	ret
A0CCE:	cp	0Ah
	jr	nz,A0CD6
	ld	a,0F8h			; тоже ?
	ret
A0CD6:	cp	"/"
	jr	nz,A0CF8
	call	A0E3E
	cp	"/"
	jr	nz,A0CF0
A0CE1:	call	A0E3E
	cp	1Ah
	jp	z,A0C2D
	cp	0Ah
	jr	nz,A0CE1
	jp	A0C2D
	;
A0CF0:	call	A0F0F
;-	ld	a,2Fh			; "/"  ??
	jr	A0D12
	;
A0CF8:	cp	"\"
	jr	nz,A0D12
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T0BE7
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jp	A0C2D
	;
A0D12:	ld	bc,0
A0D15:	ld	hl,L1B2A
	add	hl,bc
	ld	a,(hl)
	ld	hl,L1B29
	add	hl,bc
	sub	(hl)
	ld	l,a
	ld	h,0
	ld	(D78AE),hl
	ld	hl,L1B29
	add	hl,bc
	ld	l,(hl)
	ld	h,0
	ld	(D78AC),hl
A0D2F:	ld	hl,(D78AE)
	dec	hl
	ld	(D78AE),hl
	inc	hl
	ld	a,l
	or	h
	jr	nz,A0D51
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T0BE7
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jp	A0C2D
	;
A0D51:	ld	hl,(D78AC)
	ld	c,l
	ld	b,h
	inc	bc
	ld	l,c
	ld	h,b
	ld	(D78AC),hl
	ld	hl,L1A97
	add	hl,bc
	ld	e,(hl)
	ld	a,(D78AA)
	call	A07BD
	or	a
	jr	z,A0D2F
	ld	bc,(D78AC)
	dec	bc
	ld	hl,L1A98
	add	hl,bc
	ld	a,(D78AA)
	cp	(hl)
	jr	nz,A0D87
	push	bc
	call	A0E3E
	ld	(D78AA),a
	pop	bc
	jr	A0D15
	;
A0D87:	ld	hl,L1B29
	add	hl,bc
	ld	l,(hl)
	ld	h,0
	ld	bc,L1A98
	add	hl,bc
	ld	l,(hl)
	ld	h,0
	ld	a,l
	sub	0F9h
	or	h
	jr	z,A0DA6
	ld	a,(D78AA)
	push	hl
	call	A0F0F
	pop	hl
	ld	a,l
	ret
	;
A0DA6:	ld	a,(D76CA)		; true/false  флаг вложения комментариев
	or	a
	jr	z,A0E07
	ld	a,1
	ld	(D78AB),a
A0DB2:	ld	a,(D78AA)
	cp	1Ah			; код конца файла ?
	jr	z,A0DC7
	cp	"*"
	jr	z,A0DCA
	cp	"/"
	jr	z,A0DE0
	jr	A0DF3
	;
A0DC7:	call	A0BC6
A0DCA:	call	A0E3E
	ld	(D78AA),a
	cp	"/"
	jr	nz,A0DF9
	ld	hl,(D78AB)
	dec	l
	ld	a,l
	ld	(D78AB),a
	jr	A0DF3
	;
A0DE0:	call	A0E3E
	ld	(D78AA),a
	cp	"*"
	jr	nz,A0DF9
	ld	hl,(D78AB)
	inc	l
	ld	a,l
	ld	(D78AB),a
A0DF3:	call	A0E3E
	ld	(D78AA),a
A0DF9:	ld	hl,(D78AB)
	inc	l
	dec	l
	jr	nz,A0DB2
	call	A0F0F
	jp	A0C2D
	;
A0E07:	ld	a,(D78AA)
	cp	"*"
	jr	nz,A0E1D
	call	A0E3E
	cp	"/"
	jp	z,A0C2D
	call	A0F0F
	jr	A0E25
	;
A0E1D:	cp	1Ah			; код конца файла ?
	jr	nz,A0E25
	call	A0BC6
A0E25:	call	A0E3E
	ld	(D78AA),a
	jr	A0E07


A0E2E:	ld	hl,(D76C1)		; описатель файла
	call	A053C			; чтение блока файла
	ld	a,l
	ld	(D78A9),a
	cp	0Dh
	jr	z,A0E2E
	ret


A0E3E:	ld	hl,(D77AA)
	ld	bc,A77AC
	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jr	nc,A0E59
	ld	hl,(D77AA)
	dec	hl
	ld	(D77AA),hl
	ld	a,(hl)
	ld	(D78A9),a
	jp	A0EFD
	;
A0E59:	call	A0E2E
	ld	hl,(D77CC)
	inc	hl
	ld	(D77CC),hl
	;ld	a,(D78A9)
	inc	a
	jr	z,A0E72
	;ld	a,(D78A9)
	dec	a;
	cp	1Ah
	jr	nz,A0EB6
A0E72:	ld	hl,(index)		; индекс описателя файла
	ld	a,l
	or	h
	jr	z,A0EAE			; индекс входного *.C файла
	ld	hl,(D76C1)		; include-файл
	call	A0504			; записать посл. блок (если надо) и закрыть файл
	ld	hl,(index)		; индекс описателя файла
	dec	hl
	ld	(index),hl
	add	hl,hl
	ld	c,l
	ld	b,h
	add	hl,hl		;1+1=2
	add	hl,bc		;2+1=3
	ld	bc,A7852		; ds 40
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	(D77CA),de
	ld	(D1A86),de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	(D77CC),de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D76C1),de
	jr	A0E59
	;
A0EAE:	ld	a,1Ah
	ld	(D78A9),a
	jr	A0EFD
	;
A0EB6:	ld	a,(D78A9)
	cp	0Ah
	jr	nz,A0ED1
	ld	hl,(D77CA)
	inc	hl
	ld	(D77CA),hl
	ld	(D1A86),hl
	ld	hl,-1
	ld	(D77CC),hl
	jr	A0EFD
	;
A0ED1:	ld	a,(D78A9)
	cp	5Ch			; \
	jr	nz,A0EFD
	call	A0E2E
	cp	0Ah
	jr	nz,A0EF4
	ld	hl,(D77CA)
	inc	hl
	ld	(D77CA),hl
	ld	(D1A86),hl
	ld	hl,-1
	ld	(D77CC),hl
	jp	A0E59
	;
A0EF4:	ld	a,(D78A9)
	call	A0F0F
	ld	a,5Ch
	ret
A0EFD:	ld	a,(D78A9)
	cp	1Ah
	jr	nz,A0F0B
	ld	a,(D78A9)
	call	A0F0F
A0F0B:	ld	a,(D78A9)
	ret
	;
A0F0F:	ld	hl,(D77AA)
	ld	(hl),a
	inc	hl
	ld	(D77AA),hl
	ret


A0F18:	call	A0E3E
	cp	0Ah
	jr	nz,A0F18
	ret


A0F20:	xor	a
	ld	(D787F),a
	call	A0F18
A0F27:	call	A0BF3
	ld	(D77FB),a
	cp	0C9h			; токен ?
	jr	z,A0F40
	ld	a,(D77FB)
	cp	0FAh			; тоже ?
	jr	nz,A0F27
	call	A5473
	jr	A0F27
	;
A0F40:	ld	hl,(D77F7)		; номер колонки
	ld	a,l
	or	h
	jr	nz,A0F27
	call	A0BF3
	dec	a
	jr	nz,A0F27
	ld	de,(D77FD)
	ld	hl,(D780A)
	ld	a,e
	cp	l
	jr	nz,A0F5F
	ld	a,d
	cp	h
	jr	z,A0F6C
A0F5F:	ld	hl,(D780C)
	ld	a,e
	cp	l
	jr	nz,A0F76
	ld	a,d
	cp	h
	jr	nz,A0F76
A0F6C:	ld	a,(D787F)
	inc	a
	ld	(D787F),a
	jr	A0F27
	;
A0F76:	ld	de,(D77FD)
	ld	hl,(D7810)
	ld	a,e
	cp	l
	jr	nz,A0F84
	ld	a,d
	cp	h
A0F84:	jr	nz,A0F95
	ld	a,(D787F)
	dec	a
	ld	(D787F),a
	inc	a
	jp	nz,A0F27
	jp	A0F18			;A0FAD
	;
A0F95:	ld	de,(D77FD)
	ld	hl,(D780E)
	ld	a,e
	cp	l
	jr	nz,A0FA3
	ld	a,d
	cp	h
A0FA3:	jp	nz,A0F27
	ld	a,(D787F)
	or	a
	jp	nz,A0F27
	jp	A0F18


A0FBF:	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T0FB0
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	jp	A0F18


A0FD9:	ld	c,l
	ld	b,h
	ld	(D787D),hl
A0FDE:	ld	a,(bc)
	cp	0FAh
	jr	z,A0FEA
	dec	bc
	dec	bc
	dec	bc
	jr	A0FDE
	;
A0FEA:	ld	hl,1
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,(bc)
	push	bc
	call	A50B5
	pop	bc
	inc	bc
	inc	bc
	inc	bc
	ld	hl,-3
	add	hl,bc
	ld	de,(D787D)
	ld	a,l
	cp	e
	jr	nz,A0FEA
	ld	a,h
	cp	d
	jr	nz,A0FEA
	ld	hl,(D79FB)
	ret


A1036:	ld	hl,-20
	add	hl,sp
	ld	sp,hl
	xor	a
	ld	(D787A),a
	call	A0BF3
	dec	a
	jr	z,A104F
	ld	hl,(D7804)
	call	A0FBF
	jp	A1197
	;
A104F:	ld	hl,(D77F7)		; номер колонки
	call	A50EB
	ld	(D787B),hl
	ex	de,hl
	ld	hl,1
	add	hl,de
	push	hl
	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	push	de
	call	A0E3E
	pop	hl
	cp	28h
	jp	nz,A1100
A107C:	call	A0BF3
	ld	(D77FB),a
	cp	0F8h
	jr	z,A10EC
	ld	a,(D77FB)
	cp	10h
	jr	z,A10EC
	ld	a,(D77FB)
	cp	0FAh
	jr	z,A10EC
	ld	a,(D77FB)
	dec	a
	jp	nz,A1182
	ld	a,(D787A)
	cp	0Ah
	jr	c,A10BB
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T1010		; "Xtoo much parameters"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jp	A1194
	;
A10BB:	inc	a
	ld	(D787A),a
	dec	a
	ld	l,a
	ld	h,0
	add	hl,hl
	ex	de,hl
	ld	hl,0
	add	hl,sp
	add	hl,de
	ld	de,(D77FD)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	call	A0BF3
	ld	(D77FB),a
	cp	10h
	jr	nz,A10E1
	jr	A10EC
	;
A10E1:	ld	a,(D77FB)
	cp	0B8h
	jr	z,A107C
	jp	A1182
	;
A10EC:	ld	a,(D77FB)
	cp	10h
	jp	nz,A1182
	ld	a,(D787A)
	inc	a
	inc	a
	ld	hl,(D787B)
	ld	(hl),a
	jr	A1108
	;
A1100:	push	hl
	call	A0F0F
	ld	a,1
	pop	hl
	ld	(hl),a
A1108:	push	hl
	call	A5142
	ld	a,0FAh
	ld	(D77FB),a
	call	A5153
	ld	a,1			; true ?
	ld	(D77A8),a
A1119:	call	A0BF3
	ld	(D77FB),a
	cp	0F8h
	jr	z,A1167
	ld	a,(D77FB)
	dec	a
	jr	nz,A1161
	ld	c,0
A112D:	ld	a,c
	ld	hl,(D787A)
	cp	l
	jr	nc,A1161
	ld	l,c
	ld	h,0
	add	hl,hl
	ex	de,hl
	ld	hl,2
	add	hl,sp
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D77FD)
	ld	a,l
	cp	e
	jr	nz,A114C
	ld	a,h
	cp	d
A114C:	jr	nz,A115D
	ld	a,7
	ld	(D77FB),a
	ld	l,c
	ld	h,0
	ld	(D77FD),hl
	jr	A1161
	;
A115D:	inc	c
	jr	A112D
	;
A1161:	call	A5153
	jr	A1119
	;
A1167:	ld	hl,(D79F1)
	dec	hl
	dec	hl
	dec	hl
	call	A0FD9
	ex	de,hl
	pop	hl
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D79EF)
	ld	(D77E5),hl
	xor	a			; false ?
	ld	(D77A8),a
	jr	A1197
	;
A1182:	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T1025		; 
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A1194:	call	A0F18
A1197:	ld	hl,20
	add	hl,sp
	ld	sp,hl
	ret


A119D:	call	A0BF3
	dec	a
	jr	z,A11AA
	ld	hl,(D7806)
	jp	A0FBF
	;
A11AA:	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,l
	or	h
	ret	z
	ld	a,(hl)
	or	a
	ret	z
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ret


;T11DB:	db	"R",0			; файл на чтение (include-файл)


; Открыть include-файл
; вход: hl=адрес имени include-файла
A11DD:	push	hl
	ld	de,(D77CA)
	ld	hl,(index)		; индекс описателя файла
	add	hl,hl		;1+1=2
	ld	c,l
	ld	b,h
	add	hl,hl		;2+2=4
	add	hl,bc		;4+2=6
	ld	bc,A7852		; ds 40
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	de,(D77CC)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	de,(D76C1)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(index)		; индекс описателя файла
	inc	hl
	ld	(index),hl
	ld	a,l
	sub	4+1			; макс. индекс для include-файлов (5=индекс .tmc файла)
	ld	a,h
	sbc	a,0
	jr	c,A1223
	; превышено число открытых include-файлов
	ld	bc,0			; номер колонки
	push	bc
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T11C6		; "X#include too nested"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	jp	abort			; выход в ДОС
	;
A1223:	ld	c,l			; индекс описателя файла
	ld	b,h
	pop	hl
	ld	(D79E9),hl		; адрес имени include-файла
	;ld	de,T11DB		; "r" на чтение
	ld	a,"R"			; на чтение
	push	hl			; адрес имени файла
	call	A03FA			; открыть include-файл
	ld	(D76C1),hl
	pop	de
	ld	a,l
	or	h
	ld	hl,T1BBA		; "cannot open ["
	jp	z,A06C7			; вывод строки и abort
	ld	hl,0
	ld	(D77CA),hl
	ld	(D1A86),hl
	dec	hl
	ld	(D77CC),hl
	ret


; Парсинг имени include-файла
A1250:	call	A0BF3
	cp	60h
	jr	z,A1268
	cp	5
	jr	nz,A12A6
	ld	hl,(D77FD)
	inc	hl
	inc	hl			; hl=имя файла
	push	hl;
	ld	hl,dirs			; диск+путь входного .c файла
	call	set_cur_path
	pop	hl
	ld	a,"\"
	ld	(de),a
	inc	de
	; открыть #include "file.ext"
	jr	A129A;
	;jp	A11DD
	;
A1268:	call	A4F68
A126B:	call	A0E3E
	cp	">"
	jr	z,A1286
	cp	0Ah
	jr	z,A1286
	cp	1Ah
	jr	z,A1286
	call	A06F5
	call	A4F87
	jr	A126B
	;
A1286:	push	af
	xor	a
	call	A4F87
	pop	af
	cp	">"
	jr	nz,A12A6
	call	A4FC2
	inc	hl
	inc	hl
	;ld	de,(D77A6)		; адрес начала имени include-файла
	; добавить каталог по-умолчанию
	push	hl;
	ld	hl,disk			; текущий диск+путь компилятора
	call	set_cur_path
	;-
	ld	hl,A12A8		; каталог по-умолчанию
A1295:	ld	a,(hl)
	ldi
	or	a
	jr	nz,A1295
	dec	de
	pop	hl;
	;
A129A:	ld	a,(hl)
	ldi				; скопировать имя include-файла
	or	a
	jr	nz,A129A
	; открыть #include <file.ext>
	ld	hl,incl_filename	; ds 65 имя файла
	jp	A11DD
	;
A12A6:	ld	hl,(D7808)
	jp	A0FBF

; Скопировать путь для include-файлов
; вход: hl-строка пути
set_cur_path:
	ld	de,incl_filename
	ld	a,(hl)
	inc	hl
	add	a,"A"
	ld	(de),a			; имя тек. диска
	inc	de
	ld	a,":"
	ld	(de),a
	inc	de
	ld	a,(hl)
	cp	"\"			; в пути только один "\" ?
	jr	nz,A1290
	inc	hl
	xor	a
	or	(hl)
	dec	hl
	jr	nz,A1290
	ld	(hl),a			; затереть "\"
	push	hl;
	call	A1290			; скопировать путь
	pop	hl;
	ld	(hl),"\";		; восст. "\"
	ret;
A1290:	ld	a,(hl)
	ldi				; скопировать тек. путь
	or	a
	jr	nz,A1290
	dec	de
	ret

A12A8:	db	"\INCLUDE\",0		; каталог по-умолчанию



A12AC:	call	A0BF3
	dec	a
	jr	z,A12B9
	ld	hl,(D780A)
	jp	A0FBF
	;
A12B9:	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	or	(hl)
	jp	z,A0F20
	ld	a,(hl)
	dec	hl
	ld	l,(hl)
	ld	h,a
	ld	a,(hl)
	or	a
	jp	z,A0F20
	jp	A0F18


A12D0:	call	A0BF3
	dec	a
	jr	z,A12DD
	ld	hl,(D780C)
	jp	A0FBF
	;
A12DD:	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	or	(hl)
	jp	z,A0F18
	ld	a,(hl)
	dec	hl
	ld	l,(hl)
	ld	h,a
	ld	a,(hl)
	or	a
	jp	z,A0F18
	jp	A0F20


A12F4:	ld	bc,0			; номер колонки
	push	bc
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	hl,T1313		; "Xerror: "
	push	hl
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A1306:	call	A0E3E
	push	af
	call	A015E			; вывод "a" на экран
	pop	af
	cp	0Ah
	jr	nz,A1306
	ret



A132B:	call	A0BF3
	dec	a
	jr	nz,A139C
	ld	de,(D77FD)
	ld	hl,(D7814)
	ld	a,e
	cp	l
	jr	nz,A1349
	ld	a,d
	cp	h
	jr	nz,A1349
	ld	a,1			; true?
	;ld	(D76D2),a
	ld	(A550B+1),a;
	ret
A1349:	ld	hl,(D7816)
	ld	a,e
	cp	l
	jr	nz,A135B
	ld	a,d
	cp	h
	jr	nz,A135B
	xor	a			; false?
	;ld	(D76D2),a
	ld	(A550B+1),a;
	ret
A135B:	ld	hl,(D7818)
	ld	a,e
	cp	l
	jr	nz,A139C
	ld	a,d
	cp	h
	jr	nz,A139C
	call	A0BF3
	dec	a
	jr	nz,A139C
	ld	de,(D77FD)
	ld	hl,(D781A)
	ld	a,e
	cp	l
	jr	nz,A1386
	ld	a,d
	cp	h
	jr	nz,A1386
	ld	hl,T131C		; $T оптимизация "time"
	jr	A1396
	;
A1386:	ld	hl,(D781C)
	ld	a,e
	cp	l
	jr	nz,A139C
	ld	a,d
	cp	h
	jr	nz,A139C
	ld	hl,T1320		; $S оптимизация "size"
A1396:	push	hl
	call	A4ABC
	pop	bc
	ret
A139C:	ld	hl,(D7812)
	jp	A0FBF


A13A9:	ld	hl,(D77F7)		; номер колонки
	ld	a,l
	or	h
	jp	nz,A1441
	call	A0BF3
	ld	(D77FB),a
	dec	a
	jp	nz,A1441
	ld	de,(D77FD)
	ld	hl,(D7804)
	ld	a,e
	cp	l
	jr	nz,A13CC
	ld	a,d
	cp	h
	jp	z,A1036
A13CC:	ld	hl,(D7806)
	ld	a,e
	cp	l
	jr	nz,A13D9
	ld	a,d
	cp	h
	jp	z,A119D
A13D9:	ld	hl,(D781E)
	ld	a,e
	cp	l
	jr	nz,A13E6
	ld	a,d
	cp	h
	jp	z,A0F18
A13E6:	ld	hl,(D7808)
	ld	a,e
	cp	l
	jr	nz,A13F3
	ld	a,d
	cp	h
	jp	z,A1250			; парсинг имени include-файла
A13F3:	ld	hl,(D7820)
	ld	a,e
	cp	l
	jr	nz,A1400
	ld	a,d
	cp	h
	jp	z,A12F4
A1400:	ld	hl,(D780A)
	ld	a,e
	cp	l
	jr	nz,A140D
	ld	a,d
	cp	h
	jp	z,A12AC
A140D:	ld	hl,(D780C)
	ld	a,e
	cp	l
	jr	nz,A141A
	ld	a,d
	cp	h
	jp	z,A12D0
A141A:	ld	hl,(D780E)
	ld	a,e
	cp	l
	jr	nz,A1427
	ld	a,d
	cp	h
	jp	z,A0F20
A1427:	ld	hl,(D7810)
	ld	a,e
	cp	l
	jr	nz,A1434
	ld	a,d
	cp	h
	jp	z,A0F18
A1434:	ld	hl,(D7812)
	ld	a,e
	cp	l
	jr	nz,A1441
	ld	a,d
	cp	h
	jp	z,A132B
A1441:	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T13A2
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret


A1454:	ld	(D784C),hl
	ld	hl,-20
	add	hl,sp
	ld	sp,hl
	ld	hl,(D784C)
	call	A5142
	ld	hl,(D77F9)		; номер строки
	ld	(D784E),hl
	ld	hl,(D77F7)		; номер колонки
	ld	de,(D784C)
	ld	a,(de)
	push	de
	cp	2
	jp	c,A156F
	push	de
	push	hl
	call	A0BF3
	ld	(D77FB),a
	pop	hl
	pop	de
	cp	8
	jr	z,A1499
	push	hl			; номер колонки
	ld	hl,(D784E)		; номер строки
	push	hl
	ld	bc,T15E6		; "Xconflicting number of macro parameter"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jp	A156F
	;
A1499:	push	de
	xor	a
	ld	(D7851),a
	push	hl
	call	A0BF3
	ld	(D77FB),a
	cp	10h
	jp	z,A1537
	call	A5119
A14AD:	ld	a,0FAh
	ld	(D77FB),a
	call	A5153
	xor	a
	ld	(D7850),a
A14B9:	call	A0BF3
	ld	(D77FB),a
	cp	0F8h
	jr	z,A1507
	ld	a,(D77FB)
	cp	0FAh
	jr	z,A1507
	ld	hl,(D7850)
	inc	l
	dec	l
	jr	nz,A14E4
	ld	a,(D77FB)
	cp	10h
	jr	z,A1507
	ld	a,(D77FB)
	cp	0B8h
	jr	z,A1507
A14E4:	ld	a,(D77FB)
	cp	8
	jr	nz,A14F4
	inc	l
	ld	a,l
	ld	(D7850),a
	jr	A1501
	;
A14F4:	ld	a,(D77FB)
	cp	10h
	jr	nz,A1501
	dec	l
	ld	a,l
	ld	(D7850),a
A1501:	call	A5153
	jr	A14B9
	;
A1507:	ld	a,(D7851)
	cp	0Ah
	jr	nc,A152F
	ld	(D7851),a
	ld	hl,(D79F1)
	dec	hl
	dec	hl
	dec	hl
	push	hl
	ld	a,(D7851)
	inc	a
	ld	(D7851),a
	dec	a
	ld	l,a
	ld	h,0
	add	hl,hl
	ex	de,hl
	ld	hl,8
	add	hl,sp
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
A152F:	ld	a,(D77FB)
	cp	0B8h
	jr	z,A14AD
A1537:	ld	a,(D77FB)
	pop	hl
	pop	de
	cp	10h
	jr	z,A1553
	push	hl			; номер колонки
	ld	hl,(D784E)		; номер строки
	push	hl
	ld	bc,T160D		; 
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A156F
	;
A1553:	ld	a,(D7851)
	ld	c,a
	ld	a,(de)
	dec	a
	dec	a
	cp	c
	jr	z,A156F
	push	hl			; номер колонки
	ld	hl,(D784E)		; номер строки
	push	hl
	ld	bc,T15E6		; "Xconflicting number of macro parameter"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A156F:	pop	de
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
A1578:	ld	a,(hl)
	cp	0FAh
	jr	z,A15DD
	ld	a,(hl)
	ld	(D77FB),a
	dec	hl
	dec	hl
	dec	hl
	push	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D77FD),hl
	ld	a,(D77FB)
	cp	7
	jr	nz,A15D6
	ld	a,(D7851)
	ld	e,a
	ld	d,0
	ld	hl,(D77FD)
	call	A74EC
	jr	nc,A15D9
	ld	hl,(D77FD)
	add	hl,hl
	ex	de,hl
	ld	hl,2
	add	hl,sp
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
A15B6:	ld	a,(hl)
	cp	0FAh
	jr	z,A15D9
	ld	a,(hl)
	ld	(D77FB),a
	dec	hl
	dec	hl
	dec	hl
	push	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D77FD),hl
	call	A5119
	pop	hl
	jr	A15B6
	;
A15D6:	call	A5119
A15D9:	pop	hl
	jr	A1578
	;
A15DD:	ld	hl,(D79EF)
	ld	(D77E5),hl
	ld	hl,20
	add	hl,sp
	ld	sp,hl
	ret



A161E:	ld	hl,(D77CE)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,A7822
	add	hl,bc
	ld	a,(D77FB)
	ld	(hl),a
	inc	hl
	ld	de,(D77FD)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	de,(D77F9)		; номер строки
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	de,(D77F7)		; номер колонки
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D77CE)
	inc	hl
	ld	(D77CE),hl
	ret


A1651:	ld	hl,(D77CE)
	ld	a,l
	or	h
	jr	z,A168D
	ld	hl,(D77CE)
	dec	hl
	ld	(D77CE),hl
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,A7822
	add	hl,bc
	ld	a,(hl)
	ld	(D77FB),a
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	(D77FD),de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	(D77F9),de		; номер строки
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	(D77F7),de		; номер колонки
	ld	a,(D77FB)
	ret
A168D:	call	A0BF3
	ld	(D77FB),a
	cp	0C9h
	jr	nz,A169E
	call	A13A9
	jr	A168D
	;
A169E:	ld	a,(D77FB)
	cp	0F8h
	jr	z,A168D
	dec	a
	jr	nz,A16CD
	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,l
	or	h
	jr	z,A16CD
	ld	a,(hl)
	or	a
	jr	nz,A16C7
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	ld	(D77FB),a
	jr	A16CD
	;
A16C7:	call	A1454
	jr	A168D
	;
A16CD:	ld	a,(D77FB)
	ret


	; для сканир. директив
A16D1:	push	hl
	call	A0802
	pop	de
	ld	a,(hl)
	inc	hl
	or	(hl)
	dec	hl
	ret	nz
	push	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
	pop	hl
	ret


; для сканир. зарез. слов
; вход: hl=адрес имени зарез. слова
;       a=токен?
A16E7:	push	de
	push	hl
	call	A0802
	;ld	(D7802),hl
	ld	(A16F7+1),hl;
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	call	A50EB
	ex	de,hl
A16F7:	ld	hl,0 ;(D7802)
	inc	hl
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	xor	a
	ld	(de),a
	pop	bc
	ld	b,a
	ld	hl,3
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ret


; адреса 34-х строк
T170C:	dw	L1772
	db	0D0h			; токен ?
	dw	L1777
	db	0EAh
	dw	L177D
	db	0E7h
	dw	L1782
	db	0D5h
	dw	L1787
	db	0EBh
	dw	L1790
	db	0E8h
	dw	L1798
	db	0E5h
	dw	L179B			;7 double
	db	0DBh
	dw	T17A2
	db	0E2h
	dw	L17A7
	db	0EDh
	dw	L17AC
	db	0D2h
	dw	L17B3			;11 float
	db	0DAh
	dw	L17B9
	db	0E3h
	dw	L17BD
	db	0ECh
	dw	L17C2
	db	0E1h
	dw	L17C5
	db	0D7h
	dw	L17C9			;16 long
	db	0D8h
	dw	L17CE
	db	0EEh
	dw	L17D5
	db	0EFh
	dw	L17DF
	db	0D3h
	dw	L17E8
	db	0E9h
	dw	L17EF
	db	0D6h
	dw	L17F5
	db	3Fh
	dw	L17FC
	db	0D1h
	dw	L1803
	db	0DCh
	dw	L180A
	db	0E6h
	dw	L1811
	db	0D4h
	dw	L1819
	db	0DDh
	dw	L181F
	db	0D9h
	dw	L1828
	db	0E4h
	dw	L182E
	db	0F0h
	dw	L1832
	db	0F1h
	dw	L1838
	db	0F2h
	dw	L1841
	db	0F3h

; Зарезерв. слова
Keywords equ	34

L1772:	db	"auto",0
L1777:	db	"break",0
L177D:	db	"case",0
L1782:	db	"char",0
L1787:	db	"continue",0
L1790:	db	"default",0
L1798:	db	"do",0
L179B:	db	"double",0
T17A2:	db	"else",0
L17A7:	db	"void",0
L17AC:	db	"extern",0
L17B3:	db	"float",0
L17B9:	db	"for",0
L17BD:	db	"goto",0
L17C2:	db	"if",0
L17C5:	db	"int",0
L17C9:	db	"long",0
L17CE:	db	"nonrec",0
L17D5:	db	"recursive",0
L17DF:	db	"register",0
L17E8:	db	"return",0
L17EF:	db	"short",0
L17F5:	db	"sizeof",0
L17FC:	db	"static",0
L1803:	db	"struct",0
L180A:	db	"switch",0
L1811:	db	"typedef",0
L1819:	db	"union",0
L181F:	db	"unsigned",0
L1828:	db	"while",0
L182E:	db	"asm",0
L1832:	db	"const",0
L1838:	db	"volatile",0
L1841:	db	"signed",0


; Директивы
L1848:	db	"define",0
T184F:	db	"undef",0
T1855:	db	"include",0
T185D:	db	"ifdef",0
T1863:	db	"ifndef",0
T186A:	db	"endif",0
T1870:	db	"pragma",0
T1877:	db	"nonrec",0
T187E:	db	"recursive",0
T1888:	db	"optimize",0
T1891:	db	"time",0
T1896:	db	"size",0		;"space",0
T189C:	db	"line",0
L18A1:	db	"error",0



L18A7:	ld	hl,(D77D7)
	add	hl,hl
	add	hl,hl
	ld	c,l
	ld	b,h
	dec	bc
	ld	hl,(D77DD)
	ld	d,h
	ld	e,l
	inc	de
	ld	(hl),0
	ldir
	ld	hl,T170C		; адреса 34-х имен зарез. слов
	ld	b,Keywords		; число зарезерв. слов
A18C9:	push	bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)			; токен ?
	inc	hl
	push	hl
	ex	de,hl			; hl=адрес строки
	ld	e,a
	call	A16E7
	pop	hl
	pop	bc
	djnz	A18C9
	; сканир. на директивы
	ld	hl,T189C		; строка "line"
	call	A16D1
	ld	(D781E),hl
	ld	hl,L1848		; "define"
	call	A16D1
	ld	(D7804),hl
	ld	hl,T184F		; "undef"
	call	A16D1
	ld	(D7806),hl
	ld	hl,T1855		; "include"
	call	A16D1
	ld	(D7808),hl
	ld	hl,T185D		; "ifdef"
	call	A16D1
	ld	(D780A),hl
	ld	hl,T1863		; "ifndef"
	call	A16D1
	ld	(D780C),hl
	ld	hl,T17A2		; "else"
	call	A16D1
	ld	(D780E),hl
	ld	hl,T186A		; "endif"
	call	A16D1
	ld	(D7810),hl
	ld	hl,T1870		; "pragma"
	call	A16D1
	ld	(D7812),hl
	ld	hl,T1877		; "nonrec"
	call	A16D1
	ld	(D7814),hl
	ld	hl,T187E		; "recursive"
	call	A16D1
	ld	(D7816),hl
	ld	hl,T1888		; "optimize"
	call	A16D1
	ld	(D7818),hl
	ld	hl,T1891		; "time"
	call	A16D1
	ld	(D781A),hl
	ld	hl,T1896		; "size"
	call	A16D1
	ld	(D781C),hl
	ld	hl,L18A1		; "error"
	call	A16D1
	ld	(D7820),hl
	;
	ld	b,13			; кол-во директив ? (с нулем)
	ld	hl,T19F1
A1966:	push	bc
	push	hl
	ld	e,(hl)
	ld	d,0
	ld	c,d
	ld	b,d
	ld	a,1
	call	A1D2E
	pop	hl
	pop	bc
	inc	hl
	djnz	A1966
	ld	hl,(D77DF)
	ld	bc,9
	add	hl,bc
	ld	(D78B0),hl
	add	hl,bc
	ld	(D78B2),hl
	add	hl,bc
	ld	(D78B4),hl
	add	hl,bc
	ld	(D78B6),hl
	add	hl,bc
	ld	(D78B8),hl
	add	hl,bc
	ld	(D78BA),hl
	;
	ld	hl,T1A42		; "__SOLIDC__"
	ld	de,T1A3F
	call	A19FE
	ld	hl,T1A6A		; "MSXDOS"  (отлич. для разных ОС)
	ld	de,T1A3F
	call	A19FE
	ld	hl,T1A4D		; "__Z80__"
	ld	de,T1A3F
	call	A19FE
	ld	hl,T1A55		; "_CHAR_UNSIGNED"
	ld	de,T1A3F
	call	A19FE
	ld	hl,T1A79		; "__LINE__"
	ld	de,T1A85		; db 2
	call	A19FE
	ld	hl,T1A88		; "__FILE__"
	ld	de,L1A94		; db 5
	call	A19FE
	;
	ld	hl,(L0080)		; ком-строка
A19DE:	ld	a,(hl)
	or	a
	ret	z			;
	push	hl
	ld	de,T1A3F
	call	A19FE
	pop	hl
	ld	bc,128			; длина ком.строки ?
	xor	a
	cpir
	jr	A19DE

T19F1:	db	0
	db	1
	db	2
	db	3
	db	4
	db	5
	db	6
	db	7
	db	8
	db	9
	db	10
	db	11
	db	3


	; к парсингу
A19FE:	push	de
	push	hl
	call	A0802
	pop	de
	ld	(D77FD),hl
	ld	a,(hl)
	inc	hl
	or	(hl)
	dec	hl
	jr	nz,A1A10
	ld	(hl),e
	inc	hl
	ld	(hl),d
A1A10:	call	A50EB
	ld	(D787B),hl
	ex	de,hl
	ld	hl,1
	add	hl,de
	push	hl
	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ex	de,hl
	ld	a,1
	ld	(hl),a
	inc	hl
	inc	hl
	inc	hl
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ret


T1A3F:	db	2,1,0			; типы ОС (msx-dos2,misix,msx-dos) ??

; Макросы
T1A42:	db	"__SOLIDC__",0
T1A4D:	db	"__Z80__",0
T1A55:	db	"_CHAR_UNSIGNED",0
T1A6A:	db	"MSXDOS",0
T1A79:	db	"__LINE__",0


T1A85:	db	2			; токен "__LINE__" ?
D1A86:	dw	0

T1A88:	db	"__FILE__",0


L1A94:	db	5			; ? токен "__FILE__" ?
	dw	D7722			; 7722h



L1A97:	db	16h
L1A98:	db	0x00
	db	0x21,0x23,0x25,0x26,0x28,0x29,0x2A,0x2B
	db	0x2C,0x2D,0x2E,0x2F,0x3A,0x3B,0x3C,0x3D
	db	0x3E,0x3F,0x40,0x5B,0x5D,0x5E,0x7B,0x7C
	db	0x7D,0x7E,0x3D,0xFB,0xFB,0x3D,0xFB,0x26
	db	0x3D,0xFB,0xFB,0xFB,0x3D,0xFB,0x2B,0x3D
	db	0xFB,0xFB,0x2D,0x3D,0x3E,0xFB,0xFB,0x2A
	db	0x3D,0xFB,0xFB,0xFB,0x3C,0x3D,0xFB,0x3D
	db	0xFB,0x3D,0x3E,0xFB,0xFB,0xFB,0xFB,0xFB
	db	0x3D,0xFB,0xFB,0x3D,0x7C,0xFB,0xFB,0xFB
	db	0xFB,0x3B,0xC9,0xFB,0x4A,0xFB,0xFB,0x70
	db	0x08,0x10,0xFB,0x48,0xFB,0xFB,0x50,0xB8
	db	0xFB,0xFB,0xFB,0x51,0x29,0xFB,0xFB,0x49
	db	0xA0,0xC8,0x3D,0xFB,0xFB,0x60,0xFB,0xA8
	db	0xFB,0x3D,0xFB,0x62,0x98,0xCA,0x18,0x20
	db	0xFB,0x78,0xDF,0xFB,0xFB,0x80,0xE0,0x3C
	db	0x69,0xAD,0x88,0xB0,0xAB,0x30,0xA9,0x31
	db	0xAA,0x28,0xF9,0xAC,0xFB,0x59,0x61,0x68
	db	0x63,0xFB,0x58,0xB1,0xB2,0x90,0xAF,0xAE

L1B29:	db	0x01
L1B2A:	db	0x1B,0x1D,0x1E,0x20,0x23,0x24,0x25,0x27
	db	0x2A,0x2B,0x2F,0x30,0x33,0x34,0x35,0x38
	db	0x3A,0x3D,0x3E,0x3F,0x40,0x41,0x43,0x44
	db	0x47,0x48,0x49,0x4A,0x4B,0x4C,0x4D,0x4E
	db	0x4F,0x50,0x51,0x52,0x53,0x54,0x55,0x56
	db	0x57,0x58,0x59,0x5A,0x5B,0x5C,0x5D,0x5E
	db	0x5F,0x60,0x61,0x62,0x63,0x65,0x66,0x67
	db	0x68,0x69,0x6A,0x6C,0x6D,0x6E,0x6F,0x70
	db	0x71,0x72,0x73,0x74,0x75,0x76,0x77,0x78
	db	0x79,0x7A,0x7A,0x7A,0x7B,0x7B,0x7C,0x7D
	db	0x7D,0x7D,0x7D,0x7E,0x7E,0x7F,0x80,0x80
	db	0x80,0x81,0x82,0x83,0x83,0x83,0x84,0x85
	db	0x85,0x85,0x85,0x86,0x87,0x88,0x88,0x89
	db	0x89,0x8A,0x8B,0x8C,0x8C,0x8C,0x8C,0x8C
	db	0x8C,0x8D,0x8D,0x8D,0x8E,0x8F,0x8F,0x8F
	db	0x8F,0x8F,0x8F,0x8F,0x8F,0x8F,0x8F,0x8F
	db	0x8F,0x8F,0x8F,0x8F,0x8F,0x90,0x90,0x90
	db	0x90,0x90,0x91,0x91,0x91,0x91,0x91,0x91


D1BC8:	dw	1


A1BCA:	ld	a,e
	ld	(D78BD),a
	push	bc
	push	hl
	call	A5082
	ld	(D78BE),hl
	call	A5255
	pop	de
	pop	bc
	ld	a,l
	or	h
	jr	z,A1BF3
	ld	hl,(D78BE)
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc			; номер колонки
	push	de			; номер строки
	ld	bc,T1C3F		; 'YR"S"'
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret
A1BF3:	push	bc
	ld	hl,(D78BE)
	call	A527D
	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(D78BD)
	ld	(hl),a
	cp	"P"			; 50h
	jr	z,A1C1C
	cp	"X"			; 58h
	jr	z,A1C1C
	cp	"d"			; 64h
	jr	z,A1C1C
	cp	"Y"			; 59h
	jr	z,A1C1C
	cp	"G"			; 47h
	jr	nz,A1C22
A1C1C:	ld	hl,0
	jr	A1C2A
	;
A1C22:	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
A1C2A:	push	de
	push	hl
	ld	hl,3
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	de
	ld	hl,5
	add	hl,de
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ex	de,hl
	ret


A1C45:	ld	(D78C0),hl
	push	de
	push	hl
	call	A5082
	call	A5255
	ld	c,l
	ld	b,h
	pop	hl
	pop	de
	ld	a,c
	or	b
	jr	z,A1C87
	ld	hl,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	z,A1CA0
	push	bc
	ld	hl,(D78C0)
	ld	(D78C0),hl
	call	A5082
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de			; номер колонки
	ld	hl,(D78C0)		; номер строки
	push	hl
	ld	bc,T1C3F
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	hl,2
	add	hl,bc
	ld	(hl),"e"		; 65h
	ret
A1C87:	ld	(D78C0),hl
	call	A5082
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de			; номер колонки
	ld	hl,(D78C0)		; номер строки
	push	hl
	ld	bc,T1CC0		; 'Y "S" is not in parameter list'
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret
A1CA0:	push	de
	ld	hl,2
	add	hl,bc
	ld	(hl),"P"		; 50h
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ex	de,hl
	ld	hl,3
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,5
	add	hl,bc
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret


A1CDF:	ld	(D78C2),de
	push	de
	push	bc			; номер колонки
	push	de			; номер строки
	push	hl
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	hl
A1CEE:	push	hl
	call	A5079
	ld	a,l
	pop	hl
	dec	a
	jr	z,A1D01
	call	A5082
	ld	(D78C2),hl
	jr	A1CEE
	;
A1D01:	call	A5082
	call	A5255
	ld	a,l
	or	h
	jr	z,A1D13
	inc	hl
	inc	hl
	ld	(hl),"e"		; 65h
	jr	A1D1E
	;
A1D13:	ld	hl,(D78C2)
	ld	e,"e"			; 65h
	ld	bc,0
	call	A1BCA
A1D1E:	ld	hl,-1
	ld	(D7A11),hl
	ld	hl,0
	ret


A1D28:	ld	bc,0
	jp	A1CDF


A1D2E:	ld	hl,0
	ld	(D78C4),de
	push	bc
	push	af
	call	A527D
	ex	de,hl
	ld	hl,2
	add	hl,de
	pop	af
	ld	(hl),a
	ld	hl,3
	add	hl,de
	push	de
	ld	de,(D78C4)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	de
	ld	hl,5
	add	hl,de
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ex	de,hl
	ret


A1D58:	ld	(D78C9),bc
	ld	a,e
	ld	(D78C8),a
	ld	(D78C6),hl
	call	A5082
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,2Eh
	call	A085F
	ld	c,l
	ld	b,h
	ld	hl,(D790A)
	ld	a,l
	or	h
	jr	nz,A1D86
	ld	l,c
	ld	h,b
	call	A527D
	ex	de,hl
	ld	l,e
	ld	h,d
	ld	(D790A),hl
	jp	A1DE2
	;
A1D86:	ld	hl,(D790A)
	ld	(D78CB),hl
	ex	de,hl
A1D8D:	ld	l,e
	ld	h,d
	ld	a,(hl)
	cp	c
	inc	hl
	jr	nz,A1DB4
	ld	a,(hl)
	cp	b
	jr	nz,A1DB4
	ld	hl,(D78C6)		; номер строки
	push	hl
	ld	bc,T1DAB		; "YDmember"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ld	hl,(D78CB)
	ret


A1DB4:	ld	hl,7
	add	hl,de
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	z,A1DCC
	ld	hl,7
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D78CB),de
	jr	A1D8D
	;
A1DCC:	push	de
	ld	l,c
	ld	h,b
	call	A527D
	ex	de,hl
	pop	bc
	ld	hl,7
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,7
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A1DE2:	ld	hl,2
	add	hl,de
	push	de
	ld	a,(D78C8)
	ld	(hl),a
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	push	hl
	ld	hl,3
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	de
	ld	hl,5
	add	hl,de
	push	de
	ld	de,(D78C9)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	de
	ld	hl,7
	add	hl,de
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ex	de,hl
	ret


A1E15:	ld	c,e
	ld	b,d
	ld	(D78CD),bc
	ex	de,hl
A1E1C:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	ld	hl,2
	add	hl,bc
	cp	(hl)
	jr	nz,A1E97
	cp	1
	jr	z,A1E38
	cp	0Bh
	jr	z,A1E38
	cp	0Ch
	jr	nz,A1E57
A1E38:	ld	hl,3
	add	hl,de
	ld	(D78CD),bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D78CD)
	inc	hl
	inc	hl
	inc	hl
	ld	a,c
	cp	(hl)
	inc	hl
	jr	nz,A1E55
	ld	a,b
	cp	(hl)
	jr	nz,A1E55
	ld	a,true
	ret
A1E55:	xor	a			; false
	ret
A1E57:	cp	0Dh
	jr	nz,A1E7C
	ld	hl,7
	add	hl,de
	ld	(D78CD),bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D78CD)
	ld	bc,7
	add	hl,bc
	pop	bc
	ld	a,c
	cp	(hl)
	inc	hl
	jr	nz,A1E7A
	ld	a,b
	cp	(hl)
	jr	z,A1E7C
A1E7A:	xor	a
	ret
A1E7C:	ld	hl,5
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	ld	de,(D78CD)
	ld	hl,5
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	(D78CD),bc
	pop	de
	jr	A1E1C
A1E97:	xor	a
	ret


A1EB1:	ld	c,e
	ld	b,d
	ex	de,hl
A1EB4:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	0Dh
	jr	nz,A1EC8
	ld	hl,5
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jr	A1EB4
	;
A1EC8:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	0Ch
	jr	z,A1EDC
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	0Bh
	jr	nz,A1EFC
A1EDC:	ld	hl,7
	add	hl,de
	ld	a,(hl)
	or	a
	jr	nz,A1EFC		; Ok
	push	bc			; номер колонки
	push	bc			; номер строки
	ld	bc,T1E99		; "Yundefined struct/union"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	hl
	ld	e,65h
	ld	bc,0
	call	A1D58
	ld	a,-1			; Failed
	ret
A1EFC:	xor	a			; Ok
	ret


A1F1D:	ld	c,e
	ld	b,d
	ld	(D78D1),bc
	ld	(D78CF),hl
	ex	de,hl
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	cp	9
	jr	z,A1F4F
	cp	0Ah
	jr	z,A1F4F
	cp	0Dh
	jp	z,A2023
	cp	0Bh
	jp	z,A2023
	cp	0Ch
	jp	z,A2023
	cp	8
	jp	z,A2032
	dec	a
	jp	z,A2032
	ret
A1F4F:	ld	a,(D7A06)
	cp	64h
	jr	z,A1F68
	cp	47h
	jr	z,A1F78
	cp	54h
	jr	z,A1F78
	or	a
	jr	z,A1F78
	jp	A2023
	;
A1F68:	ld	l,e
	ld	h,d
	ld	e,64h
	call	A1BCA
	push	hl
	ld	bc,7
A1F73:	add	hl,bc
	ld	(hl),1
	pop	hl
	ret
A1F78:	ld	a,(D7A06)
	cp	54h
	jr	nz,A1F83
	ld	a,59h			; 
	jr	A1F85
	;
A1F83:	ld	a,58h			; 
A1F85:	push	bc
	ld	l,e
	ld	h,d
	ld	(D78E0),a
	call	A5082
	call	A5255
	ld	(D78D3),hl
	pop	bc
	ld	a,(D78E0)
	ld	e,a
	ld	a,l
	or	h
	jr	z,A1FF3
	ld	a,(D7A0E)
	or	a
	jr	z,A1FBF
	ld	bc,7
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,A1FBF
	ld	hl,(D78CF)
	push	hl
	call	A5082
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	de
	ld	hl,T1EFE
	jp	A1CDF
	;
A1FBF:	ld	hl,(D78D1)
	ld	bc,5
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D78D3)
	ld	bc,5
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A1E15
	or	a
	jr	nz,A2002
	ld	hl,(D78CF)
	push	hl
	call	A5082
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	de
	ld	hl,T1F04
	jp	A1CDF
	;
A1FF3:	ld	hl,(D78CF)
	call	A1BCA
	ld	(D78D3),hl
	ld	bc,7
	add	hl,bc
	ld	(hl),0
A2002:	ld	a,(D7A0E)
	or	a
	jr	z,A201F
	ld	hl,(D78D3)
	ld	bc,7
	add	hl,bc
	ld	(hl),1
	ld	hl,(D78D1)
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D7A0F),hl
A201F:	ld	hl,(D78D3)
	ret


A2023:	ld	l,c
	ld	h,b
	push	bc
	call	A1EB1
	pop	bc
	inc	a
	jr	nz,A2032
	ld	hl,0			; false?
	ret
A2032:	ld	a,(D7A06)
	cp	64h
	jr	nz,A2044
	ld	hl,(D78CF)
	ld	a,(D7A06)
	ld	e,a
	jp	A1BCA
	;
A2044:	ld	a,(D7A06)
	cp	47h
	jr	z,A2051
	ld	a,1
	jr	A2052
	;
A2051:	xor	a
A2052:	push	bc
	ld	(D78D5),a
	ld	(D7907),a
	ld	a,(D7A06)
	or	a
	jr	nz,A2065
	ld	a,47h
	jr	A2068
	;
A2065:	ld	a,(D7A06)
A2068:	ld	hl,(D78CF)
	ld	(D78E0),a
	call	A5082
	call	A5255
	ld	(D78D3),hl
	pop	bc
	ld	a,(D78E0)
	ld	e,a
	ld	a,l
	or	h
	jr	z,A20C2
	ld	bc,7
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,A209B
	ld	hl,(D78CF)
	push	hl
	call	A5082
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	de
	ld	hl,T1EFE
	jp	A1CDF
	;
A209B:	ld	de,(D78D1)
	ld	hl,(D78D3)
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A1E15
	or	a
	jr	nz,A20D3
	ld	hl,(D78CF)
	push	hl
	call	A5082
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	de
	ld	hl,T1F04
	jp	A1CDF
	;
A20C2:	ld	hl,(D78CF)
	call	A1BCA
	ld	(D78D3),hl
	ld	bc,7
	add	hl,bc
	ld	a,(D78D5)
	ld	(hl),a
A20D3:	ld	hl,(D78D3)
	ret


A20D7:	push	hl
	push	de
	push	bc
	push	de
	push	hl
	call	A5079
	ld	a,l
	pop	hl
	pop	de
	; switch
	cp	1
	jr	z,A2103
	cp	33h
	jr	z,A2109
	cp	35h
	jr	z,A2109
	cp	34h
	jp	z,A2179
	cp	32h
	jp	z,A21B3
	cp	3Dh
	jp	z,A2238
	jp	A224E			; default
	;
A2103:	call	A1F1D
	jp	A2254
	;
A2109:	ex	de,hl
	inc	hl
	inc	hl
	; switch
	ld	a,(hl)
	cp	9
	jr	z,A2133
	cp	0Ah
	jr	z,A2133
	cp	0Dh
	jr	z,A2133
	cp	0Bh
	jr	z,A2133
	cp	0Ch
	jr	z,A2133
	cp	1
	jr	z,A2140
	cp	8
	jr	z,A2140
	; default
	jr	A2173
	;
A2133:	call	A758A
	ex	de,hl
	ld	hl,T2258
	call	A1D28
	jp	A2254
	;
A2140:	call	A758A
	call	A508D
	push	hl
	call	A7584
	call	A5079
	ld	a,l
	cp	33h
	jr	nz,A2158
	ld	a,9
	jr	A215A
	;
A2158:	ld	a,0Ah
A215A:	ld	hl,4
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	de
	call	A1D2E
	push	hl
	call	A7584
	call	A5082
	pop	de
	call	A20D7
	jp	A2254
	;
	; default
A2173:	ld	hl,T225B
	jp	A4F27
	;
A2179:	ld	a,(D7A06)
	cp	64h
	jr	z,A21A6
	cp	54h
	jr	z,A2188
	or	a
	jr	nz,A2190
A2188:	ld	a,(D77FB)
	cp	0A8h
	jr	nz,A21A6
A2190:	ld	a,(D7A06)
	cp	47h
	jr	nz,A21B3
	call	A758A
	call	A5082
	call	A5079
	ld	a,l
	dec	a
	jr	z,A21B3
A21A6:	call	A758A
	ex	de,hl
	ld	hl,T225F
	call	A1D28
	jp	A2254
	;
A21B3:	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	9
	jr	z,A21CE
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	0Ah
	jr	nz,A21DB
A21CE:	call	A758A
	ex	de,hl
	ld	hl,T2262
	call	A1D28
	jp	A2254
	;
A21DB:	push	de
	call	A7584
	pop	de
	push	hl
	push	hl
	ld	hl,6
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	call	A5079
	ld	a,l
	pop	hl
	push	hl
	cp	34h
	jr	nz,A21FB
	ld	hl,-1
	jr	A21FE
	;
A21FB:	call	A508D
A21FE:	push	hl
	ld	hl,6
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ld	a,l
	cpl
	ld	e,a
	ld	a,h
	cpl
	ld	d,a
	inc	de
	ld	a,0Dh
	call	A1D2E
	call	A7553
	ld	bc,7
	add	hl,bc
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	call	A5082
	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	call	A20D7
	jp	A2254
	;
A2238:	push	hl
	ld	c,e
D223A:	ld	b,d
	ld	de,0
	ld	a,8
	call	A1D2E
	ex	(sp),hl
	call	A5082
	pop	de
	call	A20D7
	jp	A2254
	;
A224E:	ld	hl,T2265
	jp	A4F27
	;
A2254:	pop	bc
	pop	bc
	pop	bc
	ret


A2269:	push	hl
	push	de
	push	bc
	push	hl
	ld	hl,4
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	push	de
	call	A754D
	pop	de
	push	de
	push	hl
	call	A5079
	ld	a,l
	pop	hl
	pop	bc
	; switch
	cp	1
	jr	z,A22A3
	cp	33h
	jp	z,A234F
	cp	35h
	jp	z,A234F
	cp	34h
	jp	z,A23D6
	cp	32h
	jp	z,A2417
	cp	3Dh
	jp	z,A249C
	jp	A24B5			; default
	;
A22A3:	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	; switch
	cp	9
	jr	z,A22CD
	cp	0Ah
	jr	z,A22CD
	cp	0Dh
	jp	z,A2308
	cp	0Bh
	jp	z,A2308
	cp	0Ch
	jp	z,A2308
	cp	8
	jp	z,A231D
	dec	a
	jp	z,A231D
	jp	A2349			; default
	;
A22CD:	ld	a,(D7A06)
	cp	47h
	jr	z,A22D9
	or	a
	jr	nz,A22E6
A22D9:	push	de
	call	A7584
	pop	de
	ld	e,58h
	call	A1BCA
	jp	A24BB
	;
A22E6:	ld	a,(D7A06)
	cp	64h
	jr	nz,A22FB
	push	de
	call	A7584
	pop	de
	ld	e,64h
	call	A1BCA
	jp	A24BB
	;
A22FB:	call	A758A
	ex	de,hl
	ld	hl,T24BF
	call	A1D28
	jp	A24BB
	;
A2308:	call	A758A
	ex	de,hl
	ld	l,c
	ld	h,b
	push	bc
	call	A1EB1
	pop	bc
	inc	a
	jr	nz,A231D
	ld	hl,0
	jp	A24BB
	;
A231D:	ld	a,(D7A06)
	or	a
	jr	nz,A2329
	ld	a,41h
	jr	A232C
	;
A2329:	ld	a,(D7A06)
A232C:	ld	e,a
	push	de
	call	A7584
	pop	de
	push	af
	call	A1BCA
	pop	af
	cp	47h
	jp	z,A24BB
	cp	64h
	jp	z,A24BB
	ld	a,1
	ld	(D7907),a
	jp	A24BB
	;
A2349:	ld	hl,T24C2
	jp	A4F27
	;
A234F:	call	A758A
	push	hl
	call	A508D
	pop	de
	ld	a,l
	or	h
	jr	z,A2366
	push	de			; номер строки
	ld	bc,T24C6		; 
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
A2366:	call	A7590
	inc	hl
	inc	hl
	ld	a,(hl)
	; switch
	cp	9
	jr	z,A2392
	cp	0Ah
	jr	z,A2392
	cp	0Dh
	jr	z,A2392
	cp	0Bh
	jr	z,A2392
	cp	0Ch
	jr	z,A2392
	cp	1
	jr	z,A239F
	cp	8
	jr	z,A239F
	jr	A23D0			; default
	;
A2392:	call	A758A
	ex	de,hl
	ld	hl,T24C9
	call	A1D28
	jp	A24BB
	;
A239F:	call	A758A
	call	A7553
	call	A5079
	ld	a,l
	cp	33h
	jr	nz,A23B3
	ld	a,9
	jr	A23B5
	;
A23B3:	ld	a,0Ah
A23B5:	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	de,0
	call	A1D2E
	push	hl
	call	A7584
	call	A5082
	pop	de
	call	A2269
	jp	A24BB
	; default
A23D0:	ld	hl,T24CC
	jp	A4F27
	;
A23D6:	ld	a,(D7A06)
	cp	41h
	jr	z,A240A
	cp	64h
	jr	z,A240A
	or	a
	jr	z,A240A
	cp	54h
	jr	nz,A23F4
	ld	a,(D77FB)
	cp	0A8h
	jr	nz,A240A
A23F4:	ld	a,(D7A06)
	cp	47h
	jr	nz,A2417
	call	A758A
	call	A5082
	call	A5079
	ld	a,l
	dec	a
	jr	z,A2417
A240A:	call	A758A
	ex	de,hl
	ld	hl,T24D0
	call	A1D28
	jp	A24BB
	;
A2417:	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	9
	jr	z,A2432
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	0Ah
	jr	nz,A243F
A2432:	call	A758A
	ex	de,hl
	ld	hl,T24D3
	call	A1D28
	jp	A24BB
	;
A243F:	push	de
	call	A7584
	pop	de
	push	hl
	push	hl
	ld	hl,6
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	call	A5079
	ld	a,l
	pop	hl
	push	hl
	cp	34h
	jr	nz,A245F
	ld	hl,-1
	jr	A2462
	;
A245F:	call	A508D
A2462:	push	hl
	ld	hl,6
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ld	a,l
	cpl
	ld	e,a
	ld	a,h
	cpl
	ld	d,a
	inc	de
	ld	a,0Dh
	call	A1D2E
	call	A7553
	ld	bc,7
	add	hl,bc
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	call	A5082
	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	call	A2269
	jp	A24BB
	;
A249C:	call	A7553
	ld	de,0
	ld	a,8
	call	A1D2E
	push	hl
	call	A7584
	call	A5082
	pop	de
	call	A2269
	jr	A24BB
	;
A24B5:	ld	hl,T24D6
	jp	A4F27
	;
A24BB:	pop	bc
	pop	bc
	pop	bc
	ret


A24DA:	ld	(D78D6),hl
	push	hl
	pop	iy
	ld	a,(iy+7)
	and	(iy+8)
	inc	a
	ret	z
	ld	a,(iy+4)
	or	a
	ret	p
	ld	e,(iy+5)
	ld	d,(iy+6)
	inc	de
	inc	de
	ld	a,(de)
	cp	0Bh
	jr	z,A24FE
	cp	0Ch
	jr	nz,A2505
A24FE:	ld	hl,5
	add	hl,de
	ld	a,(hl)
	or	a
	ret	z
A2505:	dec	de
	dec	de
	ld	(D78D8),de
	ld	c,(iy+7)
	ld	b,(iy+8)
	push	iy
	push	bc
	ld	hl,(D78D8)
	push	hl
	ld	hl,(D78D6)
	push	hl
	ld	bc,T253B		; "%t	%t	#%u"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	iy
	ld	a,(iy+3)
	cpl
	ld	c,a
	ld	a,(iy+4)
	cpl
	ld	b,a
	inc	bc
	ld	(iy+3),c
	ld	(iy+4),b
	ret

;++T253B:	db	"%t",9,"%t",9,"#%u",0Ah,0


A2546:	ex	de,hl
	ld	a,e
	or	d
	ret	z
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	65h
	ret	z
	ld	hl,5
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	push	de
	ld	bc,T2566		; "%v	%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	ret

;++T2566:	db	"%v",9,"%t",0Ah,0


A256D:	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	; switch
	cp	1
	jr	z,A2592
	cp	0Bh
	jr	z,A2595
	cp	0Ch
	jr	z,A2595
	cp	0Dh
	jr	z,A259B
	; default
	ld	hl,5
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A256D
	;
A2592:	ld	a,true
	ret
A2595:	ld	hl,7
	add	hl,de
	ld	a,(hl)
	ret
A259B:	ld	hl,5
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	de
	call	A256D
	pop	hl
	or	a
	jr	z,A25B2
	call	A24DA
	ld	a,true
	ret
A25B2:	xor	a			; false
	ret


A25B4:	ld	a,l
	or	h
	ret	z
	push	hl
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A256D
	ld	a,(D7907)
	pop	hl
	or	a
	ret	z
	jp	A2546



A25F2:	push	hl
	push	de
	push	bc
	push	de
	push	hl
	call	A5079
	ld	a,l
	pop	hl
	pop	de
	; switch
	cp	1
	jr	z,A261E
	cp	33h
	jp	z,A265D
	cp	35h
	jp	z,A265D
	cp	32h
	jp	z,A26E4
	cp	34h
	jp	z,A275A
	cp	3Dh
	jp	z,A275A
	jp	A2778			; default
	;
A261E:	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	; switch
	cp	0Dh
	jr	z,A2642
	cp	1
	jr	z,A2652
	cp	8
	jr	z,A2652
	; default
	push	hl
	call	A5082
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	de
	ld	hl,T25CC
	call	A1CDF
	jp	A277E
	;
A2642:	ld	hl,5
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	de,0
	ld	a,8
	call	A1D2E
	ex	de,hl
A2652:	push	de
	call	A7584
	pop	de
	call	A1C45
	jp	A277E
	;
A265D:	push	hl
	call	A508D
	pop	de
	ld	a,l
	or	h
	jr	z,A2670
	ld	hl,T25E1
	call	A1D28
	jp	A277E
	;
A2670:	call	A7590
	ld	e,l
	ld	d,h
	inc	hl
	inc	hl
	ld	a,(hl)
	; switch
	cp	9
	jr	z,A269E
	cp	0Ah
	jr	z,A269E
	cp	0Dh
	jr	z,A269E
	cp	0Bh
	jr	z,A269E
	cp	0Ch
	jr	z,A269E
	cp	1
	jr	z,A26AB
	cp	8
	jr	z,A26AB
	jr	A26DC			; default
	;
A269E:	call	A758A
	ex	de,hl
	ld	hl,T25E4
	call	A1D28
	jp	A277E
	;
A26AB:	call	A758A
	call	A7553
	call	A5079
	ld	a,l
	cp	33h
	jr	nz,A26BF
	ld	a,9
	jr	A26C1
	;
A26BF:	ld	a,0Ah
A26C1:	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	de,0
	call	A1D2E
	push	hl
	call	A7584
	call	A5082
	pop	de
	call	A25F2
	jp	A277E
	;
A26DC:	;push	de
	ld	hl,T25E7
	jp	A4F27
	;pop	de
	;
A26E4:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	9
	jr	z,A26F8
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	0Ah
	jr	nz,A2705
A26F8:	call	A758A
	ex	de,hl
	ld	hl,T25EB
	call	A1D28
	jr	A277E
	;
A2705:	push	de
	call	A7584
	pop	de
	push	hl
	push	hl
	ld	hl,6
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	call	A508D
	push	hl
	ld	hl,6
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ld	a,l
	cpl
	ld	e,a
	ld	a,h
	cpl
	ld	d,a
	inc	de
	ld	a,0Dh
	call	A1D2E
	call	A7553
	ld	bc,7
	add	hl,bc
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	call	A7590
	call	A755F
	call	A24DA
	pop	hl
	call	A5082
	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	call	A25F2
	jr	A277E
	;
A275A:	push	de
	call	A754D
	pop	de
	ex	de,hl
	ld	c,l
	ld	b,h
	ld	de,0
	ld	a,8
	call	A1D2E
	push	hl
	call	A7584
	call	A5082
	pop	de
	call	A25F2
	jr	A277E
	;
A2778:	ld	hl,T25EE
	jp	A4F27
	;
A277E:	pop	bc
	pop	bc
	pop	bc
	ret


A27B2:	push	hl
	push	de
	push	bc
	push	hl
	ld	hl,4
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	push	de
	call	A754D
	pop	de
	push	de
	push	hl
	call	A5079
	ld	a,l
	pop	hl
	pop	bc
	; switch
	cp	1
	jr	z,A27EC
	cp	33h
	jp	z,A2854
	cp	35h
	jp	z,A2854
	cp	32h
	jp	z,A28EE
	cp	34h
	jp	z,A297A
	cp	3Dh
	jp	z,A2991
	jp	A29AA			; default
	;
A27EC:	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	; switch
	cp	9
	jr	z,A2816
	cp	0Ah
	jr	z,A2816
	cp	0Bh
	jr	z,A2832
	cp	0Ch
	jr	z,A2832
	cp	0Dh
	jr	z,A2832
	cp	8
	jr	z,A2841
	dec	a
	jr	z,A2841
	jr	A284E			; default
	;
A2816:	push	de
	call	A7584
	pop	de
	push	hl			; номер колонки
	push	hl			; номер строки
	ld	bc,T2782
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	hl
	ld	e,65h
	ld	bc,0
	call	A1D58
	jp	A29B0
	;
A2832:	call	A758A
	ex	de,hl
	ld	l,c
	ld	h,b
	push	bc
	call	A1EB1
	pop	bc
	inc	a
	jp	z,A29B0
A2841:	push	de
	call	A7584
	pop	de
	ld	e,4Dh
	call	A1D58
	jp	A29B0
	;
A284E:	ld	hl,T279A
	jp	A4F27
	;
A2854:	push	de
	call	A7584
	pop	de
	push	hl
	call	A508D
	pop	bc
	ld	a,l
	or	h
	jr	z,A286D
	push	bc
	ld	bc,T279E
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
A286D:	push	de
	call	A758A
	pop	de
	inc	hl
	inc	hl
	; switch
	ld	a,(hl)
	cp	9
	jr	z,A289B
	cp	0Ah
	jr	z,A289B
	cp	0Dh
	jr	z,A289B
	cp	0Bh
	jr	z,A289B
	cp	0Ch
	jr	z,A289B
	cp	1
	jr	z,A28B7
	cp	8
	jr	z,A28B7
	jr	A28E8			; default
	;
A289B:	push	de
	call	A7584
	pop	de
	push	hl
	push	hl
	ld	bc,T27A1
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	hl
	ld	e,65h
	ld	bc,0
	call	A1D58
	jp	A29B0
	;
A28B7:	call	A758A
	call	A7553
	call	A5079
	ld	a,l
	cp	33h
	jr	nz,A28CB
	ld	a,9
	jr	A28CD
	;
A28CB:	ld	a,0Ah
A28CD:	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	de,0
	call	A1D2E
	push	hl
	call	A7584
	call	A5082
	pop	de
	call	A27B2
	jp	A29B0
	;
A28E8:	ld	hl,T27A4
	jp	A4F27
	;
A28EE:	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	9
	jr	z,A2909
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	0Ah
	jr	nz,A2925
A2909:	push	de
	call	A7584
	pop	de
	push	hl
	push	hl
	ld	bc,T27A8
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	hl
	ld	e,65h
	ld	bc,0
	call	A1D58
	jp	A29B0
	;
A2925:	push	de
	call	A7584
	pop	de
	push	hl
	push	hl
	ld	hl,6
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	call	A508D
	push	hl
	ld	hl,6
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ld	a,l
	cpl
	ld	e,a
	ld	a,h
	cpl
	ld	d,a
	inc	de
	ld	a,0Dh
	call	A1D2E
	call	A7553
	ld	bc,7
	add	hl,bc
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	call	A7590
	call	A755F
	call	A24DA
	pop	hl
	call	A5082
	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	call	A27B2
	jr	A29B0
	;
A297A:	push	hl
	push	hl
	ld	bc,T27AB
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	hl
	ld	e,65h
	ld	bc,0
	call	A1D58
	jr	A29B0
	;
A2991:	call	A7553
	ld	de,0
	ld	a,8
	call	A1D2E
	push	hl
	call	A7584
	call	A5082
	pop	de
	call	A27B2
	jr	A29B0
	;
A29AA:	ld	hl,T27AE
	jp	A4F27
	;
A29B0:	pop	bc
	pop	bc
	pop	bc
	ret


;++T29B4:	db	"%t",9,"(",0Ah,0
;T29BA:	db	")",0Ah,0


A29BD:	push	hl
	push	hl
	ld	bc,T29B4		; "%t	("
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	hl
	push	hl
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
A29D2:	ld	a,l
	or	h
	jr	z,A29E7
	push	hl
	call	A2546
	pop	hl
	ld	bc,7
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A29D2
	;
A29E7:	ld	bc,T29BA		; ")"
	push	bc
	call	A4ABC
	pop	bc
	pop	hl
	jp	A51DB


A2A0A:	ld	a,1			; true?
	ld	(D79FF),a
	ld	hl,(D76DB)
	push	hl
	call	A3640
	call	A36A1
	ld	(D78DA),hl
	pop	hl
	ld	(D76DB),hl
	ld	hl,(D78DA)
	ret


A2A26:	ld	a,(D77FB)
	cp	0DFh
	jp	nz,A2A0A
A2A2E:	call	A1651
A2A31:	ld	a,(D77FB)
	cp	0E0h
	jr	z,A2A44
	call	A2A26
	ld	a,(D77FB)
	cp	0B8h
	jr	z,A2A2E
A2A44:	ld	de,T2A24		; "}"
	ld	a,0E0h
	jp	A54CE


A2A5A:	ld	c,l
	ld	b,h
	inc	hl
	inc	hl
	ld	a,(hl)
	cp	8
	jr	z,A2A67
	cp	1
	jr	nz,A2A72
A2A67:	push	bc
	ld	bc,T2A4F
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	ret
A2A72:	cp	0Dh
	jr	nz,A2AA3
	ld	hl,7
	add	hl,bc
	ld	a,(hl)
	inc	hl
	and	(hl)
	inc	a
	ret	z
	ld	hl,0
A2A83:	push	hl
	ld	hl,7
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	call	A74EC
	ret	nc
	push	bc
	push	hl
	ld	hl,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2A5A
	pop	hl
	inc	hl
	pop	bc
	jr	A2A83
	;
A2AA3:	cp	0Bh
	jr	nz,A2ACB
	ld	hl,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
A2AB0:	ld	a,l
	or	h
	ret	z
	push	hl
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2A5A
	pop	hl
	ld	bc,7
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A2AB0
	;
A2ACB:	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T2A57
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jp	A2A26



A2AE8:	ld	(D78DC),hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	hl,(D77F7)		; номер колонки
	ld	(D78DE),hl
	ld	hl,(D78DC)
	push	hl
	ld	bc,T2AE0		; "	%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	ld	a,(D77FB)
	cp	0DFh
	jr	nz,A2B1D
	call	A1651
	call	A2A0A
	ld	de,T2AE4
	ld	a,0E0h
	push	hl
	call	A54CE
	pop	hl
	jr	A2B20
	;
A2B1D:	call	A2A0A
A2B20:	pop	bc
	ld	de,(D78DE)
	ld	a,l
	or	h
	jr	z,A2B33
	push	de
	ex	de,hl
	ld	hl,(D78DC)
	call	A636C
	pop	bc
A2B33:	ld	bc,T2AE6
	push	bc
	call	A4ABC
	pop	bc
	ret



A2B50:	push	hl
	push	bc
	push	bc
	push	bc
	push	bc
	ld	hl,8
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D77F9)		; номер строки
	push	de
	call	A754D
	pop	de
	ld	hl,(D77F7)		; номер колонки
	push	de
	call	A7541
	pop	de
	push	hl
	ld	hl,7
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	de
	call	A754D
	pop	de
	ld	hl,5
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D78B4)
	pop	bc
	or	a
	sbc	hl,de
	jp	nz,A2C24
	ld	a,(D77FB)
	cp	5
	jp	nz,A2C24
	push	bc
	ld	hl,(D77FD)
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	l,c
	ld	h,b
	call	A755F
	push	hl
	ld	hl,(D77FD)
	inc	hl
	inc	hl
	ex	de,hl
A2BA6:	push	de
	call	A7584
	pop	de
	dec	hl
	push	de
	call	A754D
	pop	de
	inc	hl
	ld	a,l
	or	h
	jr	z,A2BCB
	ld	a,(de)
	inc	de
	ld	c,a
	ld	b,0
	push	de
	push	bc
	ld	bc,T2B3C
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	de
	jr	A2BA6
	;
A2BCB:	call	A7584
	pop	de
	pop	bc
	ld	a,l
	and	h
	inc	a
	jr	nz,A2BE7
	push	de
	call	A759C
	db	0Ch,0
	;
	pop	de
	ld	bc,7
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	jr	A2C1E
	;
A2BE7:	call	A74EC
	jr	nc,A2BFF
	push	bc
	call	A7584
	push	hl
	ld	bc,T29F3
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A2C1E
	;
A2BFF:	ld	a,l
	sub	e
	ld	c,a
	ld	a,h
	sbc	a,d
	ld	b,a
	ld	e,c
	ld	d,b
A2C07:	ld	hl,0
	call	A74EC
	jr	nc,A2C1E
	ld	bc,T2B44
	push	de
	push	bc
	call	A4ABC
	pop	bc
	pop	de
	dec	de
	jr	A2C07
	;
A2C1E:	call	A1651
	jp	A2D6F
	;
A2C24:	ld	a,(D77FB)
	cp	0DFh
	jp	nz,A2CD7
	ld	hl,0
	ld	d,h
	ld	e,h
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
A2C36:	push	de
	call	A1651
	ld	a,(D77FB)
	pop	de
	cp	0E0h
	jr	z,A2C65
	push	de
	call	A759C
	db	0Ch,0
	;
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2E97
	pop	de
	inc	de
	ld	hl,0
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	a,(D77FB)
	cp	0B8h
	jr	z,A2C36
A2C65:	ld	de,T2B4B
	ld	a,0E0h
	call	A54CE
	call	A7590
	ld	a,l
	and	h
	inc	a
	jr	nz,A2C8C
	call	A7578
	ld	bc,7
	add	hl,bc
	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	jp	A2D6F
	;
A2C8C:	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	call	A74EC
	jr	nc,A2CB0
	call	A7584
	push	hl
	call	A7584
	push	hl
	ld	bc,T29F3
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jp	A2D6F
	;
A2CB0:	ld	a,l
	sub	e
	ld	c,a
	ld	a,h
	sbc	a,d
	ld	b,a
	ld	e,c
	ld	d,b
A2CB8:	ld	hl,0
	call	A74EC
	jp	nc,A2D6F
	push	de
	call	A759C
	db	0Ch,0
	;
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2A5A
	pop	de
	dec	de
	jr	A2CB8
	;
A2CD7:	call	A7590
	ld	a,l
	and	h
	inc	a
	jr	nz,A2CF7
	ld	l,c
	ld	h,b
	push	hl
	call	A7584
	push	hl
	ld	bc,T2B4D
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,7FFFh		; константа max "int" 32767 ? (в стек)
	call	A755F
A2CF7:	ld	de,0
	push	hl
	ld	hl,2
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	push	hl
A2D04:	ld	a,(D77FB)
	cp	0E0h
	jr	z,A2D3F
	call	A759C
	db	0Ch,0
	;
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2E97
	call	A758A
	ex	de,hl
	push	de
	call	A758A
	pop	de
	inc	hl
	push	de
	call	A7553
	pop	de
	call	A74EC
	jr	nc,A2D3F
	ld	a,(D77FB)
	cp	0B8h
	jr	nz,A2D3F
	call	A1651
	jr	A2D04
	;
A2D3F:	pop	de
	ld	a,d
	add	a,80h
	and	e
	inc	a
	jr	z,A2D6F
A2D48:	push	de
	call	A7590
	pop	de
	inc	hl
	push	de
	call	A755F
	pop	de
	dec	hl
	call	A74EC
	jr	nc,A2D6F
	push	de
	call	A759C
	db	0Ch,0
	;
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2A5A
	pop	de
	jr	A2D48
	;
A2D6F:	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret


A2D77:	push	bc
	push	bc
	ld	a,(D77FB)
	cp	0DFh
	jp	nz,A2E38
	push	hl
	ld	hl,(D77F9)		; номер строки
	call	A755F
	ld	hl,(D77F7)		; номер колонки
	call	A7553
	pop	hl
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
A2D97:	push	hl
	call	A1651
	pop	hl
	cp	0E0h
	jr	z,A2DC8
	ld	a,l
	or	h
	jr	z,A2DC8
	push	hl
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2E97
	pop	hl
	ld	bc,7
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,l
	or	h
	jr	z,A2DC8
	ld	a,(D77FB)
	cp	0B8h
	jr	z,A2D97
A2DC8:	push	hl
	push	hl
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	push	hl
	ld	hl,6
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	ld	a,l
	or	h
	jr	nz,A2DF4
	ld	a,(D77FB)
	cp	0E0h
	jr	z,A2DF4
	push	bc
	push	de
	ld	bc,T29F3		; 
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A2DF4:	ld	a,(D77FB)
	cp	0E0h
	jr	z,A2E12
	ld	a,(D77FB)
	cp	0FAh
	jr	z,A2E12
	ld	a,(D77FB)
	cp	0C8h
	jr	z,A2E12
	call	A1651
	jr	A2DF4
	;
A2E12:	ld	de,T2D75
	ld	a,0E0h
	call	A54CE
	pop	hl
A2E1B:	ld	a,l
	or	h
	jr	z,A2E94
	push	hl
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2A5A
	pop	hl
	ld	bc,7
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A2E1B
	;
A2E38:	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
A2E40:	ld	a,l
	or	h
	jr	z,A2E77
	ld	a,(D77FB)
	cp	0E0h
	jr	z,A2E77
	push	hl
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2E97
	pop	hl
	ld	bc,7
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,l
	or	h
	jr	z,A2E77
	ld	a,(D77FB)
	cp	0B8h
	jr	nz,A2E77
	push	hl
	call	A1651
	pop	hl
	jr	A2E40
	;
A2E77:	ld	a,l
	or	h
	jr	z,A2E94
	push	hl
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2A5A
	pop	hl
	ld	bc,7
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A2E77
A2E94:	pop	bc
	pop	bc
	ret
	;
A2E97:	push	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	pop	hl
	cp	8
	jp	z,A2AE8
	cp	1
	jp	z,A2AE8
	cp	0Dh
	jp	z,A2B50
	cp	0Bh
	jp	z,A2D77
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T2EC5		; "XI"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jp	A2A26


A2EC8:	ld	a,l
	or	h
	ret	z
	push	hl
	push	hl
	ld	bc,T2EEF
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	hl
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A2E97
	ld	bc,T2EF5
	push	bc
	call	A4ABC
	pop	bc
	xor	a
	ld	(D7907),a
	ret

;++T2EEF:	db	"%v",9,"(",0Ah,0
;T2EF5:	db	")",0Ah,0


A2EF8:	ld	(D78E4),a
	ld	hl,(D79DF)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T790D
	add	hl,bc
	ld	a,(hl)
	ld	hl,T2F19
	ld	bc,11
	cpir
	jr	nz,A2F24
	ld	a,(D78E4)
	ret

T2F19:	db	0x30,0x31,0x10,0x20,0x01,0x04,0x02,0x03,0x05,0x06,0xFF	; ?

A2F24:	ld	a,(D78E4)
	cp	51h			; Q
	jr	z,A2F41
	cp	30h			; 0
	jr	z,A2F44
	cp	31h			; 1
	jr	z,A2F47
	cp	48h			; H
	jr	z,A2F4A
	cp	70h			; p
	jr	z,A2F4D
	ret
A2F41:	ld	a,3Ah			; :
	ret
A2F44:	ld	a,38h			; 8
	ret
A2F47:	ld	a,39h			; 9
	ret
A2F4A:	ld	a,3Dh			; =
	ret
A2F4D:	ld	a,3Eh			; >
	ret



A2F5A:	push	bc
	push	bc
	call	A1651
	cp	8
	jp	nz,A2FEC
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	hl,(D77F7)		; номер колонки
	call	A755F
	call	A1651
	ld	hl,(D78F3)
	ld	a,(D7A06)
	push	hl
	ld	hl,6
	add	hl,sp
	ld	(hl),a
	call	A3967
	or	a
	jr	z,A2FCC
	ld	a,(D78F5)
	or	a
	jr	z,A2F9D
	ld	hl,(D7A24)
	push	hl
	ld	hl,(D7A22)
	push	hl
	ld	bc,T2F50
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A2F9D:	call	A388D
	ld	de,(D78F3)
	call	A3735
	ld	(D77FD),hl
	ld	a,(D77FB)
	cp	10h
	jr	z,A2FC4
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T2F53
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A2FC4:	ld	a,40h
	ld	(D77FB),a
	jr	A2FD4
	;
A2FCC:	call	A161E
	ld	a,8
	ld	(D77FB),a
A2FD4:	pop	hl
	ld	(D78F3),hl
	ld	hl,4
	add	hl,sp
	ld	a,(hl)
	ld	(D7A06),a
	pop	hl
	ld	(D77F9),hl		; номер строки
	pop	hl
	push	hl
	ld	(D77F7),hl		; номер колонки
	jr	A301F
	;
A2FEC:	ld	a,(D77FB)
	cp	3Fh
	jr	nz,A301F
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	hl,(D77F7)		; номер колонки
	call	A755F
	call	A2F5A
	cp	40h
	jr	nz,A300E
	ld	a,6
	ld	(D77FB),a
	jr	A3016
	;
A300E:	call	A161E
	ld	a,3Fh
	ld	(D77FB),a
A3016:	pop	hl
	ld	(D77F9),hl		; номер строки
	pop	hl
	push	hl
	ld	(D77F7),hl		; номер колонки
A301F:	ld	a,(D77FB)
	pop	bc
	pop	bc
	ret



A3025:	call	A2F5A
	dec	a
	jr	nz,A304A
	ld	hl,(D77FD)
	call	A522C
	ld	(D78E2),hl
	ld	a,l
	or	h
	jr	nz,A3050
	ld	hl,(D77FD)
	call	A527D
	ld	(D78E2),hl
	inc	hl
	inc	hl
	ld	(hl),75h
	jr	A3050
	;
A304A:	ld	hl,(D77FD)
	ld	(D78E2),hl
A3050:	ld	a,(D77FB)
	ret


A3054:	push	de
	push	af
	ld	(D78E5),bc
	ld	a,(D79DF)
	inc	a
	cp	1Eh
	ld	a,2			; индекс строки "stack"
	jp	nc,A4F02		; abort
	;
	ld	hl,(D79DF)
	inc	hl
	ld	(D79DF),hl
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T790D
	add	hl,bc
	pop	af
	ld	(hl),a
	inc	hl
	ld	bc,(D78E5)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	ld	iy,0
	add	iy,sp
	ld	c,(iy+4)
	ld	b,(iy+5)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	cp	0FFh
	ret	z
	cp	0FBh
	ret	z
	ld	hl,(D79DF)
	ld	(D79E1),hl
	ret


A30A7:	ex	de,hl
A30A8:	ld	a,(de)
	cp	(hl)
	jr	nz,A30BC
	ld	a,(de)
	cp	0FBh
	jr	nz,A30B4
	ld	a,true
	ret
A30B4:	inc	de
	ld	bc,7
	add	hl,bc
	jr	A30A8
A30BC:	xor	a			; false
	ret


A30BE:	ld	a,(hl)
	inc	hl
	cp	0FBh
	ret	z
	jr	A30BE
	

	; 58 байт
T30C6:	db	0x01
	db	0xFB,0x03,0xFB,0x02,0xFB,0x04,0xFB,0x05
	db	0xFB,0x06,0xFB,0xFF,0x29,0x01,0xFB,0xFF
	db	0x28,0x01,0xFB,0xFF,0x18,0xFF,0x20,0xFB
	db	0xFF,0x08,0xFF,0x10,0xFB,0xFF,0x08,0x10
	db	0xFB,0x08,0xFF,0x10,0xFB,0xFF,0x30,0xFB
	db	0xFF,0x31,0xFB,0x38,0xFF,0xFB,0x39,0xFF
	db	0xFB,0x3A,0xFF,0xFB,0x3B,0xFF,0xFB,0x3C
	db	0xFF
	; 141 байт
	db	0xFB,0x3D,0xFF,0xFB,0x3E,0xFF,0xFB,0x3F
	db	0xFF,0xFB,0x40,0xFF,0xFB,0xFF,0x48,0xFF
	db	0xFB,0xFF,0x49,0xFF,0xFB,0xFF,0x4A,0xFF
	db	0xFB,0xFF,0x50,0xFF,0xFB,0xFF,0x51,0xFF
	db	0xFB,0xFF,0x58,0xFF,0xFB,0xFF,0x59,0xFF
	db	0xFB,0xFF,0x60,0xFF,0xFB,0xFF,0x61,0xFF
	db	0xFB,0xFF,0x62,0xFF,0xFB,0xFF,0x63,0xFF
	db	0xFB,0xFF,0x68,0xFF,0xFB,0xFF,0x69,0xFF
	db	0xFB,0xFF,0x70,0xFF,0xFB,0xFF,0x78,0xFF
	db	0xFB,0xFF,0x80,0xFF,0xFB,0xFF,0x88,0xFF
	db	0xFB,0xFF,0x90,0xFF,0xFB,0xFF,0x98,0xFF
	db	0xA0,0xFF,0xFB,0xFF,0xA8,0xFF,0xFB,0xFF
	db	0xA9,0xFF,0xFB,0xFF,0xAA,0xFF,0xFB,0xFF
	db	0xAB,0xFF,0xFB,0xFF,0xAC,0xFF,0xFB,0xFF
	db	0xAD,0xFF,0xFB,0xFF,0xAE,0xFF,0xFB,0xFF
	db	0xAF,0xFF,0xFB,0xFF,0xB0,0xFF,0xFB,0xFF
	db	0xB1,0xFF,0xFB,0xFF,0xB2,0xFF,0xFB,0xFF
	db	0xB8,0xFF,0xFB,0xFC



A318C:	ld	(A328C+1),hl
	ld	(A31C2+1),de
A3193:	ld	hl,(D79E1)
	ld	(D78E7),hl
A3199:	ld	hl,(D79E1)
	dec	hl
	ld	(D79E1),hl
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T790D
	add	hl,bc
	ld	a,(hl)
	inc	a
	jr	z,A3199
	dec	a
	ld	hl,(D78E7)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T790D
	add	hl,bc
	ld	e,(hl)
A31C2:	call	0
	cp	0Eh
	jr	nz,A3193
	ld	bc,0
;*	push	bc
	;ld	bc,0
	;ld	de,0
	ld	e,c;
	ld	d,c;
	ld	a,0FBh
	call	A3054
;	pop	bc
	ld	hl,(D79E1)
	inc	hl
	ld	(D78E7),hl
	ld	a,1
	ld	(D78E9),a
	ld	hl,T30C6
A31E9:	push	hl
	ld	hl,(D78E7)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T790D
	add	hl,bc
	ex	de,hl
	pop	hl
	push	hl
	call	A30A7
	pop	hl
	or	a
	jr	nz,A327F
	ld	a,(hl)
	cp	0FCh
	jr	nz,A3272
	ld	hl,(D79E1)
	inc	hl
A320E:	push	hl
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T790D
	add	hl,bc
	ld	a,(hl)
	pop	hl
	inc	a
	jr	nz,A3225
	inc	hl
	jr	A320E
	;
A3225:	ld	(D78E7),hl
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7910
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	ld	hl,(D78E7)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T790E
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	ld	bc,T329A		; "Xsyntax error"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,(D79E1)
	ld	(D79DF),hl
	;ld	bc,0
	xor	a;
	ld	c,a;
	ld	b,a;
	push	bc
;-	ld	bc,0
;	ld	de,0
	ld	e,a;
	ld	d,a;
	dec	a;
	;ld	a,0FFh
	call	A3054
	pop	bc
	ld	hl,-1
	ld	(D7A11),hl
	ret
A3272:	ld	a,(D78E9)
	inc	a
	ld	(D78E9),a
	call	A30BE
	jp	A31E9
	;
A327F:	ld	hl,(D79E1)
	ld	(D79DF),hl
	ld	bc,0
	push	bc
	ld	a,(D78E9)
A328C:	call	0
	ex	de,hl
	ld	bc,0
	ld	a,-1
	call	A3054
	pop	bc
	ret


A32A8:	ld	a,49h
	ld	(D77FB),a
	push	hl
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T32E1		; "XS"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret

A32C2:	push	de
	push	af
	call	A161E
	pop	af
	ld	(D77FB),a
	pop	de
	push	de
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T32E4		; "XMS"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret



A3367:	ld	hl,-1
	ld	(D7A11),hl
	cp	9
	jp	nc,A33CB
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	de,T337F
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	jp	(hl)

T337F:	dw	A33CB
	dw	L3391
	dw	L3399
	dw	L33A1
	dw	L33A9
	dw	L33B1
	dw	L33B7
	dw	L33BD
	dw	L33C5

L3391:	ld	de,T32E8		; "operator (or semicolon)"
	ld	a,49h
	jp	A32C2
	;
L3399:	ld	de,T3300		; "member name"
	ld	a,1
	jp	A32C2
	;
L33A1:	ld	de,T330C		; ")"
	ld	a,10h
	jp	A32C2
	;
L33A9:	ld	de,T3310		; "]"
	ld	a,20h
	jp	A32C2
	;
L33B1:	ld	hl,T3314		; "bad assignment"
	jp	A32A8
	;
L33B7:	ld	hl,T3323		; bad conditional expression... (плохое условное выражение)
	jp	A32A8
	;
L33BD:	ld	de,T334C		; ":"
	ld	a,0A0h
	jp	A32C2
	;
L33C5:	ld	hl,T3350		; "precedence error"
	jp	A32A8
	;
A33CB:	ld	hl,T3361		; "norel"
	jp	A4F27


A33D1:	push	hl
	push	de
	push	bc
	ld	e,c
	ld	d,b
	ld	hl,(D79DF)
	push	hl
	ld	hl,(D79E1)
	call	A755F
	call	A161E
	call	A3025
	ld	bc,0
;*	push	bc
;	ld	bc,0
;	ld	de,0
	ld	e,c
	ld	d,c
	ld	a,0C8h
	call	A3054
;	pop	bc
A33F6:	ld	hl,T3424
	push	hl
	ld	iy,8
	add	iy,sp
	ld	l,(iy+0)
	ld	h,(iy+1)
	push	hl
	ld	a,(D77FB)
	call	A2EF8
	ld	(D77FB),a
	ld	e,a
	push	de
	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T790D
	add	hl,bc
	ld	a,(hl)
	pop	de
	ret
	;
T3424:	cp	0Eh
	jr	z,A342C
	cp	0Dh
	jr	nz,A3445
A342C:	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	bc,(D77F9)		; номер строки
	ld	de,(D78E2)
	ld	a,(D77FB)
	call	A3054
	pop	bc
	call	A3025
	jp	A33F6
	;
A3445:	cp	0Fh
	jr	nz,A3469
	ld	hl,(D79E1)
	push	hl
	call	A7590
	pop	de
	inc	hl
	ld	a,e
	cp	l
	jr	nz,A345A
	ld	a,d
	cp	h
	jr	z,A346F
A345A:	call	A7584
	ex	de,hl
	push	de
	call	A7584
	pop	de
	call	A318C
	jp	A33F6
	;
A3469:	call	A3367
	jp	A33F6
	;
A346F:	ld	hl,(D79DF)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7912		; ds 6
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	hl
	call	A7590
	ld	(D79DF),hl
	call	A758A
	ld	(D79E1),hl
	pop	hl
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret


A3495:	cp	0C0h
	jr	c,A349D
	ld	a,17h
	ret
A349D:	rrca				; одинаково с A34B8
	rrca
	rrca
	and	1Fh
	ld	l,a
	ld	h,0
	ld	bc,T350D		; массив байтов
	add	hl,bc
	ld	a,(hl)
	ret

A34AB:	cp	0C0h
	jr	nc,A34B5
	cp	0B8h
	jp	nz,A349D		; A34B8
A34B5:	ld	a,17h
	ret


T34C6:	ld	(D78EA),a
	ld	a,e
	call	A3495
	ld	e,a
	push	de
	ld	a,(D78EA)
	call	A3495
	pop	de
	jr	A34E8
	;
T34D8:	ld	(D78EB),a
	ld	a,e
	call	A34AB
	ld	e,a
	push	de
	ld	a,(D78EB)
	call	A34AB
	pop	de
A34E8:	ld	h,0
	ld	l,a
	ld	a,e
	dec	a
	dec	hl
	add	hl,hl
	add	hl,hl
	ld	b,h
	ld	c,l
	add	hl,hl
	add	hl,bc
	ld	bc,T3525		; массив байтов
	add	hl,bc
	ld	c,a
	and	0FEh
	rrca
	ld	d,0
	ld	e,a
	add	hl,de
	ld	a,c
	and	1
	ld	a,(hl)
	jr	z,A350A
	rrca
	rrca
	rrca
	rrca
A350A:	and	0Fh
	ret


T350D:	db	0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08
	db	0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F
	db	0x10,0x11,0x12,0x13,0x14,0x15,0x15,0x16

T3525:	db	0xF1,0xFF,0xFF,0x1F,0xFF,0xFF,0xFF,0xFF
	db	0xFF,0xFF,0xFF,0x0F,0xEE,0xED,0xE3,0xEE
	db	0xEE,0xEE,0xEE,0xEE,0xEE,0x6E,0xEE,0x03
	db	0xF1,0xFF,0xFF,0x1F,0xFF,0xFF,0xFF,0xFF
	db	0xFF,0xFF,0xFF,0x0F,0xEE,0xE4,0xED,0xEE
	db	0xEE,0xEE,0xEE,0xEE,0xEE,0x6E,0xEE,0x04
	db	0xF1,0xFF,0xFF,0x1F,0xFF,0xFF,0xFF,0xFF
	db	0xFF,0xFF,0xFF,0x0F,0x2D,0x22,0x22,0x22
	db	0x22,0x22,0x22,0x22,0x22,0x22,0x22,0x02
	db	0x11,0x1F,0x1F,0x1F,0xFF,0xFF,0xFF,0xFF
	db	0xFF,0xFF,0xFF,0x0F,0xEE,0xEF,0xEF,0xEE
	db	0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x0F
	db	0xEE,0xEF,0xEF,0xEE,0xFF,0xFF,0xFF,0xFF
	db	0xFF,0xFF,0xF5,0x0F,0xEE,0xEF,0xEF,0xEE
	db	0xFE,0xFF,0xFF,0xFF,0xFF,0xFF,0xF5,0x0F
	db	0xEE,0xEF,0xEF,0xEE,0xEE,0xFF,0xFF,0xFF
	db	0xFF,0xFF,0xF5,0x0F,0xEE,0xEF,0xEF,0xEE
	db	0xEE,0xFE,0xFF,0xFF,0xFF,0xFF,0xF5,0x0F
	db	0xEE,0xEF,0xEF,0xEE,0xEE,0xEE,0xFF,0xFF
	db	0xFF,0xFF,0xF5,0x0F,0xEE,0xEF,0xEF,0xEE
	db	0xEE,0xEE,0xFE,0xFF,0xFF,0xFF,0xF5,0x0F
	db	0xEE,0xEF,0xEF,0xEE,0xEE,0xEE,0xEE,0xFF
	db	0xFF,0xFF,0xF5,0x0F,0xEE,0xEF,0xEF,0xEE
	db	0xEE,0xEE,0xEE,0xFE,0xFF,0xFF,0xF5,0x0F
	db	0xEE,0xEF,0xEF,0xEE,0xEE,0xEE,0xEE,0xEE
	db	0xFF,0xFF,0xF5,0x0F,0xEE,0xEF,0xEF,0xEE
	db	0xEE,0xEE,0xEE,0xEE,0xFE,0xFF,0xF5,0x0F
	db	0xEE,0xE7,0xE7,0xEE,0xEE,0xEE,0xEE,0xEE
	db	0xEE,0xDE,0x88,0x07,0xEE,0xEF,0xEF,0xEE
	db	0xEE,0xEE,0xEE,0xEE,0xEE,0xFE,0xF8,0x0F
	db	0xEE,0xEF,0xEF,0xEE,0xEE,0xEE,0xEE,0xEE
	db	0xEE,0x6E,0xFE,0x0F,0xEE,0xEF,0xEF,0xEE
	db	0xEE,0xEE,0xEE,0xEE,0xEE,0x6E,0xFE,0x0F
	db	0xEE,0xEF,0xEF,0xEE,0xEE,0xEE,0xEE,0xEE
	db	0xEE,0xFE,0xEE,0x0F


A3639:	ld	hl,-1
	ld	(D79DF),hl
	ret


A3640:	xor	a			; false
	ld	(D78E1),a
	call	A518B
	call	A3639
	ld	hl,0
	ld	(D7A11),hl
	ld	de,T45B0
	ld	a,(D79FF)
	or	a
	jr	z,A365E
	ld	hl,T34D8
	jr	A3661
	;
A365E:	ld	hl,T34C6
A3661:	call	A33D1
	ld	(D78EC),hl
	ld	a,l
	or	h
	jr	nz,A3670
	ld	hl,false		; 0
	ret
A3670:	ld	hl,(D7A11)
	ld	a,l
	and	h
	inc	a
	jr	nz,A367D
	ld	hl,true			; 1
	ret
A367D:	ld	a,(D76C8)
	ld	(D78EE),a
	xor	a			; false
	ld	(D76C8),a
	inc	a			; true
	ld	(D78BC),a
	ld	hl,(D78EC)
	push	hl
	call	A742E
	call	A63F8
	ld	(D78F3),hl
	ld	a,(D78EE)
	ld	(D76C8),a
	pop	hl
	ret


A36A1:	xor	a
	ld	(D78F6),a
	ld	a,l
	or	h
	jr	nz,A36B5
	ld	a,1
	ld	(D78F6),a
	ld	hl,0
	jr	A36CD
	;
A36B5:	ld	a,(D78E1)
	or	a
	jr	z,A36C2			; false
	ld	hl,0
	jr	A36CD
	;
A36C2:	ld	a,2
	ld	(D78BC),a
	call	A742E
	call	A63F8
A36CD:	push	hl
	call	A51C2
	pop	hl
	ret


A36D3:	xor	a
	ld	(D79FF),a
	ld	hl,(D76DB)
	push	hl
	call	A3640
	call	A36A1
	ld	(D78EF),hl
	pop	hl
	ld	(D76DB),hl
	ld	hl,(D78EF)
	ret


A3700:	ld	a,l
	or	h
	ret	z
	ld	a,l
	dec	a
	or	h
	ret	z
	push	hl
	call	A644E
	pop	hl
	or	a
	ret	z
	push	hl
	ld	bc,T36EC		; "бесполезное выражение"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ret


A3719:	xor	a
	ld	(D79FF),a
	ld	hl,(D76DB)
	push	hl
	call	A3640
	call	A3700
	call	A36A1
	ld	(D78F1),hl
	pop	hl
	ld	(D76DB),hl
	ld	hl,(D78F1)
	ret



A3735:	ld	a,l
	or	h
	ex	de,hl
	ret	z
	ex	de,hl
	push	hl
	push	de
	push	bc
	push	de
	push	hl
	call	A5079
	ld	a,l
	pop	hl
	pop	de
	; switch
	cp	33h
	jr	z,A3761
	cp	35h
	jr	z,A3761
	cp	32h
	jp	z,A37CA
	cp	34h
	jp	z,A3846
	cp	3Dh
	jp	z,A3856
	jp	A3877			; default
	;
A3761:	ld	hl,2
	add	hl,de
	; switch
	ld	a,(hl)
	cp	9
	jr	z,A378C
	cp	0Ah
	jr	z,A378C
	cp	0Dh
	jr	z,A378C
	cp	0Bh
	jr	z,A378C
	cp	0Ch
	jr	z,A378C
	cp	1
	jr	z,A379F
	cp	8
	jr	z,A379F
	jr	A37CA			; default
	;
A378C:	call	A758A
	push	hl
	ld	bc,T3881
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ld	hl,(D78B2)
	jp	A387D
	;
A379F:	push	de
	call	A7584
	pop	de
	push	de
	call	A5079
	ld	a,l
	cp	33h
	jr	nz,A37B3
	ld	a,9
	jr	A37B5
	;
A37B3:	ld	a,0Ah
A37B5:	pop	bc
	ld	de,0
	call	A1D2E
	push	hl
	call	A7584
	call	A5082
	pop	de
	call	A3735
	jp	A387D
	;
A37CA:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	9
	jr	z,A37DE
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	0Ah
	jr	nz,A37F1
A37DE:	call	A758A
	push	hl
	ld	bc,T3884
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ld	hl,(D78B2)
	jp	A387D
	;
A37F1:	push	de
	call	A7584
	pop	de
	push	hl
	push	hl
	ld	hl,6
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	call	A508D
	push	hl
	ld	hl,6
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ld	a,l
	cpl
	ld	e,a
	ld	a,h
	cpl
	ld	d,a
	inc	de
	ld	a,0Dh
	call	A1D2E
	call	A7553
	ld	bc,7
	add	hl,bc
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	call	A7590
	call	A755F
	call	A24DA
	pop	hl
	call	A5082
	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	call	A3735
	jr	A387D
	;
A3846:	push	hl
	ld	bc,T3887		;"YK"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ld	hl,(D78B2)
	jr	A387D
	;
A3856:	push	hl
	ld	c,e
	ld	b,d
	ld	de,0
	ld	a,8
	call	A1D2E
	call	A755F
	pop	hl
	call	A5082
	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	call	A3735
	jr	A387D
	;
A3877:	ld	hl,T388A		; "ga"
	jp	A4F27
	;
A387D:	pop	bc
	pop	bc
	pop	bc
	ret



A388D:	call	A161E
	call	A38C8
	ld	a,(D77FB)
	cp	48h
	jp	z,A4487
	cp	8
	jp	z,A4487
	cp	32h
	jp	z,A4487
	cp	34h
	jp	z,A4487
	ld	hl,0			; false?
	ret


A38AE:	ld	de,(D77F7)		; номер колонки
	ld	hl,(D77F9)		; номер строки
	push	af
	call	A4FF1
	ex	de,hl
	ld	hl,L0000
	call	A4FF1
	ex	de,hl
	pop	hl
	ld	l,h
	ld	h,0
	jp	A4FF1


A38C8:	call	A1651
	cp	18h
	jr	nz,A3902
	call	A1651
	cp	20h
	jr	nz,A38DC
	ld	a,34h
	ld	(D77FB),a
	ret
A38DC:	call	A5ED5
	ld	(D77FD),hl
	ld	a,(D77FB)
	cp	20h
	jr	z,A38FC
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T3906		; 'X"]" E'
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A38FC:	ld	a,32h
	ld	(D77FB),a
	ret
A3902:	ld	a,(D77FB)
	ret


A390D:	call	A3639
	xor	a
	ld	(D7A0D),a
	;ld	hl,0
	ld	l,a
	ld	h,a
	ld	(D7A11),hl
	call	A161E
	call	A38C8
	jp	A430C


A3923:	ld	a,(D77FB)
	dec	a
	jr	nz,A393A
	ld	hl,(D77FD)
	call	A522C
	ld	a,l
	or	h
	ret	z
	push	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	pop	hl
	cp	64h
	ret	z
A393A:	ld	hl,0			; false?
	ret


A393E:	ld	a,(D77FB)
	cp	0D0h
	jr	c,A3962
	cp	0DEh
	jr	c,A3964
	cp	0EDh
	jr	z,A3964
	cp	0EEh
	jr	z,A3964
	cp	0EFh
	jr	z,A3964
	cp	0F1h
	jr	z,A3964
	cp	0F2h
	jr	z,A3964
	cp	0F3h
	jr	z,A3964
A3962:	xor	a			; false
	ret
A3964:	ld	a,true
	ret


A3967:	push	ix
	ld	hl,-16
	add	hl,sp
	ld	sp,hl
	push	hl
	pop	ix
	xor	a
	ld	(ix+12),a
	ld	(ix+13),a
	ld	(ix+14),a
	ld	(ix+15),a
A397E:	ld	a,(ix+14)
	or	a
	jr	z,A398E
	ld	a,(ix+12)
	or	(ix+13)
	jp	nz,A3C1E
A398E:	ld	l,(ix+12)
	ld	h,(ix+13)
	ld	a,l
	or	h
	jr	nz,A39B6
	push	ix
	call	A3923
	pop	ix
	ld	a,l
	or	h
	jr	z,A39B6
	ld	a,0DEh
	ld	(D77FB),a
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D77FD),hl
	jr	A39C1
	;
A39B6:	push	ix
	call	A393E
	pop	ix
	or	a
	jp	z,A3C1E
A39C1:	ld	a,(D77FB)
	cp	0EEh
	jr	z,A39CD
	cp	0EFh
	jr	nz,A39EF
A39CD:	cp	0EEh
	jr	nz,A39D5
	ld	l,1
	jr	A39D7
	;
A39D5:	ld	l,2
A39D7:	ld	(ix+15),l
	ld	hl,(D77F9)		; номер строки
	ld	(ix+8),l
	ld	(ix+9),h
	ld	hl,(D77F7)		; номер колонки
	ld	(ix+10),l
	ld	(ix+11),h
	jp	A3C14
	;
A39EF:	ld	a,(D77FB)
	cp	0F1h
	jr	z,A39FF
	cp	0F2h
	jr	z,A39FF
	cp	0D5h
	jp	nc,A3A7B
A39FF:	ld	a,(ix+14)
	or	a
	jr	z,A3A1F
	push	ix
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T3C8A
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	ix
	jp	A3C14
	;
A3A1F:	ld	hl,(D77F9)		; номер строки
	pop	de
	push	hl
	ld	hl,(D77F7)		; номер колонки
	ld	(ix+2),l
	ld	(ix+3),h
	; switch
	ld	a,(D77FB)
	cp	0D0h
	jr	z,A3A4A
	cp	0D3h
	jr	z,A3A51
	cp	0D1h
	jr	z,A3A58
	cp	0F1h
	jr	z,A3A66
	cp	0F2h
	jr	z,A3A5F
	cp	0D2h
	jr	z,A3A6D
	jr	A3A74			; default
	;
A3A4A:	ld	a,41h
	jr	A3A76
	;
A3A51:	ld	a,72h
	jr	A3A76
	;
A3A58:	ld	a,54h
	jr	A3A76
	;
A3A5F:	ld	a,76h
	jr	A3A76
	;
A3A66:	ld	a,4Bh
	jr	A3A76
	;
A3A6D:	ld	a,47h
	jr	A3A76
	; default
A3A74:	ld	a,64h
A3A76:	ld	(ix+14),a
	jp	A3C14
	;
A3A7B:	ld	l,(ix+12)
	ld	h,(ix+13)
	ld	a,l
	or	h
	jr	z,A3A9F
	push	ix
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T3C9B
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	ix
	jp	A3C14
	;
A3A9F:	ld	hl,(D77F9)		; номер строки
	ld	(ix+4),l
	ld	(ix+5),h
	ld	hl,(D77F7)		; номер колонки
	ld	(ix+6),l
	ld	(ix+7),h
	; switch
	ld	a,(D77FB)
	cp	0F3h
	jp	z,A3B59
	cp	0D7h
	jr	z,A3B01
	cp	0D5h
	jr	z,A3B1D
	cp	0DEh
	jr	z,A3B29
	cp	0D6h
	jr	z,A3AF3
	cp	0D9h
	jr	z,A3B35
	cp	0D8h
	jp	z,A3BB4
	cp	0DAh
	jp	z,A3BDF
	cp	0DBh
	jp	z,A3BF4
	cp	0DCh
	jp	z,A3C07
	cp	0DDh
	jp	z,A3C07
	cp	0EDh
	jr	z,A3B0D
	jp	A3C14			; default
	;
A3AF3:	push	ix
	call	A1651
	cp	0D7h
	jr	z,A3AFF
	call	A161E
A3AFF:	pop	ix
A3B01:	ld	hl,(D78B2)
	jr	A3B2C
	;
A3B0D:	ld	hl,(D77DF)
	ld	bc,108			; 006Ch
	add	hl,bc
	jr	A3B2C
	;
A3B1D:	ld	hl,(D78B4)
	jr	A3B2C
	;
A3B29:	ld	hl,(D77FD)
A3B2C:	ld	(ix+12),l
	ld	(ix+13),h
	jp	A3C14
	;
A3B35:	push	ix
	call	A1651
	pop	ix
	cp	0D5h			; токен ?
	jr	z,A3B1D
	cp	0D7h
	jr	z,A3B87
	cp	0D6h
	jr	z,A3B79
	cp	0D8h
	jr	z,A3B93
	push	ix
	call	A161E
	pop	ix
	jr	A3B87
	;
A3B59:	push	ix
	call	A1651
	pop	ix
	cp	0D7h
	jr	z,A3B01
	cp	0D6h
	jr	z,A3AF3
	cp	0D8h
	jr	z,A3BB4
	push	ix
	call	A161E
	pop	ix
	jr	A3B01
	;
A3B79:	push	ix
	call	A1651
	cp	0D7h
	jr	z,A3B85
	call	A161E
A3B85:	pop	ix
A3B87:	ld	hl,(D78B0)
	jr	A3B2C
	;
A3B93:	push	ix
	call	A1651
	cp	0D7h
	jr	z,A3B9F
	call	A161E
A3B9F:	pop	ix
	ld	bc,72			; 0048h
	jr	A3BF7
	;
A3BB4:	push	ix
	call	A1651
	cp	0DAh
	jr	z,A3BF2
	cp	0DBh
	jr	z,A3BF2
	cp	0D7h
	jr	z,A3BCA
	call	A161E
A3BCA:	pop	ix
	ld	bc,81			; 0051h
	jr	A3BF7
	;
A3BDF:	ld	bc,90			; 005Ah
	jr	A3BF7
	;
A3BF2:	pop	ix
A3BF4:	ld	bc,99			; 0063h
A3BF7:	ld	hl,(D77DF)
	add	hl,bc
	ld	(ix+12),l
	ld	(ix+13),h
	call	A3CAD
	jr	A3C14
	;
A3C07:	push	ix
	call	A3F00
	pop	ix
	ld	(ix+12),l
	ld	(ix+13),h
A3C14:	push	ix
	call	A1651
	pop	ix
	jp	A397E


A3C1E:	ld	l,(ix+12)
	ld	h,(ix+13)
	ld	(D78F3),hl
	ld	a,(ix+14)
	cp	76h
	jr	nz,A3C2F
	xor	a
A3C2F:	ld	(D7A06),a
	ld	a,(ix+15)
	ld	(D78F5),a
	pop	hl
	push	hl
	ld	(D78F7),hl
	ld	l,(ix+4)
	ld	h,(ix+5)
	ld	(D78FB),hl
	ld	l,(ix+8)
	ld	h,(ix+9)
	ld	(D7A22),hl
	ld	l,(ix+2)
	ld	h,(ix+3)
	ld	(D78F9),hl
	ld	l,(ix+6)
	ld	h,(ix+7)
	ld	(D78FD),hl
	ld	l,(ix+10)
	ld	h,(ix+11)
	ld	(D7A24),hl
	ld	hl,(D78F3)
	ld	a,l
	or	h
	jr	nz,A3C7D
	ld	a,(D7A06)
	or	a
	jr	nz,A3C7D
	ld	a,(D78F5)
	or	a
	jr	z,A3C81
A3C7D:	ld	a,1			; true ?
	jr	A3C82
	;
A3C81:	xor	a			; false ?
A3C82:	ld	hl,16
	add	hl,sp
	ld	sp,hl
	pop	ix
	ret


A3CAD:	ld	a,(D790C)		; флаг типа long/float/double
	or	a
	ret	z			; false
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	hl,T3CC5		; "long/float/double" не поддерж.
	push	hl
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret


A3CDB:	ld	a,(D77FB)
	cp	0DFh
	jp	z,A5388
	call	A3967
	ld	a,(D78F5)
	or	a
	jr	z,A3CFE
	ld	hl,(D7A24)
	push	hl
	ld	hl,(D7A22)
	push	hl
	ld	bc,T3D74
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A3CFE:	ld	hl,(D78F3)
	ld	a,l
	or	h
	jr	nz,A3D0C
	ld	hl,(D78B2)
	ld	(D78F3),hl
A3D0C:	ld	a,(D7A06)
	cp	72h
	jr	z,A3D2C
	cp	4Bh
	jr	z,A3D2C
	or	a
	jr	z,A3D2C
	ld	hl,(D78F9)
	push	hl
	ld	hl,(D78F7)
	push	hl
	ld	bc,T3D77
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A3D2C:	ld	a,(D77FB)
	cp	0C8h
	jr	nz,A3D3A
	call	A1651
	jr	A3CDB
	;
A3D3A:	ld	hl,(D76DB)
	push	hl
	call	A390D
	push	hl
	ld	de,(D78F3)
	call	A5749
	pop	de
	ld	hl,(D7A11)
	ld	a,l
	or	h
	jr	nz,A3D58
	ld	hl,(D78F3)
	ex	de,hl
	call	A25F2
A3D58:	pop	hl
	ld	(D76DB),hl
	ld	a,(D77FB)
	cp	0B8h
	jr	nz,A3D69
	call	A1651
	jr	A3D3A
	;
A3D69:	ld	de,T3D7A
	ld	a,0C8h
	call	A54CE
	jp	A3CDB


A3D7C:	call	A3967
	or	a
	ret	z
	ld	a,(D78F5)
	or	a
	jr	z,A3D99
	ld	hl,(D7A24)
	push	hl
	ld	hl,(D7A22)
	push	hl
	ld	bc,T3EDB
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A3D99:	ld	hl,(D78F3)
	ld	a,l
	or	h
	jr	nz,A3DA6
	ld	hl,(D78B2)
	ld	(D78F3),hl
A3DA6:	ld	a,(D7A06)
	cp	72h
	jr	nz,A3DB2
	ld	a,41h
	ld	(D7A06),a
A3DB2:	ld	a,(D77FB)
	cp	0C8h
	jr	nz,A3DBF
	call	A1651
	jr	A3D7C
	;
A3DBF:	ld	hl,(D76DB)
	ld	(D7903),hl
	call	A390D
	push	hl
	ld	de,(D78F3)
	call	A5749
	pop	de
	ld	hl,(D7A11)
	ld	a,l
	or	h
	jr	nz,A3DE6
	xor	a
	ld	(D7907),a
	ld	hl,(D78F3)
	ex	de,hl
	call	A2269
	ld	(D7905),hl
A3DE6:	ld	a,(D77FB)
	cp	0A8h
	jp	nz,A3E92
	call	A1651
	ld	de,(D77F9)		; номер строки
	ld	hl,(D77F7)		; номер колонки
	ld	a,(D7A06)
	cp	41h
	jr	z,A3E03
	or	a
	jr	nz,A3E7E
A3E03:	xor	a
	ld	(D79FF),a
	ld	(D7901),hl
	push	de
	push	hl
	ex	de,hl
	ld	(D78FF),hl
	call	A3640
	push	hl
	ld	hl,(D7905)
	ld	bc,5
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D7908),de
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	ld	hl,(D7901)
	ld	bc,(D78FF)
	dec	a
	jr	z,A3E3C
	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	8
	jr	nz,A3E4E
A3E3C:	ld	hl,(D7905)
	push	hl
	call	A25B4
	pop	hl
	push	hl
	ld	bc,T3EDE
	push	bc
	call	A4ABC
	jr	A3E58
	;
A3E4E:	push	hl
	push	bc
	ld	bc,T3EE2
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
A3E58:	pop	bc
	pop	bc
	pop	hl
	call	A36A1
	pop	de
	pop	bc
	ld	a,l
	or	h
	jp	z,A3ED0
	push	de
	ex	de,hl
	ld	hl,(D7908)
	call	A636C
	pop	bc
	ld	hl,(D7908)
	push	hl
	ld	bc,T3EE5
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	jp	A3ED0
	;
A3E7E:	ld	a,(D7A06)
	cp	4Bh
	jr	z,A3E89
	cp	54h
	jr	nz,A3EA7
A3E89:	ld	hl,(D7905)
	call	A2EC8
	jr	A3EB6
	;
A3E92:	ld	a,(D7A06)
	cp	4Bh
	jr	nz,A3EB6
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T3EF0
	jr	A3EAC
	;
A3EA7:	push	hl
	push	de
	ld	bc,T3EEB
A3EAC:	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	call	A2A26
A3EB6:	ld	hl,(D7905)
	call	A25B4
	ld	hl,(D7903)
	ld	(D76DB),hl
	ld	a,(D77FB)
	cp	0B8h
	jr	nz,A3ED0
	call	A1651
	jp	A3DBF
	;
A3ED0:	ld	de,T3EEE
	ld	a,0C8h
	call	A54CE
	jp	A3D7C



A3F00:	push	bc
	push	bc
	push	bc
	push	bc
	ld	a,(D77FB)
	cp	0DCh
	jr	nz,A3F11
	ld	a,0Bh
	jr	A3F13
	;
A3F11:	ld	a,0Ch
A3F13:	ld	hl,0
	add	hl,sp
	ld	(hl),a
	push	af
	call	A1651
	pop	de
	ld	e,d
	dec	a
	jp	nz,A3FEF
	ld	hl,0
	add	hl,sp
	ld	a,(hl)
	cp	0Bh
	jr	nz,A3F31
	ld	a,24h
	jr	A3F33
	;
A3F31:	ld	a,23h
A3F33:	ld	hl,(D77FD)
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	call	A085F
	call	A7565
	push	hl
	call	A1651
	pop	hl
	cp	0DFh
	jr	nz,A3FAE
	call	A5255
	ld	c,l
	ld	b,h
	ld	a,c
	or	b
	jr	z,A3F5B
	ld	hl,7
	add	hl,bc
	ld	a,(hl)
	or	a
	jp	z,A407B
A3F5B:	ld	a,c
	or	b
	jr	z,A3F81
	call	A7596
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	push	bc
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T4153
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	hl,0
	call	A7565
A3F81:	call	A7596
	call	A527D
	ld	c,l
	ld	b,h
	ld	hl,2
	add	hl,bc
	push	hl
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	pop	hl
	ld	(hl),a
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ex	de,hl
	ld	hl,3
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,7
	add	hl,bc
	ld	(hl),0
	jp	A407B
	;
A3FAE:	push	hl
	call	A161E
	pop	hl
	call	A522C
	ld	a,l
	or	h
	jp	nz,A414E
	call	A7596
	call	A527D
	call	A7559
	push	hl
	inc	hl
	inc	hl
	push	hl
	ld	hl,4
	add	hl,sp
	ld	a,(hl)
	pop	hl
	ld	(hl),a
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ex	de,hl
	push	de
	call	A757E
	pop	de
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	push	hl
	ld	bc,7
	add	hl,bc
	ld	(hl),0
	pop	hl
	jp	A414E
	;
A3FEF:	ld	a,(D77FB)
	cp	0DFh
	jr	nz,A401F
	push	de
	ld	hl,0
	call	A527D
	ld	c,l
	ld	b,h
	ld	hl,2
	add	hl,bc
	pop	de
	ld	(hl),e
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ex	de,hl
	ld	hl,3
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,7
	add	hl,bc
	ld	(hl),0
	jr	A407B
	;
A401F:	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T415D
	push	bc
	ld	hl,3
	push	hl
	ld	hl,8
	add	hl,sp
	ld	(hl),e
	pop	hl
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,0
	call	A527D
	ex	de,hl
	ld	hl,2
	add	hl,de
	push	hl
	ld	hl,5
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	push	de
	push	hl
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	pop	hl
	ld	(hl),e
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	push	hl
	ld	hl,7
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,3
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	de
	ld	hl,7
	add	hl,de
	ld	(hl),0
	ex	de,hl
	jp	A414E
	;
A407B:	ld	hl,(D790A)
	push	bc
	call	A7547
	ld	hl,0
	ld	(D790A),hl
	call	A1651
A408B:	call	A3967
	or	a
	jp	z,A4115
	ld	a,(D78F5)
	or	a
	jr	z,A40AA
	ld	hl,(D7A24)
	push	hl
	ld	hl,(D7A22)
	push	hl
	ld	bc,T4163		; "XO"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A40AA:	ld	a,(D7A06)
	or	a
	jr	z,A40C3
	ld	hl,(D78F9)
	push	hl
	ld	hl,(D78F7)
	push	hl
	ld	bc,T4166		; "XT"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A40C3:	ld	hl,(D78F3)
	ld	a,l
	or	h
	jr	nz,A40D1
	ld	hl,(D78B2)
	ld	(D78F3),hl
A40D1:	ld	a,(D77FB)
	cp	0C8h
	jr	z,A410A
A40D9:	ld	hl,(D76DB)
	push	hl
	call	A390D
	push	hl
	ld	de,(D78F3)
	call	A5749
	pop	de
	ld	hl,(D7A11)
	ld	a,l
	or	h
	jr	nz,A40F8
	ld	hl,(D78F3)
	ex	de,hl
	call	A27B2
A40F8:	pop	hl
	ld	(D76DB),hl
	ld	a,(D77FB)
	cp	0B8h
	jr	nz,A410A
	call	A1651
	jr	A40D9
	;
A410A:	ld	de,T4169
	ld	a,0C8h
	call	A54CE
	jp	A408B
	;
A4115:	ld	a,(D77FB)
	cp	0E0h
	jr	z,A412F
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T416B
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A412F:	ld	de,(D790A)
	pop	bc
	ld	hl,5
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,7
	add	hl,bc
	ld	(hl),1
	ld	l,c
	ld	h,b
	push	bc
	call	A29BD
	call	A757E
	ld	(D790A),hl
	pop	hl
A414E:	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret



A4171:	ld	a,(D77FB)
	dec	a
	jr	z,A419B
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T41AD		; "XMidentifier"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,-1
	ld	(D7A11),hl
	ld	a,1
	call	A38AE
	ld	de,T41BA
	jp	A501B
	;
A419B:	ld	a,1
	call	A38AE
	ld	de,(D77FD)
	call	A501B
	push	hl
	call	A38C8
	pop	hl
	ret


T41BA:	db	0


A41BB:	push	bc
	call	A4171
A41BF:	ld	a,(D77FB)
	cp	0B8h
	jr	nz,A41DF
	ld	a,0B8h
	pop	de
	push	hl
	call	A38AE
	push	hl
	call	A38C8
	call	A4171
	ld	c,l
	ld	b,h
	pop	hl
	pop	de
	push	de
	call	A5028
	jr	A41BF
A41DF:	pop	bc
	ret


A41E1:	push	bc
	ld	a,(D77FB)
	cp	8
	jr	nz,A421B
	call	A38C8
	call	A430C
	pop	de
	push	hl
	ld	a,(D77FB)
	cp	10h
	jr	z,A4215
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T4305		; X")" E
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,-1
	ld	(D7A11),hl
	jp	A4220
	;
A4215:	call	A38C8
	jr	A4220
	;
A421B:	call	A4171
	pop	de
	push	hl
A4220:	ld	a,(D77FB)
	cp	34h
	jr	nz,A4238
	call	A38AE
	push	hl
	call	A7590
	ex	de,hl
	pop	hl
	call	A501B
	pop	de
	push	hl
	jp	A42FD
	;
A4238:	ld	a,(D77FB)
	cp	32h
	jr	nz,A4258
	ld	a,32h
	call	A38AE
	push	hl
	call	A7590
	ex	de,hl
	ld	bc,(D77FD)
	pop	hl
	call	A5028
	pop	de
	push	hl
	jp	A42FD
	;
A4258:	ld	a,(D77FB)
	cp	8
	jp	nz,A42FB
	pop	hl
	push	hl
	push	hl
	call	A5079
	ld	a,l
	dec	a
	or	h
	jr	nz,A4271
	ld	a,1
	ld	(D7A0D),a
A4271:	call	A38C8
	pop	de
	cp	29h
	jr	nz,A42AC
	push	de
	ld	a,35h
	call	A38AE
	pop	de
	ld	bc,0
	call	A5028
	pop	de
	push	hl
	call	A38C8
	cp	10h
	jr	z,A42FD
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T4305		; X")" E
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,-1
	ld	(D7A11),hl
	jp	A4220
	;
A42AC:	ld	a,33h
	push	de
	call	A38AE
	ld	a,(D77FB)
	pop	de
	cp	10h
	jr	nz,A42C6
	ld	bc,0
	call	A5028
	pop	de
	push	hl
	jr	A42FD
	;
A42C6:	pop	bc
	push	de
	push	hl
	call	A41BB
	ld	c,l
	ld	b,h
	call	A7590
	ex	de,hl
	pop	hl
	call	A5028
	pop	de
	push	hl
	ld	a,(D77FB)
	cp	10h
	jr	z,A42FD
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T4305		; X")" E
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,-1
	ld	(D7A11),hl
	jp	A4220
	;
A42FB:	pop	hl
	ret
A42FD:	call	A38C8
	jp	A4220



A430C:	ld	a,(D77FB)
	cp	48h
	jp	nz,A41E1
	ld	a,3Dh
	call	A38AE
	push	hl
	call	A38C8
	call	A430C
	ex	de,hl
	pop	hl
	jp	A501B


A4325:	push	hl
	ld	a,(D77FB)
	cp	34h
	jr	nz,A433A
	ld	a,34h
	push	hl
	call	A38AE
	pop	de
	call	A501B
	jp	A43DA
	;
A433A:	ld	a,(D77FB)
	cp	32h
	jr	nz,A435B
	ld	a,32h
	pop	de
	push	hl
	call	A38AE
	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	bc,(D77FD)
	pop	hl
	call	A5028
	jr	A43DA
	;
A435B:	ld	a,(D77FB)
	cp	8
	jr	nz,A43C5
	push	hl
	call	A38C8
	pop	de
	cp	10h
	jr	nz,A437C
	push	de
	ld	a,33h
	call	A38AE
	pop	de
	ld	bc,0
	call	A5028
	jr	A43DA
	;
A437C:	ld	a,(D77FB)
	cp	29h
	jr	nz,A43B0
	ld	a,35h
	push	de
	call	A38AE
	pop	de
	ld	bc,0
	call	A5028
	push	hl
	call	A38C8
	pop	hl
	cp	10h
	jr	z,A43DA
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T4305		; X")" E
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A43E2
	;
A43B0:	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T4305		; X")" E
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A43E2
	;
A43C5:	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T43F8		; "XBabstract declarator"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A43E2
	;
A43DA:	push	hl
	call	A38C8
	pop	hl
	jr	A43F6
	;
A43E2:	ld	hl,-1
	ld	(D7A11),hl
	ld	a,33h
	call	A38AE
	ld	de,0
	ld	c,e
	ld	b,d
	call	A5028
A43F6:	pop	bc
	ret


A440E:	ld	hl,0
	ld	a,(D77FB)
	cp	8
	jr	nz,A446A
	push	hl
	call	A38C8
	pop	hl
	cp	10h
	jr	z,A445B
	call	A4487
	ld	a,(D77FB)
	push	hl
	cp	10h
	jr	z,A4447
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T4480		; X")" E
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,-1
	ld	(D7A11),hl
A4447:	call	A38C8
	pop	hl
	cp	32h
	jr	z,A446A
	ld	a,(D77FB)
	cp	34h
	jr	z,A446A
	cp	8
	jr	z,A446A
	ret
A445B:	push	hl
	call	A161E
	ld	a,8
	ld	(D77FB),a
	pop	hl
	push	hl
	call	A4325
	pop	hl
A446A:	ld	a,(D77FB)
	cp	34h
	jr	z,A447A
	cp	32h
	jr	z,A447A
	cp	8
	ret	nz
A447A:	call	A4325
	jr	A446A


A4487:	ld	a,(D77FB)
	cp	48h
	jp	nz,A440E
	ld	a,3Dh
	call	A38AE
	push	hl
	call	A38C8
	call	A4487
	ex	de,hl
	pop	hl
	jp	A501B


A44A0:	push	hl
	ld	hl,(D79E1)
	add	hl,de
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T790E
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ex	de,hl
	call	A4FF1
	ex	de,hl
	ld	hl,L0000
	call	A4FF1
	ex	de,hl
	pop	hl
	jp	A4FF1


A44C9:	ld	l,a
	ld	h,0
	ld	de,1
	call	A44A0
	push	hl
	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7919		; ds 6
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	jp	A501B


A44E9:	ld	de,2
	call	A44A0
	push	hl
	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7919		; ds 6
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	bc,13
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	jp	A5028


A450D:	ld	l,a
	ld	h,0
	ld	de,1
	call	A44A0
	push	hl
	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7920		; ds 7
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	jp	A501B


A452D:	ld	l,a
	ld	h,0
	ld	de,2
	call	A44A0
	push	hl
	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7919		; ds 6
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	jp	A501B



T454D:	db	1,3,2,4,5,6
T4553:	db	"89:;<=>?"		; 38h,39h,3Ah,3Bh,3Ch,3Dh,3Eh,3Fh

T455B:	db	0C1h,"*"
	db	0C1h,"/"
	db	0C1h,"%"
	db	0C1h,"+"
	db	0C1h,"-"
	db	0C4h,"r"
	db	0C4h,"l"
	db	0C2h,"<"
	db	0C2h,"["
	db	0C2h,">"
	db	0C2h,"]"
	db	0C2h,"="
	db	0C2h,"!"
	db	0C1h,"&"
	db	0C1h,"^"
	db	0C1h,"|"
	db	0C3h,"m"
	db	0C3h,"s"
	;
T457F:	db	0C5h,":"
	db	0C5h,"+"
	db	0C5h,"-"
	db	0C5h,"*"
	db	0C5h,"/"
	db	0C5h,"%"
	db	0C5h,"r"
	db	0C5h,"l"
	db	0C5h,"&"
	db	0C5h,"^"
	db	0C5h,"|"
	db	0B8h,0



T45B0:	cp	7
	jr	z,A45EE
	jr	nc,A45C3
	dec	a
	ld	l,a
	ld	h,0
	ld	bc,T454D		; 1,3,2,4,5,6
	add	hl,bc
	ld	a,(hl)
	jp	A44C9
	;
A45C3:	cp	8
	jr	z,A4609
	cp	9
	jr	z,A45F4
	cp	0Ah
	jp	z,A4641
	cp	0Bh
	jp	z,A4641
	cp	0Ch
	jr	z,A45FA
	cp	0Dh
	jr	z,A45FF
	cp	0Eh
	jr	z,A4604
	cp	17h
	jp	z,A46F0
	cp	2Ah
	jp	z,A4719
	jp	A4755
	;
A45EE:	ld	hl,L0029
	jp	A44E9
	;
A45F4:	ld	hl,L0032
	jp	A44E9
	;
A45FA:	ld	a,8
	jp	A450D
	;
A45FF:	ld	a,30h
	jp	A452D
	;
A4604:	ld	a,31h
	jp	A452D
	;
A4609:	ld	de,2
	ld	hl,L003D
	call	A44A0
	push	hl
	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7919		; ds 6
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	(sp),hl
	call	A501B
	push	hl
	ld	de,2
	ld	hl,L0029
	call	A44A0
	pop	de
	pop	bc
	push	hl
	ld	hl,13
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	jp	A5028
	;
A4641:	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7919		; ds 6
	add	hl,bc
	push	af
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D79E3),hl
	call	A5079
	ld	a,l
	dec	a
	or	h
	jp	nz,A46BF
	ld	hl,(D79E3)
	call	A5082
	push	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	pop	hl
	cp	75h			; токен "undeclared"
	jr	nz,A46BF
	; если функция не определена
	push	hl
	ld	a,(mode)		; Свой режим компилятора  (1-я ячейка)
	or	a
	jr	z,A46A4			; режим K&R совместимости
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T791F		; db 0 : ds 7
	add	hl,bc
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	dec	hl
	push	de			; de=номер колонки
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	push	de			; de=номер строки в файле
	ld	bc,T4597		; 'Xundeclared function "S"'
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
A46A4:	pop	hl
	push	hl
	inc	hl
	inc	hl
	ld	(hl),58h		; "X"
	ld	bc,(D78B2)
	ld	de,0
	ld	a,9
	call	A1D2E
	ex	de,hl
	pop	hl
	ld	bc,5
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
A46BF:	pop	af
	cp	0Ah
	jr	nz,A46DB
	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7927
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A46DE
	;
A46DB:	ld	hl,0
A46DE:	push	hl
	ld	de,2
	ld	hl,L0033
	call	A44A0
	ld	de,(D79E3)
	pop	bc
	jp	A5028
	;
A46F0:	ld	de,1
	ld	hl,L0040
	call	A44A0
	push	hl
	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7919		; ds 6
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	ld	bc,6
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	de
	pop	hl
	jp	A5028
	;
A4719:	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7935
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	ld	de,2
	ld	hl,L0098
	call	A44A0
	push	hl
	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7919		; ds 6
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	bc,13
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	call	A503C
	pop	bc
	ret
A4755:	cp	17h
	jr	nc,A4767
	sub	0Fh
	ld	l,a
	ld	h,0
	ld	bc,T4553		; "89:;<=>?"
	add	hl,bc
	ld	a,(hl)
	jp	A450D
	;
A4767:	cp	2Ah			; *
	jr	nc,A477D
	sub	18h
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,T455B		; массив
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jp	A44E9
	;
A477D:	cp	37h
	jp	nc,abort		; выход в ДОС
	sub	2Bh
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,T457F
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jp	A44E9



T4796:	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7919		; ds 6
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	ld	bc,6
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	bc,6
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	; switch
	cp	3
	ret	z
	cp	2
	jp	z,A485C
	cp	4
	ret	z
	cp	0Ch
	jp	z,A4868
	cp	11h
	jp	z,A486A
	cp	13h
	jp	z,A4872
	cp	17h
	jp	z,A4868
	cp	18h
	jp	z,A4879
	cp	19h
	jp	z,A487E
	cp	1Ah
	jp	z,A4883
	cp	1Bh
	jp	z,A488A
	cp	1Ch
	jp	z,A488C
	cp	1Dh
	jp	z,A4890
	cp	1Eh
	jp	z,A4894
	cp	1Fh
	jp	z,A4898
	cp	20h
	jp	z,A48A7
	cp	21h
	jp	z,A48B6
	cp	22h
	jp	z,A48C5
	cp	23h
	jp	z,A48D4
	cp	24h
	jp	z,A48E6
	cp	25h
	jp	z,A48F8
	cp	26h
	jp	z,A48FF
	cp	27h
	jp	z,A4906
	cp	2Ah
	jp	z,A490D
	cp	1
	jp	z,A4929
	cp	5
	jp	z,A4929
	cp	6
	jp	z,A4929
	cp	0Fh
	jp	z,A4929
	cp	10h
	jp	z,A4929
	cp	12h
	jp	z,A4929
	cp	14h
	jp	z,A4929
	cp	15h
	jp	z,A4929
	cp	16h
	jp	z,A4929
	jp	A494F			; default
	;
A485C:	ld	a,(hl)
	cp	25h
	jp	nz,A4929
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret
A4868:	ex	de,hl
	ret

	; neg hl
A486A:	ld	a,e
	cpl
	ld	l,a
	ld	a,d
	cpl
	ld	h,a
	inc	hl
	ret

	; cpl hl
A4872:	ld	a,e
	cpl
	ld	l,a
	ld	a,d
	cpl
	ld	h,a
	ret

A4879:	ld	e,c
	ld	d,b
	jp	A752D

A487E:	ld	e,c
	ld	d,b
	jp	A750B

A4883:	call	A487E
	ex	de,hl
	ret

A488A:	add	hl,bc
	ret

A488C:	or	a
	sbc	hl,bc
	ret

A4890:	ld	b,c
	jp	A74FA

A4894:	ld	b,c
	jp	A7504

A4898:	ld	a,l
	sub	c
	ld	a,h
	sbc	a,b
	jr	nc,.loc1
	ld	hl,true
	ret
.loc1:	ld	hl,false
	ret

A48A7:	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jr	c,.loc1
	ld	hl,true
	ret
.loc1:	ld	hl,false
	ret

A48B6:	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jr	nc,.loc1
	ld	hl,true
	ret
.loc1:	ld	hl,false
	ret

A48C5:	ld	a,l
	sub	c
	ld	a,h
	sbc	a,b
	jr	c,.loc1
	ld	hl,true
	ret
.loc1:	ld	hl,false
	ret

A48D4:	ld	a,l
	cp	c
	jr	nz,.loc1		; модерн. переходы
	ld	a,h
	cp	b
	jr	nz,.loc1
	ld	hl,true
	ret
.loc1:	ld	hl,false
	ret

A48E6:	ld	a,l
	cp	c
	jr	nz,.loc1		; модерн. переходы
	ld	a,h
	cp	b
	jr	z,.loc2
.loc1:	ld	hl,true
	ret
.loc2:	ld	hl,false
	ret

A48F8:	ld	a,l
	and	c
	ld	l,a
	ld	a,h
	and	b
	ld	h,a
	ret

A48FF:	ld	a,l
	xor	c
	ld	l,a
	ld	a,h
	xor	b
	ld	h,a
	ret

A4906:	ld	a,l
	or	c
	ld	l,a
	ld	a,h
	or	b
	ld	h,a
	ret

A490D:	ld	a,l
	or	h
	jr	z,A4915
	ld	l,c
	ld	h,b
	ret
A4915:	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7935
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret

A4929:	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T7918		; db 0 : ds 6
	add	hl,bc
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	push	de
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	push	de
	ld	bc,T4975		; "XBconstant expression"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,1			; true?
	ret
	; default
A494F:	ld	hl,(D79E1)
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,T791F		; db 0 : ds 7
	add	hl,bc
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	push	de
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	push	de
	ld	bc,T4975		; "XBconstant expression"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,1			; true?
	ret



; вывод "a" в файл (и на экран ?)
A498B:	ld	(D79ED),a
	ld	a,(D76C7)		; false/true флаг наличия ошибок компиляции
	or	a
	ret	nz
	ld	a,(D76C8)		; true/false
	or	a
	ret	z
	ld	a,(D79ED)
	ld	de,(D76C3) ;hl		; описатель .tmc файла ?
	;ex	de,hl
	push	ix
	call	A0572
	pop	ix
	ret


A49A7:	ld	a,(D76C7)		; false/true флаг наличия ошибок компиляции
	or	a
	ret	nz
	ld	a,(D76C8)		; true/false
	or	a
	ret	z
	ld	de,(D76C3)
	push	ix
	call	A052E			; записать строку "hl" в файл
	pop	ix
	ret


; Вывод в файл чисел в десят. формате
; вход: hl=число
A49BF:	ld	de,0
	ld	c,e
	ld	b,16			; счетчик
A49C5:	add	hl,hl
	ld	a,e
	adc	a,a
	daa
	ld	e,a
	ld	a,d
	adc	a,a
	daa
	ld	d,a
	ld	a,c
	adc	a,a
	daa
	ld	c,a
	djnz	A49C5
	ld	hl,T4A63		; "00000"
	ld	a,c
	call	A49F9
	ld	a,d
	call	A49F0
	ld	a,e
	call	A49F0
	ld	b,4
	ld	hl,T4A63		; "00000"
A49E8:	ld	a,(hl)
	cp	"0"
	ret	nz
	inc	hl
	djnz	A49E8
	ret
	; "a" в hex-формате
A49F0:	push	af
	rrca
	rrca
	rrca
	rrca
	call	A49F9
	pop	af
A49F9:	and	0Fh
	add	a,"0"
	ld	(hl),a
	inc	hl
	ret

T4A63:	db	"00000",0



A4A00:	ex	de,hl
	ld	a,(D76C7)		; false/true флаг наличия ошибок компиляции
	or	a
	ret	nz
	ld	hl,2
	add	hl,de
	; switch
	ld	a,(hl)
	cp	1
	jr	z,A4A2D
	cp	8
	jr	z,A4A39
	cp	0Bh
	jr	z,A4A3E
	cp	0Ch
	jr	z,A4A3E
	cp	0Dh
	jr	z,A4A3E
	cp	9
	jr	z,A4A5E
	cp	0Ah
	jr	z,A4A5E
	ld	hl,T4A78		; "tn"
	jp	A4F27			; default
	;
A4A2D:	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,A4A69		; $NICBNICZWQH
	add	hl,bc
	ld	a,(hl)
	jp	A498B
	;
A4A39:	ld	a,"R"			; 52h
	jp	A498B
	;
A4A3E:	sub	0Bh
	ld	l,a
	ld	h,0
	ld	bc,T4A75		; SUV
	add	hl,bc
	ld	a,(hl)
	push	de
	call	A498B
	pop	de
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A014D			; neg hl
	call	A49BF			; вывод в файл чисел в десят. формате
	jp	A49A7
	;
A4A5E:	ld	a,"C"			; 43h
	jp	A498B

A4A69:	db	"$NICBNICZWQH"
T4A75:	db	"SUV"


A4A7B:	ld	a,l
	or	h
	ret	z
	push	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	pop	hl
	cp	65h
	ret	z
	cp	4Bh
	jr	nz,A4A8C
	ld	a,"T"			; 54h
A4A8C:	push	hl
	call	A498B
	pop	de
	ld	hl,2
	add	hl,de
A4A95:	ld	a,(hl)
	cp	47h
	jr	z,A4AA2
	cp	58h
	jr	z,A4AA2
	cp	59h
	jr	nz,A4AAE
A4AA2:	ex	de,hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jp	A49A7
	;
A4AAE:	ld	hl,3
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	call	A49BF			; вывод в файл чисел в десят. формате
	jp	A49A7



; формат. вывод в файл ?
; вход: hl=форм.строка?
A4ABC:	pop	bc
	pop	hl
	push	hl
	push	bc
	ld	ix,4
	add	ix,sp
A4AC6:	ld	a,(hl)
	inc	hl
	or	a
	ret	z			; конец строки
	cp	"%"
	jp	nz,A4B69
	ld	a,(hl)
	inc	hl
	push	hl
	cp	"d"
	jr	z,A4AF3
	cp	"u"
	jr	z,A4B14
	cp	"t"
	jr	z,A4B26
	cp	"v"
	jr	z,A4B39
	cp	"s"
	jr	z,A4B4C
	cp	"c"
	jr	z,A4B5B
	jr	A4B62			; default
	; "d"
A4AF3:	bit	7,(ix+1)
	jr	z,A4AFE
	ld	a,"-"			; 2Dh
	call	A498B
A4AFE:	ld	l,(ix+0)
	inc	ix
	ld	h,(ix+0)
	inc	ix
	call	A014D			; neg hl
	call	A49BF			; вывод в файл чисел в десят. формате
	call	A49A7
	jr	A4B65
	; "u"
A4B14:	ld	l,(ix+0)
	inc	ix
	ld	h,(ix+0)
	inc	ix
	call	A49BF			; вывод в файл чисел в десят. формате
	call	A49A7
	jr	A4B65
	; "t"
A4B26:	ld	l,(ix+0)
	inc	ix
	ld	h,(ix+0)
	inc	ix
	push	ix
	call	A4A00
	pop	ix
	jr	A4B65
	; "v"
A4B39:	ld	l,(ix+0)
	inc	ix
	ld	h,(ix+0)
	inc	ix
	push	ix
	call	A4A7B
	pop	ix
	jr	A4B65
	; "s"
A4B4C:	ld	l,(ix+0)
	inc	ix
	ld	h,(ix+0)
	inc	ix
	call	A49A7
	jr	A4B65
	; "c"
A4B5B:	ld	a,(ix+0)
	inc	ix
	inc	ix
A4B62:	call	A498B
A4B65:	pop	hl
	jp	A4AC6
	;
A4B69:	push	hl
	call	A498B			; вывод "a" в файл ?
	pop	hl
	jp	A4AC6



A4DFB:	push	hl
	ld	bc,T4E06		; "Ytype mismatch"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ret


; Вывести статистику по занятости таблиц
info:	ld	bc,0
	ld	d,c
	ld	e,c
A4E1B:	ld	hl,(D77D7)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A4E3B
	ld	l,e
	ld	h,d
	add	hl,hl
A4E28:	add	hl,hl
	push	de
	ex	de,hl
	ld	hl,(D77DD)
	add	hl,de
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	z,A4E36
	inc	bc
A4E36:	pop	de
	inc	de
	jr	A4E1B
	;
A4E3B:	ld	hl,(D76D3)		; отношение размера пула
	push	hl
	ld	de,(D77E7)
	ld	hl,(D77E3)
	ld	a,e
	sub	l
	ld	l,a
	ld	a,d
	sbc	a,h
	ld	h,a
	push	hl
	ld	l,c
	ld	h,b
	ld	(D79EB),hl
	ld	bc,T4E9F		; "Pool:  N/N"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,(D76D5)		; отношение размера таблицы идентиф.
	push	hl
	ld	hl,(D77E5)
	ld	bc,9
	add	hl,bc
	ex	de,hl
	ld	hl,(D77DF)
	ld	a,e
	sub	l
	ld	c,a
	ld	a,d
	sbc	a,h
	ld	b,a
	ld	hl,(D77E1)
	add	hl,bc
	ex	de,hl
	ld	hl,(D79F9)
	ld	a,e
	sub	l
	ld	l,a
	ld	a,d
	sbc	a,h
	ld	h,a
	push	hl
	ld	bc,T4EA9		; "Symbol table:  N/N"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	hl,(D76D7)		; отношение размера хэш-таблицы
	push	hl			; hash N/..
	ld	hl,(D79EB)
	add	hl,hl
	add	hl,hl
	push	hl			; hash ../N
	ld	bc,T4EBA		; "Hash:  N/N"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ld	a,0Ah			; новая строка
	jp	A015E			; вывод "a" на экран



; Переполнение буферов компилятора
; (запись строки в вых. файл, вывод статистики и выход в ДОС)
; вход: a=индекс строки
A4F02:	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,L4EC4		; адреса строк
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T4EF6		; "XS overflow"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	call	info			; вывод статистики по занятости таблиц
	jp	abort			; выход в ДОС



A4F27:	push	hl
	ld	hl,T4F35		; "bug in "
	call	A0170			; вывод строки на экран
	pop	hl
	call	A0170
	jp	abort			; выход в ДОС



; Увеличить число текущих ошибок
A4F3D:	ld	hl,(errors)
	inc	hl
	ld	(errors),hl		; увел. число тек. ошибок
	ld	de,(max_errors)		; ячейка макс. числа ошибок
	and	a
	sbc	hl,de
	ret	c
	ld	hl,T4F55		; "Too many errors!"
	call	A0170			; вывод строки на экран
	jp	abort			; выход в ДОС



A4F68:	ld	a,(D77A8)		; false/true ?
	or	a
	jr	z,A4F78
	ld	hl,(D77E7)
	ld	(D79F5),hl
	jr	A4F7E
	;
A4F78:	ld	hl,(D76DB)
	ld	(D79F5),hl
A4F7E:	ld	hl,(D79F5)
	inc	hl
	inc	hl
	ld	(D79F7),hl
	ret


A4F87:	push	af
	ld	a,(D77A8)		; false/true ?
	or	a
	jr	z,A4FA5
	ld	de,(D79F7)
	ld	hl,(D77E9)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	a,1			; индекс строки "pool"
	jp	nc,A4F02		; abort
	jr	A4FB8
	;
A4FA5:	ld	de,(D79F7)
	ld	hl,(D76DD)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	a,3			; индекс строки "heap"
	jp	nc,A4F02		; abort
	;
A4FB8:	ld	hl,(D79F7)
	pop	af
	ld	(hl),a
	inc	hl
	ld	(D79F7),hl
	ret


A4FC2:	ld	de,(D79F7)
	ld	hl,(D79F5)
	inc	hl
	inc	hl
	ld	a,e
	sub	l
	ld	e,a
	ld	a,d
	sbc	a,h
	ld	d,a
	ld	hl,(D79F5)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	a,(D77A8)		; false/true ?
	or	a
	jr	z,A4FE7
	ld	hl,(D79F7)
	ld	(D77E7),hl
	jr	A4FED
A4FE7:	ld	hl,(D79F7)
	ld	(D76DB),hl
A4FED:	ld	hl,(D79F5)
	ret


A4FF1:	push	de
	push	hl
	ld	de,(D76DB)
	ld	hl,(D76DD)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	a,3			; индекс строки "heap"
	jp	nc,A4F02		; abort
	;
	ld	hl,(D76DB)
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	(D76DB),hl
	dec	hl
	dec	hl
	dec	hl
	dec	hl
	ret


A501B:	push	hl
	ex	de,hl
	ld	de,0
	call	A4FF1
	ex	de,hl
	pop	hl
	jp	A4FF1


A5028:	push	hl
	ld	l,c
	ld	h,b
	push	de
	ld	de,0
	call	A4FF1
	ex	de,hl
	pop	hl
	call	A4FF1
	ex	de,hl
	pop	hl
	jp	A4FF1


A503C:	ld	(D79FD),de
	push	hl
	call	A758A
	ld	de,0
	push	bc
	call	A4FF1
	ex	de,hl
	pop	hl
	call	A4FF1
	ex	de,hl
	ld	hl,(D79FD)
	call	A4FF1
	ex	de,hl
	pop	hl
	jp	A4FF1


A505C:	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret


A506A:	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret


; разадресация '*' ?
A5079:	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret


A5082:	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret


A508D:	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret


A509E:	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret


A50B5:	ld	hl,(D77E9)
	push	de
	ex	de,hl
	ld	hl,(D77E7)
	ld	(D79FB),hl
	inc	hl
	inc	hl
	inc	hl
	push	af
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	a,1			; индекс строки "pool"
	jp	c,A4F02			; abort
	;
	ld	hl,(D79FB)
	pop	af
	ld	(hl),a
	ld	hl,(D79FB)
	inc	hl
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D77E7)
	inc	hl
	inc	hl
	inc	hl
	ld	(D77E7),hl
	ret


A50EB:	ld	de,(D77E9)
	ld	hl,(D77E7)
	push	hl
	ld	bc,5
	add	hl,bc
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	a,1			; индекс строки "pool"
	jp	c,A4F02			; abort
	;
	pop	de
	ld	hl,1
	add	hl,de
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	hl,(D77E7)
	ld	bc,5
	add	hl,bc
	ld	(D77E7),hl
	ex	de,hl
	ret


A5119:	ld	hl,(D77E9)
	dec	hl
	dec	hl
	dec	hl
	ld	(D77E9),hl
	ex	de,hl
	ld	hl,(D77E7)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	a,1			; индекс строки "pool"
	jp	c,A4F02			; abort
	;
	ld	a,(D77FB)
	ld	hl,(D77E9)
	ld	(hl),a
	inc	hl
	ld	de,(D77FD)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret


A5142:	ld	hl,(D77E5)
	ld	(D79EF),hl
	ld	hl,(D77E5)
	ld	bc,9
	add	hl,bc
	ld	(D79F1),hl
	ret


A5153:	ld	de,(D79F1)
	ld	hl,(D79F9)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	a,4			; индекс строки "symbol table"
	jp	nc,A4F02		; abort
	;
	ld	a,(D77FB)
	ld	hl,(D79F1)
	ld	(hl),a
	ld	de,(D77FD)
	ld	hl,(D79F1)
	inc	hl
	inc	hl
	inc	hl
	ld	(D79F1),hl
	dec	hl
	dec	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret


A518B:	ld	hl,(D77E5)
	ld	bc,9
	add	hl,bc
	ld	(D77E5),hl
	ex	de,hl
	ld	hl,(D79F9)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	a,4			; индекс строки "symbol table"
	jp	nc,A4F02		; abort
	;
	ld	de,(D79F3)
	ld	hl,(D77E5)
	ld	bc,5
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D77E5)
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	hl,(D77E5)
	ld	(D79F3),hl
	ret


A51C2:	ld	hl,(D79F3)
	ld	bc,-9
	add	hl,bc
	ld	(D77E5),hl
	ld	hl,(D79F3)
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D79F3),hl
	ret


A51DB:	push	hl
	ld	de,(D77E5)
	push	de
A51E1:	ld	hl,(D77DF)
	or	a
	sbc	hl,de
	jr	nc,A5229
	ld	hl,5
	add	hl,de
	push	de
	push	hl
	ld	hl,6
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	ld	a,(hl)
	cp	e
	inc	hl
	jr	nz,A521D
	ld	a,(hl)
	cp	d
	jr	nz,A521D
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	0Dh
	jr	nz,A521D
	ld	l,e
	ld	h,d
	push	de
	call	A24DA
	pop	hl
	call	A51DB
A521D:	pop	de
	ld	hl,-9
	add	hl,de
	ex	de,hl
	inc	sp
	inc	sp
	push	de
	jr	A51E1
	;
A5229:	pop	bc
	pop	bc
	ret


A522C:	ld	c,l
	ld	b,h
	ld	de,(D77E5)
A5232:	ld	hl,(D77DF)
	or	a
	sbc	hl,de
	jr	nc,A5251
	ld	l,e
	ld	h,d
	ld	a,c
	cp	(hl)
	inc	hl
	jr	nz,A5249
	ld	a,b
	cp	(hl)
	jr	nz,A5249
	ex	de,hl
	ret
A5249:	ld	hl,-9
	add	hl,de
	ex	de,hl
	jr	A5232
A5251:	ld	hl,0
	ret


A5255:	ld	c,l
	ld	b,h
	ld	de,(D77E5)
A525B:	ld	hl,(D79F3)
	or	a
	sbc	hl,de
	jr	nc,A5279
	ld	l,e
	ld	h,d
	ld	a,c
	cp	(hl)
	inc	hl
	jr	nz,A5271
	ld	a,b
	cp	(hl)
	jr	nz,A5271
	ex	de,hl
	ret
A5271:	ld	hl,-9
	add	hl,de
	ex	de,hl
	jr	A525B
A5279:	ld	hl,0
	ret


A527D:	push	hl
	ld	hl,(D77E5)
	ld	bc,9
	add	hl,bc
	ld	(D77E5),hl
	ld	de,(D79F9)
	ld	a,l
	sub	e
	ld	a,h
	sbc	a,d
	ld	a,4			; индекс строки "symbol table"
	jp	nc,A4F02		; abort
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	dec	hl
	ret


A529E:	push	hl
	ld	de,(D77E5)
	ld	hl,(D79F9)
	ld	bc,-9
	add	hl,bc
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	a,4			; индекс строки "symbol table"
	jp	nc,A4F02		; abort
	;
	ld	hl,(D79F9)
	ld	bc,-9
	add	hl,bc
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D77E1)
	ld	bc,-9
	add	hl,bc
	ld	(D7A0B),hl
A52CB:	ld	a,(hl)
	cp	e
	inc	hl
	jr	nz,A52D3
	ld	a,(hl)
	cp	d
A52D3:	dec	hl
	jr	z,A52E1
	ld	bc,-9
	add	hl,bc
	ld	(D7A0B),hl
	jr	A52CB
A52E1:	ld	hl,(D79F9)
	ld	c,e
	ld	b,d
	ld	de,(D7A0B)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	c,A52F4
	ex	de,hl
	ret
A52F4:	push	bc
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ex	de,hl
	ld	hl,(D79F9)
	ld	bc,-9
	add	hl,bc
	ld	(D79F9),hl
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D79F9)
	ld	bc,7
	add	hl,bc
	ld	(hl),0
	ld	hl,(D79F9)
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,(D79F9)
	ret


A5322:	ld	hl,(D77E1)
	ld	bc,-9
	add	hl,bc
	ex	de,hl
A532A:	ld	hl,(D79F9)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	c
	ld	hl,7
	add	hl,de
	push	de
	ld	a,(hl)
	or	a
	jr	nz,A535B
	ld	a,true
	ld	(D76C7),a		; false/true флаг наличия ошибок компиляции
	ld	(D78E1),a
	ld	hl,(D5575)
	push	hl
	ex	de,hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,T5364		; undefined label "S" in function "S"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A535B:	pop	de
	ld	hl,-9
	add	hl,de
	ex	de,hl
	jr	A532A


A5388:	ld	hl,(D77E5)
	ld	c,l
	ld	b,h
A538D:	ld	hl,(D79F3)
	or	a
	sbc	hl,bc
	ret	nc
	ld	hl,2
A5397:	add	hl,bc
	ld	a,(hl)
	push	bc
	cp	50h
	jr	nz,A53EC
	ld	hl,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	nz,A53E7
	push	bc
	ld	a,(mode)		; Свой режим компилятора  (1-я ячейка)
	or	a
	jr	z,A53CE			; режим K&R совместимости
	ld	l,c
	ld	h,b
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T53F6		; Xundeclared parameter "S"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
A53CE:	ld	de,(D78B2)
	pop	bc
	ld	hl,6
	add	hl,bc
	ld	(hl),d
	dec	hl
	ld	(hl),e
	dec	hl
A53DB:	ld	de,(D1BC8)
	ld	(hl),d
	dec	hl
	ld	(hl),e
A53E2:	inc	de
	ld	(D1BC8),de
A53E7:	ld	l,c
	ld	h,b
	call	A2546
A53EC:	pop	bc
D53ED:	ld	hl,-9
	add	hl,bc
	ld	c,l
	ld	b,h
	jr	A538D


A5410:	ld	de,(D77E5)
A5414:	ld	hl,(D77DF)
	ld	a,l
	sub	e
	ld	a,h
	sbc	a,d
	ret	nc
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	push	de
	cp	"Y"			; 59h
	jr	nz,A544A
	ld	hl,7
	add	hl,de
	ld	a,(hl)
	or	a
	jr	nz,A544A
	ex	de,hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,T5453		; static function "S" not defined
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ld	a,true
	ld	(D76C7),a		; false/true флаг наличия ошибок компиляции
	ld	(D78E1),a
A544A:	pop	de
	ld	hl,-9
	add	hl,de
	ex	de,hl
	jr	A5414


A5473:	ld	hl,(D5575)
	ld	a,l
	or	h
	jr	nz,A5490
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T54AA		; "XunEeof"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jp	abort			; выход в ДОС
	;
A5490:	ld	hl,(D5575)
	push	hl
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T54B2		; XunEeof inside function "S"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	jp	abort			; выход в ДОС



A54CE:	ld	l,a
	ld	a,(D77FB)
	cp	0FAh
	jp	z,A5473
	cp	l
	jp	z,A1651
	push	de
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T54F0		; X"S" E
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret



A54F7:	ld	(D7A13),hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	hl,(D77F7)		; номер колонки
	ld	(D7A17),hl
	ld	hl,(D7A13)
	push	hl
	ld	bc,T5577		; "	j	L%u"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	call	A36D3
	call	A6194
	ex	de,hl
	ld	hl,(D78B6)
	pop	bc
	or	a
	sbc	hl,de
	jr	z,A553A
	ld	a,(D78E1)
	or	a
	jr	nz,A553A		; true
	ld	hl,(D7A17)
	push	hl
	push	bc
	ld	bc,T557E		; "XBcondition"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A5557
A553A:	ld	a,(D78F6)
	or	a
	jr	z,A5557
	ld	(D7A15),bc
	ld	hl,(D7A17)
	push	hl
	ld	hl,(D7A15)
	push	hl
	ld	bc,T558A		; "XMcondition"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A5557:	ld	bc,T5596		; "	n"
	push	bc
	call	A4ABC
	pop	bc
	ret

A5560:	ld	de,T559A		; "("
	ld	a,8
	push	hl
	call	A54CE
	pop	hl
	call	A54F7
	ld	de,A559C		; ")"
	ld	a,10h
	jp	A54CE

D5575:	dw	0


A559E:	push	hl
	ld	bc,T55BC		; "L%u"
	jp	A55AD


A55A9:	push	hl
	ld	bc,T55B4		; "	j	L%u"
A55AD:	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	ret


A55C1:	ld	a,l
	or	h
	ret	z
	ld	(D7A19),hl
	push	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D5575),hl
	push	hl
	ld	hl,(D7A19)
	inc	hl
	inc	hl
	ld	l,(hl)
	push	hl
	ld	bc,T5653		; "%c%s     "
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	pop	de
	ld	hl,5
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	ld	a,(hl)
	ld	(D7A1B),a
	ld	a,(D78F5)
	or	a
	jr	nz,A5601
A550B:	ld	a,0
	;ld	a,(D76D2)
	ld	(D78F5),a
A5601:	ld	a,(D76C8)		; true/false
	push	af
	xor	a			; false
	ld	(D76C8),a
	ld	hl,5
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A6421
	ld	(D7A02),hl
	pop	af
	ld	(D76C8),a		; true/false
	ld	a,(D78F5)
	dec	a
	jr	nz,A562E
	ld	hl,T5662		; 0
	jr	A5631
A562E:	ld	hl,T5663		; "	E"
A5631:	push	hl
	ld	a,(D7A1B)
	cp	9
	jr	nz,A563F
	ld	a,46h
	jr	A5641
A563F:	ld	a,55h
A5641:	ld	c,a
	push	bc
	ld	hl,(D7A02)
	push	hl
	ld	bc,T5659
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret

;++T5653:	db	"%c%s",9,0
;T5659:	db	"%t",9,"%c%s",0Ah,0
;T5662:	db	0
;T5663:	db	9,"E",0


A5666:	ld	(D7A1C),hl
	ld	hl,(D7A11)
	ld	a,l
	or	h
	jr	nz,A5680
	xor	a
	ld	(D7907),a
	ld	hl,(D7A1C)
	call	A20D7
	ld	(D7A1E),hl
	jr	A5686
A5680:	ld	hl,0
	ld	(D7A1E),hl
A5686:	ld	a,(D77FB)
	push	hl
	cp	0A8h
	jr	nz,A56AA
	call	A1651
	ld	a,(D7A06)
	cp	54h
	jr	z,A56A1
	cp	4Bh
	jr	z,A56A1
	or	a
	jr	nz,A56C2
A56A1:	ld	hl,(D7A1E)
	call	A2EC8
	jr	A56D7
	;
A56AA:	ld	a,(D7A06)
	cp	4Bh
	jr	nz,A56D7
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T56DB		; "XuninitializedG"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	jr	A56D1
	;
A56C2:	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T570E		; "XI"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
A56D1:	pop	bc
	pop	bc
	pop	bc
	call	A2A26
A56D7:	pop	hl
	jp	A25B4


A56EB:	ld	bc,T5711		; "{"
	push	bc
	call	A4ABC
	pop	bc
	ld	hl,(D77E1)
	ld	(D79F9),hl
	call	A594D
	call	A5322
	ld	bc,T5714		; "}"
	push	bc
	call	A4ABC
	pop	bc
	ld	hl,0
	ld	(D5575),hl
	ret


A5717:	ld	(D7A20),hl
	ld	a,l
	or	h
	ret	z
A571D:	call	A5079
	ld	a,l
	dec	a
	or	h
	jr	z,A573E
	ld	hl,(D7A20)
	push	hl
	call	A508D
	ld	e,50h
	ld	bc,0
	call	A1BCA
	pop	hl
	call	A5082
	ld	(D7A20),hl
	jr	A571D
A573E:	ld	hl,(D7A20)
	ld	e,50h
	ld	bc,0
	jp	A1BCA


A5749:	push	hl
	ld	hl,(D77DF)
	ld	bc,108			; 006Ch
	add	hl,bc
	or	a
	sbc	hl,de
	pop	hl
	ret	nz
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,h
	or	a
	ret	nz
	ld	a,l
	cp	34h
	ret	z
	cp	33h
	ret	z
	cp	35h
	ret	z
	cp	3Dh
	ret	z
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	hl,T5781		; X"void" object
	push	hl
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret


A5790:	call	A518B
A5793:	ld	a,(D77FB)
	cp	0FAh
	jp	z,A5914
	;call	test_Esc		; тест на Esc
	call	A3967
	ld	hl,(D78F3)
	ld	a,l
	or	h
	jr	nz,A57AC
	ld	hl,(D78B2)
A57AC:	ld	(D7A04),hl
	ld	a,(D7A06)
	cp	47h
	jr	z,A57DB
	cp	54h
	jr	z,A57DB
	cp	4Bh
	jr	z,A57DB
	cp	64h
	jr	z,A57DB
	or	a
	jr	z,A57DB
	xor	a
	ld	(D7A06),a
	ld	hl,(D78F9)
	push	hl
	ld	hl,(D78F7)
	push	hl
	ld	bc,T591A
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A57DB:	ld	a,(D77FB)
	cp	0C8h
	jr	nz,A57E8
	call	A1651
	jr	A5793
	;
A57E8:	ld	a,(D7A06)
	ld	hl,(D76DB)
	ld	(D7A07),hl
	push	af
	call	A390D
	ld	(D7A09),hl
	ld	de,(D78F3)
	call	A5749
	pop	af
	ld	(D7A06),a
	ld	a,(D77FB)
	cp	0DFh
	jr	z,A5818
	call	A393E
	or	a
	jr	nz,A5818
	call	A3923
	ld	a,l
	or	h
	jp	z,A58A4
A5818:	ld	a,1
	ld	(D7A0E),a
	ld	a,(D7A06)
	cp	64h
	jr	nz,A583A
	xor	a
	ld	(D7A06),a
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T591A
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A583A:	ld	a,(D7A06)
	cp	54h
	jr	z,A5856
	or	a
	jr	z,A5856
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T591A		; "XT"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A5856:	ld	a,(D7A0D)
	or	a
	jr	nz,A586E
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T591D		; "Xfunction E"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A586E:	ld	hl,0
	ld	(D7A0F),hl
	ld	hl,(D7A11)
	ld	a,l
	or	h
	jr	nz,A5889
	ld	de,(D7A04)
	ld	hl,(D7A09)
	call	A20D7
	call	A55C1
A5889:	call	A518B
	ld	hl,(D7A0F)
	call	A5717
	ld	hl,(D7A07)
	ld	(D76DB),hl
	call	A3CDB
	call	A56EB
	call	A51C2
	jp	A5793
A58A4:	ld	a,(D78F5)
	or	a
	jr	z,A58BD
	ld	hl,(D7A24)
	push	hl
	ld	hl,(D7A22)
	push	hl
	ld	bc,T5929		; "XO"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A58BD:	xor	a
	ld	(D7A0E),a
	ld	de,(D7A04)
	ld	hl,(D7A09)
	call	A5666
	ld	hl,(D7A07)
	ld	(D76DB),hl
A58D1:	ld	a,(D77FB)
	cp	0B8h
	jr	nz,A58F5
	;call	test_Esc		; тест на Esc
	call	A1651
	ld	hl,(D76DB)
	push	hl
	call	A390D
	ld	de,(D7A04)
	call	A5666
	pop	hl
	ld	(D76DB),hl
	jr	A58D1
A58F5:	ld	a,(D77FB)
	cp	0C8h
	jr	z,A590E
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T592C		; "XBelement encountered externally"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A590E:	call	A1651
	jp	A5793
A5914:	call	A5410
	jp	A51C2



A594D:	ld	de,T5EE5
	ld	a,0DFh
	call	A54CE
	call	A3D7C
A5958:	ld	a,(D77FB)
	cp	0E0h
	jp	z,A1651
	call	A600A
	jr	A5958


A5966:	ld	a,(D790C)		; флаг типа long/float/double
	or	a
	call	nz,A59D2		; записать 'XQ"asm" U' в вых. файл
A596D:	call	A0E3E
	cp	20h
	jr	z,A596D
	cp	9
	jr	z,A596D
	cp	0Ah
	jr	z,A596D
	cp	7Bh
	jr	z,A5987
	call	A599B
	jp	A1651
	;
A5987:	call	A0E3E
	cp	20h
	jr	z,A5987
	cp	9
	jr	z,A5987
	cp	7Dh
	jp	z,A1651
	call	A599B
	jr	A5987
	;
A599B:	cp	0Ah
	ret	z
	push	af
	ld	a,"\"			; 5Ch
	call	A498B
	pop	af
A59A5:	call	A498B
	call	A0E3E
	cp	27h
	jr	z,A59C0
	cp	22h
	jr	z,A59C0
	cp	3Bh
	jr	z,A59BB
	cp	0Ah
	jr	nz,A59A5
A59BB:	ld	a,0Ah
	jp	A498B
	;
A59C0:	ld	b,a
A59C1:	push	bc
	call	A498B
	call	A0E3E
	pop	bc
	cp	b
	jr	nz,A59C1
	call	A498B
	jr	A59A5


; для типа long/float/double
A59D2:	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	hl,T59E5		; 'XQ"asm" U'
	push	hl
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret



A59EF:	push	bc
	call	A1651
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	push	hl
	call	A5560
	call	A600A
	ld	a,(D77FB)
	pop	hl
	cp	0E2h
	jr	nz,A5A2C
	push	hl
	call	A1651
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	call	A755F
	call	A55A9
	pop	hl
	call	A559E
	call	A600A
	pop	hl
	push	hl
	call	A559E
	jr	A5A2F
A5A2C:	call	A559E
A5A2F:	pop	bc
	ret


A5A31:	ld	hl,(D5EE0)
	push	hl
	ld	hl,(D5EDE)
	push	hl
	ld	bc,T5A76		; "	d"
	push	bc
	call	A4ABC
	pop	bc
	call	A1651
	ld	hl,(D1BC8)
	ld	(D5EE0),hl
	inc	hl
	ld	(D5EDE),hl
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	call	A5560
	call	A600A
	ld	hl,(D5EE0)
	call	A559E
	ld	bc,T5A82		; "	b"
	push	bc
	call	A4ABC
	pop	bc
	ld	hl,(D5EDE)
	call	A559E
	pop	hl
	ld	(D5EDE),hl
	pop	hl
	ld	(D5EE0),hl
	ret


;++T5A76:	db	9,"d",0Ah,0
;T5A7A:	db	"while",0
;T5A80:	db	";",0
;T5A82:	db	9,"b",0Ah,0


A5A86:	ld	hl,(D5EE0)
	push	hl
	ld	hl,(D5EDE)
	push	hl
	ld	hl,(D1BC8)
	ld	(D5EDE),hl
	inc	hl
	ld	(D5EE0),hl
	inc	hl
	ld	(D1BC8),hl
	ld	bc,T5A76		; "	d"
	push	bc
	call	A4ABC
	pop	bc
	call	A1651
	call	A600A
	ld	de,T5A7A		; "while"
	ld	a,0E4h
	call	A54CE
	ld	hl,(D5EDE)
	call	A5560
	ld	hl,(D5EE0)
	call	A559E
	ld	de,T5A80		; ";"
	ld	a,0C8h
	call	A54CE
	ld	bc,T5A82		; "	b"
	push	bc
	call	A4ABC
	pop	bc
	ld	hl,(D5EDE)
	call	A559E
	pop	hl
	ld	(D5EDE),hl
	pop	hl
	ld	(D5EE0),hl
	ret


;++T5ADD:	db	"(",0
;T5ADF:	db	")",0
;T5AE1:	db	0Ah,0


A5AE3:	ld	hl,(D5EE0)
	push	hl
	ld	hl,(D5EDE)
	push	hl
	ld	hl,(D1BC8)
	ld	(D5EDE),hl
	inc	hl
	ld	(D5EE0),hl
	inc	hl
	ld	(D1BC8),hl
	call	A1651
	ld	de,T5ADD		; "("
	ld	a,8
	call	A54CE
	ld	a,(D77FB)
	cp	0C8h
	jr	z,A5B16
	call	A3719
	ld	bc,T5AE1		; 0Ah
	push	bc
	call	A4ABC
	pop	bc
A5B16:	ld	de,T5A80		; ";"
	ld	a,0C8h
	call	A54CE
	ld	bc,T5A76		; "	d"
	push	bc
	call	A4ABC
	pop	bc
	ld	a,(D77FB)
	cp	0C8h
	jr	z,A5B33
	ld	hl,(D5EDE)
	call	A54F7
A5B33:	ld	de,T5A80		; ";"
	ld	a,0C8h
	call	A54CE
	ld	a,(D77FB)
	cp	10h
	jr	z,A5B7C
	xor	a
	ld	(D79FF),a
	ld	hl,(D76DB)
	push	hl
	call	A3640
	push	hl
	call	A3700
	ld	a,(D78E1)		; false/true
	ld	de,T5ADF		; ")"
	push	af
	ld	a,10h
	call	A54CE
	call	A600A
	ld	hl,(D5EE0)
	call	A559E
	pop	af
	ld	(D78E1),a
	pop	hl
	call	A36A1
	ld	bc,T5AE1
	push	bc
	call	A4ABC
	pop	bc
	pop	hl
	ld	(D76DB),hl
	jr	A5B88
	;
A5B7C:	call	A1651
	call	A600A
	ld	hl,(D5EE0)
	call	A559E
A5B88:	ld	bc,T5A82
	push	bc
	call	A4ABC
	pop	bc
	ld	hl,(D5EDE)
	call	A559E
	pop	hl
	ld	(D5EDE),hl
	pop	hl
	push	hl
	ld	(D5EE0),hl
	pop	bc
	ret


A5BA1:	ld	hl,(D5EDE)
	ld	a,l
	or	h
	jr	nz,A5BBA
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T5BCB		; X"break" outside switch/break
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A5BBA:	call	A1651
	ld	hl,(D5EDE)
	call	A55A9
	ld	de,T5A80
	ld	a,0C8h
	jp	A54CE


A5BE9:	ld	hl,(D5EE0)
	ld	a,l
	or	h
	jr	nz,A5C03
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T5C14		; X"continue" outside loop
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A5C03:	call	A1651
	ld	hl,(D5EE0)
	call	A55A9
	ld	de,T5A80
	ld	a,0C8h
	jp	A54CE


A5C2D:	call	A1651
	ld	bc,T5C9E		; "	y"
	push	bc
	call	A4ABC
	pop	bc
	ld	a,(D77FB)
	cp	0C8h
	jr	z,A5C8E
	ld	hl,(D77DF)
	ld	de,108			; 006Ch
	add	hl,de
	ld	de,(D7A02)
	or	a
	sbc	hl,de
	jr	nz,A5C61
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T5CA6		; X"void" returns value
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A5C61:	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	hl,(D77F7)		; номер колонки
	ld	(D7A00),hl
	ld	hl,(D7A02)
	push	hl
	ld	bc,T5CA1		; "%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	call	A36D3
	pop	bc
	ld	de,(D7A00)
	ld	a,l
	or	h
	jr	z,A5C8E
	push	de
	ex	de,hl
	ld	hl,(D7A02)
	call	A636C
	pop	bc
A5C8E:	ld	bc,T5CA4		; 0Ah
	push	bc
	call	A4ABC
	pop	bc
	ld	de,T5A80
	ld	a,0C8h
	jp	A54CE


A5CD4:	ld	hl,-10
	add	hl,sp
	ld	sp,hl
	ld	hl,(D76DF)
	push	hl
	ld	hl,(D76DD)
	ld	(D76DF),hl
	ld	hl,(D5EDE)
	push	hl
	ld	hl,(D5EE2)
	call	A7553
	ld	a,(D5EE4)
	ld	hl,(D1BC8)
	ld	(D5EDE),hl
	inc	hl
	ld	(D1BC8),hl
	ld	hl,0
	ld	(D5EE2),hl
	ld	hl,12
	add	hl,sp
	ld	(hl),a
	ld	a,1
	ld	(D5EE4),a
	call	A1651
	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	call	A754D
	call	A55A9
	ld	de,T5CBC
	ld	a,8
	call	A54CE
	ld	hl,(D77F9)		; номер строки
	call	A7541
	ld	hl,(D77F7)		; номер колонки
	xor	a
	ld	(D79FF),a
	call	A756B
	db	0Ch,0
	;
	ld	hl,(D76DB)
	push	hl
	call	A3640
	ld	a,(D78E1)		; false/true
	push	hl
	ld	de,(D78F3)
	ld	hl,2
	add	hl,de
	push	af
	ld	a,(hl)
	push	de
	ld	hl,18
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	dec	a
	jr	z,A5D70
	ld	hl,(D78B6)
	or	a
	sbc	hl,de
	jr	z,A5D70
	push	bc
	call	A759C
	db	14h,0
	;
	push	hl
	ld	bc,A5CBE		; "XBswitch expression"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A5D70:	ld	de,T5CD2		; ")"
	ld	a,10h
	call	A54CE
	call	A600A
	ld	hl,(D5EDE)
	call	A55A9
	call	A759C
	db	10h,0
	;
	call	A559E
	ld	hl,(D78B6)
	pop	de
	or	a
	sbc	hl,de
	jr	nz,A5D97
	ld	hl,(D78B4)
	jr	A5D98
	;
A5D97:	ex	de,hl
A5D98:	push	hl
	ld	bc,T5E32
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	af
	ld	(D78E1),a		; false/true
	pop	hl
	call	A36A1
	ld	de,(D78B4)
	call	A617E
	ld	bc,T5CA4
	push	bc
	call	A4ABC
	pop	bc
	ld	hl,(D76DF)
	dec	hl
	dec	hl
	dec	hl
	dec	hl
	ex	de,hl
A5DC1:	ld	hl,(D76DD)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	c,A5DEB
	ld	hl,2
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	de
	push	bc
	ex	de,hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,T5E37		; "w	L%u	#%u"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	pop	de
	dec	de
	dec	de
	dec	de
	dec	de
	jr	A5DC1
	;
A5DEB:	ld	hl,(D5EE2)
	ld	a,l
	or	h
	jr	z,A5DF9
	ld	hl,(D5EE2)
	jr	A5DFC
	;
A5DF9:	ld	hl,(D5EDE)
A5DFC:	push	hl
	ld	bc,T5E43		; "f	L%u"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	ld	hl,(D5EDE)
	call	A559E
	pop	hl
	ld	(D76DB),hl
	pop	hl
	ld	(D5EDE),hl
	call	A7590
	ld	(D5EE2),hl
	ld	hl,10
	add	hl,sp
	ld	a,(hl)
	ld	(D5EE4),a
	ld	hl,(D76DF)
	ld	(D76DD),hl
	pop	hl
	ld	(D76DF),hl
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret


A5E80:	ld	a,(D5EE4)
	or	a
	jr	nz,A5E9C
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T5E4B		; X"default" outside switch
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A5EC7
	;
A5E9C:	ld	hl,(D5EE2)
	ld	a,l
	or	h
	jr	z,A5EB9
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T5E65		; X"default" appeard twice
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A5EC7
	;
A5EB9:	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ld	(D5EE2),hl
	call	A559E
A5EC7:	call	A1651
	ld	de,T5E7E		; ":"
	ld	a,0A0h
	call	A54CE
	jp	A600A


A5ED5:	ld	de,T4796
	ld	hl,T34D8
	jp	A33D1


D5EDE:	dw	0
D5EE0:	dw	0
D5EE2:	dw	0
D5EE4:	db	0


A5F25:	ld	a,(D5EE4)
	or	a
	jr	nz,A5F47
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T5EE7		; X"case" outside switch
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	call	A1651
	call	A5ED5
	jp	A5FDF
	;
A5F47:	call	A1651
	call	A5ED5
	ld	c,l
	ld	b,h
	ld	de,(D76DB)
	ld	hl,(D76DD)
	push	bc
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	a,3			; индекс строки "heap"
	jp	nc,A4F02		; abort
	;
	ld	de,(D76DF)
	dec	de
	dec	de
	dec	de
	dec	de
	pop	bc
A5F86:	ld	hl,(D76DD)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	c,A5FBB
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	c
	inc	hl
	jr	nz,A5F9C
	ld	a,(hl)
	cp	b
A5F9C:	jr	nz,A5FB4
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T5F14		; XD"case" label
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A5FDF
A5FB4:	dec	de
	dec	de
	dec	de
	dec	de
	jr	A5F86
	;
A5FBB:	ld	hl,(D1BC8)
	inc	hl
	ld	(D1BC8),hl
	dec	hl
	ex	de,hl
	ld	hl,(D76DD)
	dec	hl
	dec	hl
	dec	hl
	dec	hl
	ld	(D76DD),hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ex	de,hl
	push	bc
	call	A559E
	ld	hl,(D76DD)
	inc	hl
	inc	hl
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
A5FDF:	ld	de,T5F23		; ":"
	ld	a,0A0h
	call	A54CE
	jp	A600A


;++T5FEA:	db	";",0

A5FEC:	call	A1651
	ld	hl,(D77FD)
	call	A529E
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A55A9
	call	A1651
	ld	de,T5FEA		; ";"
	ld	a,0C8h
	jp	A54CE


A600A:	push	bc
	push	bc
	push	bc
A600D:	;call	test_Esc		; тест на Esc
	ld	a,(D77FB)
	dec	a
	jr	nz,A608E
	ld	hl,(D77FD)
	pop	de
	push	hl
	push	hl
	ld	hl,(D77F9)		; номер строки
	call	A7553
	ld	hl,(D77F7)		; номер колонки
	call	A754D
	call	A1651
	pop	hl
	cp	0A0h
	jr	nz,A6075
	call	A529E
	ex	de,hl
	ld	hl,7
	add	hl,de
	ld	a,(hl)
	or	a
	jr	z,A605B
	pop	hl
	push	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T6164		; XDlabel "S"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	jr	A606C
	;
A605B:	ld	hl,7
	add	hl,de
	ld	(hl),1
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A559E
A606C:	call	A1651
	call	A600A
	jp	A6160
	;
A6075:	push	hl
	call	A161E
	pop	hl
	ld	(D77FD),hl
	ld	a,1
	ld	(D77FB),a
	call	A7590
	ld	(D77F9),hl		; номер строки
	call	A758A
	ld	(D77F7),hl		; номер колонки
A608E:	ld	a,(D77FB)
	ld	bc,15			; длина сравнения
	ld	hl,T60A4		; 15 байт
	cpir
	jp	nz,A612E
	add	hl,bc
	add	hl,bc
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jp	(hl)

T60A4:	db	0xDF,0xE1,0xE4,0xE5,0xE3,0xEA,0xEB,0xE9     ; токены ?
	db	0xC8,0xE6,0xE7,0xE8,0xEC,0xF0,0xFA

L60B3:	dw	L612B
	dw	L60DD
	dw	L6125
	dw	L611F
	dw	L6119
	dw	L6113
	dw	L610D
	dw	L6107
	dw	L6101
	dw	L60FB
	dw	L60F5
	dw	L60EF
	dw	L60E9
	dw	L60E3
	dw	L60D1


L60D1:	call	A518B
	call	A594D
	call	A51C2
	jp	A6160
	;
L60DD:	call	A5966
	jp	A6160
	;
L60E3:	call	A59EF
	jp	A6160
	;
L60E9:	call	A5A31
	jp	A6160
	;
L60EF:	call	A5A86
	jp	A6160
	;
L60F5:	call	A5AE3
	jp	A6160
	;
L60FB:	call	A5BA1
	jp	A6160
	;
L6101:	call	A5BE9
	jp	A6160
	;
L6107:	call	A5C2D
	jp	A6160
	;
L610D:	call	A1651
	jp	A6160
	;
L6113:	call	A5CD4
	jp	A6160
	;
L6119:	call	A5F25
	jp	A6160
	;
L611F:	call	A5E80
	jp	A6160
	;
L6125:	call	A5FEC
	jp	A6160
	;
L612B:	call	A5473
A612E:	call	A3719
	ld	a,(D78F6)
	or	a
	jr	z,A6150
	ld	hl,(D77F7)		; номер колонки
	push	hl
	ld	hl,(D77F9)		; номер строки
	push	hl
	ld	bc,T6170		; "XBelement"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
D6148:	pop	bc
	pop	bc
	call	A1651
	jp	A600D
	;
A6150:	ld	bc,T617A		; 0Ah
	push	bc
	call	A4ABC
	pop	bc
	ld	de,T617C		; ";"
	ld	a,0C8h
	call	A54CE
A6160:	pop	bc
	pop	bc
	pop	bc
	ret


A617E:	push	de
	ex	de,hl
	ld	hl,(D78B6)
	or	a
	sbc	hl,de
	pop	hl
	ex	de,hl
	ret	nz
	push	de
	ld	bc,T61BD		; "	#1	#0	?%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	hl
	ret


A6194:	ex	de,hl
	ld	hl,(D78B6)
	or	a
	sbc	hl,de
	jr	z,A61B9
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	dec	a
	jr	z,A61A9
	cp	7
	jr	nz,A61B5
A61A9:	push	de
	ld	bc,T61C8		; "	#0	!%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	jr	A61B9
A61B5:	ld	hl,0			; false?
	ret
A61B9:	ld	hl,(D78B6)
	ret

;++T61BD:	db	9,"#1",9,"#0",9,"?%t",0
;T61C8:	db	9,"#0",9,"!%t",0


T61D0:	db	0x01,0x01,0x01,0x01,0x01,0x01,0x01,0x08
	db	0x09,0x0A,0x0B,0x01,0x02,0x02,0x02,0x02
	db	0x02,0x02,0x08,0x09,0x0A,0x0B,0x01,0x02
	db	0x03,0x03,0x03,0x03,0x03,0x08,0x09,0x0A
	db	0x0B,0x01,0x02,0x03,0x03,0x01,0x02,0x03
	db	0x08,0x09,0x0A,0x0B,0x01,0x02,0x03,0x01
	db	0x05,0x05,0x05,0x08,0x09,0x0A,0x0B,0x01
	db	0x02,0x03,0x02,0x05,0x06,0x06,0x08,0x09
	db	0x0A,0x0B,0x01,0x02,0x03,0x03,0x05,0x06
	db	0x07,0x08,0x09,0x0A,0x0B,0x08,0x08,0x08
	db	0x08,0x08,0x08,0x08,0x08,0x09,0x0A,0x0B
	db	0x09,0x09,0x09,0x09,0x09,0x09,0x09,0x09
	db	0x09,0x0A,0x0B,0x0A,0x0A,0x0A,0x0A,0x0A
	db	0x0A,0x0A,0x0A,0x0A,0x0A,0x0B,0x0B,0x0B
	db	0x0B,0x0B,0x0B,0x0B,0x0B,0x0B,0x0B,0x0B
	db	0x0B


A6249:	ld	c,e
	ld	b,d
	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	8
	jr	nz,A6257
	ex	de,hl
	ret
A6257:	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	cp	8
	jr	nz,A6263
	ld	l,c
	ld	h,b
	ret
A6263:	ld	hl,3
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,-11
	add	hl,bc
	ex	de,hl
	ld	hl,T61D0		; массив байтов
	add	hl,de
	pop	bc
	add	hl,bc
	dec	hl
	ld	l,(hl)
	ld	h,0
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ex	de,hl
	ld	hl,(D77DF)
	add	hl,de
	ret


A6297:	ld	(D7A2B),de
	ld	(D7A29),hl
	ld	bc,3
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,h
	or	a
	jr	nz,A62B3
	ld	a,l
	cp	5
	jr	c,A62B7
	cp	8
	jr	nc,A62B7
A62B3:	dec	hl
	dec	hl
	dec	hl
	dec	hl
A62B7:	ld	(D7A2D),hl
	ld	hl,(D7A2B)
	ld	bc,3
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,h
	or	a
	jr	nz,A62D2
	ld	a,l
	cp	5
	jr	c,A62D6
	cp	8
	jr	nc,A62D6
A62D2:	dec	hl
	dec	hl
	dec	hl
	dec	hl
A62D6:	push	hl
	ld	hl,(D7A29)
	inc	hl
	inc	hl
	ld	a,(hl)
	ld	hl,(D7A2B)
	inc	hl
	inc	hl
	ld	de,(D7A2D)
	cp	(hl)
	pop	hl
	jr	nz,A62EE
	or	a
	sbc	hl,de
	ret	z
A62EE:	ld	hl,(D78B6)
	ld	de,(D7A2B)
	or	a
	sbc	hl,de
	ld	hl,(D7A29)
	ex	de,hl
	jp	z,A617E
	push	hl
	push	de
	ld	bc,T630C		; "	%t%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	ret

;++T630C:	db	9,"%t%t",0


A6312:	ld	c,l
	ld	b,h
	ld	a,(mode)		; Свой режим компилятора (2-я ячейка)
	or	a
	ret	z			; K&R совместимость
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	cp	8
	jr	z,A6333
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	ld	hl,2
	add	hl,de
	cp	(hl)
	jr	z,A6331
	ld	a,true
	ret
A6331:	xor	a			; false
	ret
A6333:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	dec	a
	jr	nz,A6354
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	sub	6
	inc	hl
	or	(hl)
	jr	z,A6354
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	sub	5
	inc	hl
	or	(hl)
	jr	nz,A6367
A6354:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	8
	jr	nz,A636A
	ld	l,c
	ld	h,b
	call	A1E15
	or	a
	jr	nz,A636A
A6367:	ld	a,true
	ret
A636A:	xor	a			; false
	ret


A636C:	push	de
	ld	(D7A2F),hl
	push	bc
	call	A6312
	pop	bc
	or	a
	jr	z,A638B
	call	A758A
	push	hl
	push	bc
	ld	bc,T6392		; "Xpointer type mismatch - use cast"
	push	bc
	ld	a,"X"			; 58h
	ld	(bc),a
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A638B:	pop	de
	ld	hl,(D7A2F)
	jp	A6297


A63B4:	push	de
	ld	(D7A27),hl
	push	bc
	call	A6312
	pop	bc
	or	a
	jr	z,A63CD
	push	bc
	ld	bc,T6392		; "Xpointer type mismatch - use cast"
	push	bc
	ld	a,"Y"			; 59h
	ld	(bc),a
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
A63CD:	pop	de
	ld	hl,(D7A27)
	jp	A6297


A63D4:	push	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	pop	hl
	cp	0Dh
	ret	nz
	push	hl
	ld	bc,T63F5		; "	a"
	push	bc
	call	A4ABC
	pop	bc
	pop	hl
	ld	bc,5
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	de,0
	ld	a,8
	jp	A1D2E

;++T63F5:	db	9,"a",0


A63F8:	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	9
	jr	z,A640B
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	0Ah
	jr	nz,A641D
A640B:	ld	bc,T63F5		; "	a"
	push	de
	push	bc
	call	A4ABC
	pop	bc			; восст. стек
	pop	bc
	ld	de,0
	ld	a,8
	jp	A1D2E
A641D:	ex	de,hl
	jp	A63D4


A6421:	ex	de,hl
	ld	a,(D76C9)		; false/true строгая совм. с MSX-C
	or	a
	jr	z,A6448
	; режим совместимости с msx-c
	ld	hl,(D78B4)
	or	a
	sbc	hl,de
	jr	z,A643C
	ld	hl,(D77DF)
	ld	bc,63			; 003Fh
	add	hl,bc
	sbc	hl,de
	jr	nz,A6448
A643C:	ld	bc,T644A		; "	IC"
	push	bc
	call	A4ABC
	pop	bc
	ld	hl,(D78B2)
	ret
A6448:	ex	de,hl
	ret

;++T644A:	db	9,"IC",0


A644E:	push	hl
	call	A5079
	ld	a,l
	pop	hl
	; switch
	cp	0B8h			; токены ?
	jr	z,A648E
	cp	98h
	jr	z,A6494
	cp	0C5h
	jr	z,A64AD
	cp	35h
	jr	z,A64AD
	cp	33h
	jr	z,A64AD
	cp	30h
	jr	z,A64AD
	cp	31h
	jr	z,A64AD
	cp	38h
	jr	z,A64AD
	cp	39h
	jr	z,A64AD
	cp	0C6h
	jr	z,A64AF
	cp	0BFh
	jr	z,A64AF
	jr	A64AA			; default
	;
A648E:	call	A508D
	jr	A644E
	;
A6494:	push	hl
	call	A508D
	call	A644E
	pop	hl
	or	a
	jr	nz,A64AA
	call	A509E
	call	A644E
	or	a
	jr	z,A64AD
A64AA:	ld	a,true
	ret
A64AD:	xor	a			; false
	ret
	;
A64AF:	call	A5079
	ld	a,h
	cp	0C5h
	jr	nz,A64AA
	xor	a			; false
	ret
	;
A64BA:	ld	a,true
	ld	(D7A31),a
	push	hl
	call	A5082
	push	hl
	pop	iy
	ld	l,(iy+2)
	ld	h,0
	pop	de
	ld	a,l
	ld	(D7A26),a
	cp	75h
	jr	nz,A64EB
	ld	l,(iy+0)
	ld	h,(iy+1)
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	push	de
	ld	bc,T6520		; Yundeclared identifier "S"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret
	;
A64EB:	cp	65h
	jr	nz,A64F4
	ld	hl,0			; false?
	ret
A64F4:	push	iy
	ld	bc,T653B		; "	%v"
	push	bc
	call	A4ABC
	pop	bc
	pop	iy
	ld	c,(iy+5)
	ld	b,(iy+6)
	inc	bc
	inc	bc
	ld	a,(bc)
	cp	9
	jr	z,A6515
	cp	0Ah
	jr	z,A6515
	cp	0Dh
	jr	nz,A6519
A6515:	xor	a			; false?
	ld	(D7A31),a
A6519:	ld	l,(iy+5)
	ld	h,(iy+6)
	ret


A653F:	xor	a			; false
	ld	(D7A31),a
	push	hl
	ld	a,9
	call	A498B
	ld	a,"#"			; 23h
	call	A498B
	pop	hl
	call	A5082
	ld	a,(hl)
	cp	21h
	jr	z,A6570
	push	af
	push	hl
	call	A498B
	pop	hl
	inc	hl
	ld	b,4
	call	A6583
	pop	af
	cp	23h
	jr	z,A657B
	ld	bc,72			; 0048h
	ld	hl,(D77DF)
	add	hl,bc
	ret
A6570:	push	hl
	call	A498B
	pop	hl
	inc	hl
	ld	b,8
	call	A6583
A657B:	ld	hl,(D77DF)
	ld	bc,99			; 0063h
	add	hl,bc
	ret
	;
A6583:	push	bc
	push	hl
	ld	a,(hl)
	call	A658F
	pop	hl
	inc	hl
	pop	bc
	djnz	A6583
	ret
	;
A658F:	push	af
	rrca
	rrca
	rrca
	rrca
	call	A6598
	pop	af
A6598:	and	0Fh
	add	a,"0"
	cp	"9"+1
	jp	c,A498B
	add	a,7
	jp	A498B


A65A6:	call	A65C0
	bit	7,b
	jr	nz,A65BF
	ld	hl,(D78BA)
	ret
A65BF:	ld	hl,(D78B8)
	ret

A65C0:	xor	a			; false
	ld	(D7A31),a
	call	A5082
	push	hl
	ld	bc,T65DC		; "	#%u"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	ret


A65C3:	call	A65C0
	ld	hl,(D77DF)
	ld	bc,63			; 003Fh
	add	hl,bc
	ret


A65E1:	xor	a			; false
	ld	(D7A31),a
	ld	bc,T6640		; '	"'
	push	hl
	push	bc
	call	A4ABC
	pop	bc
	pop	hl
	call	A5082
	push	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D7A32),hl
	pop	hl
	inc	hl
	inc	hl
	ld	(D7A34),hl
A6600:	ld	hl,(D7A34)
	ld	a,(hl)
	inc	hl
	ld	(D7A34),hl
	ld	c,a
	ld	b,0
	push	bc
	ld	bc,T6643		; "%u"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	ld	hl,(D7A32)
	dec	hl
	ld	(D7A32),hl
	ld	a,l
	or	h
	jr	z,A662C
	ld	bc,T6646		; ","
	push	bc
	call	A4ABC
	pop	bc
	jr	A6600
	;
A662C:	ld	bc,T6648		; "'	a"
	push	bc
	call	A4ABC
	pop	bc
	ld	bc,(D78B4)
	ld	de,0
	ld	a,8
	jp	A1D2E


A664C:	xor	a			; false
	ld	(D7A31),a
	call	A5082
	push	hl
	ld	bc,T6661		; "	#%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	ld	hl,(D78BA)
	ret


A6684:	push	hl
	push	bc
	call	A755F
	xor	a
	ld	(D7A36),a
	push	hl
	call	A5082
	call	A742E
	ex	de,hl
	ld	hl,2
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	ld	a,e
	or	d
	jr	nz,A66A8
	ld	hl,0
	jp	A673A
	;
A66A8:	ld	a,(D7A31)		; false/true
	or	a
	jr	nz,A66BC
	push	hl
	ld	bc,T6666		; "YL"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	jp	A673A
	;
A66BC:	xor	a			; false
	ld	(D7A31),a
	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	dec	a
	jr	nz,A66D6
	ld	bc,T6669		; "	#1"
	push	bc
	call	A4ABC
	pop	bc
	jr	A66FC
	;
A66D6:	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	8
	jr	nz,A66F6
	ld	hl,5
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,T666D		; "	#%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	jr	A66FC
	;
A66F6:	call	A4DFB
	jr	A673A
	;
A66FC:	call	A7590
	call	A5079
	ld	a,l
	; switch
	cp	30h
	jr	z,A6715
	cp	31h
	jr	z,A671A
	cp	38h
	jr	z,A671F
	jr	A6724			; default
	;
A6715:	ld	de,T6672		; ";+"
	jr	A6727
	;
A671A:	ld	de,T6675		; ";-"
	jr	A6727
	;
A671F:	ld	de,T6678		; ":+"
	jr	A6727
	;
A6724:	ld	de,T667B		; ":-"
A6727:	push	de
	call	A7590
	pop	de
	push	hl
	push	hl
	push	de
	ld	bc,T667E		; "	%s%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	pop	hl
A673A:	pop	bc
	pop	bc
	ret


A673D:	push	hl
	pop	de
	push	hl
	call	A5082
	call	A742E
	ld	a,l
	or	h
	jr	z,A678A
	xor	a			; false
	ld	(D7A31),a
	ld	de,(D78B4)
	call	A617E
	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	dec	a
	jr	nz,A6785
	push	de
	push	de
	call	A758A
	call	A5079
	ld	a,l
	sub	3Ah
	or	h
	jr	nz,A6773
	ld	a,5Fh
	jr	A6775
	;
A6773:	ld	a,7Eh
A6775:	ld	l,a
	push	hl
	ld	bc,T6A60		; "	%c%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	pop	hl
	jr	A678A
	;
A6785:	pop	hl
	push	hl
	call	A4DFB
A678A:	pop	bc
	ret


A678C:	push	hl
	pop	de
	push	hl
	xor	a
	ld	(D7A36),a
	call	A5082
	call	A742E
	ld	a,l
	or	h
	jr	nz,A67A4
	ld	hl,0
	jr	A67C1
A67A4:	xor	a			; false
	ld	(D7A31),a
	call	A6194
	ld	a,l
	or	h
	jr	nz,A67B7
	pop	hl
	push	hl
	call	A4DFB
	jr	A67C1
A67B7:	ld	bc,T67C3		; "	n"
	push	hl
	push	bc
	call	A4ABC
	pop	bc
	pop	hl
A67C1:	pop	bc
	ret


A67C6:	xor	a
	ld	(D7A36),a
	push	hl
	call	A5082
	call	A742E
	call	A63D4
	pop	de
	ld	a,l
	or	h
	ret	z
	ld	a,true
	ld	(D7A31),a
	push	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	pop	hl
	cp	8
	jr	z,A67F2
	push	de
	ld	bc,T6805		; "YBindirection"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ret
A67F2:	push	hl
	ld	bc,T6813		; "	@"
	push	bc
	call	A4ABC
	pop	bc
	pop	hl
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret


A6819:	push	hl
	call	A5082
	call	A742E
	pop	de
	ld	a,l
	or	h
	ret	z
	ld	a,(D7A31)		; false/true
	or	a
	jr	nz,A6836
	push	de
	ld	bc,T6816		; "YL"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ret
A6836:	xor	a			; false
	ld	(D7A31),a
	ld	bc,T63F5		; "	a"
	push	hl
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	ld	de,0
	ld	a,8
	jp	A1D2E


A684C:	ld	a,(D78BC)
	dec	a
	jr	nz,A6881
	push	hl
	call	A5082
	call	A742E
	ld	de,(D78B4)
	call	A617E
	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	9
	jr	z,A6870
	cp	0Ah
	jr	nz,A687B
A6870:	push	hl
	ld	bc,T6896		; "Ysizeof(func) not permitted"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ret
A687B:	call	A505C
	jr	A688E
	;
A6881:	call	A506A
	push	hl
	ld	bc,T68B2		; "	#%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
A688E:	xor	a			; false
	ld	(D7A31),a
	ld	hl,(D78BA)
	ret


A68B7:	push	bc
	xor	a
	ld	(D7A36),a
	push	hl
	call	A5082
	ex	de,hl
	ld	hl,2
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	dec	a
	jr	z,A68E2
	cp	7
	jr	z,A68E2
	push	hl
	ld	bc,T6929		; "YBcast"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	jr	A6927
	;
A68E2:	push	hl
	push	de
	call	A508D
	call	A742E
	pop	de
	pop	bc
	ld	a,l
	or	h
	jr	nz,A68F7
	ld	hl,0
	jr	A6927
	;
A68F7:	push	bc
	xor	a			; false
	ld	(D7A31),a
	call	A617E
	call	A63F8
	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	bc
	dec	a
	jr	z,A691D
	cp	7
	jr	z,A691D
	push	bc
	ld	bc,T6930		; "YBtype in cast"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	jr	A6927
A691D:	push	de
	call	A7590
	pop	de
	push	hl
	call	A6297
	pop	hl
A6927:	pop	bc
	ret


A693F:	push	bc
	ld	c,e
	ld	b,d
	ex	de,hl
	pop	hl
	ld	a,e
	or	d
	jr	z,A6962
	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	dec	a
	jr	z,A6962
	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	8
	jr	nz,A697B
A6962:	ld	a,c
	or	b
	jr	z,A6980
	push	hl
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	pop	hl
	dec	a
	jr	z,A6980
	push	hl
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	pop	hl
	cp	8
	jr	z,A6980
A697B:	call	A4DFB
	xor	a			; false?
	ret
A6980:	ld	a,e
	or	d
	ret	z
	ld	a,c
	or	b
	ret	z
	ld	a,true
	ret


A6989:	ld	(D7A39),de
	ld	(D7A37),hl
	push	bc
	push	hl
	call	A5079
	ld	a,l
	ld	(D7A3B),a
	pop	hl
	call	A5079
	ld	l,h
	ld	h,0
	ld	a,(D7A3B)
	ld	e,a
	pop	bc
	ld	a,h
	or	a
	jp	nz,A6A5A
	ld	a,l
	cp	2Dh
	jr	z,A6A02
	cp	2Bh
	jp	nz,A6A5A
	ld	hl,(D7A39)
	push	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	pop	hl
	cp	8
	jr	nz,A69E7
	push	hl
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	pop	hl
	cp	8
	jr	nz,A69D3
	ld	hl,(D7A37)
	jp	A4DFB
	;
A69D3:	push	hl
	ld	b,e
	ld	c,0
	ld	a,c
	or	0C6h
	ld	c,a
	ld	hl,(D7A37)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	hl
	ret
A69E7:	ld	a,e
	cp	0C5h
	jr	nz,A69F3
	ld	hl,(D7A37)
	jp	A4DFB
	;
A69F3:	ld	hl,(D7A37)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(hl),0C7h
	inc	hl
	ld	(hl),0C1h
	ld	l,c
	ld	h,b
	ret


A6A02:	ld	hl,(D7A39)
	push	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	pop	hl
	cp	8
	jr	nz,A6A5A
	push	hl
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	pop	hl
	cp	8
	jr	nz,A6A46
	ld	a,e
	cp	0C5h
	jr	nz,A6A27
	ld	hl,(D7A37)
	jp	A4DFB
	;
A6A27:	ld	e,c
	ld	d,b
	call	A1E15
	or	a
	jr	z,A6A40
	ld	hl,(D7A37)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(hl),0BEh
	inc	hl
	ld	(hl),0
	ld	hl,(D78B2)
	ret
A6A40:	ld	hl,(D7A37)
	jp	A4DFB
	;
A6A46:	ld	b,e
	ld	c,0
	ld	a,c
	or	0BFh
	ld	c,a
	push	hl
	ld	hl,(D7A37)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	hl
	ret
A6A5A:	ld	hl,(D7A37)
	jp	A4DFB


;++T6A60:	db	9,"%c%t",0


A6A66:	push	hl
	push	bc
	push	bc
	push	bc
	call	A754D
	push	hl
	call	A5079
	ld	a,h
	pop	hl
	push	af
	push	hl
	call	A5082
	call	A742E
	call	A63D4
	ld	a,(D7A31)		; false/true
	or	a
	jr	z,A6A89
	xor	a
	ld	(D7A36),a
A6A89:	ld	a,(D78BC)
	call	A7553
	pop	hl
	push	hl
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	pop	bc
	ld	c,b
	dec	a
	jr	nz,A6B0E
	push	hl
	call	A508D
	call	A742E
	call	A63D4
	ld	a,(D7A31)		; false/true
	or	a
	jr	z,A6AB4
	xor	a
	ld	(D7A36),a
;A6AB4:	xor	a			; false
	ld	(D7A31),a
A6AB4:	pop	bc
	push	hl
	ex	de,hl
	push	de
	call	A758A
	pop	de
	push	de
	call	A7553
	pop	de
	call	A693F
	pop	de
	push	de
	call	A7590
	pop	de
	or	a
	jr	nz,A6AD8
	ld	hl,0
	jp	A6B5F
	;
A6AD8:	push	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	pop	hl
	cp	8
	jr	z,A6AEE
	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	8
	jr	nz,A6AFC
A6AEE:	ld	c,e
	ld	b,d
	ex	de,hl
	push	de
	call	A7578
	pop	de
	call	A6989
	jr	A6B5F
	;
A6AFC:	call	A6249
	call	A755F
	ex	de,hl
	push	de
	call	A7578
	pop	de
	call	A505C
	jr	A6B5C
	;
A6B0E:	push	hl
	ld	hl,6
	add	hl,sp
	ld	(hl),c
	pop	hl
	push	hl
	ld	hl,2
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	push	hl
	call	A506A
	call	A7553
	push	hl
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	pop	bc
	push	hl
	push	bc
	call	A63B4
	pop	hl
	push	hl
	call	A508D
	call	A742E
	call	A63D4
	ex	de,hl
	pop	bc
	pop	hl
	push	hl
	call	A63B4
	xor	a			; false
	ld	(D7A31),a
	pop	hl
	push	hl
	ld	hl,6
	add	hl,sp
	ld	c,(hl)
	push	bc
	ld	bc,T6A60		; "	%c%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
A6B5C:	call	A7590
A6B5F:	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret


;++T6B64:	db	9,"R%t",9,"#%t",9,"*R",9,0
;T6B71:	db	":",0
;T6B73:	db	"-R",0
;T6B76:	db	"+R",0


A6B79:	push	hl
	push	bc
	push	bc
	call	A7553
	call	A5079
	ld	a,l
	push	af
	call	A7584
	push	hl
	cp	0C6h
	jr	z,A6B92
	cp	0BFh
	jr	nz,A6BA9
A6B92:	push	hl
	call	A5082
	call	A742E
	call	A63D4
	call	A754D
	pop	hl
	call	A508D
	call	A742E
	jr	A6BBD
	;
A6BA9:	push	hl
	call	A508D
	call	A742E
	call	A63D4
	call	A754D
	pop	hl
	call	A5082
	call	A742E
A6BBD:	xor	a			; false
	ld	(D7A31),a
	call	A754D
	call	A758A
	call	A7553
	ld	bc,5
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	call	A7578
	push	hl
	ld	bc,T6B64		; "	R%t	#%t	*R	"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	pop	hl
	call	A5079
	ld	a,h
	cp	0C5h
	jr	nz,A6BF2
	ld	bc,T6B71		; ":"
	push	bc
	call	A4ABC
	pop	bc
A6BF2:	pop	af
	cp	0BFh
	jr	nz,A6BFE
	ld	hl,T6B73		; "-R"
	jr	A6C01
	;
A6BFE:	ld	hl,T6B76		; "+R"
A6C01:	push	hl
	call	A4ABC
	pop	bc
	pop	hl
	push	hl
	pop	bc
	pop	bc
	pop	bc
	ret


;++T6C0C:	db	9,"IR",0
;T6C10:	db	9,"IR",9,"-I",9,"#%t",9,"/I",0


A6C1E:	push	bc
	push	hl
	call	A5082
	call	A742E
	call	A63D4
	ld	bc,T6C0C		; "	IR"
	push	bc
	call	A7553
	call	A4ABC
	pop	bc
	pop	hl
	call	A508D
	call	A742E
	call	A63D4
	pop	hl
	push	hl
	ld	bc,5
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,T6C10		; "	IR	-I	#%t	/I"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	xor	a			; false
	ld	(D7A31),a
	ld	hl,(D78B2)
	pop	bc
	ret


A6C5A:	push	hl
	pop	de
	push	hl
	push	hl
	call	A5082
	call	A742E
	ld	de,(D78B4)
	call	A617E
	push	hl
	call	A758A
	call	A508D
	call	A742E
	ld	de,(D78B4)
	call	A617E
	ex	de,hl
	pop	bc
	pop	hl
	ld	a,c
	or	b
	jr	z,A6C89
	ld	a,e
	or	d
	jr	nz,A6C8F
A6C89:	ld	hl,0
	jp	A6D08
	;
A6C8F:	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	8
	jr	z,A6CA7
	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	0Dh
	jr	nz,A6CB8
A6CA7:	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(hl),0CCh
	inc	hl
	ld	(hl),0
	ex	de,hl
	ld	e,c
	ld	d,b
	ld	c,l
	ld	b,h
	jr	A6CC1
A6CB8:	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(hl),0CBh
	inc	hl
	ld	(hl),0
A6CC1:	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	cp	8
	jr	z,A6CD5
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	cp	0Dh
	jr	nz,A6D03
A6CD5:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	dec	a
	jr	nz,A6D03
	ld	hl,5
	add	hl,bc
	ld	e,c
	ld	d,b
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	ld	a,(bc)
	cp	0Dh
	jr	z,A6CF4
	ld	a,true
	jr	A6CF5
A6CF4:	xor	a			; false
A6CF5:	ld	(D7A31),a
	ld	hl,5
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A6D08
A6D03:	pop	hl
	push	hl
	call	A4DFB
A6D08:	pop	bc
	ret


;++T6D0A:	db	9,"@",0
;T6D0D:	db	9,"R%t",9,"#%t",9,"*R",9,"'",0


A6D1B:	push	bc
	push	bc
	push	hl
	call	A5079
	ld	a,l
	pop	hl
	cp	0CBh
	jr	nz,A6D53
	push	hl
	call	A5082
	call	A742E
	call	A755F
	inc	hl
	inc	hl
	ld	a,(hl)
	cp	8
	jr	nz,A6D42
	ld	bc,T6D0A		; "	@"
	push	bc
	call	A4ABC
	pop	bc
A6D42:	pop	hl
	call	A508D
	call	A742E
	ld	de,(D78B4)
	call	A617E
	jr	A6D7B
A6D53:	push	hl
	call	A508D
	call	A742E
	call	A755F
	inc	hl
	inc	hl
	ld	a,(hl)
	cp	8
	jr	nz,A6D6D
	ld	bc,T6D0A		; "	@"
	push	bc
	call	A4ABC
	pop	bc
A6D6D:	pop	hl
	call	A5082
	call	A742E
	ld	de,(D78B4)
	call	A617E
A6D7B:	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	push	de
	call	A7553
	pop	de
	ld	hl,5
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	ld	a,(bc)
	cp	0Dh
	jr	z,A6D9D
	ld	a,1
	jr	A6D9E
A6D9D:	xor	a			; false
A6D9E:	ld	(D7A31),a
	ld	hl,5
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	de
	push	bc
	call	A7584
	push	hl
	ld	bc,T6D0D		; "	R%t	#%t	*R	'"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	pop	de
	ld	hl,5
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	pop	bc
	pop	bc
	ret


A6DC4:	push	bc
	push	bc
	push	bc
	push	hl
	call	A5079
	ld	a,h
	pop	hl
	push	af
	push	hl
	call	A5082
	call	A742E
	call	A63F8
	ld	a,(D7A31)		; false/true
	or	a
	jr	z,A6DE3
	xor	a
	ld	(D7A36),a
A6DE3:	ld	a,(D78BC)
	call	A7553
	pop	hl
	push	hl
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	pop	bc
	ld	c,b
	dec	a
	jr	nz,A6E3B
	push	hl
	call	A508D
	call	A742E
	call	A63F8
	ld	a,(D7A31)		; false/true
	or	a
	jr	z,A6E0E
	xor	a
	ld	(D7A36),a
;A6E0E:	xor	a			; false
	ld	(D7A31),a
A6E0E:	pop	bc
	push	hl
	ex	de,hl
	push	de
	call	A758A
	pop	de
	push	bc
	call	A693F
	pop	hl
	pop	de
	or	a
	jr	nz,A6E2A
	ld	hl,(D78B6)
	jr	A6E91
A6E2A:	push	hl
	push	de
	call	A758A
	pop	de
	call	A6249
	ex	de,hl
	pop	hl
	call	A505C
	jr	A6E8E
A6E3B:	push	hl
	ld	hl,6
	add	hl,sp
	ld	(hl),c
	pop	hl
	push	hl
	ld	hl,2
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	push	hl
	call	A506A
	push	hl
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	pop	bc
	push	bc
	push	de
	call	A754D
	pop	de
	call	A63B4
	pop	hl
	push	hl
	call	A508D
	call	A742E
	call	A63F8
	ex	de,hl
	pop	bc
	push	de
	call	A758A
	pop	de
	push	hl
	call	A63B4
	xor	a			; false
	ld	(D7A31),a
	pop	hl
	push	hl
	ld	hl,6
	add	hl,sp
	ld	c,(hl)
	push	bc
	ld	bc,T6A60		; "	%c%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
A6E8E:	ld	hl,(D78B6)
A6E91:	pop	bc
	pop	bc
	pop	bc
	ret


A6E95:	push	hl
	push	bc
	push	bc
	xor	a
	ld	(D7A36),a
	push	hl
	call	A5079
	ld	a,h
	ld	hl,4
	add	hl,sp
	ld	(hl),a
	pop	hl
	push	hl
	call	A5082
	call	A742E
	call	A63F8
	call	A6194
	ex	de,hl
	pop	hl
	pop	bc
	push	de
	call	A508D
	call	A742E
	call	A63F8
	call	A6194
	xor	a			; false
	ld	(D7A31),a
	ld	b,h
	ld	c,l
	ld	hl,(D78B6)
	pop	de
	push	de
	sbc	hl,de
	jr	nz,A6EDB
	ld	hl,(D78B6)
	or	a
	sbc	hl,bc
	jr	z,A6EE4
A6EDB:	call	A758A
	call	A4DFB
	jr	A6EF7
	;
A6EE4:	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	ld	c,a
	push	bc
	ld	bc,T6EFB		; "	%c"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	ld	hl,(D78B6)
A6EF7:	pop	bc
	pop	bc
	pop	bc
	ret

;++T6EFB:	db	9,"%c",0


A6EFF:	push	hl
	push	bc
	push	bc
	push	hl
	call	A5079
	ld	a,h
	pop	hl
	push	af
	call	A5082
	call	A742E
	ld	de,(D78B4)
	call	A617E
	call	A6421
	call	A755F
	ld	a,(D7A31)		; false/true
	or	a
	jr	z,A6F27
	xor	a
	ld	(D7A36),a
A6F27:	ld	a,(D78BC)
	pop	bc
	ld	c,b
	dec	a
	jr	nz,A6F99
	pop	de
	push	hl
	call	A758A
	push	hl
	call	A508D
	call	A742E
	push	hl
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	push	de
	call	A617E
	ld	c,l
	ld	b,h
	ld	a,(D7A31)		; false/true
	or	a
	jr	z,A6F56
	xor	a
	ld	(D7A36),a
;A6F56:	xor	a			; false
	ld	(D7A31),a
A6F56:	pop	de
	pop	hl
	ld	a,e
	or	d
	jr	z,A6F72
	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	dec	a
	jr	z,A6F72
	call	A4DFB
	jr	A6FCA
	;
A6F72:	ld	a,c
	or	b
	jr	z,A6F89
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	dec	a
	jr	z,A6F89
	call	A758A
	call	A4DFB
	jr	A6FCA
	;
A6F89:	ld	a,e
	or	d
	jr	z,A6F93
	ld	a,c
	or	b
	jr	nz,A6FC8
A6F93:	ld	hl,0
	jr	A6FCA
	;
A6F99:	push	hl
	ld	hl,4
	add	hl,sp
	ld	(hl),c
	pop	hl
	push	hl
	call	A7584
	push	hl
	call	A508D
	call	A742E
	ex	de,hl
	pop	bc
	pop	hl
	push	hl
	call	A63B4
	xor	a			; false
	ld	(D7A31),a
	pop	hl
	push	hl
	ld	hl,4
	add	hl,sp
	ld	c,(hl)
	push	bc
	ld	bc,T6A60		; "	%c%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
A6FC8:	pop	hl
	push	hl
A6FCA:	pop	bc
	pop	bc
	pop	bc
	ret


A6FCE:	push	hl
	push	bc
	push	bc
	xor	a
	ld	(D7A36),a
	ld	(D7A26),a
	push	hl
	call	A5079
	ld	a,h
	ld	hl,4
	add	hl,sp
	ld	(hl),a
	pop	hl
	push	af
	push	hl
	call	A5082
	call	A742E
	ld	a,(D78BC)
	call	A7553
	pop	hl
	push	hl
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	pop	bc
	ld	c,b
	dec	a
	jr	nz,A7067
	ld	a,(D7A26)
	push	hl
	cp	4Bh
	jr	z,A700F
	ld	a,(D7A31)		; false/true
	or	a
	jr	nz,A7019
A700F:	push	hl
	ld	bc,T70C9		; "YL"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
A7019:	pop	hl
	push	hl
	call	A508D
	call	A742E
	call	A63F8
	xor	a			; false
	ld	(D7A31),a
	pop	bc
	push	hl
	ex	de,hl
	push	de
	call	A758A
	pop	de
	push	hl
	call	A693F
	pop	de
	pop	bc
	or	a
	jr	nz,A7040
	ld	hl,0
	jp	A70C5
	;
A7040:	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	cp	3Ah
	jr	z,A70C3
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	8
	jr	z,A705C
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	cp	8
	jr	nz,A70C3
A705C:	push	de
	call	A7584
	pop	de
	call	A6989
	jr	A70C5
	;
A7067:	push	hl
	ld	hl,4
	add	hl,sp
	ld	(hl),c
	pop	hl
	push	hl
	ld	hl,2
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	push	de
	call	A754D
	pop	de
	push	de
	call	A508D
	call	A742E
	call	A63F8
	push	hl
	ld	hl,8
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	pop	de
	call	A63B4
	xor	a			; false
	ld	(D7A31),a
	ld	hl,4
	add	hl,sp
	ld	c,(hl)
	ld	a,c
	pop	de
	cp	3Ah
	jr	z,A70B9
	push	de
	push	bc
	ld	bc,T70CC		; "	:%c%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	jr	A70C3
A70B9:	push	de
	ld	bc,T70D3		; "	:%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
A70C3:	pop	hl
	push	hl
A70C5:	pop	bc
	pop	bc
	pop	bc
	ret


A70D8:	xor	a
	ld	(D7A36),a
	push	hl
	call	A5082
	call	A3700
	call	A742E
	pop	hl
	call	A508D
	call	A742E
	ld	bc,T70FC		; "	,"
	push	hl
	push	bc
	call	A4ABC
	pop	bc
	xor	a			; false
	ld	(D7A31),a
	pop	hl
	ret

;++T70FC:	db	9,",",0


A70FF:	push	hl
	push	bc
	call	A755F
	xor	a
	ld	(D7A36),a
	push	hl
	call	A5082
	call	A742E
	ex	de,hl
	ld	a,true
	ld	(D7A31),a
	pop	hl
	ld	a,e
	or	d
	jr	nz,A7121
	ld	hl,0
	jp	A71C9
	;
A7121:	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	0Bh
	jr	z,A713F
	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	0Ch
	jr	z,A713F
	call	A4DFB
	jp	A71C9
	;
A713F:	push	de
	call	A508D
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,2Eh			; "."
	call	A085F
	ex	de,hl
	ld	hl,2
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	de
	ld	hl,5
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	hl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
A7169:	ld	a,l
	or	h
	jr	z,A71B5
	ld	a,(hl)
	cp	e
	inc	hl
	jr	nz,A7176
	ld	a,(hl)
	cp	d
A7176:	dec	hl
	jr	nz,A71AA
	push	hl
	inc	hl
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,T71CC		; "	M%u	."
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	de
	ld	hl,5
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	ld	a,(bc)
	cp	0Dh
	jr	nz,A719F
	xor	a			; false
	ld	(D7A31),a
A719F:	ld	hl,5
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A71C9
	;
A71AA:	ld	bc,7
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A7169
	;
A71B5:	ex	de,hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	push	bc
	call	A758A
	push	hl
	ld	bc,T71D3		; Yundeclared member name "S"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	pop	bc
A71C9:	pop	bc
	pop	bc
	ret



A71EF:	push	hl
	call	A742E
	call	A63F8
	ld	de,(D78B4)
	call	A617E
	call	A6421
	ex	de,hl
	pop	hl
	ld	a,e
	or	d
	jr	nz,A720B
	ld	hl,0			; false?
	ret
A720B:	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	dec	a
	jr	z,A722D
	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	8
	jr	z,A722D
	push	hl
	ld	bc,T7326		; "YBparameter type"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
	ret
A722D:	push	de
	push	de
	ld	bc,T7337		; "	p%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
	pop	hl
	ret


A723A:	push	hl
	push	bc
	call	A5079
	ld	a,l
	sub	0B8h
	or	h
	jr	z,A7259
	call	A7590
	call	A71EF
	ld	a,l
	or	h
A724D:	jr	z,A7254
	ld	hl,1
	jr	A727A
	;
A7254:	ld	hl,-1
	jr	A727A
	;
A7259:	call	A7590
	push	hl
	call	A5082
	call	A723A
	call	A755F
	pop	hl
	call	A508D
	call	A71EF
	pop	de
	push	de
	ld	a,l
	or	h
	jr	z,A7254
	ld	a,e
	and	d
	inc	a
	jr	z,A7279
	inc	de
A7279:	ex	de,hl
A727A:	pop	bc
	pop	bc
	ret


A727D:	push	hl
	push	bc
	push	bc
	xor	a
	ld	(D7A36),a
	call	A5082
	call	A742E
	ex	de,hl
	push	de
	push	de
	call	A7578
	pop	de
	push	hl
	ld	a,e
	or	d
	jr	z,A72AF
	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	9
	jr	z,A72AF
	cp	0Ah
	jr	z,A72AF
	push	hl
	ld	bc,T733C		; "Yfunction E"
	push	bc
	call	fprintf			; вывод строки на экран или в вых. файл
	pop	bc
	pop	bc
A72AF:	pop	hl
	call	A508D
	ld	a,l
	or	h
	jr	z,A72C2
	call	A7584
	call	A508D
	call	A723A
	jr	A72C5
	;
A72C2:	ld	hl,0
A72C5:	call	A755F
	pop	de
	ld	a,e
	or	d
	jr	z,A72DB
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	9
	jr	z,A72E0
	cp	0Ah
	jr	z,A72E0
A72DB:	ld	hl,0
	jr	A7322
	;
A72E0:	xor	a			; false
	ld	(D7A31),a
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	cp	9
	jr	nz,A72F1
	ld	a,46h
	jr	A72F3
	;
A72F1:	ld	a,55h
A72F3:	ld	l,a
	push	hl
	ld	hl,5
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A6421
	push	hl
	ld	bc,T7348		; "	c%t	%c"
	push	bc
	call	A7541
	call	A4ABC
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	push	bc
	inc	b
	dec	b
	jp	m,A731F
	push	bc
	ld	bc,T7350		; "%u"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
A731F:	call	A7590
A7322:	pop	bc
	pop	bc
	pop	bc
	ret


A7353:	push	hl
	push	bc
	push	bc
	push	hl
	call	A5082
	call	A742E
	ld	a,l
	or	h
	jr	z,A736E
	call	A6194
	ld	a,l
	or	h
	jr	nz,A736E
	call	A7584
	call	A4DFB
A736E:	ld	a,(D7A31)		; false/true
	or	a
	jr	z,A7378
	xor	a
	ld	(D7A36),a
A7378:	pop	hl
	push	hl
	call	A508D
	call	A742E
	call	A63F8
	ld	a,(D7A31)		; false/true
	or	a
	jr	z,A738D
	xor	a
	ld	(D7A36),a
A738D:	ld	a,(D78BC)
	call	A755F
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	dec	a
	jr	nz,A73E2
	push	hl
	call	A509E
	call	A742E
	call	A63F8
	ld	a,(D7A31)		; false/true
	or	a
	jr	z,A73B2
	xor	a
	ld	(D7A36),a
;A73B2:	xor	a			; false
	ld	(D7A31),a
A73B2:	pop	bc
	push	hl
	ex	de,hl
	push	de
	call	A758A
	pop	de
	push	bc
	call	A693F
	pop	hl
	pop	de
	or	a
	jr	nz,A73CE
	ld	hl,0
	jp	A7425
	;
A73CE:	push	hl
	push	de
	call	A758A
	pop	de
	call	A6249
	call	A7553
	ex	de,hl
	pop	hl
	call	A505C
	jp	A7422
	;
A73E2:	push	hl
	ld	hl,2
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	push	hl
	call	A506A
	call	A7553
	push	hl
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	pop	bc
	push	hl
	push	bc
	call	A63B4
	pop	hl
	push	hl
	call	A509E
	call	A742E
	call	A63F8
	ex	de,hl
	pop	bc
	pop	hl
	push	hl
	call	A63B4
	xor	a			; false
	ld	(D7A31),a
	pop	hl
	push	hl
	ld	bc,T7429		; "	?%t"
	push	bc
	call	A4ABC
	pop	bc
	pop	bc
A7422:	call	A7590
A7425:	pop	bc
	pop	bc
	pop	bc
	ret

;++T7429:	db	9,"?%t",0


A742E:	push	hl
	call	A5079
	ld	a,l
	pop	hl
	; switch
	cp	1
	jp	z,A64BA
	cp	3
	jp	z,A653F
	cp	2
	jp	z,A65A6
	cp	4
	jp	z,A65C3
	cp	5
	jp	z,A65E1
	cp	32h
	jp	z,A6C5A
	cp	0C5h
	jp	z,A6FCE
	cp	0C3h
	jp	z,A6E95
	cp	0C1h
	jp	z,A6A66
	cp	0CBh
	jp	z,A6D1B
	cp	0CCh
	jp	z,A6D1B
	cp	0C6h
	jp	z,A6B79
	cp	0C7h
	jp	z,A6B79
	cp	0BFh
	jp	z,A6B79
	cp	0BEh
	jp	z,A6C1E
	cp	8
	jp	z,A74E6
	cp	35h
	jp	z,A727D
	cp	33h
	jp	z,A727D
	cp	29h
	jp	z,A70FF
	cp	3Dh
	jp	z,A67C6
	cp	0B8h
	jp	z,A70D8
	cp	30h
	jp	z,A6684
	cp	31h
	jp	z,A6684
	cp	38h
	jp	z,A6684
	cp	39h
	jp	z,A6684
	cp	0C2h
	jp	z,A6DC4
	cp	3Eh
	jp	z,A6819
	cp	3Ah
	jp	z,A673D
	cp	3Ch
	jp	z,A673D
	cp	98h
	jp	z,A7353
	cp	0C4h
	jp	z,A6EFF
	cp	3Bh
	jp	z,A678C
	cp	6
	jp	z,A664C
	cp	3Fh
	jp	z,A684C
	cp	40h
	jp	z,A68B7
	jp	abort			; default, выход в ДОС
	;
A74E6:	call	A5082
	jp	A742E


A74EC:	ld	a,h
	xor	d
	jp	p,.loc1
	ld	a,d
	cp	h
	ret
.loc1:	ld	a,h
	cp	d
	ret	nz
	ld	a,l
	cp	e
	ret


A74FA:	inc	b
	dec	b
	ret	z
.loc1:	srl	h
	rr	l
	djnz	.loc1
	ret


A7504:	inc	b
.loc1:	dec	b
	ret	z
	add	hl,hl
	jr	.loc1


A750B:	ld	b,d
	ld	c,e
	ld	de,0
	ld	a,16
.loc1:	ex	af,af'
	add	hl,hl
	rl	e
	rl	d
	jr	c,.loc2
	ld	a,e
	sub	c
	ld	a,d
	sbc	a,b
	jr	c,.loc3
.loc2:	ld	a,e
	sub	c
	ld	e,a
	ld	a,d
	sbc	a,b
	ld	d,a
	inc	l
.loc3:	ex	af,af'
	dec	a
	jr	nz,.loc1
	ret


A752D:	ld	b,h
	ld	c,l
	ld	hl,0
	ld	a,16
.loc1:	add	hl,hl
	ex	de,hl
	add	hl,hl
	ex	de,hl
	jr	nc,.loc2
	add	hl,bc
.loc2:	dec	a
	jr	nz,.loc1
	ret


A7541:	ld	de,10
	jp	A7571
	;
A7547:	ld	de,9
	jp	A7571
	;
A754D:	ld	de,8
	jp	A7571
	;
A7553:	ld	de,6
	jp	A7571
	;
A7559:	ld	de,5
	jp	A7571
	;
A755F:	ld	de,4
	jp	A7571
	;
A7565:	ld	de,3
	jp	A7571
	;
A756B:	ex	(sp),hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ex	(sp),hl
A7571:	ex	de,hl
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ex	de,hl
	ret


A7578:	ld	hl,10
	jp	A75A3
	;
A757E:	ld	hl,9
	jp	A75A3
	;
A7584:	ld	hl,8
	jp	A75A3
	;
A758A:	ld	hl,6
	jp	A75A3
	;
A7590:	ld	hl,4
	jp	A75A3
	;
A7596:	ld	hl,3
	jp	A75A3
	;
A759C:	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	push	hl
	ex	de,hl
A75A3:	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ret




; Сохраняются заданные пути рабочих файлов
	; .c файл
dirs:	db	0			; диск
	ds	81 ;65			; путь
	; 1  include-файлы
	db	0
	ds	81 ;65
	; 2
	db	0
	ds	81 ;65
	; 3
	db	0
	ds	81 ;65
	; 4
	db	0
	ds	81 ;65
	; .tmc файл
	db	0
	ds	81 ;65
	; .err файл
	db	0			; диск
	ds	81 ;65			; путь




;=========================
;D75A9:	db	0
;	db	0,0			; не исп.?
;D75AC:	dw	0		; не исп.!	адрес имени файла
;D75AE:	dw	0		; не исп.!	индекс в таблице "L064E"
;D75B0:	dw	0

;D75B2:	dw	0			; сохр. адрес "r" или "w"
;	dw	0			; не исп.?
;==========================


; Таблица, 266 байт (38*7)
; Сохр. дескрипторы в первом байте
L75B6:	ds	38			; .c файл
L75DC:	ds	38			; include
L7602:	ds	38			; файлы
L7628:	ds	38			;
L764E:	ds	38			;
L7674:	ds	38			; .tmc файл
L769A:	ds	38			; .err файл

D76C1:	dw	0			; файл *.c и include-файлы
D76C3:	dw	0			; файл *.tmc
D76C5:	dw	0			; файл *.err



D76C7:	db	false			; флаг наличия ошибок компиляции
D76C8:	db	true
D76C9:	db	false			; строгая совместимость с MSX-C
D76CA:	db	true			; флаг допуст. вложения комментариев
D76CB:	db	false			; флаг вывода ошибок в файл *.err
;	db	0			; ячейка не исп.!
mode:	db	true			; Свой режим компилятора (не K&R), 1-я ячейка
D76CE:	db	false			; флаг вывода инфы по занятости памяти
;	db	0			; ячейка не исп.!
;D76D0:	db	false			; не исп. флаг "продолжить даже при ошибках"
;mode2:	db	true			; Свой режим компилятора (не K&R), 2-я ячейка
;D76D2:	db	0			; не исп.


; Отношение рабочих таблиц (по умолчанию 13:6:4)
D76D3:	dw	13			; размер пула
D76D5:	dw	6			; размер таблицы идентификаторов
D76D7:	dw	4			; размер хэш-таблицы

D76D9:	dw	1000			; 03E8
D76DB:	dw	start			; начало программы

D76DD:	dw	L8209+512		; L8409
D76DF:	dw	L8209+512		; L8409




tmc_filename:
	ds	81 ;65			; полное (disk+path+file.ext) имя .TMC файла
	;
D7722:	dw	0

c_filename:
	ds	81 ;65			; полное имя *.C файла

incl_filename:
	ds	256 ;81 ;65		; полное имя include-файла
	;
D77A6:	dw	incl_filename		; можно убрать



D77A8:	db	0			; 0/1  false/true ?
;	db	1			; не исп. !!

D77AA:	dw	A77AC

A77AC:	ds	30

D77CA:	dw	0			; начальный номер строки
D77CC:	dw	-1			; начальный номер колонки

D77CE:	dw	0
index:	dw	0			; индекс описателя файла
D77D2:	db	0
D77D3:	dw	0
D77D5:	dw	0
D77D7:	dw	0
D77D9:	dw	0
D77DB:	dw	0
D77DD:	dw	0
D77DF:	dw	0
D77E1:	dw	0
D77E3:	dw	0
D77E5:	dw	0
D77E7:	dw	0
D77E9:	dw	0
D77EB:	dw	0
D77ED:	dw	0
D77EF:	db	0
D77F0:	db	0
D77F1:	db	0,0,0,0,0,0

D77F7:	dw	0			; номер колонки
D77F9:	dw	0			; номер строки

D77FB:	dw	0
D77FD:	dw	0
D77FF:	db	0,0,0
;D7802:	dw	0

D7804:	dw	0			; для "define"
D7806:	dw	0			; для "undef"
D7808:	dw	0			; для "include"
D780A:	dw	0			; для "ifdef"
D780C:	dw	0			; для "ifndef"
D780E:	dw	0			; для "else"
D7810:	dw	0			; для "endif"
D7812:	dw	0			; для "pragma"
D7814:	dw	0			; для "nonrec"
D7816:	dw	0			; для "recursive"
D7818:	dw	0			; для "optimize"
D781A:	dw	0			; для "time"
D781C:	dw	0			; для "size"
D781E:	dw	0			; для "line"
D7820:	dw	0			; для "error"

A7822:	ds	42

D784C:	dw	0
D784E:	dw	0
D7850:	db	0
D7851:	db	0

A7852:	ds	40

D787A:	db	0
D787B:	dw	0
D787D:	dw	0
D787F:	db	0

A7880:	ds	40			; число отслеживается (ldir)

D78A8:	db	0
D78A9:	db	0
D78AA:	db	0
D78AB:	db	0			; раб. ячейка обработки комментариев
D78AC:	dw	0
D78AE:	dw	0

D78B0:	dw	0
D78B2:	dw	0
D78B4:	dw	0
D78B6:	dw	0
D78B8:	dw	0
D78BA:	dw	0

D78BC:	db	0
D78BD:	db	0
D78BE:	dw	0
D78C0:	dw	0
D78C2:	dw	0
D78C4:	dw	0
D78C6:	dw	0
D78C8:	db	0
D78C9:	dw	0
D78CB:	dw	0
D78CD:	dw	0
D78CF:	dw	0
D78D1:	dw	0
D78D3:	dw	0
D78D5:	db	0
D78D6:	dw	0
D78D8:	dw	0
D78DA:	dw	0
D78DC:	dw	0
D78DE:	dw	0
D78E0:	db	0
D78E1:	db	false
D78E2:	dw	0
D78E4:	db	0
D78E5:	dw	0
D78E7:	dw	0
D78E9:	db	0
D78EA:	db	0
D78EB:	db	0
D78EC:	dw	0
D78EE:	db	0
D78EF:	dw	0
D78F1:	dw	0
D78F3:	dw	0
D78F5:	db	0
D78F6:	db	0
D78F7:	dw	0
D78F9:	dw	0
D78FB:	dw	0
D78FD:	dw	0
D78FF:	dw	0
D7901:	dw	0
D7903:	dw	0
D7905:	dw	0
D7907:	db	0
D7908:	dw	0
D790A:	dw	0
D790C:	db	false			; флаг типа long/float/double (зарез. на будущее)
T790D:	db	0
T790E:	dw	0
T7910:	dw	0

T7912:	db	0,0,0,0,0,0
T7918:	db	0
T7919:	db	0,0,0,0,0,0
T791F:	db	0
T7920:	db	0,0,0,0,0,0,0

T7927:	ds	14

T7935:	ds	170

D79DF:	dw	0
D79E1:	dw	0
D79E3:	dw	0

max_errors:
	dw	25			; 100, ячейка макс. числа ошибок
errors:	dw	0			; текущее число ошибок компиляции

D79E9:	dw	0

D79EB:	dw	0			; hash N/N  2-е число

D79ED:	db	0
;D79EE:	db	0			; для fprintf
D79EF:	dw	0
D79F1:	dw	0
D79F3:	dw	0
D79F5:	dw	0
D79F7:	dw	0
D79F9:	dw	0
D79FB:	dw	0
D79FD:	dw	0
D79FF:	db	0
D7A00:	dw	0
D7A02:	dw	0
D7A04:	dw	0
D7A06:	db	0
D7A07:	dw	0
D7A09:	dw	0
D7A0B:	dw	0
D7A0D:	db	0
D7A0E:	db	0
D7A0F:	dw	0
D7A11:	dw	0
D7A13:	dw	0
D7A15:	dw	0
D7A17:	dw	0
D7A19:	dw	0
D7A1B:	db	0
D7A1C:	dw	0
D7A1E:	dw	0
D7A20:	dw	0
D7A22:	dw	0
D7A24:	dw	0
D7A26:	db	0
D7A27:	dw	0
D7A29:	dw	0
D7A2B:	dw	0
D7A2D:	dw	0
D7A2F:	dw	0
D7A31:	db	false
D7A32:	dw	0
D7A34:	dw	0
D7A36:	db	0
D7A37:	dw	0
D7A39:	dw	0

D7A3B:	ds	81




; Начало программы
start:	ld	(L0080),hl		; сохр. адрес ком-строки
	ld	sp,Stack
	ld	hl,Exit			; 0  ??
	push	hl			;; не убирать
	push	hl			;;
	call	save_path		; сохр. тек. путь
	jp	A8122



; Выделение и иниц. памяти для буферов ?
;
A7CF8:	ld	hl,L8F09		; L9009-256  размер буферов
	ld	a,(D76CB)		; вывод ошибок в файл
	or	a
	jr	z,A7D04			; false
	ld	hl,L9009		; L8209+3584  размер буферов
A7D04:	ld	(D818F),hl
	push	hl
	ld	hl,0
	add	hl,sp
	push	hl
	ld	hl,(D76D9)		; 1000
	ld	de,(D818F)
	add	hl,de
	ld	bc,1000			; 
	add	hl,bc
	pop	de
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A7D2E
	; мало памяти
	ld	hl,T7CE0		; "Not enough memory"
	call	A0170			; вывод строки на экран
	jp	abort			; было "call", выход в ДОС
	;
A7D2E:	ld	hl,0
	add	hl,sp
	pop	de
	push	de
	or	a
	sbc	hl,de
	ld	de,(D76D9)		; 1000
	sbc	hl,de
	push	hl
	ld	hl,(D76D5)		; размер таблицы идентификаторов
	ld	de,(D76D3)		; размер пула
	add	hl,de
	ld	de,(D76D7)		; размер хэш-таблицы
	add	hl,de
	ex	de,hl
	pop	hl
	call	A750B
	ld	e,l
	ld	d,h
	push	hl
	ld	hl,(D76D3)		; размер пула
	call	A752D
	ld	(D76D3),hl		; размер пула
	pop	de
	ld	hl,(D76D5)		; размер таблицы идентификаторов
	push	de
	call	A752D
	ld	de,9
	call	A750B
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	(D76D5),hl		; размер таблицы идентификаторов
	pop	de
	ld	hl,(D76D7)		; размер хэш-таблицы
	call	A752D
	ld	a,l
	and	0FCh			; -4
	ld	l,a
	ld	(D76D7),hl
	pop	hl
	ld	(D77E3),hl
	ex	de,hl
	ld	hl,(D76D3)		; размер пула
	add	hl,de
	ld	(D77DF),hl
	ld	(D77EB),hl
	ld	hl,(D76D5)		; размер таблицы идентификаторов
	push	hl
	ld	hl,(D76D3)		; размер пула
	add	hl,de
	pop	de
	add	hl,de
	ld	(D77DD),hl
	ld	(D77E1),hl
	ld	hl,(D76D7)		; размер хэш-таблицы
	srl	h
	rr	l
	srl	h
	rr	l
	ld	(D77D7),hl
	ld	de,5
	call	A750B
	ld	a,e
	or	d
	jr	nz,A7DCA
	ld	hl,(D77D7)
	inc	hl
	ld	(D77D7),hl
	ld	hl,(D76D7)		; размер хэш-таблицы
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	(D76D7),hl		; размер хэш-таблицы
A7DCA:	ld	hl,(D77DF)
	ld	bc,-9
	add	hl,bc
	ld	(D79F3),hl
	ld	(D77E5),hl
	ld	hl,(D77E1)
	ld	(D79F9),hl
	ld	hl,(D77E3)
	ld	(D77E7),hl
	ld	hl,(D77EB)
	ld	(D77E9),hl
	ret


; строка -> число (опции ком-строки)
A7DEA:	push	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)
	cp	":"
	jr	nz,A7DF6
	inc	hl
A7DF6:	push	hl
	ld	hl,0
	ld	(D8193),hl
	pop	hl
A7DFE:	ld	a,(hl)
	push	af
	call	isdigit
	pop	bc
	ld	c,b
	or	a
	jr	z,A7E26			; false
	push	hl
	push	bc
	ld	hl,(D8193)
	add	hl,hl
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	pop	bc
	ld	b,0
	add	hl,bc
	ld	bc,-48
	add	hl,bc
	ld	(D8193),hl
	pop	hl
	inc	hl
	jr	A7DFE
	;
A7E26:	ex	de,hl
	pop	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D8193)
	ret


; добавить расш. к имени файла, если не задано
A7E2F:	push	hl
A7E30:	ld	a,(de)
	inc	de
	ld	(hl),a
	or	a
	jr	z,A7E3E
	cp	"."
	jr	z,A7E3E
	inc	hl
	jr	A7E30
	;
A7E3E:	ld	a,(bc)
	inc	bc
	ld	(hl),a
	inc	hl
	or	a
	jr	nz,A7E3E
	pop	hl
	ret



;T7E69:	db	"R",0			; файл на чтение
;T7E70:	db	"W",0			; файл на запись

; расш. файлов по-умолчанию
;T7E66:	db	".C",0
;T7E6B:	db	".TMC",0		; коррект. также на ".tco"
;T7E72:	db	".ERR",0



A7E8B:	ld	(D8195),hl
	ld	hl,(L0080)		; ком-строка (как буфер)
	ld	(D8191),hl
	ld	(hl),0
	ld	(D8197),de
A7EE7:	ld	hl,(D8195)
	dec	hl
	ld	(D8195),hl
	ex	de,hl
	ld	a,e
	or	d
	jp	z,A805A			; конец парсинга ком-строки
	ld	hl,(D8197)
	inc	hl
	inc	hl
	ld	(D8197),hl
	push	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a,(bc)
	pop	hl
	cp	"-"			; префикс опций
	jp	nz,A805A		; нет опций
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	ld	l,c
	ld	h,b
	ld	(D8199),hl		; строка параметров опции(й)
A7F10:	ld	a,(hl)
	or	a
	jr	z,A7EE7
	ld	e,l
	ld	d,h
	; switch (парсинг опций)
	call	toupper
	cp	"C"			; откл. вложение (гнездование) комментариев
	jr	z,A7F55
	cp	"D"			; задать макро-определение (-dNAME)
	jr	z,A7F5C
	cp	"E"			; переопределение диагностики в <filename>.err
	jp	z,A7F9C
	cp	"K"			; совместимость с K&R стандартом
	jp	z,A7FA4
	cp	"M"			; вывод на экран статистики по таблицам
	jp	z,A7FAE
	cp	"O"			; задать имя для вых. файла
	jp	z,A7FB6
	cp	"R"			; распред. отнош. таблиц P:S:H (Pool:SymbolTable:Hash)
	jp	z,A7FF2
	cp	"J"			; останов. после N ошибок
	jp	z,A7F7D
	;cp	"I"			; задать путь располож. #include-файлов
	;jp	z,A7FCB
	cp	"X"			; строгая совмест. с MSX-C
	jp	z,A7F8E
	; default, не знакомая опция
	jp	A803C

; -c  откл. вложение (гнездование) комментариев
A7F55:	xor	a			; false
	ld	(D76CA),a		; ячейка флага
	jp	A8050

; -dNAME  задать макро-определение (#define)
A7F5C:	inc	de
	ld	hl,(D8191)
.loc1:	ld	a,(de)
	or	a
	jr	z,.loc2
	call	toupper
	ld	(hl),a
	inc	de
	inc	hl
	jr	.loc1
.loc2:	xor	a
	ld	(hl),a
	inc	hl
	ld	(hl),a
	ld	(D8191),hl
	dec	de
	ld	(D8199),de		; строка параметров опции(й)
	jp	A8050

; -jN  остановиться после N ошибок
A7F7D:	inc	de
	ld	(D8199),de		; строка параметров опции(й)
	ld	hl,D8199
	call	A7DEA
	ld	(max_errors),hl		; ячейка макс. числа ошибок
	jp	A7EE7

; -x  совместимость с MSX-C
A7F8E:	ld	a,true
	ld	(D76C9),a		; пропатченная D790C !!
	ld	hl,"CO"			; заменить расш. ".tmc" на ".tco"
	ld	(T7E6B+2),hl
	jp	A8050

; -e  перенапр. вывода ошибок/сообщений в <filename>.err
A7F9C:	ld	a,true
	ld	(D76CB),a		; флаг
	jp	A8050

; -k  Свой режим компилятора (не совм. с K&R)
A7FA4:	xor	a			; false
	ld	(mode),a		; ячейка флага
	;ld	(mode1),a
	;ld	(mode2),a
	jp	A8050

; -m  вывод статистики по таблицам
A7FAE:	ld	a,true
	ld	(D76CE),a		; флаг
	jp	A8050

; -oNAME  задать имя выходного файла
A7FB6:	inc	de
	ld	hl,tmc_filename		; имя tmc-файла
.loc1:	ld	a,(de)
	ld	(hl),a
	inc	hl
	inc	de
	or	a
	jr	nz,.loc1
A7FC3:	dec	de
	dec	de
	ld	(D8199),de		; строка параметров опции(й)
	jp	A8050

; -iPATH  задать путь для #include-файлов
;A7FCB:	inc	de
;	ld	hl,incl_filename	; ds 65  имя вкл. файла
;A7FCF:	ld	a,(de)
;	ld	(hl),a
;	inc	hl
;	inc	de
;	or	a
;	jr	nz,A7FCF
;	dec	hl
;	dec	hl
;	ld	a,(hl)
;	inc	hl
;	cp	"\"
;	jr	z,.loc2
;	ld	(hl),"\"		; концовка каталога
;	inc	hl
;.loc2:	ld	(D77A6),hl
;	jr	A7FC3

; -rP:S:H  задать отношение таблиц (Pool : SymbolTable : Hash)
A7FF2:	inc	de
	ld	(D8199),de		; строка параметров опции(й)
	; таблица пула
	ld	hl,D8199
	call	A7DEA
	ld	(D76D3),hl		; отнош. размера таблицы пула
	ld	a,l
	or	h
	jr	z,A8021			; ошибка
	; таблица идентиф.
	ld	hl,D8199
	call	A7DEA
	ld	(D76D5),hl		; отнош. размера таблицы идентиф.
	ld	a,l
	or	h
	jr	z,A8021			; ошибка
	; хэш-таблица
	ld	hl,D8199
	call	A7DEA
	ld	(D76D7),hl		; отнош. размера хэш-таблицы
	ld	a,l
	or	h
	jr	nz,A802A
A8021:	ld	hl,T7E48		; "bad table ratio"
	call	A0170			; вывод строки на экран
	jp	usage			; вывести Help
	;
A802A:	ld	hl,(D8199)		; строка параметров опции(й)
	dec	hl
	ld	(D8199),hl
	jp	A8050

; default
A803C:	ld	hl,T7E59		; "unknown option: "
	push	de
	call	A0170			; вывод строки на экран
	pop	hl
	ld	a,(hl)
	call	A015E			; вывести bad-букву опции на экран
	ld	a,0Ah
	call	A015E			; вывод "a" на экран
	jp	usage			; вывести Help

; выход из парсинга опций
A8050:	ld	hl,(D8199)		; строка параметров опции(й)
	inc	hl
	ld	(D8199),hl
	jp	A7F10

; Начать компиляцию
A805A:	ld	hl,(D8195)
	ld	a,l
	dec	a
	or	h
	jp	nz,usage		; вывести Help
	ld	hl,commenced		; "Compiling commenced..."
	call	A0170			; вывести строку
	ld	hl,(D8197)
	push	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	bc,T7E66		; расш. ".c"
	ld	hl,c_filename		; имя .c файла
	call	A7E2F			; добавить расш., если нет
	push	hl
	xor	a
;	ld	bc,0
	ld	c,a;
	ld	b,a;
	cpir
	pop	de
	or	a
	sbc	hl,de
	ld	(D7722),hl
	ex	de,hl			; hl = адрес имени файла
	;ld	de,T7E69		; "r" на чтение
	ld	a,"R"			; на чтение
	ld	bc,0			; индекс .c файла (таблица "L064E")
	call	A03FA			; открыть начальный *.C файл
	ld	(D76C1),hl
	ld	a,l
	or	h
	jr	nz,A809B
	ld	de,c_filename		; имя .c файла
	ld	hl,T1BBA		; "cannot open ["
	jp	A06C7			; вывод строки и abort
	;
A809B:	pop	hl
	push	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,tmc_filename		; имя tmc-файла
	ld	a,(hl)
	or	a
	jr	nz,A80AD
	ld	bc,T7E6B		; расш. ".tmc"
	call	A7E2F			; добавить расш., если нет
A80AD:	;ld	de,T7E70		; "w" на запись
	ld	a,"W"			; на запись
	ld	bc,5			; индекс .tmc файла (таблица "L064E")
	call	A03FA			; создать .tmc файл
	ld	(D76C3),hl
	ld	a,l
	or	h
	jr	nz,A80C7
	ld	de,tmc_filename		; имя .tmc файла
	ld	hl,T7CD2		; "Cannot make ["
	jp	A06C7			; вывод строки и abort
	;
A80C7:	ld	a,(D76CB)		; false/true  вывод ошибок в файл
	pop	hl
	or	a
	jr	z,A80F8			; вывод не задан
	; создать .err файл
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	bc,T7E72		; расш. ".err"
	ld	hl,0
	add	hl,sp			; hl = адрес имени файла
	call	A7E2F			; добавить расш., если нет
	;ld	de,T7E70		; "w" на запись
	ld	a,"W"			; на запись
	ld	bc,6			; индекс .err файла (таблица "L064E")
	call	A03FA			; создать *.err файл
	ld	(D76C5),hl
	ld	a,l
	or	h
	jr	nz,A80F8		; без ошибок
	ld	hl,0
	add	hl,sp
	ex	de,hl
	ld	hl,T7CD2		; "Cannot make ["
	jp	A06C7			; вывод строки и abort
	;
A80F8:	call	A7CF8
	jp	A0686			; был "call"


usage:	ld	hl,Help
	call	A0170			; вывод строки на экран
	jp	abort			; выход в ДОС


A8118:	ld	a,(de)
	inc	de
	ld	(hl),a
	inc	hl
	or	a
	jr	nz,A8118
	ret




L8121:	db	0

; Начало осн. кода
A8122:	ld	hl,(L0080)
	ld	e,(hl)			; длина ком-строки
	ld	d,0
	inc	hl
	add	hl,de
	ld	(hl),d			; ноль в конец ком-строки
	;
	ld	de,(L0080)
	inc	de
	ld	hl,D819B		; буфер ком-строки
	call	A8118			; ком-строку в буфер
	ld	hl,1 ;0
;	inc	hl
	ld	(L8209),hl		; true
;**	dec	hl
;	add	hl,hl
;	ld	bc,T81EB		; ds 30
;	add	hl,bc
	ld	hl,T81EB;
	ld	bc,L8121		; адрес уже не нужного кода ?
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	de,(L0080)		; ком-строка
	inc	de
A814D:	ld	a,(de)
	cp	" "
	jr	nz,A8157
	inc	de
	jr	A814D			; пропустить пробелы
	;
A8157:	;ld	a,(de)
	or	a
	jr	z,A8186
	ld	hl,(L8209)
	inc	hl
	ld	(L8209),hl
	dec	hl
	add	hl,hl
	ld	bc,T81EB		; ds 30
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
A816C:	ld	a,(de)
	or	a
	;jr	z,A817B
	jr	z,A8186;
	cp	" "
	jr	z,A817B
	inc	de
	jr	A816C
	;
A817B:	;ld	a,(de)
	;or	a
	;jr	z,A814D
	xor	a
	ld	(de),a
	inc	de
	jr	A814D
	;
A8186:	ld	hl,(L8209)
	ld	de,T81EB		; ds 30
	jp	A7E8B




D818F:	dw	0
D8191:	dw	0
D8193:	dw	0
D8195:	dw	0			; false/true ?
D8197:	dw	0
D8199:	dw	0			; адрес строки параметров опции(й) ?

D819B:	ds	80			; буфер ком-строки

T81EB:	ds	30





; буфер функции "found_first"
f_path:	ds	256 ;81 ;65

; сохр. текущей папки компилятора
disk:	db	0			; диск
dir:	ds	256 ;81			; путь




; Таблица 6-ти описателей файлов (72 байта)
L05FA:	ds	12			; .c файл и .? файл ?
L0606:	ds	12			; include
L0612:	ds	12			; файлы
L061E:	ds	12			;
L062A:	ds	12			;
L0636:	ds	12			; .tmc файл

; первые 2 байта не обнулять!
L0642:	db	1,2			; также описатель .err файла, когда задан
	ds	10



; Таблица указателей на описатели (FCB) файлов
;
L064E:	; 0=0*8  описатель начального .c файла
	dw	L75B6		; ds 38
	dw	L05FA		; описатель
	dw	L8209+1280	; L00+1024=L01      (L00=L8209+256)
	dw	1024		;
	;
	; описатель 1-го открытого include-файла
L01	dw	L75DC		; ds 38
	dw	L0606		; описатель
	dw	L8209+512	; L01+256=L02
	dw	256		;
	; описатель 2-го открытого include-файла
L02	dw	L7602		; ds 38
	dw	L0612		; описатель
	dw	L8209+768	; L02+256=L03
	dw	256		;
	; описатель 3-го открытого include-файла
L03	dw	L7628		; ds 38
	dw	L061E		; описатель
	dw	L8209+1024	; L03+256=L04
	dw	128		;
	; описатель 4-го открытого include-файла
	dw	L764E		; ds 38
	dw	L062A		; описатель
	dw	L8209+1152	; L03+256+128=L..?
	dw	128		;
	;
	; 40=5*8  описатель .tmc файла
L04	dw	L7674		; ds 38
	dw	L0636		; описатель
	dw	L8209+2304	; L04+1024=L05
	dw	1024		;
	;
	; 48=6*8  описатель .err файла
L05	dw	L769A		; ds 38
	dw	L0642		; описатель
	dw	L8F09		; L8209+3328=L8F09
	dw	256		;



; начало буферов файлов
L8209:	ds	256		; отступ
	;
	ds	1024		; .c файл
	ds	256		; include-файлы
	ds	256		;
	ds	128		;
	ds	128		;
	ds	1024		; .tmc файл
	ds	256		; .err файл



	ds	0112h		; заполнить до границы 8000h

	%include "io1.asm"
	%include "cc.1"




L8F09:	;dw	0			; тек. адрес
L9009	equ	L8F09+256


commenced:
	db	"compiling commenced...",0Dh,0Ah,0Ah,0


Help:	db	"syntax: cc1 [options] <filename>",0Ah
	db	"options:",0Ah
	db	9,"-c        disables comment nesting",0Ah
	db	9,"-d<name>  #define NAME 1",0Ah
	db	9,"-e        redirects diagnostics to <filename>.err",0Ah
	;db	9,"-i<path>  set prefix for #include files",0Ah
	db	9,"-j<n>     stop after N errors",0Ah
	db	9,"-k        Karnighan & Ritchie compatability",0Ah
	db	9,"-m        displays memory usage statistics",0Ah
	db	9,"-o<name>  set explicit output file NAME",0Ah
	db	9,"-rP:S:H   allocate tables in ratio P:S:H (Pool:SymbolTable:Hash)",0Ah
	db	9,"-x        strict MSX-C compatability",0Ah,0
