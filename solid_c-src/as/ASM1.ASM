; Последняя редакция 31.01.2004
;


; A4194 - записывает начальные биты при extended REL формате.
;
;
;
;




; описание "ds xx"
%imacro ds 1
times %1 db 0
%endmacro

; описание "ds xx,yy"
%imacro ds 2
times %1 db %2
%endmacro

; описание комментария
%idefine .comment  0



;
; Примечания по ассемблеру:
;
; ■ 64 символа - макс. длина полных имен для всех файлов.
; ■ 64 символа - макс. длина сохраняемого текущего пути ассемблера.
; ■ В name('xxx') можно использовать двойные (") кавычки.
; ■ Имя include-файла можно задавать без расширения. В этом случае
;   будет исп. расширение по-умолчанию ".asm". Это же законно и для
;   входного asm-файла.
; ■ Поддерживаются три варианта записи недокум. регистров:
;	HX,HY,HIX или XH,YH,IYH
;	LX,LY,LIX или XL,YL,IYL
; ■ пс-команды "equ" и "=" идентичны.
;
;
;
;


;
; 0FEh - признак extended REL формата, записывается 2-м байтом от начала файла.
; В .rel файле находится в виде бит. массива.
;




true	equ	1
false	equ	0

; порты страниц
PAGE_1	equ	0A2h
PAGE_3	equ	0E2h

stack	equ	0FFF0h





	org	4000h



A0100:	jp	start


A0103:	ld	(D399F),hl
	dec	h
	dec	h
	dec	h
	ld	(D39A1),hl
	xor	a
	ld	hl,T43FD		; начало буфера(ов) компилятора
	ld	(D36AC),hl
	ld	(hl),a
	inc	h
	inc	h
	inc	h
	inc	h
	ld	(D3995),hl		; hl+1024  конец симв. таблицы ?
	ld	bc,32
	add	hl,bc
	ld	(D3997),hl
	ld	hl,T01B5		; "--PASS 1---"
	call	A40AE			; вывод строки на экран
	ld	hl,T39A3
A012B:	ld	de,idlen		; длина идентиф.
	ld	a,(hl)
	or	a
	jr	z,A015F
	push	af
	and	7
	ld	(de),a
	ld	b,a
A0137:	inc	hl
	inc	de
	ld	a,(hl)
	ld	(de),a
	djnz	A0137
	push	hl
A013E:	call	A0C9C
	pop	de
	pop	af
	and	0F8h			; выделить старшие 5 бит
	ld	(hl),a
	inc	hl
	inc	de
	ld	a,(de)
	inc	de
	ld	(hl),20h
	inc	hl
	ld	(hl),a
	ex	de,hl
	jr	A012B


;[]==============================================================[]
;	2-й проход
;
PASS_2:	ld	hl,T01C3		; "--PASS 2--"
	call	A40AE			; вывод строки на экран
	call	open_file		; откр. ASM файл
	ld	a,true
	ld	(pass2),a		; уст. 2-й проход
A015F:	xor	a
	ld	(D397E),a
	ld	(D3671),a
	ld	(D3672),a
	ld	(D37D2),a
	ld	(D3673),a
	ld	(D3972),a
	ld	(D37CE),a
	ld	hl,D37BC		; обнулить 10 ячеек
	ld	b,10
A017A:	ld	(hl),a
	inc	hl
	djnz	A017A
	inc	a
	ld	(D36A6),a
	ld	(D37BB),a		; a=01 (cseg)  ячейка типа сегмента
	ld	a,10
	ld	(D366F),a		; база чисел
	ld	hl,0
	ld	(D398E),hl
	dec	hl
	ld	(D3661),hl		; номер тек. строки
	ld	sp,(D399F) ;hl
	;ld	sp,hl
	ld	hl,A0231
	push	hl
	ld	hl,T01E0
	push	hl
A01A1:	xor	a
	ld	(D3973),a
	inc	a
	ld	(D36A7),a
	ld	a," "
	ld	(D3815),a		; сбр. символ ошибки
	pop	hl
	push	hl
	ld	bc,T01D1
	push	bc
	jp	(hl)


T01D1:	ld	hl,D36B3		; 257 буфер строки
	ld	(D36B1),hl		; тек. адрес в потоке
	pop	bc
	pop	hl
	push	hl
	push	bc
	ld	bc,A03E3
	push	bc
	jp	(hl)


T01E0:	ld	a,1
	ld	(D3988),a
	ld	(D3987),a
A01E8:	call	A0216
	cp	0Ah
	jr	z,A01E8
	cp	0Ch
	jp	z,A01E8
	ld	b,83h			; 131
	ld	hl,D36B3		; 257 буфер строки
	jr	A01FE
	;
A01FB:	call	A0216
A01FE:	cp	0Ah
	jr	z,A01FB
	ld	(hl),a
	cp	0Dh
	jr	z,A020E
	inc	hl
	djnz	A01FB
	inc	b
	dec	hl
	jr	A01FB
	;
A020E:	ld	hl,(D3661)		; номер тек. строки
	inc	hl
	ld	(D3661),hl
	ret

A0216:	ld	a,(D36A8)
	or	a
	jr	z,A0224
	call	read_include		; чтение include-файла
	ret	nc
	; концовка asm-строки (порции данных)
	xor	a
	ld	(D36A8),a
A0224:	call	A427B			; чтение .asm файла
	ret	nc
	ld	a,0Dh
	ld	(D36B3),a		; начало буфера строки
	scf			; нужен ?
	jp	do_end			; на закрытие .asm файла


A0231:	ld	hl,0
	ld	(D36AE),hl
	xor	a
	ld	(D36A9),a
	dec	a
	ld	(D3973),a
	ld	hl,(D37C4)		; размер common-области
	ld	(D37C8),hl
	ld	a,(D36B3)		; 257 буфер строки
	sub	"$"
	ld	(A0260+1),a
	call	token_copy
	jp	nz,A03B3
	cp	":"
	jp	z,A02FF
	cp	"="
	jr	z,A0280
A0260:	ld	a,0
	or	a
	jr	nz,A0287
	ld	a,(idlen)		; длина идентиф.
	dec	a
	jr	nz,A0287
	call	token_copy
	ld	b,18
	ld	hl,idlen		; длина идентиф.
	ld	a,(hl)
	cp	b
	jr	nc,A0275
	inc	(hl)
A0275:	inc	hl
	ld	a,"$"
A0278:	ld	c,(hl)
	ld	(hl),a
	ld	a,c
	inc	hl
	djnz	A0278
	jr	A0287
	;
A0280:	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	ld	(D36B1),hl
A0287:	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	ld	a,(hl)
	inc	hl
	cp	0Dh
	jp	z,A032E
	push	hl
	call	A03D1			; обменять содержимое буферов
	call	token_copy
	cp	"="			; аналог "equ"
	jr	nz,A02AF
	ld	a,(idlen)		; длина идентиф.
	or	a
	jr	nz,A02AF
	ld	hl,(D36B1)		; тек. адрес в потоке
	inc	hl
	ld	(D36B1),hl
	ld	hl,_EQU_		; запись "equ" в таблице
	jr	A02B5
	;
A02AF:	call	searchtree		; поиск зарез. слов
	jr	nz,A02F5		; не найдены
A02B5:	bit	7,(hl)
	jr	z,A02F5
	inc	hl
	ld	a,(hl)
	cp	22h
	jr	z,A02C7
	cp	1Ch
	jr	z,A02C7
	cp	0Dh
	jr	nz,A02F5
A02C7:	pop	hl
	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	ld	(D36B1),hl
	push	af
	ld	a,(D36A6)
	or	a
	jp	z,A03F9
	call	A03D1			; обменять содержимое буферов
	pop	af
	push	af
	cp	1Ch
	jr	z,A02E7
	or	a
	call	A0C9C
	call	A27C5
A02E7:	pop	af
	cp	22h
	jp	z,A27E2			; "aset"
	cp	1Ch
	jp	z,A30E3			; "macro"
	jp	A0390			; "equ", "="
	;
A02F5:	pop	hl
	ld	(D36B1),hl		; тек. адрес в потоке
	call	A03D1			; обменять содержимое буферов
	jp	A032E
	;
A02FF:	ld	a,(D36A6)
	or	a
	jr	z,A0328
	call	A0C9C
	call	A27C5
	ld	(D36AE),hl
	ex	de,hl
	call	A1815
	ex	de,hl
	or	20h
	push	af
	call	A3583			; узнать след. символ не смещ. поток
	cp	":"
	jr	nz,A0324
	pop	af
	or	40h
	push	af
	call	nextchar
A0324:	pop	af
	call	A0D32
A0328:	call	token_copy
	jp	nz,A03B3
A032E:	call	A3595			; поток на байт назад
	ld	a,(D36A6)
	or	a
	jr	z,A033D
	call	A0BB8
	jp	z,A31C5
A033D:	call	searchtree		; поиск зарез. слов
	jp	nz,A03B3		; не найдены
	or	a
	push	af
	ld	a,(D36A6)
	or	a
	jr	nz,A0355
	pop	af
	jp	p,A03FA
	push	af
	and	60h
	jp	z,A03F9
A0355:	pop	af
	jp	p,A0368
	inc	hl
	ld	a,(hl)
	ld	hl,L0AD6
A035E:	add	a,a
	ld	e,a
	ld	d,0
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	jp	(hl)



A0368:	ld	b,a
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	a,(pass2)
	or	a
	jr	nz,A0376		; 2-й проход
	ld	a,(hl)
	or	a
	jr	nz,A0383
A0376:	ld	a,b
	rra
	rra
	rra
	and	0Fh
	ld	hl,A0AB7		; массив адресов
	jr	A035E
	;
A0383:	ld	hl,(D37BC)		; счетчик org ?
	add	a,l
	ld	l,a
	ld	a,0
	adc	a,h
	ld	h,a
	ld	(D37BC),hl
	ret


; Обработка "equ", "="
A0390:	ld	(D36AE),hl
	call	A27D7
	ld	a,(D3815)		; символ ошибки
	cp	"U"
	ret	z			; метка не определена
	bit	7,b			; внеш. метка ?
	jp	nz,A04E3		; да, "Invalid use of external"
	ld	a,b
	or	20h
	ld	(D36A9),a
	ld	hl,(D36AE)
	ld	(D36AA),hl
	call	A0D32
	ex	de,hl
	ld	a,b
	ret

A03B3:	cp	";"
	ret	z
	cp	0Dh
	ret	z
	ld	hl,D36B3		; 257 буфер строки
	ld	(D36B1),hl		; тек. адрес в потоке
	ld	hl,(D36AE)
	ld	a,h
	or	l
	call	nz,token_copy
	ld	a,(D36A6)
	or	a
	jp	z,A03FA
	jp	A2369


; обменять содержимое буферов
A03D1:	ld	hl,idlen
	ld	de,T37F4
	ld	b,33
A03D9:	ld	c,(hl)
	ld	a,(de)
	ld	(hl),a
	ld	a,c
	ld	(de),a
	inc	hl
	inc	de
	djnz	A03D9
	ret


A03E3:	call	A3595			; поток на байт назад
A03E6:	call	skipspace
	or	a
	jr	z,A03E6
A03EC:	push	hl
	cp	0Dh
	jr	z,A03FA
	cp	";"
	jr	z,A03FA
	call	A0514			; "Warning: maybe mistake!"
	push	af
A03F9:	pop	af
A03FA:	pop	hl
	ld	a,(pass2)
	or	a
	jr	nz,A0415		; 2-й проход
	ld	a,(D3815)		; символ ошибки
T0404:	cp	"V"
	jr	z,A0415
	cp	"M"
	jr	z,A0415
	cp	"D"
	jr	z,A0415
	cp	"X"
	jp	nz,A01A1
A0415:	call	A17FA
	ld	a,(D3815)		; символ ошибки
	cp	" "
	jp	z,A01A1
	call	A0426			; вывод номера и строки с ошибкой
	jp	A01A1



;[]=============================================[]
; Вывод номера и строки с ошибкой
;
A0426:	ld	hl,T0467		; "line"
	call	A40AE			; вывод строки на экран
	ld	a,"["
	call	A41A3			; вывод "a" на экран
	ld	hl,(D3661)		; номер тек. строки
	call	A046F			; вывод номера в десят. формате
	ld	a,"]"
	call	A41A3			; вывод "a" на экран
	ld	a,":"
	call	A41A3			; вывод "a" на экран
	ld	a," "
	call	A41A3			; вывести пробел
	ld	hl,(D3663)
	call	A40AE			; вывод строки ошибки
	call	newline
	ld	a,"?"
	call	A41A3			; вывод "a" на экран
	ld	a,(D3815)		; символ ошибки
	call	A41A3			; вывести символ
	ld	a,9			; Tab
	call	A41A3			; вывод "a" на экран
	; вывести ошибочную строку асм-листинга на экран
	ld	hl,D36B3		; 257 буфер строки
A0453:	ld	a,(hl)
	inc	hl
	call	A41A3			; вывод "a" на экран
	cp	0Dh
	jr	nz,A0453		; цикл вывода ошиб. строки
	ld	a,0Ah
	call	A41A3			; вывод "a" на экран
	ld	a," "
	ld	(D3815),a		; сбр. символ ошибки
	ret



; вывод "hl" в десят. формате
A046F:	ld	bc,1000h		; b-счетчик
	ld	de,0
A0475:	add	hl,hl
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
	djnz	A0475
	ld	hl,T04A4		; буфер под "a"
	ld	a,c
	call	A04AB			; "a" в ascii-формат
	ld	a,d
	call	A04AB			; "a" в ascii-формат
	ld	a,e
	call	A04AB			; "a" в ascii-формат
	ld	b,5
	ld	hl,T04A4
A0498:	ld	a,(hl)
	cp	"0"
	jp	nz,A40AE		; вывод строки на экран
	inc	hl
	djnz	A0498
	jp	A40AE			; вывод строки на экран



; "a" в ascii-формат
A04AB:	push	af
	rrca
	rrca
	rrca
	rrca
	call	A04B4
	pop	af
A04B4:	and	0Fh
	or	"0"
	ld	(hl),a
	inc	hl
	ret

A04BB:	push	bc
	push	hl
	ld	hl,T0656		; "Divide by zero"
	ld	b,"Z"			; символ ошибки
	jp	A053F

out_of_range:
	push	bc
	push	hl
	ld	hl,T055A		; "Argument out of range"
	ld	b,"A"			; символ ошибки
	jp	A053F

A04CF:	push	bc
	push	hl
	ld	b,"C"			; символ ошибки
	ld	hl,T0570		; "Bad conditional"
	jp	A053F

A04D9:	push	bc
	push	hl
	ld	hl,T0580		; "Duplicate definition"
	ld	b,"D"			; символ ошибки
	jp	A053F

A04E3:	push	bc
	push	hl
	ld	hl,T0595		; "Invalid use of external"
	ld	b,"E"			; символ ошибки
	jp	A053F

A04ED:	push	bc
	push	hl
	ld	hl,T0632		; "Multiple symbol definition"
	ld	b,"M"			; символ ошибки
	jp	A053F

A04F7:	push	bc
	push	hl
	ld	b,"N"			; символ ошибки
	ld	hl,T05AD		; "Error in number"
	jp	A053F

A0501:	push	bc
	push	hl
	ld	hl,T05BD		; "Syntax error"
	ld	b,"O"			; символ ошибки
	jp	A053F

A050B:	push	bc
	push	hl
	ld	hl,T05CA		; "Pass 1/2 phase error"
	ld	b,"P"			; символ ошибки
	jr	A053F

A0514:	push	bc
	push	hl
	ld	hl,T0609		; "Warning: maybe mistake!"
	ld	b,"Q"			; символ ошибки
	jr	A053F

A051D:	push	bc
	push	hl
	ld	hl,T05DF		; "Error in relocatable value"
	ld	b,"R"			; символ ошибки
	jr	A053F

undefined:
	push	bc
	push	hl
	ld	hl,T0621		; "Undefined symbol"
	ld	b,"U"			; символ ошибки
	jr	A053F

A052F:	push	bc
	push	hl
	ld	hl,T05FA		; "Error in value"
	ld	b,"V"			; символ ошибки
	jr	A053F

A0538:	push	bc
	push	hl
	ld	hl,T064D		; "Mistake!"
	ld	b,"X"			; символ ошибки
A053F:	push	af
	ld	a,(D3815)		; символ ошибки
	cp	" "
	jr	nz,A0556
	ld	(D3663),hl
	ld	a,b
	ld	(D3815),a		; символ ошибки
	ld	a,(D384C)
	or	10h
	ld	(D384C),a
A0556:	pop	af
	pop	hl
	pop	bc
	ret





; Поиск зарез. слов компилятора
; выход: "z" - найдено (a = 1-й байт записи)
;        "nz" - не найдено
;        "nc" - ?
;        "m" - ?
searchtree:
	ld	a,(idname)		; 1-я буква имени идентиф.
	cp	"."
	jr	z,A06BC			; зарез. слова с "."
	cp	"$"
	jr	z,A06C3			; зарез. слово "include"
	cp	"Z"+1
	inc	a
	ret	nc
	sub	42h
	or	a
	ret	m
	add	a,a
	push	bc
	push	de
	ld	e,a
	ld	d,0
	ld	hl,T06C8		; таблица адресов под-списков keywords
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl			; hl=адрес под-списка
	; цикл сравнения зарез. имени
A0686:	ld	a,(idlen)		; длина идентиф.
	dec	a			; длина минус первая буква
	ld	c,a
A068B:	ld	a,(hl)			; длина имени из таблицы
	or	a
	jr	z,not_found		; конец списка зарез. слов
	and	7			; выделить 3 бита длины имени
	cp	c			; равна искомому ?
	jr	nz,A06AC		; нет, на след. запись
	ld	de,idname+1		; 2-я буква имени идентиф.
	push	hl
	ld	b,c			; длина зарез. слова (мнемоники)
	inc	hl			; пройти 4 служ. байта в записи
	inc	hl
	inc	hl
	;inc	hl
A069D:	ld	a,(de)
	cp	(hl)
	jr	nz,A06AB		; не совпадает, на след. запись
	inc	hl
	inc	de
	djnz	A069D
	; найдено
	pop	hl
	xor	a			; флаг "z"
	ld	a,(hl)			; 1-й байт записи
	pop	de
	pop	bc
	ret
	;
A06AB:	pop	hl
A06AC:	ld	a,(hl)			; 1-й байт записи
	and	7			; выделить длину записи
A06AF:	add	a,3;4			; число служ. байт в записи
	ld	e,a
	ld	d,0
	add	hl,de
	jr	A068B			; назад в цикл
	;
not_found:
	pop	de
	pop	de
	inc	a			; флаг "nz"
	ret
	;
A06BC:	ld	hl,_period		; keywords с "."
A06BF:	push	bc
A06C0:	push	de
	jr	A0686
	;
A06C3:	ld	hl,_includ		; "include"
	jr	A06BF



; Таблица адресов под-списков зарез. слов
; 26 букв
T06C8:	dw	_A_			; a
	dw	_B_			; b
	dw	_C_			; c
	dw	_D_			; d
	dw	_E_			; e
	dw	empty			; f (заглушка)
	dw	_G_			; g
	dw	_H_			; h
	dw	_I_			; i
	dw	_J_			; j
	dw	empty			; k (заглушка)
	dw	_L_			; l
	dw	_M_			; m
	dw	_N_			; n
	dw	_O_			; o
	dw	_P_			; p
	dw	empty			; q (заглушка)
	dw	_R_			; r
	dw	_S_			; s
	;dw	_T_			; t
	dw	empty			; t (заглушка) поставил
	dw	empty			; u (заглушка)
	dw	empty			; v (заглушка)
	dw	empty			; w (заглушка)
	dw	_X_			; x
	dw	empty			; y (заглушка)
	dw	empty			; z (заглушка)


	; 1-й байт - после "and 7", 4 мл.бита - длина остатка имени
	; 2-й байт - код мнемоники или индекс в таблице адресов
	; 3-й байт - число байт мнем. ?
_A_:	db	0x52,0x00,0x00,"DC"		; adc
	db	0x52,0x02,0x00,"DD"		; add
	db	0x52,0x04,0x00,"ND"		; and
	db	0x83,0x00,0x00,"SEG"		; aseg
	db	0x83,0x22,0x00,"SET"		; aset
	db	0
	;
_B_:	db	0x5A,0x06,0x00,"IT"		; bit
	db	0
	;
_C_:	db	0x53,0x08,0x00,"ALL"		; call
	db	0x51,0x0A,0x00,"P"		; cp
	db	0x6A,0x3F,0x01,"CF"		; ccf
	db	0x73,0xB1,0x02,"PIR"		; cpir
	db	0x72,0xA1,0x02,"PI"		; cpi
	db	0x6A,0x2F,0x01,"PL"		; cpl
	db	0x72,0xA9,0x02,"PD"		; cpd
	db	0x73,0xB9,0x02,"PDR"		; cpdr
	db	0x83,0x02,0x00,"SEG"		; cseg
	db	0x85,0x01,0x00,"OMMON"		; common
	db	0xC3,0x14,0x00,"OND"		; cond     усл. компиляция
	db	0
	;
_D_:	db	0x81,0x03,0x00,"B"		; db
	db	0x52,0x0C,0x00,"EC"		; dec
	db	0x81,0x07,0x00,"W"		; dw
	db	0x53,0x0E,0x02,"JNZ"		; djnz
	db	0x81,0x05,0x00,"S"		; ds
	db	0x69,0xF3,0x01,"I"		; di
	db	0x6A,0x27,0x01,"AA"		; daa
	db	0x81,0x04,0x00,"C"		; dc
	db	0x83,0x03,0x00,"EFB"		; defb
	db	0x83,0x05,0x00,"EFS"		; defs
	db	0x83,0x07,0x00,"EFW"		; defw
	db	0x83,0x22,0x00,"EFL"		; defl
	db	0x83,0x03,0x00,"EFM"		; defm
	db	0x83,0x06,0x00,"SEG"		; dseg
	db	0
	;
_E_:	db	0x69,0xFB,0x01,"I"		; ei
_EQU_:	db	0x82,0x0D,0x00,"QU"		; equ
	db	0x51,0x10,0x00,"X"		; ex
	db	0x6A,0xD9,0x01,"XX"		; exx
	db	0xC3,0x08,0x00,"LSE"		; else
	db	0x82,0x09,0x00,"ND"		; end
	db	0xA3,0x0A,0x00,"NDC"		; endc   концовка "cond"
	db	0xA4,0x0A,0x00,"NDIF"		; endif
	db	0x8B,0x0B,0x00,"NDM"		; endm
	db	0x84,0x0C,0x00,"NTRY"		; entry
	db	0x84,0x0E,0x00,"XITM"		; exitm
	db	0x82,0x0F,0x00,"XT"		; ext
	db	0x87,0x0F,0x00,"XTERNAL"	; external
	db	0x84,0x10,0x00,"XTRN"		; extrn
	db	0
	;
_G_:	db	0x85,0x20,0x00,"LOBAL"		; global
	db	0
	;
_H_:	db	0x6B,0x76,0x01,"ALT"		; halt
	db	0
	;
_I_:	db	0x52,0x16,0x00,"NC"		; inc
	db	0x51,0x14,0x02,"N"		; in
	db	0x73,0xB2,0x02,"NIR"		; inir
	db	0x72,0xA2,0x02,"NI"		; ini
	db	0x12,0x00,0x03,"N0"		; in0
	db	0xC1,0x11,0x00,"F"		; if
	db	0xC2,0x32,0x00,"FB"		; ifb
	db	0xC4,0x39,0x00,"FDIF"		; ifdif
	db	0xC2,0x12,0x00,"FE"		; ife
	db	0xC2,0x13,0x00,"FF"		; iff
	db	0xC4,0x3A,0x00,"FIDN"		; ifidn
	db	0xC3,0x33,0x00,"FNB"		; ifnb
	db	0xC2,0x14,0x00,"FT"		; ift
	db	0x61,0x12,0x02,"M"		; im
	db	0x86,0x38,0x00,"NCLUDE"		; include
	db	0x72,0xAA,0x02,"ND"		; ind
	db	0x73,0xBA,0x02,"NDR"		; indr
	db	0xC2,0x15,0x00,"F1"		; if1
	db	0xC2,0x16,0x00,"F2"		; if2
	db	0xC4,0x17,0x00,"FDEF"		; ifdef
	db	0xC5,0x18,0x00,"FNDEF"		; ifndef
	db	0x92,0x19,0x00,"RP"		; irp
	db	0x93,0x1A,0x00,"RPC"		; irpc
	db	0
	;
_J_:	db	0x51,0x18,0x00,"P"		; jp
	db	0x51,0x1A,0x02,"R"		; jr
	db	0
	;
_L_:	db	0x01,0x00,0x00,"D"		; ld
	db	0x73,0xB0,0x02,"DIR"		; ldir
	db	0x73,0xB8,0x02,"DDR"		; lddr
	db	0x72,0xA8,0x02,"DD"		; ldd
	db	0x72,0xA0,0x02,"DI"		; ldi
	db	0x84,0x1B,0x00,"OCAL"		; local
	db	0
	;
_M_:	db	0x94,0x1C,0x00,"ACRO"		; macro
	db	0x85,0x38,0x00,"ACLIB"		; maclib
;	db	0x34,0x14,0x02,0x02,"ULUB"	; mulub		?!
;	db	0x3C,0x34,0x02,0x02,"ULUW"	; muluw		?!
;	db	0x0A,0x4C,0x02,0x01,"LT"	; mlt		?!
	db	0
	;
_N_:	db	0x72,0x44,0x02,"EG"		; neg
	db	0x6A,0x00,0x01,"OP"		; nop
	db	0x83,0x1D,0x00,"AME"		; name
	db	0
	;
_O_:	db	0x51,0x1E,0x00,"R"		; or
	db	0x52,0x20,0x02,"UT"		; out
	db	0x73,0xB3,0x02,"TIR"		; otir
	db	0x73,0xA3,0x02,"UTI"		; outi
	db	0x73,0xBB,0x02,"TDR"		; otdr
	db	0x73,0xAB,0x02,"UTD"		; outd
	db	0x82,0x1E,0x00,"RG"		; org
;	db	0x1B,0x01,0x03,0x01,"UT0"	; out0		?!
;	db	0x73,0x83,0x02,0x01,"TIM"	; otim		?!
;	db	0x73,0x8D,0x02,0x01,"TDM"	; otdm		?!
;	db	0x74,0x93,0x02,0x01,"TIMR"	; otimr		?!
;	db	0x74,0x9D,0x02,0x01,"TDMR"	; otdmr		?!
	db	0
	;
_P_:	db	0x52,0x22,0x00,"OP"		; pop
	db	0x53,0x24,0x00,"USH"		; push
	db	0x85,0x20,0x00,"UBLIC"		; public
	db	0
	;
_R_:	db	0x52,0x28,0x01,"ET"		; ret
	db	0x5A,0x26,0x00,"ES"		; res
	db	0x6B,0x0F,0x01,"RCA"		; rrca
	db	0x6B,0x07,0x01,"LCA"		; rlca
	db	0x59,0x2A,0x00,"L"		; rl
	db	0x6A,0x17,0x01,"LA"		; rla
	db	0x5A,0x2C,0x00,"LC"		; rlc
	db	0x59,0x2E,0x00,"R"		; rr
	db	0x6A,0x1F,0x01,"RA"		; rra
	db	0x5A,0x30,0x00,"RC"		; rrc
	db	0x52,0x32,0x01,"ST"		; rst
	db	0x73,0x4D,0x02,"ETI"		; reti
	db	0x72,0x6F,0x02,"LD"		; rld
	db	0x72,0x67,0x02,"RD"		; rrd
	db	0x73,0x45,0x02,"ETN"		; retn
	db	0x93,0x21,0x00,"EPT"		; rept
	db	0
	;
_S_:	db	0x52,0x34,0x00,"BC"		; sbc
	db	0x52,0x3E,0x00,"UB"		; sub
	db	0x6A,0x37,0x01,"CF"		; scf
	db	0x5A,0x36,0x00,"ET"		; set
	db	0x5A,0x38,0x00,"LA"		; sla
	db	0x5A,0x3A,0x00,"RA"		; sra
	db	0x5A,0x3C,0x00,"RL"		; srl
	db	0x5A,0x42,0x00,"LI"		; sli
;	db	0x72,0x76,0x02,0x01,"LP"	; slp		?!
	db	0
	;
;_T_:	db	0x22,0x04,0x00,0x01,"ST"	; tst		?!
;	db	0x2C,0x74,0x03,0x01,"STIO"	; tstio		?!
;	db	0
	;
empty:	db	0				; заглушка (пустая запись)
	;
_X_:	db	0x52,0x40,0x00,"OR"		; xor
	db	0
	;
_period:db	0x84,0x36,0x00,"8080"		; .8080
	db	0x83,0x37,0x00,"Z80"		; .z80
	db	0x87,0x25,0x00,"COMMENT"	; .comment
	db	0x87,0x27,0x00,"DEPHASE"	; .dephase
	db	0x85,0x2B,0x00,"PHASE"		; .phase
	db	0x86,0x2C,0x00,"PRINTX"		; .printx
	db	0x85,0x2D,0x00,"RADIX"		; .radix
	db	0x87,0x35,0x00,"REQUEST"	; .request
	db	0
	;
_includ:db	0x87,0x38,0x00,"INCLUDE"
	db	0



A0AB7:	dw	L13CB
	dw	L12BF
	dw	L125F
	dw	L128E
	dw	L11FC
	dw	L1244
	dw	L12DF
	dw	L12FF
	dw	A0D24
	dw	A0D24
	dw	L0DE5			; "adc"
	dw	L0DE8
	dw	L0DEB
	dw	L0DC5			; "ccf"
	dw	L0DC0


L0AD6:	dw	L22D6			;+0 "aseg"
	dw	L273E
	dw	L22EC
	dw	A2369
	dw	A2417
	dw	L2459
	dw	L22FE
	dw	A24A8
	dw	L24DF
	dw	do_end			;+9 "end"
	dw	A24B8
	dw	A0501			; "Syntax error"
	dw	A264D			; "entry"
	dw	A0501			; "Syntax error"
	dw	L2E42
	dw	L278D			; "ext", "extern"
	dw	L278D			; "extrn"
	dw	L2548
	dw	L2550
	dw	L2550
	dw	L2548
	dw	L255D
	dw	L2567
	dw	L2571
	dw	L2572
	dw	A013E
	dw	L2F9A
	dw	A0501			; "Syntax error"
	dw	A0501			;
	dw	L26F5			; "name ('...')"
	dw	L2267			; "org"
	dw	A0501			; "Syntax error"
	dw	A264D			; "global", "public"
	dw	L2D76
	dw	A0501			; "Syntax error"
	dw	A0501			;
	dw	A0501			;
	dw	L309D
	dw	A359F			; продвинуть полож. в потоке на 1 байт
	dw	L32AE			;+27h ".dephase"
	dw	A359F			; продвинуть полож. в потоке на 1 байт
	dw	A359F
	dw	A0501			; "Syntax error"
	dw	L3285			;+2Bh ".phase"
	dw	L306F
	dw	L267A
	dw	A359F			; продвинуть полож. в потоке на 1 байт
	dw	A359F
	dw	A359F
	dw	A359F
	dw	L25AC
	dw	L25AD
	dw	A0501			; "Syntax error"
	dw	A26A4
	dw	A0501			; "Syntax error"
	dw	A359F			; продвинуть полож. в потоке на 1 байт
	dw	L26CF			; "include", "maclib"
	dw	L25C1
	dw	L25C0
	dw	A359F			; продвинуть полож. в потоке на 1 байт
	dw	A359F
	dw	A359F			;+3Dh


L0B52:	db	04h,0x88
	db	06h,0x80
	db	00h,0xA0
	db	02h,0x40
	db	0Ch,0xCD
	db	00h,0xB8
	db	08h,0x05
	db	16h,0x10
	db	1Eh,0x00
	db	0Ah,0x46
	db	1Ah,0x00
	db	08h,0x04
	db	10h,0xC3
	db	12h,0x18
	db	22h,0x00
	db	00h,0xB0
	db	1Ch,0x00
	db	20h,0xC1
	db	20h,0xC5
	db	02h,0x80
	db	0Eh,0x00
	db	14h,0x10
	db	14h,0x00
	db	14h,0x18
	db	14h,0x08
	db	18h,0xC7
	db	04h,0x98
	db	02h,0xC0
	db	14h,0x20
	db	14h,0x28
	db	14h,0x38
	db	00h,0x90
	db	00h,0xA8
	db	14h,0x30


L0B96:	dw	A11AD			; "and", "cp"
	dw	L10ED
	dw	L1325
	dw	L136D
	dw	L1152			; "dec"
	dw	L0E00
	dw	L0EB8			; "call"
	dw	L0E4A
	dw	L0ED8
	dw	L0F03
	dw	L1101
	dw	L0F71			; "djnz"
	dw	L0E20
	dw	L1039
	dw	L0FE8
	dw	L107B
	dw	L0E32


A0BB8:	ld	hl,T38EA		; ds 66
	ld	a,(idlen)		; длина идентиф.
	push	af
	call	A0BD0
	jr	z,A0BCB
	pop	af
	ld	(idlen),a		; длина идентиф.
	or	a
	ld	a,(hl)
	ret
A0BCB:	pop	bc
	ret


A0BCD:	ld	hl,T392C		; ds 66
A0BD0:	call	A0C7C
	ld	b,0
	add	hl,bc
	add	hl,bc
	ld	(D38E8),hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,T38DF
	ld	b,9
	xor	a
A0BE3:	ld	(hl),a
	inc	hl
	djnz	A0BE3
	ld	hl,idlen		; длина идентиф.
	ld	a,(hl)
	cp	30			; макс. длина id (для extended REL)
	jr	c,A0BF1
	ld	(hl),30
A0BF1:	ld	c,(hl)
	dec	c
A0BF6:	ld	a,d
	or	e
	jr	z,A0C5E
	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	push	hl
	inc	hl
	ld	a,(hl)
	dec	a
	jr	z,A0C1B
	ld	de,8
	add	hl,de
	ld	de,idname+1		; 2-я буква идентиф.
	ld	b,a
A0C13:	ld	a,(de)
	cp	(hl)
	jr	nz,A0C2D
	inc	hl
	inc	de
	djnz	A0C13
A0C1B:	pop	hl
	inc	hl
	ld	a,(hl)
	dec	a
	cp	c
	jp	nz,A0C58
	inc	hl
	ld	(D36AA),hl
	inc	hl
	ld	a,(hl)
	dec	hl
	pop	bc
	pop	bc
	ret
	;
A0C2D:	ccf
	sbc	a,a
	and	2
	pop	hl
A0C32:	push	af
	ex	de,hl
	dec	de
	dec	de
	dec	de
	push	af
	push	de
	ld	de,T38E2
	ld	hl,T38DF
	ld	b,6
A0C41:	ld	a,(de)
	ld	(hl),a
	inc	hl
	inc	de
	djnz	A0C41
	pop	de
	pop	af
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	af
	pop	hl
	pop	de
	jp	z,A0BF6
	ex	de,hl
	jp	A0BF6
	;
A0C58:	dec	hl
	ld	a,2
	jp	A0C32
	;
A0C5E:	inc	a
	ld	hl,(D36AC)
	ld	a,(hl)
	ret

A0C64:	ld	hl,(D3993)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	or	a
	scf
	ret	z
	inc	hl
	push	hl
	add	a,6
	ld	d,0
	ld	e,a
	add	hl,de
	ld	(D3993),hl
	pop	hl
	ret

A0C7C:	ld	a,(idname)		; 1-я буква имени идентиф.
	cp	"$"
	ld	c,0
	ret	z
	inc	c
	cp	"."
;	ld	c,1
	ret	z
	inc	c
	cp	"?"
;	ld	c,2
	ret	z
	inc	c
	cp	"_"
;	ld	c,3
	ret	z
	inc	c
	cp	" "
;	ld	c,4
	ret	z
	sub	";"
	ld	c,a
	ret


A0C9C:	push	af
	call	A0BCD
A0CA0:	ld	(D36AA),hl
	pop	bc
	ret	z
	ex	de,hl
	ld	hl,(D38E6)
	ld	a,h
	or	l
	jr	nz,A0CB3
	ld	hl,(D38E8)
	jr	A0CBB
	;
A0CB3:	ld	a,(D38E5)
	ld	b,0
	ld	c,a
	add	hl,bc
A0CBB:	ld	(hl),e
	inc	hl
	ld	(hl),d
	ex	de,hl
	ld	b,4			; очистить 4 ячейки
	xor	a
A0CC3:	ld	(hl),a
	inc	hl
	djnz	A0CC3
	;
	ld	de,idlen		; длина идентиф.
	ld	a,(de)
	cp	30			; макс. длина id (для extended REL)
	jr	c,A0CD1
	ld	a,30
A0CD1:	ld	(hl),a			; сохр. длину имени
	ld	b,a			; b=длина идентиф.
	inc	hl
	inc	de
	ld	(D36AA),hl
	xor	a
	ld	(hl),a			; атрибут метки (C0-норм., 40-extrn)
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(hl),a			; мл. байт адреса метки
	inc	hl
	ld	(hl),a			; ст. байт адреса метки
	inc	hl
	inc	hl
	inc	hl
A0CE3:	ld	a,(de)			; скопир. в запись имя идентиф.
	ld	(hl),a
	inc	hl
	inc	de
	djnz	A0CE3
	ld	(D36AC),hl		; адрес своб. места ?
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),b
	inc	h
	ex	de,hl
	ld	hl,(D3995)		; конец симв. таблицы ?
	call	A0D1F			; сравнить hl с de
	call	c,A3420
	ld	hl,(D36AA)
	ld	a,h
	or	a
	ld	a,0
	ret


stack_overflow:
	ld	hl,T2D5A		; "Stack overflow, aborting."
	jp	A0D07

symtable_full:
	ld	hl,T0D0B		; "Symbol table full"
A0D07:	call	A40AE			; вывод строки на экран
	jp	abort



; сравнить hl с de
A0D1F:	ld	a,h
	sub	d
	ret	nz
	ld	a,l
	sub	e
A0D24:	ret


A0D2B:	push	af
	call	A0BB8
	jp	A0CA0


A0D32:	ld	b,a
	ld	a,(hl)
	and	38h
	jr	nz,A0D59
	inc	hl
	ld	a,(hl)
	and	20h
	jr	nz,A0D64
A0D40:	dec	hl
	ld	a,(hl)
	or	80h
	ld	(hl),a
	inc	hl
	ld	a,(hl)
	or	b
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	push	de
	ld	de,(D37C8)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	de
	ret
A0D59:	ld	a,(hl)
	and	40h
	ld	(hl),a
	call	A0514			; "Warning: maybe mistake!"
	inc	hl
	jr	A0D40
	;
A0D64:	ld	a,(hl)
	and	94h
	call	nz,A0DB1
	ld	a,(hl)
	xor	b
	and	3
	call	nz,A0DB1
	inc	hl
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ex	(sp),hl
	call	A0D1F			; сравнить hl с de
	call	nz,A0DA3
	pop	de
A0D7F:	push	hl
	ld	hl,(D37C8)
	ex	de,hl
	ld	a,b
	and	3
A0D87:	cp	3
	jr	nz,A0D95
	ld	a,e
	cp	(hl)
	jr	nz,A0D92
	inc	hl
	ld	a,d
	cp	(hl)
A0D92:	call	nz,A0DB1
A0D95:	pop	de
	ld	a,(D3815)		; символ ошибки
	cp	" "
	ld	hl,(D36AA)
	inc	hl
	jr	z,A0D40
	ret

A0DA3:	ld	a,(D36A9)
	or	a
	jr	nz,A0DB1
	ld	hl,(D36AA)
	ld	a,(hl)
	or	a
	jp	p,A050B			; "Pass 1/2 phase error"
A0DB1:	push	hl
	push	af
	ld	hl,(D36AA)
	inc	hl
	set	4,(hl)
	set	4,b
	pop	af
	pop	hl
	jp	A04ED			; "многократное опред. метки"


; Обработка "cpir", "cpi", "cpd", "cpdr"
L0DC0:	ld	a,0EDh
	call	A1631
; Обработка "ccf", "cpl", "daa", "di"
L0DC5:	ld	a,c
	call	A1631
	jp	A359F			; продвинуть полож. в потоке на 1 байт


A0DCC:	call	A3595			; поток на байт назад
	call	nextchar
	cp	","
	call	nz,A0501		; "Syntax error"
	ret

A0DD8:	call	A27D7
	ld	a,d
	or	a
	jr	z,A0DE3
	inc	a
	call	nz,out_of_range
A0DE3:	ld	a,e
	ret


L0DE5:	ld	b,0
	db	11h
L0DE8:	ld	b,0CBh
	db	11h
L0DEB:	ld	b,0EDh
	ld	e,c
	ld	d,0
	ld	hl,L0B52
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	c,(hl)
	ld	hl,L0B96
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	jp	(hl)


L0E00:	push	bc
	call	A0DD8
	cp	3
	call	nc,out_of_range
	call	A1627
	pop	bc
	ld	a,b
	call	A1631
	ld	a,e
	cp	1
	ccf
	adc	a,0
	and	3
A0E19:	add	a,a
	add	a,a
	add	a,a
	add	a,c
	jp	A1631

L0E20:	push	bc
	call	A0DD8
	and	38h
	cp	e
	call	nz,out_of_range
	call	A1627
	pop	bc
	add	a,c
	jp	A1631

L0E32:	push	bc
	call	A0FB9
	call	c,out_of_range
	and	8
	call	nz,A0E6D
	pop	bc
	call	A0FCE
	ld	a,(D3667)
	and	6
	jp	A0E19

L0E4A:	call	A1CD9
	ld	a,(D383A)
	or	a
	jr	nz,A0E68
	call	A0FB3
	ld	a,(D3666)
	cp	30h
	call	nz,A0E7D
	ld	a,(D3667)
	and	7
	ld	c,0C0h
	jp	A0E19
	;
A0E68:	ld	a,0C9h
	jp	A1631

A0E6D:	ld	a,(D3667)
	and	20h
	add	a,0DDh
	call	A1631
	ld	a,4
	ld	(D3667),a
	ret

A0E7D:	cp	10h
	jp	nz,out_of_range
	ld	a,(D3667)
	cp	1
	jp	nz,out_of_range
	ld	a,3
	ld	(D3667),a
	ret

A0E90:	push	bc
	xor	a
	ld	(D3668),a
	call	skipspace
	call	A3595			; поток на байт назад
	cp	"("
	jr	nz,A0EA2
	ld	(D3668),a
A0EA2:	call	A27D7
	ld	a,c
	sub	","
	pop	bc
	or	a
	ret	nz
	call	A0FB3
	ld	a,(D3666)
	cp	30h
	call	nz,A0E7D
	scf
	ret


; Обработка "call"
L0EB8:	call	A0E90
	jr	nc,A0ED1
	ld	c,0C4h
A0EBF:	ld	a,(D3667)
	add	a,a
	add	a,a
	add	a,a
	and	38h
	add	a,c
	ld	c,a
	push	bc
	call	A27D7
	call	A1627
	pop	bc
A0ED1:	ld	a,c
	call	A1631
	jp	A1735


L0ED8:	call	A0E90
	jr	c,A0EFE
	ld	a,(D3666)
	cp	20h
	ccf
	jp	nc,A0ED1
	cp	28h			; "("
	call	z,A0E6D
	call	A0FC6
	ld	a,(D3667)
	cp	4
	call	nz,out_of_range
	call	A0FB3
	ld	a,0E9h
	jp	A1631
	;
A0EFE:	ld	c,0C2h
	jp	A0EBF

L0F03:	call	A0E90
	jr	nc,A0F1D
	ld	a,(D3667)
	cp	4
	call	nc,out_of_range
	and	3
	add	a,a
	add	a,a
	add	a,a
	add	a,20h
	ld	c,a
	push	bc
	call	A27D7
	pop	bc
A0F1D:	call	A0F29
	ld	a,c
	ld	c,b
	call	A1631
	ld	a,c
	jp	A1631

A0F29:	ld	a,(D3839)
	ld	b,a
	and	80h
	jp	nz,A04E3		; "Invalid use of external"
	call	A1627
	ld	a,b
	and	3
	ld	b,a
	call	A1815
	cp	b
	jp	nz,A051D		; "Error in relocatable value"
	cp	3
	jr	nz,A0F53
	push	de
	ld	de,(D37C4)		; размер common-области
	ld	hl,(D37C8)
	call	A0D1F			; сравнить hl с de
	pop	de
	jp	nz,A051D		; "Error in relocatable value"
A0F53:	call	A1815
	inc	hl
	inc	hl
	ex	de,hl
	call	A327E			; hl-de -> de
	ld	a,d
	or	a
	ld	b,e
	jr	z,A0F6B
	inc	a
	jp	nz,out_of_range
	ld	a,b
	or	a
	jp	p,out_of_range
	ret
A0F6B:	ld	a,b
	or	a
	jp	m,out_of_range
	ret


; Обработка "djnz"
L0F71:	push	bc
	call	A27D7
	pop	bc
	jp	A0F1D


A0F79:	call	A0DCC
A0F7C:	push	bc
	xor	a
	ld	(D3668),a
	call	skipspace
	call	A3595			; поток на байт назад
	cp	"("
	jr	nz,A0F8E
	ld	(D3668),a
A0F8E:	call	A27D7
	pop	bc
	ld	a,(D3666)
	or	a
	ret	z
	cp	30h
	call	z,out_of_range
	ld	l,a
	ld	a,(D3668)
	or	a
	ld	a,l
	jr	z,A0FB3
	cp	28h			; "("
	jr	nz,A0FB3
A0FA8:	ld	a,d
	or	a
	jr	z,A0FB8			; на ret
	inc	a
	ld	d,a
	jr	z,A0FB8			; на ret
	call	out_of_range
A0FB3:	ld	a,d
	or	e
	call	nz,out_of_range
A0FB8:	ret

A0FB9:	call	A0F7C
	ld	a,(D3666)
	or	a
	jp	z,out_of_range
	cp	20h
	ret

A0FC6:	ld	a,(D3668)
	or	a
	call	z,out_of_range
	ret

A0FCE:	ld	a,(D3668)
	or	a
	call	nz,out_of_range
	ret

A0FD6:	call	A0F7C
A0FD9:	ld	a,(D3666)
	cp	10h
	ret	nz
	ld	a,(D3667)
	cp	8
	ret	c
	jp	out_of_range

L0FE8:	call	A0FD6
	call	A0DCC
	call	A0FC6
	ld	a,(D3666)
	cp	10h
	jr	z,A1019
	or	a
	call	nz,out_of_range
	call	A0FA8
	ld	a,0D3h
	call	A1631
	ld	a,e
	call	A1643
	call	A0FB9
	call	nc,out_of_range
	ld	a,(D3667)
	cp	7
	call	nz,out_of_range
	jp	A0FCE
	;
A1019:	ld	a,(D3667)
	dec	a
	call	nz,out_of_range
	call	A0FB9
	call	nc,out_of_range
	call	A0FCE
	ld	a,0EDh
	call	A1631
	call	A0FCE
	call	A0FD9
	ld	c,41h
	jp	A0E19

L1039:	call	A0FB9
	call	nc,out_of_range
	call	A0FCE
	call	A0FD9
	push	af
	call	A0F79
	call	A0FC6
	ld	a,(D3666)
	cp	10h
	jr	z,A1069
	or	a
	call	nz,out_of_range
	ld	a,0DBh
	call	A1631
	pop	af
	cp	7
	call	nz,out_of_range
	call	A0FA8
	ld	a,e
	jp	A1643
	;
A1069:	ld	a,(D3667)
	dec	a
	call	nz,out_of_range
	ld	a,0EDh
	call	A1631
	pop	af
	ld	c,40h
	jp	A0E19

L107B:	call	A0FB9
	call	c,out_of_range
	call	A0DCC
	call	A1CBB
	jp	z,A10BB
	ld	a,(D3667)
	cp	2
	jp	z,A10CF
	cp	6
	call	nz,out_of_range
	call	A0FC6
	call	A0FB9
	call	c,out_of_range
	call	A0FCE
	call	A0FB3
	ld	a,(D3666)
	cp	28h			; "("
	call	z,A0E6D
	ld	a,(D3667)
	cp	4
	call	nz,out_of_range
	ld	a,0E3h
	jp	A1631
	;
A10BB:	call	A0FCE
	call	A0FB9
	call	c,out_of_range
	call	A1CBB
	call	nz,out_of_range
	ld	a,8
	jp	A1631

A10CF:	call	A0FCE
	call	A0FB9
	call	c,out_of_range
	ld	a,(D3666)
	cp	20h
	call	nz,out_of_range
	ld	a,(D3667)
	cp	4
	call	nz,out_of_range
	ld	a,0EBh
	jp	A1631


; Обработка "bit"
L10ED:	push	bc
	call	A0DD8
	cp	8
	call	nc,out_of_range
	and	7
	add	a,a
	add	a,a
	add	a,a
	pop	bc
	add	a,c
	ld	c,a
	call	A0DCC
L1101:	call	A0FD6
	db	0F6h			; or
A1105:	scf				; 37h
	push	af
	ld	a,(D3666)
	cp	28h
	push	af
	call	z,A0E6D
	pop	hl
	pop	af
	push	hl
	push	af
	ld	a,0CBh
	call	nc,A1631
	pop	af
	jp	c,A1123
	pop	af
	ld	a,e
	call	z,A1643
	push	af
A1123:	push	af
	ld	a,(D3666)
	or	a
	call	z,out_of_range
	and	20h
	ld	a,(D3667)
	jp	nz,A113D
	add	a,c
	call	A1631
	call	A0FCE
	pop	af
	pop	af
	ret
A113D:	cp	4
	call	nz,out_of_range
	ld	a,6
	add	a,c
	call	A1631
	call	A0FC6
	pop	af
	jp	nc,A17F8
	jp	A11A7


; Обработка "dec"
L1152:	call	A0F7C
	ld	a,(D3666)
	cp	10h
	jr	z,A1187
	or	a
	call	z,out_of_range
	cp	28h
	push	af
	call	z,A0E6D
	ld	a,(D3667)
	cp	4
	jr	nz,A1173
	ld	a,(D3668)
	or	a
	jr	nz,A11A2
A1173:	call	A0FCE
	pop	af
	ld	a,c
	dec	c
	cp	5
	jr	nz,A117F
	ld	c,0Bh
A117F:	ld	a,(D3667)
	and	6
	jp	A0E19
	;
A1187:	ld	a,(D3667)
	cp	10h
	jr	c,A119D
	bit	6,a
	jp	z,out_of_range
	and	20h
	add	a,0DDh
	call	A1631
	ld	a,(D3667)
A119D:	and	7
	jp	A0E19
	;
A11A2:	ld	a,6
	call	A119D
A11A7:	pop	af
	ld	a,e
	call	z,A1643
	ret


; Обработка "and", "cp"
A11AD:	call	A0F7C
	ld	a,(D3666)
	or	a
	jp	z,A11EF
	cp	10h
	jp	z,A11D8
	cp	28h
	push	af
	call	z,A0E6D
	call	A0FC6
	ld	a,(D3667)
	and	7
	cp	4
	call	nz,out_of_range
	ld	a,6
	add	a,c
	call	A1631
	jp	A11A7
	;
A11D8:	ld	a,(D3667)
	cp	8
	jr	c,A11E9
	and	20h
	add	a,0DDh
	call	A1631
	ld	a,(D3667)
A11E9:	and	7
	add	a,c
	jp	A1631
	;
A11EF:	ld	a,46h
	add	a,c
	call	A1631
	call	A0FA8
	ld	a,e
	jp	A1643

L11FC:	ld	a,0EDh
	call	A1631
	call	A0F7C
	ld	a,(D3666)
	or	a
	jp	z,A1221
	cp	10h
	jr	nz,A122D
	ld	a,(D3667)
	cp	8
	call	nc,out_of_range
	and	7
	add	a,a
	add	a,a
	add	a,a
	or	4
	jp	A1631
	;
A1221:	ld	a,64h
	call	A1631
	call	A0FA8
	ld	a,e
	jp	A1643
	;
A122D:	cp	28h
	jp	z,out_of_range
	call	A0FC6
	ld	a,(D3667)
	and	7
	cp	4
	call	nz,out_of_range
	ld	a,34h
	jp	A1631

L1244:	ld	a,0EDh
	call	A1631
	ld	a,74h
	call	A1631
	call	A0F7C
	ld	a,(D3666)
	or	a
	call	nz,out_of_range
	call	A0FA8
	ld	a,e
	jp	A1643

L125F:	call	A0F7C
	ld	a,(D3666)
	cp	10h
	call	nz,out_of_range
	ld	a,0EDh
	call	A1631
	ld	a,(D3667)
	and	7
	add	a,a
	add	a,a
	add	a,a
	call	A1631
	call	A0F79
	call	A0FC6
	ld	a,(D3666)
	or	a
	call	nz,out_of_range
	call	A0FA8
	ld	a,e
	jp	A1643

L128E:	call	A0FD6
	call	A0DCC
	call	A0FC6
	ld	a,(D3666)
	or	a
	call	nz,out_of_range
	call	A0FA8
	push	de
	call	A0FB9
	call	nc,out_of_range
	ld	a,0EDh
	call	A1631
	ld	a,(D3667)
	and	7
	add	a,a
	add	a,a
	add	a,a
	or	1
	call	A1631
	pop	de
	ld	a,e
	jp	A1643

L12BF:	call	A0FB9
	call	A0FCE
	ld	a,(D3666)
	cp	20h
	call	nz,out_of_range
	ld	a,0EDh
	call	A1631
	ld	a,(D3667)
	and	6
	add	a,a
	add	a,a
	add	a,a
	or	4Ch
	jp	A1631

L12DF:	call	A0F7C
	ld	a,(D3666)
	cp	10h
	call	nz,out_of_range
	ld	a,0EDh
	call	A1631
	ld	a,(D3667)
	and	7
	cp	4
	call	nc,out_of_range
	rrca
	and	81h
	jp	A1631

L12FF:	call	A0F7C
	ld	a,(D3666)
	cp	10h
	call	nz,out_of_range
	ld	a,0EDh
	call	A1631
	ld	a,(D3667)
	or	a
	jr	z,A131A
	cp	6
	call	nz,out_of_range
A131A:	or	a
	ld	a,34h
	jp	z,A1631
	ld	a,3Fh
	jp	A1631


; Обработка "adc"
L1325:	call	A0FB9
	call	A0DCC
	call	A0FCE
	ld	a,(D3666)
	cp	10h
	jr	z,A1362
	cp	20h
	call	nz,out_of_range
	ld	a,(D3667)
	cp	4
	call	nz,out_of_range
	ld	a,0EDh
	call	A1631
	ld	a,c
	xor	10h
	rra
	and	8
	add	a,42h
	ld	c,a
A1350:	call	A0FB9
	call	nz,out_of_range
	call	A1CBB
	call	z,out_of_range
	call	A0FCE
	jp	A117F
	;
A1362:	ld	a,(D3667)
	cp	7
	call	nz,out_of_range
	jp	A11AD


; Обработка "add"
L136D:	call	A0FB9
	call	A0DCC
	call	A0FCE
	ld	a,(D3666)
	cp	10h
	jr	z,A1362
	cp	28h
	jr	z,A138E
	ld	a,(D3667)
	cp	4
	call	nz,out_of_range
	ld	c,9
	jp	A1350
	;
A138E:	ld	a,(D3667)
	push	af
	call	A0E6D
	call	A0FB9
	call	c,out_of_range
	push	af
	call	A1CBB
	call	z,out_of_range
	call	A0FCE
	ld	a,(D3667)
	cp	4
	call	z,out_of_range
	ld	b,a
	pop	af
	ld	a,b
	jr	z,A13BA
	pop	af
	cp	b
	call	nz,out_of_range
	ld	a,4
	push	af
A13BA:	pop	bc
	and	6
	ld	c,9
	jp	A0E19

A13C2:	ld	a,(D3666)
	cp	10h
	call	nz,out_of_range
	ret


; Обработка "ld"
L13CB:	xor	a
	ld	(D160C),a
	call	A0F7C
	ld	a,(D3666)
	or	a
	jr	z,A1409
	cp	10h
	jp	z,A14E2
	ld	a,(D3668)
	or	a
	jp	z,A146F
	ld	a,(D3667)
	and	6
	cp	4
	jp	z,A155F
	call	nc,out_of_range
	push	af
	call	A0F7C
	call	A0FCE
	call	A13C2
	ld	a,(D3667)
	cp	7
	call	nz,out_of_range
	ld	c,2
	pop	af
	jp	A0E19
	;
A1409:	push	de
	call	A160D
	call	A0FC6
	ld	a,(D3835)
	push	af
	ld	a,(D3839)
	push	af
	call	A0F79
	call	A0FCE
	ld	a,(D3666)
	or	a
	call	z,out_of_range
	cp	20h
	jr	c,A145F
	ld	a,(D3667)
	ld	c,a
	and	6
	cp	4
	jr	z,A144F
	ld	a,0EDh
	call	A1631
	ld	a,c
	ld	c,43h
	call	A0E19
A1440:	call	A160D
	pop	af
	ld	(D3839),a
	pop	af
	ld	(D3835),a
	pop	de
	jp	A1735
	;
A144F:	ld	a,(D3666)
	cp	28h
	call	z,A0E6D
	ld	a,22h
	call	A1631
	jr	A1440
	;
A145F:	ld	a,(D3667)
	cp	7
	call	nz,out_of_range
	ld	a,32h
	call	A1631
	jr	A1440
	;
A146F:	ld	a,(D3667)
	push	af
	call	A0F79
	ld	a,(D3666)
	cp	20h
	jr	nc,A149F
	or	a
	call	nz,out_of_range
	ld	a,(D3668)
	or	a
	jr	nz,A14B8
	ld	c,1
	pop	af
	push	af
	and	60h
	add	a,9Dh
	cp	0C0h
	call	nc,A1631
	pop	af
	and	6
	call	A0E19
	jp	A1735
	;
A149F:	call	nz,A0E6D
	pop	af
	cp	6
	call	nz,out_of_range
	call	A0FCE
	ld	a,(D3667)
	cp	4
	call	nz,out_of_range
	ld	a,0F9h
	jp	A1631
	;
A14B8:	pop	af
	ld	(D3667),a
	ld	c,a
	and	6
	cp	4
	jr	nz,A14D2
	ld	a,c
	cp	40h
	call	nc,A0E6D
	ld	a,2Ah
	call	A1631
	jp	A1735
	;
A14D2:	ld	a,0EDh
	call	A1631
	ld	a,c
	and	6
	ld	c,4Bh
	call	A0E19
	jp	A1735


A14E2:	call	A0FCE
	ld	a,(D3667)
	cp	8
	jr	nc,A152A
A14ED:	push	af
	call	A0F79
	ld	a,(D3666)
	or	a
	jr	nz,A150C
	ld	a,(D3668)
	or	a
	jp	nz,A1590
	call	A0FA8
	ld	c,6
	pop	af
	call	A0E19
	ld	a,e
	jp	A1643
	;
A150C:	ld	a,(D3666)
	cp	10h
	call	z,A15D0
	cp	20h
	jr	nz,A1520
	ld	a,(D3667)
	cp	4
	jp	c,A159E
A1520:	pop	af
	add	a,a
	add	a,a
	add	a,a
	add	a,40h
	ld	c,a
	jp	A1105
	;
A152A:	bit	6,a
	jr	nz,A154A
	push	af
	call	A0F79
	call	A13C2
	ld	a,(D3667)
	cp	7
	call	nz,out_of_range
	ld	a,0EDh
	call	A1631
	pop	af
	and	1
	ld	c,47h
	jp	A0E19
	;
A154A:	and	20h
	add	a,0DDh
	ld	(D160C),a
	call	A1631
	ld	a,(D3667)
	and	7
	ld	(D3667),a
	jp	A14ED

A155F:	ld	a,(D3667)
	push	de
	push	af
	call	A160D
	call	A0F79
	call	A0FCE
	pop	af
	push	af
	and	60h
	add	a,9Dh
	cp	0C0h
	call	nc,A1631
	ld	c,70h
	ld	a,(D3666)
	or	a
	jp	z,A15AF
	call	A1105
	call	A160D
	pop	af
	pop	de
	cp	40h
	ld	a,e
	call	nc,A1643
	ret

A1590:	pop	af
	cp	7
	call	nz,out_of_range
	ld	a,3Ah			; запис. биты
	call	A1631			; на 2-м проходе записать 9 бит
	jp	A1735

A159E:	call	A0FC6
	pop	af
	cp	7
	call	nz,out_of_range
	ld	a,(D3667)
	ld	c,0Ah
	jp	A0E19

A15AF:	call	A0FA8
	call	A0FCE
	ld	a,36h
	call	A1631
	ld	c,e
	ld	b,d
	call	A160D
	pop	af
	pop	de
	cp	40h
	ld	a,e
	call	nc,A1643
	call	A160D
	ld	e,c
	ld	d,b
	ld	a,c
	jp	A1643

A15D0:	ld	a,(D3667)
	bit	6,a
	jr	nz,A15F2
	cp	8
	ld	c,a
	ld	a,(D3666)
	ret	c
	pop	hl
	pop	af
	cp	7
	call	nz,out_of_range
	ld	a,0EDh
	call	A1631
	ld	a,c
	and	1
	ld	c,57h
	jp	A0E19
	;
A15F2:	ld	a,(D160C)
	or	a
	jp	nz,A0501		; "Syntax error"
	ld	a,(D3667)
	and	20h
	add	a,0DDh
	call	A1631
	ld	a,(D3667)
	and	7
	ld	(D3667),a
	ret

D160C:	db	0

A160D:	push	bc
	push	de
	push	hl
	ld	hl,D384C
	ld	de,T388D
	ld	c,41h
A1618:	ld	b,(hl)
	ld	a,(de)
	ld	(hl),a
	ld	a,b
	ld	(de),a
	inc	hl
	inc	de
	dec	c
	jp	nz,A1618
	pop	hl
	pop	de
	pop	bc
	ret

A1627:	push	af
	ld	a,(D3666)
	or	a
	call	nz,A0514		; "Warning: maybe mistake!"
	pop	af
	ret

A1631:	ld	b,a
	ld	a,(pass2)
	or	a
	push	hl
	ld	hl,(D37BC)		; счетчик org ?
	inc	hl
	ld	(D37BC),hl
	pop	hl
	ret	z
	jp	A1900			; 2-й проход, записать 9 битов

A1643:	ld	b,a
	ld	a,(D384C)
	or	40h
	ld	(D384C),a
	ld	a,(pass2)
	or	a
	push	hl
	ld	hl,(D37BC)		; счетчик org ?
	inc	hl
	ld	(D37BC),hl
	pop	hl
	ret	z
	jp	A1665			; 2-й проход

A165D:	ld	a,(D384C)
	and	0BFh
	ld	(D384C),a
A1665:	push	hl
	ld	hl,D384C
	ld	a,(hl)
	and	10h
	jr	z,A1677
	call	A04E3			; "Invalid use of external"
	ld	a,(hl)
	and	40h
	jp	A1714
	;
A1677:	ld	a,(hl)
	and	0A0h
	jp	z,A1719
	push	de
	push	bc
	inc	hl
	ld	a,(hl)
	and	3Fh
	ld	b,a
A1684:	ld	a,b
	or	a
	jp	z,A16FB
	inc	hl
	dec	b
	ld	a,(hl)
	or	a
	jp	m,A169D
	ld	(D3845),a
	ld	a,41h
	ld	e,2
A1697:	call	A171E
	jp	A1684
	;
A169D:	and	7Fh
	rra
	jp	c,A16CC
	cp	3
	jp	nz,A16B8
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	dec	b
	dec	b
	ld	(D37C8),de
	push	bc
	ld	b,a			; тип (".code", ".common" и т.д.)
	call	A182D			; если тип "common" - записать элемент "select COMMON block"
	pop	bc
A16B8:	ld	(D3845),a
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	dec	b
	dec	b
	ld	(D3846),de
	ld	a,43h
	ld	e,4
	jp	A1697
	;
A16CC:	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	dec	b
	dec	b
	push	bc
	push	hl
	ex	de,hl
	dec	hl
	ld	a,(hl)
	cp	6
	jr	c,A16DD
	ld	a,6
A16DD:	inc	a
	ld	(D383D),a
	dec	a
	ld	bc,6
	add	hl,bc
	ld	b,a
	ld	de,D3844
	ld	a,42h
	ld	(de),a
A16ED:	inc	de
	inc	hl
	ld	a,(hl)
	ld	(de),a
	djnz	A16ED
	call	A1725
	pop	hl
	pop	bc
	jp	A1684

A16FB:	ld	a,(D384C)
	and	40h
	push	af
	ld	a,1
	jr	nz,A1707
	ld	a,2
A1707:	ld	(D3845),a
	ld	a,41h
	ld	e,2
	call	A171E
	pop	af
	pop	bc
	pop	de
A1714:	ld	b,0
	call	z,A1900			; записать 9 битов
A1719:	call	A1900
	pop	hl
	ret

A171E:	ld	(D3844),a
	ld	a,e
	ld	(D383D),a
A1725:	push	bc
	push	hl
	ld	hl,D383E
	ld	(D36AA),hl
	ld	c,4			; элемент "extension LINK items"
	call	put_spec_item
	pop	hl
	pop	bc
	ret

A1735:	ld	a,(pass2)
	or	a
	push	hl
	ld	hl,(D37BC)		; счетчик org ?
	inc	hl
	inc	hl
	ld	(D37BC),hl
	pop	hl
	ret	z			; 1-й проход
	ld	a,(D3839)
	ld	b,a
	ld	a,(D384C)
	and	40h
	ld	a,b
	call	z,A17C4
	ld	a,(D3839)
	ld	b,a			; тип
	call	A182D			; если тип "common" - записать элемент "select COMMON block"
	and	83h
	jr	nz,A1764
	ld	b,e
	call	A1900			; записать 9 битов
	ld	b,d
	jp	A1900
	;
A1764:	ld	a,b
	and	80h
	push	bc
	jr	z,A1775
	ex	de,hl
	ld	hl,(D3837)
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A1775:	pop	bc			; b=тип
	call	A182D			; если тип "common" - записать элемент "select COMMON block"
	bit	7,b
	jr	z,A1785
	ld	a,(D384C)
	and	40h
	jp	nz,A165D
A1785:	ld	a,b
	and	3
	push	bc
	jr	z,A17BA
	call	A192F			; запись 3-х бит "1 00" спец-записи
	ld	b,e
	call	A1904			; запись 1-го байта
	ld	b,d
	call	A1904			; запись 1-го байта
A1796:	pop	bc
	bit	7,b
	ret	z
	ld	de,(D37BC)		; счетчик org ?
	dec	de
	dec	de
	ld	hl,(D3837)
	inc	hl
	ld	a,(D37BB)		; ячейка типа сегмента
	ld	b,a
	ld	a,(hl)
	and	0FCh			; сбр. 1,0 биты
	or	b			; + 1,0 биты (тип сегмента)
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	de,(D37C6)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret
A17BA:	ld	b,e
	call	A1900			; записать 9 битов
	ld	b,d
	call	A1900
	jr	A1796

A17C4:	push	af
	or	a
	jp	p,A17F8
	ld	a,(D3836)
	ld	(D3839),a
	ld	a,(D3835)
	or	a
	jp	z,A17F8
	push	hl
	push	bc
	push	de
	ld	a,b			; b=тип
	call	A182D			; если тип "common" - записать элемент "select COMMON block"
	and	3
	jp	nz,A17E4
	ld	a,d			; de=значение (метки)
	or	e
A17E4:	ld	c,9			; элемент "external + offset"
	call	nz,put_spec_item
	xor	a
	ld	(D3835),a
	pop	de
	pop	bc
	ld	hl,(D3837)
	inc	hl
	ld	a,(hl)
	ld	(D3839),a
	pop	hl
A17F8:	pop	af
	ret

A17FA:	ld	a,(D3815)		; символ ошибки
	cp	" "
	ret	z
	cp	"Q"			; вопрос
	jr	z,A180D
	ld	hl,(D366B)		; число ошибок
	inc	hl
	ld	(D366B),hl
	ret
A180D:	ld	hl,(D366D)		; число предупреждений
	inc	hl
	ld	(D366D),hl
	ret

A1815:	ld	hl,(D37BC)		; счетчик org ?
	ld	a,(D37CE)
	or	a
	jr	z,A1829
	push	de
	ld	de,(D37CF)
	add	hl,de
	pop	de
	ld	a,(D37D1)
	ret
A1829:	ld	a,(D37BB)		; ячейка типа сегмента
	ret


; Если тип "common" - записать элемент "select COMMON block"
; вход: b=тип
A182D:	push	af
	push	bc
	ld	a,b
	and	3
	cp	3
	jr	nz,A184F
	; тип "common"
	push	de
	push	hl
	ld	de,(D37C6)
	ld	hl,(D37C8)
	call	A0D1F			; сравнить hl с de
	ld	(D36AA),hl
	ld	(D37C6),hl
	ld	c,1			; элемент "select COMMON block"
	call	nz,put_spec_item
	pop	hl
	pop	de
A184F:	pop	bc
	pop	af
	ret



;[]====================================================[]
;   Записать спец-запись (Special LINK items)
;
; вход: b=запис. байт
;       c=элемент
;       de=16 бит значения метки
put_spec_item:
	push	bc
	; записать "заголовок" спец-записи
	ld	b,0
	call	A192F			; записать стандартные 3 бита "1 00"
	ld	a,c			; a=item
	add	a,a			; a << 4
	add	a,a
	add	a,a
	add	a,a
	ld	b,a
	; записать значение (0-15) в контр. поле (4 бита)
	rl	b
	call	putbit
	rl	b
	call	putbit
	rl	b
	call	putbit
	rl	b
	call	putbit
	pop	bc			; b=запис. байт
	;
	ld	a,c			; a=item
	cp	5
	jr	c,A1895			; только для B-поля
	cp	15			; элемент "end file"
	ret	z
	; Содержит A-поле
	; 2 бита типа поля (сегмента)
	ld	a,b
	rra
	rra
	call	putbit
	rr	b
	call	putbit
	; 16 бит значения метки
	ld	b,e
	call	A1904			; записать 1 байт
	ld	b,d
	call	A1904			; записать 1 байт
L188E:	call	A18B6			; "ret" (для extended REL - "A18B7" записать 2 байта)
	ld	a,c
	cp	8
	ret	nc			; только для A-поля
	; Содержит B-поле
A1895:	push	hl
	ld	hl,(D36AA)		; адрес ячейки... в записи
	dec	hl
	; 3 (5 бит) бита длины метки
	ld	a,(hl)			; длина имени
L189B:	call	putlensym		; "ext_putlensym" для extended REL
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
.loop:	ld	b,(hl)			; ячейка...
	ld	a,c
	cp	4
	jr	z,.loc1
	res	7,b
.loc1:	call	A1904			; записать 1 байт имени
	inc	hl
	dec	d
	jr	nz,.loop		; цикл записи имени
	pop	hl
A18B6:	ret


; Запись 2-х байт, для extended REL формата
A18B7:	ld	b,0
	call	A1904			; запись 1-го байта
	ld	b,0
	jr	A1904



;[]=================================[]
; Вставить длину имени метки
; вход: a=длина метки
putlensym:
	cp	8			; 6 при опции "-t" (макс. длина метки)
	jr	c,A18C7
A18C5:	ld	a,8			; 6 при опции "-t" (совмест. с Link-80)
A18C7:	ld	d,a
	and	7
	ld	b,a
	rra
	rra
	rra
	; записать 3 бита длины метки
	ld	b,a
	call	putbit
	rl	b
	call	putbit
	rl	b
	jp	putbit


;[]=======================================================[]
; Вставить длину имени метки для расш. REL формата
; вход: a=длина метки
ext_putlensym:
	cp	30			; макс. длина метки
	jr	c,A18E3
	ld	a,30
A18E3:	ld	d,a
	rla;				; (убрать для 6-ти битной длины метки)
	rla
	rla
	rla
	; записать 5 бит длины метки
	ld	b,a
	call	putbit
	rl	b
	call	putbit
	rl	b
	call	putbit
	rl	b
	call	putbit
	rl	b
	jp	putbit
	; записать 6-й бит длины метки
	;rl	b
	;jp	putbit



; Запись с начала границы байта или просто с ведущим бит="0" ?.
A1900:	xor	a			; сбр. CF (будет записан бит=0)
	call	putbit
; записать 8 бит (1 байт)
A1904:	push	bc
	rl	b			; цикл. сдвиг влево через перенос
	call	putbit
	rl	b
	call	putbit
	rl	b
	call	putbit
	rl	b
	call	putbit
	rl	b
	call	putbit
	rl	b
	call	putbit
	rl	b
	call	putbit
	rl	b
	call	putbit
	pop	bc
	ret


; Запись 3-х бит "1 00" спец-записи
A192F:	scf				; "1" (1-й бит)
	call	putbit
	ld	a,b
	rra				; цикл. сдвиг вправо через перенос
	rra
	call	putbit			; "0" (2-й бит)
	ld	a,b
	rra
	;
putbit:	push	hl			; "0" (3-й бит для A192F)
	ld	hl,D383B		; ячейка записываемого rel-байта
	rl	(hl)			; цикл. сдвиг влево через перенос
	inc	hl
	inc	(hl)			; outrem (счетчик границы байта)
	jr	nz,A1950		; байт не "собран"
	dec	hl
	ld	a,(hl)			; взять rel-байт (D383B)
	call	A4263			; записать байт в "outrel"
	ld	a,0F8h			; сбр. счетчик границы байта
	ld	(outrem),a
A1950:	pop	hl
	ret


A1952:	push	bc
	call	token_copy
	pop	bc
	jp	z,A1B1E			; также тест на "shr ", "shl ", "high",...
	jp	p,A19F8			; обработка чисел
	cp	" "
	jr	z,A1952
	cp	9			; Tab
	jr	z,A1952
	cp	"'"
	jr	z,A19B9			; парсинг строки символов
	cp	'"'
	jr	z,A19B9			; парсинг строки символов
	cp	"("
	jr	z,A19A2
	cp	")"
	jr	z,A19A5
	cp	"+"
	jr	z,A19A8
	cp	"-"
	jr	z,A19AB
	cp	"*"
	jr	z,A19AE
	cp	"/"
	jr	z,A19B1
	cp	";"
	jr	z,A199E
	cp	","
	jr	z,A199E
	cp	0Dh
	call	nz,A0501		; "Syntax error"
A199E:	xor	a
	jr	A19B6

; приоритеты операций ?
A19A2:	ld	a,2			; "("
	db	11h
A19A5:	ld	a,3			; ")"
	db	11h
A19A8:	ld	a,8			; операция "+"
	db	11h
A19AB:	ld	a,9			; "-"
	db	11h
A19AE:	ld	a,10			; "*"
	db	11h
A19B1:	ld	a,11			; "/"
	db	11h
A19B4:	ld	a,1
A19B6:	cp	1
	ret


; парсинг строки символов
A19B9:	ld	hl,0
	push	bc
	ld	b,a
	call	A3588
	cp	b
	jr	nz,A19CD
	call	A3583			; узнать след. символ не смещ. поток
	cp	b
	jr	nz,A19EB
	call	A3588
A19CD:	ld	l,a
	ld	(D37CC),a
	call	A3588
	cp	b
	jr	nz,A19E1
	call	A3583			; узнать след. символ не смещ. поток
	cp	b
	ld	a,b
	jr	nz,A19E6
	call	A3588
A19E1:	ld	h,l
	ld	l,a
	call	A3588
A19E6:	cp	b
	pop	bc
	jp	A1A59
	;
A19EB:	ld	de,D37CC
	ld	a,(de)
	or	a
	jr	nz,A19F4
	dec	a
	ld	(de),a
A19F4:	ld	a,b
	jr	A19E6


; Конвертация чисел
A19F8:	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	push	hl			; сохр. адрес потока
A19FD:	call	A35A7
	jp	p,A19FD			; пройти на конец числа
	ld	(D37CC),a
	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	dec	hl
	ld	(D36B1),hl
	call	A35A7			; взять посл. символ числа
	pop	hl
	ld	(D36B1),hl		; восст. адрес потока
	jp	nz,A1ADE
	cp	"F"+1			;47h  a=концовка числа
	jr	nc,A1A38
	ld	h,a
	ld	a,(D366F)		; база чисел
	cp	14
	jp	nc,A1ADE
	ld	l,a
	ld	a,h
	cp	"D"			; концовка числа
	jp	z,A1A7C ;A1A38
	cp	"B"			; концовка числа
	jp	nz,A1ADE
	ld	a,l			; база чисел
	cp	12
	jp	nc,A1ADE
	ld	a,h
	; концовка чисел
A1A38:	cp	"B"			; форматы записи числа
	jr	z,A1A62
	cp	"D"
	jr	z,A1A7C
	cp	"H"
	jr	z,A1A83
	cp	"O"
	jr	z,A1A50
	cp	"Q"
	call	nz,A0501		; "Syntax error"
	jr	nz,A1A7C
A1A50:	call	A1AA1
	cp	"O"
	jr	z,A1A5C
	cp	"Q"
A1A59:	call	nz,A0501		; "Syntax error"
A1A5C:	ld	c,20h
	ex	de,hl
	jp	A19B4

; Конвертация ascii -> bin-формат
A1A62:	ld	hl,0			; счетчик числа
A1A65:	call	A35A7
	cp	"B"
	jr	z,A1A5C
	sub	"0"
	call	m,A04F7			; "Error in number"
	cp	2
	call	nc,A04F7		; "Error in number"
	rra
	adc	hl,hl
	jr	A1A65

A1A7C:	call	A1A8A
	cp	"D"			; концовка числа
	jr	A1A59

A1A83:	call	A1ABA
	cp	"H"			; концовка числа
	jr	A1A59

; Конвертация ascii -> дес. формат
A1A8A:	ld	hl,0			; счетчик числа
A1A8D:	call	A35A7
	ret	z
	ret	m
	sub	"0"
	add	hl,hl
	ld	d,h
	ld	e,l
	add	hl,hl
	add	hl,hl
	add	hl,de
	ld	d,0
	ld	e,a
	add	hl,de
	jr	A1A8D

; Конвертация ascii -> окт. формат
A1AA1:	ld	hl,0			; счетчик числа
A1AA4:	call	A35A7
	ret	z
	ret	m
	sub	"0"
	cp	7+1
	call	nc,A04F7		; "Error in number"
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	e,a
	ld	d,0
	add	hl,de
	jr	A1AA4

; Конвертация ascii -> hex-формат
A1ABA:	ld	hl,0			; счетчик числа
A1ABD:	call	A35A7
	ret	m
	cp	"F"+1
	jr	nc,A1AD8
	sub	"0"
	cp	9+1
	jr	c,A1ACD
	sub	7
A1ACD:	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	e,a
	ld	d,0
	add	hl,de
	jr	A1ABD
	;
A1AD8:	cp	"H"			; концовка числа
	ret	z
	jp	A04F7			; "Error in number"


A1ADE:	ld	a,(D3670)
	or	a
	jr	nz,A1B15
	ld	hl,0
	push	bc
A1AE8:	call	A35A7
	jp	m,A1B11
	sub	"0"
	cp	9+1
	jr	c,A1AF9
	sub	7
	call	c,A04F7			; "Error in number"
A1AF9:	ld	c,a
	ld	b,0
	ld	a,(D366F)		; база чисел
	dec	a
	cp	c
	call	c,A04F7			; "Error in number"
	inc	a
	ld	e,a
	ld	d,b
	push	bc
	call	A20AC
	ex	de,hl
	pop	bc
	add	hl,bc
	jp	A1AE8
	;
A1B11:	pop	bc
	jp	A1B18
	;
A1B15:	call	A1A8A
A1B18:	call	A3595			; поток на байт назад
	jp	A1A5C


A1B1E:	push	bc
	call	A3595			; поток на байт назад
	ld	a,(idlen)		; длина идентиф.
	ld	(D37CC),a
	cp	A1C64+1			; 4+1  длина элемента списка + 1
	jr	nc,A1B8F
	dec	a
	jp	z,A1C53			; тест id на "$"
	call	A0BCD
	jr	z,A1B8F
	ld	hl,T1C66		; список "shr ", "shl ", "high",...
	ld	c,A1C65			; 17 число слов в списке
	jr	A1B47
	;
A1B40:	dec	c
	jr	z,A1B8F
A1B44:	inc	hl
	djnz	A1B44
A1B47:	ld	b,A1C64			; 4 длина элемента списка
	ld	de,idname		; буфер имени идентиф.
A1B4C:	ld	a,(de)
	cp	(hl)
	jr	nz,A1B40
	inc	de
	inc	hl
	djnz	A1B4C
	ld	hl,A1CAA-1
	add	hl,bc
	ld	a,(hl)
	cp	1Eh
	jr	nz,A1B60
	ld	(D3669),a
A1B60:	pop	bc
	or	a
	jp	p,A19B6
	call	skipspace
	ld	de,0FFFFh
A1B6B:	cp	";"
	jr	z,A1B89
	cp	0Dh
	jr	z,A1B89
	or	a
	jr	nz,A1B81
	call	nextchar
	cp	"&"
	call	z,nextchar
	jr	A1B6B
	;
A1B81:	call	nextchar
	cp	0Dh
	jr	nz,A1B81		; пройти до конца строки
	inc	de
A1B89:	call	A3595			; поток на байт назад
	jp	A19B4


A1B8F:	ld	hl,(D36B1)		; тек. адрес в потоке
	push	hl
	call	nextchar
	cp	"#"
	jr	nz,A1BBA
	call	nextchar
	cp	"#"			; токен ##
	jr	nz,A1BBA
	scf
	call	A0C9C
	call	A27C5
	inc	hl
	ld	b,(hl)
	bit	5,b
	call	nz,A04ED		; "многократное опред. метки"
	ld	a,b
	and	3
	or	80h
	ld	(hl),a
	pop	bc
	dec	hl
	jr	A1BDC
	;
A1BBA:	pop	hl
	ld	(D36B1),hl		; тек. адрес в потоке
	call	A0BCD
	jp	z,A1C21
	ld	a,(D3669)
	or	a
	jr	z,A1BD8
	scf
	call	A0BCD
	jr	z,A1BDC
	xor	a
	ld	hl,(D3995)
	ld	(hl),a
	jr	A1BDC
	;
A1BD8:	scf
	call	A0C9C
A1BDC:	and	0A3h
	ld	b,a
	bit	7,a
	jr	z,A1BEB
	ld	(D3836),a
	ld	b,80h
	ld	(D3837),hl
A1BEB:	and	10h
	call	nz,A04D9		; "двойное определение метки"
	ld	a,(hl)
	and	40h
	or	a
	ld	a,b
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	bc
	ld	c,a
	jr	z,A1C00
	ld	e,0
A1C00:	and	3
	cp	3
	jr	nz,A1C10
	push	de
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D37C8),de
	pop	de
A1C10:	ld	a,c
	bit	5,a
	jp	nz,A19B4
	and	80h
	call	z,undefined		; метка не определена
	ld	de,0
	jp	A19B4
	;
A1C21:	ld	(D36AA),hl
	ld	a,(hl)
	and	7Fh
	cp	42h
	jp	c,A1C4D
	ld	a,(hl)
	and	38h
	push	af
	ld	a,(D3666)
	or	a
	call	nz,A0501		; "Syntax error"
	pop	af
	ld	(D3666),a
	inc	hl
	inc	hl
	ld	a,(hl)
	ld	(D3667),a
	call	A1CBB
	call	z,A1CD0
	dec	hl
	ld	a,(hl)
	dec	hl
	jp	A1BDC
	;
A1C4D:	inc	hl
	ld	a,(hl)
	dec	hl
	jp	A1BDC
	;
A1C53:	ld	a,(idname)		; имя идентиф.
	cp	"$"
	jp	nz,A1B8F
	call	A1815
	ex	de,hl
	add	a,20h
	pop	bc
	ld	c,a
	jp	A19B4



A1C64	equ	4			; длина элемента списка
A1C65	equ	17			; число слов в списке

T1C66:	db	"XOR "
	db	"AND "
	db	"NOT "
	db	"MOD "
	db	"SHL "
	db	"SHR "
	db	"OR  "
	db	"EQ  "
	db	"NE  "
	db	"LT  "
	db	"LE  "
	db	"GT  "
	db	"GE  "
	db	"LOW "
	db	"HIGH"
	db	"NUL "
	db	"TYPE"
	;
A1CAA:	db	1Eh
	db	0FFh
	db	16h
	db	15h
	db	14h
	db	13h
	db	12h
	db	11h
	db	10h
	db	0Fh
	db	4
	db	0Eh
	db	0Dh
	db	0Ch
	db	7
	db	6
	db	5


A1CBB:	ld	a,(D3666)
	cp	20h
A1CC0:	ret	nz
	ld	a,(D3667)
	cp	6
	ret	nz
	ld	a,(D3665)
A1CCA:	cp	41h
	ret	z
	cp	61h
	ret

A1CD0:	call	A3583			; узнать след. символ не смещ. поток
	cp	"'"
	call	z,nextchar
	ret


; калькулятор ?
A1CD9:	xor	a
	ld	b,a
	ld	l,a
	ld	h,a
	ld	c,20h
	ld	(D383F),a
	ld	(D3835),a
	ld	(D37CC),a
	ld	(D3669),a
	ld	(D384C),a
	ld	(D384D),a
	ld	(D384B),a
	ld	(D3666),a
	ld	(D3667),a
	add	hl,sp
	ld	(save_stack),hl		; сохр. стек
	ex	de,hl
	ld	hl,(D39A1)
	call	A0D1F			; сравнить hl с de
	jp	nc,stack_overflow	; переполн. стека (калькулятора ?)
	push	bc
A1D09:	call	A1952
	jp	m,A1D71
	jp	z,A1DB3			; 
	cp	3
	jp	m,A1DD4			; 
	jp	z,A1E48			; ")"
	cp	18h			; 24
	jr	c,A1D24
	cp	1Eh			; 30
	call	c,A1DBC
A1D24:	ld	c,a
	ld	(D383E),a
	call	A1DD9
	dec	a
	cp	b
	ld	a,c
	jp	nc,A1E62
	cp	8
	jp	z,A1E5A
	cp	9
	jp	z,A1E5A
A1D3B:	call	A1E95
	ld	a,c
	ld	(D38CF),a
	call	A1DE4
	cp	2
	jr	z,A1D92
	or	a
	jr	nz,A1D5D
	ld	a,(D383E)
	cp	3
	jr	nz,A1D92
	call	z,A0501			; "Syntax error"
	push	bc
	jr	A1D92
	;
A1D5D:	push	bc
	call	A1DD9
	push	af
	ld	a,(D38CF)
	ld	c,a
	pop	af
	call	A1DBC
	ld	b,a
	ld	a,(D383E)
	jr	A1D24
	;
A1D71:	push	af
	call	A3595			; поток на байт назад
	call	nextchar
	cp	","
	jr	nz,A1D8E
	ld	a,(D383F)
	or	a
	jr	z,A1D8E
	pop	af
	xor	a
	ld	(D383F),a
	ld	a,1Ch
	jr	A1D24
	;
A1D8E:	pop	af
	jp	A1DF5
	;
A1D92:	ld	a,(D38CF)
	ld	c,a
	ld	a,(D383E)
	cp	3
	jr	z,A1DA5
	push	bc
	call	A1DBC
	jp	A1E62
	;
A1DA5:	pop	bc
	push	bc
	ld	a,b
	call	A1DD9
	ld	b,a
	ld	a,(D38CF)
	ld	c,a
	jr	A1DB6
	;
A1DB3:	call	A1F12
A1DB6:	call	A1DBC
	jp	A1D09

A1DBC:	pop	hl
	push	de
	ld	e,a
	ld	a,c
	and	3
	cp	3
	ld	a,e
	jr	nz,A1DCF
	ex	de,hl
	ld	hl,(D37C8)
	ex	(sp),hl
	push	hl
	ex	de,hl
A1DCF:	ld	d,1			; !!
	ld	e,c			;
	push	de
A1DD3:	jp	(hl)


A1DD4:	ld	b,a
	push	bc
	jp	A1D09

A1DD9:	push	de
	ld	hl,A1F49
	ld	e,a
	ld	d,0
	add	hl,de
	ld	a,(hl)
	pop	de
	ret

A1DE4:	pop	hl
	pop	bc
	ld	a,b
	cp	1
	jr	nz,A1DF4
	call	A0501			; "Syntax error"
	push	bc
	xor	a
	ld	b,a
	cp	1
A1DF4:	jp	(hl)

A1DF5:	pop	hl
	ld	a,h
	cp	1
	sbc	a,a
	ld	(D383A),a
	push	hl
A1DFE:	call	A1E95
	ld	a,c
	ld	(D38CF),a
	call	A1DE4
	jp	m,A1E25
	cp	2
	jp	z,A2181
	push	bc
	ld	a,(D38CF)
	ld	c,a
	call	A1DBC
	jp	A1DFE

A1E1B:	ld	de,0
	call	A359F			; продвинуть полож. в потоке на 1 байт
	xor	a
	ld	(D38CF),a
A1E25:	ld	a,(D38CF)
	ld	b,a
	ld	(D3839),a
	and	3
	ld	c,a
	jr	z,A1E34
	ld	c,20h
A1E34:	ld	a,b
	and	80h
	or	c
	ld	hl,D384C
	or	(hl)
	ld	(hl),a
	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	ld	c,(hl)
	ld	a,e
;	ld	hl,(save_stack)
;	ld	sp,hl
	ld	sp,(save_stack)		; восст. стек
	ret

A1E48:	ld	(D383E),a
	pop	de
	ld	a,d
	cp	2
	call	z,A0501			; "Syntax error"
	or	a
	call	z,A0501
	push	de
	jp	A1D3B

A1E5A:	ex	(sp),hl
	ld	a,h
	ex	(sp),hl
	dec	a
	jp	z,A1D3B
	ld	a,c
A1E62:	pop	bc
	ld	d,a
	push	bc
	ld	a,b
	dec	a
	ld	a,d
	jr	z,A1E8C
	ld	a,d
	cp	7
	jr	z,A1E8C
	cp	8
	jp	z,A1D09
	cp	15h
	jr	z,A1E8C
	cp	16h
	jr	z,A1E8C
	cp	1Eh
	jr	z,A1E8C
	cp	9
	call	nz,A0501		; "Syntax error"
	ld	a,17h
A1E8C:	ld	b,a
	push	bc
	call	A1DD9
	ld	b,a
	jp	A1D09


A1E95:	pop	hl
	ld	(D38D1),hl
	pop	de
	ld	a,d
	or	a
	push	de
	jr	nz,A1EA7
	ld	de,0
	push	de
	ld	de,0120h		; T0120
	push	de
A1EA7:	call	A1EF9
	ld	(D37CA),hl
	ld	(D3842),de
	ld	a,c
	ld	(D38CF),a
	call	A1DE4
	jp	m,A1EF0
	sub	2
	jp	z,A1EF0
	ld	(D38D0),a
	cp	5
	jr	z,A1EDA
	cp	14h
	jr	z,A1EDA
	cp	13h
	jr	z,A1EDA
	cp	15h
	jr	z,A1EDA
	cp	1Ch
	jr	z,A1EDA
	call	A1EF9
A1EDA:	ld	a,(D38D0)
	ld	hl,(D38D1)
	push	hl
	ld	hl,L1F68-4		; A1F64
	add	a,a
	add	a,l
	ld	l,a
	ld	a,0
	adc	a,h
	ld	h,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jp	(hl)
	;
A1EF0:	push	bc
	ld	a,(D38CF)
	ld	c,a
	ld	hl,(D38D1)
	jp	(hl)

A1EF9:	pop	hl
	pop	bc
	dec	b
	call	nz,A0501		; "Syntax error"
	jr	z,A1F04
	inc	b
	push	bc
	jp	(hl)
	;
A1F04:	pop	de
	ld	a,c
	and	3
	cp	3
	jp	nz,A1DD3
	ex	(sp),hl
	ld	(D37C8),hl
	ret

A1F12:	push	af
	push	de
	push	hl
	ld	a,c
	rlca
	and	7
	or	80h
	call	A2207
	and	7
	cp	6
	jr	nz,A1F31
	push	de
	ld	de,(D37C8)
	call	A1F41
	pop	de
	jr	A1F3A
	;
A1F31:	cp	1
	jr	nz,A1F3A
	ld	de,(D3837)
A1F3A:	call	A1F41
	pop	hl
	pop	de
	pop	af
	ret

A1F41:	ld	a,e
	call	A2207
	ld	a,d
	jp	A2207


A1F49:	db	1,1,1,1,4,4,5,6
	db	8,8,9,9,9,9,9,7
	db	7,7,7,7,7,10,10,10
	db	2,2,2
	db	2,3,2,10
	;
L1F68:	dw	L1F9E
	dw	L1FA8
	dw	L1FB2
	dw	L1FBC
	dw	L2019
	dw	L2047
	dw	L2097
	dw	L20E3
	dw	L2152
	dw	L1FEB
	dw	L1FFA
	dw	L218C
	dw	L2197
	dw	L21A3
	dw	L21B0
	dw	L21B6
	dw	L21BF
	dw	L21F1
	dw	L21E2
	dw	L1FD3
	dw	L1FA7
	dw	L1FA7
	dw	L1FA7
	dw	L1FA7
	dw	L1FA7
	dw	L222E
	dw	L224D


L1F9E:	call	A20C9
	ld	a,d
	or	h
	ld	d,a
	ld	a,e
	or	l
	ld	e,a
L1FA7:	ret

L1FA8:	call	A20C9
	ld	a,d
	xor	h
	ld	d,a
	ld	a,e
	xor	l
	ld	e,a
	ret

L1FB2:	call	A20C9
	ld	a,d
	and	h
	ld	d,a
	ld	a,e
	and	l
	ld	e,a
	ret

L1FBC:	ld	hl,(D3842)
	ld	a,h
	cpl
	ld	d,a
	ld	a,l
	cpl
	ld	e,a
	ld	a,(D38CF)
	ld	c,a
	and	83h
A1FCB:	ld	a,5
	jp	nz,A21FD
	jp	A2207

L1FD3:	ld	hl,(D3842)
	ld	a,h
	cpl
	ld	d,a
	ld	a,l
	cpl
	ld	e,a
	inc	de
	ld	a,(D38CF)
	ld	c,a
	and	83h
	ld	a,6
	jp	nz,A21FD
	jp	A2207

L1FEB:	call	A20C9
	ex	de,hl
	inc	de
A1FF0:	dec	de
	ld	a,d
	or	e
	jr	z,A1FF8
	add	hl,hl
	jr	A1FF0
	;
A1FF8:	ex	de,hl
	ret

L1FFA:	call	A20C9
	inc	hl
A1FFE:	dec	hl
	ld	a,l
	or	h
	ret	z
	srl	d
	rr	e
	jp	A1FFE

; ?
;L2009:	ld	hl,(D3842)
;	ld	a,(D38CF)
;	and	80h
;	ret	z
;	ld	a,c
;	and	80h
;	call	m,A04E3
;	ret

L2019:	call	A202A
	ld	a,(D38CF)
	or	c
	ld	c,a
	and	83h
	cp	80h
	ret	nz
	ld	(D3835),a
	ret

A202A:	ld	a,(D38CF)
	cp	20h
	jr	z,A2037
	ld	hl,(D37CA)
	ld	(D37C8),hl
A2037:	ld	hl,(D3842)
	add	hl,de
	ex	de,hl
	call	A20D9
	ld	a,8
	jp	nz,A21FD
	jp	A2207

L2047:	ld	hl,(D3842)
	call	A2090
	ld	a,(D38CF)
	and	83h
	jp	m,A206E
	jp	z,A206E
	ld	a,c
	and	83h
	jp	m,A206E
	jp	z,A206D
	ld	a,(D38CF)
	cp	c
	jp	nz,A206E
	ld	c,20h
	jp	A2088
	;
A206D:	dec	a
A206E:	push	af
	ld	a,(D38CF)
	and	83h
	jp	nz,A2082
	ld	a,c
	and	83h
	cp	80h
	jp	nz,A2082
	ld	(D3835),a
A2082:	ld	a,(D38CF)
	or	c
	ld	c,a
	pop	af
A2088:	ld	a,7
	jp	nz,A21FD
	jp	A2207

A2090:	ld	a,e
	sub	l
	ld	e,a
	ld	a,d
	sbc	a,h
	ld	d,a
	ret

L2097:	ld	hl,(D3842)
	call	A20B2
	ld	a,(D38CF)
	or	c
	ld	c,a
	and	83h
	ld	a,9
	jp	nz,A21FD
	jp	A2207

A20AC:	call	A20B2
	ld	c,20h
	ret

A20B2:	ld	b,h
	ld	c,l
	ld	hl,0
	ld	a,11h
A20B9:	dec	a
	jr	z,A20C7
	add	hl,hl
	sla	c
	rl	b
	jr	nc,A20B9
	add	hl,de
	jp	A20B9
	;
A20C7:	ex	de,hl
	ret

A20C9:	ld	a,(D38CF)
	cp	c
	call	nz,A051D		; "Error in relocatable value"
	cp	20h
	call	nz,A051D
	ld	hl,(D3842)
	ret

A20D9:	ld	a,(D38CF)
	and	83h
	ret	z
	ld	a,c
	and	83h
	ret

L20E3:	ld	hl,(D3842)
	call	A20F8
	ld	a,(D38CF)
	or	c
	ld	c,a
	and	83h
	ld	a,0Ah
	jp	nz,A21FD
	jp	A2207

A20F8:	push	bc
	ex	de,hl
	ld	a,d
	or	e
	call	z,A04BB			; "Divide by zero"
	ld	a,d
	or	a
	ld	b,d
	call	m,A214A
	ld	a,h
	xor	b
	ld	b,a
	ld	a,h
	or	l
	jr	z,A211C
	ld	a,h
	or	a
	ex	de,hl
	call	m,A214A
	push	bc
	call	A211F
	pop	af
	or	a
	call	m,A214A
	ex	de,hl
A211C:	ex	de,hl
	pop	bc
	ret

A211F:	ld	a,h
	cpl
	ld	b,a
	ld	a,l
	cpl
	ld	c,a
	inc	bc
	ld	hl,0
	ld	a,11h
	push	af
	or	a
	jp	A213A

A2130:	push	af
	push	hl
	add	hl,bc
	jr	nc,A2139
	pop	af
	scf
	db	3Eh			; ld a,n
A2139:	pop	hl			; 0E1h
A213A:	rl	e
	rl	d
	adc	hl,hl
	pop	af
	dec	a
	jr	nz,A2130
	srl	h
	rr	l
	ret

A214A:	xor	a
	ld	c,a
	sub	e
	ld	e,a
	ld	a,c
	sbc	a,d
	ld	d,a
	ret

L2152:	ld	hl,(D3842)
	push	bc
	ex	de,hl
	ld	a,d
	or	e
	jr	z,A2170
	ld	a,h
	or	l
	jr	z,A2170
	ld	a,h
	xor	d
	push	af
	push	de
	ex	de,hl
	call	A20F8
	ex	de,hl
	pop	hl
	pop	af
	call	m,A214A
	ex	de,hl
A2170:	ex	de,hl
	pop	bc
	ld	a,(D38CF)
	or	c
	ld	c,a
	and	83h
	ld	a,0Bh
	jp	nz,A21FD
	jp	A2207

A2181:	ld	a,"O"			; символ ошибки
	ld	de,A1E1B
	push	de
	push	bc
	ld	b,a
	jp	A053F

L218C:	call	A21D4
	call	A0D1F			; сравнить hl с de
	sub	1
	jr	A21AA

L2197:	call	A21D4
	call	A0D1F			; сравнить hl с de
	sub	1
	ccf
	jr	A21AA

L21A3:	call	A21D4
	ex	de,hl
	call	A0D1F			; сравнить hl с de
A21AA:	sbc	a,a
	ld	d,a
	ld	e,a
	ld	c,20h
	ret

L21B0:	call	A21D4
	jr	A21C3

L21B6:	call	A21D4
	call	A0D1F			; сравнить hl с de
	jr	A21AA

L21BF:	call	A21D4
	ex	de,hl
A21C3:	ld	a,e
	sub	l
	ld	e,a
	ld	a,d
	sbc	a,h
	jr	c,A21AA
	or	e
	scf
	jr	z,A21AA
	ccf
	jr	A21AA

A21D4:	ld	a,(D38CF)
	cp	c
	call	nz,A051D		; "Error in relocatable value"
	call	A2237
	ld	hl,(D3842)
	ret

L21E2:	ld	hl,(D3842)
	ld	e,h
	xor	a
	ld	d,a
	ld	a,(D38CF)
	ld	c,a
	ld	a,3
	jr	A21FD

L21F1:	ld	hl,(D3842)
	ld	e,l
	xor	a
	ld	d,a
	ld	a,(D38CF)
	ld	c,a
	ld	a,4
A21FD:	push	af
	ld	a,(D384C)
	or	40h
	ld	(D384C),a
	pop	af
A2207:	push	hl
	push	af
	ld	hl,D384D
	inc	(hl)
	ld	a,(hl)
	and	3Fh
	jr	z,A221C
	add	a,l
	ld	l,a
	jr	nc,A2218
	inc	h
A2218:	pop	af
	ld	(hl),a
	pop	hl
	ret

A221C:	dec	(hl)
	ld	a,c
	and	83h
	jr	z,A222B
	ld	a,(D384C)
	or	10h
	ld	(D384C),a
A222B:	pop	af
	pop	hl
	ret

L222E:	call	A20C9
	ld	a,l
	and	3Fh
	add	a,e
	ld	e,a
	ret

A2237:	and	3
	cp	3
	ret	nz
	push	hl
	push	de
	ld	de,(D37C8)
	ld	hl,(D37CA)
	sbc	hl,de
	call	nz,A051D		; "Error in relocatable value"
	pop	de
	pop	hl
	ret

L224D:	ld	a,(D38CF)
	ld	e,a
	ld	d,0
	ld	c,20h
	ld	a,(D3815)		; символ ошибки
	cp	" "
	ret	z
	cp	"O"
	jr	nz,A2261
	ld	e,0
A2261:	ld	a," "
	ld	(D3815),a		; символ ошибки
	ret


; Обработка "org"
L2267:	call	A2784
	call	A1CD9
	ex	de,hl
	ld	a,b
	and	20h
	jp	z,A052F			; "Error in value"
	xor	a
	ld	(D37D2),a
	ld	a,b
	and	3
	ld	b,a
	jr	z,A229A
	ld	a,(D37BB)		; ячейка типа сегмента
	cp	b
	jp	nz,A051D		; "Error in relocatable value"
	cp	3			; common
	jr	nz,A229A
	push	hl
	ld	de,(D37C4)		; размер common-области
	ld	hl,(D37C8)
	call	A0D1F			; сравнить hl с de
	jp	nz,A051D		; "Error in relocatable value"
	pop	hl
A229A:	ld	a,(D37BB)		; ячейка типа сегмента
	ld	b,a
A229E:	ex	de,hl
	ld	hl,(D37C4)		; размер common-области
	ld	(D37C8),hl
	ld	a,(pass2)
	or	a
	call	nz,A182D		; на 2-м проходе
	ld	(D37BC),de		; счетчик org ?
	ld	c,11			; элемент "set loading location counter to A"
	ld	a,(D37D2)
	or	a
	jr	nz,A22C6
	ld	a,(pass2)
	or	a
	call	nz,put_spec_item	; на 2-м проходе (и 1-м ?)
	ld	a,(D38D3)
	or	a
	call	z,A2310
A22C6:	ld	a,(D38D3)
	or	a
	ret	z
	xor	a
	ld	(D38D3),a
	call	token_copy
	jp	z,A0514			; "Warning: maybe mistake!"
	ret


; Обработка "aseg"
L22D6:	call	A2310
	xor	a			; тип "aseg"
	ld	b,a
	ld	(D37BB),a		; ячейка типа сегмента
	inc	a
	ld	(D38D3),a
	ld	(D37D2),a
	ld	hl,(D37BE)		; размер aseg-области
	jp	A229E


; Обработка "cseg"
L22EC:	call	A2310
	ld	a,1			; тип "cseg"
	ld	(D38D3),a
	ld	b,a
	ld	(D37BB),a		; ячейка типа сегмента
	ld	hl,(D37C0)		; размер code-области
	jp	A229E


; Обработка "dseg"
L22FE:	call	A2310
	ld	a,2			; тип "dseg"
	ld	(D38D3),a
	ld	b,a
	ld	(D37BB),a		; ячейка типа сегмента
	ld	hl,(D37C2)		; размер data-области
	jp	A229E


A2310:	ld	a,(D38D3)
	or	a
	call	nz,A2784
	ld	a,(D37BB)		; ячейка типа сегмента
	ld	bc,D37BE		; ячейка размера aseg-области
	and	3
	cp	3			; "common"
	jr	z,A233E
	add	a,a
	ld	l,a
	ld	h,0
	add	hl,bc
A2329:	push	hl
	ld	e,(hl)			; de=размер одной из aseg/cseg/dseg/common областей
	inc	hl
	ld	d,(hl)
	ld	hl,(D37BC)		; счетчик org ?
	call	A0D1F			; сравнить hl с de
	pop	de
	ret	c
	ex	de,hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	xor	a
	ld	(D37D2),a
	ret
A233E:	ld	hl,(D37C4)		; размер common-области
	inc	hl
	inc	hl
	jr	A2329


A2346:	push	af
	ld	a,(pass2)
	or	a
	jr	z,A2363			; 1-й проход
	ld	a,(D37D2)
	or	a
	jr	z,A2367
	push	bc
	push	de
	push	hl
	ld	de,(D37BE)		; размер aseg-области
	ld	bc,000Bh		; c=элемент "set loading location counter to A"
	call	put_spec_item		; записать значение aseg-области
	pop	hl
	pop	de
	pop	bc
A2363:	xor	a
	ld	(D37D2),a
A2367:	pop	af
	ret


; обработка "db"
A2369:	call	skipspace
	call	A3595			; поток на байт назад
	cp	'"'
	jr	z,A2379
	cp	"'"
	jr	nz,A23F5
A2379:	ld	b,a
	call	A3588
	call	A3588
	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	dec	hl
	push	hl
	cp	b
	ld	c,0
	jr	z,A2399
A238C:	inc	c
	call	A3588
	cp	0Dh			; конец строки
	jr	z,A23A0
	cp	b
	jr	nz,A238C
A2399:	call	nextchar
	cp	b
	jr	z,A238C
A23A0:	call	A3595			; поток на байт назад
	call	skipspace
	cp	","
	jr	z,A23B6
	cp	";"
	jr	z,A23B6
	cp	b
	jr	z,A23B6
	cp	0Dh
A23B6:	pop	hl
	ld	(D36B1),hl		; тек. адрес в потоке
	jr	nz,A23F5
	ld	a,c
	cp	2
	jr	c,A23F5
	call	A3583			; узнать след. символ не смещ. поток
	ld	b,a
	call	A3588
	call	A3588
	jr	A23D8
	;
A23D0:	push	bc
	call	A1631
	pop	bc
	call	A3588
A23D8:	cp	0Dh			; конец строки
	ret	z
	cp	b
	jr	nz,A23D0
	call	A3583			; узнать след. символ не смещ. поток
	cp	b
	jr	z,A23EF
	call	nextchar
	cp	","
	jr	z,A2369
	ret
	;
A23EF:	call	A1631
	jr	A2369
	;
A23F5:	call	A0DD8
	push	af
	ld	a,(D37CC)
	or	a
	jp	m,A17F8
	pop	af
	call	A1643
	ld	a,c
	cp	","
	jp	z,A2369
	ret


A240B:	call	A1CD9
	push	af
	ld	a,b
	and	83h
	call	nz,A051D		; "Error in relocatable value"
	pop	af
	ret


; обработка "dc"
A2417:	call	skipspace
	cp	'"'
	jr	z,A2424
	cp	"'"
	call	nz,out_of_range
A2424:	ld	c,a
	xor	a
A2426:	push	af
	call	A3588
	cp	0Dh
	jp	z,A17F8
	cp	c
	jr	nz,A243A
	call	nextchar
	cp	c
	jr	nz,A2445
A243A:	ld	b,a
	pop	af
	push	bc
	or	a
	call	nz,A1631
	pop	af
	jr	A2426
	;
A2445:	pop	bc
	push	af
	ld	a,b
	add	a,a
	ld	a,b
	jr	z,A2452
	or	80h			; захорить посл. символ
	call	A1631
A2452:	pop	af
	cp	","
	jp	z,A2417
	ret


; Обработка "ds"
L2459:	call	A2495
	call	A2346
	ld	a,c
	cp	","
	jr	nz,A246D
	push	de
	call	A0DD8
	ld	b,e
	pop	de
	jr	A2475
	;
A246D:	ld	a,(D3A2C)		; флаг "zero init DS"
	or	a
	jr	z,A248A			; false, не инициализ.
	ld	b,0
A2475:	ld	a,d			; de=счетчик
	or	e
	ret	z
	dec	de
	ld	hl,(D37BC)		; счетчик org ?
	inc	hl
	ld	(D37BC),hl
	ld	a,(pass2)
	or	a
	call	nz,A1900		; 2-й проход, записать 9 битов
	jr	A2475
	;
A248A:	ld	hl,(D37BC)		; счетчик org ?
	add	hl,de
	ld	a,(D37BB)		; ячейка типа сегмента
	ld	b,a
	jp	A229E


A2495:	call	A240B
	ld	a,(pass2)
	or	a
	ret	nz			; 2-й проход
	ld	a,(D3815)		; символ ошибки
	cp	"U"
	ret	nz
	inc	a
	ld	(D3815),a		; "V"
	ret


; обработка "dw"
A24A8:	call	A2346
	call	A1CD9
	call	A1735
	ld	a,c
	cp	","
	jr	z,A24A8
	ret


A24B8:	ld	a,(D3671)
	dec	a
	jp	m,A04CF			; "Bad conditional"
	ld	b,a
	ld	(D3671),a
	ld	a,(D3672)
	dec	a
	cp	b
	jr	nz,A24CD
	ld	(D3672),a
A24CD:	ld	a,(D3672)
	sub	b
	sbc	a,a
	inc	a
	ld	(D36A6),a
	call	A2508
	ld	(D3673),a
	jp	A359F			; продвинуть полож. в потоке на 1 байт

L24DF:	ld	a,(D3673)
	or	a
	call	nz,A04CF		; "Bad conditional"
	ld	a,(D3671)
	or	a
	call	z,A04CF			; "Bad conditional"
	ld	hl,D3672
	sub	(hl)
	jp	z,A2504
	dec	a
	jp	nz,A359F		; продвинуть полож. в потоке на 1 байт
	inc	(hl)
	dec	a
A24FA:	ld	(D36A6),a
	inc	a
	ld	(D3673),a
	jp	A359F			; продвинуть полож. в потоке на 1 байт
	;
A2504:	dec	(hl)
	jp	A24FA

A2508:	ld	a,(D3671)
	ld	e,a
	cp	32h
	ld	a,0
	ret	nc
	ld	d,a
	ld	hl,T3674
	add	hl,de
	scf
	ld	a,(hl)
	ret

A2519:	push	af
	call	A2508
	ld	de,D3673
	jp	nc,A2525
	ld	a,(de)
	ld	(hl),a
A2525:	xor	a
	ld	(de),a
	ld	hl,D3671
	inc	(hl)
	ld	a,(D36A6)
	or	a
	jp	z,A17F8
	pop	af
	ld	(D36A6),a
	ld	hl,D3672
	or	a
	jp	z,A253F
	inc	(hl)
	ret
A253F:	ld	a,(D3671)
	dec	a
	sub	(hl)
	ld	(D36A7),a
	ret

L2548:	call	A259A
	ld	a,d
	or	e
	jp	A2519

L2550:	call	A259A
	ld	a,d
	or	e
	cpl
	jp	z,A2519
	xor	a
	jp	A2519

L255D:	ld	a,(pass2)
	call	A359F			; продвинуть полож. в потоке на 1 байт
	dec	a
	jp	A2519

L2567:	ld	a,(pass2)
	call	A359F			; продвинуть полож. в потоке на 1 байт
	or	a
	jp	A2519

L2571:	db	0F6h			; or
L2572:	scf				; 37h
	push	af
	ld	a,(D36A6)
	or	a
	jp	z,A25A1
	call	token_copy
	call	A0BCD
	jp	nz,A2589
	and	0A0h
	jp	nz,A2594
A2589:	call	A0BB8
	jp	z,A2594
A258F:	pop	af
	sbc	a,a
	jp	A2519
	;
A2594:	pop	af
	ccf
	sbc	a,a
	jp	A2519

A259A:	ld	a,(D36A6)
	or	a
	jp	nz,A2495
A25A1:	pop	bc
	xor	a
	ld	hl,T0D1D
	ld	(D36B1),hl		; тек. адрес в потоке
	jp	A2519

L25AC:	db	0F6h			; or
L25AD:	scf				; 37h
	push	af
	call	A25FB
	jp	nz,A25A1
	ld	(D36B1),hl		; тек. адрес в потоке
	ld	a,b
	or	c
	jp	z,A2594
	jp	A258F

L25C0:	db	0F6h			; or
L25C1:	scf				; 37h
	push	af
	call	A25FB
	jp	nz,A25A1
	push	de
	push	bc
	ld	a,(hl)
	cp	2Ch
	jp	nz,A25F3
	inc	hl
	ld	(D36B1),hl		; тек. адрес в потоке
	call	A25FB
	jp	nz,A25F6
	ld	(D36B1),hl		; тек. адрес в потоке
	ld	a,c
	pop	bc
	pop	hl
	cp	c
	jp	nz,A258F
A25E5:	ld	a,(de)
	cp	(hl)
	jp	nz,A258F
	inc	de
	inc	hl
	dec	c
	jp	nz,A25E5
	jp	A2594
	;
A25F3:	call	A0501			; "Syntax error"
A25F6:	pop	hl
	pop	hl
	jp	A25A1

A25FB:	call	skipspace
	cp	"<"
	call	nz,out_of_range
A2603:	call	A3583			; узнать след. символ не смещ. поток
	or	a
	jp	nz,A261B
	call	nextchar
	call	A3583			; узнать след. символ не смещ. поток
	cp	"&"
	jp	nz,A261B
	call	nextchar
	jp	A2603
	;
A261B:	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	ld	de,0
A2622:	inc	hl
	ld	a,(hl)
	cp	">"
	jr	nz,A262B
	ld	d,h
	ld	e,l
A262B:	cp	","
	jr	nz,A2635
	ld	a,d
	or	e
	jr	nz,A263B
A2635:	cp	0Dh
	jr	nz,A2622
	inc	hl
A263B:	push	hl
	ld	hl,(D36B1)		; тек. адрес в потоке
	ld	a,d
	or	e
	call	z,out_of_range
	ex	de,hl
	ld	a,l
	sub	e
	ld	c,a
	ld	a,h
	sbc	a,d
	ld	b,a
	pop	hl
	ret


; Обработка "entry", "public", "global"
A264D:	call	token_copy
	ld	c,a
	push	bc
	call	nz,out_of_range
	scf
	call	A0C9C
	call	A27C5
	inc	hl
	set	6,(hl)
	bit	5,(hl)
	pop	bc
	call	z,undefined		; метка не определена
	ld	a,(hl)
	and	80h
	call	nz,A04ED		; "многократное опред. метки"
	rra
	rra
	rra
	or	(hl)
	ld	(hl),a
	ld	a,c
	cp	","
	jr	z,A264D
	ret


L267A:	ld	a,0FFh
	ld	(D3670),a
	call	A2495
	xor	a
	ld	(D3670),a
	ld	a,d
	or	a
	jp	nz,out_of_range
	ld	a,(D3815)		; символ ошибки
	cp	" "
	ret	nz
	ld	a,e
	dec	a
	ret	m
	jp	z,out_of_range
	cp	16
	jp	nc,out_of_range
	inc	a
	ld	(D366F),a		; база чисел
	xor	a
	ld	h,a
	ld	l,e
	ret


; Обработка request
A26A4:	call	token_copy
	jp	nz,out_of_range
	push	af
	ld	a,(idlen)		; длина идентиф.
	cp	8+1
	jr	c,A26B7
	call	A0514			; "Warning: maybe mistake!"
	ld	a,7			; ограничить макс. длину имени
A26B7:	ld	hl,T37CD
	ld	(hl),a
	inc	hl
	ld	(D36AA),hl
	ld	a,(pass2)
	or	a
	ld	c,3			; элемент "request library search"
	call	nz,put_spec_item	; на 2-м проходе
	pop	af
	cp	","
	jr	z,A26A4			; имеется след. имя файла
	ret


; Обработка "INCLUDE", "MACLIB"
L26CF:	ld	a,(D36A8)
	or	a
	jp	nz,A0501		; "Syntax error"
	call	skipspace
	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	call	open_include		; открыть include-файл
	or	a
	jp	nz,A052F		; "Error in value"
	dec	a
	ld	(D36A8),a
A26E8:	ld	hl,(D36B1)		; тек. адрес в потоке
	ld	a,(hl)
	inc	hl
	ld	(D36B1),hl
	cp	" "+1
	jr	nc,A26E8
	ret


; Обработка name ('...')
L26F5:	call	skipspace
	cp	"("
	jp	nz,out_of_range
	call	A3588
	cp	'"'
	jr	z,L2700
	cp	"'"
	jp	nz,out_of_range
L2700:	call	token_copy
	jp	nz,out_of_range
	cp	'"'
	jr	z,L2706
	cp	"'"
	jp	nz,out_of_range
L2706:	call	A3588
	cp	")"
	jp	nz,out_of_range
	call	A359F			; продвинуть полож. в потоке на 1 байт
	ld	a,(pass2)
	or	a
	ret	nz			; 2-й проход
	ld	a,(idlen)		; длина идентиф.
	cp	6
	jr	c,A272A
	ld	a,6			; ограничить имя 6-ю символами
A272A:	ld	de,idname		; буфер имени идентиф.
	ld	hl,T38D5		; ds 10  буфер имени для name('..')
	ld	b,a
	ld	a,(hl)
	or	a
	jp	nz,A04ED		; "многократное опред. метки"
	; скопировать имя
A2736:	ld	a,(de)
	cp	"a"
	jr	c,A2739
	and	5Fh
A2739:	ld	(hl),a
	inc	hl
	inc	de
	djnz	A2736
	ld	(hl),b
	ret


; Обработка "common"
L273E:	call	A2784
	call	skipspace
	cp	"/"
	jp	nz,out_of_range
	call	token_copy
	call	nz,A277C
	cp	"/"
	jp	nz,out_of_range
	call	A359F			; продвинуть полож. в потоке на 1 байт
	call	A0C9C
	inc	hl
	ld	a,(hl)
	and	0D0h
	jp	nz,A04ED		; "многократное опред. метки"
	push	hl
	ld	a,(hl)
	or	24h
	ld	(hl),a
	call	A2310
	pop	hl
	dec	hl
	ld	(D37C4),hl		; размер common-области
	ld	a,3			; тип "common"
	ld	(D37BB),a		; ячейка типа сегмента
	ld	hl,0
	ld	(D37BC),hl		; счетчик org ?
	jp	A229A

A277C:	ex	af,af'
	ld	a,1
	ld	(idlen),a		; длина идентиф.
	ex	af,af'
	ret

A2784:	ld	a,(D37CE)
	or	a
	ret	z
	pop	bc
	jp	A050B			; "Pass 1/2 phase error"


; Обработка "extrn", "ext", "extern"
L278D:	ld	de,0080h		; константа
A2790:	call	token_copy
	jp	nz,A27B6
	push	af
	or	a
	push	de
	call	A0C9C
	call	A27C5
	pop	de
	ld	a,(hl)
	or	d
	ld	(hl),a
	inc	hl
	ld	a,(hl)
	and	64h
	jp	nz,A27BC
	ld	a,(hl)
	and	3
	or	e
	ld	(hl),a
A27AF:	pop	af
A27B0:	cp	","
	jp	z,A2790
	ret
A27B6:	call	out_of_range
	jp	A27B0
	;
A27BC:	or	10h
	ld	(hl),a
	call	A04ED			; "многократное опред. метки"
	jp	A27AF

A27C5:	ld	a,(hl)
	and	7Fh
	cp	42h
	ret	c
	xor	a
	ld	(hl),a
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(hl),a
	dec	hl
	dec	hl
	dec	hl
	ret

A27D7:	call	A1CD9
	ld	a,(D383A)
	or	a
	ret	z
	jp	A0514			; "Warning: maybe mistake!"



; Обработка "aset"
A27E2:	ld	(D36AE),hl
	set	7,(hl)
	ld	a,h
	call	A27D7
	ld	a,b
	and	80h			; аргумент "extrn" метка ?
	jp	nz,A04E3		; да, "Invalid use of external"
	ld	hl,(D36AE)
	call	A27C5
	inc	hl
	ld	a,(hl)
	and	94h
	jp	nz,A04ED		; "многократное опред. метки"
	ld	a,(hl)
	and	40h
	or	b
	or	20h
	ld	(hl),a
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	push	de
	ld	de,(D37C8)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	ret


; Обработка "END"
do_end:	push	af
	call	close_file		; закрыть .asm файл
	ld	a,(D3972)
	or	a
	call	nz,A293C
	ld	a,(D3671)
	or	a
	call	nz,A296E
	pop	af
	ld	hl,pass2
	inc	(hl)
	ld	a,(hl)
	dec	a
	jp	nz,A28AC		; 2-й проход, вывод статистики
	;
	ld	hl,T38D5		; ds 10  буфер имени name('...')
	ld	a,(hl)
	or	a
	jr	nz,A283B
	; взять имя асм-файла
	ld	hl,T3A54		; имя .asm файла
	; выделить из полного имени только "file.ext"
	ld	e,l			; запомнить посл. "\"
	ld	d,h
A2820:	ld	a,(hl)
	inc	hl
	cp	"\"
	jr	nz,A2828
	ld	e,l			; запомнить посл. "\"
	ld	d,h
A2828:	or	a
	jr	nz,A2820
	ex	de,hl			; hl=адрес начала имени
A283B:	ld	bc,0006h		; c=6  макс. длина имени модуля (program name)
	ld	de,T38D5		; буфер имени name('..')
A2841:	ld	a,(hl)
	inc	hl
	cp	"."			; конец имени ?
	jr	z,A2858			; да
	or	a
	jr	z,A2858
	cp	0Dh
	jr	z,A2858
	ld	(de),a
	inc	de
	inc	b
	dec	c
	jr	nz,A2841
	; вставить имя модуля в вых. код
A2858:	ld	hl,T38CE
	ld	(hl),b			; длина имени
	inc	hl
	ld	(D36AA),hl
	ld	c,2			; элемент "имя модуля" (program name)
	call	put_spec_item		; вставить элемент в вых. код
	call	A2310
	ld	hl,T43FD
	ld	(D3993),hl
A286E:	call	A0C64
	jr	c,A2893
	ld	(D36AA),hl
	res	7,(hl)
	inc	hl
	ld	a,(hl)
	and	40h
	jp	nz,A2930
	ld	a,(hl)
	and	4
	jr	z,A286E
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)			; de=common size
	; c=элемент "размер common-области"
	ld	bc,0005h
	call	put_spec_item		; записать размер
	jr	A286E
	;
A2893:	ld	de,(D37C2)		; размер data-области
	; c=элемент "размер Data-области (в A-поле - как размер)"
	ld	bc,000Ah
	call	put_spec_item
	; c=элемент "размер Code-области (в A-поле - как размер)"
	ld	bc,010Dh
	ld	de,(D37C0)		; размер code-области
	ld	a,e
	or	d
	call	nz,put_spec_item
	jp	PASS_2			; на 2-й проход


A28AC:	ld	hl,(D36B1)		; тек. адрес в потоке
	push	af
	call	nc,A1CD9
	push	de
	push	bc
	call	A34AF
	; вывод имени входного .asm файла
	ld	hl,msg_name		; "Assembling file:  "
	call	A40AE
	ld	hl,T3A54		; имя .asm файла
A28B0:	ld	a,(hl)
	cp	" "+1
	jr	c,A28B3
	cp	"\"+1			;"Z"+1
	jr	nc,A28B3
	inc	hl
A28B1:	call	A41A3			; вывод "a" на экран
	jr	A28B0
	;
A28B3:	call	newline
	; вывод числа ошибок
	ld	hl,msg_err		; "Error messages:   "
	call	A40AE
	ld	hl,(D366B)		; число ошибок
	ld	a,h
	or	l
	jr	z,A28C6
	call	A046F			; вывод числа ошибок
	call	newline
	jr	A28CC
	;
A28C6:	ld	hl,msg_none		; "None"
	call	A40AE			; вывод строки на экран
	; вывод числа предупреждений
A28CC:	ld	hl,msg_warn		; "Warning messages: "
	call	A40AE
	ld	hl,(D366D)		; число предупреждений
	ld	a,h
	or	l
	jr	nz,A28E3
	ld	hl,msg_none		; "None"
	call	A40AE			; вывод строки на экран
	jr	A28E9
	;
A28E3:	call	A046F			; вывод числа предупреждений
	call	newline
A28E9:	call	newline;
	pop	bc
	pop	de
	pop	af
	jr	nc,A28F6
	ld	de,0			; адрес (точка входа) послед. цепочки в нуль
	ld	b,e
A28F6:	call	A182D			; если тип "common" - записать элемент "select COMMON block"
	ld	c,14			; элемент "end program"
	call	put_spec_item
A28FE:	ld	hl,(D383B)
	ld	a,h			; a = счетчик границы байта
	cp	0F8h			; дошли до границы байта ?
	jr	z,A290C			; да
	xor	a			; бит="0"
	call	putbit			; запись нулевого бита
	jr	A28FE
	;
A290C:	ld	bc,000Fh		; c=15, элемент "end file"
	call	put_spec_item
	ld	b,0
	call	A1904			; записать 8 бит ("spec items" + 15)
	call	A421D			; дописать конец REL файла и закрыть
	; норм. выход в ДОС
	ld	b,0			; код возврата
	jp	exit



A2930:	ld	c,0			; элемент "имя метки" (entry symbol)
	ld	a,(D37BB)		; ячейка типа сегмента
	ld	b,a
	call	put_spec_item
	jp	A286E


A293C:	ld	hl,T2960		; "Unterminated "
	call	A40AE			; вывод строки на экран
	ld	hl,T294E		; "macro constuction"
	call	A40AE			; вывод строки на экран
	call	A180D
	jp	newline


A296E:	ld	hl,T2960		; "Unterminated "
	call	A40AE			; вывод строки на экран
	ld	hl,T2980		; "conditional"
	call	A40AE			; вывод строки на экран
	call	A180D
	jp	newline


A298C:	ld	hl,-30			; 0-30
	add	hl,sp
	ex	de,hl
	ld	hl,(D39A1)
	call	A0D1F			; сравнить hl с de
	jp	nc,stack_overflow	; переполн. стека
	ld	a,(D3972)
	or	a
	ld	hl,0
	ld	(D399B),hl
	ld	(D399D),hl
	ld	hl,(D3970)
	jr	nz,A29B0
	ld	hl,(D39A1)
	dec	hl
A29B0:	inc	a
	ld	(D3972),a
	xor	a
	ld	(D3973),a
A29B8:	ld	(D397D),a
A29BB:	ex	de,hl
	ld	hl,(D3997)
	inc	h
	call	A0D1F			; сравнить hl с de
	jr	nc,A29CA
	ex	de,hl
	ld	(D3970),hl
	ret
A29CA:	dec	h
	ex	de,hl
	push	hl
	call	A346D
	pop	hl
	jr	A29BB

A29D3:	call	searchtree		; поиск зарез. слов
	ret	nz			; не найдены
	ld	a,(hl)
	or	a
	inc	a
	ret	p
	dec	a
	push	af
	and	10h
	jr	z,A29FD
	ld	a,(D397D)
	inc	a
	ld	(D397D),a
A29E9:	pop	af
	and	8
	xor	8
	ret	nz
	ld	a,(D397D)
	or	a
	ret	z
	ld	a,(D397D)
	dec	a
	ld	(D397D),a
	inc	a
	ret
A29FD:	inc	hl
	ld	a,(hl)
	cp	1Bh
	jr	nz,A29E9
	ld	a,(D397D)
	or	a
	jr	nz,A29E9
	ld	a,(D3987)
	or	a
	jr	nz,A29E9
	pop	af
	scf
	ret

A2A15:	ld	(D3970),hl
	ld	a,(D3972)
	dec	a
	ld	(D3972),a
	ret

A2A20:	call	nextchar
	cp	"&"
	jr	nz,A2A5C
	ld	hl,(D36B1)		; тек. адрес в потоке
	ld	a,(hl)
	cp	" "
	jr	z,A2A5A
	cp	9			; Tab
	jr	z,A2A5A
	push	hl
	push	bc
	call	token_copy
	call	A2A68
	pop	bc
	pop	hl
	ld	(D36B1),hl
	jr	nz,A2A5A
	ld	a,"&"
	ld	(D3974),a
	jp	A2AC9
	;
A2A4E:	cp	"&"
	jr	nz,A2A5C
	ld	a,(D3974)
	or	a
	jr	nz,A2A61
A2A5A:	ld	a,"&"
A2A5C:	call	A3363
	or	a
	ret	m
A2A61:	push	af
	xor	a
	ld	(D3974),a
	pop	af
	ret

A2A68:	ld	hl,(D397F)
	ld	b,0
A2A6D:	ld	a,(hl)
	or	a
	jp	z,A2A96
	ld	de,idlen		; длина идентиф.
	ld	a,(de)
	cp	(hl)
	jp	nz,A2A8B
	ld	c,a
A2A7B:	dec	hl
	inc	de
	ld	a,(de)
	cp	(hl)
	jp	nz,A2A8B
	dec	c
	jp	nz,A2A7B
	ld	a,b
	or	80h
	cp	a
	ret
A2A8B:	dec	hl
	ld	a,(hl)
	cp	7
	jp	nc,A2A8B
	inc	b
	jp	A2A6D

A2A96:	ld	a,(D3988)
	or	a
	ret	nz
	ld	hl,(D3989)
	ld	b,0C0h
A2AA0:	ld	a,(hl)
	or	a
	jp	z,A2AC7
	ld	de,idlen		; длина идентиф.
	ld	a,(de)
	cp	(hl)
	jp	nz,A2ABC
	ld	c,a
A2AAE:	dec	hl
	inc	de
	ld	a,(de)
	cp	(hl)
	jp	nz,A2ABC
	dec	c
	jp	nz,A2AAE
	xor	a
	ld	a,b
	ret
A2ABC:	dec	hl
	ld	a,(hl)
	cp	7
	jp	nc,A2ABC
	inc	b
	jp	A2AA0
	;
A2AC7:	inc	a
	ret

A2AC9:	ld	hl,(D36B1)		; тек. адрес в потоке
	push	hl
	call	token_copy
	push	af
	call	A2A68
	jr	nz,A2B02
	ld	b,a
	pop	af
	pop	hl
	push	af
A2ADB:	ld	a,(hl)
	inc	hl
	cp	" "
	jr	z,A2AE7
	cp	9			; Tab
	jr	nz,A2AEF
A2AE7:	push	hl
	call	A2A5C
	pop	hl
	jr	A2ADB
	;
A2AEF:	ld	a,b
	call	A2A5C
	pop	af
	ld	b,a
	push	af
A2AF6:	pop	af
	jp	nz,A2A4E
	cp	26h
	jp	nz,A2A4E
	jp	A3595			; поток на байт назад
	;
A2B02:	pop	af
	pop	hl
	push	af
	ld	(D36B1),hl		; тек. адрес в потоке
A2B08:	call	nextchar
	cp	" "
	jr	z,A2B1B
	cp	9			; Tab
	jr	z,A2B1B
	call	A3595			; поток на байт назад
	jr	A2B21
	;
A2B1B:	call	A2A5C
	jr	A2B08
	;
A2B21:	call	A3609
	jr	nz,A2AF6
	jr	A2B30
	;
A2B2A:	call	A3609
	jp	m,A2AF6
A2B30:	call	A2A5C
	jp	A2B2A

A2B36:	call	nextchar
	cp	";"
	jp	z,A2B52
	jp	A2B44
	;
A2B41:	call	A33E8
A2B44:	call	A2A5C
	cp	0Dh
	jp	z,A33C0
	call	nextchar
	jp	A2B44

A2B52:	call	A33E8
A2B55:	call	A33E8
	cp	" "
	jr	z,A2B55
	cp	9			; Tab
	jr	z,A2B55
	or	a
	call	A340E
	ld	(D399D),hl
	jp	z,A33C0
	cp	0Dh
	jp	z,A33C0
	ld	a,0Dh
	call	A3363
	jp	A33C0

A2B79:	push	hl
	push	af
	ld	a,(D3988)
	or	a
	jr	z,A2B89
	push	de
	ex	de,hl
	ld	hl,(D3995)
	add	hl,de
	inc	(hl)
	pop	de
A2B89:	pop	af
	and	7Fh
	push	af
	add	a,a
	jp	m,A2BD3
	ld	hl,(D3983)
	ld	a,(hl)
	or	a
	jr	z,A2BC2
	pop	af
	push	bc
	ld	b,a
	inc	b
	dec	hl
A2B9E:	dec	b
	jr	z,A2BAD
	ld	a,(hl)
	push	de
	cpl
	ld	e,a
	ld	d,0FFh
	add	hl,de
	pop	de
	jr	A2B9E
	;
A2BAD:	ld	a,(hl)
	or	a
	jr	z,A2BD0
	dec	a
	ld	b,a
A2BB4:	dec	hl
	ld	a,(hl)
	inc	b
	dec	b
	jr	z,A2BD0
	call	A2D1A
	dec	b
	jr	A2BB4
	;
A2BC2:	pop	af
	dec	hl
	inc	a
A2BC5:	dec	a
	jp	z,A2BCD
	dec	hl
	jp	A2BC5
	;
A2BCD:	ld	a,(hl)
	pop	hl
	ret
A2BD0:	pop	bc
	pop	hl
	ret
	;
A2BD3:	ld	a,2Eh			; "."  2 точки для макро-меток "..NNNN" ?
	call	A2D1A
	call	A2D1A
	pop	af
;	and	3Fh
;	push	bc
;	ld	hl,(D3990)
;	ld	c,a
;	ld	b,0
;	add	hl,bc
;	ld	b,h
;	call	A2C0A			; ??
;	ld	b,l
;	call	A2C0A			; ??
;	pop	bc
	pop	hl
	dec	de
	ld	a,(de)
	ret

A2BF3:	push	hl
	call	token_copy
	pop	hl
	call	nz,A2C0B
	push	af
	ld	de,idlen		; длина идентиф.
	ld	a,(de)
	inc	a
	ld	b,a
A2C02:	ld	a,(de)
	ld	(hl),a
	inc	de
	dec	hl
	djnz	A2C02
	pop	af
	ret


A2C0B:	cp	0Dh
	ret	z
	cp	";"
	ret	z
	pop	de
	jp	out_of_range

A2C15:	ld	b,0
	push	bc
	push	hl
	dec	hl
	call	skipspace
A2C1D:	cp	"'"
	jp	z,A2CC2
	cp	'"'
	jp	z,A2CC2
	cp	"<"
	jp	z,A2CDF
	cp	">"
	jp	z,A2CEA
	cp	"%"
	jr	z,A2C5C
	cp	","
	jp	z,A2CF4
	cp	" "
	jp	z,A2CF4
	cp	9			; Tab
	jp	z,A2CF4
	cp	";"
	jp	z,A2CF4
	cp	"!"
	call	z,A3588
	cp	0Dh
	jp	z,A2D11
A2C54:	ld	(hl),a
	dec	hl
A2C56:	call	nextchar
	jr	A2C1D
	;
A2C5C:	ld	(D365F),hl
	push	bc
	ld	bc,A2C88
	push	bc
	call	A2495
	ex	de,hl
	ld	c,0
	ld	a,(D3815)		; символ ошибки
	cp	" "
	jr	nz,A2C7A
	ld	b,h
	call	A2C92
	ld	b,l
	call	A2C92
A2C7A:	inc	c
	dec	c
	jr	z,A2C83
	ld	a,"0"
	call	A2CB7
A2C83:	ld	a,"H"
	jp	A2CB7
	;
A2C88:	pop	bc
	call	A3595			; поток на байт назад
	ld	hl,(D365F)
	jp	A2C56

A2C92:	ld	a,b
	rra
	rra
	rra
	rra
	call	A2C9B
	ld	a,b
A2C9B:	and	0Fh
	add	a,"0"
	cp	"9"+1
	jr	c,A2CA5
	add	a,7
A2CA5:	inc	c
	dec	c
	jr	nz,A2CB7
	cp	"0"
	ret	z
	ld	c,a
	cp	"9"+1
	jr	c,A2CB7
	ld	a,"0"
	call	A2CB7
	ld	a,c
A2CB7:	push	hl
	ld	hl,(D365F)
	ld	(hl),a
	dec	hl
	ld	(D365F),hl
	pop	hl
	ret

A2CC2:	ld	c,a
A2CC3:	ld	(hl),a
	dec	hl
	call	nextchar
	cp	c
	jr	z,A2CD3
	cp	0Dh
	jp	z,A2D15
	jr	A2CC3
	;
A2CD3:	ld	(hl),a
	dec	hl
	call	nextchar
	cp	c
	jr	z,A2CC3
	jp	A2C1D
	;
A2CDF:	inc	b
	dec	b
	jp	z,A2CE6
	ld	(hl),a
	dec	hl
A2CE6:	inc	b
	jp	A2C56
	;
A2CEA:	dec	b
	jp	z,A2C56
	jp	m,A2CF9
	jp	A2C54
	;
A2CF4:	inc	b
	dec	b
	jp	nz,A2C54
A2CF9:	pop	de
	ld	a,e
	sub	l
	dec	a
	ld	(de),a
	pop	bc
	ex	de,hl
	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	ld	a,(hl)
	cp	" "
	call	z,A3595			; поток на байт назад
	cp	9			; Tab
	call	z,A3595			; поток на байт назад
	ex	de,hl
	ret

A2D11:	inc	b
	dec	b
	jr	z,A2CF9
A2D15:	call	A0538			; "Mistake!"
	jr	A2CF9


A2D1A:	push	af
	push	hl
	ld	hl,T37B4		; ds 7
	call	A0D1F			; сравнить hl с de
	jr	nc,A2D2C
	inc	hl
	ld	(hl),0Dh
	dec	hl
	ex	de,hl
	pop	hl
	pop	af
	ret
A2D2C:	pop	hl
	pop	af
	ld	(de),a
	inc	de
	ret


A2D31:	call	A2AC9
	cp	"&"			; 26h
	jr	z,A2D31
	cp	":"			; 3Ah
	jp	z,A2AC9
	cp	" "+1			; 21h
	ret	nc
	cp	0Dh
	ret	z
	push	af
	call	A0BB8
	jr	z,A2D50
	call	searchtree		; поиск зарез. слов
	jp	z,A17F8			; найдены
A2D50:	pop	af
	jp	A2AC9


L2D76:	call	A2495
	ld	a,(D3815)		; символ ошибки
	cp	" "
	jr	z,A2D83
	ld	de,0
A2D83:	ex	de,hl
	ld	(D3975),hl
	call	A298C
	pop	bc
	pop	de
	pop	hl
	ld	bc,A2D97
A2D90:	push	bc
	push	de
A2D92:	ld	a,0Dh
	jp	A03EC
	;
A2D97:	pop	bc
	ld	bc,A2D92
	push	bc
	call	token_copy
	cp	":"
	call	z,token_copy		; продв. поток
	call	A29D3
	jp	z,A2DB8
	ld	de,D36B3		; 257 буфер строки
A2DAD:	ld	a,(de)
	call	A3363
	inc	de
	cp	0Dh
	jp	nz,A2DAD
	ret
A2DB8:	xor	a
	call	A3363
	call	A33C0
	pop	bc
	pop	de
	pop	hl
	ld	hl,A0231
	push	hl
	push	de
	ld	hl,(D399B)
	push	hl
	push	hl
A2DCC:	ld	hl,(D3975)
	push	hl
A2DD0:	ld	hl,A0231
	push	hl
	ld	hl,A2DDA
	push	hl
	push	bc
	ret				; на A2D92
	;
A2DDA:	call	A2E2D
	pop	bc
	pop	hl
A2DDF:	pop	de
	call	A0D1F			; сравнить hl с de
	jp	nz,A2E09
	ld	a,(D397E)
	or	a
	jp	nz,A2DF2
	ld	a,b
	or	c
	jp	nz,A2E09
A2DF2:	ld	hl,(D3970)
A2DF5:	push	hl
	call	A32BC
	pop	hl
A2DFA:	call	A2A15
	xor	a
	ld	(D397E),a
	pop	de
	push	de
	ld	hl,(D3977)
	push	hl
	ex	de,hl
	jp	(hl)			; none
	;
A2E09:	push	de
	call	A3399
	or	a
	jp	z,A2E3C
	ld	de,D36B3		; 257 буфер строки
A2E14:	call	A33AB
	call	A2D1A
	cp	0Dh
	jp	nz,A2E14
	push	hl
	push	bc
A2E21:	ld	hl,(D3979)
	push	hl
	ld	hl,(D397B)
	push	hl
	ld	hl,(D3977)
	jp	(hl)

A2E2D:	pop	de
	pop	hl
	ld	(D3977),hl
	pop	hl
	ld	(D397B),hl
	pop	hl
	ld	(D3979),hl
	ex	de,hl
	jp	(hl)

A2E3C:	dec	bc
	ld	h,d
	ld	l,e
	jp	A2DDF

L2E42:	ld	a,(D3972)
	or	a
	jp	z,A0538			; "Mistake!"
	ld	(D397E),a
	pop	bc
	pop	hl
	pop	de
	ld	de,A2E5F
	push	de
	push	hl
	push	bc
	xor	a
	ld	(D397D),a
	jp	A359F			; продвинуть полож. в потоке на 1 байт


A2E5F:	ld	a,(D397E)
	or	a
	jr	z,A2EBE
	pop	bc
	ld	bc,A01A1
	push	bc
	call	token_copy
	cp	":"
	call	z,token_copy		; продв. поток
	call	searchtree		; поиск зарез. слов
	ret	nz			; не найдены
	or	a
	ret	p
	ld	c,a
	and	8
	jr	nz,A2E92
	ld	a,c
	and	10h
	jr	nz,A2E9A
	ld	a,c
	and	20h
	jr	nz,A2EA2
	ld	a,c
	and	40h
	jr	nz,A2EAF
	ret
A2E92:	ld	a,(D397D)
	dec	a
	ld	(D397D),a
	ret
A2E9A:	ld	a,(D397D)
	inc	a
	ld	(D397D),a
	ret
A2EA2:	ld	a,(D397D)
	or	a
	ret	nz
	ld	a,(D3671)
	or	a
	ret	z
	jp	A24B8
	;
A2EAF:	ld	a,(D397D)
	or	a
	ret	nz
	inc	hl
	ld	a,(hl)
	cp	8
	ret	z
	ld	a,0FFh
	jp	A2519
	;
A2EBE:	pop	bc
	pop	de
	pop	hl
	ld	hl,A0231
	push	hl
	push	de
	push	bc
	ret


A2EC8:	or	a
	push	af
	call	A298C
	ld	(D397F),hl
	call	A2BF3
	ld	c,a
	ld	a,(D3815)		; символ ошибки
	cp	" "
	jr	z,A2EE4
	ld	hl,(D397F)
	call	A2A15
	pop	af
	ret
A2EE4:	ld	a,c
	ld	(hl),0
	dec	hl
	cp	2Ch
	call	nz,out_of_range
	pop	af
	push	af
	jp	z,A2F20
	call	A3588
	cp	"<"
	call	nz,out_of_range
A2EFA:	pop	af
	ld	(hl),a
	push	hl
	push	af
	ld	c,0
	dec	hl
	ld	a,(D3815)		; символ ошибки
	cp	" "
	jp	nz,A2F7B
	pop	af
	push	af
	ld	b,a
	jp	z,A2F2E
A2F0F:	call	A2C15
	inc	c
	cp	0Dh
	jp	z,A2F78
	cp	3Eh
	jp	z,A2F7B
	jp	A2F0F
	;
A2F20:	call	A3583			; узнать след. символ не смещ. поток
	sub	"<"
	ld	(D3986),a
	call	z,nextchar
	jp	A2EFA
	;
A2F2E:	call	nextchar
	cp	0Dh
	jr	z,A2F71
	push	af
	ld	a,(D3986)
	or	a
	jr	z,A2F53
	pop	af
	ld	de,A2F7B
	push	de
	cp	" "
	ret	z
	cp	9
	ret	z
	cp	";"
	ret	z
	cp	","
	ret	z
	pop	de
	jr	A2F6B
	;
A2F53:	pop	af
	cp	3Ch
	jp	z,A2F67
	cp	3Eh
	jp	nz,A2F6B
	inc	b
	dec	b
	jp	z,A2F7B
	dec	b
	jp	A2F6B
	;
A2F67:	inc	b
	jp	A2F6B
	;
A2F6B:	inc	c
	ld	(hl),a
	dec	hl
	jp	A2F2E
	;
A2F71:	ld	a,(D3986)
	or	a
	jp	nz,A2F7B
A2F78:	call	A0514			; "Warning: maybe mistake!"
A2F7B:	ld	(hl),0
	dec	hl
	call	A29BB
	ld	a,b
	or	a
	call	nz,out_of_range
	pop	af
	pop	hl
	ld	(D3981),hl
	ld	h,0
	ld	l,c
	ld	(D3975),hl
	pop	bc
	pop	de
	pop	hl
	ld	bc,A2FA1
	jp	A2D90

L2F9A:	xor	a
	jp	nz,A013E
	jp	A2EC8

A2FA1:	pop	bc
	ld	bc,A2D92
	push	bc
	ld	hl,(D399D)
	ld	a,1
	ld	(D3988),a
	push	hl
	call	A2D31
	push	af
	call	A29D3
	jp	z,A2FE5
	pop	af
	pop	hl
A2FBB:	cp	0Dh
	jp	z,A2B41
	cp	3Bh
	jp	z,A2B36
	cp	27h
	jp	z,A2FD5
	cp	22h
	jp	z,A2FD5
A2FCF:	call	A2AC9
	jp	A2FBB
	;
A2FD5:	ld	b,a
A2FD6:	call	A2A20
	cp	0Dh
	jp	z,A2B41
	cp	b
	jp	z,A2FCF
	jp	A2FD6
	;
A2FE5:	pop	af
	pop	hl
	ld	(D399D),hl
	xor	a
	call	A3363
	call	A33C0
	pop	bc
	pop	de
	pop	hl
	ld	hl,A0231
	push	hl
	push	de
	ld	hl,(D399B)
	push	hl
	push	hl
	ld	hl,(D3981)
	push	hl
	ld	hl,(D3975)
	push	hl
	ld	hl,A0231
	push	hl
	ld	hl,A3010
	push	hl
	push	bc
	ret				; на A2D92

A3010:	call	A2E2D
	pop	bc
	pop	hl
	pop	de
	ld	a,1
	ld	(D3988),a
	ld	(D3983),hl
	pop	hl
	call	A0D1F			; сравнить hl с de
	jp	nz,A3041
A3025:	ld	a,(D397E)
	or	a
	jp	nz,A3031
	ld	a,b
	or	c
	jp	nz,A3041
A3031:	ld	hl,(D3983)
	inc	hl
	inc	hl
A3036:	ld	a,(hl)
	cp	8
	inc	hl
	jr	nc,A3036
	dec	hl
	jp	A2DF5
	;
A3041:	ex	de,hl
	push	de
	call	A3399
	or	a
	jr	z,A3068
	ld	de,D36B3		; 257 буфер строки
A304D:	call	A3399
	or	a
	call	m,A2B79
	call	A340E
	call	A2D1A
	cp	0Dh
	jr	nz,A304D
	push	hl
	ld	hl,(D3983)
	push	hl
	push	bc
	jp	A2E21
	;
A3068:	dec	bc
	ld	h,d
	ld	l,e
	pop	de
	jp	A3025

L306F:	call	skipspace
	cp	0Dh
	jp	z,out_of_range
	ld	c,a
	call	A41A3			; вывод "a" на экран
A307B:	call	A3588
	cp	0Dh
	jr	z,A308A
	call	A41A3			; вывод "a" на экран
	cp	c
	jr	nz,A307B
A308A:	call	newline
	ld	a,(D3815)		; символ ошибки
	cp	" "
	ret	nz
	jp	A359F			; продвинуть полож. в потоке на 1 байт

L309D:	call	skipspace
	cp	0Dh
	jp	z,out_of_range
	ld	(D3985),a
	ld	c,a
A30A9:	call	nextchar
	cp	0Dh
	jr	z,A30B8
	cp	c
	jp	z,A359F			; продвинуть полож. в потоке на 1 байт
	jp	A30A9
	;
A30B8:	pop	hl
	pop	de
	pop	bc
	ld	bc,A30C1
	jp	A2D90

A30C1:	pop	bc
	ld	bc,A2D92
	push	bc
	ld	hl,D36B3		; 257 буфер строки
	ld	a,(D3985)
	ld	c,a
A30CD:	ld	a,(hl)
	cp	c
	jp	z,A30D9
	cp	0Dh
	ret	z
	inc	hl
	jp	A30CD
	;
A30D9:	pop	bc
	pop	de
	pop	hl
	ld	hl,A0231
	push	hl
	push	de
	push	bc
	ret


; Обработка "macro"
A30E3:	or	a
	call	A0D2B
	inc	hl
	ld	(D396E),hl
	ld	a,(hl)
	or	28h
	ld	(hl),a
	call	A298C
	ld	(D397F),hl
	ld	c,0
A30F7:	push	bc
	call	A2BF3
	pop	bc
	inc	c
	cp	2Ch
	jr	z,A30F7
	xor	a
	ld	(hl),a
	dec	hl
	ld	(D3987),a
	ld	(D398D),a
	inc	a
	ld	(hl),a
	dec	hl
	ld	(D3989),hl
	ld	(D398B),hl
	ld	(hl),0
	ld	a,c
	ld	(D3992),a
	call	A3363
	xor	a
	call	A3363
	pop	bc
	pop	de
	pop	hl
	ld	hl,A312A
	push	hl
	push	de
	push	bc
	ret
	;
A312A:	pop	bc
	ld	bc,A2D92
	push	bc
	ld	hl,(D399D)
	push	hl
	xor	a
	ld	(D3987),a
	ld	(D3988),a
	call	A2D31
	push	af
	call	A29D3
	jr	c,A314F
	jr	z,A3182
	pop	af
	ld	(D3987),a
	pop	hl
	jp	A2FBB
	;
A314F:	pop	af
A3150:	call	token_copy
	call	nz,out_of_range
	ld	hl,(D398B)
	push	af
	jr	nz,A3164
	ld	a,(D398D)
	inc	a
	ld	(D398D),a
A3164:	ld	de,idlen		; длина идентиф.
	ld	a,(de)
	inc	a
	ld	c,a
A316A:	ld	a,(de)
	ld	(hl),a
	dec	hl
	inc	de
	dec	c
	jp	nz,A316A
	ld	(hl),0
	ld	(D398B),hl
	pop	af
	cp	2Ch			; ","
	jr	z,A3150
	pop	hl
	ld	(D399D),hl
	ret
	;
A3182:	pop	af
	pop	hl
	xor	a
	ld	(D399D),hl
	call	A3363
	call	A33C0
	ld	hl,(D399B)
	ld	de,5
	add	hl,de
	ex	de,hl
	ld	hl,(D3995)
	add	hl,de
	ld	a,(D398D)
	ld	(hl),a
	ld	de,(D399B)
	ld	hl,(D396E)
	inc	hl
	push	de
	push	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,d
	or	e
	call	nz,A32BC
	pop	hl
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D397F)
	call	A2A15
	pop	bc
	pop	de
	pop	hl
	ld	hl,A0231
	push	hl
	push	de
	push	bc
	ret

A31C5:	push	hl
	scf
	call	A298C
	ld	(hl),0
	dec	hl
	ld	(hl),1
	ld	(D3983),hl
	dec	hl
	ld	c,0
A31D5:	call	A2C15
	ld	b,a
	inc	c
	call	A3595			; поток на байт назад
	call	skipspace
	cp	0Dh
	jr	z,A31FB
	cp	";"
	jr	z,A31FB
	cp	","
	jp	z,A31D5
	ld	a,b
	cp	20h
	jp	z,A31D5
	cp	9
	call	nz,A0514		; "Warning: maybe mistake!"
	jp	A31D5
	;
A31FB:	ex	(sp),hl
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	call	A33AB
	ex	(sp),hl
	or	a
	jr	z,A3215
A3209:	cp	c
	jr	z,A3215
	jr	c,A3215
	ld	(hl),0
	dec	hl
	inc	c
	jp	A3209
	;
A3215:	ld	(hl),0
	dec	hl
	call	A29BB
	pop	hl
	pop	bc
	call	A33AB
	push	hl
	ld	hl,(D398E)
	push	hl
	push	bc
	ld	c,a
	ld	b,0
	add	hl,bc
	ld	(D398E),hl
	pop	bc
	ld	hl,(D3983)
	push	hl
	ld	hl,A0231
	push	hl
	ld	de,A323C
	push	de
	push	bc
	ret

A323C:	call	A2E2D
	pop	hl
	ld	(D3983),hl
	pop	hl
	ld	(D3990),hl
	pop	hl
	xor	a
	ld	(D3988),a
	call	A3399
	or	a
	jr	z,A3273
	ld	de,D36B3		; 257 буфер строки
A3255:	call	A3399
	or	a
	call	m,A2B79
	call	A340E
	call	A2D1A
	cp	0Dh
	jr	nz,A3255
	push	hl
	ld	hl,(D3990)
	push	hl
	ld	hl,(D3983)
	push	hl
	jp	A2E21
	;
A3273:	ld	hl,(D3983)
	inc	hl
	xor	a
	ld	(D397E),a
	jp	A2DFA


; hl-de -> de
A327E:	ld	a,l
	sub	e
	ld	e,a
	ld	a,h
	sbc	a,d
	ld	d,a
	ret


; Обработка ".phase"
L3285:	ld	a,(D37CE)
	or	a
	jp	nz,A050B		; "Pass 1/2 phase error"
	call	A1CD9
	ld	a,(D3815)		; символ ошибки
	cp	" "
	ret	nz
	ld	(D37CE),a
	bit	7,b
	jp	nz,out_of_range
	ld	a,b
	and	3
	ld	(D37D1),a
	ld	hl,(D37BC)		; счетчик org ?
	ex	de,hl
	or	a
	sbc	hl,de
	ld	(D37CF),hl
	ret

; Обработка ".dephase"
L32AE:	ld	a,(D37CE)
	or	a
	call	z,A0514			; "Warning: maybe mistake!"
	xor	a
	ld	(D37CE),a
	jp	A359F			; продвинуть полож. в потоке на 1 байт


A32BC:	ld	bc,(D3999)
	ld	(D3999),de
	call	A32CE
	call	A32D7
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ret

A32CE:	ld	hl,(D3995)
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	dec	hl
	ret

A32D7:	ld	hl,(D3995)
	add	hl,de
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	dec	hl
	ret

A32E2:	ld	hl,(D3999)
	ld	a,l
	or	h
	jp	z,A32F7
	ex	de,hl
	push	de
	call	A32D7
	ex	de,hl
	ld	(D3999),hl
	pop	de
	jp	A3323
	;
A32F7:	ld	hl,(D3997)
	ld	de,32
	ex	de,hl
	add	hl,de
	ld	(D3997),hl
	push	de
	ex	de,hl
	ld	hl,(D39A1)
	call	A0D1F			; сравнить hl с de
	pop	de
	jp	c,A3467
	ld	hl,(D3970)
	dec	h
	ld	a,(D3972)
	or	a
	call	A0D1F			; сравнить hl с de
	jp	c,A3467
	ld	hl,(D3995)
	ex	de,hl
	call	A327E			; hl-de -> de
A3323:	push	de
	call	A32CE
	ld	de,(D399D)
	ld	a,e
	and	0E0h
	ld	e,a
	ld	a,e
	or	d
	jp	nz,A3337
	pop	de
	push	de
A3337:	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	a,0			; не заменять на "xor a"
	ld	(hl),a
	inc	hl
	ld	(hl),a
	call	A32D7
	pop	de
	jp	z,A334D
	ld	(hl),e
	inc	hl
	ld	(hl),d
	jp	A3352
	;
A334D:	ld	(D399B),de
A3352:	ld	hl,(D399B)
	push	de
	ex	de,hl
	call	A32CE
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	a,e
	or	4
	ld	e,a
	ret

A3363:	push	de
	push	af
	ld	hl,(D399D)
	ex	de,hl
	ld	a,e
	and	1Fh
	call	z,A32E2
	ld	hl,(D3995)
	add	hl,de
	pop	af
	push	af
	ld	(hl),a
	ld	a,e
	and	1Fh
	cp	1Fh
	jr	z,A337E
	inc	de
A337E:	call	z,A3388
	ex	de,hl
	ld	(D399D),hl
	pop	af
	pop	de
	ret

A3388:	ld	a,e
	and	0E0h
	ld	e,a
	call	A32D7
	ld	a,d
	or	e
	jp	z,A32E2
	inc	de
	inc	de
	inc	de
	inc	de
	ret

A3399:	push	de
	ld	de,(D3995)
	ld	a,l
	and	1Fh
	jr	nz,A33A5
	set	2,l
A33A5:	ex	de,hl
	add	hl,de
	ld	a,(hl)
	ex	de,hl
	pop	de
	ret

A33AB:	call	A3399
	push	af
	push	de
	ex	de,hl
	ld	a,e
	and	1Fh
	cp	1Fh
	jr	z,A33B9
	inc	de
A33B9:	call	z,A3388
	ex	de,hl
	pop	de
	pop	af
	ret

A33C0:	ex	de,hl
	ld	a,e
	and	0E0h
	ld	e,a
	push	de
	call	A32D7
	ld	a,e
	or	d
	pop	bc
	ret	z
	xor	a
	ld	(hl),a
	inc	hl
	ld	(hl),a
	ld	hl,(D3995)
	add	hl,de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	push	bc
	call	A32BC
	pop	bc
	ld	hl,(D399B)
	ex	de,hl
	call	A32CE
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ret

A33E8:	ld	hl,(D399D)
	push	de
	ex	de,hl
	ld	a,e
	and	1Fh
	dec	de
	cp	4
	call	z,A3402
	ld	hl,(D3995)
	ld	(D399D),de
	add	hl,de
	ld	a,(hl)
	ex	de,hl
	pop	de
	ret

A3402:	ld	a,e
	and	0E0h
	ld	e,a
	call	A32CE
	ld	a,e
	or	1Fh
	ld	e,a
	ret

A340E:	push	de
	push	af
	ex	de,hl
	ld	a,e
	and	1Fh
	cp	1Fh
	jr	z,A3419
	inc	de
A3419:	call	z,A3388
	ex	de,hl
	pop	af
	pop	de
	ret

A3420:	ld	de,(D3997)
	ld	hl,(D3970)
	ld	a,(D3972)
	or	a
	jr	nz,A3431
	ld	hl,(D39A1)
	dec	h
A3431:	call	A327E			; hl-de -> de
	jp	c,symtable_full		; переполн. симв. таблицы
	ld	a,d
	or	a
	jp	z,symtable_full		; переполн. симв. таблицы
	rra
	ld	d,a
	rr	e
	push	de
	ld	de,(D3995)
	ld	hl,(D3997)
	or	a
	sbc	hl,de
	ld	b,h
	ld	c,l
	pop	de
	ld	hl,(D3997)
	ex	de,hl
	add	hl,de
	ld	(D3997),hl
A3456:	ld	a,b
	or	c
	jp	z,A3463
	dec	hl
	dec	de
	ld	a,(de)
	ld	(hl),a
	dec	bc
	jp	A3456
	;
A3463:	ld	(D3995),hl
	ret

A3467:	call	A346D
	jp	A32F7

A346D:	push	de
	ld	de,(D36AC)
	ld	hl,(D3995)
	call	A327E			; hl-de -> de
	jp	c,symtable_full		; переполн. симв. таблицы
	ld	a,d
	cp	3
	jp	c,symtable_full		; переполн. симв. таблицы
	rra
	ld	d,a
	rr	e
	pop	hl
	push	bc
	push	hl
	ld	hl,(D3995)
	ex	de,hl
	ex	(sp),hl
	or	a
	sbc	hl,de
	ld	b,h
	ld	c,l
	pop	de
	ld	hl,(D3995)
	push	hl
	ld	hl,(D36AC)
	add	hl,de
	push	hl
	ld	(D3995),hl
	add	hl,bc
	ld	(D3997),hl
	pop	hl
	pop	de
	ld	a,b
	or	c
	jr	z,A34AD
	ex	de,hl
	ldir
	ex	de,hl
A34AD:	pop	bc
	ret


A34AF:	ld	hl,T392C		; ds 66
	ld	b,33
A34B4:	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	push	hl
	push	bc
	call	A34C2
	pop	bc
	pop	hl
	djnz	A34B4
	ret

A34C2:	ld	bc,0
	push	bc
	ld	a,d
	or	e
	jp	z,A17F8
A34CB:	ex	de,hl
	push	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,e
	or	d
	jp	nz,A34CB
A34D5:	pop	hl
	ld	a,l
	or	h
	ret	z
	call	A34EF
	dec	hl
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	ld	a,e
	or	d
	jr	z,A34D5
	xor	a
	ld	(hl),a
	inc	hl
	ld	(hl),a
	dec	hl
	dec	hl
	dec	hl
	push	hl
	jr	A34CB

A34EF:	ld	bc,4
	add	hl,bc
	ld	b,(hl)
	inc	hl
	ld	(D36AA),hl
	bit	6,(hl)
	ret	nz
	inc	hl
	bit	7,(hl)
	call	nz,A3543
	ld	a,(hl)
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	bc
	ld	b,a
	and	8Ch
	jr	nz,A3511
	bit	6,b
	call	nz,A3518
A3511:	pop	bc
	ld	hl,(D36AA)
	set	6,(hl)
	ret

A3518:	push	de
	push	bc
	ld	hl,(D36AA)
	push	hl
	inc	hl
	ld	a,b
	and	3
	ld	b,a
	ld	c,7			; элемент "define entry point (A-поле - адрес, B-поле - имя)"
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D37C8),de
	pop	de
	call	A182D
	pop	hl
	ld	(D36AA),hl
	inc	hl
	bit	5,(hl)
	call	nz,put_spec_item
	pop	bc
	pop	de
	ret

A3543:	push	bc
	push	hl
	ld	a,(hl)
	and	3
	ld	b,a
	ld	c,6			; элемент "chain external"
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	call	put_spec_item
	pop	hl
	pop	bc
	ret


; Получить след. символ из потока
; выход: a = байт из потока
;        "z" - символ
;        "nc" - число
;        "c" - не доп. символ ?
nextchar:
	push	hl
	ld	hl,(D36B1)		; тек. адрес в потоке
	ld	a,(hl)
	inc	hl
	ld	(D36B1),hl
	ld	l,a
	cp	"A"
	jr	nc,A3573
	cp	"0"
	jr	c,A356B
	cp	"9"+1
	jr	c,A3570
A356B:	scf
	sbc	a,a
	ld	a,l
	pop	hl
	ret
A3570:	or	a
	pop	hl
	ret
A3573:	cp	"Z"+1
	jr	c,A357F
	cp	"a"
	jr	c,A356B
	cp	"z"+1
	jr	nc,A356B
A357F:	xor	a
	ld	a,l
	pop	hl
	ret

; узнать след. символ не смещ. поток
A3583:	call	nextchar
	jr	A3595			; поток на байт назад


A3588:	call	nextchar
	push	af
	cp	0Dh
	jp	nz,A17F8
	call	A0501			; "Syntax error"
	pop	af
	; поток на байт назад
A3595:	push	hl
	ld	hl,(D36B1)		; тек. адрес в потоке
	dec	hl
	ld	(D36B1),hl
	pop	hl
	ret

; продвинуть полож. в потоке на 1 байт
A359F:	ld	hl,(D36B1)		; тек. адрес в потоке
	inc	hl
	ld	(D36B1),hl
	ret


A35A7:	call	nextchar
	ret	nz
	cp	"a"
	jr	c,A35B1
	sub	20h
A35B1:	cp	a
	ret


; Получить (в буфер токена) след. токен из потока
; выход: a=символ
token_copy:
	call	skipspace
	call	A3595			; поток на байт назад
;	ld	hl,idname		; имя идентиф.
;	ld	bc,2020h		; b=32 счетчик
;A35BF:	ld	(hl),c
;	inc	hl
;	djnz	A35BF
	ld	hl,idlen		; ячейка длины идентиф.
	ld	(hl),0			; сбросить длину
	inc	hl			; hl=буфер тек. зарез. слова (мнемоники)
	call	A3609
	call	nz,A3654
	ld	(D3665),a
	ld	c,0			; счетчик длины идентиф.
A35D4:	cp	"a"
	jr	c,A35DA
	sub	20h			; a..z -> A..Z
A35DA:	ld	(hl),a			; сохр. символ в буфере токена
	inc	hl
	inc	c
	ld	a,c
	cp	30			; макс. длина идентиф.
	jr	z,A35F8
	call	A3609
	jp	p,A35D4
	call	A3630
	jr	nc,A35F0
	jp	p,A35D4
A35F0:	ld	b,a
	ld	a,c
	ld	(idlen),a		; длина идентиф.
	ld	(hl)," "		; поставил
	xor	a
	ld	a,b
	ret
A35F8:	call	A3609
	jp	p,A35F8
	call	A3630
	jr	nc,A35F0
	jp	p,A35F8
	jr	A35F0

A3609:	call	nextchar
	ret	p
	cp	"$"
	ret	z
	cp	"."
	ret	z
	cp	"@"
	ret	z
	cp	"?"
	ret	z
	cp	"_"
	ret	z
	cpl
	or	a
	cpl
	ret

skipspace:
	call	nextchar
	ret	p
	cp	" "
	jr	z,skipspace
	cp	9			; Tab
	jr	z,skipspace
	cpl
	or	a
	cpl
	ret

A3630:	push	af
	or	a
	jr	z,A3638
	cp	"&"
	jr	nz,A363F
A3638:	ld	a,(D3973)
	or	a
	jp	nz,A3641
A363F:	pop	af
	ret
A3641:	pop	af
A3642:	call	A3609
	or	a
	jr	z,A3642
	cp	"&"
	jr	z,A3642
	call	A3595			; поток на байт назад
	call	A3609
	scf
	ret

A3654:	call	A3630
	jr	nc,A365A
	ret	z
A365A:	pop	bc
	ld	c,0
	ld	b,a
	ret



D365F:	dw	0
D3661:	dw	0			; номер тек. строки asm-листинга
D3663:	dw	0
D3665:	db	0
D3666:	db	0
D3667:	db	0
D3668:	db	0
D3669:	db	0

pass2:	db	false			; false/true  тек. проход

D366B:	dw	0			; число ошибок
D366D:	dw	0			; число предупреждений
D366F:	db	10			; база чисел
D3670:	db	0
D3671:	db	0
D3672:	db	0
D3673:	db	0

T3674:	ds	50

D36A6:	db	0
D36A7:	db	0
D36A8:	db	0
D36A9:	db	0
D36AA:	dw	0
D36AC:	dw	0
D36AE:	dw	0

D36B1:	dw	0			; тек. адрес в потоке

D36B3:	ds	257			; буфер строки

T37B4:	ds	7

D37BB:	db	0			; ячейка типа сегмента
	;-
D37BC:	dw	0			; счетчик org ?
D37BE:	dw	0			; размер aseg-области
D37C0:	dw	0			; размер code-области
D37C2:	dw	0			; размер data-области
D37C4:	dw	0			; размер common-области
	;-
D37C6:	dw	0
D37C8:	dw	0
D37CA:	dw	0
D37CC:	db	0
T37CD:	db	0
D37CE:	db	0
D37CF:	dw	0
D37D1:	db	0
D37D2:	db	0

; буфер тек. зарез. слова (мнемоники)
idlen:	db	0			; длина идентиф.
idname:	ds	32			; имя идентиф.
	;
T37F4:	db	0			; копия
	ds	32

D3815:	db	0			; символ ошибки
	ds	31			; буфер строки-признака ошибки ?

D3835:	db	0
D3836:	db	0
D3837:	dw	0
D3839:	db	0
D383A:	db	0

; ячейки не разделять
D383B:	db	0			; ячейка записываемого rel-байта
outrem:	db	0F8h			; счетчик границы байта

D383D:	db	0
D383E:	db	0
D383F:	db	0

save_stack:
	dw	0			; сохр. стек

D3842:	dw	0
D3844:	db	0
D3845:	db	0
D3846:	ds	5
D384B:	db	0
D384C:	db	0

D384D:	ds	64

T388D:	ds	65

T38CE:	db	0
D38CF:	db	0
D38D0:	db	0
D38D1:	dw	0
D38D3:	dw	0

T38D5:	ds	10			; буфер имени для name('...')

T38DF:	ds	3
T38E2:	ds	3
D38E5:	db	0
D38E6:	dw	0
D38E8:	dw	0

T38EA:	ds	66

T392C:	ds	66

D396E:	dw	0
D3970:	dw	0
D3972:	db	0
D3973:	db	0
D3974:	db	0
D3975:	dw	0
D3977:	dw	0
D3979:	dw	0
D397B:	dw	0
D397D:	db	0
D397E:	db	0
D397F:	dw	0
D3981:	dw	0
D3983:	dw	0
D3985:	db	0
D3986:	db	0
D3987:	db	0
D3988:	db	0
D3989:	dw	0
D398B:	dw	0
D398D:	db	0
D398E:	dw	0
D3990:	dw	0
D3992:	db	0
D3993:	dw	0
D3995:	dw	0
D3997:	dw	0
D3999:	dw	0
D399B:	dw	0
D399D:	dw	0
D399F:	dw	0
D39A1:	dw	0


; 3-й байт - порядк. номер
T39A3:	db	51h,"A",7
	db	51h,"B",0
	db	51h,"C",1
	db	51h,"D",2
	db	51h,"E",3
	db	51h,"H",4
	db	51h,"L",5
	db	62h,"SP",6
	db	51h,"I",8
	db	51h,"R",9
	db	62h,"BC",0
	db	62h,"DE",2
	db	62h,"HL",4
	db	62h,"AF",6
	db	6Ah,"IX",44h
	db	6Ah,"IY",64h
	; недокум. регистры
	db	52h,"HX",44h
	db	52h,"HY",64h
	db	52h,"LX",45h
	db	52h,"LY",65h
	db	52h,"XH",44h		; поставил
	db	52h,"YH",64h		;
	db	52h,"XL",45h		;
	db	52h,"YL",65h		;
	db	53h,"IXH",44h
	db	53h,"IYH",64h
	db	53h,"IXL",45h
	db	53h,"IYL",65h
	;
	db	72h,"NZ",0
	db	71h,"Z",1
	db	72h,"NC",2
	db	71h,"P",6
	db	71h,"M",7
	db	72h,"PO",4
	db	72h,"PE",5
	db	0,0


D3A27:	dw	0
;	ds	3			; ?

D3A2C:	db	false			; флаг "zero init DS"
D3A2D:	db	false			; флаг "truncate to 6 characters"
extended_rel_mode:
	db	false			; флаг "extended REL output"





usage:	ld	hl,Help			; вывод помощи
	jp	A40C7


A40BE:	ld	hl,T408E		; "File not found"
	jp	A40C7


A40C4:	ld	hl,T409D		; "Can't create file"
A40C7:	call	A40AE			; вывод строки на экран
	call	newline
	jp	abort			; выйти в ДОС






handle_rel:
	db	0			; дескриптор .rel файла

; FCB имя .rel файла, 37 байт
T3A2F:	ds	65;
;T3A2F:	ds	14
;D3A3D:	dw	0
;	ds	17
;D3A50:	dw	0
;D3A52:	dw	0


handle_asm:
	db	0			; дескриптор .asm файла

; FCB имя .asm файла, 37 байт
T3A54:	ds	65;
;T3A54:	db	0
;	ds	8
;D3A5D:	db	0
;	ds	4
;D3A62:	dw	0
;	ds	17
;D3A75:	dw	0
;D3A77:	dw	0

;	ds	12			; нужно ??


; расш. файлов по-умолчанию
T3A85:	db	".REL",0
T43F9:	db	".ASM",0


; буфер REL файла
rel_ptr:dw	0			; число байт (и тек.полож. в буфере)
	;
outrel:	ds	512			; буфер REL-файла


; буфер ASM файла
asm_ptr:dw	0			; число чит. байт
	;
D3C8D:	ds	1024+1			; буфер ASM-файла





;[]========================================[]
;   Начало программы
;
start:	ld	(L0080),hl		; сохр. адрес ком-строки
	ld	hl,stack		; вершина стека
	dec	hl
	dec	hl
	dec	hl
	dec	hl
	ld	sp,hl
	ld	(D3A27),hl
	call	save_path		; сохр. тек. путь
	xor	a			; false
	ld	(D3A2C),a		; флаг "zero init DS"
	ld	hl,(L0080)		; адрес ком-строки
	ld	c,(hl)			; длина ком-строки
	inc	hl
	ld	b,a
	add	hl,bc
	ld	(hl),a			; нуль в конец ком-строки
	ld	hl,(L0080)		; начало ком-строки
	inc	hl
A40EF:	ld	a,(hl)
	inc	hl
	cp	" "
	jr	z,A40EF
	cp	9
	jr	z,A40EF
	or	a
	jr	z,A414A			; конец парсинга
	cp	"-"			; префикс опций
	jr	z,A410A
	dec	hl
	ld	de,T3A54		; имя .asm файла
	ld	iy,T43F9		; ".asm" расш. по-умолчанию
	call	A9E9F			; добавить расш., если не задано
	jr	A40EF
	; разбор опций
A410A:	ld	a,(hl)
	inc	hl
	cp	" "
	jr	z,A40EF
A4110:	cp	9			; Tab
	jr	z,A40EF
	and	5Fh
	cp	"T"			; огран. имен глоб. меток до 6 символов
	jr	z,A412A
	cp	"X"			; расширенный (extended) REL формат
	jr	z,A4137
	cp	"Z"
	jp	nz,usage		; вывод помощи
	; "Z" иниц."ds" нулями
	ld	(D3A2C),a		; ячейка флага
	jr	A410A
	;
	; "T" ограничение имен глоб. меток до 6 символов
A412A:	ld	(D3A2D),a		; ячейка флага
	ld	a,6			; макс. длина имени метки
	ld	(putlensym+1),a
	ld	(A18C5+1),a
	jr	A410A
	;
	; "X" расширенный (extended) REL формат
A4137:	ld	(extended_rel_mode),a	; ячейка флага
	push	hl
	ld	hl,A18B7
	ld	(L188E+1),hl
	ld	hl,ext_putlensym	; процедура обработки
	ld	(L189B+1),hl
	pop	hl
	jr	A410A
	;
	; конец парсинга ком. строки
	;
A414A:	ld	hl,T3A54		; имя .asm файла
	ld	a,(hl)			; имя файла
	cp	" "+1
	jp	c,usage			; вывод помощи
	; создать имя .rel файла
	ld	de,T3A2F		; FCB rel-файла
	ld	bc,T3A85		; "REL" расш. по-умолчанию
	call	LA1B9			; скопировать имя файла
A4175:	ld	hl,(L0080)
	ld	(hl),0
	call	open_file		; откр. ASM файл
	ld	hl,0F800h		; h=счетчик границы байта
	ld	(D383B),hl		; сбр. ячейки
	call	create_file		; создать REL файл
	ld	a,(extended_rel_mode)	; флаг "extended REL output"
	or	a			; расширенный ?
	call	nz,A4194		; да, записать нач. биты
	ld	hl,(D3A27)
	inc	hl
	inc	hl
	jp	A0103


; Копирование имени файла и добавление расширения
; вход: hl-откуда
;       de-куда
;       bc-расш. по-умолчанию
LA1B9:	ld	a,(hl)
	inc	hl
	cp	"."
	jr	z,LA1BE
	cp	"a"
	jr	c,LA1BB
	and	5Fh
LA1BB:	ld	(de),a
	inc	de
	or	a
	jr	nz,LA1B9
	dec	de
	; скопир. расш. по-умолчанию
LA1BE:	ld	a,(bc)
	inc	bc
	ld	(de),a
	inc	de
	or	a
	jr	nz,LA1BE
	ret


; Проверка имени файла на расширение и его обработка.
; Отслеживается макс. длина абсол. имени файла
; вход: hl-адрес ком.строки
;       de-буфер имени
;       iy-адрес расш.
;
A9E9F:	ld	b,64-3			; макс. длина "\диск\каталог\имя" (без расш.)
A9EA0:	ld	a,(hl)
	inc	hl
	cp	"."
	jr	z,A9EB7
	cp	"a"
	jr	c,A9EA6
	and	5Fh
A9EA6:	ld	(de),a
	;or	a
	;jr	z,A9EAD
	cp	" "+1
	jr	c,A9EAD
	inc	de
	djnz	A9EA0
	; скопир. расш. по-умолчанию
A9EAD:	ld	a,(iy+0)
	inc	iy
	ld	(de),a
	inc	de
	or	a
	jr	nz,A9EAD
	ret
	; скопир. расш.
A9EB7:	ld	(de),a
	;or	a
	;ret	z
	cp	" "+1
	ret	c
	inc	de
	ld	a,(hl)
	cp	"a"
	jr	c,A9EBC
	and	5Fh
A9EBC:	inc	hl
	jr	A9EB7





; Запись начальных битов при extended REL output
A4194:	scf				; бит="1"
	call	putbit
	ld	b,00100001b		; 21h
	call	A1900			; запись 9-ти бит
	ld	b,0FEh			; признак extended REL формата
	jp	A1904			; записать байт признака



; Записать готовый байт в "outrel"
; вход: a = байт
A4263:	push	af
	push	de
	ld	hl,(rel_ptr)		; число запис. байт
	bit	1,h			; 512 ?
	call	nz,A4246		; да, записать готовый блок
	inc	hl
	ld	(rel_ptr),hl		; число байт (и тек.полож. в буфере)
	ld	de,rel_ptr+1		; начало буфера
	add	hl,de
	pop	de
	pop	af
	ld	(hl),a			; сохр. байт в "outrel"
	ret


; Чтение ASM файла
; выход: "nc" - Ok
;        "c" - конец тек. блока данных
A427B:	push	hl
	push	de
	ld	hl,(asm_ptr)		; число чит. байт
	bit	2,h			; 1024 ?
	call	nz,A4296		; да, прочитать след. порцию
	inc	hl
	ld	(asm_ptr),hl
	ld	de,asm_ptr+1
	add	hl,de
	pop	de
	ld	a,(hl)
	pop	hl
	cp	1Ah			; код конца блока
	scf
	ret	z			; конец блока данных
	or	a
	ret




handle_incl:
	db	0			; дескриптор include-файла

; FCB include-файла, 37 байт
T42EC:	ds	65;
;T42EC:	ds	14
;D42FA:	dw	0
;	ds	17
;D430D:	dw	0
;D430F:	dw	0


D4311:	db	0			; 00,FF..80
D4312:	dw	T4314			; тек. полож. в T4314

; буфер include-файлов
T4314:	ds	65



	%include "io.asm"


	; ds убрать ?
T43FD:	;ds	299			; начало буферов ассемблера


Help:	db	"Syntax: AS [options] <file>[.asm]",0Dh,0Ah
	db	"options:",0Dh,0Ah
	db	" -t",9,"truncate globals to 6 characters",0Dh,0Ah
	db	" -x",9,"extended REL output",0Dh,0Ah
	db	" -z",9,"zero init DS memory",0Dh,0Ah,0
