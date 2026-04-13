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

%idefine DEBUG	yes		; режим компиляции исходника




;
; Компилятор SOLID C  2-й проход (кодогенератор)
;
;
;------------------------------------------------------------------------
; Примечания к программе:
;
; Позволяет компилировать несколько бОльшие исходники, по сравнению
; с фирменной версией.
;
;
; Исправлены две фирм. ошибки:
;    1. Нельзя было указывать расширение для TMC-файлов.
;    2. Зависание при компиляции запредельно больших исходников.
;       Исправлен вызов "A74A0" (см. ниже метки A764F).
;
;
; Коды возврата компилятора:
; ~~~~~~~~~~~~~~~~~~~~~~~~~
;   #00 - Ok
;   #FF - были errors/warnings, ошибки выделения памяти или работы с файлами.
;
;
; Если не указано расширение у входного файла, то используется ".tmc".
; Если не указано расширение для выходного файла, то используется ".asm".
;
; Макс. длина строки "\диск\каталог\имя файла" не более 64 символов.
; 61 символ - без расширения файла. Лишняя строка обрезается.
;
; Если путь расположения для выходного файла не указан, то по-умолчанию
; он создается в каталоге расположения входного файла.
;
; Между опцией "-o" (имя вых. asm-файла) и заданным именем не должно
; быть пробела!.
;
;
; Макс. длина индикатора из "----+++" до переполнения буферов, составляет
; чуть больше 3,5..4,5 (зависит от вариантов кода) полных линий на экране.
;
; Предположительно:  индикаторы "----"  - генерация кода
;                    индикаторы "++++"  - оптимизация кода
;
;
;
;------------------------------------------------------------------------
;
;
;
; warnings - ячейка флага наличия предупреждений
; D9BE6 - символ постфикса имен asm-листинга ("_" по-умолчанию)
; D9CEA - флаг опции "k", (false по-умолчанию, удаление файла т-кода)
;
;





true	equ	1
false	equ	0

; порты страниц
PAGE_0	equ	82h
PAGE_1	equ	0A2h
PAGE_3	equ	0E2h


L7530	equ	30000			; L752F+1  ??
Stack	equ	0FFF0h ;0FEB0h		; начало стека ;(см. метку "A357B")



	org	0100h


	jp	start

A0103:	call	cpshd			; знак. сравнение hl с de
	ret	nc
	ex	de,hl
	ret


A02F8:	ld	a,(de)
	inc	de
	cpi
	jr	nz,A0304
	or	a
	jr	nz,A02F8
	ld	a,true
	ret
A0304:	xor	a
	ret


A0306:	cp	"0"
	jr	c,.loc1
	cp	"9"+1
	ret	c
.loc1:	xor	a			; false
	ret


A030F:	ld	c,e
	ld	de,14
	call	cpshd			; знак. сравнение hl с de
	jr	c,A034D
	ld	(D99F1),hl
	inc	c
	dec	c
	push	af
	jr	z,A032A
	ld	c,0C4h
	ld	e,0C2h
	ld	a,62h
	call	A40DA
A032A:	ld	bc,0
	push	bc
	ld	hl,(D99F1)
	push	hl
	ld	c,15h
	push	bc
	ld	e,c
	ld	c,10h
	ld	a,53h
	call	A3F47
	pop	bc			; выровнять стек
	pop	bc
	pop	bc
	pop	af
	ret	z
	ld	c,0C2h
	ld	e,0C4h
	ld	a,62h
	jp	A40DA
	;
A034D:	ld	a,l
	or	h
	ret	z
	ld	c,15h
	ld	e,0C0h
	ld	a,55h
	push	hl
	call	A40DA
	pop	hl
	dec	hl
	dec	hl
	jr	A034D


A0360:	ld	hl,(D9CEE)
	ld	bc,-24
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9CF8),hl
	ld	hl,(D9CE3)
	ld	a,l
	sub	2
	or	h
	jr	nz,A0384
	ld	a,(D9CCE)
	or	a
	jr	z,A0384
	ld	a,1
	jr	A0385
	;
A0384:	xor	a
A0385:	ld	e,a
	push	de
	ld	de,(D9CE1)
	ld	hl,(D9CDF)
	add	hl,de
	pop	de
	call	A04F0
	ld	c,15h
	ld	e,c
	ld	a,50h
	call	A40DA
	ld	hl,(D9CEE)
	ld	bc,-24
	add	hl,bc
	ex	de,hl
	ld	hl,(D9CF8)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret


A03AB:	ld	hl,(D9CEC)
	ld	(D9CF8),hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	de,0
	ld	(D99F3),de
	ld	(D99F7),hl
	push	de
	call	A04D6
	pop	de
A03C4:	ld	hl,(D9CCF)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A0473
	ld	l,e
	ld	h,d
	add	hl,hl
	add	hl,hl
	ld	bc,T9CD4
	add	hl,bc
	push	de
	ld	a,(hl)
	ld	(D99F6),a
	or	a
	jr	z,A03F2
	call	A41FA
	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl		;1+1=2
	add	hl,hl		;2+2=4
	add	hl,bc		;4+1=5
	ld	bc,T9C78
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,A046A
A03F2:	ld	hl,(D99F3)
	add	hl,hl
	add	hl,hl
	ld	bc,T9CD1
	add	hl,bc
	ld	c,(hl)
	ld	a,(D9CCD)
	or	a
	jr	z,A040C			; false
	ld	e,15h
	ld	a,54h
	call	A40DA
	jr	A046A
	;
A040C:	ld	a,(D99F6)
	or	a
	jr	z,A042D
	push	bc
	call	A41FA
	ld	b,a
	ld	hl,1
	call	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	ex	de,hl
	ld	hl,(D9CE7)
	ld	a,l
	and	e
	ld	l,a
	ld	a,h
	and	d
	ld	h,a
	pop	bc
	ld	a,l
	or	h
	jr	z,A046A
A042D:	ld	hl,T99F5
	ld	(hl),c
	ld	hl,(D99F3)
	add	hl,hl
	add	hl,hl
	ld	bc,T9CD2
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,0
	push	bc
	ld	c,10h
	push	bc
	ld	hl,T99F5
	ld	c,(hl)
	bit	0,c
	ld	a,5Bh
	jr	nz,A0454
	ld	a,59h
A0454:	ld	e,12h
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	ld	de,(D9CE5)
	ld	hl,(D9CF8)
	ld	bc,6
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
A046A:	pop	de
	inc	de
	ld	(D99F3),de
	jp	A03C4
	;
A0473:	ld	de,10
	ld	hl,(D9CDF)
	call	cpshd			; знак. сравнение hl с de
	jr	c,A0487
	ld	hl,(D9CE5)
	ld	a,l
	and	10h
	jr	z,A04A4
A0487:	ld	de,0
A048A:	ld	hl,(D9CDF)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A04C2
	ld	c,0C0h
	push	de
	ld	e,15h
	ld	a,54h
	call	A40DA
	pop	de
	inc	de
	inc	de
	jr	A048A
	;
A04A4:	ld	bc,0
	push	bc
	ld	hl,(D9CDF)
	ld	a,l
	cpl
	ld	l,a
	ld	a,h
	cpl
	ld	h,a
	inc	hl
	push	hl
	ld	c,15h
	push	bc
	ld	c,10h
	ld	e,15h
	ld	a,53h
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
A04C2:	ld	hl,(D9CF8)
	push	hl
	ld	de,(D99F7)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,2
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret


A04D6:	ld	hl,(D9CDF)
	ld	de,(D9CE1)
	add	hl,de
	ld	a,h
	or	l
	jr	nz,A04E7
	ld	a,(D99F0)
	or	a
	ret	z			; false ?
A04E7:	ld	c,15h
	ld	e,c
	ld	a,7Dh
	jp	A40DA


A04F0:	ld	a,h
	or	l
	jr	nz,A04F9
	ld	a,(D99F0)
	or	a
	ret	z			; false ?
A04F9:	ld	c,15h
	ld	e,c
	ld	a,7Eh
	jp	A40DA


T0502:	db	0Ah,"?D:"		; метка "?число:"
	db	9,"ds",9,"D",0

A050C:	ld	hl,0
	ld	(D99F9),hl
	ld	(D99FB),hl
	ld	hl,-1
	ld	(D99FD),hl
	ld	hl,(D9CF2)
	ld	(D99FF),hl
	ex	de,hl
A0522:	ld	hl,(D9CF0)
	or	a
	sbc	hl,de
	jp	z,A05D7
	ld	a,(de)
	push	de
	ld	(D9A01),a
	cp	45h
	jr	z,A0544
	cp	41h
	jr	z,A0587
	cp	70h
	jp	nz,A05CB
	ld	hl,(D99FD)
	inc	hl
	ld	(D99FD),hl
A0544:	ld	hl,5
	add	hl,de
	ld	a,(hl)
	or	a
	jr	z,A0560
	call	A41FA
	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl		;1+1=2
	add	hl,hl		;2+2=4
	add	hl,bc		;4+1=5
	ld	bc,T9C78
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,A05CB
A0560:	ld	a,(D9CCD)
	or	a
	jr	nz,A0587		; true
	call	set_dseg		; уст. тип "dseg"
	ld	hl,(D99FF)
	ex	de,hl
	ld	hl,4
	add	hl,de
	ld	b,(hl)
	dec	hl
	ld	c,(hl)
	push	bc
	dec	hl
	ld	b,(hl)
	dec	hl
	ld	c,(hl)
	push	bc
	ld	bc,T0502		; метка "?число: ds  число"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	jr	A05CB
	;
A0587:	ld	a,(D9A01)
	cp	70h
	jr	nz,A05B4
	ld	hl,(D99FB)
	dec	hl
	dec	hl
	ld	(D99FB),hl
	push	hl
	ld	hl,(D99FD)
	add	hl,hl
	add	hl,hl
	ld	bc,T9CD1
	add	hl,bc
	ld	a,(hl)
	pop	hl
	cp	7
	jr	nz,A05A7
	inc	hl
A05A7:	ex	de,hl
	ld	hl,(D99FF)
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	jr	A05CB
	;
A05B4:	ld	de,(D99F9)
	ld	hl,(D99FF)
	inc	hl
	inc	hl
	inc	hl
	push	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	add	hl,de
	ld	(D99F9),hl
	pop	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
A05CB:	pop	hl
	ld	bc,6
	add	hl,bc
	ld	(D99FF),hl
	ex	de,hl
	jp	A0522


A05D7:	ld	hl,(D99F9)
	inc	hl
	res	0,l
	ld	(D9CDF),hl
	ld	hl,(D99FB)
	ld	a,l
	cpl
	ld	l,a
	ld	a,h
	cpl
	ld	h,a
	inc	hl
	ld	(D9CE1),hl
	ld	de,(D9CF2)
A05F1:	ld	hl,(D9CF0)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	ld	a,(de)
	push	de
	cp	50h
	jr	z,A0603
	cp	70h
	jr	nz,A0619
A0603:	ld	hl,3
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	hl
	ld	bc,(D9CE1)
	ld	hl,(D9CDF)
	add	hl,bc
	add	hl,de
	ex	de,hl
	pop	hl
	ld	(hl),d
	dec	hl
	ld	(hl),e
A0619:	pop	de
	ld	hl,6
	add	hl,de
	ex	de,hl
	jr	A05F1


A0622:	ex	de,hl
	ld	hl,T13C3
	ld	a,(D9CC5)
	cp	(hl)
	jr	nc,A0637
	ld	a,d
	or	a
	jr	nz,A0637
	ld	a,e
	or	a
	ret	z
	cp	3
	jr	c,A0639
A0637:	xor	a
	ret
A0639:	dec	a
	ld	hl,(D9CC5)
	ld	h,0
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C77
	add	hl,bc
	ld	(hl),a
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0FFh
	ld	hl,D9CC5
	ld	a,(hl)
	inc	(hl)
	jp	A41F3


A0657:	ld	c,l
	ld	b,h
	ld	hl,(D9CF4)
	ex	de,hl
	push	bc
A065E:	dec	de
	inc	bc
	ld	hl,-1
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	nz,A065E
	ld	hl,(D9CF0)
	push	de
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	c,A762B
	pop	de
	ld	l,e
	ld	h,d
	ld	(D9CF4),hl
	pop	bc
A067A:	ld	a,(bc)
	inc	bc
	ld	(de),a
	inc	de
	or	a
	jr	nz,A067A
	ld	hl,(D9CF4)
	ret


A0685:	ld	hl,(D9CF0)
	ld	(D9A02),de
	ld	(D9A06),hl
	ex	de,hl
	ld	hl,(D9CF4)
	push	de
	push	hl
	ld	hl,6
	add	hl,de
	ld	(D9CF0),hl
	pop	de
	push	af
	ld	(D9A04),bc
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	c,A762B
	pop	af
	pop	de
	ld	(de),a
	ld	hl,1
	add	hl,de
	ld	bc,(D9A02)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,3
	add	hl,de
	ld	bc,(D9A04)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	ld	hl,5
	add	hl,de
	ld	(hl),c
	cp	45h
	jr	z,A06D7
	cp	70h
	ret	nz
A06D7:	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	or	a
	ret	z
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	call	A41FA
	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl		;1+1=2
	add	hl,hl		;2+2=4
	add	hl,bc		;4+1=5
	ld	bc,T9C75
	add	hl,bc
	ld	de,(D9A06)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret


A06FA:	ld	hl,(D9CF2)
	ld	(D9A0A),hl
	ld	de,(D9CF2)
A0704:	ld	hl,(D9CF0)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A0737
	ld	a,(de)
	push	de
	cp	47h
	jr	nz,A072E
	ex	de,hl
	ld	(D9A08),hl
	ld	hl,(D9A0A)
	ld	e,l
	ld	d,h
	push	hl
	ld	hl,(D9A08)
	ld	bc,6
	ldir
	pop	hl
	ld	bc,6
	add	hl,bc
	ld	(D9A0A),hl
A072E:	pop	de
	ld	hl,6
	add	hl,de
	ex	de,hl
	jr	A0704
	;
A0737:	ld	hl,(D9A0A)
	ld	(D9CF0),hl
	ret


A073E:	call	A76D5
	ld	(D9A0C),a
	call	A77A1
	ld	c,l
	ld	b,h
	ld	de,Table		; начало таблицы идентиф.
A074C:	ld	hl,(D9CF0)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A75D7		; вывод строки "bad t-codeP"
	ld	a,(de)
	ld	hl,(D9A0C)
	cp	l
	jr	nz,A0770
	ld	hl,1
	add	hl,de
	ld	a,(hl)
	cp	c
	inc	hl
	jr	nz,A0770
	ld	a,(hl)
	cp	b
	jr	nz,A0770
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret
A0770:	ld	hl,6
	add	hl,de
	ex	de,hl
	jr	A074C


A0778:	ld	(D9A0D),hl
	ld	hl,D9A0F
	ld	(hl),e
	ld	de,Table		; начало таблицы идентиф.
	ld	(D9A10),de
A0786:	ld	hl,(D9CF0)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A07B9
	ld	a,(de)
	cp	47h
	jr	nz,A07AB
	ld	(D9A10),de
	push	de
	ld	hl,1
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	de,(D9A0D)
	call	A02F8
	pop	hl
	or	a
	ret	nz
A07AB:	ld	hl,(D9A10)
	ld	de,6
	add	hl,de
	ld	(D9A10),hl
	ex	de,hl
	jr	A0786
	;
A07B9:	push	de
	ld	a,(D9A0F)
	ld	c,a
	push	bc
	ld	hl,(D9A0D)
	call	A0657
	ex	de,hl
	ld	bc,0
	ld	a,47h
	call	A0685
	pop	bc
	pop	hl
	ret


A07D1:	ld	(D9A16),bc
	ld	(D9A14),de
	ld	(D9A12),hl
	ld	hl,(D9CF2)
	ld	(D9A18),hl
	ex	de,hl
	push	bc
A07E4:	ld	hl,(D9CF0)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A0812
	ld	a,(de)
	cp	4Ch			; "L"
	jr	nz,A0807
	ld	hl,1
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	a,(hl)
	and	7Fh
	ld	b,a
	ld	hl,(D9A12)
	ld	a,c
	cp	l
	jr	nz,A0807
	ld	a,b
	cp	h
	jr	z,A0812
A0807:	ld	hl,6
	add	hl,de
	ld	(D9A18),hl
	ex	de,hl
	jr	A07E4
	;
A0812:	ld	hl,(D9CF0)
	push	de
	ld	bc,(D9A12)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	c,A083A
	ld	(D9A12),bc
	ld	c,0
	push	bc
	ld	hl,(D9A12)
	ld	c,l
	ld	b,h
D082C:	ld	e,c
	ld	a,b
	or	80h
	ld	d,a
	ld	bc,0
	ld	a,4Ch			; "L"
	call	A0685
	pop	bc
A083A:	pop	de
	ld	hl,1
	add	hl,de
	inc	hl
	ld	a,(hl)
	and	80h
	pop	bc
	or	a
	jr	z,A0898
	ld	hl,3
D084B:	add	hl,de
	push	de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9A1A),hl
	ld	hl,0
A0857:	ld	de,(D9A14)
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A088B
	push	hl
	add	hl,hl
	add	hl,bc
	ld	(D9A16),bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,12
	add	hl,bc
	ld	bc,(D9A1A)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	hl
	push	hl
	add	hl,hl
	ld	bc,(D9A16)
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9A1A),hl
	pop	hl
	inc	hl
	jr	A0857
	;
A088B:	pop	de
	ld	hl,3
	add	hl,de
	ld	bc,(D9A1A)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ret
A0898:	ld	hl,0
A089B:	ld	de,(D9A14)
	call	cpshd			; знак. сравнение hl с de
	ret	nc
	ld	(D9A1C),hl
	push	hl
	ld	hl,(D9A18)
	inc	hl
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	ld	hl,(D9A1C)
	add	hl,hl
	ld	de,(D9A16)
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,12
	add	hl,bc
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	inc	hl
	jr	A089B


A08CA:	ld	a,53h			; "S"
	db	21h			; ld hl,..
A08CD:	ld	a,55h			; "U"
	ld	(D9A1E),a
	call	A77A1
	ld	(D9A1F),hl
	call	A7728
	ld	hl,0
	ld	(D9A21),hl
A08E1:	push	hl
	call	A76D5
	pop	hl
	cp	29h			; ")"
	jr	z,A0933
	push	hl
	cp	4Dh			; "M"
	jp	nz,A75D7		; вывод строки "bad t-codeP"
	ld	c,0
	push	bc
	call	A77A1
	ex	de,hl
	ld	a,(D9A1E)
	cp	53h			; "S"
	ld	hl,(D9A21)
	jr	z,A0907
	ld	hl,0
A0907:	ld	c,l
	ld	b,h
	ld	(D9A1E),a
	ld	a,4Dh			; "M"
	call	A0685
	pop	bc
	call	A7731
	call	A073E
	ex	de,hl
	ld	a,(D9A1E)
	pop	hl
	cp	53h			; "S"
	jr	nz,A0925
	add	hl,de
	jr	A0928
	;
A0925:	call	A0103
A0928:	ld	(D9A21),hl
	push	hl
	call	A7728
	pop	hl
	jr	A08E1
	;
A0933:	ld	c,0
	push	bc
	ld	c,l
	ld	b,h
	ld	de,(D9A1F)
	ld	a,(D9A1E)
	call	A0685
	pop	bc
	ret


A0944:	call	A77A1
	ld	(D9A25),hl
	call	A7731
	call	A073E
	ld	(D9A23),hl
	call	A7731
	ld	c,0
	push	bc
	ld	de,D9CC8
	ld	hl,D9CC8
	call	A32DA
	ld	de,(D9A23)
	call	mul_hlde		; hl*de=hl
	ld	c,l
	ld	b,h
	ld	de,(D9A25)
	ld	a,56h
	call	A0685
	pop	bc
	ret


T0976:	db	"GXYTAP",0
T097D:	db	"EpAP",0


A0982:	ld	(D9A27),hl
	ld	hl,-34
	add	hl,sp
	ld	sp,hl
	ld	(D9A29),de
	ld	hl,(D9A27)
	push	de
	call	A76D5
	ld	(D9A2B),a
	ld	de,T0976
	call	A7695
	inc	h
	dec	h
	jp	m,A75D7			; вывод строки "bad t-codeP"
	ld	a,l
	push	hl
	ld	hl,(D9A27)
	ld	(hl),a
	pop	hl
	pop	bc
	cp	3
	jr	nc,A09D3
	ld	a,1
	ld	(bc),a
	ld	hl,0
	add	hl,sp
	call	A773B
	ld	a,(D9A2B)
	cp	59h			; "Y"
	ld	a,20h
	jr	z,A09C8
	ld	a,58h			; "X"
A09C8:	ld	e,a
	ld	hl,0
	add	hl,sp
	call	A0778
	jr	A0A52
	;
A09D3:	push	bc
	push	hl
	call	A77A1
	ld	(D9A30),hl
	pop	hl
	pop	bc
	ld	a,l
	sub	3
	or	h
	jr	nz,A09EC
	ld	a,2
	ld	(bc),a
	ld	hl,(D9A30)
	jr	A0A52
	;
A09EC:	ld	hl,(D9CF2)
	ld	(D9A2C),hl
	ex	de,hl
A09F3:	ld	hl,(D9CF0)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A0A4F
	ld	a,(de)
	ld	de,T097D
	call	A7695
	ld	(D9A2E),hl
	inc	h
	dec	h
	jp	m,A0A41
	ld	hl,(D9A2C)
	inc	hl
	ld	de,(D9A30)
	ld	a,(hl)
	cp	e
	inc	hl
	jr	nz,A0A41		; поставил на A0A41
	ld	a,(hl)
	cp	d
	jr	nz,A0A41
	ld	hl,(D9A2E)
	ld	de,2
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A0A35
	ld	a,(D9CCD)
	or	a
	jr	nz,A0A35		; true
	ld	a,2
	jr	A0A37
	;
A0A35:	ld	a,3
A0A37:	ld	hl,(D9A29)
	ld	(hl),a
	ld	hl,(D9A2C)
	jr	A0A52
	;
A0A41:	ld	hl,(D9A2C)
	ld	bc,6
	add	hl,bc
	ld	(D9A2C),hl
	ex	de,hl
	jr	A09F3
	;
A0A4F:	call	A75D7			; вывод строки "bad t-codeP"
A0A52:	ex	de,hl
	ld	hl,34
	add	hl,sp
	ld	sp,hl
	ex	de,hl
	ret
	;
T0A5A:	db	"INRBCZW",0
	;
A0A62:	call	A77A1
	ld	(D9A33),hl
	call	A7731
	call	A76D5
	call	A76BB
	ld	de,T0A5A
	call	A7695
	inc	h
	dec	h
	jp	m,A0A81
	ld	a,1
	jr	A0A82
A0A81:	xor	a
A0A82:	push	af
	call	A073E
	ex	de,hl
	ld	hl,(D9CDD)
	add	hl,de
	ld	(D9CDD),hl
	xor	a
	ld	(D9A37),a
	ld	(D9A35),de
	pop	af
	ld	(D9A32),a
	or	a
	jr	z,A0AA4
	ex	de,hl
	call	A0622
	ld	(D9A37),a
A0AA4:	ld	a,(D9A37)
	ld	c,a
	push	bc
	ld	bc,(D9A35)
	ld	de,(D9A33)
	ld	a,(D9A32)
	or	a
	jr	z,A0ABB
	ld	a,45h			; "E"
	jr	A0ABD
	;
A0ABB:	ld	a,41h			; "A"
A0ABD:	call	A0685
	pop	bc
	ret


D0AC2:	db	0			; 00/01  false/true ?

T0AC3:	db	"Ndb",9,0		; "	db"


A0AC8:	ld	de,10
	ld	hl,(D9A3A)
	push	af
	call	cpshd			; знак. сравнение hl с de
	jr	c,A0AE4
	ld	hl,0
	ld	(D9A3A),hl
	ld	bc,T0AC3		; "db	"  строка
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	jr	A0AE9
	;
A0AE4:	ld	a,2Ch			; ","
	call	A7808			; запись мнемоники в вых. файл
A0AE9:	pop	hl
	ld	l,h
	ld	h,0
	call	A7873			; вывод в буфер десят. числа
	ld	hl,(D9A3A)
	inc	hl
	ld	(D9A3A),hl
	ret

T0AF8:	db	0Ah,"?D:",0		; метка "?число:" с новой строки

A0AFD:	call	set_cseg		; уст. тип "cseg"
	ld	hl,(D9533)		; счетчик недост. (необход.) размера таблицы идентиф.
	dec	hl			; --счетчика
	ld	(D9533),hl
	ld	a,(D0AC2)
	or	a
	jr	z,A0B25			; false
	ld	hl,(D9533)
	ex	de,hl
	ld	hl,(D9A38)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D9A38)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	(D9A3C),hl
	jr	A0B32
	;
A0B25:	ld	hl,(D9533)
	push	hl
	ld	bc,T0AF8		; метка "?число:" с новой строки
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A0B32:	ld	hl,10
	ld	(D9A3A),hl
A0B38:	call	A76D5
	cp	22h			; '"'
	jr	z,A0B75
	cp	2Ch			; ","
	jr	z,A0B48
	call	A76BB
A0B48:	call	A77A1
	ld	a,(D0AC2)
	or	a
	jr	z,A0B6E			; false
	push	hl
	ld	hl,(D9CFC)
	ld	de,(D9A3C)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A7624		;1
	pop	hl
	ld	a,l
	ld	hl,(D9A3C)
	ld	(hl),a
	inc	hl
	ld	(D9A3C),hl
	jr	A0B38
	;
A0B6E:	ld	a,l
	call	A0AC8
	jr	A0B38
	;
A0B75:	ld	a,(D0AC2)
	or	a
	ret	z			; false
	ld	hl,(D9A38)
	inc	hl
	inc	hl
	ld	de,(D9A3C)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	(D9A38),de
	ret


T0B8B:	db	0Ah,"?D:",0


A0B90:	ld	de,(D9CF6)
A0B94:	ld	hl,(D9A38)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	ld	l,e
	ld	h,d
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	de
	push	bc
	ld	bc,T0B8B		; метка "?число:" с новой строки
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ld	hl,10
	ld	(D9A3A),hl
	pop	bc
	ld	hl,4
	add	hl,bc
	ex	de,hl
A0BB8:	ld	hl,2
	add	hl,bc
	ld	a,e
	sub	(hl)
	inc	hl
	ld	a,d
	sbc	a,(hl)
	jr	nc,A0B94
	ld	a,(de)
	push	bc
	push	de
	call	A0AC8
	pop	de
	inc	de
	pop	bc
	jr	A0BB8


T0BD0:	db	"M",0			; имя переменной (функция, массив и т.д.)
T0BD2:	db	"?D",0			; "?число"
T0BD5:	db	"?genwordP",0		; "?genword<рег.пара>"


A0BDF:	ex	de,hl
	ld	(D9A3E),hl
	and	3
	or	a
	jp	z,A7873			; вывод в буфер десят. числа
	cp	1
	jr	z,A0BF6
	cp	2
	jr	z,A0C03
	jr	A0C10
	;
A0BF6:	push	bc
	ld	bc,T0BD0		; "M" записать имя переменной (функция, массив и т.д.)
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	jr	A0C16
	;
A0C03:	push	bc
	ld	bc,T0BD2		; метка "?число"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	jr	A0C16
	;
A0C10:	ld	hl,T0BD5
	call	A75DA			; вывод строки "hl" (большие буквы зарез.)
A0C16:	ld	hl,(D9A3E)
	ld	a,l
	or	h
	ret	z
	inc	h
	dec	h
	jp	p,A0C34
	ld	a,"-"			; для "метка -"
	push	hl
	call	A7808			; запись мнемоники в вых. файл
	pop	hl
	ld	a,l
	cpl
	ld	c,a
	ld	a,h
	cpl
	ld	b,a
	inc	bc
	ld	l,c
	ld	h,b
	jr	A0C3B
	;
A0C34:	ld	a,"+"			; для "метка +"
	push	hl
	call	A7808			; запись мнемоники в вых. файл
	pop	hl
A0C3B:	jp	A7873			; вывод в буфер десят. числа



T0C3E:	db	0Ah,"M:",0		; "имя переменной:"
T0C42:	db	"Ndb",9,"D",0		; "	db	число"
T0C48:	db	"Ndw",9,0		; "	dw"
T0C4D:	db	0Ah,"M:",9,"ds",9,"D",0	; "имя переменной:  ds	число"


A0C56:	push	hl
	call	A7731
	call	A76D5
	call	A76BB
	pop	hl
	cp	28h			; "("
	jr	nz,A0CE3
	push	hl
	ld	a,true
	ld	(D0AC2),a
	ld	hl,(D9CF6)
	ld	(D9A38),hl
	call	set_cseg		; уст. тип "cseg"
	pop	hl
	push	hl
	ld	bc,T0C3E		; "M:" записать имя переменной (функция, массив)
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A0C80:	call	A7728
	call	A76D5
	cp	29h			; ")"
	jr	z,A0CDC
	call	A073E
	push	hl
	call	A7731
	pop	hl
	ld	a,l
	dec	a
	or	h
	jr	z,A0CA2
	ld	a,l
	sub	2
	or	h
	jr	z,A0CBA
	jp	A75D7			; вывод строки "bad t-codeP"
	;
A0CA2:	ld	de,D9CC8
	ld	hl,D9CC8
	call	A32DA
	ld	h,0
	push	hl
	ld	bc,T0C42		; "db число"  строка
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	jr	A0C80
	;
A0CBA:	ld	bc,T0C48		; "dw число"  строка
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	ld	de,D9A43
	ld	hl,D9A42
	call	A32DA
	push	hl
	ld	hl,(D9A43)
	ld	c,l
	ld	b,h
	pop	hl
	ex	de,hl
	ld	a,(D9A42)
	call	A0BDF
	jr	A0C80
	;
A0CDC:	xor	a			; false
	ld	(D0AC2),a
	jp	A0B90
	;
A0CE3:	ld	(D9A40),hl
	call	set_dseg		; уст. тип "dseg"
	call	A073E
	push	hl
	ld	hl,(D9A40)
	push	hl
	ld	bc,T0C4D		; "переменная: ds  число"  строка
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret


A0CFC:	ld	a,47h			; "G"
	call	A76BB
	ld	de,D9CC8
	ld	hl,D9CC8
	call	A0982
	ex	de,hl
	ld	hl,5
	add	hl,de
	ld	(hl),50h		; "P"
	ld	hl,1
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jp	A0C56


A0D1C:	ld	hl,-34
	add	hl,sp
	ld	sp,hl
	ld	a,3Fh			; "?"
	call	A76BB
	ld	hl,0
	add	hl,sp
	call	A773B
	ld	hl,0
	add	hl,sp
	call	A0C56
	ld	hl,34			; восст. стек
	add	hl,sp
	ld	sp,hl
	ret


A0D3A:	call	A76D5
	call	A76BB
	cp	0Ah
	jr	z,A0D60
	call	A073E
	ld	e,l
	ld	d,h
	push	hl
	ld	hl,2
	call	cpshd			; знак. сравнение hl с de
	jp	c,A75D7			; вывод строки "bad t-codeP"
	ld	a,1
	ld	(D9CCE),a
	call	A7731
	pop	hl
	call	A3304
A0D60:	ld	hl,(D9CF6)
	ld	(D9A45),hl
	ld	bc,0
	push	bc
	push	bc
	ld	c,14h
	push	bc
	ld	c,15h
	ld	e,c
	ld	a,4Dh
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	ld	bc,D9A45
	ld	de,1
	;ld	hl,L752F+1		; T7530 (jr nc,..)  ??
	ld	hl,L7530		; 30000
	jp	A07D1


A0D86:	call	A76D5
	cp	4Ch			; "L"
	jp	nz,A75D7		; вывод строки "bad t-codeP"
	jp	A77A1

A0D91:	ld	hl,(D9CFA)
	ld	a,l
	or	h
	jr	z,A0DA8
	ld	hl,(D9CF8)
	ld	(D9A4B),hl
	ld	hl,(D9CFA)
	ld	(D9CF8),hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
A0DA8:	push	hl
	call	A073E
	ld	(D9A49),hl
	push	hl
	call	A7731
	pop	hl
	call	A3304
A0DB7:	call	A7728
	call	A7731
	call	A76D5
	cp	77h
	jr	nz,A0E41
	call	A7731
	call	A0D86
	push	hl
	call	A7731
	ld	hl,(D9A49)
	ld	a,l
	dec	a
	or	h
	jr	nz,A0DFA
	ld	bc,0
	push	bc
	ld	de,D9CC8
	ld	hl,D9CC8
	call	A32DA
	ld	h,0
	push	hl
	ld	c,10h
	push	bc
	ld	c,47h
	ld	e,9
	ld	a,2Fh
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	jr	A0E17
	;
A0DFA:	ld	bc,0
	push	bc
	ld	de,D9CC8
	ld	h,d
	ld	l,e
	call	A32DA
	push	hl
	ld	c,10h
	push	bc
	ld	c,0C4h
	ld	e,9
	ld	a,2Dh
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
A0E17:	ld	hl,(D9CF6)
	ld	(D9A47),hl
	ld	bc,0
	push	bc
	push	bc
	ld	c,14h
	push	bc
	ld	c,9
	ld	e,15h
	ld	a,4Ch
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	pop	hl
	ld	de,1
	ld	bc,D9A47
	call	A07D1
	jp	A0DB7
	;
A0E41:	cp	66h
	jp	nz,A75D7		; вывод строки "bad t-codeP"
	call	A7731
	call	A0D86
	push	hl
	ld	hl,(D9CF6)
	ld	(D9A47),hl
	ld	bc,0
	push	bc
	push	bc
	ld	c,14h
	push	bc
	ld	c,15h
	ld	e,c
	ld	a,4Dh
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	pop	hl
	ld	de,1
	ld	bc,D9A47
	call	A07D1
	pop	de
	ld	a,e
	or	d
	ret	z
	ld	hl,(D9CF8)
	push	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,2
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D9A4B)
	ld	(D9CF8),hl
	ret


A0E91:	call	A3CC1
	ld	hl,(D9CF6)
	ld	a,80h
	ld	(D9CC6),a
	ld	c,15h
	ld	e,c
	ld	a,64h
	push	hl
	call	A40DA
	call	A7728
A0EA9:	call	A76D5
	cp	9
	jr	nz,A0EBE
	call	A76D5
	cp	62h
	jr	z,A0ECB
	call	A76BB
	ld	a,9
A0EBE:	call	A76BB
	call	A1048			; генерация кода из т-кода ??
	or	a
	jr	nz,A0EA9
	jp	A75D7			; вывод строки "bad t-codeP"
	;
A0ECB:	ld	c,15h
	ld	e,c
	ld	a,65h
	call	A40DA
	pop	hl
	ld	bc,0
	push	bc
	push	hl
	ld	c,14h
	push	bc
	ld	c,15h
	ld	e,c
	ld	a,4Dh
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	ret


A0EEA:	ld	(D9A4D),hl
	ld	hl,(D9CF8)
	ld	bc,8
	add	hl,bc
	ld	a,(hl)
	and	7Fh
	cp	4Dh			; "M"
	ld	a,1			; true ?
	jr	z,A0F02
	xor	a
A0F02:	ld	(D9A51),a
	ld	hl,(D9CF2)
	ex	de,hl
A0F09:	ld	hl,(D9CF0)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A0F37
	ld	a,(de)
	cp	4Ch			; "L"
	jr	nz,A0F2F
	ld	hl,1
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	a,(hl)
	and	7Fh
	ld	b,a
	ld	hl,(D9A4D)
	ld	a,c
	cp	l
	jr	nz,A0F2F
	ld	a,b
	cp	h
	jr	z,A0F37
A0F2F:	ld	hl,6
	add	hl,de
	ex	de,hl
	jr	A0F09
	;
A0F37:	ld	hl,(D9CF0)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A0FAE
	ld	hl,3
	add	hl,de
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9A4F),de
A0F4D:	ld	a,e
	or	d
	jr	z,A0F95
	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D9CF6)
	push	hl
	ld	hl,12
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	e,c
	ld	d,b
	ld	a,(D9A51)
	or	a
	jr	z,A0F8E
	ld	hl,(D9CF8)
	ld	bc,(D9A4F)
	ld	a,c
	cp	l
	jr	nz,A0F7D
	ld	a,b
	cp	h
	jr	z,A0F8E
A0F7D:	ld	hl,8
	add	hl,bc
	ld	a,(hl)
	and	7Fh
	cp	4Dh
	jr	nz,A0F8E
	ld	l,c
	ld	h,b
	ld	(D9CFA),hl
A0F8E:	ld	(D9A4F),de
	jr	A0F4D
	;
A0F95:	pop	de
	ld	hl,1
	add	hl,de
	inc	hl
	ld	a,(hl)
	and	7Fh
	ld	(hl),a
	ld	hl,(D9CF6)
	push	hl
	ld	hl,3
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	jr	A0FBF
	;
A0FAE:	ld	c,0
	push	bc
	ld	de,(D9A4D)
	ld	bc,(D9CF6)
	ld	a,4Ch			; "L"
	call	A0685
	pop	bc
A0FBF:	ld	a,80h
	ld	(D9CC6),a
	ret


A0FC5:	call	A7731
	call	A0D86
	ld	(D9A8F),hl
	ld	hl,1
	push	hl
	call	A76D5
	ld	(D9A8E),a
	pop	hl
	cp	9
	jr	nz,A0FFA
	call	A32AF
	ld	a,l
	and	h
	inc	a
	jr	nz,A0FFA
	call	A152F
	ld	hl,D9A52		; ds 60
	call	A156A
	ex	de,hl
	ld	hl,(D9A8F)
	ld	bc,D9A52		; ds 60
	jp	A07D1
	;
A0FFA:	ld	a,l
	or	h
	ret	z
	ld	a,(D9A8E)
	call	A76BB
	ld	hl,(D9CF6)
	ld	(D9A52),hl		; ds 60
	ld	bc,0
	push	bc
	push	bc
	ld	c,14h
	push	bc
	ld	c,15h
	ld	e,c
	ld	a,4Dh
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	ld	hl,(D9A8F)
	ld	de,1
	ld	bc,D9A52		; ds 60
	jp	A07D1


A102C:	call	A76D5
	cp	53h			; "S"
	jr	z,A103A
	cp	54h			; "T"
	jr	z,A1041
	jp	A75D7			; вывод строки "bad t-codeP"
	;
A103A:	ld	hl,false
	ld	(D9537),hl
	ret
A1041:	ld	hl,true
	ld	(D9537),hl
	ret


; Генерация кода из т-кода ??
; выход: Ok    - true (!=0)
;        Error - false
A1048:	call	A76D5
	cp	7Dh			; "}"
	jr	z,A107F
	ld	hl,A10A4
	push	hl
	cp	24h			; "$"
	jr	z,A102C
	cp	41h			; "A"
	jp	z,A0A62
	cp	54h			; "T"
	jp	z,A0D1C
	cp	53h			; "S"
	jp	z,A08CA
	cp	55h			; "U"
	jp	z,A08CD
	cp	56h			; "V"
	jp	z,A0944
	cp	4Ch			; "L"
	jr	z,A1081
	cp	9
	jr	z,A1087
	jp	A75D7			; вывод строки "bad t-codeP"
	;
A107F:	xor	a			; false
	ret
	;
A1081:	call	A77A1
	jp	A0EEA
	;
A1087:	call	A76D5
D108A:	cp	6Ah			; "j"
	jp	z,A0FC5
	cp	64h			; "d"
	jp	z,A0E91
	cp	65h			; "e"
	jp	z,A0D91
	cp	79h			; "y"
	jp	z,A0D3A
	call	A76BB
	call	A314F
	call	A3CEB
	ld	de,T8BAB
	call	A2868
	jp	A19FB
	;
A10A4:	call	A7728
	ld	a,"-"			; вывод на экран (для ---++;)
	call	A77B0			; тест на нажатие Esc и вывод "a" на экран
	ld	a,true
	ret


A10AF:	ld	hl,(D9CF0)
	ld	(D9CF2),hl
	xor	a			; false ?
	ld	(D9CC5),a
	ld	(D99F0),a
	ld	h,a
	ld	l,a
	ld	(D9CDD),hl
	ld	de,T9A9C
	ld	hl,D9A9B
	call	A0982
	ex	de,hl
	ld	a,(D9A9B)
	cp	2
	ld	a,20h
	jr	z,A10D9
	ld	a,50h
A10D9:	ld	hl,5
	add	hl,de
	ld	(hl),a
	ld	hl,1
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9CCA),hl
	call	A77C1			; вывод строки "hl" на экран
	ld	a,9			; Tab
	call	A77B0			; тест на нажатие Esc и вывод "a" на экран
	call	A7731
	call	A76D5
	call	A76BB
	cp	9
	jr	z,A1106
	call	A073E
	ld	(D9CE3),hl
	jr	A110C
	;
A1106:	ld	hl,0
	ld	(D9CE3),hl
A110C:	call	A7731
	call	A76D5
	cp	55h			; "U"
	ld	a,1			; true ?
	jr	z,A111B
	xor	a
A111B:	ld	(D9CCC),a
	or	a
	ld	hl,1
	jr	nz,A1129
	ld	hl,3
A1129:	ld	(D9A91),hl
	call	A76D5
	cp	9
	jr	z,A113E
	ex	af,af'
	xor	a			; false
	ld	(D9CCD),a
	ex	af,af'
	call	A76BB
	jr	A1154
	;
A113E:	call	A76D5
	cp	52h			; "R"
	jr	z,A1149
	cp	45h			; "E"
	jr	nz,A1151		; плохой т-код
A1149:	ld	a,true
	ld	(D9CCD),a
	jr	A1154
	;
A1151:	call	A75D7			; вывод строки "bad t-codeP"
A1154:	call	A7728
	xor	a
	ld	(D9CC7),a
	ld	(D9CCE),a
	ld	h,a
	ld	l,a
	ld	(D9CF8),hl
	ld	hl,(table_end)		; конец таблицы идентиф.
	ld	(D9CF6),hl
	ld	a,80h
	ld	(D9CC6),a
	ld	c,15h
	ld	e,c
	xor	a
	call	A40DA
	ld	hl,0
	ld	(D9CCF),hl
	ld	hl,4
	ld	(D9A97),hl
A1184:	call	A76D5
	push	af
	ld	hl,A1266
	push	hl
	cp	24h			; "$"
	jp	z,A102C
	cp	53h			; "S"
	jp	z,A08CA
	cp	55h			; "U"
	jp	z,A08CD
	cp	56h			; "V"
	jp	z,A0944
	pop	hl
	cp	7Bh			; "{"
	jp	z,A1266
	cp	50h			; "P"
	jp	nz,A1263
	call	A77A1
	push	hl
	call	A7731
	call	A073E
	ld	(D9A99),hl
	ld	de,(D9A91)
	ld	hl,(D9CCF)
	pop	bc
	ld	(D9A93),bc
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A123F
	ld	(D9A93),bc
	ld	hl,(D9A99)
	ld	(D9A95),hl
	push	hl
	ld	de,(D9CCF)
	dec	hl
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,bc
	ld	bc,T13C4
	add	hl,bc
	add	hl,de
	ld	d,(hl)
	ld	hl,(D9CCF)
	add	hl,hl
	add	hl,hl
	ld	bc,T9CD1
	add	hl,bc
	ld	(hl),d
	inc	hl
	ld	bc,(D9A93)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	hl
	call	A0622
	push	af
	ld	hl,(D9A99)
	or	a
	jr	z,A1228
	ld	de,(D9CCF)
	ld	(D9A9D),a
	dec	hl
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,bc
	ld	bc,T13C4
	add	hl,bc
	add	hl,de
	ld	a,(hl)
	push	af
	ld	a,(D9A9D)
	call	A41FA
	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl		;1+1=2
	add	hl,hl		;2+2=4
	add	hl,bc		;4+1=5
	ld	bc,T9C79
	add	hl,bc
	pop	af
	ld	(hl),a
A1228:	ld	hl,(D9CCF)
	add	hl,hl
	add	hl,hl
	ld	bc,T9CD4
	add	hl,bc
	pop	bc
	ld	c,b
	ld	(hl),c
	ld	hl,(D9CCF)
	inc	hl
	ld	(D9CCF),hl
	ld	a,70h
	jr	A1253
	;
A123F:	ld	hl,(D9A97)
	xor	a
	ld	c,a
	inc	a			; a=true ?
	ld	(D99F0),a
	ld	(D9A95),hl
	inc	hl
	inc	hl
	ld	(D9A97),hl
	ld	a,50h
A1253:	push	bc
	ld	bc,(D9A95)
	ld	de,(D9A93)
	call	A0685
	pop	bc
	jr	A1266
	;
A1263:	call	A75D7			; вывод строки "bad t-codeP"
A1266:	call	A7728
	pop	af
	cp	7Bh
	jp	nz,A1184
	ld	a,80h
	ld	(D9CC6),a
A1274:	call	A1048			; генерация кода из т-кода ??
	or	a
	jr	nz,A1274
	;ld	hl,L752F+1		; T7530 (jr nc,..)	??
	ld	hl,L7530		; 30000
	call	A0EEA
	ld	c,15h
	ld	e,c
	xor	a
	call	A40DA
	ld	hl,(D9CF8)
	xor	a
	ld	(hl),a
	inc	hl
	ld	(hl),a
	ld	hl,(D9D02)
	ld	(D9CFC),hl
	ld	(D9CFE),hl
	inc	a
	ld	(D9CC7),a
	call	A3A5B
	call	A6131
	ld	a,0Ah			; код "вниз на строку"
	call	A77B0			; тест на нажатие Esc и вывод "a" на экран
	call	A050C
	call	A03AB
	call	A0360
	call	A38AC
	call	A734B
	jp	A06FA


A12BC:	call	A76D5
	cp	1Ah			; код конца файла
	jr	z,A1313
	ld	hl,0
	ld	(D9CCA),hl
	ld	hl,(table_end)		; конец таблицы идентиф.
	ld	(D9CF6),hl
	ld	hl,(D9D02)
	ld	(D9CFC),hl
	ld	(D9CFE),hl
	ld	hl,A130D
	push	hl
	cp	24h			; "$"
	jp	z,A102C
	cp	47h			; "G"
	jp	z,A0CFC
	cp	54h			; "T"
	jp	z,A0D1C
	cp	53h			; "S"
	jp	z,A08CA
	cp	55h			; "U"
	jp	z,A08CD
	cp	56h			; "V"
	jp	z,A0944
	cp	58h			; "X"
	jr	z,A1307
	cp	59h			; "Y"
	jp	nz,A75D7		; вывод строки "bad t-codeP"
A1307:	call	A76BB
	jp	A10AF
	;
A130D:	call	A7728
	jr	A12BC
	;
	;
A1313:	ld	hl,T139D		; "Successful complete..."
	ld	a,(warnings)		; флаг наличия предупреждений
	or	a
	jr	z,A131E			; false
	ld	hl,T138A		; "Warnings detected"
A131E:	call	A011E			; вывод строки на экран
	ld	hl,T13A7		; новая строка
	call	A7866			; записать ее в вых. файл
	ld	de,Table		; начало таблицы идентиф.
A132D:	ld	hl,(D9CF0)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,put_end		; записать "end" в конец asm-файла
	ld	a,(de)
	push	de
	cp	47h
	jr	nz,A1361
	ld	hl,5
	add	hl,de
	ld	a,(hl)
	cp	20h
	jr	z,A1361
	ld	hl,1
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,T13A9		; "extrn  имя метки"
	cp	"X"			; 58h
	jr	z,A135B
	ld	bc,T13B2		; "public  имя метки"
A135B:	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A1361:	pop	de
	ld	hl,6
	add	hl,de
	ex	de,hl
	jr	A132D
	;
	; записать "end" в конец файла
put_end:ld	bc,_end			; "	end"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	call	A02A2
	ld	a,(warnings)		; флаг наличия предупреждений
	or	a			; были ?
	jp	nz,abort1		; да, выход в ДОС
	ld	a,(D9CEA)		; флаг опции "k"
	or	a
	call	z,del_tcode		; удалить файл т-кода
	ld	b,0			; возвр. код ошибки
	jp	Exit			; Ok


T138A:	db	0Dh,0Ah,"Warnings detected...",0Dh,0Ah,0
T139D:	db	0Dh,0Ah,"Successful complete...",0Dh
T13A7:	db	0Ah,0

T13A9:	db	"Nextrn",9,"M",0	; "	extrn	имя переменной"
T13B2:	db	"Npublic",9,"M",0	; "	public	имя переменной"

_end:	db	0Ah,"Nend",0Ah,0	; "	end"


T13C3:	db	10h
T13C4:	db	7,3,1,4,2,0



A13CA:	ld	hl,(D9CFC)
	push	bc
	ld	bc,-21
	add	hl,bc
	ld	(D9CFC),hl
	push	de
	ex	de,hl
	ld	hl,(D9CF6)
	push	af
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A13E9
	ld	e,0
	ld	hl,T142B		; "tree"
	call	A7630
A13E9:	ld	hl,(D9CFC)
	inc	hl
	inc	hl
	pop	af
	ld	(hl),a
	inc	hl
	pop	de
	ld	(hl),e
	inc	hl
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	ex	de,hl
	ld	hl,2
	add	hl,sp
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	ldi
	push	de
	inc	de
	ldi
	ldi
	ldi
	ldi
	ld	de,(D9CFC)
	ldi
	ldi
	ld	a,(hl)
	pop	hl
	ld	(hl),a
	ld	hl,(D9CFC)
	ret
	;
T142B:	db	"tree",0


A1430:	ld	(D33D4),de
	ld	a,e
	and	3Fh
	ld	(D33D6),bc
	ld	c,a
	ld	b,0
	push	hl
	call	A94D9
	ld	a,l
	and	3Fh
	ld	l,a
	ld	h,0
	ld	(D33D8),hl
	ld	de,(D33D6)
	pop	hl
	call	cpshd			; знак. сравнение hl с de
	jr	c,A147A
	ex	de,hl
	ld	(D33D6),hl
	call	cpshd			; знак. сравнение hl с de
	jr	c,A147D
	ld	hl,(D33D8)
	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jr	c,A147A
	ld	a,l
	sub	c
	ld	a,h
	sbc	a,b
	jr	c,A147D
	call	A94DF
	ld	de,(D33D4)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A147D
A147A:	ld	a,true
	ret
A147D:	xor	a			; false
	ret


A147F:	ld	(D33DC),bc
A1483:	dec	de
	dec	de
	ld	a,l
	or	h
	ret	z
	ld	(D33DA),hl
	ld	l,e
	ld	h,d
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D9CF8)
	push	de
	ld	a,c
	cp	l
	jr	nz,A14D2
	ld	a,b
	cp	h
	jr	nz,A14D2
	push	de
	ld	bc,(D33DC)
	call	A94D3
A14A4:	dec	hl
	dec	hl
	ld	(D33DE),hl
	ld	a,c
	or	b
	jr	z,A14B7
	ld	a,(hl)
	inc	hl
	or	(hl)
	dec	hl
	jr	z,A14B7
	dec	bc
	jr	A14A4
	;
A14B7:	pop	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	de,(D9CF8)
	ld	hl,(D33DE)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,10
	add	hl,de
	ld	a,(hl)
	xor	1
	ld	(hl),a
	jr	A14E9
	;
A14D2:	ld	l,e
	ld	h,d
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	z,A14E9
	ld	hl,(D9CF6)
	push	hl
	ex	de,hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,12
	add	hl,bc
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
A14E9:	ld	hl,(D33DA)
	dec	hl
	pop	de
	jr	A1483


A14F1:	ld	hl,(D9CFE)
	dec	hl
	dec	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	de,(D9CFE)
	ld	(D33E0),hl
	add	hl,hl
	ld	a,e
	sub	l
	ld	e,a
	ld	a,d
	sbc	a,h
	ld	d,a
	dec	de
	dec	de
	dec	de
	dec	de
	push	de
	ld	de,(D9CFE)
	ld	hl,(D33E0)
	push	hl
	add	hl,hl
	ld	a,e
	sub	l
	ld	l,a
	ld	a,d
	sbc	a,h
	ld	h,a
	dec	hl
	dec	hl
	dec	hl
	dec	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D9CFE)
	dec	hl
	dec	hl
	ex	de,hl
	pop	hl
	call	A147F
	pop	bc
	ret


A152F:	ld	hl,(D9CFE)
	dec	hl
	dec	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D9CFE)
	dec	hl
	dec	hl
	push	hl
	ld	hl,(D9CFE)
	ex	de,hl
	ld	l,c
	ld	h,b
	add	hl,hl
	ld	a,e
	sub	l
	ld	e,a
	ld	a,d
	sbc	a,h
	ld	d,a
	dec	de
	dec	de
	dec	de
	dec	de
	push	de
	ld	hl,(D9CFE)
	ex	de,hl
	ld	l,c
	ld	h,b
	add	hl,hl
	ld	a,e
	sub	l
	ld	l,a
	ld	a,d
	sbc	a,h
	ld	h,a
	dec	hl
	dec	hl
	dec	hl
	dec	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	pop	de
	call	A147F
	pop	bc
	ret


A156A:	ld	(D33E2),hl
	call	A3CEB
	push	hl
A1571:	ld	a,l
	or	h
	jr	z,A1589
	push	hl
	call	A3CEB
	ex	de,hl
	ld	hl,(D33E2)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	(D33E2),hl
	pop	hl
	dec	hl
	jr	A1571
A1589:	pop	hl
	ret


A158B:	ld	c,e
	ld	b,d
	ex	de,hl
	ld	l,c
	ld	h,b
	add	hl,hl
	add	hl,de
	ld	(D33E4),hl
A1595:	ld	a,c
	or	b
	ret	z
	ld	hl,(D33E4)
	dec	hl
	dec	hl
	ld	(D33E4),hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	bc
	call	A3CD2
	pop	bc
	dec	bc
	jr	A1595


A15AD:	ld	hl,T3358
	call	A156A
	push	hl
	ld	hl,T3394
	call	A156A
	push	hl
	call	A3CEB
	call	A3D0A
	call	A3CEB
	pop	de
	add	hl,de
	push	hl
	ld	hl,T3394
	call	A158B
	pop	hl
	call	A3CD2
	pop	de
	ld	hl,T3358
	push	de
	call	A158B
	pop	hl
	jp	A3CD2


A15DD:	ld	hl,T3358
	call	A156A
	push	hl
	ld	hl,T3394
	call	A156A
	ld	(D33E6),hl
	pop	hl
	push	hl
	add	hl,hl
	ld	bc,T3358
	add	hl,bc
	call	A156A
	pop	de
	add	hl,de
	push	hl
	call	A3CEB
	call	A3D0A
	ld	de,(D33E6)
	ld	hl,T3394
	push	de
	call	A158B
	pop	hl
	call	A3CD2
	pop	de
	ld	hl,T3358
	push	de
	call	A158B
	pop	hl
	jp	A3CD2


A161B:	ld	hl,T3394
	call	A156A
	ld	(D33E8),hl
	ld	hl,T3358
	call	A156A
	push	hl
	ld	de,(D33E8)
	ld	hl,T3394
	push	de
	call	A158B
	pop	hl
	call	A3CD2
	pop	de
	ld	hl,T3358
	push	de
	call	A158B
	pop	hl
	jp	A3CD2


A1646:	ld	(D33EA),hl
	ld	hl,10
	add	hl,de
	ld	(D33EC),de
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D33EA)
	push	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	call	A3D48
	ld	(D33EE),a
	pop	hl
	push	hl
	ld	bc,10
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	ld	hl,(D33EC)
	ex	de,hl
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	pop	de
	call	A3D48
	ld	(D33EF),a
	pop	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	4
	pop	de
	ld	hl,D33EE
	ld	c,(hl)
	ld	hl,(D33EF)
	or	a
	jr	nz,A16C4
	push	hl
	ld	hl,2
	add	hl,de
	bit	2,(hl)
	pop	hl
	jr	nz,A16C7
	inc	c
	dec	c
	jr	nz,A16A0
	inc	l
	dec	l
	jr	nz,A16C4
A16A0:	push	hl
	ld	hl,10
	add	hl,de
	inc	hl
	bit	5,(hl)
	pop	hl
	jr	nz,A16C7
	push	hl
	ld	hl,(D33EA)
	ld	bc,11
	add	hl,bc
	bit	5,(hl)
	pop	hl
	jr	z,A16C7
	ld	a,(D33EE)
	ld	c,a
	inc	c
	dec	c
	jr	z,A16C4
	inc	l
	dec	l
	jr	z,A16C7
A16C4:	ld	a,true
	ret
A16C7:	xor	a			; false
	ret


A16C9:	ld	(D33F2),de
	ld	(D33F0),hl
	ld	de,0
A16D3:	ld	a,e
	sub	c
	ld	a,d
	sbc	a,b
	jr	nc,A170F
	ld	l,e
	ld	h,d
	add	hl,hl
	ld	(D33F6),de
	push	bc
	push	de
	ld	de,(D33F2)
	add	hl,de
	ld	(D33F4),bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D33F6)
	ex	de,hl
	ld	bc,(D33F4)
	ld	a,c
	sub	e
	ld	l,a
	ld	a,b
	sbc	a,d
	ld	h,a
	add	hl,hl
	ld	de,(D33F0)
	add	hl,de
	dec	hl
	dec	hl
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	de
	inc	de
	pop	bc
	jr	A16D3
	;
A170F:	ld	de,0
	ld	(D33F6),de
A1716:	ld	a,e
	sub	c
	ld	a,d
	sbc	a,b
	ret	nc
	ld	hl,1
	add	hl,de
	push	de
A1720:	ld	a,l
	sub	c
	ld	a,h
	sbc	a,b
	jr	nc,A1784
	ld	(D33F8),hl
	push	bc
	push	hl
	ld	hl,(D33F6)
	push	hl
	add	hl,hl
	ld	de,(D33F0)
	add	hl,de
	ld	(D33F0),de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	ld	hl,(D33F8)
	add	hl,hl
	ld	de,(D33F0)
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D33F0),de
	pop	de
	call	A1646
	pop	hl
	ld	bc,(D33F0)
	or	a
	jr	z,A177E
	ld	(D33F6),hl
	add	hl,hl
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D33F8)
	push	de
	push	hl
	add	hl,hl
	add	hl,bc
	ld	e,c
	ld	d,b
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D33F6)
	add	hl,hl
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	hl
	add	hl,hl
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
A177E:	pop	hl
	inc	hl
	pop	bc
	jr	A1720
	;
A1784:	pop	de
	inc	de
	ld	(D33F6),de
	jr	A1716


A178D:	push	hl
	push	de
	push	bc
	push	bc
	push	bc
	push	bc
	push	de
	call	A3CC1
	pop	bc
	ld	hl,10
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,2
	add	hl,sp
	call	A16C9
	ld	hl,0
	pop	de
	push	hl
	ld	c,15h
	ld	hl,0
A17B0:	push	hl
	ld	hl,10
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	ld	a,l
	sub	e
	ld	a,h
	sbc	a,d
	jr	nc,A1816
	push	hl
	add	hl,hl
	ex	de,hl
	ld	hl,4
	add	hl,sp
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,14
	add	hl,de
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	z,A1811
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	cp	15h
	jr	nz,A17E2
	dec	hl
	bit	4,(hl)
	jr	z,A1811
A17E2:	push	de
	ld	a,c
	cp	15h
	jr	z,A1804
	and	3Fh
	cp	20h
	jr	nc,A1804
	ld	e,15h
	ld	a,56h
	push	bc
	call	A40DA
	pop	bc
	ld	l,c
	ld	h,0
	call	A3CD2
	call	A94D9
	inc	hl
	call	A94AE
A1804:	pop	de
	ld	l,e
	ld	h,d
	push	de
	call	A19FB
	pop	de
	ld	hl,3
	add	hl,de
	ld	c,(hl)
A1811:	pop	hl
	inc	hl
	jr	A17B0
	;
A1816:	push	de
	call	A94DF
	pop	de
	ld	a,l
	or	h
	jr	z,A1835
	push	hl
	call	A3CEB
	ld	e,l
	ld	c,15h
	ld	a,57h
	call	A40DA
	pop	hl
	dec	hl
	push	de
	call	A94B4
	pop	de
	jr	A1816
A1835:	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret


A183C:	ld	hl,4
	add	hl,de
	ld	(D33FA),a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	hl
	ld	hl,6
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D33FB),hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	and	3
	ld	e,a
	ld	a,(D33FA)
	and	3
	pop	hl
	or	a
	jr	z,A1875
	cp	1
	jr	z,A1882
	cp	2
	jr	z,A188B
	ld	hl,T1893
	call	A75DA			; вывод строки "hl" (большие буквы зарез.)
	ld	a,10h
	ret
A1875:	ld	(D33D0),hl
	ld	hl,(D33FB)
	ld	(D33D2),hl
	ld	a,10h
	or	e
	ret
A1882:	ld	l,h
A188B:	ld	h,0
	jp	A19ED
	;
T1893:	db	"?dvhlP",0		; "?dvhl<рег.пара>"  имя библ. функции


A189A:	ld	(D33FD),a
	ld	a,e
	and	0C0h
	ld	(D33FE),a
	ld	a,e
	ret	z
	and	3Fh
	ld	(D33FF),a
	and	0FEh
	ld	(D3400),a
	ld	a,(D33FD)
	and	3
	or	a
	jr	z,A18CB
	cp	1
	jr	z,A18CD
	cp	2
	jr	z,A18DA
	ld	a,(D3400)
	cp	6
	jr	nz,A18C8
	ld	a,4
A18C8:	or	0C0h
	ret
A18CB:	ld	a,e
	ret
A18CD:	ld	a,(D3400)
	cp	6
	jr	nz,A18D7
	ld	a,(D33FF)
A18D7:	or	80h
	ret
A18DA:	ld	a,(D33FE)
	cp	40h
	jr	nz,A18E3
	ld	a,e
	ret
A18E3:	ld	a,(D3400)
	cp	6
	jr	nz,A18EF
	ld	a,(D33FF)
	jr	A18F0
A18EF:	inc	a
A18F0:	or	40h
	ret


A18F3:	ld	l,e
	ld	e,c
	ld	d,b
	cp	2Ch
	jr	z,A1968
	cp	2Dh
	jr	z,A1968
	cp	2Eh
	jr	z,A1968
	cp	2Fh
	jr	z,A1968
	cp	8
	jr	z,A196C
	cp	9
	jr	z,A196C
	cp	0Ah
	jr	z,A196C
	cp	0Bh
	jr	z,A196C
	cp	0Ch
	jr	z,A1974
	cp	0Dh
	jr	z,A1974
	cp	0Eh
	jr	z,A1974
	cp	0Fh
	jr	z,A1974
	cp	18h
	jp	z,A183C
	cp	19h
	jp	z,A183C
	cp	1Ah
	jp	z,A183C
	cp	1Ch
	jr	z,A197E
	cp	1Dh
	jr	z,A197E
	cp	1Eh
	jr	z,A197E
	cp	1Fh
	jr	z,A1985
	cp	20h
	jr	z,A1996
	cp	21h
	jr	z,A19AA
	cp	22h
	jr	z,A19B9
	cp	24h
	jr	z,A19CB
	cp	27h
	jr	z,A19E1
	cp	26h
	jr	z,A19EA
	cp	23h
	jr	z,A19F3
	ret
	;
A1968:	ld	e,l
	jp	A189A
	;
A196C:	ld	hl,3
	add	hl,de
	ld	e,(hl)
	jp	A189A
	;
A1974:	call	A94DF
	inc	hl
	inc	hl
	inc	hl
	ld	e,(hl)
	jp	A189A
	;
A197E:	call	A94DF
	ex	de,hl
	jp	A183C
	;
A1985:	ld	hl,4
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A7670
	jr	A19ED
	;
A1996:	call	A94DF
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	call	A7670
	jr	A19ED
	;
A19AA:	ld	hl,4
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	jr	A19ED
	;
A19B9:	call	A94DF
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	dec	hl
	jr	A19ED
	;
A19CB:	call	A94DF
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,0
	or	a
	sbc	hl,de
	jr	A19ED
	;
A19E1:	ld	hl,0
	jr	A19ED
	;
A19EA:	ld	hl,1
A19ED:	ld	(D33D0),hl
	ld	a,10h
	ret
A19F3:	ld	hl,3
	add	hl,de
	ld	a,(hl)
	xor	1
	ret


A19FB:	push	hl
	push	bc
	push	bc
	push	bc
	call	A94D3
	push	hl
	call	A3CC1
	pop	de
	ld	hl,14
	add	hl,de
	ld	a,(hl)
	inc	hl
	or	(hl)
	jp	z,A1C5B
	ld	hl,2
	add	hl,de
	bit	3,(hl)
	jr	z,A1A27
	ld	hl,A1C5B
	push	hl
	ld	hl,14
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ex	de,hl
	ret
A1A27:	ld	hl,14
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	ld	a,(bc)
	and	8
	push	de
	jr	z,A1A46
	ld	hl,16
	add	hl,de
	ld	c,e
	ld	b,d
	ld	e,(hl)
	ld	d,0
	ld	hl,17
	add	hl,bc
	call	A178D
A1A46:	pop	bc
	ld	hl,14
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,9
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	pop	de
	push	hl
A1A58:	ld	a,(hl)
	inc	a
	jp	z,A1C5B
	ld	a,(hl)
	and	1
	push	hl
	ld	l,a
	ld	h,0
	add	hl,hl
	push	hl
	ld	hl,10
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	add	hl,de
	ld	bc,17
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	ld	a,(hl)
	and	0FEh
	cp	80h
	jr	z,A1AB2
	cp	82h
	jr	z,A1AB9
	cp	86h
	jr	z,A1ADE
	cp	88h
	jr	z,A1AE4
	cp	8Ah
	jr	z,A1AEA
	cp	8Ch
	jr	z,A1AF0
	cp	8Eh
	jr	z,A1B0B
	cp	90h
	jr	z,A1B11
	cp	98h
	jr	z,A1B17
	cp	9Ah
	jr	z,A1B17
	cp	9Ch
	jr	z,A1B17
	cp	9Eh
	jr	z,A1B17
	cp	0A0h
	jp	z,A1B71
	jp	A1B80
	;
A1AB2:	ex	de,hl
	call	A19FB
	jp	A1C55
	;
A1AB9:	ld	hl,3
	add	hl,de
	ld	a,(hl)
	and	3Fh
	cp	6
	jp	nz,A1C55
	ld	bc,0
	push	bc
	ld	c,1
	push	bc
	ld	c,10h
	push	bc
	ld	c,0C4h
	ld	e,c
	ld	a,2
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	jp	A1C55
	;
A1ADE:	call	A15AD
	jp	A1C55
	;
A1AE4:	call	A15DD
	jp	A1C55
	;
A1AEA:	call	A161B
	jp	A1C55
	;
A1AF0:	ld	hl,0
	call	A3CD2
	ld	hl,1
	call	A3CD2
	ld	hl,(D9CF6)
	call	A3CD2
	ld	hl,1
	call	A3CD2
	jp	A1C55
	;
A1B0B:	call	A14F1
	jp	A1C55
	;
A1B11:	call	A152F
	jp	A1C55
	;
A1B17:	push	de
	call	A94B4
	call	A94AE
	pop	de
	ld	hl,2
	add	hl,de
	bit	5,(hl)
	jr	nz,A1B2D
	ld	hl,0
	jr	A1B50
	;
A1B2D:	ld	hl,3
	add	hl,de
	ld	a,(hl)
	cp	15h
	jr	z,A1B3C
	ld	hl,1
	jr	A1B50
	;
A1B3C:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	and	3
	cp	3
	ld	hl,2
	jr	nz,A1B50
	ld	hl,3
A1B50:	push	hl
	call	A94DF
	ld	a,(hl)
	and	7
	add	a,a
	add	a,a
	pop	hl
	add	a,l
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,T7893
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	dec	bc
	ld	hl,0
	add	hl,sp
	ld	(hl),c
	inc	hl
	ld	(hl),b
	jp	A1C55
	;
A1B71:	call	A94DF
	ld	c,l
	ld	b,h
	ld	hl,0
	add	hl,sp
	ld	(hl),c
	inc	hl
	ld	(hl),b
	jp	A1C55
	;
A1B80:	pop	de
	push	hl
	push	hl
	ld	hl,0
	ld	(D33D0),hl
	ld	(D33D2),hl
	ld	hl,8
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,19
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	de
	push	bc
	ld	hl,17
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,3
	add	hl,de
	ld	e,(hl)
	ld	hl,8
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,1
	add	hl,bc
	ld	a,(hl)
	ld	hl,8
	add	hl,sp
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	bc
	call	A18F3
	pop	bc
	pop	de
	ld	hl,19
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	de
	push	bc
	ld	hl,17
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,3
	add	hl,de
	ld	e,(hl)
	ld	hl,8
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,2
	add	hl,bc
	push	hl
	ld	hl,14
	add	hl,sp
	ld	(hl),a
	pop	hl
	ld	a,(hl)
	ld	hl,8
	add	hl,sp
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	bc
	call	A18F3
	pop	bc
	pop	de
	ld	hl,19
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,17
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
A1C08:	ld	hl,3
	add	hl,de
	ld	e,(hl)
	ld	hl,6
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,3
	add	hl,bc
	push	hl
	ld	hl,13
	add	hl,sp
	ld	(hl),a
	pop	hl
	ld	a,(hl)
	ld	hl,6
	add	hl,sp
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	bc
	call	A18F3
	pop	bc
	ld	hl,(D33D2)
	push	hl
	ld	hl,(D33D0)
	push	hl
	ld	c,a
	push	bc
	ld	hl,13
	add	hl,sp
	ld	c,(hl)
	push	bc
	ld	hl,14
	add	hl,sp
	ld	e,(hl)
	ld	hl,10
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a,(bc)
	pop	bc
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	pop	hl
	inc	hl
	inc	hl
	inc	hl
	ex	(sp),hl
A1C55:	pop	hl
	inc	hl
	push	hl
	jp	A1A58
A1C5B:	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret


A1C60:	ld	(D3401),hl
	ex	de,hl
	ld	(D3403),hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,0
A1C6D:	call	cpshd			; знак. сравнение hl с de
	jr	nc,A1C9B
	ld	(D3405),hl
	push	de
	ld	hl,(D3401)
	ex	de,hl
	push	de
	ld	hl,(D3405)
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,bc
	ld	de,(D3403)
	add	hl,de
	inc	hl
	inc	hl
	pop	de
	call	A1F4B
	pop	de
	or	a
	jr	nz,A1C98
	ld	hl,(D3405)
	inc	hl
	jr	A1C6D
A1C98:	ld	a,true
	ret
A1C9B:	xor	a			; false
	ret


A1C9D:	ld	hl,D3408
	ld	(hl),e
	ld	(D3407),a
	push	af
	and	0E0h
	ld	c,a
	ld	a,e
	and	0E0h
	ld	l,a
	pop	af
	and	3
	ld	(D3409),a
	ld	a,e
	and	3
	ld	e,a
	ld	a,c
	cp	0E0h
	jr	nz,A1CC4
	ld	a,l
	cp	20h
	jr	z,A1CC4
	cp	60h
	jr	nz,A1CCB
A1CC4:	ld	a,c
	cp	l
	jr	z,A1CCB
	xor	a
	ret
A1CCB:	ld	a,(D3407)
	and	10h
	jr	z,A1CDB
	ld	a,(D3408)
	and	10h
	jr	z,A1CDB
	xor	a
	ret
A1CDB:	ld	a,(D334D)
	or	a
	jr	z,A1CF1
	ld	a,(D3408)
	and	4
	ld	b,a
	ld	a,(D3407)
	and	4
	cp	b
	jr	z,A1CF1
	xor	a
	ret
A1CF1:	ld	a,(D3409)
	cp	1
	jr	z,A1D14
	or	a
	jr	nz,A1CFF
	inc	e
	dec	e
	jr	z,A1D14
A1CFF:	cp	2
	jr	nz,A1D08
	ld	a,e
	cp	3
	jr	nz,A1D14
A1D08:	ld	a,(D3409)
	cp	3
	jr	nz,A1D17
	ld	a,e
	cp	3
	jr	nz,A1D17
A1D14:	ld	a,true
	ret
A1D17:	xor	a			; false
	ret


A1D19:	ld	l,a
	ld	a,c
	and	0EFh
	cp	2
	jr	z,A1D4A
	cp	3
	jr	z,A1D52
	cp	4
	jr	z,A1D5A
	cp	0Fh
	jr	z,A1D67
	cp	5
	jr	z,A1D6F
	cp	8
	jr	z,A1D80
	cp	0Eh
	jr	z,A1D8D
	cp	6
	jr	z,A1D9A
	ld	a,c
	ld	hl,2
	add	hl,sp
	cp	(hl)
	jr	nz,A1D48
	ld	a,true
	ret
A1D48:	xor	a			; false
	ret
	;
A1D4A:	ld	a,l
	cp	80h
	jr	nz,A1D48		; false
	ld	a,true
	ret
	;
A1D52:	ld	a,l
	cp	40h
	jr	nz,A1D48		; false
	ld	a,true
	ret
	;
A1D5A:	ld	a,l
	cp	0C0h
	jr	nz,A1D48		; false
	ld	a,e
	cp	6
	jr	z,A1D48
	ld	a,true
	ret
	;
A1D67:	ld	a,l
	cp	0C0h
	jr	nz,A1D48		; false
	ld	a,true
	ret
	;
A1D6F:	ld	a,l
	cp	0C0h
	jr	nz,A1D48		; false
	ld	a,e
	cp	4
	jr	z,A1D48
	cp	6
	jr	z,A1D48
	ld	a,true
	ret
	;
A1D80:	ld	a,l
	cp	40h
	jr	nz,A1D48		; false
	ld	a,e
	cp	7
	jr	z,A1D48
	ld	a,true
	ret
	;
A1D8D:	ld	a,l
	cp	80h
	jr	nz,A1D48		; false
	ld	a,e
	cp	7
	jr	z,A1D48
	ld	a,true
	ret
	;
A1D9A:	ld	a,e
	cp	8
	jr	c,A1D48			; false
	cp	10h
	jr	nc,A1D48
	ld	a,true
	ret


A1DA6:	ld	c,e
	ld	hl,D340A
	ld	(hl),c
	ld	hl,(D3352)
	inc	hl
	inc	hl
	inc	hl
	ld	l,(hl)
	ex	af,af'
	ld	a,l
	ld	(D340C),a
	ex	af,af'
	push	af
	ld	a,c
	and	0C0h
	ld	l,a
	ld	(D340B),a
	ld	a,c
	and	3Fh
	ld	e,a
	pop	hl
	ld	l,h
	ld	a,l
	and	10h
	jr	z,A1DD6
	ld	a,e
	cp	10h
	jr	nc,A1DD4
	cp	6
	jr	nz,A1DD6
A1DD4:	xor	a
	ret
A1DD6:	ld	a,l
	and	0EFh
	cp	1
	jr	z,A1E01
	cp	7
	jr	z,A1E04
	cp	9
	jr	z,A1E0E
	cp	0Ah
	jr	z,A1E25
	cp	0Bh
	jr	z,A1E46
	cp	0Ch
	jr	z,A1E64
	cp	0Dh
	jp	z,A1E84
	push	bc
	ld	c,l
	ld	a,(D340B)
	call	A1D19
	pop	bc
	ret
A1E01:	ld	a,true
	ret
	;
A1E04:	ld	a,c
	cp	15h
	jr	nz,A1E0C
	ld	a,true
	ret
A1E0C:	xor	a			; false
	ret
	;
A1E0E:	ld	hl,(D340B)
	ld	a,l
	cp	40h
	jr	nz,A1E0C
	ld	a,e
	and	0FEh
	cp	4
	jr	z,A1E0C
	ld	a,e
	cp	6
	jr	z,A1E0C
	ld	a,true
	ret
	;
A1E25:	ld	a,(D340B)
	cp	0C0h
	jr	nz,A1E0C
	ld	a,(D340C)
	call	A3D16
	push	hl
	ld	a,(D340A)
	call	A3D16
	pop	de
	ld	a,e
	and	l
	ld	l,a
	ld	a,d
	and	h
	ld	h,a
	or	l
	jr	nz,A1E0C
	ld	a,true
	ret
	;
A1E46:	ld	a,(D340B)
	cp	0C0h
	jr	nz,A1E0C
	ld	a,e
	call	A41FA
	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl		;1+1=2
	add	hl,hl		;2+2=4
	add	hl,bc		;4+1=5
	ld	bc,T9C77
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,A1E0C
	ld	a,true
	ret
	;
A1E64:	ld	a,(D340B)
	cp	40h
	jr	nz,A1E82		; false
	ld	a,e
	call	A41FA
	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl		;1+1=2
	add	hl,hl		;2+2=4
	add	hl,bc		;4+1=5
	ld	bc,T9C77
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	nz,A1E82
	ld	a,true
	ret
A1E82:	xor	a			; false
	ret
	;
A1E84:	ld	a,(D340C)
	cp	c
	jr	nz,A1E82		; false
	ld	a,true
	ret


A1E8D:	push	af
	and	0Fh
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,T787F		; знаковые константы
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	l,c
	ld	h,b
	pop	af
	and	0F0h
	or	a
	jr	z,A1ECD
	cp	10h
	jr	z,A1ED0
	cp	20h
	jr	z,A1EDD
	cp	30h
	jr	z,A1EE7
	cp	40h
	jr	z,A1EEE
	cp	50h
	jr	z,A1EFC
	cp	90h
	jr	z,A1F0A
	cp	80h
	jr	z,A1F18
	cp	60h
	jr	z,A1F28
	cp	70h
	jr	z,A1F37
	ld	hl,T1F46
	jp	A75DA			; вывод строки "hl" (большие буквы зарез.)
	;
A1ECD:	ld	a,true
	ret
	;
A1ED0:	ld	a,e
	cp	l
	jr	nz,A1EDB
	ld	a,d
	cp	h
	jr	nz,A1EDB
	ld	a,true
	ret
A1EDB:	xor	a			; false
	ret
	;
A1EDD:	ld	a,e
	cp	l
	jr	nz,A1ECD		; true
	ld	a,d
	cp	h
	jr	nz,A1ECD
	xor	a
	ret
	;
A1EE7:	or	a
	sbc	hl,de
	jr	nc,A1ECD		; true
	xor	a
	ret
	;
A1EEE:	ld	c,e
	ld	b,0
	ld	a,c
	cp	l
	jr	nz,A1EDB		; false
	ld	a,b
	cp	h
	jr	nz,A1EDB
	ld	a,true
	ret
	;
A1EFC:	ld	c,d
	ld	b,0
	ld	a,c
	cp	l
	jr	nz,A1EDB		; false
	ld	a,b
	cp	h
	jr	nz,A1EDB
	ld	a,true
	ret
	;
A1F0A:	ex	de,hl
	call	A7685
	ld	a,l
	dec	a
	or	h
	jr	nz,A1F16
	ld	a,true
	ret
A1F16:	xor	a			; false
	ret
	;
A1F18:	ex	de,hl
	call	A7685
	ex	de,hl
	ld	hl,3
	call	cpshd			; знак. сравнение hl с de
	jr	c,A1F16			; false
	ld	a,true
	ret
	;
A1F28:	ex	de,hl
	call	A64E6
	ld	de,5
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A1F16		; false
	ld	a,true
	ret
	;
A1F37:	ex	de,hl
	call	A9461
	ld	a,l
	sub	3
	ld	a,h
	sbc	a,0
	jr	nc,A1F16		; false
	ld	a,true
	ret
	;
T1F46:	db	"?vmP",0		; "?vm<рег.пара>"  имя библ. функции


A1F4B:	push	hl
	ld	a,(hl)
	cp	8
	jr	nz,A1F5B
	ex	de,hl
	ld	de,T8BD8
	call	A1C60
	jr	A1FCA
	;
A1F5B:	cp	9
	jr	nz,A1F69
	ex	de,hl
	ld	de,T8BE3
	call	A1C60
	jr	A1FCA
	;
A1F69:	push	de
	call	A94B4
	pop	de
	ld	hl,2
	add	hl,de
	push	de
	ld	e,(hl)
	push	de
	call	A94D9
	pop	de
	ld	a,(hl)
	push	hl
	call	A1C9D
	pop	hl
	pop	bc
	or	a
	jr	z,A1FC9
	push	de
	call	A94B4
	pop	de
	push	bc
	push	hl
	ld	hl,3
	add	hl,bc
	ld	e,(hl)
	push	de
	call	A94D3
	pop	de
	inc	hl
	ld	a,(hl)
	call	A1DA6
	pop	de
	pop	bc
	or	a
	jr	z,A1FC9
	ld	a,(de)
	and	20h
	jr	z,A1FB0
	ld	hl,8
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A1FB8
	;
A1FB0:	ld	hl,4
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
A1FB8:	push	hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	de
	call	A1E8D
	or	a
	jr	z,A1FC9
	ld	a,1			; true ?
	jr	A1FCA
	;
A1FC9:	xor	a			; false ?
A1FCA:	pop	bc
	ret


A1FCC:	ld	(D340D),hl
	ld	hl,0
	ld	(D340F),hl
A1FD5:	ld	de,(D334A)
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A2001
	push	hl
	add	hl,hl
	ld	bc,D3352
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	inc	hl
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,bc
	ld	bc,(D340D)
	add	hl,bc
	call	A1F4B
	or	a
	ret	z			; false ?
	ld	hl,(D340F)
	inc	hl
	ld	(D340F),hl
	jr	A1FD5
	;
A2001:	ld	a,1			; true ?
	ret


A2004:	call	A3CEB
	push	hl
	call	A3CEB
	ex	(sp),hl
	call	A3CD2
	pop	hl
	jp	A3CD2


A2013:	cp	66h			; "f"
	jr	nz,A2020
	ld	a,e
	cp	51h			; "Q"
	jr	z,A203D
	cp	48h			; "H"
	jr	A203B
	;
A2020:	cp	6Ch			; "l"
	jr	nz,A202C
	cp	57h			; "W"
	jr	z,A203D
	cp	5Ah			; "Z"
	jr	A203B
	;
A202C:	cp	77h			; "w"
	jr	nz,A2042
	ld	a,e
	cp	4Eh			; "N"
	jr	z,A203D
	cp	52h			; "R"
	jr	z,A203D
	cp	49h			; "I"
A203B:	jr	nz,A2040
A203D:	ld	a,true
	ret
A2040:	xor	a			; false
	ret
	;
A2042:	cp	75h			; "u"
	jr	nz,A204F
	ld	a,e
	cp	4Eh			; "N"
	jr	z,A203D
	cp	52h			; "R"
	jr	A203B
	;
A204F:	cp	62h			; "b"
	jr	nz,A205C
	ld	a,e
	cp	43h			; "C"
	jr	z,A203D			; true
	cp	42h			; "B"
	jr	A203B
	;
A205C:	cp	e
	jr	z,A203D			; true
	xor	a
	ret


A2061:	ld	d,a
	ld	hl,T7941
A2065:	ld	a,(hl)
	or	a
	jp	z,A75D7			; вывод строки "bad t-codeP"
	push	de
	ld	e,d
	ld	a,(hl)
	push	hl
	call	A2013
	pop	hl
	pop	de
	or	a
	jr	z,A2080			; false
	push	hl
	inc	hl
	ld	a,(hl)
	call	A2013
	pop	hl
	or	a
	ret	nz			; true
A2080:	ld	bc,8
	add	hl,bc
	jr	A2065


A2087:	ex	de,hl
	ld	e,c
	ld	d,b
	or	a
	jr	z,A210A
	dec	a
	jr	z,A210C
	dec	a
	jp	z,mul_hlde		; hl*de=hl
	dec	a
	jp	z,A9446
	dec	a
	jp	z,div_hlde		; hl/de=hl
	dec	a
	jr	z,A2110
	dec	a
	jr	z,A2115
	dec	a
	jr	z,A211A
	dec	a
	jr	z,A2121
	dec	a
	jr	z,A2128
	dec	a
	jr	z,A20D3
	dec	a
	jr	z,A20D3
	dec	a
	jr	z,A20D7
	dec	a
	jr	z,A20DB
	dec	a
	jr	z,A20DC
	dec	a
	jr	z,A20E3
	dec	a
	jr	z,A20F0
	dec	a
	jr	z,A20F9
	dec	a
	jr	z,A2102
	ld	hl,T212F
	jp	A75DA			; вывод строки "hl" (большие буквы зарез.)
	;
A20D3:	ld	b,e
	jp	A942E			; сдвиг "hl" вправо (деление на 2), счетчик "b"
	;
A20D7:	ld	b,e
	jp	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	;
A20DB:	dec	hl
A20DC:	ld	a,l
	cpl
	ld	l,a
	ld	a,h
	cpl
	ld	h,a
	ret
	;
A20E3:	or	a
	sbc	hl,de
	jr	nz,A20EC
	ld	hl,true
	ret
A20EC:	ld	hl,false
	ret
	;
A20F0:	call	cpshd			; знак. сравнение hl с de
	jr	nc,A20EC		; false
	ld	hl,true
	ret
	;
A20F9:	or	a
	sbc	hl,de
	jr	nc,A20EC		; false
	ld	hl,true
	ret
	;
A2102:	ld	a,l
	or	h
	jr	nz,A20EC		; false
	ld	hl,true
	ret
	;
A210A:	add	hl,de
	ret
	;
A210C:	or	a
	sbc	hl,de
	ret
	;
A2110:	call	A9446
	ex	de,hl
	ret
	;
A2115:	call	div_hlde		; hl/de=hl
	ex	de,hl
	ret
	;
A211A:	ld	a,l
	and	e
	ld	l,a
	ld	a,h
	and	d
	ld	h,a
	ret
	;
A2121:	ld	a,l
	or	e
	ld	l,a
	ld	a,h
	or	d
	ld	h,a
	ret
	;
A2128:	ld	a,l
	xor	e
	ld	l,a
	ld	a,h
	xor	d
	ld	h,a
	ret


T212F:	db	"?ceP",0		; "?ce<рег.пара>"  имя библ. функции


A2134:	ld	hl,D3419
	ld	(hl),c
	ex	de,hl
	ld	(D3417),hl
	ld	hl,0
	ld	(D341A),hl
	ld	(D341C),hl
	or	a
	jr	z,A21AA
	ld	bc,(D334A)
	ld	de,D3352
	ld	hl,T3411
	call	A16C9
	ld	hl,(D334A)
A2159:	dec	hl
	inc	h
	dec	h
	jp	m,A21AA
	push	hl
	add	hl,hl
	ld	bc,T3411
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,12
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	bc
	push	de
	ld	de,(D341C)
	ld	hl,3
	add	hl,bc
	ld	a,(hl)
	call	A3D48
	or	a
	jr	z,A2185
	ld	hl,2
	jr	A2188
	;
A2185:	ld	hl,0
A2188:	pop	de
	add	hl,de
	ld	de,(D341A)
	add	hl,de
	ld	(D341A),hl
	pop	bc
	ld	hl,10
	add	hl,bc
	ld	de,(D341C)
	ld	a,e
	or	(hl)
	ld	c,a
	inc	hl
	ld	a,d
	or	(hl)
	ld	b,a
	ld	(D341C),bc
	pop	hl
	jr	A2159
	;
A21AA:	ld	hl,(D3417)
	ex	de,hl
	ld	a,(de)
	inc	a
	jp	z,A23C2
	ld	a,(de)
	and	1
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,D3352
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a,(de)
	and	0FEh
	cp	80h
	jr	z,A2207
	cp	86h
	jp	z,A23B8
	cp	88h
	jp	z,A23B8
	cp	8Ah
	jp	z,A23B8
	cp	8Ch
	jp	z,A23B8
	cp	8Eh
	jp	z,A23B8
	cp	90h
	jp	z,A23B8
	cp	82h
	jr	z,A222D
	cp	98h
	jr	z,A2243
	cp	9Ah
	jr	z,A2243
	cp	9Ch
	jr	z,A2243
	cp	9Eh
	jr	z,A2243
	cp	0A0h
	jp	z,A2290
	jp	A2299
	;
A2207:	ld	hl,12
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	de,(D341A)
	add	hl,de
	ld	(D341A),hl
	ld	hl,10
	add	hl,bc
	ld	de,(D341C)
	ld	a,e
	or	(hl)
	ld	c,a
	inc	hl
	ld	a,d
	or	(hl)
	ld	b,a
	ld	(D341C),bc
	jp	A23B8
	;
A222D:	ld	hl,3
	add	hl,bc
	ld	a,(hl)
	and	3Fh
	cp	6
	jp	nz,A23B8
	ld	hl,(D341A)
	inc	hl
	ld	(D341A),hl
	jp	A23B8
	;
A2243:	ld	(D3423),de
	ld	hl,2
	add	hl,bc
	bit	5,(hl)
	jr	nz,A2254
	ld	hl,0
	jr	A2275
	;
A2254:	ld	hl,3
	add	hl,bc
	ld	a,(hl)
	cp	15h
	jr	z,A2262
	ld	hl,1
	jr	A2275
	;
A2262:	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	and	3
	cp	3
	ld	hl,2
	jr	nz,A2275
	ld	hl,3
A2275:	ld	a,(de)
	and	7
	add	a,a
	add	a,a
	add	a,l
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,T7893
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	dec	bc
	ld	e,c
	ld	d,b
	ex	de,hl
	ld	(D3417),hl
	jp	A23B8
	;
A2290:	ld	hl,(D3423)
	ld	(D3417),hl
	jp	A23B8
	;
A2299:	ld	hl,0
	ld	(D33D0),hl
	ld	hl,(D3354)
	push	de
	push	hl
	ld	c,e
	ld	b,d
	ld	a,(D3419)
	ld	e,a
	ld	hl,1
	add	hl,bc
	ld	(D3419),a
	ld	a,(hl)
	ld	(D3417),bc
	ld	bc,(D3352)
	call	A18F3
	pop	bc
	ld	hl,(D3354)
	push	hl
	ld	(D3420),a
	ld	hl,D3419
	ld	e,(hl)
	ld	bc,(D3417)
	ld	hl,2
	add	hl,bc
	ld	a,(hl)
	ld	(D3417),bc
	ld	bc,(D3352)
	ld	hl,D3419
	ld	(hl),e
	call	A18F3
	pop	bc
	ld	hl,(D3354)
	push	hl
	ld	(D3421),a
	ld	hl,D3419
	ld	e,(hl)
	ld	bc,(D3417)
	ld	hl,3
	add	hl,bc
	ld	a,(hl)
	ld	(D3417),bc
	ld	bc,(D3352)
	call	A18F3
	pop	bc
	ld	hl,(D33D0)
	push	hl
	ld	c,a
	push	bc
	ld	(D3422),a
	ld	hl,D3421
	ld	c,(hl)
	ld	hl,D3420
	ld	e,(hl)
	ld	hl,(D3417)
	ld	a,(hl)
	ld	hl,D3421
	ld	(hl),c
	call	A3D84
	pop	bc
	pop	bc
	ld	(D3425),hl
	pop	bc
	ld	a,(bc)
	push	bc
	ld	hl,(D3422)
	ex	af,af'
	ld	a,(D3421)
	ld	e,a
	ex	af,af'
	cp	56h
	jr	z,A233A
	cp	57h
	jr	z,A2343
	jr	A236C
	;
A233A:	ld	hl,0
	ld	(D341E),hl
	jr	A23B0
	;
A2343:	ld	hl,(D341E)
	ex	de,hl
	ld	a,(D3420)
	call	A3D48
	or	a
	jr	z,A2358
	ld	hl,(D341A)
	inc	hl
	inc	hl
	ld	(D341A),hl
A2358:	ld	hl,(D341C)
	ld	de,(D3425)
	ld	a,l
	or	e
	ld	c,a
	ld	a,h
	or	d
	ld	b,a
	ld	(D341C),bc
	jr	A23B0
	;
A236C:	ld	a,l
	ld	(D3422),a
	ld	hl,(D33D0)
	push	hl
	ld	(D3417),bc
	ld	hl,(D3422)
	ld	c,l
	push	bc
	ld	c,e
	ld	a,(D3420)
	ld	e,a
	ld	hl,(D3417)
	ld	a,(hl)
	call	A3EC8
	pop	bc
	pop	bc
	ld	de,(D341A)
	add	hl,de
	ld	(D341A),hl
	ld	hl,(D341E)
	ld	de,(D3425)
	ld	a,l
	or	e
	ld	l,a
	ld	a,h
	or	d
	ld	h,a
	ld	(D341E),hl
	ld	hl,(D341C)
	ld	a,l
	or	e
	ld	c,a
	ld	a,h
	or	d
	ld	b,a
	ld	(D341C),bc
A23B0:	pop	de
	inc	de
	inc	de
	inc	de
	ex	de,hl
	ld	(D3417),hl
A23B8:	ld	hl,(D3417)
	inc	hl
	ld	(D3417),hl
	jp	A21AA


A23C2:	call	A94D9
	ld	de,(D341C)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	call	A94DF
	ld	de,(D341A)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret


A23D7:	ld	hl,D3428
	ld	(hl),e
	ld	(D3427),a
	ld	(D3429),bc
	xor	a
	ld	(D342D),a
	ld	hl,(D334E)
	ld	(D342B),hl
	ex	de,hl
A23ED:	ld	a,e
	or	d
	jp	z,A24D1
	ld	hl,(D3350)
	ld	a,e
	cp	l
	jr	nz,A2402
	ld	a,d
	cp	h
	jr	nz,A2402
	ld	a,1
	ld	(D342D),a
A2402:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	ld	hl,(D3427)
	cp	l
	jp	nz,A24C4
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	ld	hl,(D3428)
	cp	l
	jp	nz,A24C4
	ld	hl,4
	add	hl,de
	ld	de,(D3429)
	ld	a,(hl)
	cp	e
	inc	hl
	jp	nz,A24C4
	ld	a,(hl)
	cp	d
	jp	nz,A24C4
	ld	hl,(D342B)
	ex	de,hl
	ld	hl,6
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	call	A94DF
	ld	a,c
	cp	l
	jp	nz,A24C4
	ld	a,b
	cp	h
	jr	nz,A24C4
	ld	hl,(D342B)
	ld	bc,8
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	call	A94D9
	ld	a,c
	cp	l
	jr	nz,A24C4
	ld	a,b
	cp	h
	jr	nz,A24C4
	ld	de,(D342B)
	ld	hl,10
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	call	A94C7
	push	hl
	call	A94E5
	db	0Eh,0			; #000E
	;
	pop	de
	call	A1430
	pop	bc
	or	a
	ret	z
	ld	a,(D342D)
	or	a
	jr	nz,A24D1
	call	A94D3
	ex	de,hl
	ld	bc,(D342B)
	ld	hl,10
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	call	A94C7
	ex	de,hl
	ld	hl,12
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	call	A94E5
	db	0Ch,0			; #000C
	;
	ex	de,hl
	ld	hl,14
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D3352)
	ex	de,hl
	ld	hl,17
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D3354)
	ex	de,hl
	ld	hl,19
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret
A24C4:	ld	hl,(D342B)
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D342B),de
	jp	A23ED
	;
A24D1:	ld	hl,(D334A)
	push	hl
	ld	hl,(D334E)
	push	hl
	ld	hl,(D3354)
	push	hl
	ld	hl,(D3352)
	push	hl
	call	A94E5
	db	14h,0			; #0014
	;
	push	hl
	call	A94E5
	db	14h,0			; #0014
	;
	push	hl
	call	A94E5
	db	14h,0			; #0014
	;
	push	hl
	call	A94E5
	db	14h,0			; #0014
	;
	push	hl
	call	A94E5
	db	14h,0			; #0014
	;
	push	hl
	ld	bc,(D3429)
	ld	hl,(D3428)
	ld	e,l
	ld	a,(D3427)
	call	A13CA
	ex	de,hl
	ld	hl,18
	add	hl,sp
	ld	sp,hl
	ex	de,hl
	ld	(D334E),hl
	ret


A2518:	ld	(D342E),hl
	push	hl
	ld	hl,(D3354)
	push	hl
	ld	hl,(D342E)
	inc	hl
	ld	a,(hl)
	ld	bc,(D3352)
	call	A18F3
	pop	bc
	ld	(D343B),a
	pop	hl
	ld	a,(hl)
	ld	l,a
	and	3
	jr	z,A2547
	dec	a
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,D3352
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	ld	l,(hl)
A2547:	ld	a,l
	and	0F7h
	ld	(D3430),a
	ld	hl,0
	ld	(D3431),hl
A2553:	ld	de,(D334A)
	ld	c,a
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A2593
	add	hl,hl
	ld	bc,D3352
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	inc	bc
	ld	a,(bc)
	cp	0C6h
	jr	nz,A2573
	ld	a,(D343B)
	cp	0C4h
	ret	z
A2573:	ld	hl,(D3431)
	push	hl
	add	hl,hl
	ld	bc,D3352
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	ld	a,(bc)
	and	14h
	ld	hl,(D3430)
	or	l
	ld	(D3430),a
	pop	hl
	inc	hl
	ld	(D3431),hl
	jr	A2553
	;
A2593:	ld	hl,-1
	ld	(D3431),hl
	ld	hl,0
	ld	(D343C),hl
	ld	hl,(D342E)
	push	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	0F0h
	cp	40h
	jr	z,A25C7
	cp	20h
	jr	z,A2609
	cp	30h
	jr	z,A2620
	cp	50h
	jr	z,A2637
	cp	10h
	jp	z,A264D
	cp	60h
	jp	z,A2656
	jp	A268A
	;
A25C7:	ld	hl,(D3344)
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	ld	hl,(D3352)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D3354)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	call	A2087
	ld	(D3433),hl
	ld	hl,(D334A)
	ld	a,l
	dec	a
	or	h
	jr	z,A25FB
	ld	hl,(D3352)
	inc	hl
	inc	hl
	ld	a,(hl)
	and	3
	jr	z,A2600
A25FB:	ld	hl,0
	jr	A2603
	;
A2600:	ld	hl,1
A2603:	ld	(D3431),hl
	jp	A2690
	;
A2609:	ld	hl,(D3352)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D3433),hl
	ld	hl,0
	ld	(D3431),hl
	jr	A2690
	;
A2620:	ld	hl,(D3354)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D3433),hl
	ld	hl,1			; true ?
	ld	(D3431),hl
	jr	A2690
	;
A2637:	ld	hl,(D3354)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	cpl
	ld	c,a
	inc	hl
	ld	a,(hl)
	cpl
	ld	b,a
	inc	bc
	ld	(D3433),bc
	jr	A2690
	;
A264D:	ld	hl,1
	ld	(D3433),hl
	jr	A2690
	;
A2656:	push	bc
	ld	hl,(D3352)
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	call	A41FA
	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl		;1+1=2
	add	hl,hl		;2+2=4
	add	hl,bc		;4+1=5
	ld	bc,T9C75
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	(D343C),bc
	ld	a,(D9CCD)
	or	a
	ld	a,3
	jr	nz,A2685		; true
	ld	a,2
A2685:	pop	bc
	or	c
	ld	(D3430),a
A268A:	ld	hl,0
	ld	(D3433),hl
A2690:	ld	hl,(D3431)
	ld	a,l
	and	h
	inc	a
	jr	z,A26C1
	push	hl
	add	hl,hl
	ld	bc,D3352
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,6
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	(D343C),bc
	pop	hl
	add	hl,hl
	ld	bc,D3352
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	ld	a,(bc)
	and	3
	ld	hl,(D3430)
	or	l
	ld	(D3430),a
A26C1:	pop	de
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	and	3
	or	a
	jr	z,A26DA
	cp	1
	jr	z,A26E8
	cp	2
	jr	z,A26F6
	cp	3
	jr	z,A2704
	jr	A270F
	;
A26DA:	ld	hl,(D3352)
	ld	bc,8
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A270F
	;
A26E8:	ld	hl,(D3354)
	ld	bc,8
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A270F
	;
A26F6:	ld	hl,(D3352)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A270F
	;
A2704:	ld	hl,(D3354)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
A270F:	ld	bc,D3439
	push	de
	push	bc
	ld	bc,D3437
	push	bc
	ld	(D3435),hl
	ld	a,(D343B)
	ld	c,a
	push	bc
	ld	hl,9
	add	hl,de
	ld	c,e
	ld	b,d
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,2
	add	hl,bc
	ld	(D343B),a
	ld	a,(hl)
	and	8
	pop	bc
	call	A2134
	pop	bc
	pop	bc
	pop	bc
	push	bc
	ld	hl,(D3437)
	push	hl
	ld	hl,(D3439)
	push	hl
	ld	hl,(D3435)
	push	hl
	ld	hl,(D343C)
	push	hl
	ld	bc,(D3433)
	ld	hl,D343B
	ld	e,(hl)
	ld	a,(D3430)
	call	A23D7
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret


A275F:	ld	(D343E),hl
	push	hl
	inc	hl
	ld	a,(hl)
	pop	hl
	cp	2Ch			; ","
	jr	nz,A277D
	ld	a,0C0h
A276C:	cp	0C5h
	ret	nc
	ld	e,a
	push	af
	ld	hl,(D343E)
	call	A2518
	pop	af
	inc	a
	inc	a
	jr	A276C
	;
A277D:	cp	2Dh			; "-"
	jr	nz,A2794
	ld	a,80h
A2783:	cp	85h
	ret	nc
	ld	e,a
	push	af
	ld	hl,(D343E)
	call	A2518
	pop	af
	inc	a
	inc	a
	jr	A2783
	;
A2794:	cp	2Eh			; "."
	jr	nz,A27AB
	ld	a,41h
A279A:	cp	48h			; "H"
	ret	nc
	ld	e,a
	push	af
	ld	hl,(D343E)
	call	A2518
	pop	af
	inc	a
	inc	a
	jr	A279A
	;
A27AB:	ld	e,15h
	jp	A2518


A27B0:	ld	(D3440),hl
	ld	(D3350),de
	ld	hl,1
	ld	(D334A),hl
	xor	a
	ld	(D334D),a
A27C1:	ld	a,e
	or	d
	jr	z,A27F6
	ld	(D3352),de
	push	de
	ld	hl,(D3440)
A27CD:	ld	a,(hl)
	inc	a
	jr	z,A27EF
	push	hl
	call	A1FCC
	pop	hl
	ld	e,l
	ld	d,h
	or	a
	jr	z,A27E8
	push	hl
	call	A275F
	pop	de
	ld	hl,2
	add	hl,de
	bit	2,(hl)
	jr	z,A27EF
A27E8:	ld	hl,11
	add	hl,de
	jr	A27CD
	;
A27EF:	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jr	A27C1
	;
A27F6:	ld	hl,(D334E)
	ret


A27FA:	ld	a,e
	ld	e,c
	ld	d,b
	ld	(D334E),hl
	ld	b,a
	add	a,a
	add	a,a
	add	a,b
	ld	l,a
	ld	h,0
	add	hl,de
	add	hl,hl
	ld	bc,T790F		;
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,e
	or	d
	jr	nz,A2818
	ld	hl,(D334E)
	ret
A2818:	ld	a,e
	and	d
	inc	a
	jr	nz,A283C
	ld	de,(D334E)
	ld	hl,(D7903)
	call	A27B0
	ex	de,hl
	ld	hl,(D7905)
	call	A27B0
	ex	de,hl
	ld	hl,(D7909)
	call	A27B0
	ex	de,hl
	ld	hl,(D790D)
	jp	A27B0
	;
A283C:	ld	a,e
	inc	a
	and	d
	inc	a
	jr	nz,A2861
	ld	de,(D334E)
	ld	hl,(D7903)
	call	A27B0
	ex	de,hl
	ld	hl,(D7905)
	call	A27B0
	ex	de,hl
	ld	hl,(D7907)
	call	A27B0
	ex	de,hl
	ld	hl,(D790B)
	jp	A27B0
	;
A2861:	ld	hl,(D334E)
	ex	de,hl
	jp	A27B0


A2868:	push	hl
	ld	hl,7FFFh		; 32767 ??
	ld	(D3442),hl
	ld	hl,-1
	ld	(D3444),hl
	inc	hl	;/		; hl=0000
	ld	(D3446),hl
	pop	hl
A287C:	ld	a,l
	or	h
	jr	z,A28D3
	push	de
	push	hl
	call	A1C60
	pop	bc
	push	bc
	or	a
	jr	z,A28CA
	ld	(D3448),bc
	push	bc
	ld	hl,(D3444)
	push	hl
	ld	hl,(D3442)
	push	hl
	ld	bc,(D3448)
	ld	hl,10
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	pop	bc
	call	A1430
	pop	bc
	pop	bc
	or	a
	jr	z,A28CA
	ld	hl,12
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D3442),hl
	ld	hl,10
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D3444),hl
	ld	(D3446),bc
A28CA:	pop	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	pop	de
	jr	A287C
	;
A28D3:	ld	hl,(D3446)
	ret


A28D7:	ld	a,e
	ld	(D344C),a
	ld	(D344A),hl
	ld	hl,0
	ld	(D344D),hl
A28E4:	ld	de,5
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A2912		; вывод "cvs"
	push	bc
	push	hl
	ld	hl,D344C
	ld	c,(hl)
	ld	e,c
	ld	hl,(D344A)
	pop	bc
	call	A27FA
	ld	(D344A),hl
	pop	bc
	ld	e,c
	ld	d,b
	push	bc
	call	A2868
	pop	bc
	ld	a,l
	or	h
	ret	nz
	ld	hl,(D344D)
	inc	hl
	ld	(D344D),hl
	jr	A28E4
	;
A2912:	ld	hl,T2918		; вывод "?cvs<рег.пара>"
	jp	A75DA			; вывод строки "hl" (большие буквы зарез.)
	;
T2918:	db	"?cvsP",0		; "?cvs<рег.пара>"  имя библ. функции


A291E:	push	hl
	ld	c,l
	ld	b,h
	ld	hl,(D334A)
	ld	a,c
	cp	l
	jr	nz,A292C
	ld	a,b
	cp	h
	jr	z,A2967
A292C:	ld	l,c
	ld	h,b
	add	hl,hl
	ex	de,hl
	ld	hl,(D3348)
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A2937:	ld	a,e
	or	d
	jr	z,A298C
	ld	l,c
	ld	h,b
	add	hl,hl
	push	hl
	ld	hl,2
	add	hl,sp
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	hl
	ld	bc,D3352
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	push	de
	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,1
	add	hl,bc
	call	A291E
	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	bc
	push	bc
	jr	A2937
	;
A2967:	ld	hl,(D3346)
A296A:	ld	a,(hl)
	inc	a
	jr	z,A298C
	push	hl
	call	A1FCC
	pop	hl
	ld	e,l
	ld	d,h
	or	a
	jr	z,A2985
	push	hl
	call	A275F
	pop	de
	ld	hl,2
	add	hl,de
	bit	2,(hl)
	jr	z,A298C
A2985:	ld	hl,11
	add	hl,de
	jr	A296A
A298C:	pop	bc
	ret


A298E:	cp	3Bh
	jr	nz,A29B4
	call	A76D5
	cp	2Dh
	jr	nz,A29B2
	ld	hl,(D9CFE)
	dec	hl
	dec	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	cpl
	ld	c,a
	inc	hl
	ld	a,(hl)
	cpl
	ld	b,a
	inc	bc
	ld	(hl),b
	dec	hl
	ld	(hl),c
A29B2:	ld	a,0ABh
A29B4:	ld	(D3458),a
	push	af
	call	A76D5
	ld	(D3459),a
	cp	9
	jr	z,A29C6
	cp	0Ah
	jr	nz,A29CE
A29C6:	call	A76BB
	ld	a,20h
	ld	(D3459),a
A29CE:	pop	af
	cp	3Ah
	jp	nz,A2A6D
	ld	a,(D3459)
	cp	41h
	jr	c,A29E0
	cp	5Bh
	jp	c,A2A6D
A29E0:	push	af
	call	A76D5
	ld	(D344F),a
	call	A3CEB
	ld	(D3456),hl
	call	A3CEB
	ex	de,hl
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	and	3Fh
	cp	20h
	jr	c,A2A05
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	and	0E0h
	jr	z,A2A0E
A2A05:	ld	hl,3
	add	hl,de
	ld	a,(hl)
	cp	15h
	jr	nz,A2A2C
A2A0E:	ld	l,e
	ld	h,d
	push	de
	call	A3CD2
	pop	hl
	call	A3CD2
	ld	hl,(D3456)
	call	A3CD2
	ld	a,(D344F)
	call	A76BB
	ld	hl,T2BD0
	call	A76C8
	jr	A2A63
	;
A2A2C:	ld	l,e
	ld	h,d
	ld	e,4
	ld	bc,T8BEB
	call	A28D7
	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	and	1Fh
	or	80h
	ld	hl,2
	add	hl,de
	ld	(hl),a
	ld	l,e
	ld	h,d
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	l,e
	ld	h,d
	call	A3CD2
	ld	hl,(D3456)
	call	A3CD2
	ld	a,(D344F)
	call	A76BB
	ld	hl,T2BD3
	call	A76C8
A2A63:	pop	af
	ld	(D3458),a
	ld	a,(D344F)
	ld	(D3459),a
A2A6D:	ld	a,(D3458)
	cp	3Eh
	jr	z,A2A8B
	cp	5Bh
	jr	z,A2A96
	cp	5Dh
	jr	z,A2A99
	cp	21h
	jr	z,A2AA7
	cp	72h
	jr	z,A2AB5
	cp	6Ch
	jr	z,A2AB5
	jr	A2ACD
	;
A2A8B:	call	A2004
	ld	a,3Ch
A2A90:	ld	(D3458),a
	jr	A2ACD
	;
A2A96:	call	A2004
A2A99:	ld	hl,T2BD6
	call	A76C8
	ld	a,3Ch
	ld	(D3458),a
	jr	A2ACD
	;
A2AA7:	ld	hl,T2BD9
	call	A76C8
	ld	a,3Dh
	ld	(D3458),a
	jr	A2ACD
	;
A2AB5:	ld	hl,(D3459)
	ex	af,af'
	ld	a,l
	call	A76BB
	ex	af,af'
	or	80h
	call	A76BB
	ld	a,9
	call	A76BB
	ld	a,43h
	ld	(D3458),a
A2ACD:	ld	hl,D3459
	ld	e,(hl)
	push	af
	call	A2061
	ld	(D3344),hl
	ld	bc,6
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D3346),hl
	ld	hl,(D3344)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	ld	(D334C),a
	dec	hl
	dec	hl
	ld	l,(hl)
	ld	h,0
	ld	(D3452),hl
	ld	de,(D9CFE)
	add	hl,hl
	ld	a,e
	sub	l
	ld	l,a
	ld	a,d
	sbc	a,h
	ld	h,a
	ld	(D3348),hl
	ex	de,hl
	ld	hl,(D9D02)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	c,A75D7			; вывод строки "bad t-codeP"
	ld	hl,0
	ld	d,h
	ld	e,l
	ld	(D3454),hl
A2B19:	ld	a,l
	or	h
	jp	nz,A2BAE
	push	de
	push	hl
	ex	de,hl
	ld	de,5
	call	cpshd			; знак. сравнение hl с de
	jr	c,A2B30
	ld	hl,T2BDC
	call	A75DA			; вывод строки "hl" (большие буквы зарез.)
A2B30:	ld	hl,(D3344)
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	ld	hl,(D3452)
A2B3A:	dec	hl
	bit	7,h
	jr	nz,A2B71
	push	hl
	ld	(D3450),hl
	push	af
	ld	bc,(D3454)
	add	hl,hl
	ex	de,hl
	ld	hl,(D3348)
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	l,e
	ld	h,d
	and	7
	ld	e,a
	call	A27FA
	push	hl
	ld	hl,(D3450)
	add	hl,hl
	ex	de,hl
	ld	hl,(D3348)
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	af
	rrca
	rrca
	rrca
	and	1Fh
	pop	hl
	jr	A2B3A
	;
A2B71:	pop	hl
	ld	(D334E),hl
	ld	hl,(D3452)
	ld	(D334A),hl
	ld	a,(D3458)
	cp	2
	ld	a,1			; true ?
	jr	z,A2B87
	xor	a			; false ?
A2B87:	ld	(D334D),a
	ld	hl,0
	call	A291E
	ld	a,(D334C)
	or	a
	jr	z,A2BA2
	call	A2004
	ld	hl,0
	call	A291E
	call	A2004
A2BA2:	ld	hl,(D334E)
	pop	de
	inc	de
	ld	(D3454),de
	jp	A2B19
	;
A2BAE:	pop	af
	push	hl
	cp	2
	jr	nz,A2BC6
	ex	de,hl
A2BB5:	ld	a,e
	or	d
	jr	z,A2BC6
	ld	hl,2
	add	hl,de
	res	2,(hl)
	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jr	A2BB5
	;
A2BC6:	ld	hl,(D3348)
	ld	(D9CFE),hl
	pop	hl
	jp	A3CD2


T2BD0:	db	":",9,0
T2BD3:	db	2,9,0
T2BD6:	db	"n",9,0
T2BD9:	db	"n",9,0
T2BDC:	db	"?loP",0		; "?lo<рег.пара>"  имя библ. функции


T2BE1:	push	bc
	push	hl
	call	A3CC1
	pop	hl
	push	hl
	ld	bc,17
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A19FB
	call	A14F1
	pop	hl
	push	hl
	ld	bc,19
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,17
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A19FB
	ld	hl,(D9CF6)
	ld	bc,0
	push	bc
	push	bc
	ld	c,14h
	push	bc
	ld	c,15h
	ld	e,c
	ld	a,4Dh
	push	de
	call	A94BA
	db	0Ch,0			; #000C
	pop	de
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	call	A152F
	pop	hl
	ld	bc,19
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,19
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A19FB
	ld	hl,(D9CF6)
	ex	de,hl
	push	de
	call	A94DF
	pop	de
	ld	bc,12
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	a,80h
	ld	(D9CC6),a
	call	A3CEB
	call	A3D0A
	call	A3CEB
	call	A3D0A
	pop	bc
	ret


A2C61:	call	A073E
	ld	a,l
	dec	a
	or	h
	jr	nz,A2C79
	ld	a,1
	ld	(D345C),a
	ld	hl,T8B99
	ld	(D345A),hl
	ld	a,47h
	jr	A2C86
	;
A2C79:	ld	a,2
	ld	(D345C),a
	ld	hl,T8B94
	ld	(D345A),hl
	ld	a,0C4h
A2C86:	push	af
	call	A3CEB
	ld	(D345D),hl
	push	hl
	call	A3CEB
	ld	(D345F),hl
	call	A3CEB
	ld	e,3
	ld	bc,T8BA3
	call	A28D7
	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	and	0E0h
	pop	hl
	pop	bc
	ld	c,b
	cp	0C0h
	jp	nz,A2D90
	ld	a,c
	ld	(D3463),a
	ld	(D345D),hl
	ld	(D3461),de
	ld	hl,(D345A)
	ld	c,l
	ld	b,h
	push	hl
	ld	a,(D345C)
	ld	e,a
	ld	(D345C),a
	ld	hl,(D345D)
	call	A28D7
	ld	(D345D),hl
	pop	bc
	ld	hl,D345C
	ld	e,(hl)
	ld	hl,(D345F)
	call	A28D7
	ex	de,hl
	ld	c,2
	push	bc
	ld	bc,0
	push	bc
	ld	hl,(D345D)
	push	hl
	push	de
	ld	bc,0
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	ld	(D345F),de
	ld	e,15h
	ld	a,8
	call	A13CA
	ex	de,hl
	ld	hl,18
	add	hl,sp
	ld	sp,hl
	ex	de,hl
	ld	c,2
	push	bc
	ld	bc,0
	push	bc
	push	hl
	ld	hl,(D3461)
	ex	de,hl
	push	de
	ld	bc,T2BE1
	push	bc
	ex	de,hl
	ld	(D3461),hl
	ld	hl,(D345D)
	ld	bc,12
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	ld	hl,(D345F)
	ex	de,hl
	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ex	de,hl
	ld	(D345F),hl
	ld	hl,(D3461)
	ex	de,hl
	ld	hl,12
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	add	hl,bc
	ld	(D3461),de
	pop	de
	add	hl,de
	ld	bc,6
	add	hl,bc
	push	hl
	ld	hl,(D3461)
	ex	de,hl
	ld	hl,10
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D345F)
	ex	de,hl
	ld	hl,10
	add	hl,de
	ld	a,c
	or	(hl)
	ld	c,a
	inc	hl
	ld	a,b
	or	(hl)
	ld	b,a
	push	bc
	ld	hl,(D345D)
	ld	bc,10
	add	hl,bc
	pop	bc
	ld	a,c
	or	(hl)
	ld	c,a
	inc	hl
	ld	a,b
	or	(hl)
	ld	b,a
	push	bc
	ld	bc,0
	push	bc
	push	bc
	ld	hl,D3463
	ld	c,(hl)
	ld	e,c
	ld	bc,0
	ld	a,8
	call	A13CA
	ex	de,hl
	ld	hl,18
	add	hl,sp
	ld	sp,hl
	ex	de,hl
	jp	A3CD2
	;
A2D90:	ld	hl,4
	add	hl,de
	ld	a,(hl)
	inc	hl
	or	(hl)
	ld	hl,(D345D)
	jp	z,A3CD2
	ld	hl,(D345F)
	jp	A3CD2


A2DA6:	ld	e,1
	jr	A2DAC
A2DAA:	ld	e,0
A2DAC:	push	hl
	ld	hl,-22
	add	hl,sp
	ld	sp,hl
	push	de
	call	A94E5
	db	1Ah,0			; #001A
	;
	pop	de
	push	hl
	push	de
	call	A3CC1
	pop	de
	ld	hl,0
	inc	e
	dec	e
	jr	nz,A2DCB
	ld	hl,3
A2DCB:	push	de
	call	A94AE
	pop	de
	pop	hl
	push	de
	call	A94BA
	db	1Ah,0			; #001A
	;
	pop	de
	push	hl
	ld	bc,19
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	de
	ld	de,0
	push	hl
	ld	hl,8
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
A2DEE:	ld	a,l
	or	h
	jr	z,A2E07
	inc	de
	push	hl
	ld	hl,8
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	ld	bc,19
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A2DEE
	;
A2E07:	push	de
	ld	hl,28
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,17
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	inc	bc
	ld	a,(bc)
	cp	15h
	ld	a,1			; true ?
	jr	nz,A2E23
	xor	a			; false ?
A2E23:	ld	hl,0
	push	de
	call	A94BA
	db	0Eh,0			; #000E
	;
	pop	de
	ld	hl,19
	add	hl,de
	push	hl
	ld	hl,29
	add	hl,sp
	ld	(hl),a
	pop	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A94BA
	db	15h,0			; #0015
	;
	pop	de
A2E42:	push	de
	call	A94D3
	pop	de
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A2E93
	push	de
	call	A94E5
	db	15h,0			; #0015
	;
	pop	de
	push	hl
	push	hl
	ld	hl,14
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	call	A19FB
	pop	hl
	push	hl
	inc	hl
	inc	hl
	inc	hl
	ld	c,(hl)
	ld	e,15h
	ld	a,54h
	call	A40DA
	call	A94E5
	db	0Ch,0			; #000C
	;
	inc	hl
	call	A94BA
	db	0Ch,0			; #000C
	;
	ld	hl,12
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	dec	de
	pop	hl
	ld	bc,19
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	de
	call	A94BA
	db	15h,0			; #0015
	;
	pop	de
	jr	A2E42
	;
A2E93:	push	de
	ld	hl,27
	add	hl,sp
	ld	a,(hl)
	ld	hl,27
	add	hl,sp
	ld	(hl),a
	or	a
	jr	z,A2EF5
	ld	hl,(D9CF6)
	ld	hl,(D9535)
	inc	hl
	ld	(D9535),hl
	dec	hl
	push	de
	call	A94BA
	db	14h,0			; #0014
	;
	pop	de
	ld	bc,0
	push	bc
	push	hl
	ld	c,15h
	push	bc
	ld	c,10h
	ld	e,0C4h
	ld	a,51h
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	ld	c,0C4h
	ld	e,15h
	ld	a,54h
	call	A40DA
	call	A94E5
	db	1Eh,0			; #001E
	;
	push	hl
	ld	bc,17
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A19FB
	pop	de
	ld	hl,17
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	inc	hl
	ld	c,(hl)
	ld	e,15h
	ld	a,54h
	call	A40DA
A2EF5:	ld	a,10h
	ld	hl,18
	add	hl,sp
	ld	(hl),a
	pop	de
	ld	l,e
	ld	h,d
	push	de
A2F00:	dec	hl
	inc	h
	dec	h
	jp	m,A2F4B
	push	hl
	call	A94BA
	db	12h,0			; #0012
	;
	call	A94E5
	db	17h,0			; #0017
	;
	push	hl
	inc	hl
	inc	hl
	inc	hl
	ex	af,af'
	ld	a,(hl)
	and	7
	srl	a
	ld	b,a
	ld	hl,1
	call	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	ex	af,af'
	or	l
	ld	hl,22
	add	hl,sp
	ld	(hl),a
	call	A94E5
	db	14h,0			; #0014
	;
	add	hl,hl
	ex	de,hl
	ld	hl,25
	add	hl,sp
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,19
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,21
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	jr	A2F00
	;
A2F4B:	pop	de
	ld	hl,19
	add	hl,sp
	call	A178D
	pop	de
	inc	e
	dec	e
	jr	z,A2F7D
	ld	bc,0
	push	bc
	push	de
	call	A94C7
	pop	de
	push	hl
	ld	c,15h
	push	bc
	ld	c,10h
	ld	e,0C4h
	ld	a,3Ch
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	ld	hl,14
	add	hl,sp
	ld	a,(hl)
	or	4
	ld	hl,14
	add	hl,sp
	ld	(hl),a
A2F7D:	ld	hl,23
	add	hl,sp
	ld	a,(hl)
	or	a
	jr	z,A2FB0
	ld	bc,0
	push	bc
	push	de
	call	A94E5
	db	12h,0			; #0012
	;
	pop	de
	push	hl
	ld	hl,18
	add	hl,sp
	ld	a,(hl)
	ld	c,a
	push	bc
	push	de
	call	A94E5
	db	22h,0			; #0022
	;
	pop	de
	inc	hl
	inc	hl
	inc	hl
	ld	e,(hl)
	ld	c,10h
	ld	a,52h
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	jr	A2FF9
	;
A2FB0:	ld	hl,24
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,17
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,6
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,17
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,18
	add	hl,sp
	ld	a,(hl)
	ld	c,a
	push	bc
	ld	hl,17
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	ld	a,(bc)
	and	3
	or	10h
	ld	c,a
	ld	hl,3
	add	hl,de
	ld	e,(hl)
	ld	a,4Eh
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
A2FF9:	pop	de
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	cp	0C4h
	ld	a,1
	jr	z,A3008
	xor	a
A3008:	ld	e,a
	push	de
	call	A94D3
	pop	de
	add	hl,hl
	call	A030F
	ld	hl,24
	add	hl,sp
	ld	sp,hl
	ret


A3018:	call	A76D5
	call	A76BB
	ld	hl,0
	cp	9
	jr	z,A302A
	call	A073E
A302A:	ld	(D3464),hl
	call	A7731
	call	A76D5
	cp	55h
	ld	a,1
	jr	z,A303C
	xor	a
A303C:	or	a
	ld	hl,0
	jr	nz,A3047
	ld	hl,3
A3047:	ld	(D346A),hl
	ld	bc,0
	push	bc
	push	bc
	push	bc
	push	bc
	ld	hl,A2DA6
	or	a
	jr	nz,A305C
	ld	hl,A2DAA
A305C:	push	hl
	push	bc
	dec	bc
	push	bc
	inc	bc
	push	bc
	push	bc
	ld	hl,(D3464)
	ld	a,l
	or	h
	jr	nz,A306E
	ld	a,15h
	jr	A3079
	;
A306E:	ld	a,l
	dec	a
	or	h
	jr	nz,A3077
	ld	a,47h
	jr	A3079
	;
A3077:	ld	a,0C4h
A3079:	ld	e,a
	ld	bc,0
	ld	a,8
	call	A13CA
	ex	de,hl
	ld	hl,18
	add	hl,sp
	ld	sp,hl
	ld	hl,0
	ld	(D3466),hl
	ld	(D346C),de
	push	de
	call	A77A1
	ex	de,hl
A3097:	ld	a,e
	or	d
	jr	z,A310C
	ld	hl,(D346A)
	push	hl
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A30AA
	ld	hl,T8BB0
	jr	A30C3
	;
A30AA:	ld	a,e
	sub	3
	or	d
	jr	nz,A30B5
	ld	hl,T8BB8
	jr	A30C3
	;
A30B5:	ld	a,e
	sub	2
	or	d
	jr	nz,A30C0
	ld	hl,T8BC0
	jr	A30C3
	;
A30C0:	ld	hl,T8BC8
A30C3:	push	hl
	ex	de,hl
	ld	(D3468),hl
	call	A3CEB
	pop	de
	call	A2868
	ld	(D346E),hl
	ld	bc,12
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	de,(D3468)
	pop	hl
	call	cpshd			; знак. сравнение hl с de
	ld	hl,1
	jr	c,A30EB
	dec	hl			; hl,0
A30EB:	add	hl,bc
	push	de
	ld	de,(D3466)
	add	hl,de
	ld	(D3466),hl
	ld	hl,(D346C)
	ld	bc,19
	add	hl,bc
	ld	de,(D346E)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ex	de,hl
	ld	(D346C),hl
	pop	de
	dec	de
	jr	A3097
	;
A310C:	ld	hl,(D346C)
	ld	bc,19
	add	hl,bc
	ld	(hl),0
	inc	hl
	ld	(hl),0
	call	A3CEB
	ld	e,4
	ld	bc,T8BD0
	call	A28D7
	ex	de,hl
	pop	bc
	ld	hl,17
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	cp	15h
	ld	hl,3
	jr	z,A313D
	ld	hl,6
A313D:	ld	de,(D3466)
	add	hl,de
	ex	de,hl
	ld	hl,12
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	l,c
	ld	h,b
	jp	A3CD2


A314F:	ld	hl,(D9D02)
	ld	(D9CFC),hl
	ld	(D9CFE),hl
A3158:	call	A76D5
	cp	4Dh
	jr	nz,A3165
	call	A76BB
	ld	a,23h
A3165:	cp	23h
	jr	nz,A31A4
	call	A76D5
	call	A76BB
	cp	2Dh
	jr	z,A317B
	call	A0306
	or	a
	jr	z,A3180
A317B:	call	A77A1
	jr	A3183
	;
A3180:	call	A073E
A3183:	ld	bc,0
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	ld	c,l
	ld	b,h
	ld	e,15h
	xor	a
	call	A13CA
	ex	de,hl
	ld	hl,18
	add	hl,sp
	ld	sp,hl
	ex	de,hl
	call	A3CD2
	jp	A3291
	;
A31A4:	cp	22h
	jr	nz,A31D2
	call	A0AFD
	ld	bc,0
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	ld	hl,(D9533)		; недост. (необход.) размер таблицы идентиф.
	push	hl
	ld	e,15h
	ld	a,42h
	call	A13CA
	ex	de,hl
	ld	hl,18
	add	hl,sp
	ld	sp,hl
	ex	de,hl
	call	A3CD2
	jp	A3291
	;
A31D2:	ld	de,T329E
	push	af
	call	A7695
	pop	af
	inc	h
	dec	h
	jp	m,A3257
	call	A76BB
	ld	de,D347D
	ld	hl,D347C
	call	A0982
	ld	e,l
	ld	d,h
	ld	a,(D347C)
	push	hl
	cp	3
	jr	z,A31FA
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A31FA:	pop	hl
	cp	4
	jr	c,A3231
	ld	bc,5
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,A3231
	ld	bc,0
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	ld	bc,2000h		; 8192  константа ?
	push	bc
	ld	bc,0
	push	bc
	push	bc
	call	A4219
	ld	e,a
	xor	a
	ld	b,a
	ld	c,a
	call	A13CA
	ex	de,hl
	ld	hl,18
	add	hl,sp
	ld	sp,hl
	ex	de,hl
	call	A3CD2
	jr	A3291
	;
A3231:	ld	bc,0
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	bc
	push	de
	ld	a,(D347D)
	or	40h
	ld	e,15h
	call	A13CA
	ex	de,hl
	ld	hl,18
	add	hl,sp
	ld	sp,hl
	ex	de,hl
	call	A3CD2
	jr	A3291
	;
A3257:	cp	1
	jr	nz,A3263
	ld	hl,(D347A)
	call	A3CD2
	jr	A3291
	;
A3263:	cp	27h
	jr	z,A326B
	cp	2Eh
	jr	nz,A327A
A326B:	call	A3CEB
	ld	(D347A),hl
	ld	hl,T32A5
	call	A76C8
	jr	A3291
	;
A327A:	cp	3Fh
	jr	nz,A3284
	call	A2C61
	jr	A3291
	;
A3284:	cp	63h
	jr	nz,A328E
	call	A3018
	jr	A3291
	;
A328E:	call	A298E
A3291:	call	A76D5
	cp	0Ah
	jp	nz,A3158
	jp	A76BB


T329E:	db	"GXYTAP",0
	;
T32A5:	db	40h,9,52h,2Bh,9,1,9,61h,9,0


A32AF:	call	A314F
	call	A3CEB
	ld	e,3
	ld	bc,T8BA3
	call	A28D7
	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	and	0E0h
	cp	0C0h
	jr	nz,A32D1
	ex	de,hl
	call	A19FB
	ld	hl,-1
	ret
A32D1:	ld	hl,4
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret


A32DA:	push	de
	push	hl
	call	A314F
	call	A3CEB
	ld	de,T8B9E
	call	A2868
	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	pop	hl
	ld	(hl),a
	ld	hl,6
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,4
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret


A3304:	push	hl
	call	A314F
	pop	hl
	ld	(D347E),hl
	ld	a,l
	dec	a
	or	h
	jr	nz,A3316
	ld	hl,T8B99
	jr	A3319
	;
A3316:	ld	hl,T8B94
A3319:	push	hl
	call	A3CEB
	push	hl
	ld	hl,(D347E)
	ld	a,l
	dec	a
	or	h
	ld	a,1
	jr	z,A332C
	inc	a
A332C:	ld	e,a
	pop	hl
	pop	bc
	call	A28D7
	jp	A19FB


D3344:	dw	0
D3346:	dw	0
D3348:	dw	0
D334A:	dw	0
D334C:	db	0
D334D:	db	0
D334E:	dw	0
D3350:	dw	0
D3352:	dw	0
D3354:	db	0,0,0,0
	;
T3358:	ds	60
	;
T3394:	ds	60
	;
D33D0:	dw	0
D33D2:	dw	0
D33D4:	dw	0
D33D6:	dw	0
D33D8:	dw	0
D33DA:	dw	0
D33DC:	dw	0
D33DE:	dw	0
D33E0:	dw	0
D33E2:	dw	0
D33E4:	dw	0
D33E6:	dw	0
D33E8:	dw	0
D33EA:	dw	0
D33EC:	dw	0
D33EE:	db	0
D33EF:	db	0
D33F0:	dw	0
D33F2:	dw	0
D33F4:	dw	0
D33F6:	dw	0
D33F8:	dw	0
D33FA:	db	0
D33FB:	dw	0
D33FD:	db	0
D33FE:	db	0
D33FF:	db	0
D3400:	db	0
D3401:	dw	0
D3403:	dw	0
D3405:	dw	0
D3407:	db	0
D3408:	db	0
D3409:	db	0
D340A:	db	0
D340B:	db	0
D340C:	db	0
D340D:	dw	0
D340F:	dw	0
	;
T3411:	ds	6
	;
D3417:	dw	0
D3419:	db	0
D341A:	dw	0
D341C:	dw	0
D341E:	dw	0
D3420:	db	0
D3421:	db	0
D3422:	db	0
D3423:	dw	0
D3425:	dw	0
D3427:	db	0
D3428:	db	0
D3429:	dw	0
D342B:	dw	0
D342D:	db	0
D342E:	dw	0
D3430:	db	0
D3431:	dw	0
D3433:	dw	0
D3435:	dw	0
D3437:	dw	0
D3439:	dw	0
D343B:	db	0
D343C:	dw	0
D343E:	dw	0
D3440:	dw	0
D3442:	dw	0
D3444:	dw	0
D3446:	dw	0
D3448:	dw	0
D344A:	dw	0
D344C:	db	0
D344D:	dw	0
D344F:	db	0
D3450:	dw	0
D3452:	dw	0
D3454:	dw	0
D3456:	dw	0
D3458:	db	0
D3459:	db	0
D345A:	dw	0
D345C:	db	0
D345D:	dw	0
D345F:	dw	0
D3461:	dw	0
D3463:	db	0
D3464:	dw	0
D3466:	dw	0
D3468:	dw	0
D346A:	dw	0
D346C:	dw	0
	;
D346E:	ds	12
	;
D347A:	dw	0
D347C:	db	0
D347D:	db	0
D347E:	dw	0



A3480:	ld	hl,-30
	add	hl,sp
	ret


A3485:	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	dec	hl
	inc	bc
	sla	c
	rl	b
A348E:	ld	a,(de)
	cp	(hl)
	jr	nz,A349D
	inc	de
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,A348E
	ld	a,true
	ret
A349D:	xor	a
	ret


A349F:	ex	de,hl
	ld	l,e
	ld	h,d
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	add	hl,hl
	add	hl,de
	inc	hl
	inc	hl
	ret


A34AB:	ld	(D9A9E),hl
	ld	a,e
	ld	(D9AA0),a
	push	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
A34B7:	ld	a,(D9AA0)
	ld	e,a
	inc	e
	ld	c,e
	ld	b,0
	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jr	nc,A34E9
	push	hl
	ld	l,e
	ld	h,0
	add	hl,hl
	ld	a,e
	ld	(D9AA0),a
	ld	de,(D9A9E)
	add	hl,de
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,D9AA0
	ld	l,(hl)
	ld	h,0
	add	hl,hl
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	hl
	jr	A34B7
	;
A34E9:	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	dec	de
	ld	(hl),d
	dec	hl
	ld	(hl),e
	ret


A34F2:	ex	de,hl
	ld	(D9AA1),hl
	ld	l,e
	ld	h,d
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	add	hl,hl
	add	hl,de
	inc	hl
	inc	hl
	push	de
	ld	de,(D9AA1)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	de
	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	de
	ld	(hl),d
	dec	hl
	ld	(hl),e
	ld	a,e
	sub	50h			; 80
	ld	a,d
	sbc	a,0
	ret	c
	jp	A7624			;2


A351B:	push	hl
	ex	de,hl
	ld	(D9AA5),hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	ld	(D9AA3),hl
	push	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ex	de,hl
	ld	(D9AA9),hl
	call	A3480
	push	hl
	ld	hl,(D9AA9)
	add	hl,hl
	ld	de,(D9AA3)
	add	hl,de
	inc	hl
	inc	hl
	pop	de
	ld	a,l
	sub	e
	ld	a,h
	sbc	a,d
	jp	nc,A7624		;3
	ld	hl,0
A3549:	ld	de,(D9AA9)
	ld	a,l
	sub	e
	ld	a,h
	sbc	a,d
	jr	nc,A3575
	ld	(D9AA7),hl
	push	hl
	add	hl,hl
	ld	de,(D9AA5)
	add	hl,de
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D9AA7)
	add	hl,hl
	ld	de,(D9AA3)
	add	hl,de
	inc	hl
	inc	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	pop	hl
	inc	hl
	jr	A3549
A3575:	pop	hl
	add	hl,de
	add	hl,de
	inc	hl
	inc	hl
	ret


A357B:	ld	hl,-324			; 0FEBCh (-0144h)
	add	hl,sp
	ld	sp,hl
	ld	hl,(D9CF6)
	ld	(D9AAB),hl
	ld	(D9AAD),hl
	ld	hl,0
	call	A94BA
	db	0A4h,0			; #00A4
	;
	pop	de
	push	hl
	ld	de,(D9CEC)
A3597:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A3712
	xor	a
A35A2:	ld	hl,9
	add	hl,de
	cp	(hl)
	jp	nc,A3626
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	l,a
	ld	h,0
	add	hl,hl
	add	hl,bc
	push	de
	push	af
	ld	(D9AAF),de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9AB1),de
	push	de
	ld	hl,(D9AAF)
	ex	de,hl
	ld	hl,-24
	add	hl,de
	pop	de
	ld	a,e
	cp	l
	jr	nz,A35D2
	ld	a,d
	cp	h
	jr	z,A3620
A35D2:	ld	c,0
A35D4:	call	A94E5
	db	0A8h,0			; #00A8 ??  
	;
	ld	e,c
	ld	d,0
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A35FD
	ld	l,c
	ld	h,0
	add	hl,hl
	ex	de,hl
	ld	hl,168			; #00A8 
	add	hl,sp
	add	hl,de
	ld	de,(D9AB1)
	ld	a,(hl)
	cp	e
	inc	hl
	jr	nz,A35F9
	ld	a,(hl)
	cp	d
	jr	z,A35FD
A35F9:	inc	c
	jr	A35D4
	;
A35FD:	call	A94E5
	db	0A8h,0			; #00A8
	;
	ld	e,c
	ld	d,0
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A3615
	ld	e,c
	ld	hl,166			; #00A6
	add	hl,sp
A3610:	call	A34AB
	jr	A3620
	;
A3615:	ld	hl,(D9AB1)
	ex	de,hl
	ld	hl,4
	add	hl,sp
	call	A34F2
A3620:	pop	af
	inc	a
	pop	de
	jp	A35A2
	;
A3626:	ld	(D9AAF),de
	push	de
	ld	hl,(D9AAB)
A362E:	ld	de,(D9AAD)
	ld	a,l
	sub	e
	ld	a,h
	sbc	a,d
	jr	nc,A3662
	push	hl
	ld	hl,4
	add	hl,sp
	ex	de,hl
	pop	hl
	push	hl
	call	A3485
	pop	hl
	or	a
	jr	z,A3659
	push	hl
	call	A349F
	push	hl
	ld	hl,168			;00A8h
	add	hl,sp
	ex	de,hl
	pop	hl
	call	A3485
	pop	hl
	or	a
	jr	nz,A3662
A3659:	call	A349F
	call	A349F
	jr	A362E
	;
A3662:	push	hl
	ld	hl,(D9AAF)
	ld	de,6
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D9AAD)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	c,A368E
	ld	hl,2
	add	hl,sp
	push	hl
	ex	de,hl
	pop	de
	call	A351B
	push	hl
	ld	hl,166			;00A6h
	add	hl,sp
	ex	de,hl
	pop	hl
	call	A351B
	ld	(D9AAD),hl
A368E:	xor	a
A368F:	cp	2
	jr	nc,A3709
	ld	l,a
	ld	h,0
	add	hl,hl
	push	af
	ld	de,(D9AAF)
	add	hl,de
	ld	bc,12			;000Ch
	add	hl,bc
	ld	c,e
	ld	b,d
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,e
	or	d
	jr	z,A3704
	ld	hl,24			;0018h
	add	hl,bc
	ld	a,e
	cp	l
	jr	nz,A36B9
	ld	a,d
	cp	h
	jr	z,A3704
A36B9:	ld	c,0
A36BB:	call	A94D9
	ld	e,c
	ld	d,0
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A36E2
	ld	l,c
	ld	h,0
	add	hl,hl
	ex	de,hl
	ld	hl,6
	add	hl,sp
	add	hl,de
	ld	de,(D9AAF)
	ld	a,(hl)
	cp	e
	inc	hl
	jr	nz,A36DE
	ld	a,(hl)
	cp	d
	jr	z,A36E2
A36DE:	inc	c
	jr	A36BB
	;
A36E2:	call	A94D9
	ld	e,c
	ld	d,0
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A36F9
	ld	e,c
	ld	hl,4
	add	hl,sp
	call	A34AB
	jr	A3704
	;
A36F9:	ld	hl,(D9AAF)
	ex	de,hl
	ld	hl,166
	add	hl,sp
	call	A34F2
A3704:	pop	af
	inc	a
	jr	A368F
	;
A3709:	pop	de
	ld	hl,24			;0018h
	add	hl,de
	ex	de,hl
	jp	A3597
	;
A3712:	ld	hl,324			;;
	add	hl,sp
	ld	sp,hl
	ret


A3718:	ld	(D9AB3),hl
A371B:	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D9CEE)
	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jr	nc,A375F
	ld	hl,(D9AB3)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A3731:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	z,A374A
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	or	a
	jr	z,A3743
	ex	de,hl
	ret
A3743:	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jr	A3731
	;
A374A:	ld	hl,(D9AB3)
	push	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	hl
	ld	hl,24			;0018h
	add	hl,de
	ex	de,hl
	pop	hl
	ld	(hl),d
	dec	hl
	ld	(hl),e
	pop	hl
	jr	A371B
	;
A375F:	ld	hl,(D9CEE)
	ld	bc,-24
	add	hl,bc
	ex	de,hl
	ld	hl,(D9AB3)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	de
	inc	de
	ex	de,hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret


T3775:	db	"?rtP",0		; "?rt<рег.пара>"  имя библ. функции


A377A:	ld	(D9AB5),hl
	call	A415F
A3780:	ld	hl,(D9AB5)
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D9CEE)
	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jr	nc,A37BF
	ld	hl,(D9AB5)
	call	A3718
	ex	de,hl
	ld	hl,4
	add	hl,de
	bit	6,(hl)
	jr	nz,A37A7
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	cp	4Dh
	jr	z,A37A9
A37A7:	ex	de,hl
	ret
A37A9:	ld	hl,4
	add	hl,de
	set	6,(hl)
	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D9AB5)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	jr	A3780
	;
A37BF:	ld	hl,T3775
	jp	A75DA			; вывод строки "hl" (большие буквы зарез.)


A37C5:	ld	bc,9
	add	hl,bc
	push	hl
	ld	a,(hl)
	xor	1
	ld	hl,D9AB7
	or	(hl)
	ld	(D9AB7),a
	pop	hl
	ld	(hl),1
	ret


A37D8:	ld	de,(D9CEC)
A37DC:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A37F3
	ld	hl,9
	add	hl,de
	ld	(hl),0
	ld	hl,24			;0018h
	add	hl,de
	ex	de,hl
	jr	A37DC
	;
A37F3:	ld	hl,(D9CEC)
	ld	bc,9
	add	hl,bc
	ld	(hl),1
A37FC:	xor	a
	ld	(D9AB7),a
	ld	hl,(D9CEC)
	ld	(D9AB8),hl
	ex	de,hl
A3807:	ld	hl,(D9CEE)
	ld	bc,-24
	add	hl,bc
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A3868
	ld	hl,9
	add	hl,de
	push	de
	ld	a,(hl)
	or	a
	jr	z,A385C
	ld	hl,2
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	cp	4Dh
	jr	z,A3839
	cp	50h
	jr	z,A385C
	cp	4Ch
	jr	z,A3847
	jr	A3852
	;
A3839:	ld	hl,12
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A37C5
	jr	A385C
	;
A3847:	ld	hl,12
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A37C5
A3852:	ld	hl,(D9AB8)
	ld	bc,24			;0018h
	add	hl,bc
	call	A37C5
A385C:	pop	de
	ld	hl,24			;0018h
	add	hl,de
	ld	(D9AB8),hl
	ex	de,hl
	jr	A3807
	;
A3868:	ld	a,(D9AB7)
	or	a
	jr	nz,A37FC
	ld	de,(D9CEC)
A3873:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	ld	hl,9
	add	hl,de
	ld	a,(hl)
	or	a
	jr	nz,A38A4
	ld	l,e
	ld	h,d
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,8
	add	hl,bc
	ld	(hl),0
	ld	l,e
	ld	h,d
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	l,e
	ld	h,d
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,2
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
A38A4:	ld	hl,24			;0018h
	add	hl,de
	ex	de,hl
	jr	A3873


A38AC:	call	A37D8
	ld	de,(D9CEC)
A38B3:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A38EA
	ld	hl,6
	add	hl,de
	ld	(hl),0FFh
	inc	hl
	ld	(hl),0FFh
	ld	hl,2
	add	hl,de
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	cp	4Dh
	jr	z,A38DA
	cp	4Ch
	jr	nz,A38E1
A38DA:	ld	hl,12
	add	hl,de
	call	A377A
A38E1:	pop	de
	ld	hl,24			;0018h
	add	hl,de
	ex	de,hl
	jp	A38B3
	;
A38EA:	call	A37D8
	ld	bc,(D9CEC)
A38F1:	ld	hl,(D9CEE)
	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jr	nc,A396C
	ld	hl,2
	add	hl,bc
A38FF:	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	push	bc
	cp	4Ch
	jr	nz,A3962
	push	de
	ld	hl,24			;0018h
	add	hl,bc
	ld	(D9ABC),hl
	ld	hl,D9ABC
	call	A3718
	ld	(D9AC0),hl
	ld	bc,8
	add	hl,bc
	ld	a,(hl)
	pop	de
	cp	4Dh
	jr	nz,A3962
	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D9ABC)
	ld	bc,24
	add	hl,bc
	pop	bc
	ld	a,l
	cp	c
	jr	nz,A3962
	ld	a,h
	cp	b
	jr	nz,A3962
	ld	hl,(D9AC0)
	push	hl
	ld	bc,8
	add	hl,bc
	ld	(hl),0
	ld	hl,10
	add	hl,de
	ld	a,(hl)
	xor	1
	ld	(hl),a
	pop	hl
	ld	bc,12
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,12
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
A3962:	pop	bc
	ld	hl,24
	add	hl,bc
	ld	c,l
	ld	b,h
	jr	A38F1
	;
A396C:	call	A37D8
	ld	hl,(D9CEC)
	ld	(D9ABA),hl
	ex	de,hl
A3976:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A37D8
	ld	hl,2
	add	hl,de
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	cp	4Dh
	jr	z,A3996
	cp	4Ch
	jp	nz,A3A16
A3996:	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	de
	ld	(D9ABC),bc
	ld	bc,(D9ABA)
	ld	hl,24
	add	hl,bc
	ld	(D9ABE),hl
	ld	hl,D9ABE
	call	A3718
	push	hl
	ld	hl,D9ABC
	call	A3718
	ex	de,hl
	pop	hl
	pop	bc
	ld	a,e
	cp	l
	jr	nz,A39CE
	ld	a,d
	cp	h
	jr	nz,A39CE
	ld	hl,8
	add	hl,bc
	ld	(hl),0
	jr	A3A16
	;
A39CE:	ld	hl,12
	add	hl,bc
	push	bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	(D9ABC),bc
	ld	hl,D9ABC
	call	A377A
	ld	bc,8
	add	hl,bc
	ld	a,(hl)
	pop	bc
	cp	50h
	jr	nz,A39F5
	ld	hl,8
	add	hl,bc
	ld	a,(hl)
	add	a,3
	ld	(hl),a
	jr	A3A16
	;
A39F5:	ld	hl,12
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,6
A39FF:	add	hl,bc
	ld	a,(hl)
	inc	hl
	and	(hl)
	inc	a
	jr	nz,A3A16
	ld	hl,(D9535)
	inc	hl
	ld	(D9535),hl
	dec	hl
	ex	de,hl
	ld	hl,6
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
A3A16:	pop	bc
	ld	hl,24
	add	hl,bc
	ld	(D9ABA),hl
	ex	de,hl
	jp	A3976


T3A25:  db	"?pbP",0


A3A2A:	ld	c,l
	ld	b,h
	ld	de,(D9CEC)
A3A30:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A3A4E
	ld	l,e
	ld	h,d
	ld	a,c
	cp	(hl)
	inc	hl
	jr	nz,A3A46
	ld	a,b
	cp	(hl)
	jr	nz,A3A46
	ex	de,hl
	ret
A3A46:	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A3A30
	;
A3A4E:	ld	hl,T3A25
	jp	A75DA			; вывод строки "hl" (большие буквы зарез.)


T3A54:	db	"?partP",0		; "?part<рег.пара>"  имя библ. функции


A3A5B:	ld	hl,(D9CF6)
	ld	(D9CEC),hl
	xor	a
	ld	(D9AC8),a
	ld	de,(table_end)		; конец таблицы идентиф.
	ld	bc,(D9CEC)
A3A6D:	ld	a,e
	or	d
	jp	z,A3B12
	ld	hl,(D9D02)
	push	de
	ld	(D9AC4),bc
	ld	a,c			; bc-hl
	sub	l
	ld	a,b
	sbc	a,h
	jp	nc,A7624		;4
	pop	de
	ld	hl,8
	add	hl,de
	res	7,(hl)
	ld	hl,(D9AC4)
	ld	c,l
	ld	b,h
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,2
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,4
	add	hl,bc
	ld	(hl),0
	ld	hl,8
	add	hl,bc
	ld	a,(D9AC8)
	ld	(hl),a
	ld	hl,12
	add	hl,bc
	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	hl,9
	add	hl,bc
	ld	(hl),0
A3ABA:	ex	de,hl
	ld	(D9AC2),hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	and	7Fh
	cp	64h
	jr	z,A3AD2
	cp	65h
	jr	z,A3ADB
	jr	A3AEA
	;
A3AD2:	ld	a,(D9AC8)
	inc	a
	ld	(D9AC8),a
	jr	A3AE2
	;
A3ADB:	ld	a,(D9AC8)
	dec	a
	ld	(D9AC8),a
A3AE2:	ld	hl,8
	add	hl,de
	ld	a,(hl)
	and	80h
	ld	(hl),a
A3AEA:	ld	a,e
	or	d
	jr	z,A3AF7
	ld	hl,8
	add	hl,de
	bit	7,(hl)
	jr	z,A3ABA
A3AF7:	ld	hl,2
	add	hl,bc
	push	bc
	ld	bc,(D9AC2)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	l,c
	ld	h,b
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,24
	add	hl,bc
	ld	c,l
	ld	b,h
	jp	A3A6D
	;
A3B12:	ld	hl,(D9CEC)
	push	bc
	ld	bc,24
	add	hl,bc
	pop	bc
	push	bc
	ld	a,l
	sub	c
	ld	a,h
	sbc	a,b
	jr	c,A3B28
	ld	hl,T3A54
	call	A75DA			; вывод строки "hl" (большие буквы зарез.)
A3B28:	pop	hl
	ld	(D9CEE),hl
	ld	(D9CF6),hl
	ld	de,(D9CEC)
A3B33:	ld	hl,(D9CEE)
	ld	bc,-24
	add	hl,bc
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A3BEC
	ld	hl,2
	add	hl,de
	ld	c,e
	ld	b,d
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	push	bc
	cp	4Ch
	jr	z,A3B5C
	cp	4Dh
	jr	z,A3BA4
	jr	A3BD2
	;
A3B5C:	ld	hl,24
	add	hl,bc
	push	hl
	ld	hl,12
	add	hl,bc
	ld	(D9AC2),de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,33
	add	hl,bc
	inc	(hl)
	push	bc
	ld	hl,(D9AC2)
	ex	de,hl
	ld	hl,12
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9AC2),de
	call	A3A2A
	ex	de,hl
	pop	bc
	ld	hl,14
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	push	de
	ld	hl,(D9AC2)
	ex	de,hl
	ld	hl,12
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,9
	add	hl,de
	inc	(hl)
	jr	A3BE3
	;
A3BA4:	push	bc
	ld	hl,12
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9AC2),de
	call	A3A2A
	ex	de,hl
	pop	bc
	ld	hl,12
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	push	de
	ld	de,(D9AC2)
	ld	hl,12
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,9
	add	hl,de
	inc	(hl)
	jr	A3BE3
	;
A3BD2:	ld	hl,24
	add	hl,bc
	ex	de,hl
	ld	hl,12
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,33
	add	hl,bc
	inc	(hl)
A3BE3:	pop	bc
	ld	hl,24
	add	hl,bc
	ex	de,hl
	jp	A3B33
	;
A3BEC:	ld	bc,(D9CF6)
	ld	de,(D9CEC)
A3BF4:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A3C2C
	ld	hl,(D9D02)
	push	de
	ld	(D9AC6),bc
	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jp	nc,A7624		;5
	pop	de
	ld	hl,10
	add	hl,de
	ld	bc,(D9AC6)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,9
	add	hl,de
	ld	l,(hl)
	ld	h,0
	add	hl,hl
	add	hl,bc
	ld	c,l
	ld	b,h
	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A3BF4
	;
A3C2C:	ld	(D9CF6),bc
	ld	hl,(D9CEC)
	ld	(D9AC4),hl
	ex	de,hl
A3C37:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A3C85
	push	de
	ld	hl,0
A3C45:	ld	a,l
	sub	2
	ld	a,h
	sbc	a,0
	jr	nc,A3C79
	push	hl
	add	hl,hl
	ld	de,(D9AC4)
	add	hl,de
	ld	bc,12
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,e
	or	d
	jr	z,A3C74
	ld	hl,10
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	de
	inc	de
	ld	(hl),d
	dec	hl
	ld	(hl),e
	dec	de
	dec	de
	ld	hl,(D9AC4)
	ex	de,hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
A3C74:	pop	hl
	inc	hl
	jr	A3C45
	;
A3C79:	pop	de
	ld	hl,24
	add	hl,de
	ld	(D9AC4),hl
	ex	de,hl
	jr	A3C37
	;
A3C85:	ld	bc,(D9CEC)
A3C89:	ld	hl,(D9CEE)
	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jp	nc,A357B
	ld	hl,11
	add	hl,bc
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	push	hl
	dec	hl
	ld	l,(hl)
	ld	h,0
	add	hl,hl
	ex	de,hl
	sbc	hl,de
	ex	de,hl
	pop	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,24
	add	hl,bc
	ld	c,l
	ld	b,h
	jr	A3C89


T3CB1:	db	"stack overflowA",0
	;
A3CC1:	call	A3480
	ex	de,hl
	ld	hl,(D9CFE)
	or	a
	sbc	hl,de
	ret	c
	ld	hl,T3CB1		; "stack overflow"
	jp	A75DA			; вывод строки "hl" (большие буквы зарез.)


A3CD2:	push	hl
	call	A3CC1
	ld	hl,(D9CFE)
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	(D9CFE),hl
	ret


T3CE2:	db	"?popstkP",0		; "?popstk<рег.пара>"  имя библ. функции
	;
A3CEB:	ld	de,(D9D02)
	ld	hl,(D9CFE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A3D04
	ld	hl,(D9CFE)
	dec	hl
	ld	a,(hl)
	dec	hl
	ld	(D9CFE),hl
	ld	l,(hl)
	ld	h,a
	ret
A3D04:	ld	hl,T3CE2
	jp	A75DA			; вывод строки "hl" (большие буквы зарез.)


A3D0A:	ld	a,l
	or	h
	ret	z
	push	hl
	call	A3CEB
	pop	hl
	dec	hl
	jr	A3D0A


A3D16:	ld	(D9AC9),a
	and	3Fh
	cp	10h
	jr	c,A3D23
	ld	hl,0
	ret
A3D23:	cp	6
	jr	nz,A3D2B
	ld	hl,0030h
	ret
A3D2B:	ld	b,a
	ld	hl,1
	call	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	ex	de,hl
	ld	a,(D9AC9)
	and	0C0h
	cp	0C0h
	jr	nz,A3D46
	ld	l,e
	ld	h,d
	add	hl,hl
	ld	a,e
	or	l
	ld	l,a
	ld	a,d
	or	h
	ld	h,a
	ret
A3D46:	ex	de,hl
	ret


A3D48:	ld	(D9ACA),a
	ex	de,hl
	ld	(D9ACB),hl
	and	0C0h
	ret	z
	ld	a,(D9ACA)
	call	A3D16
	ex	de,hl
	ld	a,e
	or	d
	jr	nz,A3D6A
	ld	hl,(D9ACB)
	ld	a,l
	and	0BFh
	cp	0BFh
	jr	nz,A3D6A
	ld	a,1			; true ?
	ret
A3D6A:	ld	hl,(D9ACB)
	ld	a,l
	and	30h
	jr	z,A3D78
	ld	a,l
	or	40h
	ld	c,a
	ld	b,h
	ld	l,c
A3D78:	ld	a,e
	and	l
	ld	c,a
	ld	a,d
	and	h
	ld	b,a
	ld	a,c
	or	b
	ret	z
	ld	a,1			; true ?
	ret


A3D84:	ld	(D9ACD),a
	ld	hl,D9ACE
	ld	(hl),e
	ld	hl,0
	ld	(D9ACF),hl
	cp	3Dh
	jr	z,A3DBC
	cp	37h
	jr	z,A3DBC
	cp	2
	jr	z,A3DC7
	cp	0Dh
	jr	z,A3DF5
	cp	0Fh
	jr	z,A3E23
	cp	46h
	jp	z,A3E4F
	cp	30h
	jp	z,A3E5C
	cp	36h
	jp	z,A3E5C
	cp	5Ch
	jp	z,A3E69
	jp	A3E76
	;
A3DBC:	ld	a,e
	xor	c
	and	3Fh
	jp	nz,A3E76
	ld	hl,0
	ret
	;
A3DC7:	ld	a,e
	cp	c
	jr	nz,A3DE6
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	cp	10h
	jr	nz,A3DE6
	call	A94D9
	push	bc
	call	A64E6
	ex	de,hl
	ld	hl,4
	pop	bc
	call	cpshd			; знак. сравнение hl с de
	jp	nc,A3E76
A3DE6:	ld	a,c
	cp	0C4h
	jp	nz,A3E76
	ld	hl,3
	ld	(D9ACF),hl
	jp	A3E76
	;
A3DF5:	call	A94D9
	call	A7685
	ex	de,hl
	ld	hl,1
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A3E0A
	ld	hl,3
	ld	(D9ACF),hl
A3E0A:	call	A94D9
	call	A7685
	ex	de,hl
	ld	hl,2
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A3E76
	ld	hl,15
	ld	(D9ACF),hl
	jr	A3E76
	;
A3E23:	call	A94D9
	call	A7685
	ex	de,hl
	ld	hl,1
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A3E38
	ld	hl,1
	ld	(D9ACF),hl
A3E38:	call	A94D9
	call	A7685
	ex	de,hl
	ld	hl,2
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A3E76
	ld	hl,3
	ld	(D9ACF),hl
	jr	A3E76
	;
A3E4F:	ld	a,e
	cp	0C4h
	jr	nz,A3E76
	jr	A3E61
	;
A3E5C:	ld	a,c
	cp	46h
	jr	nz,A3E76
A3E61:	ld	hl,128			; 80h
	ld	(D9ACF),hl
	jr	A3E76
	;
A3E69:	ld	a,e
	and	3Fh
	cp	5
	jr	nz,A3E76
	ld	hl,48			; 30h
	ld	(D9ACF),hl
A3E76:	ld	a,(D9ACD)
	cp	57h
	jr	nz,A3E8F
	ld	hl,(D9ACE)
	ld	a,l
	and	3Fh
	cp	6
	jr	nc,A3E8F
	ld	a,l
	and	0FEh
	or	0C0h
	ld	(D9ACE),a
A3E8F:	ld	a,(D9ACE)
	and	3Fh
	cp	6
	jr	nz,A3E9F
	ld	a,(D9ACD)
	cp	57h
	jr	nz,A3EA7
A3E9F:	ld	a,(D9ACE)
	call	A3D16
	jr	A3EAA
	;
A3EA7:	ld	hl,0
A3EAA:	push	hl
	ld	hl,(D9ACD)
	ld	h,0
	add	hl,hl
	ld	bc,T931B
	add	hl,bc
	ld	de,(D9ACF)
	ld	a,e
	or	(hl)
	ld	e,a
	inc	hl
	ld	a,d
	or	(hl)
	ld	d,a
	pop	hl
	ld	a,e
	or	l
	ld	l,a
	ld	a,d
	or	h
	ld	h,a
	ret


A3EC8:	ld	(D9AD1),a
	cp	46h
	jr	z,A3EEC
	cp	2
	jr	z,A3EF5
	cp	37h
	jr	z,A3F17
	cp	3Dh
	jr	z,A3F17
A3EDF:	ld	hl,(D9AD1)
	ld	h,0
	ld	bc,T9299
	add	hl,bc
	ld	l,(hl)
	ld	h,0
	ret
	;
A3EEC:	ld	a,e
	cp	0C4h
	jr	nz,A3EDF
	ld	hl,4
	ret
	;
A3EF5:	ld	a,e
	cp	c
	jr	nz,A3EDF
	ld	hl,2
	add	hl,sp
	ld	a,(hl)
	cp	10h
	jr	nz,A3EDF
	call	A94D9
	call	A64E6
	ex	de,hl
	ld	hl,4
	call	cpshd			; знак. сравнение hl с de
	jr	c,A3EDF
	call	A94D9
	jp	A64E6
	;
A3F17:	ld	a,e
	cp	c
	jr	nz,A3F1F
	ld	hl,0
	ret
	;
A3F1F:	ld	a,e
	cp	0C4h
	jr	nz,A3F29
	ld	a,c
	cp	0C2h
	jr	z,A3F33
A3F29:	ld	a,e
	cp	0C2h
	jr	nz,A3EDF
	ld	a,c
	cp	0C4h
	jr	nz,A3EDF
A3F33:	ld	hl,1
	ret


A3F37:	ld	hl,(D9CF8)
	ld	(D9CF6),hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9CF8),hl
	ret

A3F47:	ld	hl,D9AD3
	ld	(hl),e
	ld	(D9AD2),a
	ld	hl,D9AD4
	ld	(hl),c
	cp	56h
	jr	nz,A3F5D
	ld	a,c
	and	3Fh
	cp	20h
	ret	nc
A3F5D:	ld	a,(D9AD2)
	cp	57h
	jr	nz,A3F6B
	ld	a,e
	and	3Fh
	cp	20h
	ret	nc
A3F6B:	ld	hl,0
	ld	(D9CFA),hl
	ld	de,(D9CFC)
	ld	hl,(D9CF6)
	ld	bc,16
	add	hl,bc
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	c,A7624			;6
	ld	hl,(D9CF8)
	ld	a,l
	or	h
	jp	z,A4014
	ld	de,(D9CF6)
	ld	hl,(D9CF8)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	a,(D9AD2)
	cp	56h
	jr	nz,A4014
	ld	a,(D9CC6)
	or	a
	jr	nz,A4014
	ld	a,(D9CC7)
	or	a
	jr	nz,A4014
	ld	hl,(D9CF8)
	ld	bc,8
	add	hl,bc
	ld	a,(hl)
	and	80h
	ld	(D9CC6),a
	ld	a,(hl)
	and	7Fh
	ld	(D9AD5),a
	cp	57h
	jr	nz,A3FD1
	ld	hl,(D9CF8)
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	ld	hl,(D9AD4)
	cp	l
	jp	z,A3F37
A3FD1:	ld	a,(D9AD5)
	cp	37h
	jr	z,A3FDC
	cp	3Dh
	jr	nz,A4010
A3FDC:	ld	hl,(D9CF8)
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	ld	hl,D9AD4
	ld	e,(hl)
	cp	e
	jr	nz,A4010
	ld	hl,(D9CF8)
	ld	bc,10
	add	hl,bc
	ld	l,(hl)
	ld	a,l
	and	3Fh
	cp	6
	jr	z,A4010
	cp	20h
	jr	nc,A4010
	cp	7
	jr	nz,A4006
	bit	0,e
	jr	nz,A4010
A4006:	ld	a,l
	ld	(D9AD4),a
	call	A3F37
	jr	A4014
	;
A4010:	xor	a
	ld	(D9CC6),a
A4014:	ld	de,(D9CF8)
	ld	hl,(D9CF6)
	inc	hl
	inc	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D9CF6)
	ld	(D9CF8),hl
	ld	a,(D9CC6)
	ld	hl,(D9AD2)
	or	l
	ld	h,l
	push	hl
	ex	af,af'
	ld	a,l
	ld	(D9AD2),a
	ex	af,af'
	ld	iy,(D9CF6)
	ld	(iy+8),a
	ld	(iy+4),80h
	ld	(iy+5),0
	ld	a,(D9AD3)
	ld	(iy+9),a
	ld	a,(D9AD4)
	ld	(iy+10),a
	ld	hl,4
	add	hl,sp
	push	af
	ld	a,(hl)
	ld	(iy+11),a
	call	A94C7
	push	hl
	ld	hl,8
	add	hl,sp
	ld	l,(hl)
	push	hl
	ld	hl,D9AD4
	ld	c,(hl)
	ld	hl,D9AD3
	ld	e,(hl)
	ld	hl,(D9AD2)
	ld	a,l
	call	A3D84
	pop	bc
	pop	bc
	ld	iy,(D9CF6)
	ld	(iy+6),l
	ld	(iy+7),h
	pop	af
	ld	c,a
	and	0FCh
	cp	10h
	jr	z,A409B
	ld	a,c
	cp	14h
	jr	z,A409B
	ld	hl,4
	add	hl,sp
	ld	a,(hl)
	and	0FCh
	cp	10h
	jr	z,A409B
	ld	a,(hl)
	cp	14h
	jr	nz,A40BA
A409B:	call	A94D3
	ld	(iy+12),l
	ld	(iy+13),h
	call	A94C7
	ld	(iy+14),l
	ld	(iy+15),h
	ld	hl,(D9CF6)
	ld	bc,16
	add	hl,bc
	ld	(D9CF6),hl
	jp	A40C4
	;
A40BA:	ld	hl,(D9CF6)
	ld	bc,12
	add	hl,bc
	ld	(D9CF6),hl
A40C4:	pop	af
	cp	4Dh
	jr	z,A40CD
	cp	4Ch
	jr	nz,A40D2
A40CD:	ld	hl,128			; 80h
	jr	A40D5
	;
A40D2:	ld	hl,0
A40D5:	ld	a,l
	ld	(D9CC6),a
	ret


A40DA:	ld	hl,0
	push	hl
	push	hl
	ld	l,15h
	push	hl
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	ret


A40E9:	push	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	add	hl,de
	ex	de,hl
	pop	hl
	push	hl
	ld	a,e
	sub	(hl)
	inc	hl
	ld	a,d
	sbc	a,(hl)
	jr	nc,A40FF		; поставил метку "A"
	ld	hl,-1
	ex	de,hl
A40FF:	pop	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret


A4104:	push	hl
	ex	de,hl
	ld	e,c
	ld	d,b
A4108:	ld	a,e
	or	d
	jr	z,A4122
	ld	a,l
	sub	0AAh
	ld	a,h
	sbc	a,2Ah
	jr	c,A4119
	ld	hl,-1
A4122:	ex	de,hl
	pop	hl
	jp	A40E9
	;
A4119:	add	hl,hl
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,bc
	dec	de
	jr	A4108


A4127:	ex	de,hl
	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,11
	add	hl,de
	ld	l,(hl)
	push	hl
	ld	hl,10
	add	hl,de
	ld	c,(hl)
	push	bc
	ld	hl,9
	add	hl,de
	ld	c,e
	ld	b,d
	ld	e,(hl)
	ld	hl,8
	add	hl,bc
	ld	a,(hl)
	ld	(D9AD7),bc
	pop	bc
	call	A3D84
	pop	bc
	pop	bc
	ex	de,hl
	ld	bc,(D9AD7)
	ld	hl,6
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ret


A415F:	ld	de,(D9CEC)
A4163:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	ld	hl,4
	add	hl,de
	ld	a,(hl)
	and	9Fh
	ld	(hl),a
	ld	l,e
	ld	h,d
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A4179:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	z,A418A
	res	6,(hl)
	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jr	A4179
	;
A418A:	pop	de
	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A4163


A4193:	ex	de,hl
A4194:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	z,A41A3
	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jr	A4194
	;
A41A3:	ex	de,hl
	ret


A41A5:	and	3Fh
	ld	(D9AD9),a
	ex	af,af'
	ld	a,e
	and	3Fh
	ld	l,a
	ex	af,af'
	cp	l
	jr	nz,A41B6
	xor	a
	ret
A41B6:	cp	4
	jr	z,A41C1
	cp	2
	jr	z,A41C1
A41BE:	ld	a,2
	ret
A41C1:	add	a,l
	cp	6
	jr	nz,A41BE
	ld	a,1
	ret


A41C9:	xor	e
	and	3Fh
	ret	z
	ld	a,1
	ret


A41D0:	and	3Fh
	cp	6
	jr	nz,A41D9
	ld	a,4
	ret
A41D9:	and	0FEh
	ret


A41DC:	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C77
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,A41EF
	ld	a,e
A41ED:	add	a,a			; метка не нужна ?
	ret
A41EF:	ld	a,e
A41F0:	add	a,a			; метка не нужна ?
	inc	a
	ret


A41F3:	ld	e,a
	call	A41DC
	add	a,20h
	ret


A41FA:	and	3Fh
	sub	20h
	srl	a
	ret


A4201:	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C77
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,A4215
	ld	a,0C0h
	or	e
	ret
A4215:	ld	a,40h
	or	e
	ret


A4219:	push	af
	call	A41FA
	pop	de
	ld	e,d
	jr	A4201


T4222:	db	"?tagrP",0		; "?tagr<рег.пара>"  имя библ. функции

A4229:	and	0C0h
	cp	40h
	jr	z,A423D
	cp	80h
	jr	z,A4244
	cp	0C0h
	jr	z,A4248
	ld	hl,T4222
	jp	A75DA			; вывод строки "hl" (большие буквы зарез.)
	;
A423D:	ld	a,e
	call	A6509
	or	40h
	ret
A4244:	ld	a,e
	or	80h
	ret
A4248:	ld	a,e
	or	0C0h
	ret


A424C:	ld	hl,D9ADC
	ld	(hl),c
	ld	(D9ADA),de
	ld	hl,4
	add	hl,de
	ld	e,a
	bit	7,(hl)
	jr	z,A4289
	ld	a,3
	ld	(D9ADD),a
A4262:	ld	a,(D9ADD)
	ld	hl,(D9ADC)
	cp	l
	jr	z,A4289
	push	de
	dec	a
	ld	(D9ADD),a
	ld	l,a
	ld	h,0
	ld	de,(D9ADA)
	add	hl,de
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	call	A41FA
	pop	de
	cp	e
	jr	nz,A4262
	ld	a,(D9ADD)
	ret
A4289:	ld	a,-1
	ret


A428C:	ld	a,e
	ld	(D9AE0),a
	ld	(D9ADE),hl
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9CF8),hl
	xor	a
	ld	(D9CC6),a
	ld	hl,T9AE1
	ld	(hl),c
	ld	bc,0
	push	bc
	push	bc
	ld	c,10h
	push	bc
	ld	hl,T9AE1
	ld	e,(hl)
	ld	a,(D9AE0)
	ld	hl,8
	add	hl,sp
	ld	c,(hl)
	call	A3F47
	pop	bc
	pop	bc
	pop	bc
	ld	hl,(D9CF8)
	push	hl
	ld	de,(D9ADE)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,2
	add	hl,de
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D9CF8)
	ret


A42D8:	ld	de,6
	add	hl,de
	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),15h
	inc	hl
	ld	(hl),15h
	inc	hl
	ld	(hl),15h
	ret


A42F1:	push	hl
	ld	l,e
	pop	de
	ld	(D9AE2),de
	push	hl
	push	de
	ld	h,0
	ld	a,l
	ld	(D9AE4),a
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C77
	add	hl,bc
	ld	a,(hl)
	or	a
	ld	hl,-193
	jr	nz,A4320
	ld	a,(D9CCD)
	or	a
	ld	hl,-113
	jr	nz,A4320		; true
	ld	hl,-65
A4320:	ld	a,l
	ld	(D9AE5),a
	push	hl
	ld	a,(D9AE4)
	ld	c,1
	call	A424C
	pop	hl
	pop	de
	pop	bc
	inc	a
	jr	z,A4375
	push	hl
	ld	hl,9
	add	hl,de
	ld	a,(hl)
	and	3Fh
	pop	hl
	cp	6
	jr	nz,A4347
	ld	a,l
	and	0CFh
	ld	(D9AE5),a
A4347:	ld	a,1
A4349:	cp	3
	jr	nc,A4371
	ld	l,a
	ld	h,0
	ex	af,af'
	add	hl,de
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	ex	de,hl
	ld	(D9AE2),hl
	call	A3D16
	ld	a,l
	cpl
	ld	hl,(D9AE5)
	and	l
	ld	(D9AE5),a
	ex	af,af'
	inc	a
	ld	hl,(D9AE2)
	ex	de,hl
	jr	A4349
	;
A4371:	ld	a,(D9AE5)
	ret


A4375:	push	bc
	ld	hl,9
	add	hl,de
	ld	a,(hl)
	call	A41FA
	pop	bc
	cp	c
	jr	nz,A439B
	ld	de,(D9AE2)
	ld	hl,10
	add	hl,de
	ld	a,(hl)
	cp	0C6h
	jr	z,A4395
	inc	hl
	ld	a,(hl)
	cp	0C6h
	jr	nz,A439B
A4395:	ld	a,(D9AE5)
	and	0CFh
	ret
A439B:	ld	a,(D9AE5)
	ret


A439F:	ld	a,e
	push	hl
	call	A41D0
	pop	iy
	ld	b,a
	ld	a,(iy+5)
	call	A9426			; сдвиг "a" вправо, счетчик "b"
	and	3
	ret


A43B0:	ld	a,e
	ld	(D9AE8),a
	ld	e,c
	push	de
	push	hl
	call	A439F
	pop	bc
	pop	de
	cp	3
	jr	nz,A43C2
	ld	a,e
	ret
A43C2:	ld	a,(D9AD6)
	or	a
	jr	nz,A43D4
	ld	hl,(D9CEC)
	ld	a,c
	cp	(hl)
	inc	hl
	jr	nz,A43F4
	ld	a,b
	cp	(hl)
	jr	nz,A43F4
A43D4:	ld	hl,5
	add	hl,bc
	ld	l,(hl)
	ld	e,4
A43DB:	dec	e
	ld	a,e
	inc	a
	jr	z,A43F4
	ld	a,l
	and	0C0h
	cp	0C0h
	jr	nz,A43ED
	ld	a,(D9AE8)
	jp	A41DC
	;
A43ED:	ld	a,l
	add	a,a
	add	a,a
	ld	l,a
	jr	A43DB
	;
A43F4:	ld	a,-1
	ret


A43F7:	ld	(D9B19),hl
	ex	de,hl
	xor	a
A43FC:	ld	hl,D9CC5
	cp	(hl)
	jr	nc,A4421
	ld	l,a
	ld	h,0
	ld	bc,T9AE9		; ds 16
	add	hl,bc
	ld	(hl),0
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,T9AF9		; ds 32
	add	hl,bc
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	l,a
	ld	h,0
	add	hl,de
	ld	(hl),a
	inc	a
	jr	A43FC
	;
A4421:	ld	de,(D9CEC)
A4425:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A44C2
	ld	hl,8
	add	hl,de
	ld	l,(hl)
	ld	h,0
	ld	(D9B1B),hl
	ld	l,e
	ld	h,d
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A443F:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	z,A44B9
	ld	a,3
A444A:	dec	a
	cp	0FFh
	jr	z,A44B2
	ld	l,a
	ld	h,0
	push	af
	push	af
	add	hl,de
	ld	bc,9
	add	hl,bc
	ld	(D9B21),de
	ld	a,(hl)
	call	A41FA
	ld	e,a
	pop	hl
	ld	l,h
	cp	10h
	jr	nc,A44AA
	push	de
	inc	l
	dec	l
	jr	z,A447A
	ld	l,e
	ld	h,0
	ld	bc,T9AE9		; ds 16
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	nz,A448C
A447A:	ld	l,e
	ld	h,0
	add	hl,hl
	ld	bc,T9AF9		; ds 32
	add	hl,bc
	ld	bc,(D9B1B)
	ld	de,1
	call	A4104
A448C:	xor	a
A448D:	ld	hl,D9CC5
	cp	(hl)
	jr	nc,A44A0
	ld	l,a
	ld	h,0
	ld	bc,T9AE9		; ds 16
	add	hl,bc
	ld	(hl),1
	inc	a
	jr	A448D
	;
A44A0:	pop	de
	ld	l,e
	ld	h,0
	ld	bc,T9AE9		; ds 16
	add	hl,bc
	ld	(hl),0
A44AA:	pop	af
	ld	hl,(D9B21)
	ex	de,hl
	jr	A444A
	;
A44B2:	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jr	A443F
	;
A44B9:	pop	de
	ld	hl,24
	add	hl,de
	ex	de,hl
	jp	A4425
	;
A44C2:	ld	e,0
	ld	hl,D9B1F
	ld	(hl),e
A44C8:	ld	a,e
	ld	hl,D9CC5
	cp	(hl)
	ret	nc
	ld	a,e
	inc	a
	ld	(D9B20),a
A44D3:	ld	hl,D9CC5
	cp	(hl)
	jp	nc,A455F
	ld	l,e
	ld	h,0
	add	hl,hl
	ld	bc,T9AF9		; ds 32
	add	hl,bc
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,T9AF9		; ds 32
	add	hl,bc
	push	af
	ld	a,e
	sub	(hl)
	inc	hl
	ld	a,d
	sbc	a,(hl)
	jr	nc,A4556
	ld	hl,(D9B1F)
	ld	h,0
	add	hl,hl
	ld	bc,T9AF9		; ds 32
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9B1D),hl
	ld	hl,(D9B20)
	ld	h,0
	push	hl
	add	hl,hl
	ld	bc,T9AF9		; ds 32
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,(D9B1F)
	ld	h,0
	add	hl,hl
	ld	bc,T9AF9		; ds 32
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	ld	h,0
	push	hl
	add	hl,hl
	ld	bc,T9AF9		; ds 32
	add	hl,bc
	ld	de,(D9B1D)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,(D9B1F)
	ld	h,0
	ld	de,(D9B19)
	add	hl,de
	ld	e,(hl)
	pop	hl
	ld	h,0
	push	de
	push	hl
	ld	de,(D9B19)
	add	hl,de
	ld	a,(hl)
	ld	hl,(D9B1F)
	ld	h,0
	add	hl,de
	ld	(hl),a
	pop	hl
	ld	h,0
	add	hl,de
	pop	de
	ld	(hl),e
A4556:	pop	af
	inc	a
	ld	(D9B20),a
	pop	de
	jp	A44D3
	;
A455F:	inc	e
	ld	hl,D9B1F
	ld	(hl),e
	jp	A44C8


A4567:	ld	hl,(D9B23)
	ld	bc,-7
	add	hl,bc
	ex	de,hl
	ld	hl,(D9CF6)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	jp	A7624			;7


A457A:	ld	(D9B27),a
	ld	hl,(D9D02)
	push	af
A4581:	ld	bc,-7
	add	hl,bc
	ex	de,hl
	ld	hl,(D9B23)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	c,A4641
	ld	a,(D9B27)
	add	a,a
	add	a,20h
	ld	c,a
	ld	hl,T9B2A
	ld	(hl),c
	ld	hl,6
	add	hl,de
	bit	0,(hl)
	push	de
	jr	z,A4604
	bit	1,(hl)
	ld	a,56h
	jr	nz,A45AF
	ld	a,60h
A45AF:	ld	hl,5
	add	hl,de
	ld	l,(hl)
	push	bc
	push	hl
	ex	de,hl
	ld	(D9B28),hl
	ld	e,a
	push	de
	ex	de,hl
	ld	hl,3
	add	hl,de
	ld	(D9B2B),a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	pop	de
	call	A428C
	pop	bc
	ld	(D9B2C),hl
	pop	bc
	push	bc
	ld	hl,(D9B28)
	ex	de,hl
	ld	hl,2
	add	hl,de
	ld	c,(hl)
	ex	de,hl
	ld	a,(D9B2B)
	inc	a
	ld	e,a
	push	de
	ex	de,hl
	ld	l,e
	ld	h,d
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	pop	de
	call	A428C
	pop	bc
	ex	de,hl
	ld	bc,(D9B2C)
	ld	hl,14
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,14
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	jr	A463D
	;
A4604:	ld	hl,3
	add	hl,de
	push	de
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	z,A461F
	inc	hl
	ld	l,(hl)
	push	hl
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	e,58h
	call	A428C
	pop	bc
A461F:	pop	de
	ld	l,e
	ld	h,d
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	z,A463D
	ld	hl,T9B2A
	ld	c,(hl)
	push	bc
	ld	hl,2
	add	hl,de
	ld	c,(hl)
	ld	l,e
	ld	h,d
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	e,5Ch
	call	A428C
	pop	bc
A463D:	pop	hl
	jp	A4581
	;
A4641:	pop	af
	call	A5080
	jp	A53FC


A4648:	push	hl
	push	de
	push	bc
	call	A3CC1
A464E:	call	A94D9
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,4
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	z,A46D8
	ld	hl,9
	add	hl,de
	ld	a,(hl)
	call	A41FA
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	cp	e
	jr	nz,A464E
	push	de
	call	A94D3
	pop	de
	ld	bc,8
	add	hl,bc
	ld	a,(hl)
	cp	58h
	jp	z,A4728
	cp	63h
	jp	z,A4728
	cp	56h
	jr	nc,A464E
	ld	hl,2
	add	hl,sp
	ld	(hl),e
	call	A4567
	ld	hl,(D9B23)
	ld	bc,-7
	add	hl,bc
	ld	(D9B23),hl
	push	de
	call	A94D3
	pop	de
	push	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D9B23)
	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	inc	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	inc	hl
	ld	(hl),0
	pop	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	0Fh
	ld	e,a
	push	de
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	ld	a,e
	pop	de
	call	A4201
	ld	hl,(D9B23)
	ld	bc,5
	add	hl,bc
	ld	(hl),a
	jr	A4728
	;
A46D8:	ld	de,0
A46DB:	push	de
	call	A94D3
	pop	de
	ld	bc,9
	add	hl,bc
	ld	l,(hl)
	ld	h,0
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A4728
	push	de
	call	A94D3
	pop	de
	ld	bc,10
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	l,e
	ld	h,d
	add	hl,hl
	add	hl,bc
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,4
	add	hl,de
	bit	6,(hl)
	jr	nz,A4723
	set	6,(hl)
	ld	hl,2
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	a,(hl)
	ld	e,a
	push	de
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	l,e
	ld	h,d
	pop	de
	call	A4648
A4723:	pop	de
	inc	de
	jr	A46DB
A4728:	pop	bc
	pop	bc
	pop	bc
	ret


A472C:	ld	c,e
	ld	b,d
	ex	de,hl
	inc	d
	dec	d
	jp	p,A4736
	ex	de,hl
	ret
A4736:	ld	hl,8
	add	hl,bc
	ld	a,(hl)
	cp	56h
	jr	z,A4759
	cp	54h
	jr	z,A4759
	cp	57h
	jr	z,A475E
T4747:	cp	55h
	jr	z,A475E
	cp	4Ah
	jr	z,A475E
	cp	53h
	jr	z,A4763
	cp	52h
	jr	z,A476D
	ex	de,hl
	ret
	;
A4759:	ld	hl,-2
	add	hl,de
	ret
	;
A475E:	ld	hl,2
	add	hl,de
	ret
	;
A4763:	ld	hl,12
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	add	hl,de
	ret
	;
A476D:	ld	hl,4
	add	hl,de
	ret


A4772:	push	de
	push	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	hl
	ex	de,hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ex	de,hl
	ld	hl,9
	add	hl,bc
	ld	a,(hl)
	and	3Fh
	ld	(D9B2E),bc
	pop	bc
	ld	hl,(D9B2E)
	push	hl
	cp	6
	jr	nz,A47A7
	ld	a,c
	or	30h
	ld	c,a
	ld	(D9B30),bc
	ld	a,e
	and	0CFh
	ld	c,a
	ld	b,d
	ld	(D9B32),bc
	jr	A47D4
	;
A47A7:	ld	(D9B32),de
	push	bc
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	call	A3D16
	push	hl
	ld	bc,(D9B32)
	ld	a,c
	or	l
	ld	l,a
	ld	a,b
	or	h
	ld	h,a
	ld	(D9B32),hl
	pop	hl
	ld	a,l
	cpl
	ld	c,a
	ld	a,h
	cpl
	ld	b,a
	pop	hl
	ld	a,l
	and	c
	ld	c,a
	ld	a,h
	and	b
	ld	b,a
	ld	(D9B30),bc
A47D4:	pop	de
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	cp	4Eh
	jr	z,A47E2
	cp	52h
	jr	nz,A4835
A47E2:	ex	de,hl
	ld	(D9B2E),hl
	ld	e,1
	push	de
	ld	c,0
	ld	de,(D9B2E)
	ld	hl,11
	add	hl,de
	ld	c,0
	ld	a,(hl)
	pop	de
A47F5:	push	af
	and	e
	or	c
	ld	c,a
	pop	af
	add	a,a
	ex	af,af'
	ld	a,e
	add	a,a
	add	a,a
	ld	e,a
	ex	af,af'
	inc	e
	dec	e
	jr	nz,A47F5
	ld	a,c
	ld	b,a
	add	a,a
	add	a,b
	and	0BFh
	ld	c,a
	ld	b,0
	push	bc
	ld	hl,(D9B30)
	ld	a,l
	or	c
	ld	c,a
	ld	a,h
	or	b
	ld	b,a
	ld	(D9B30),bc
	pop	bc
	ld	b,0
	ld	a,c
	cpl
	ld	c,a
	ld	a,b
	cpl
	ld	b,a
	ld	hl,(D9B32)
	ld	a,l
	and	c
	ld	c,a
	ld	a,h
	and	b
	ld	b,a
	ld	(D9B32),bc
	jr	A4877
	;
A4835:	ld	a,1
A4837:	cp	3
	jr	nc,A4877
	ld	l,a
	ld	h,0
	ex	af,af'
	add	hl,de
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	ex	de,hl
	ld	(D9B2E),hl
	call	A3D16
	push	hl
	ld	de,(D9B30)
	ld	a,e
	or	l
	ld	l,a
	ld	a,d
	or	h
	ld	h,a
	ld	(D9B30),hl
	pop	hl
	ld	a,l
	cpl
	ld	c,a
	ld	a,h
	cpl
	ld	b,a
	ld	hl,(D9B32)
	ld	a,l
	and	c
	ld	c,a
	ld	a,h
	and	b
	ld	b,a
	ld	(D9B32),bc
	ex	af,af'
	inc	a
	ld	de,(D9B2E)
	jr	A4837
	;
A4877:	pop	hl
	ld	de,(D9B30)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	hl
	ld	bc,(D9B32)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ret


A4888:	ld	c,l
	ld	b,h
	ld	hl,0
	ld	(D9B34),hl
	ld	hl,D9B34
	ld	de,D9CC8
	call	A4772
	ld	hl,(D9B34)
	ret


A489D:	ld	a,c
	ld	(D9B39),a
	ld	a,e
	ld	(D9B38),a
	ld	(D9B36),hl
	ld	bc,8
	add	hl,bc
	ld	a,(hl)
	cp	56h
	jr	nc,A48DE
	xor	a
A48B2:	cp	3
	ld	(D9B3A),a
	jr	nc,A48DE
	ld	l,a
	ld	h,0
	ld	de,(D9B36)
	add	hl,de
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	call	A41FA
	cp	10h
	jr	nc,A48D7
	ld	hl,(D9B38)
	cp	l
	jr	z,A48D7
	ld	a,1
	ret
	;
A48D7:	ld	a,(D9B3A)
	inc	a
	jr	A48B2
	;
A48DE:	ld	a,(D9B39)
	ld	e,a
	ld	a,(D9B38)
	call	A4201
	ld	hl,(D9B36)
	ld	bc,6
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jp	A3D48


A48F5:	ld	a,e
	ld	(D9B3B),a
	ld	e,l
	ld	d,h
	push	hl
	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	nz,A4908
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
A4908:	ld	hl,8
	add	hl,de
	ld	a,(hl)
	pop	hl
	cp	4Ch
	jr	z,A4917
	cp	4Dh
	ret	nz
A4915:	ex	de,hl
	ret
A4917:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	bc
	push	hl
	ld	a,c
	ld	(D9B3C),a
	call	A4888
	push	hl
	ld	hl,D9B3C
	ld	c,(hl)
	ld	e,c
	ld	a,(D9B3B)
	call	A4201
	pop	de
	call	A3D48
	pop	hl
	pop	bc
	push	af
	ld	a,(D9B3B)
	ld	e,a
	pop	af
	or	a
	jr	nz,A494B
	push	hl
	call	A489D
	pop	de
	or	a
	jr	z,A4915
A494B:	ld	hl,0
	ret


A494F:	ld	(D9B3D),hl
	ld	a,c
	ld	(D9B41),a
	ld	(D9B3F),de
	ld	b,c
	push	bc
	push	de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9B46),hl
	ld	hl,6
	add	hl,sp
	ld	a,(hl)
	ld	(D9B4C),a
	call	A4567
	ld	hl,(D9B23)
	ld	bc,-7
	add	hl,bc
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	af
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	call	A4201
	ld	hl,(D9B23)
	ld	bc,-5
	add	hl,bc
	ld	(hl),a
	ld	hl,0
	ld	(D9B42),hl
	ld	a,4
	ld	(D9B44),a
	ld	(D9B4A),hl
	ld	(D9B48),hl
	ld	a,6
	ld	(D9B45),a
A49A1:	ld	hl,(D9B3D)
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,6
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D9B46)
	ld	bc,6
	add	hl,bc
	pop	bc
	ld	a,(hl)
	cp	c
	inc	hl
	jp	nz,A4A4D
	ld	a,(hl)
	cp	b
	jp	nz,A4A4D
	ld	a,(D9B41)
	ld	e,a
	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	ld	hl,(D9B3F)
	push	af
	push	hl
	call	A48F5
	pop	de
	pop	bc
	ld	c,b
	ld	a,l
	cp	e
	jr	nz,A4A4D
	ld	a,h
	cp	d
	jr	nz,A4A4D
	ld	(D9B3F),de
	ld	hl,(D9B42)
	ld	a,l
	or	h
	ld	hl,2
	jr	z,A49F3
	ld	hl,0
A49F3:	push	hl
	ld	e,c
	ld	hl,4
	add	hl,sp
	ld	c,(hl)
	ld	hl,(D9B3F)
	call	A43B0
	ld	(D9B4D),a
	inc	a
	ld	hl,0
	jr	z,A4A0E
	ld	hl,8
A4A0E:	ld	a,l
	ld	hl,(D9B44)
	or	l
	pop	hl
	or	l
	ld	e,a
	ld	a,(D9B45)
	cp	e
	jr	c,A4A31
	and	8
	jr	nz,A4A4D
	ld	hl,(D9B3F)
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	inc	bc
	inc	bc
	ld	a,(bc)
	and	80h
	jr	nz,A4A4D
A4A31:	ld	a,(D9B4D)
	cp	0FFh
	jr	z,A4A3D
	ld	hl,2
	add	hl,sp
	ld	(hl),a
A4A3D:	ld	a,e
	ld	(D9B45),a
	ld	hl,(D9B46)
	ld	(D9B48),hl
	ld	hl,(D9B3F)
	ld	(D9B4A),hl
A4A4D:	ld	a,(D9B45)
	and	0Ah
	ld	hl,(D9B46)
	cp	0Ah
	jr	z,A4ACB
	push	hl
	ld	hl,(D9B3F)
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9B3F),de
	ld	hl,4
	add	hl,de
	bit	7,(hl)
	pop	hl
	jr	z,A4AB2
	ld	hl,(D9B42)
	push	de
	call	A472C
	ld	(D9B42),hl
	pop	de
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	cp	56h
	jr	c,A4A88
	cp	63h
	jr	nz,A4A96
A4A88:	ld	hl,9
	add	hl,de
	ld	a,(hl)
	call	A41FA
	ld	hl,(D9B41)
	cp	l
	jr	z,A4ACB
A4A96:	ld	hl,(D9B41)
	ld	e,l
	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	ld	hl,(D9B3F)
	call	A489D
	or	a
	jp	z,A49A1
	ld	l,0
	ld	a,l
	ld	(D9B44),a
	jp	A49A1
	;
A4AB2:	ld	bc,-24
	add	hl,bc
	ld	(D9B46),hl
	ex	de,hl
	ld	hl,(D9CEC)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	c,A4ACB
	ld	l,e
	ld	h,d
	ld	(D9B3F),hl
	jp	A49A1
	;
A4ACB:	ld	a,(D9B45)
	push	af
	and	4
	ld	hl,(D9B4C)
	jr	z,A4AE0
	push	hl
	ld	hl,6
	add	hl,sp
	ld	a,(hl)
	pop	hl
	cp	l
	jr	z,A4B2A
A4AE0:	ld	hl,(D9B23)
	ld	bc,-7
	add	hl,bc
	ld	(D9B23),hl
	inc	hl
	inc	hl
	inc	hl
	ld	de,(D9B4A)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	a,(D9B41)
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	call	A4201
	ld	hl,(D9B23)
	ld	bc,5
	add	hl,bc
	ld	(hl),a
	ld	a,(D9B45)
	push	af
	or	1
	ld	hl,(D9B23)
	ld	bc,6
	add	hl,bc
	ld	(hl),a
	pop	af
	and	2
	ld	hl,1
	jr	nz,A4B22
	inc	hl
A4B22:	ex	de,hl
	ld	hl,(D9B25)
	add	hl,de
	ld	(D9B25),hl
A4B2A:	ld	hl,(D9B3D)
	ld	de,(D9B48)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	af
	and	8
	ret


A4B38:	ld	a,c
	ld	(D9B50),a
	ld	(D9B4E),de
	ld	(D9B52),hl
	ex	de,hl
	ld	(D9B56),hl
	ld	hl,(D9D02)
	ld	(D9B23),hl
	ld	hl,0
	ld	(D9B25),hl
A4B53:	ld	de,3
	ld	hl,(D9B25)
	call	cpshd			; знак. сравнение hl с de
	jp	nc,A4C14
	ld	hl,2
	add	hl,sp
	ld	l,(hl)
	push	bc
	push	hl
	ld	de,(D9B56)
	ld	hl,D9B52
	call	A494F
	pop	bc
	pop	bc
	or	a
	jr	z,A4B77
	xor	a
	ret
A4B77:	ld	hl,(D9B52)
	ld	a,l
	or	h
	jp	z,A4C14
	push	bc
	xor	a
	ld	(D9B51),a
A4B85:	ld	hl,(D9B52)
	ld	bc,9
	add	hl,bc
	cp	(hl)
	jr	nc,A4BD6
	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	push	af
	ld	hl,(D9B52)
	ld	bc,10
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	l,a
	ld	h,0
	add	hl,hl
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A439F
	pop	hl
	ld	l,h
	push	hl
	cp	3
	jr	z,A4BD1
	push	hl
	ld	hl,(D9B52)
	ld	bc,10
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	ld	h,0
	add	hl,hl
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9B54),hl
	ld	a,(D9B51)
	inc	a
	ld	(D9B51),a
A4BD1:	pop	af
	inc	a
	jr	A4B85
	;
A4BD6:	ld	hl,(D9B54)
	ld	a,(D9B51)
	pop	bc
	dec	a
	jr	nz,A4C14
	ld	(D9B52),hl
	push	bc
	push	hl
	ld	a,c
	ld	hl,6
	add	hl,sp
	ld	e,(hl)
	call	A4201
	ld	hl,(D9B52)
	ld	bc,18
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	call	A3D48
	pop	hl
	pop	de
	or	a
	jr	nz,A4C14
	push	hl
	ld	hl,4
	add	hl,sp
	ld	c,(hl)
	pop	hl
	push	de
	call	A48F5
	ld	(D9B56),hl
	pop	bc
	ld	a,l
	or	h
	jp	nz,A4B53
A4C14:	call	A415F
	ld	hl,(D9D02)
	ld	(D9B23),hl
	ld	a,(D9B50)
	ld	e,a
	ld	hl,(D9B4E)
	push	af
	push	hl
	call	A4648
	call	A4567
	ld	hl,(D9B23)
	ld	bc,-7
	add	hl,bc
	ld	(D9B23),hl
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	pop	af
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	call	A4201
	ld	hl,(D9B23)
	inc	hl
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	inc	hl
	ld	(hl),0
	ld	a,1
	ret


A4C56:	ld	(D9B58),hl
	ld	hl,4
	add	hl,de
	ld	a,(hl)
	and	0Fh
	ld	l,a
	push	bc
	push	hl
	ld	hl,(D9B58)
	call	A4B38
	pop	bc
	dec	sp
	pop	af
	inc	sp
	jp	A457A


T4C70:	db	"?reP",0		; "?re<рег.пара>"  имя библ. функции


A4C75:	ld	(D9B5A),a
	ld	a,1
	ld	(D9AD6),a
	ld	hl,(D9CEC)
	ld	(D9B5B),hl
	ex	de,hl
A4C84:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A4D29
	ld	l,e
	ld	h,d
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9B5D),de
A4C98:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	z,A4D1D
	ld	hl,8
	add	hl,de
	push	de
	ld	a,(hl)
	ld	(D9B60),a
	cp	63h
	jr	nz,A4CD4
	inc	hl
	ld	a,(hl)
	call	A41FA
	ld	hl,(D9B5A)
	cp	l
	jr	nz,A4CD4
	push	hl
	call	A415F
	ld	hl,(D9D02)
	ld	(D9B23),hl
	pop	de
	ld	hl,(D9B5D)
	push	de
	call	A4648
	dec	sp
	pop	af
	inc	sp
	call	A457A
	jr	A4D12
	;
A4CD4:	ld	a,(D9B60)
	cp	56h
	jr	nc,A4D12
	ld	de,(D9B5D)
	push	de
	ld	a,(D9B5A)
	ld	c,1
	ld	(D9B5A),a
	call	A424C
	pop	hl
	ex	af,af'
	ld	a,(D9B5A)
	ld	c,a
	ex	af,af'
	inc	a
	jr	z,A4D12
	push	bc
	push	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	0Fh
	ld	e,a
	pop	hl
	call	A439F
	pop	bc
	cp	3
	jr	z,A4D12
	ex	de,hl
	ld	hl,(D9B5B)
	call	A4C56
A4D12:	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9B5D),de
	jp	A4C98
	;
A4D1D:	pop	hl
	ld	bc,24
	add	hl,bc
	ld	(D9B5B),hl
	ex	de,hl
	jp	A4C84
	;
A4D29:	ld	de,(D9CEC)
A4D2D:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	ld	l,e
	ld	h,d
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	de
A4D3B:	ld	hl,4
	add	hl,bc
	bit	7,(hl)
	jr	z,A4DC2
	ld	hl,8
	add	hl,bc
	ld	a,(hl)
	push	bc
	cp	56h
	jr	nc,A4DBB
	xor	a
	ld	(D9B5F),a
A4D53:	cp	3
	jr	nc,A4DB6
	ld	l,a
	ld	h,0
	push	af
	add	hl,bc
	ld	(D9B5D),bc
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	call	A41FA
	ld	hl,(D9B5A)
	cp	l
	jr	nz,A4DAA
	ld	hl,(D9B5D)
	push	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	10h
	jr	nz,A4D82
	ld	hl,T4C70
	jp	A75DA			; вывод строки "hl" (большие буквы зарез.)
	;
A4D82:	pop	bc
	ld	hl,4
	add	hl,bc
	ld	a,(hl)
	and	0Fh
	ld	e,a
	ld	hl,(D9B5F)
	ld	h,0
	ld	a,l
	ld	(D9B5F),a
	add	hl,bc
	push	bc
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	call	A4229
	ld	hl,(D9B5F)
	ld	h,0
	pop	bc
	add	hl,bc
	ld	bc,9
	add	hl,bc
	ld	(hl),a
A4DAA:	pop	af
	inc	a
	ld	(D9B5F),a
	ld	bc,(D9B5D)
	jr	A4D53
	;
A4DB6:	ld	l,c
	ld	h,b
	call	A4127
A4DBB:	pop	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	jp	A4D3B
	;
A4DC2:	pop	de
	ld	hl,24
	add	hl,de
	ex	de,hl
	jp	A4D2D


A4DCB:	ld	c,e
	ld	(D9B61),hl
	push	hl
	pop	iy
	ld	a,(iy+4)
	ld	(D9B63),a
	ld	a,(iy+8)
	cp	63h
	jr	z,A4DF9
	cp	5Ch
	jr	z,A4E06
	cp	61h
	jr	z,A4E06
	cp	57h
	jr	z,A4E06
	cp	58h
	jr	z,A4E0E
	cp	60h
	jr	z,A4E0E
	cp	56h
	jr	z,A4E0E
	jr	A4E14
	;
A4DF9:	ld	a,(iy+9)
;	push	bc
	call	A41FA
;	pop	bc
	cp	c
	jr	nz,A4E14
	xor	a
	ret
	;
A4E06:	ld	a,(iy+9)
	ld	(D9B63),a
	jr	A4E14
	;
A4E0E:	ld	a,(iy+10)
	ld	(D9B63),a
A4E14:	ld	a,(iy+8)
	cp	56h
	jr	nc,A4E21
	bit	4,(iy+4)
	jr	z,A4E31
A4E21:	ld	a,(D9B63)
	and	6
	ld	b,a
	ld	a,3
	jr	z,A4E38
A4E2B:	add	a,a
	djnz	A4E2B
	jr	A4E38
	;
A4E31:	ld	e,c
	ld	hl,(D9B61)
	call	A42F1
A4E38:	push	af
	and	15h
	or	40h
	ld	b,a
	pop	af
	and	0AAh
	srl	a
	and	b
	ld	b,a
	add	a,a
	add	a,b
	ret


A4E48:	ld	c,e
	push	hl
	pop	iy
	bit	7,(iy+4)
	jr	nz,A4E54
	xor	a
	ret
A4E54:	ld	a,(iy+8)
	push	bc
	cp	3Dh
	jr	z,A4E6E
	cp	37h
	jr	z,A4E7F
	cp	5Ch
	jr	z,A4E7F
	cp	61h
	jr	z,A4E7F
	cp	57h
	jr	z,A4E7F
	jr	A4E8F
	;
A4E6E:	push	bc
	ld	l,c
	ld	h,0
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C77
	add	hl,bc
	pop	bc
	ld	a,(hl)
	or	a
	jr	nz,A4E8F
A4E7F:	ld	a,(iy+10)
	call	A41FA
	cp	c
	ld	e,0
	jr	z,A4E92
A4E8F:	ld	e,(iy+6)
A4E92:	pop	hl
	ld	h,0
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C77
	add	hl,bc
	ld	a,(hl)
	or	a
	jr	z,A4EB0
	ld	a,e
	and	15h
	ld	b,a
	ld	a,e
	and	0AAh
	srl	a
	or	b
	ld	b,a
	add	a,a
	add	a,b
	ret
A4EB0:	ld	a,e
	and	0AAh
	srl	a
	ld	b,a
	add	a,a
	add	a,b
	ret


A4EB9:	push	bc
	ld	c,e
	ld	a,c
	ld	(D9B66),a
	ld	(D9B64),hl
	call	A94D3
	ld	(hl),0
	pop	bc
	ld	a,(bc)
	ld	(D9B6A),a
	call	A94DF
	ld	a,(hl)
	ld	(D9B6B),a
	ld	hl,(D9CEC)
	push	bc
	ld	de,(D9B64)
	push	de
	ld	a,e
	cp	l
	jr	nz,A4F1A
	ld	a,d
	cp	h
	jr	nz,A4F1A
	ld	hl,D9B66
	ld	c,(hl)
	ld	l,c
	ld	h,0
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C79
	add	hl,bc
	ld	a,(hl)
	ld	(D9B69),a
	cp	0FFh
	jr	z,A4F1A
	and	0FEh
	cp	4
	jr	nz,A4F0C
	ld	de,12
	ld	hl,(D9CDD)
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A4F1A
A4F0C:	ld	a,(D9B69)
	and	0FEh
	ld	b,a
	ld	a,3
	call	A9438			; сдвиг "a" влево (умнож. на 2), счетчик "b"
	ld	(D9B6B),a
A4F1A:	ld	hl,(D9D02)
	ld	(D9CFE),hl
	pop	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
A4F24:	ld	hl,4
	add	hl,bc
	bit	7,(hl)
	jp	z,A5073
	inc	hl
	ld	a,(D9B6B)
	ld	(hl),a
	ld	hl,8
	add	hl,bc
	ld	e,c
	ld	d,b
	ld	a,(hl)
	push	de
	ld	(D9B6C),a
	cp	56h
	jr	nc,A4F71
	ld	l,1
A4F43:	ld	a,l
	cp	3
	jr	nc,A4F71
	ld	h,0
	push	hl
	add	hl,de
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	and	3Fh
	pop	hl
	cp	20h
	jr	c,A4F6D
	ld	hl,D9B6B
	ld	e,(hl)
	ld	a,e
	and	0AAh
	ld	(D9B6B),a
	ld	a,(D9B6A)
	and	0AAh
	ld	(D9B6A),a
	jr	A4F71
	;
A4F6D:	inc	l
	jr	A4F43
	;
A4F71:	pop	de
	ld	a,(D9B66)
	ld	c,1
	push	af
	push	de
	call	A424C
	pop	hl
	ld	(D9B67),hl
	pop	de
	ld	e,d
	push	de
	inc	a
	jr	z,A4F90
	call	A4DCB
	ld	hl,(D9B6B)
	or	l
	ld	(D9B6B),a
A4F90:	pop	de
	ld	hl,(D9B67)
	push	hl
	ld	a,e
	ld	(D9B66),a
	call	A4E48
	push	af
	cpl
	ld	hl,(D9B6B)
	and	l
	ld	(D9B6B),a
	pop	af
	cpl
	ld	hl,(D9B6A)
	and	l
	ld	(D9B6A),a
	ld	a,(D9B6C)
	pop	hl
	ld	e,l
	ld	d,h
	ld	(D9B6C),a
	cp	56h
	jr	nc,A4FD6
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	and	3Fh
	cp	20h
	jr	c,A4FD6
	ld	a,(D9B6B)
	and	0AAh
	ld	(D9B6B),a
	ld	a,(D9B6A)
	and	0AAh
	ld	(D9B6A),a
A4FD6:	ld	hl,9
	add	hl,de
	ld	a,(hl)
	push	de
	call	A41FA
	ld	hl,D9B66
	ld	c,(hl)
	cp	c
	jr	nz,A4FFF
	call	A94C7
	ld	(hl),1
	ld	hl,(D9D02)
	ld	(D9CFE),hl
	ld	e,c
	ld	hl,(D9B67)
	call	A4DCB
	ld	(D9B6B),a
	xor	a
	ld	(D9B6A),a
A4FFF:	ld	hl,D9B6C
	ld	c,(hl)
	ld	a,c
	pop	de
	push	de
	cp	56h
	jr	nz,A5029
	ld	hl,9
	add	hl,de
	ld	a,(hl)
	cp	15h
	jr	nz,A5029
	inc	hl
	ld	a,(hl)
	call	A41D0
	ld	b,a
	ld	a,(D9B6B)
	call	A9426			; сдвиг "a" вправо, счетчик "b"
	and	3
	ld	l,a
	ld	h,0
	call	A3CD2
	jr	A506C
	;
A5029:	ex	de,hl
	ld	a,c
	cp	57h
	jr	nz,A506C
	ld	bc,10
	add	hl,bc
	ld	a,(hl)
	cp	15h
	jr	nz,A506C
	ld	de,(D9D02)
	ld	hl,(D9CFE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A506C
	ld	hl,(D9B67)
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	call	A41D0
	push	af
	call	A3CEB
	ld	a,l
	pop	hl
	ld	l,h
	ld	b,l
	call	A9438			; сдвиг "a" влево (умнож. на 2), счетчик "b"
	push	af
	ld	b,l
	ld	a,3
	call	A9438			; сдвиг "a" влево (умнож. на 2), счетчик "b"
	cpl
	ld	hl,(D9B6B)
	and	l
	pop	hl
	or	h
	ld	(D9B6B),a
A506C:	pop	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	jp	A4F24
	;
A5073:	ld	a,(D9B6A)
	pop	bc
	ld	(bc),a
	call	A94DF
	ld	a,(D9B6B)
	ld	(hl),a
	ret


A5080:	ld	c,a
	ld	hl,D9B6D
	ld	(hl),c
	ld	de,(D9CEC)
A5089:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A50DE
	ld	hl,20
	add	hl,de
	ld	(hl),0FFh
	inc	hl
	inc	hl
	ld	(hl),0
	inc	hl
	push	de
	push	hl
	dec	hl
	push	hl
	dec	hl
	dec	hl
	push	hl
	ex	de,hl
	ld	(D9B6E),hl
	ld	e,c
	ld	hl,(D9B6E)
	ld	a,c
	ld	(D9B6D),a
	pop	bc
	call	A4EB9
	pop	bc
	pop	bc
	pop	de
	ld	hl,16
	add	hl,de
	ld	(hl),0FFh
	inc	hl
	ld	(hl),0FFh
	ld	hl,20
	add	hl,de
	ld	a,(hl)
	inc	hl
	inc	hl
	or	(hl)
	ld	c,a
	ld	b,0
	ld	hl,18
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,24
	add	hl,de
	ex	de,hl
	ld	hl,D9B6D
	ld	c,(hl)
	jr	A5089
	;
A50DE:	ld	iy,(D9CEC)
	ld	d,0
	ld	e,(iy+16h)
	ld	(iy+12h),e
	ld	(iy+13h),d
	ld	(iy+10h),0
	ld	(iy+11h),0
A50F5:	xor	a
	ld	(D9B70),a
	ld	hl,(D9CEC)
	ld	bc,24
	add	hl,bc
	ex	de,hl
A5101:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A5151
	xor	a
A510B:	ld	hl,9
	add	hl,de
	cp	(hl)
	jr	nc,A5149
	ld	hl,23
	add	hl,de
	ld	(D9B74),a
	ld	a,(hl)
	ex	af,af'
	ld	hl,10
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a,(D9B74)
	ld	l,a
	ld	h,0
	add	hl,hl
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,23
	add	hl,bc
	ex	af,af'
	cp	(hl)
	jr	nc,A5142
	ld	hl,23
	add	hl,de
	ld	a,1
	ld	(hl),a
	ld	(D9B70),a
	jr	A5149
	;
A5142:	ld	a,(D9B74)
	inc	a
	jr	A510B
	;
A5149:	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A5101
	;
A5151:	ld	a,(D9B70)
	or	a
	jr	nz,A50F5
	ld	de,(D9CEC)
A515B:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A5177
	ld	hl,23
	add	hl,de
	ld	a,(hl)
	or	a
	jr	nz,A516F
	dec	hl
	ld	(hl),0FFh
A516F:	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A515B
	;
A5177:	xor	a
	ld	(D9B70),a
	ld	hl,(D9CEC)
	ld	bc,24
	add	hl,bc
	ex	de,hl
A5183:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A51FA
	ld	c,0FFh
	xor	a
A5190:	ld	hl,9
	add	hl,de
	cp	(hl)
	jr	nc,A51B8
	inc	hl
	ex	af,af'
	ld	a,c
	ld	(D9B71),a
	ex	af,af'
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	l,a
	ld	h,0
	add	hl,hl
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,18
	add	hl,bc
	ex	af,af'
	ld	a,(D9B71)
	and	(hl)
	ld	c,a
	ex	af,af'
	inc	a
	jr	A5190
	;
A51B8:	ld	hl,16
	add	hl,de
	ld	b,0
	ld	a,c
	cp	(hl)
	inc	hl
	jr	nz,A51C7
	ld	a,b
	cp	(hl)
	jr	z,A51F2
A51C7:	ld	b,0
	ld	hl,16
	add	hl,de
	push	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,20
	add	hl,de
	ld	c,(hl)
	ld	b,0
	pop	hl
	ld	a,(hl)
	and	c
	ld	c,a
	ld	hl,22
	add	hl,de
	ld	l,(hl)
	ld	h,0
	ld	a,c
	or	l
	ld	c,a
	ld	hl,18
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	a,1
	ld	(D9B70),a
A51F2:	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A5183
	;
A51FA:	ld	a,(D9B70)
	or	a
	jp	nz,A5177
	ld	de,(D9CEC)
A5205:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	ld	a,0FFh
	ld	(D9B72),a
	ld	hl,16
	add	hl,de
	ld	(D9B6E),de
	push	de
	ld	a,(hl)
	ld	(D9B73),a
	ld	bc,D9CC8
	push	bc
	ld	bc,D9B73
	push	bc
	ld	bc,D9B72
	ld	a,(D9B6D)
	ld	e,a
	ld	hl,(D9B6E)
	call	A4EB9
	pop	bc
	pop	bc
	pop	de
	ld	hl,5
	add	hl,de
	ld	a,(D9B73)
	ld	(hl),a
	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A5205


A5247:	ld	(D9B75),a
	xor	a
	ld	(D9AD6),a
	ld	hl,(D9CEC)
	ld	(D9B76),hl
	ex	de,hl
A5255:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	ld	l,e
	ld	h,d
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9B78),de
A5267:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jp	z,A5324
	ld	a,(D9B75)
	ld	c,1
	push	de
	call	A424C
	inc	a
	jp	z,A5319
	xor	a
	ld	e,a
	inc	a
	ld	(D9B7A),a
	ld	(D9B7B),a
A5289:	ld	l,a
	ld	a,e
	cp	4
	jp	nc,A5319
	push	hl
	ld	a,(D9B75)
	push	de
	push	af
	call	A41DC
	ld	e,a
	push	af
	ld	hl,(D9B78)
	call	A439F
	pop	bc
	ld	c,b
	ld	hl,(D9B78)
	pop	de
	ld	e,d
	or	a
	jr	nz,A5306
	push	hl
	push	bc
	ld	c,e
	ex	de,hl
	ld	hl,(D9B76)
	call	A4B38
	pop	bc
	pop	hl
	or	a
	jr	nz,A52C7
	ld	bc,5
	add	hl,bc
	push	hl
	ld	a,(hl)
	ld	hl,(D9B7A)
	or	l
	pop	hl
	ld	(hl),a
A52C7:	ld	de,(D9D02)
A52CB:	ld	hl,-7
	add	hl,de
	ex	de,hl
	ld	hl,(D9B23)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	c,A5306
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	z,A52EC
	ld	a,(hl)
	dec	hl
	ld	l,(hl)
	ld	h,a
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	set	5,(hl)
A52EC:	ld	l,e
	ld	h,d
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	z,A52CB
	ld	a,(hl)
	dec	hl
	ld	l,(hl)
	ld	h,a
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	push	hl
	ld	a,(hl)
	ld	hl,(D9B7B)
	or	l
	pop	hl
	ld	(hl),a
	jr	A52CB
	;
A5306:	pop	de
	inc	e
	ld	a,(D9B7A)
	add	a,a
	add	a,a
	ld	(D9B7A),a
	pop	hl
	ld	a,l
	add	a,a
	ld	(D9B7B),a
	jp	A5289
	;
A5319:	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9B78),de
	jp	A5267
	;
A5324:	pop	hl
	ld	bc,24
	add	hl,bc
	ld	(D9B76),hl
	ex	de,hl
	jp	A5255


A5330:	ld	de,(D9CEC)
A5334:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A534E
	ld	hl,16
	add	hl,de
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A5334
	;
A534E:	xor	a
	ld	(D9B7E),a
	ld	de,(D9CEE)
A5356:	ld	hl,-24
	add	hl,de
	ld	c,l
	ld	b,h
	ld	hl,(D9CEC)
	ld	a,c
	sub	l
	ld	a,b
	sbc	a,h
	jp	c,A53F4
	ld	hl,18
	add	hl,bc
	ld	(hl),0
	inc	hl
	ld	(hl),0
	ld	e,0
A5371:	ld	a,e
	cp	2
	jr	nc,A53B4
	ld	l,e
	ld	h,0
	add	hl,hl
	add	hl,bc
	push	bc
	push	bc
	ld	bc,12
	add	hl,bc
	pop	bc
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	z,A53AF
	ld	l,e
	ld	h,0
	add	hl,hl
	add	hl,bc
	ld	(D9B7C),bc
	ld	bc,12
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,16
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	hl,(D9B7C)
	ld	bc,18
	add	hl,bc
	pop	bc
	ld	a,(hl)
	or	c
	ld	(hl),a
	inc	hl
	ld	a,(hl)
	or	b
	ld	(hl),a
A53AF:	inc	e
	pop	bc
	jr	A5371
	;
A53B4:	ld	e,c
	ld	d,b
	ld	hl,20
	add	hl,de
	ld	a,(hl)
	cpl
	ld	c,a
	inc	hl
	ld	a,(hl)
	cpl
	ld	b,a
	ld	hl,18
	add	hl,de
	ld	a,(hl)
	and	c
	ld	c,a
	inc	hl
	ld	a,(hl)
	and	b
	ld	b,a
	ld	hl,22
	add	hl,de
	ld	a,c
	or	(hl)
	ld	c,a
	inc	hl
	ld	a,b
	or	(hl)
	ld	b,a
	ld	hl,16
	add	hl,de
	ld	a,c
	cp	(hl)
	inc	hl
	jr	nz,A53E5
	ld	a,b
	cp	(hl)
	jp	z,A5356
A53E5:	ld	a,1
	ld	(D9B7E),a
	ld	hl,16
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	jp	A5356
	;
A53F4:	ld	a,(D9B7E)
	or	a
	jp	nz,A534E
	ret


A53FC:	ld	de,(D9CEC)
A5400:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A5456
	ld	hl,0
	ld	(D9B81),hl
	ld	(D9B7F),hl
	ld	hl,2
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	de
A541A:	ld	hl,4
	add	hl,bc
	bit	7,(hl)
	jr	z,A5437
	ld	de,D9B7F
	ld	hl,D9B81
	push	bc
	call	A4772
	pop	bc
	ld	hl,2
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	jr	A541A
	;
A5437:	pop	bc
	ld	hl,20
	add	hl,bc
	ld	de,(D9B7F)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,22
	add	hl,bc
	ld	de,(D9B81)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,24
	add	hl,bc
	ex	de,hl
	jr	A5400
	;
A5456:	ld	a,(D9CCE)
	or	a
	jr	nz,A5461
	ld	hl,0
	jr	A5471
	;
A5461:	ld	hl,(D9CE3)
	ld	a,l
	dec	a
	or	h
	jr	nz,A546E
	ld	hl,128			; 80h
	jr	A5471
	;
A546E:	ld	hl,48			; 30h
A5471:	ex	de,hl
	ld	hl,(D9CEE)
	dec	hl
	dec	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	call	A5330
	ld	hl,(D9CEC)
	ld	bc,16
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9CE5),hl
	ret


A548C:	ld	de,(D9CEC)
A5490:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A553B
	ld	hl,0
	ld	(D9B85),hl
	ld	(D9B83),hl
	ld	l,e
	ld	h,d
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A54A9:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jp	z,A5522
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	push	de
	cp	63h
	jr	z,A54C6
	cp	5Ch
	jr	z,A54D0
	cp	58h
	jr	z,A54F7
	jr	A551B
	;
A54C6:	ld	hl,9
	add	hl,de
	ld	a,(hl)
	call	A41FA
	jr	A54D8
	;
A54D0:	ld	hl,10
	add	hl,de
	ld	a,(hl)
	call	A41FA
A54D8:	ld	b,a
	ld	hl,1
	call	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	ld	de,(D9B83)
	ld	bc,(D9B85)
	ld	a,e
	cpl
	and	l
	or	c
	ld	l,a
	ld	a,d
	cpl
	and	h
	or	b
	ld	h,a
	ld	(D9B85),hl
	jr	A551B
	;
A54F7:	ld	hl,9
	add	hl,de
	ld	a,(hl)
	call	A41FA
	ld	b,a
	ld	hl,1
	call	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	ld	de,(D9B85)
	ld	bc,(D9B83)
	ld	a,e
	cpl
	and	l
	or	c
	ld	l,a
	ld	a,d
	cpl
	and	h
	or	b
	ld	h,a
	ld	(D9B83),hl
A551B:	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jr	A54A9
	;
A5522:	pop	de
	ld	hl,20
	add	hl,de
	ld	bc,(D9B83)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	ld	bc,(D9B85)
	ld	(hl),c
	inc	hl
	ld	(hl),b
	inc	hl
	ex	de,hl
	jp	A5490
	;
A553B:	call	A5330
	ld	hl,(D9CEC)
	ld	bc,16
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9CE7),hl
	ret


A554D:	ld	a,e
	ld	(D9B97),a
	call	A439F
	ld	l,a
	ld	h,0
	ex	de,hl
	ld	a,e
	sub	2
	ld	a,d
	sbc	a,0
	jr	c,A5565
A5560:	ld	hl,4
	add	hl,de
	ret
A5565:	ld	a,e
	dec	a
	or	d
	jr	nz,A5576
	ld	hl,(D9537)
	ld	a,l
	or	h
	jr	z,A5560
	ld	hl,3
	add	hl,de
	ret
A5576:	ld	a,(D9B97)
	srl	a
	ld	l,a
	ld	h,0
	add	hl,hl
	ld	bc,T5588
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret
	;
T5588:	db	0,0,2,0,4,0,4,0


A5590:	ld	(D9B98),a
	ld	(D9B99),de
	ld	hl,9
	add	hl,bc
	push	af
	ld	a,(hl)
	push	bc
	call	A41FA
	pop	bc
	ld	hl,D9B87
	push	bc
	cp	(hl)
	jr	nz,A55CE
	ld	hl,A55BA
	push	hl
	ld	hl,(D9B99)
	push	hl
	ld	hl,10
	add	hl,bc
	ld	e,(hl)
	ld	a,(D9B98)
	ret
	;
A55BA:	ld	h,a
	ld	a,3
	sub	h
	ld	e,a
	ld	d,0
	push	de
	call	A94C7
	ld	c,l
	ld	b,h
	ld	hl,(D9B89)
	pop	de
	call	A4104
A55CE:	pop	bc
	ld	hl,10
	add	hl,bc
	ld	a,(hl)
	push	bc
	call	A41FA
	pop	bc
	ld	hl,D9B87
	pop	de
	ld	e,d
	cp	(hl)
	ret	nz
	ld	hl,A55F6
	push	hl
	ld	hl,(D9B99)
	push	hl
	ld	hl,9
	add	hl,bc
	ld	a,(hl)
	ld	(D9B9B),bc
	ld	hl,D9B98
	ld	(hl),e
	ret
	;
A55F6:	ld	h,a
	ld	a,3
	sub	h
	ld	e,a
	ld	d,0
	push	de
	ld	hl,D9B98
	ld	e,(hl)
	ld	hl,(D9B9B)
	call	A554D
	pop	de
	add	hl,de
	push	hl
	call	A94D9
	ld	c,l
	ld	b,h
	ld	hl,(D9B89)
	pop	de
	jp	A4104


A5617:	ld	a,c
	ld	(D9B9F),a
	ld	(D9B9D),hl
	push	de
	push	hl
	call	A4193
	ld	bc,8
	add	hl,bc
	ld	l,(hl)
	ld	h,0
	ld	(D9BA0),hl
	pop	de
	ld	hl,4
	add	hl,de
	ld	a,(hl)
	and	50h
	pop	bc
	ret	nz
	push	bc
	ld	hl,4
	add	hl,de
	set	6,(hl)
	push	de
	ld	de,(D9B95)
	ld	hl,(D9D02)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A7624		;8
	ld	hl,(D9B95)
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	pop	bc
	ld	(hl),c
	ld	l,e
	ld	h,d
	push	de
	ld	a,(D9B87)
	ld	e,a
	call	A4DCB
	ld	l,a
	ld	a,(D9B9F)
	and	l
	ex	af,af'
	ld	a,l
	ld	(D9BA3),a
	ex	af,af'
	ld	hl,(D9B95)
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),a
	inc	hl
	ld	(D9B95),hl
	pop	de
	ld	c,0
	ld	a,(D9B87)
	call	A424C
	ld	hl,(D9BA3)
	inc	a
	ret	z
	ld	a,(D9B88)
	and	l
	ld	c,a
	ld	hl,D9B8B
	ld	(D9B89),hl
	ld	e,0
	ld	hl,D9BA2
	ld	(hl),e
A5696:	ld	a,e
	cp	4
	ret	nc
	push	de
	ld	a,c
	and	3
	ld	b,c
	push	bc
	cp	3
	jp	nz,A5757
	ld	de,(D9B9D)
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	cp	37h
	jr	z,A56B9
	cp	3Dh
	jr	z,A56D7
	jr	A56F5
	;
A56B9:	ex	de,hl
	ld	(D9B9D),hl
	ld	hl,(D9BA0)
	push	hl
	ld	hl,D9BA2
	ld	e,(hl)
	ld	a,e
	call	A41ED
	ld	bc,(D9B9D)
	ld	de,A41A5
	call	A5590
	pop	bc
	jr	A574E
	;
A56D7:	ex	de,hl
	ld	(D9B9D),hl
	ld	hl,(D9BA0)
	push	hl
	ld	hl,D9BA2
	ld	e,(hl)
	ld	a,e
	call	A41F0
	ld	bc,(D9B9D)
	ld	de,A41C9
	call	A5590
	pop	bc
	jr	A574E
	;
A56F5:	ld	hl,9
	add	hl,de
	ld	a,(hl)
	call	A41FA
	ld	hl,D9B87
	cp	(hl)
	jr	nz,A5710
	ld	bc,(D9BA0)
	ld	de,3
	ld	hl,(D9B89)
	call	A4104
A5710:	ld	a,1
A5712:	cp	3
	jr	nc,A574E
	ld	l,a
	ld	h,0
	push	af
	ld	de,(D9B9D)
	add	hl,de
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	call	A41FA
	ld	hl,D9B87
	cp	(hl)
	jr	nz,A5749
	ld	a,(D9BA2)
	ld	e,a
	ld	a,(D9B87)
	call	A41DC
	ld	e,a
	ld	hl,(D9B9D)
	call	A554D
	ex	de,hl
	ld	bc,(D9BA0)
	ld	hl,(D9B89)
	call	A4104
A5749:	pop	af
	inc	a
	jr	A5712
	;
A574E:	ld	de,1
	ld	hl,(D9B89)
	call	A40E9
A5757:	pop	af
	rrca
	rrca
	and	3Fh
	ld	c,a
	ld	hl,(D9B89)
	inc	hl
	inc	hl
	ld	(D9B89),hl
	pop	de
	inc	e
	ld	hl,D9BA2
	ld	(hl),e
	jp	A5696


A576E:	push	hl
	push	de
	push	bc
	call	A3CC1
A5774:	ld	hl,4
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,4
	add	hl,de
	bit	4,(hl)
	jp	nz,A5839
	ld	a,(hl)
	cpl
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	and	e
	ld	(hl),a
	jp	z,A5839
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	c,0
	ld	a,(D9B87)
	push	de
	call	A424C
	pop	hl
	or	a
	jp	z,A5839
	push	hl
	inc	a
	jr	nz,A57B4
	push	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	and	0A0h
	pop	hl
	cp	0A0h
	jr	nz,A57C7
A57B4:	push	hl
	ld	hl,4
	add	hl,sp
	ld	a,(hl)
	pop	hl
	ld	c,a
	push	hl
	ld	hl,6
	add	hl,sp
	ld	a,(hl)
	pop	hl
	ld	e,a
	call	A5617
A57C7:	pop	hl
	push	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	bit	7,(hl)
	pop	hl
	jr	z,A57F1
	ld	a,(D9B87)
	ld	e,a
	call	A4E48
	cpl
	ld	hl,0
	add	hl,sp
	ld	e,(hl)
	and	e
	ld	(hl),a
	jp	z,A5839
	call	A94D9
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A94AE
	jr	A5774
	;
A57F1:	xor	a
A57F2:	cp	2
	jr	nc,A5839
	ld	l,a
	ld	h,0
	add	hl,hl
	push	af
	push	hl
	ld	hl,8
	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	pop	hl
	add	hl,de
	ld	bc,12
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,e
	or	d
	jr	z,A5834
	ld	hl,4
	add	hl,de
	bit	6,(hl)
	jr	nz,A5834
	set	6,(hl)
	ld	l,e
	ld	h,d
	push	hl
	ld	hl,4
	add	hl,sp
	ld	a,(hl)
	pop	hl
	ld	c,a
	push	hl
	ld	hl,6
	add	hl,sp
	ld	a,(hl)
	pop	hl
	ld	e,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A576E
A5834:	pop	af
	inc	a
	jp	A57F2
	;
A5839:	pop	bc
	pop	bc
	pop	bc
	ret


A583D:	push	hl
	push	de
	push	bc
	push	bc
	push	hl
	call	A3CC1
	pop	de
	pop	bc
A5847:	ld	hl,4
	add	hl,de
	bit	4,(hl)
	jp	nz,A5909
	ld	hl,0
	add	hl,sp
	ld	(hl),c
	ld	c,0
	ld	a,(D9B87)
	push	de
	call	A424C
	pop	hl
	push	af
	push	hl
	push	hl
	ld	hl,6
	add	hl,sp
	ld	c,(hl)
	pop	hl
	inc	a
	jr	z,A5876
	push	hl
	ld	hl,8
	add	hl,sp
	ld	a,(hl)
	pop	hl
	ld	e,a
	call	A5617
A5876:	pop	hl
	push	hl
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	cpl
	ld	hl,6
	add	hl,sp
	ld	e,(hl)
	and	e
	ld	hl,6
	add	hl,sp
	ld	(hl),a
	pop	hl
	ld	a,(D9B87)
	ld	e,a
	call	A4E48
	cpl
	ld	hl,2
	add	hl,sp
	ld	c,(hl)
	and	c
	ld	c,a
	ld	(hl),c
	pop	af
	ld	hl,2
	add	hl,sp
	ld	e,(hl)
	or	a
	jr	z,A5909
	inc	e
	dec	e
	jr	z,A5909
	inc	a
	jr	nz,A58B1
	inc	c
	dec	c
	jr	z,A5909
A58B1:	call	A94D9
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,4
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	nz,A5847
	xor	a
A58CA:	call	A94D9
	ld	bc,9
	add	hl,bc
	cp	(hl)
	jr	nc,A5909
	call	A94D9
	ld	bc,10
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	l,a
	ld	h,0
	add	hl,hl
	add	hl,bc
	push	af
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,4
	add	hl,de
	bit	5,(hl)
	jr	nz,A5904
	set	5,(hl)
	ld	l,e
	ld	h,d
	push	hl
	ld	hl,4
	add	hl,sp
	ld	a,(hl)
	ld	c,a
	ld	hl,6
	add	hl,sp
	ld	a,(hl)
	pop	hl
	ld	e,a
	call	A583D
A5904:	pop	af
	inc	a
	jr	A58CA
A5909:	pop	bc
	pop	bc
	pop	bc
	ret


A590D:	push	hl
	call	A415F
	ld	a,(D9B88)
	ld	c,a
	ld	e,0
	ld	l,1
A5919:	ld	a,l
	cp	10h
	jr	nc,A5929
	ld	a,c
	and	l
	or	e
	ld	e,a
	srl	c
	sla	l
	jr	A5919
	;
A5929:	ld	hl,(D9CF6)
	ld	(D9B93),hl
	ld	(D9B95),hl
	pop	hl
	ld	a,(D9B88)
	ld	c,a
	call	A5617
	ld	de,(D9B93)
A593E:	ld	hl,(D9B95)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	ld	hl,3
	add	hl,de
	ld	c,(hl)
	push	de
	push	bc
	ld	hl,2
	add	hl,de
	ld	c,e
	ld	b,d
	ld	e,(hl)
	ld	l,c
	ld	h,b
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	pop	bc
	call	A576E
	pop	de
	ld	hl,3
	add	hl,de
	ld	c,(hl)
	push	de
	ld	hl,2
	add	hl,de
	push	de
	ld	e,(hl)
	pop	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A583D
	pop	de
	inc	de
	inc	de
	inc	de
	inc	de
	jr	A593E


T597F:	db	"?assrP",0		; "?assr<рег.пара>"  имя библ. функции



; Оптимизация кода ?
; (Цикл вывода на экран "+++++")
A5986:	ld	c,a
	ld	hl,D9BA4
	ld	(hl),c
	ld	de,(D9CEC)
A598F:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A59E0
	ld	(D9BAB),de
	push	de
A599E:	ld	hl,4
	add	hl,de
	ld	a,(hl)
	and	0C0h
	ld	(hl),a
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	push	de
	cp	63h
	jr	nz,A59C6
	ld	hl,9
	add	hl,de
	ld	a,(hl)
	call	A41FA
	cp	c
	jr	nz,A59C6
	ld	hl,(D9BAB)
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	set	4,(hl)
A59C6:	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9BAB),de
	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	nz,A599E
	pop	de
	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A598F
	;
A59E0:	ld	a,c
	ld	b,c
	push	bc
	call	A5080
	call	A53FC
	pop	af
	push	af
	call	A5247
	ld	a,-1
	ld	(D9BAA),a
	ld	de,(D9CEC)
A59F7:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A5B33
	ld	l,e
	ld	h,d
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A5A07:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jp	z,A5B2A
	push	de
	bit	4,(hl)
	jp	nz,A5B23
	ld	a,(D9BA4)
	ld	c,0
	push	af
	push	de
	call	A424C
	pop	hl
	pop	de
	ld	e,d
	inc	a
	jp	z,A5B23
	push	hl
	ld	hl,0
	ld	(D9B8B),hl
	ld	(D9B8D),hl
	ld	(D9B8F),hl
	ld	(D9B91),hl
	ld	a,e
	ld	(D9B87),a
	pop	hl
	push	hl
	call	A4DCB
	ld	(D9B88),a
	pop	hl
	call	A590D
	ld	hl,0
	ld	(D9BA5),hl
	ld	e,h
	ld	hl,T9BA9
	ld	(hl),e
A5A53:	ld	a,e
	cp	4
	jr	nc,A5AC0
	ld	l,e
	ld	h,0
	add	hl,hl
	ld	bc,D9B8B
	add	hl,bc
	push	de
	ld	de,(D9BA5)
	ld	a,e
	sub	(hl)
	inc	hl
	ld	a,d
	sbc	a,(hl)
	jr	c,A5A95
	push	de
	ld	hl,T9BA9
	ld	e,(hl)
	ld	l,e
	ld	h,0
	add	hl,hl
	ld	bc,D9B8B
	add	hl,bc
	pop	de
	ld	a,(hl)
	cp	e
	inc	hl
	jr	nz,A5AB7
	ld	a,(hl)
	cp	d
	jr	nz,A5AB7
	ld	hl,T9BA9
	ld	e,(hl)
	ld	a,e
	ld	hl,(D9BAA)
	cp	l
	jr	z,A5A95
	ld	a,(D9BA8)
	cp	l
	jr	z,A5AB7
A5A95:	ld	hl,T9BA9
	ld	e,(hl)
	ld	l,e
	ld	h,0
	add	hl,hl
	ld	bc,D9B8B
	add	hl,bc
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9BA5),de
	pop	de
	ld	hl,D9BA8
	ld	(hl),e
	ld	a,(D9BA4)
	call	A41DC
	ld	(D9BA7),a
A5AB7:	pop	de
	inc	e
	ld	hl,T9BA9
	ld	(hl),e
	jr	A5A53
	;
A5AC0:	ld	a,(D9BA8)
	ld	(D9BAA),a
	ld	hl,(D9BA5)
	ld	a,l
	or	h
	ld	hl,T597F
	jp	z,A75DA			; вывод строки "hl" (большие буквы зарез.)
	ld	de,(D9B93)
A5AD8:	ld	hl,(D9B95)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A5B23
	ld	(D9BAD),de
	push	de
	ld	a,(D9BA8)
	add	a,a
	push	af
	ld	a,(D9BA4)
	ld	e,a
	push	de
	ld	hl,(D9BAD)
	ex	de,hl
	ld	l,e
	ld	h,d
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	pop	de
	call	A4DCB
	pop	bc
	call	A9426			; сдвиг "a" вправо, счетчик "b"
	and	3
	pop	hl
	ld	e,l
	ld	d,h
	or	a
	jr	z,A5B1C
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	inc	bc
	inc	bc
	inc	bc
	ld	a,(bc)
	and	0F0h
	or	10h
	ld	hl,(D9BA7)
	or	l
	ld	(bc),a
A5B1C:	inc	de
	inc	de
	inc	de
	inc	de
	jr	A5AD8
	;
A5B23:	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jp	A5A07
	;
A5B2A:	pop	de
	ld	hl,24
	add	hl,de
	ex	de,hl
	jp	A59F7
	;
A5B33:	pop	af
	push	af
	call	A5080
	call	A53FC
	pop	af
	jp	A4C75


A5B3F:	call	A53FC
	xor	a
	ld	(D9BBD),a
	ld	hl,(D9D02)
	ld	(D9CFE),hl
	ld	de,(D9CEE)
A5B50:	ld	hl,-24
	add	hl,de
	ex	de,hl
	ld	hl,(D9CEC)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	c,A5D55
	ld	hl,2
	add	hl,de
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9BB5),de
A5B6B:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jp	z,A5D51
	ld	hl,0
	ld	(D9BAF),hl
	ld	(D9BBB),de
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	push	de
	cp	56h
	jp	nz,A5CE5
	push	de
	call	A3CEB
	ld	(D9BB9),hl
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	ld	(D9BBE),a
	pop	de
	ld	hl,10
	add	hl,de
	push	de
	ld	a,(hl)
	ld	(D9BBF),a
	call	A3CEB
	ld	(D9BB1),hl
	call	A3CEB
	ld	(D9BB3),hl
	ex	de,hl
	ld	hl,0
	ld	(D9BB7),hl
	ld	a,(D9BBE)
	push	af
	call	A3D48
	ld	hl,(D9BBF)
	ld	de,(D9BB1)
	or	a
	jr	nz,A5BEB
	ld	a,(D9BBE)
	cp	l
	jr	z,A5BD4
	push	hl
	call	A3D48
	pop	hl
	or	a
	jr	nz,A5BEB
A5BD4:	push	hl
	ld	a,(D9BBE)
	cp	l
	ld	hl,(D9BB5)
	ld	(D9BB7),hl
	pop	hl
	jr	z,A5C05
	call	A3D16
	ld	(D9BAF),hl
	jr	A5C05
	;
A5BEB:	ld	a,l
	ld	de,(D9BB3)
	call	A3D48
	or	a
	jr	nz,A5C05
	ld	hl,(D9BB9)
	ld	(D9BB7),hl
	ld	(D9BBB),hl
	ld	hl,(D9BB5)
	ld	(D9BB9),hl
A5C05:	ld	de,(D9BB7)
	pop	bc
	ld	c,b
	pop	hl
	ld	a,e
	or	d
	jr	z,A5C44
	ld	a,c
	and	0C0h
	cp	0C0h
	jr	nz,A5C21
	ld	hl,8
	add	hl,de
	ld	(hl),37h
	jr	A5C27
	;
A5C21:	ld	hl,8
	add	hl,de
	ld	(hl),3Dh
A5C27:	ld	hl,10
	add	hl,de
	ld	a,(D9BBF)
	ld	(hl),a
	dec	hl
	push	de
	ld	(hl),c
	ld	hl,(D9BB9)
	call	A42D8
	pop	hl
	call	A4127
	ld	a,1
	ld	(D9BBD),a
	jp	A5CE5
	;
A5C44:	push	bc
	ld	bc,8
	add	hl,bc
	ld	(hl),54h
	ld	hl,(D9BB9)
	ld	bc,8
	add	hl,bc
	ld	(hl),55h
	ld	a,(D9BBF)
	pop	bc
	push	bc
	ld	hl,(D9BB9)
	ld	(D9BBF),a
	cp	c
	jr	z,A5CAA
	ld	a,c
	and	3Fh
	cp	7
	jr	nz,A5CAA
	ld	a,(D9BBF)
	ld	c,a
	and	1
	jr	z,A5CAA
	push	bc
	push	hl
	ld	de,(D9BB1)
	ld	a,c
	and	3Eh
	or	80h
	call	A3D48
	pop	hl
	pop	bc
	or	a
	jr	z,A5C8D
	ld	bc,8
	add	hl,bc
	ld	(hl),4Ah
	jr	A5CAA
	;
A5C8D:	ld	a,c
	ld	hl,D9BBF
	ld	(hl),c
	call	A6509
	or	40h
	ld	l,a
	push	hl
	ld	a,(D9BBF)
	and	3Eh
	or	80h
	ld	c,a
	ld	hl,(D9BB5)
	ld	e,3Dh
	call	A428C
	pop	bc
A5CAA:	pop	hl
	ld	a,l
	ld	h,l
	push	hl
	ex	af,af'
	ld	a,(D9BBF)
	ld	e,a
	ex	af,af'
	cp	e
	jr	z,A5CDE
	ld	a,l
	and	1
	jr	z,A5CDE
	ld	a,e
	and	3Fh
	cp	7
	jr	nz,A5CDE
	ld	a,l
	and	3Eh
	or	80h
	ld	c,a
	push	bc
	ld	a,l
	call	A6509
	or	40h
	ld	c,a
	ld	hl,(D9BB9)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	e,3Dh
	call	A428C
	pop	bc
A5CDE:	pop	af
	call	A3D16
	ld	(D9BAF),hl
A5CE5:	pop	hl
	push	hl
	ld	bc,8
	add	hl,bc
	ld	a,(hl)
	pop	hl
	push	hl
	cp	57h
	jr	nz,A5D06
	push	hl
	ld	hl,0
	call	A3CD2
	ld	hl,0
	call	A3CD2
	pop	hl
	call	A3CD2
	jr	A5D44
	;
A5D06:	ld	hl,(D9CFE)
A5D09:	ld	bc,-6
	add	hl,bc
	ex	de,hl
	ld	hl,(D9D02)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	c,A5D44
	ld	bc,(D9BBB)
	ld	hl,2
	add	hl,de
	push	de
	ld	de,D9CC8
	call	A4772
	ld	hl,(D9BB5)
	ld	bc,6
	add	hl,bc
	ld	de,(D9BAF)
	ld	a,(hl)
	or	e
	ld	c,a
	inc	hl
	ld	a,(hl)
	or	d
	ld	b,a
	pop	hl
	ld	a,(hl)
	or	c
	ld	(hl),a
	inc	hl
	ld	a,(hl)
	or	b
	ld	(hl),a
	dec	hl
	jr	A5D09
	;
A5D44:	pop	hl
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9BB5),de
	jp	A5B6B
	;
A5D51:	pop	de
	jp	A5B50
	;
A5D55:	ld	a,(D9BBD)
	ret


A5D59:	xor	a
	ld	(D9BC0),a
	ld	l,a
	ld	h,a
	ld	(D9BC5),hl
	ld	de,(D9CEE)
A5D67:	ld	hl,-24
	add	hl,de
	ex	de,hl
	ld	hl,(D9CEC)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	c,A5E43
	ld	hl,2
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9BC1),hl
	push	de
A5D82:	ld	e,l
	ld	d,h
	inc	hl
	inc	hl
	inc	hl
	inc	hl
	bit	7,(hl)
	jp	z,A5E3F
	push	de
	ld	hl,(D9BC5)
A5D91:	ld	a,l
	or	h
	jr	z,A5DB9
	ld	de,(D9BC1)
	push	hl
	ld	bc,12
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A472C
	ex	de,hl
	pop	bc
	ld	hl,12
	add	hl,bc
	ld	(hl),e
	inc	hl
	ld	(hl),d
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	jr	A5D91
	;
A5DB9:	pop	de
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	ld	bc,(D9BC5)
	cp	61h
	jr	z,A5DCE
	cp	60h
	jr	z,A5DE2
	jr	A5E31
	;
A5DCE:	ld	hl,12
	add	hl,de
	ld	(hl),0
	inc	hl
	ld	(hl),0
	inc	hl
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	(D9BC5),de
	jr	A5E31
	;
A5DE2:	ld	hl,14
	add	hl,de
	push	bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9BC3),hl
	ld	bc,12
	add	hl,bc
	pop	bc
	ld	a,(hl)
	inc	hl
	or	(hl)
	jr	nz,A5E31
A5DF8:	ld	hl,(D9BC3)
	ld	a,c
	cp	l
	jr	nz,A5E03
	ld	a,b
	cp	h
	jr	z,A5E13
A5E03:	ld	hl,12
	add	hl,bc
	ld	(hl),0FEh
	inc	hl
	ld	(hl),0FFh
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	jr	A5DF8
	;
A5E13:	push	hl
	ld	bc,14
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	(D9BC5),bc
	ld	hl,8
	add	hl,de
	ld	(hl),56h
	pop	hl
	ld	bc,8
	add	hl,bc
	ld	(hl),57h
	ld	a,1
	ld	(D9BC0),a
A5E31:	ld	hl,2
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9BC1),hl
	jp	A5D82
	;
A5E3F:	pop	de
	jp	A5D67
	;
A5E43:	ld	a,(D9BC0)
	ret


A5E47:	ld	(D9BC7),a
	call	A5080
	ld	de,(D9CEC)
A5E51:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	ld	l,e
	ld	h,d
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9BC8),de
A5E63:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	z,A5EC2
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	push	de
	cp	5Ch
	jr	z,A5E7A
	cp	61h
	jr	nz,A5EB7
A5E7A:	ld	hl,10
	add	hl,de
	ld	a,(hl)
	call	A41FA
	ld	hl,(D9BC7)
	cp	l
	jr	nz,A5EB7
	ld	hl,(D9BC8)
	push	hl
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	and	3Fh
	ld	e,a
	pop	hl
	push	hl
	call	A439F
	pop	bc
	cp	3
	jr	nz,A5EB7
	ld	hl,8
	add	hl,bc
	ld	a,(hl)
	push	bc
	cp	61h
	jr	nz,A5EB3
	ld	hl,14
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A42D8
A5EB3:	pop	hl
	call	A42D8
A5EB7:	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9BC8),de
	jr	A5E63
	;
A5EC2:	pop	de
	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A5E51


A5ECB:	call	A548C
	ld	de,(D9CEC)
A5ED2:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	nc
	ld	hl,18
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9BCA),hl
	ld	hl,2
	add	hl,de
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9BCC),de
A5EF1:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jp	z,A5FAF
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	ld	(D9BCE),a
	push	de
	cp	58h
	jr	nz,A5F2E
	ld	hl,9
	add	hl,de
	ld	a,(hl)
	call	A41FA
	ld	b,a
	ld	hl,1
	call	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	ld	de,(D9BCA)
	ld	a,l
	and	e
	ld	l,a
	ld	a,h
	and	d
	ld	h,a
	ld	a,l
	or	h
	jr	nz,A5F2E
	ld	hl,(D9BCC)
	call	A42D8
	jr	A5FA2
	;
A5F2E:	ld	a,(D9BCE)
	cp	58h
	jr	nz,A5F59
	ld	hl,(D9BCC)
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	call	A41FA
	ld	b,a
	ld	hl,1
	call	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	ld	bc,(D9BCA)
	ld	a,l
	cpl
	and	c
	ld	l,a
	ld	a,h
	cpl
	and	b
	jr	A5F78
	;
A5F59:	cp	5Ch
	jr	nz,A5F7F
	ld	hl,(D9BCC)
	ld	bc,10
	add	hl,bc
	ld	a,(hl)
	call	A41FA
	ld	b,a
	ld	hl,1
	call	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	ld	de,(D9BCA)
	ld	a,e
	or	l
	ld	l,a
	ld	a,d
	or	h
A5F78:	ld	h,a
	ld	(D9BCA),hl
	jr	A5FA2
	;
A5F7F:	cp	63h
	jr	nz,A5FA2
	ld	hl,(D9BCC)
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	call	A41FA
	ld	b,a
	ld	hl,1
	call	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	ld	de,(D9BCA)
	ld	a,e
	or	l
	ld	l,a
	ld	a,d
	or	h
	ld	h,a
	ld	(D9BCA),hl
A5FA2:	pop	hl
	inc	hl
	inc	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9BCC),de
	jp	A5EF1
	;
A5FAF:	pop	de
	ld	hl,24
	add	hl,de
	ex	de,hl
	jp	A5ED2


A5FB8:	call	A53FC
	ld	de,(D9CEE)
A5FBF:	ld	hl,-24
	add	hl,de
	ex	de,hl
	ld	hl,(D9CEC)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	c
	ld	hl,18
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(D9BCF),hl
	ld	hl,2
	add	hl,de
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A5FDF:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jp	z,A6099
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	push	de
	cp	63h
	jr	nz,A600D
	inc	hl
	ld	a,(hl)
	push	de
	call	A41FA
	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C78
	add	hl,bc
	ld	(hl),1
	pop	hl
	call	A42D8
	jr	A6078
	;
A600D:	ld	hl,9
A6010:	add	hl,de
	cp	58h
	jr	z,A601B
	inc	hl
	cp	5Ch
	jr	nz,A6078
A601B:	ld	(D9BD1),de
	ld	a,(hl)
	push	hl
	call	A41FA
	ld	l,a
	ld	h,0
	ld	c,a
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C75
	add	hl,bc
	push	hl
	inc	hl
	inc	hl
	inc	hl
	ld	(hl),1
	pop	hl
	push	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	de,(D9BD1)
	ld	hl,14
	add	hl,de
	ld	(hl),c
	inc	hl
	ld	(hl),b
	ld	hl,12
	add	hl,de
	ld	(hl),0
	inc	hl
	ld	(hl),0
	pop	hl
	inc	hl
	inc	hl
	ld	a,(hl)
	or	a
	jr	nz,A6061
	ld	hl,8
	add	hl,de
	inc	(hl)
	inc	(hl)
A6061:	ld	a,(D9CCD)
	pop	hl
	or	a
	jr	z,A606E			; false
	ld	a,13h
	ld	(hl),a
	jr	A6078
	;
A606E:	push	hl
	ld	hl,8
	add	hl,de
	inc	(hl)
	ld	a,12h
	pop	hl
	ld	(hl),a
A6078:	pop	bc
	ld	hl,6
	add	hl,bc
	ld	de,(D9BCF)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,D9BCF
	ld	de,D9CC8
	push	bc
	call	A4772
	pop	bc
	ld	hl,2
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jp	A5FDF
	;
A6099:	pop	de
	jp	A5FBF


A609D:	ld	bc,(D9CEE)
A60A1:	ld	hl,-24
	add	hl,bc
	ex	de,hl
	ld	hl,(D9CEC)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ret	c
	ld	hl,2
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	(D9BD3),bc
	push	de
A60BA:	ld	hl,4
	add	hl,bc
	bit	7,(hl)
	jr	z,A612D
	ld	hl,8
	add	hl,bc
	ld	a,(hl)
	push	bc
	cp	37h
	jr	z,A60D4
	cp	3Dh
	jr	z,A6110
	jr	A6120
	;
A60D4:	ld	hl,10
	add	hl,bc
	ld	e,(hl)
	dec	hl
	ld	a,(hl)
	push	bc
	call	A41A5
	pop	hl
	or	a
	jr	z,A60E9
	dec	a
	jr	z,A60EF
	jr	A6120
	;
A60E9:	call	A42D8
	jr	A6120
	;
A60EF:	ld	hl,6
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,10
	add	hl,bc
	ld	a,(hl)
	call	A3D48
	or	a
	jr	nz,A6120
	ld	bc,(D9BD3)
	ld	hl,8
	add	hl,bc
	ld	(hl),62h
	jr	A6120
	;
A6110:	ld	hl,10
	add	hl,bc
	ld	e,(hl)
	dec	hl
	ld	a,(hl)
	push	bc
	call	A41C9
	pop	hl
	or	a
	call	z,A42D8
A6120:	pop	hl
	inc	hl
	inc	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	(D9BD3),bc
	jr	A60BA
	;
A612D:	pop	bc
	jp	A60A1


A6131:	ld	a,(D9CC5)
	or	a
	jr	z,A61B1
	ld	hl,T9BD5		; ds 16
	call	A43F7
	ld	a,(D9CC5)
A6141:	dec	a
	cp	0FFh
	jr	z,A6194
	ld	l,a
	ld	h,0
	ld	bc,T9BD5		; ds 16
	add	hl,bc
	push	af
	ld	e,(hl)
	ld	l,e
	ld	h,0
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C79
	add	hl,bc
	ld	a,(hl)
	inc	a
	jr	z,A6190
	ld	a,e
	ld	d,e
	push	de
	call	A41F3
	ld	e,a
	pop	af
	ld	(D9BE5),a
	call	A4201
	ld	c,a
	push	bc
	ld	hl,(D9BE5)
	ld	h,0
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,T9C77
	add	hl,bc
	ld	c,a
	ld	a,(hl)
	or	a
	ld	a,37h
	jr	nz,A6188
	ld	a,3Dh
A6188:	ld	e,a
	ld	hl,(D9CEC)
	call	A428C
	pop	bc
A6190:	pop	af
	jr	A6141
	;
A6194:	xor	a
A6195:	ld	hl,D9CC5
	cp	(hl)
	jr	nc,A61B1
	push	af
	ld	l,a
	ld	h,0
	ld	bc,T9BD5		; ds 16
	add	hl,bc
	ld	a,(hl)
	call	A5986			; оптимизация кода ??
	ld	a,"+"			; вывод на экран (для ---+++;)
	call	A77B0			; тест на нажатие Esc и вывод "a" на экран
	pop	af
	inc	a
	jr	A6195
	;
A61B1:	ld	a,";"			; вывод на экран (для ---+++;)
	call	A77B0			; тест на нажатие Esc и вывод "a" на экран
	xor	a
A61B7:	ld	hl,D9CC5
	cp	(hl)
	jr	nc,A61CE
	ld	l,a
	ld	h,0
	ld	bc,T9BD5		; ds 16
	add	hl,bc
	push	af
	ld	a,(hl)
	call	A5E47
	pop	af
	inc	a
	jr	A61B7
	;
A61CE:	call	A5B3F
	or	a
	jr	z,A61DA
	call	A5D59
	or	a
	jr	nz,A61CE
A61DA:	ld	de,(D9CEC)
A61DE:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,A621C
	ld	l,e
	ld	h,d
	push	de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
A61ED:	ld	hl,4
	add	hl,de
	bit	7,(hl)
	jr	z,A6213
	ld	hl,8
	add	hl,de
	ld	a,(hl)
	cp	60h
	jr	nz,A6200
	ld	(hl),58h
A6200:	ld	hl,8
	add	hl,de
	ld	a,(hl)
	cp	61h
	jr	nz,A620C
	ld	(hl),5Ch
A620C:	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	jr	A61ED
	;
A6213:	pop	de
	ld	hl,24
	add	hl,de
	ex	de,hl
	jr	A61DE
	;
A621C:	call	A5ECB
	call	A5FB8
	jp	A609D



;[]==============================================================[]
;  Записать asm-строку в вых. файл
;
A6225:	ld	ix,4
	add	ix,sp
	ld	l,(ix-2)
	ld	h,(ix-1)
A6231:	ld	a,(hl)
	inc	hl
	ld	(D9BEE),a
	or	a
	ret	z
	push	hl
	cp	"A"			; записать мнемонику "add"
	jp	z,A6352
	cp	"R"			; записать имя 8-bit регистра или "(hl)"
	jr	z,A627D
	cp	"P"			; записать имя рег.пары
	jr	z,A62A4
	cp	"D"			; записать десят. число (макс. 65535)
	jp	z,A62C0
	cp	"L"			; записать число мл.разряда (макс. 255)
	jp	z,A62CE
	cp	"H"			; записать число ст.разряда (макс. 255)
	jp	z,A62DB
	cp	"S"			; записать текст. строку в вых. файл
	jp	z,A62E8
	cp	"M"			; записать имя переменной (функция, массив и т.д.)
	jp	z,A62F6
	cp	"C"			; записать символ
	jp	z,A632B
	cp	"N"			; записать Tab
	jp	z,A6336
	cp	"Z"			; записать мнемонику "ld"
	jp	z,A6344
	cp	"X"			; записать мнемонику "inc hl"
	jp	z,A6360
	cp	"Y"			; записать мнемонику "dec hl"
	jp	z,A6360
	; default
	jp	A63A8
	;
	; "R" записать букву 8-bit регистра или "(hl)"
A627D:	ld	a,(ix+0)
	push	ix
	and	7			; макс. число регистров
	ld	l,a
	ld	h,0
	ld	bc,T6467		; "bcdehlma", список 8-bit регистров
	add	hl,bc
	ld	a,(hl)
	cp	"m"			; (m)emory
	jr	z,A6296
	call	A7808			; запись мнемоники в вых. файл
	jp	A63B3
	;
A6296:	ld	hl,T629F		; "(hl)"
	call	A7866			; записать текст. строку в вых. файл
	jp	A63B3
	;
T629F:	db	"(hl)",0
	;
	; "P" записать имя рег.пары
A62A4:	ld	a,(ix+0)
	push	ix
	and	6			; огран. число
	ld	l,a
	ld	h,0
	ld	bc,T6470		; "bcdehlsp", список рег.пар
	add	hl,bc
	ld	a,(hl)
	push	hl
	call	A7808			; запись мнемоники в вых. файл
	pop	hl
	inc	hl
	ld	a,(hl)
	call	A7808			; запись мнемоники в вых. файл
	jp	A63B3
	;
	; "D" записать десят. число (макс. 65535)
A62C0:	ld	l,(ix+0)
	ld	h,(ix+1)
	push	ix
	call	A7873			; вывод в буфер десят. числа
	jp	A63B3
	;
	; "L"(ow) записать число мл. разряда (макс. 255)
A62CE:	ld	l,(ix+0)
	ld	h,0
	push	ix
	call	A7873			; вывод в буфер десят. числа
	jp	A63B3
	;
	; "H"(igh) записать число ст. разряда (макс. 255)
A62DB:	ld	l,(ix+1)
	ld	h,0
	push	ix
	call	A7873			; вывод в буфер десят. числа
	jp	A63B3
	;
	; "S" записать строку в вых. файл
A62E8:	ld	l,(ix+0)
	ld	h,(ix+1)
	push	ix
	call	A7866			; записать текст. строку в вых. файл
	jp	A63B3
	;
	; "M" записать имя переменной (функция, массив и т.д.)
A62F6:	ld	c,(ix+0)
	ld	b,(ix+1)
	push	ix
	ld	a,(bc)
	ld	(D9BEE),a
A6302:	ld	a,(bc)
	or	a
	jr	z,A631A
	cp	"_"			; постфикс всех имен
	ld	a,(D9BE6)		; символ постфикса имен asm-листинга
	jr	z,A6311
	ld	a,(bc)
A6311:	push	bc
	call	A7808			; запись имени переменной в вых. файл
	pop	bc
	inc	bc
	jr	A6302
	;
A631A:	ld	a,(D9BEE)
	cp	"?"			; 3Fh
	jp	z,A63B3
	ld	a,(D9BE6)		; символ постфикса имен
	call	A7808			; запись мнемоники в вых. файл
	jp	A63B3
	;
	; "C" записать символ
A632B:	ld	a,(ix+0)
	push	ix
	call	A7808			; запись мнемоники в вых. файл
	jp	A63B3
	;
	; "N" записать Tab
A6336:	ld	hl,T647F		; Tab
	push	ix
	call	A7866			; записать Tab в вых. файл
	pop	ix
	pop	hl
	jp	A6231
	;
	; "Z" записать мнемонику "ld"
A6344:	ld	hl,T6479		; "ld	"
	push	ix
	call	A7866			; записать текст. строку в вых. файл
	pop	ix
	pop	hl
	jp	A6231
	;
	; "A" записать мнемонику "add"
A6352:	ld	hl,T6482		; "add"
	push	ix
	call	A7866			; записать текст. строку в вых. файл
	pop	ix
	pop	hl
	jp	A6231			; назад в цикл
	;
	; "X", "Y" записать соотв. мнемоники "inc hl" и "dec hl"
A6360:	ld	c,(ix+0)
	ld	b,(ix+1)
	push	ix
	ld	hl,9
	add	hl,bc
	ld	a,(hl)
	cp	0C6h
	jr	z,A6386
	ld	hl,10
	add	hl,bc
	ld	a,(hl)
	cp	0C6h
	jr	z,A6386
	ld	hl,11
	add	hl,bc
	ld	a,(hl)
	cp	0C6h
	jr	nz,A63B3
A6386:	ld	a,(D9BEE)
	cp	"X"			; 58h
	jr	nz,A639B
	ld	hl,T63BD		; "inc	hl"
	call	A7866			; записать строку в вых. файл
	ld	hl,D9BEB
	inc	(hl)
	jr	A63B3
	;
A639B:	ld	hl,T63C6		; "dec	hl"
	call	A7866			; записать строку в вых. файл
	ld	hl,D9BEB
	dec	(hl)
	jr	A63B3
	;
	; default
A63A8:	push	ix
	call	A7808			; запись мнемоники в вых. файл
	pop	ix
	pop	hl
	jp	A6231			; назад в цикл
	;
A63B3:	pop	ix
	inc	ix
	inc	ix
	pop	hl
	jp	A6231			; назад в цикл



T63BD:	db	0Ah,9,"inc",9,"hl",0
T63C6:	db	0Ah,9,"dec",9,"hl",0


T63CF:	db	"Ze,(hl)"		; "	ld	e,(hl)"
	db	"Ninc",9,"hl"		; "	inc	hl"
	db	"Zd,(hl)",0		; "	ld	d,(hl)"

T63E5:	db	"Z(hl),d"		; "	ld	(hl),d"
	db	"Ndec",9,"hl"		; "	dec	hl"
	db	"Z(hl),e",0		; "	ld	(hl),e"

T63FB:	db	"Ninc",9,"de",0		; "	inc	de"
T6403:	db	"ZR,R",0		; "	ld	рег,рег" 8/8 битные
T6408:	db	"Ninc",9,"a",0		; "	inc	a"
T640F:	db	"Ndec",9,"a",0		; "	dec	a"
T6416:	db	"Ninc",9,"R",0		; "	inc	рег"  8-bit
T641D:	db	"Ndec",9,"R",0		; "	dec	рег"  8-bit
T6424:	db	"Za,R",0		; "	ld	a,рег"
T6429:	db	"ZR,a",0		; "	ld	рег,a"
T642E:	db	"Nand",9,"L",0		; "	and	мл.число"
T6435:	db	"Aa,L",0		; "	add	a,мл.число"
T643A:	db	"Nsub",9,"L",0		; "	sub	мл.число"
T6441:	db	"Aa,a",0		; "	add	a,a"
T6446:	db	"Ahl,hl",0		; "	add	hl,hl"
T644D:	db	"Zh,lZl,0",0		; "	ld	h,l : ld    l,0"
T6456:	db	"Nrrca",0		; "	rrca"
T645C:	db	"Nxor",9,"a",0		; "	xor	a"
T6463:	db	"X",0			; означает "	inc	hl"
T6465:	db	"Y",0			; означает "	dec	hl"
	;
T6467:	db	"bcdehlma",0		; список 8-bit регистров
T6470:	db	"bcdehlsp",0		; список 16-bit регистров
	;
T6479:	db	0Ah,9,"ld",9,0
T647F:	db	0Ah,9,0
T6482:	db	0Ah,9,"add",9,0




A6489:	push	hl
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	ret


A648F:	ld	a,l
	rla
	sbc	a,a
	ld	h,a
	ret


A6494:	call	A648F
	jp	A9461


A649A:	ld	a,h
	or	a
	ret	z
	inc	a
	ret	z
	ld	a,true
	ret


A64A2:	call	A649A
	or	a
	jp	z,A648F
	ld	(D9BF1),hl
	call	A9461
	push	hl
	ld	hl,(D9BF1)
	inc	h
	dec	h
	ld	hl,T64E5		; 0
	jp	p,A64BF
	ld	hl,T64E4		; "-"
A64BF:	push	hl
	ld	bc,T64D0		; "Ehuge char SD in F"   warning-строка
	push	bc
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	pop	bc
	pop	bc
	pop	bc
	ld	hl,(D9BF1)
	jp	A648F
	;
T64D0:	db	"Ehuge char SD in F",0Ah,0
	;
T64E4:	db	"-"			; 2Dh
T64E5:	db	0


A64E6:	ld	c,h
	ld	b,0
	ld	(D9BF3),bc
	ld	a,l
	sub	81h
	ld	a,h
	sbc	a,0
	jr	c,.loc1
	inc	bc
	ld	(D9BF3),bc
.loc1:	call	A6494
	push	hl
	ld	hl,(D9BF3)
	call	A6494
	pop	de
	add	hl,de
	ret


A6509:	ld	l,a
	and	3Fh
	sub	6
	cp	2
	jr	nc,.loc1
	ld	a,l
	ret
.loc1:	ld	a,l
	or	1
	ret


A6518:	ld	c,l
	ld	b,h
	ld	de,(D9CF2)
.loc1:	ld	hl,(D9CF0)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	nc,.loc3
	ld	hl,1
	add	hl,de
	ld	a,(hl)
	cp	c
	inc	hl
	jr	nz,.loc2
	ld	a,(hl)
	cp	b
	jr	nz,.loc2
	ld	hl,3
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret
.loc2:	ld	hl,6
	add	hl,de
	ex	de,hl
	jr	.loc1
	;
.loc3:	ld	hl,T654B
	jp	A75DA			; вывод строки "hl" (большие буквы зарез.)
	;
T654B:	db	"?gtoffP",0		; "?gtoff<рег.пара>"  имя библ. функции


A6553:	ld	e,0
A6555:	ld	a,e
	cp	5
	jr	nc,A6588
	push	de
	ld	a,l
	and	3
	ld	(D9BF5),hl
	jr	z,A6577
	ld	c,e
	push	bc
	ld	bc,T65DB		; "push  рег.пара"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ld	hl,(D9BE9)
	inc	hl
	inc	hl
	ld	(D9BE9),hl
A6577:	pop	de
	inc	e
	inc	e
	ld	hl,(D9BF5)
	srl	h
	rr	l
	srl	h
	rr	l
	jr	A6555
	;
A6588:	ld	a,l
	and	2
	ret	z
	ld	hl,T65E3		; ""
	call	A6489			; записать asm-строку в вых. файл
	ld	hl,(D9BE9)
	inc	hl
	inc	hl
	ld	(D9BE9),hl
	ret


A659B:	bit	7,l
	push	hl
	jr	z,A65AE
	ld	hl,T65EC		; ""
	call	A6489			; записать asm-строку в вых. файл
	ld	hl,(D9BE9)
	dec	hl
	dec	hl
	ld	(D9BE9),hl
A65AE:	ld	c,4
	pop	hl
A65B1:	ld	a,c
	cp	0FEh
	ret	z
	push	bc
	ld	a,l
	and	30h
	ld	(D9BF7),hl
	jr	z,A65D0
	push	bc
	ld	bc,T65F4		; "pop  рег.пара"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ld	hl,(D9BE9)
	dec	hl
	dec	hl
	ld	(D9BE9),hl
A65D0:	pop	bc
	dec	c
	dec	c
	ld	hl,(D9BF7)
	add	hl,hl
	add	hl,hl
	jr	A65B1


T65DB:	db	"Npush",9,"P",0		; "	push	рег.пара"
T65E3:	db	"Npush",9,"af",0	; "	push	af"
T65EC:	db	"Npop",9,"af",0		; "	pop	af"
T65F4:	db	"Npop",9,"P",0		; "	pop	рег.пара"


A65FB:	inc	e
	dec	e
	jr	z,.loc1
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ret
.loc1:	inc	hl
	inc	hl
	inc	hl
	ret


A660A:	ld	(D9BFB),de
	cp	0B0h
	jr	z,A665C
	cp	0A8h
	jr	z,A6667
	cp	0ACh
	jr	z,A667C
	cp	94h
	jr	z,A668E
	cp	0A1h
	jr	z,A6695
	cp	0A4h
	jp	z,A66C3
	cp	0A2h
	jp	z,A66EA
	cp	96h
	jp	z,A6700
	cp	95h
	jp	z,A671A
	cp	97h
	jp	z,A6733
	cp	98h
	jp	z,A673C
	cp	99h
	jp	z,A6745
	cp	0A0h
	jp	z,A6756
	cp	0A5h
	jp	z,A6761
	cp	0A6h
	jp	z,A677D
	jp	A7808			; запись мнемоники в вых. файл
	;
A665C:	ld	hl,12
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A64A2
A6667:	ld	hl,(D9BFB)
	ld	bc,12
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,T6799		; число мл.разряда (макс. 255)
	push	bc
	call	A6225			; записать asm-строку (число) в вых. файл
	pop	bc
	pop	bc
	ret
	;
A667C:	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,T679B		; число ст.разряда (макс. 255)
	push	bc
	call	A6225			; записать asm-строку (число) в вых. файл
	pop	bc
	pop	bc
	ret
	;
A668E:	ld	hl,T679D		; "N"  Tab
	jp	A6489			; записать asm-строку в вых. файл
	;
A6695:	ld	hl,12
	add	hl,de
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	de
	call	A649A
	pop	bc
	or	a
	jr	nz,A66B2		; true
	ld	hl,(D9BF9)
	ld	a,(hl)
	ld	hl,12
	add	hl,bc
	cp	(hl)
	jr	z,A66B7
A66B2:	ld	a,1
	jr	A66B8
	;
A66B7:	xor	a
A66B8:	ld	e,a
	ld	hl,(D9BF9)
	call	A65FB
	ld	(D9BF9),hl
	ret
	;
A66C3:	ld	hl,(D9BF9)
	ld	c,(hl)
	ld	b,0
	ld	hl,6
	add	hl,de
	ld	a,c
	and	(hl)
	ld	c,a
	inc	hl
	ld	a,b
	and	(hl)
	ld	b,a
	ld	a,c
	or	b
	ld	a,1
	jr	z,A66DF
	xor	a
A66DF:	ld	e,a
	ld	hl,(D9BF9)
	call	A65FB
	ld	(D9BF9),hl
	ret
	;
A66EA:	ld	hl,T66F7
	push	hl
	ld	hl,(D9BF9)
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ex	de,hl
	ret
	;
T66F7:	ld	hl,(D9BF9)
	inc	hl
	inc	hl
	ld	(D9BF9),hl
	ret
	;
A6700:	ld	hl,12
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A6518
	pop	de
	add	hl,de
	ld	de,(D9BE9)
	add	hl,de
	jp	A7873			; вывод в буфер десят. числа
	;
A671A:	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,6
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,T679F		; метка "@число"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ret
	;
A6733:	ld	hl,(D9BE9)
	inc	hl
	inc	hl
	jr	A6741
	;
A673C:	ld	hl,(D9BE9)
	dec	hl
	dec	hl
A6741:	ld	(D9BE9),hl
	ret
	;
A6745:	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(D9BE9)
	or	a
	sbc	hl,bc
	ld	(D9BE9),hl
	ret
	;
A6756:	push	de
	ld	bc,T6463		; "inc hl"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ret
	;
A6761:	ld	hl,(D9BF9)
	inc	hl
	ld	(D9BF9),hl
	dec	hl
	ld	c,e
	ld	b,d
	ld	e,(hl)
	ld	d,0
	ld	hl,6
	add	hl,bc
	ld	a,e
	and	(hl)
	ld	e,a
	inc	hl
	ld	a,d
	and	(hl)
	ld	d,a
	ex	de,hl
	jp	A6553
	;
A677D:	ld	hl,(D9BF9)
	inc	hl
	ld	(D9BF9),hl
	dec	hl
	ld	c,e
	ld	b,d
	ld	e,(hl)
	ld	d,0
	ld	hl,6
	add	hl,bc
	ld	a,e
	and	(hl)
	ld	e,a
	inc	hl
	ld	a,d
	and	(hl)
	ld	d,a
	ex	de,hl
	jp	A659B


T6799:	db	"L",0			; число мл.разряда (макс. 255)
T679B:	db	"H",0			; число ст.разряда (макс. 255)
T679D:	db	"N",0			; Tab (табуляция)
T679F:	db	"@D",0			; "@число"  метка
T67A2:	db	"R",0			; имя 8-bit регистра
T67A4:	db	"af",0
T67A7:	db	"bcdehlaf",0		; список имен рег.пар
	;
T67B0:	db	"?expand at W: (B)P",0


; Список имен флагов z80
T67C3:	db	"nz",0
	db	"z",0,0
	db	"nc",0
	db	"c",0,0
	db	"po",0
	db	"pe",0
	db	"p",0,0
	db	"m",0,0


A67DB:	ld	c,l
	ld	b,h
	ld	(D9BFF),de
A67E1:	ld	hl,(D9BFF)
	ld	a,(hl)
	and	0FCh
	cp	0FCh
	jp	z,A6924
	ld	a,(hl)
	and	3
	push	bc
	push	hl
	ld	l,a
	ld	h,0
	add	hl,bc
	ld	(D9BFD),bc
	ld	bc,9
	add	hl,bc
	ld	(D9C01),hl
	pop	hl
	ld	a,(hl)
	inc	hl
	ld	(D9BFF),hl
	pop	de
	cp	80h
	jr	z,A6864
	cp	81h
	jr	z,A6864
	cp	82h
	jr	z,A6864
	cp	84h
	jr	z,A6875
	cp	85h
	jr	z,A6875
	cp	86h
	jr	z,A6875
	cp	88h
	jr	z,A6890
	cp	89h
	jr	z,A6890
	cp	8Ah
	jr	z,A6890
	cp	8Ch
	jr	z,A68A5
	cp	8Dh
	jr	z,A68A5
	cp	8Eh
	jr	z,A68A5
	cp	90h
	jp	z,A68DE			; записать имя флага z80 в вых. файл
	cp	91h
	jp	z,A68DE			; записать имя флага z80 в вых. файл
	cp	92h
	jp	z,A68DE			; записать имя флага z80 в вых. файл
	cp	9Ch
	jp	z,A68F6
	cp	9Dh
	jp	z,A68F6
	cp	9Eh
	jp	z,A68F6
	jp	A6911
	;
A6864:	ld	hl,(D9C01)
	ld	c,(hl)
	push	bc
	ld	bc,T67A2		; "рег."
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	jp	A691D
	;
A6875:	ld	hl,(D9C01)
	ld	a,(hl)
	and	3Eh
	ld	l,a
	ld	h,0
	ld	bc,T67A7		; "bcdehlaf" список рег.пар
	add	hl,bc
	ld	a,(hl)
	push	hl
	call	A7808			; запись мнемоники в вых. файл
	pop	hl
	inc	hl
	ld	a,(hl)
	call	A7808			; запись мнемоники в вых. файл
	jp	A691D
	;
A6890:	ld	hl,(D9C01)
	ld	a,(hl)
	call	A6509
	ld	l,a
	push	hl
	ld	bc,T67A2		; "рег."
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	jr	A691D
	;
A68A5:	ld	hl,(D9C01)
	ld	a,(hl)
	and	3Fh
	cp	10h
	jr	nc,A68C5
	ld	de,(D9BFD)
	ld	hl,8
	add	hl,de
	ld	l,(hl)
	push	hl
	push	de
	ld	bc,T67B0		; "?expand at W: (B)P"
	push	bc
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	pop	bc
	pop	bc
	pop	bc
A68C5:	ld	de,(D9BFD)
	ld	hl,15
	add	hl,de
	ld	b,(hl)
	dec	hl
	ld	c,(hl)
	dec	hl
	ld	d,(hl)
	dec	hl
	ld	e,(hl)
	ld	hl,(D9C01)
	ld	a,(hl)
	call	A0BDF
	jr	A691D
	;
; записать имя флага z80 в вых. файл
A68DE:	ld	hl,T67C3		; список имен флагов z80
	ld	de,(D9C01)
	ld	a,(de)
	and	3Fh
	sub	8			; число флагов
	ld	c,a			; индекс в списке
	ld	b,0
	add	hl,bc
	add	hl,bc
	add	hl,bc
	call	A7866			; записать имя флага в вых. файл
	jr	A691D
	;
A68F6:	ld	de,(D9C01)
	ld	a,(de)
	and	7
	cp	(hl)
	ld	a,1
	jr	z,A6907
	xor	a
A6907:	ld	e,a
	call	A65FB
	ld	(D9BFF),hl
	jr	A691D
	;
A6911:	ld	(D9BF9),hl
	call	A660A
	ld	hl,(D9BF9)
	ld	(D9BFF),hl
A691D:	ld	bc,(D9BFD)
	jp	A67E1
	;
A6924:	ld	a,(hl)
	cp	0FEh
	jr	z,A6930
	cp	0FDh
	ret	nz
	ld	a,(D9BEC)
	ld	(D9BED),a
	ret
A6930:	ld	a,7
	ld	(D9BED),a
	ret


T693D:	db	"Ndec",9,"de",0		; "	dec	de"

T6945:	db	"Ze,(hl)"		; "	ld	e,(hl)"
	db	"Za,e"			; "	ld	a,e"
	db	"Aa,L"			; "	ld	a,мл.число"
	db	"Z(hl),a"		; "	ld	(hl),a"
	db	"Ninc",9,"hl"		; "	inc	hl"
	db	"Zd,(hl)"		; "	ld	d,(hl)"
	db	"Za,d"			; "	ld	a,d"
	db	"Nadc",9,"a,H"		; "	adc	a,ст.число"
	db	"Z(hl),a"		; "	ld	(hl),a"
	db	0

L697D:	ld	bc,12
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	l,c
	ld	h,b
	ld	(D9C03),hl
	ld	a,c
	sub	3
	ld	a,b
	sbc	a,0
	jr	nc,A69D0
	ld	hl,T63CF		; ""
	call	A6489			; записать asm-строку в вых. файл
	ld	hl,0
A699B:	ld	de,(D9C03)
	ld	a,l
	sub	e
	ld	a,h
	sbc	a,d
	jr	nc,A69B2
	push	hl
	ld	hl,T63FB		; ""
	call	A6489			; записать asm-строку в вых. файл
	pop	hl
	inc	hl
	jr	A699B
	;
A69B2:	ld	hl,T63E5		; ""
	call	A6489			; записать asm-строку в вых. файл
	ld	hl,0
A69BB:	ld	de,(D9C03)
	ld	a,l
	sub	e
	ld	a,h
	sbc	a,d
	ret	nc
	push	hl
	ld	hl,T693D		; ""
	call	A6489			; записать asm-строку в вых. файл
	pop	hl
	inc	hl
	jr	A69BB
	;
A69D0:	push	bc
	push	bc
	ld	bc,T6945		; машинная "идиома"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret


T69DD:	db	"Za,(hl)"		; "	ld	a,(hl)"
	db	"Aa,L"			; "	add	a,мл.число"
	db	"Z(hl),a"		; "	ld	(hl),a"
	db	"Ninc",9,"hl"		; "	inc	hl"
	db	"Za,(hl)"		; "	ld	a,(hl)"
	db	"Nadc",9,"a,H"		; "	adc	a,ст.число"
	db	"Z(hl),a"		; "	ld	(hl),a"
	db	0

L6A0D:	ld	bc,12
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a,c
	sub	3
	ld	a,b
	sbc	a,0
	jr	nc,A6A3D
	ld	hl,T63CF		; ""
	push	bc
	call	A6489			; записать asm-строку в вых. файл
	pop	bc
A6A25:	ld	a,c
	or	b
	jr	z,A6A36
	ld	hl,T63FB		; ""
	push	bc
	call	A6489			; записать asm-строку в вых. файл
	pop	bc
	dec	bc
	jr	A6A25
	;
A6A36:	ld	hl,T63E5		; ""
	jp	A6489			; записать asm-строку в вых. файл
	;
A6A3D:	push	bc
	push	bc
	ld	bc,T69DD		; машинная "идиома"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret


L6A4A:	ld	e,4
	jr	A6A5A
L6A4E:	ld	c,l
	ld	b,h
	ld	hl,10
	add	hl,bc
	ld	a,(hl)
	and	3Fh
	ld	e,a
	ld	l,c
	ld	h,b
A6A5A:	push	de
	call	A6A9C
	pop	de
	push	hl
	push	de
	push	hl
	ld	a,e
	call	A6509
	ld	e,a
	pop	hl
	call	A6A82
	pop	de
	pop	hl
	inc	hl
	jp	A6A82


L6A71:	ld	c,l
	ld	b,h
	ld	hl,10
	add	hl,bc
	ld	a,(hl)
	and	3Fh
	ld	e,a
	ld	l,c
	ld	h,b
	push	de
	call	A6A9C
	pop	de
A6A82:	push	de
	bit	7,h
	ld	c,"+"			; 2Bh
	jr	z,A6A8E
	ld	c,"-"			; для "(ix/iy-число)"
	xor	a
	sub	l
	ld	l,a
A6A8E:	push	hl
	push	bc
	ld	bc,T6B08		; "ld	(ix-,+мл.число),рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret
	;
A6A9C:	ld	bc,12
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	push	de
	inc	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A6518
	pop	de
	add	hl,de
	ld	de,(D9BE7)
	or	a
	sbc	hl,de
	ret


L6AB6:	ld	e,4
	jr	A6AC6
L6ABA:	ld	c,l
	ld	b,h
	ld	hl,9
	add	hl,bc
	ld	a,(hl)
	and	3Fh
	ld	e,a
	ld	l,c
	ld	h,b
A6AC6:	push	de
	call	A6A9C
	pop	de
	push	hl
	push	de
	push	hl
	ld	a,e
	call	A6509
	ld	e,a
	pop	hl
	call	A6AEE
	pop	de
	pop	hl
	inc	hl
	jp	A6AEE


L6ADD:	ld	c,l
	ld	b,h
	ld	hl,9
	add	hl,bc
	ld	a,(hl)
	and	3Fh
	ld	e,a
	ld	l,c
	ld	h,b
	push	de
	call	A6A9C
	pop	de
A6AEE:	bit	7,h
	ld	c,"+"
	jr	z,A6AF9
	ld	c,"-"			; для "(ix/iy-число)"
	xor	a
	sub	l
	ld	l,a
A6AF9:	push	hl
	push	bc
	push	de
	ld	bc,T6B12		; "ld	рег,(ix-,+мл.число)"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret

T6B08:	db	"Z(ixCL),R",0		; "	ld	(ix-,+мл.число),рег"
T6B12:	db	"ZR,(ixCL)",0		; "	ld	рег,(ix-,+мл.число)"


L6B1C:	ex	de,hl
	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	c
	dec	c
	jr	nz,A6B3D
	push	bc
	ld	hl,10
	add	hl,de
	ld	l,(hl)
	push	hl
	push	de
	ld	bc,T6B5E		; "inc	hl : ld  a,рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret
	;
A6B3D:	push	bc
	ld	hl,10
	add	hl,de
	ld	l,(hl)
	push	hl
	push	de
	push	bc
	ld	hl,10
	add	hl,de
	ld	a,(hl)
	call	A6509
	ld	l,a
	push	hl
	ld	bc,T6B69		; машинная "идиома"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret
	;
T6B5E:	db	"XZa,R"			; "	inc	hl : ld    a,рег"
	db	"Ncp",9,"H"		; "	cp	ст.число"
	db	0
	;
T6B69:	db	"Za,R"			; "	ld	a,рег"
	db	"Nsub",9,"L"		; "	sub	мл.число"
	db	"XZa,R"			; "	inc	hl : ld    a,рег"
	db	"Nsbc",9,"a,H"		; "	sbc	a,ст.число"
	db	0


L6B81:	ld	(D9C05),hl
	push	hl
	ld	bc,12
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	pop	hl
	push	hl
	ld	l,c
	ld	h,b
	ld	(D9C07),hl
	pop	hl
	push	bc
	ld	bc,10
	add	hl,bc
	ld	a,(hl)
	ld	(D9C0B),a
	ex	af,af'
	ld	a,1
	ld	(D9C0E),a
	ld	hl,(D9C07)
	ld	c,l
	ld	b,0
	ld	(D9C09),bc
	ex	af,af'
	ld	(D9C0C),a
	call	A6509
	ld	(D9C0D),a
	pop	bc
	ld	a,b
	or	a
	jr	z,A6BDC
	xor	a
	ld	(D9C0E),a
	push	bc
	ld	c,b
	ld	b,a ;0
	ld	l,c
	ld	h,b
	ld	(D9C09),hl
	ld	a,(D9C0B)
	ld	(D9C0D),a
	call	A6509
	ld	(D9C0C),a
	pop	bc
	inc	c
	dec	c
	jp	nz,A6C63
A6BDC:	ld	a,(D9C0E)
	push	af
	or	a
	jr	nz,A6BF1
	ld	hl,(D9C05)
	push	hl
	ld	bc,T6463		; "inc  hl"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A6BF1:	ld	a,(D9C0D)
	ld	c,a
	push	bc
	ld	bc,T6424		; "ld  a,рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ld	hl,(D9C09)
	ld	a,l
	or	h
	jr	z,A6C32
	ld	a,l
	dec	a
	or	h
	jr	z,A6C16
	ld	a,l
	inc	a
	or	h
	jr	z,A6C1F
	jr	A6C28
	;
A6C16:	ld	hl,T640F
	jr	A6C22
	;
A6C1F:	ld	hl,T6408		; ""
A6C22:	call	A6489			; записать asm-строку в вых. файл
	jr	A6C32
	;
A6C28:	push	hl
	ld	bc,T643A		; "sub  мл.число"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A6C32:	pop	af
	or	a
	jr	z,A6C47
	ld	hl,(D9C05)
	push	hl
	ld	bc,T6463		; "inc  hl"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	jr	A6C54
	;
A6C47:	ld	hl,(D9C05)
	push	hl
	ld	bc,T6465		; "dec  hl"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A6C54:	ld	a,(D9C0C)
	ld	c,a
	push	bc
	ld	bc,T6D57		; "or  рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ret
	;
A6C63:	ld	a,1
	ld	(D9C0E),a
	push	bc
	ld	b,0
	ld	l,c
	ld	h,b
	ld	(D9C09),hl
	ld	a,(D9C0B)
	push	af
	call	A6509
	ld	(D9C0D),a
	pop	af
	ld	(D9C0C),a
	pop	bc
	ld	a,b
	inc	a
	jr	z,A6CA3
	xor	a
	ld	(D9C0E),a
	push	bc
	ld	c,b
	ld	b,a
	ld	l,c
	ld	h,b
	ld	(D9C09),hl
	ld	a,(D9C0B)
	ld	(D9C0D),a
	call	A6509
	ld	(D9C0C),a
	pop	bc
	ld	a,c
	inc	a
	jp	nz,A6D32
A6CA3:	ld	a,(D9C0E)
	push	af
	or	a
	jr	nz,A6CB8
	ld	hl,(D9C05)
	push	hl
	ld	bc,T6463		; "inc  hl"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A6CB8:	ld	a,(D9C0D)
	ld	c,a
	push	bc
	ld	bc,T6424		; "ld  a,рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ld	hl,(D9C09)
	ld	a,l
	inc	a
	or	h
	jr	z,A6D01
	ld	a,l
	sub	0FEh
	or	h
	jr	z,A6CDC
	ld	a,l
	or	h
	jr	z,A6CE5
	jr	A6CEE
	;
A6CDC:	ld	hl,T6408		; ""
	call	A6489			; записать asm-строку в вых. файл
	jr	A6D01
	;
A6CE5:	ld	hl,T640F		; ""
	call	A6489			; записать asm-строку в вых. файл
	jr	A6D01
	;
A6CEE:	ld	bc,00FFh		; 255
	ld	a,c
	sub	l
	ld	c,a
	ld	a,b
	sbc	a,h
	ld	b,a
	push	bc
	ld	bc,T6435		; "add  a,мл.число"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A6D01:	pop	af
	or	a
	jr	z,A6D16
	ld	hl,(D9C05)
	push	hl
	ld	bc,T6463		; "inc  hl"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	jr	A6D23
	;
A6D16:	ld	hl,(D9C05)
	push	hl
	ld	bc,T6465		; "dec  hl"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A6D23:	ld	a,(D9C0C)
	ld	c,a
	push	bc
	ld	bc,T6D5D		; "and  рег : inc  a"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ret
	;
A6D32:	push	bc
	ld	de,(D9C05)
	ld	hl,10
	add	hl,de
	ld	l,(hl)
	push	hl
	push	de
	push	bc
	ld	hl,10
	add	hl,de
	ld	a,(hl)
	call	A6509
	ld	l,a
	push	hl
	ld	bc,T6D6A		; машинная "идиома"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret

T6D57:	db	"Nor",9,"R",0		; "	or	рег"

T6D5D:	db	"Nand",9,"R"		; "	and	рег"
	db	"Ninc",9,"a"		; "	inc	a"
	db	0

T6D6A:	db	"Za,R"			; "	ld	a,рег"
	db	"Ncp",9,"L"		; "	cp	мл.число"
	db	"XNjr",9,"nz,$+5"	; "	inc	hl : jr   nz,$+5"
	db	"Za,R"			; "	ld	a,рег"
	db	"Ncp",9,"H"		; "	cp	ст.число"
	db	0


L6E31:	ld	de,T6DEF
	jr	A6D88
	;
L6ED8:	ld	de,A6E54
	jr	A6D88
	;
L6F35:	ld	de,T6EDE
A6D88:	ex	de,hl
	ld	(D9C0F),hl
	ld	hl,12
	add	hl,de
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,9
	add	hl,de
	ld	a,(hl)
	and	7
	ld	(D9C11),bc
	ld	hl,10
	add	hl,de
	ld	(D9C13),a
	ld	a,(hl)
	and	7
	push	de
	ld	hl,T6DC7
	push	hl
	ld	hl,(D9C0F)
	push	hl
	ld	(D9C14),a
	call	A6509
	ld	c,a
	push	bc
	ld	a,(D9C13)
	call	A6509
	ld	e,a
	ld	hl,(D9C11)
	ld	h,0
	pop	bc
	ret
	;
T6DC7:	pop	de
	push	de
	ld	bc,T6463		; "inc  hl"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ld	hl,(D9C0F)
	push	hl
	ld	hl,D9C14
	ld	c,(hl)
	dec	hl
	ld	e,(hl)
	ld	hl,(D9C11)
	ld	l,h
	ld	h,0
	ret


T6DE3:	db	"Ncpl",0		; "	cpl"
T6DE8:	db	"Nxor",9,"L",0		; "	xor	мл.число"

T6DEF:	inc	l
	dec	l
	jr	nz,A6E04
	ld	a,e
	cp	c
	ret	z
	push	bc
	push	de
	ld	bc,T6403		; "ld  рег,рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret
A6E04:	push	de
	push	hl
	push	bc
	ld	bc,T6424		; "ld  a,рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	hl
	ld	a,l
	inc	a
	jr	nz,A6E1D
	ld	hl,T6DE3		; "	cpl"
	call	A6489			; записать asm-строку в вых. файл
	jr	A6E27
	;
A6E1D:	push	hl
	ld	bc,T6DE8		; "xor  мл.число"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A6E27:	ld	bc,T6429		; "ld  рег,a"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ret


T6E37:	db	"ZR,255",0		; "	ld	рег,255"

T6E3E:	db	"Za,R"			; "	ld	a,рег"
	db	"Nor",9,"L"		; "	or	мл.число"
	db	"ZR,a"			; "	ld	рег,a"
	db	0


T6E4C:	db	01h,02h,04h,08h,10h,20h,40h,80h


A6E54:	ld	a,c
	ld	(D9C17),a
	ld	a,l
	inc	a
	jr	z,A6E7E
	dec	a
	jr	z,A6E89
	push	hl
	ld	d,l
	ld	hl,T6E4C
	call	A6EC4
	pop	hl
	cp	8
	jr	c,A6E9C
	push	de
	push	hl
	ld	hl,(D9C17)
	push	hl
	ld	bc,T6E3E		; машинная "идиома"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret
	;
A6E7E:	push	de
	ld	bc,T6E37		; "ld  рег,255"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ret
A6E89:	ld	a,e
	ld	hl,(D9C17)
	cp	l
	ret	z
	push	hl
	push	de
	ld	bc,T6403		; "ld  рег,рег"  8 битные
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret
A6E9C:	push	de
	ld	c,a
	push	bc
	ld	bc,T6EAA		; "set xx,рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret

T6EAA:	db	"Nset",9,"L,R",0	; "	set	мл.число,рег"

T6EB3:	db	"Nres",9,"L,R",0	; "	res	мл.число,рег"


T6EBC:	db	0FEh,0FDh,0FBh,0F7h
	db	0EFh,0DFh,0BFh,7Fh


A6EC4:	ld	a,c
	cp	e
	ld	a,0FFh
	ret	nz
	push	bc
	ld	b,8
	ld	a,d
A6ECD:	cp	(hl)
	jr	z,A6ED3
	inc	hl
	djnz	A6ECD
A6ED3:	ld	a,8
	sub	b
	pop	bc
	ret


T6EDE:	ld	a,c
	ld	(D9C1A),a
	ld	a,l
	or	a
	jr	z,A6F08
	inc	a
	jr	z,A6F14
	push	hl
	ld	d,l
	ld	hl,T6EBC
	call	A6EC4
	pop	hl
	cp	8
	jr	c,A6F27
	push	de
	push	hl
	ld	hl,(D9C1A)
	push	hl
	ld	bc,T6F40		; машинная "идиома"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ret
	;
A6F08:	ld	c,e
	push	bc
	ld	bc,T6F3B		; "ld  рег,0"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ret
A6F14:	ld	a,e
	ld	hl,(D9C1A)
	cp	l
	ret	z
	push	hl
	push	de
	ld	bc,T6403		; "ld  рег,рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret
A6F27:	push	de
	ld	c,a
	push	bc
	ld	bc,T6EB3		; "res  xx,рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	ret


T6F3B:	db	"ZR,0",0		; "	ld	рег,0"

T6F40:	db	"Za,R"			; "	ld	a,рег"
	db	"Nand",9,"L"		; "	and	мл.число"
	db	"ZR,a"			; "	ld	рег,a"
	db	0

T6F4F:	db	"E>>M in F",0Ah,0

T6F5A:	db	"Nrlca",0		; "	rlca"


L6F60:	ld	bc,12
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	c,l
	ld	b,h
	ld	de,8
	call	cpshd			; знак. сравнение hl с de
	jr	c,A6F89
	ld	bc,8
	push	bc
	ld	bc,T6F4F		; ""
	push	bc
	ld	hl,2
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	pop	bc
	pop	bc
	ld	hl,T645C		; ""
	jp	A6489			; записать asm-строку в вых. файл
	;
A6F89:	ld	de,5
	push	hl
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A6FA3
A6F92:	ld	a,c
	or	b
	jr	z,A6FBF
	ld	hl,T6456		; ""
	push	bc
	call	A6489			; записать asm-строку в вых. файл
	pop	bc
	dec	bc
	jr	A6F92
	;
A6FA3:	ld	l,c
	ld	h,b
	ld	bc,8
	ld	a,c
	sub	l
	ld	c,a
	ld	a,b
	sbc	a,h
	ld	b,a
A6FAE:	ld	a,c
	or	b
	jr	z,A6FBF
	ld	hl,T6F5A
	push	bc			; ""
	call	A6489			; записать asm-строку в вых. файл
	pop	bc
	dec	bc
	jr	A6FAE
	;
A6FBF:	pop	hl
	ld	b,l
	ld	hl,00FFh
	call	A942E			; сдвиг "hl" вправо (деление на 2), счетчик "b"
	push	hl
	ld	bc,T642E		; "and  мл.число"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ret


T6FD2:	db	"E<<M in F",0Ah,0

L6FDD:	ld	bc,12
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	c,l
	ld	b,h
	ld	de,8
	call	cpshd			; знак. сравнение hl с de
	jr	c,A7003
	ld	bc,8
	push	bc
	ld	bc,T6FD2		; ""
	push	bc
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	pop	bc
	pop	bc
	ld	hl,T645C		; ""
	jp	A6489			; записать asm-строку в вых. файл
	;
A7003:	ld	de,5
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A701A
A700B:	ld	a,c
	or	b
	ret	z
	ld	hl,T6441		; ""
	push	bc
	call	A6489			; записать asm-строку в вых. файл
	pop	bc
	dec	bc
	jr	A700B
	;
A701A:	push	hl
	ld	l,c
	ld	h,b
	ld	bc,8
	ld	a,c
	sub	l
	ld	c,a
	ld	a,b
	sbc	a,h
	ld	b,a
A7026:	ld	a,c
	or	b
	jr	z,A7037
	ld	hl,T6456		; ""
	push	bc
	call	A6489			; записать asm-строку в вых. файл
	pop	bc
	dec	bc
	jr	A7026
	;
A7037:	pop	hl
	ld	b,l
	ld	hl,00FFh
	call	A943F			; сдвиг "hl" влево (умнож. на 2), счетчик "b"
	push	hl
	ld	bc,T642E		; "and  мл.число"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ret


T704A:	db	"E<<M in F",0Ah,0

T7055:	db	"Zhl,0",0		; "	ld	hl,0"

L705B:	ld	bc,12
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	de,16
	call	cpshd			; знак. сравнение hl с de
	jr	c,A707F
	ld	bc,16
	push	bc
	ld	bc,T704A		; ""
	push	bc
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	pop	bc
	pop	bc
	ld	hl,T7055		; ""
	jp	A6489			; записать asm-строку в вых. файл
	;
A707F:	ld	de,8
	call	cpshd			; знак. сравнение hl с de
	jr	c,A7094
	push	hl
	ld	hl,T644D		; ""
	call	A6489			; записать asm-строку в вых. файл
	pop	hl
	ld	bc,-8
	add	hl,bc
A7094:	ld	a,l
	or	h
	ret	z
	push	hl
	ld	hl,T6446		; ""
	call	A6489			; записать asm-строку в вых. файл
	pop	hl
	dec	hl
	jr	A7094


T70A3:	db	"?pomlbqP",0		; "?pomlbq<рег.пара>"  имя библ. функции

T70AC:	db	"Aa,R",0		; "	add	a,рег"

L70B1:	ld	bc,12
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A64A2
	ld	h,0
	push	hl
	call	A7685
	ex	de,hl
	ld	hl,3
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A70D2
	ld	hl,T70A3
	call	A75DA			; вывод строки "hl" (большие буквы зарез.)
A70D2:	xor	a
	ld	(D9C1B),a
	pop	hl
A70D7:	ld	a,l
	sub	2
	ld	a,h
	sbc	a,0
	jr	c,A710B
	ld	a,l
	and	1
	push	hl
	or	a
	jr	z,A70FC
	ld	a,(D9C1B)
	ld	c,a
	push	af
	push	bc
	ld	bc,T6429		; "ld  рег,a"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	af
	inc	a
	ld	(D9C1B),a
A70FC:	ld	hl,T6441		; ""
	call	A6489			; записать asm-строку в вых. файл
	pop	hl
	ld	b,1
	call	A942E			; сдвиг "hl" вправо (деление на 2), счетчик "b"
	jr	A70D7
	;
A710B:	ld	a,(D9C1B)
	or	a
	ret	z
	dec	a
	ld	(D9C1B),a
	ld	c,a
	push	bc
	ld	bc,T70AC		; "add  a,рег"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	jr	A710B


T7122:	db	"?pomlwqP",0		; "?pomlwq<рег.пара>"  имя библ. функции

T712B:	db	"ZR,l"			; "	ld	рег,l"
	db	"ZR,h",0		; "	ld	рег,h"

T7134:	db	"Ahl,P",0		; "	add	hl,рег.пара"


L713A:	ld	bc,12
	add	hl,bc
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	l,c
	ld	h,b
	push	hl
	ld	a,l
	or	h
	jr	z,A7156
	call	A7685
	ex	de,hl
	ld	hl,3
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A715C
A7156:	ld	hl,T7122
	call	A75DA			; вывод строки "hl" (большие буквы зарез.)
A715C:	xor	a
	ld	(D9C1C),a
	pop	hl
A7161:	ld	a,l
	sub	2
	ld	a,h
	sbc	a,0
	jr	c,A71B3
	ld	a,l
	and	1
	push	hl
	or	a
	jr	z,A718D
	ld	a,(D9C1C)
	ld	c,a
	push	af
	push	bc
	call	A6509
	ld	l,a
	push	hl
	ld	bc,T712B		; "ld  рег,l"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	pop	af
	inc	a
	inc	a
	ld	(D9C1C),a
A718D:	pop	hl
	ld	a,l
	and	0FEh
	jr	nz,A71A3
	push	hl
	ld	hl,T644D		; ""
	call	A6489			; записать asm-строку в вых. файл
	pop	bc
	ld	c,b
	ld	b,0
	ld	l,c
	ld	h,b
	jr	A7161
	;
A71A3:	push	hl
	ld	hl,T6446		; ""
	call	A6489			; записать asm-строку в вых. файл
	pop	hl
	ld	b,1
	call	A942E			; сдвиг "hl" вправо (деление на 2), счетчик "b"
	jr	A7161
	;
A71B3:	xor	a
A71B4:	ld	hl,(D9C1C)
	cp	l
	ret	nc
	ld	c,a
	push	af
	push	bc
	ld	bc,T7134		; "add  hl,рег.пара"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	af
	inc	a
	inc	a
	jr	A71B4

T71CB:	db	"?poadbqP",0		; "?poadbq<рег.пара>"  имя библ. функции


L71D4:	ld	(D9C1D),hl
	ld	bc,12
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	push	hl
	ld	hl,(D9C1D)
	ld	bc,9
	add	hl,bc
	ld	a,(hl)
	ld	(D9C1F),a
	pop	hl
	push	hl
	call	A6494
	ld	a,l
	sub	4
	ld	a,h
	sbc	a,0
	jr	c,A71FF
	ld	hl,T71CB
	call	A75DA			; вывод строки "hl" (большие буквы зарез.)
A71FF:	pop	de
	ld	a,e
	or	d
	jr	z,A720D
	ld	a,(D9C1F)
	and	7
	ld	(D9BED),a
A720D:	ld	hl,0
A7210:	call	cpshd			; знак. сравнение hl с de
	jr	nc,A722A
	push	de
	ld	a,(D9C1F)
	ld	c,a
	push	bc
	ld	bc,T6416		; "inc  рег"  8-bit
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	de
	dec	de
	jr	A720D
	;
A722A:	inc	d
	dec	d
	ret	p
	push	de
	ld	a,(D9C1F)
	ld	c,a
	push	bc
	ld	bc,T641D		; "dec  рег"  8-bit
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	de
	inc	de
	jr	A722A


L7241:	ld	bc,12
	add	hl,bc
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	call	A64A2
	inc	h
	dec	h
	jp	p,A7262
	ld	a,l
	neg
	ld	c,a
	push	bc
	ld	bc,T643A		; "sub  мл.число"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	jr	A726C
	;
A7262:	push	hl
	ld	bc,T6435		; "add  a,мл.число"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A726C:	ld	a,7
	ld	(D9BED),a
	ret


L7272:	ld	c,l
	ld	b,h
	ld	(D9C20),hl
	ld	hl,9
	add	hl,bc
	ld	a,(hl)
	ld	(D9C22),a
	ld	hl,12
	add	hl,bc
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,10
	add	hl,bc
	cp	(hl)
	jp	nz,A731D
	ld	hl,11
	add	hl,bc
	ld	a,(hl)
	cp	10h
	jp	nz,A731D
	ld	l,e
	ld	h,d
	push	de
	call	A64E6
	ex	de,hl
	ld	hl,4
	pop	bc
	call	cpshd			; знак. сравнение hl с de
	jp	c,A731D
A72A9:	ld	e,c
	ld	d,b
	ld	hl,128
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A72C8
	push	bc
	ld	a,(D9C22)
	ld	c,a
	push	bc
	ld	bc,T6416		; "inc  рег"  8-bit
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	dec	b
	jr	A72A9
	;
A72C8:	ld	l,c
	ld	h,b
	ld	de,-128
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A72E7
	push	bc
	ld	a,(D9C22)
	ld	c,a
	push	bc
	ld	bc,T641D		; "dec  рег"  8-bit
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	inc	b
	jr	A72C8
	;
A72E7:	ld	e,c
	ld	d,b
	ld	hl,0
	call	cpshd			; знак. сравнение hl с de
	jr	nc,A7306
	push	bc
	ld	a,(D9C22)
	ld	c,a
	push	bc
	ld	bc,T7334		; "inc  рег.пара"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	dec	bc
	jr	A72E7
	;
A7306:	inc	b
	dec	b
	ret	p
	push	bc
	ld	a,(D9C22)
	ld	c,a
	push	bc
	ld	bc,T733B		; "dec  рег.пара"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	pop	bc
	inc	bc
	jr	A7306
	;
A731D:	ld	a,(D9C22)
	cp	0C4h
	jr	z,A732B
	ld	hl,T7342
	call	A75DA			; вывод строки "hl" (большие буквы зарез.)
A732B:	ld	hl,(D9C20)
	ld	de,T8CFA
	jp	A67DB

T7334:	db	"Ninc",9,"P",0		; "	inc	рег.пара"
T733B:	db	"Ndec",9,"P",0		; "	dec	рег.пара"
T7342:	db	"?poadwiP",0		; "?poadwi<рег.пара>"  имя библ. функции

A734B:	call	set_cseg		; уст. тип "cseg"
	ld	hl,(D9CCA)
	push	hl
	ld	bc,T7447		; ";{"  начало функции
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
	ld	de,(D9CE1)
	ld	hl,(D9CDF)
	add	hl,de
	ld	(D9BE7),hl
	ld	a,l
	cpl
	ld	l,a
	ld	a,h
	cpl
	ld	h,a
	inc	hl
	ld	(D9BE9),hl
	ld	de,(D9CEC)
A7374:	ld	hl,(D9CEE)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,A7441
	ld	hl,9
	add	hl,de
	push	de
	ld	a,(hl)
	or	a
	jp	z,A7438
	ld	hl,6
	add	hl,de
	push	de
	ld	a,(hl)
	inc	hl
	and	(hl)
	inc	a
	jr	z,A73A0
	ld	b,(hl)
	dec	hl
	ld	c,(hl)
	push	bc
	ld	bc,T744E		; "@число"  метка
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	pop	bc
A73A0:	ld	a,-1
	ld	(D9BEC),a
	pop	de
	ex	de,hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9C23),de
A73AE:	ld	iy,(D9C23)
	bit	7,(iy+4)
	jr	z,A7438
	xor	a
	ld	(D9BEB),a
	dec	a
	ld	(D9BED),a
	ld	l,(iy+8)
	ld	h,0
	add	hl,hl
	ld	bc,T8BF0
	add	hl,bc
	push	iy
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9C25),de
	ld	hl,T8CF0
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jr	c,A73FC
	ld	a,(iy+8)
	cp	30h
	jr	nz,A73EF
	ld	a,(iy+10)
	and	7
	ld	hl,D9BEC
	cp	(hl)
	jr	z,A7405
A73EF:	ld	hl,(D9C23)
	ld	de,(D9C25)
	call	A67DB
	jr	A7405
	;
A73FC:	ld	hl,A7405
	push	hl
	push	de
	ld	hl,(D9C23)
	ret
	;
A7405:	ld	a,(D9BEB)
	or	a
	jr	z,A7427
	ld	iy,(D9C23)
	ld	a,(iy+6)
	and	30h
	jr	z,A7427
	ld	a,(D9BEB)
	dec	a
	jr	nz,A7421
	ld	hl,T63C6
	jr	A7424
	;
A7421:	ld	hl,T63BD		; "inc	hl"
A7424:	call	A7866			; записать текст. строку в вых. файл
A7427:	ld	a,(D9BED)
	ld	(D9BEC),a
	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	(D9C23),de
	jp	A73AE
	;
A7438:	pop	de
	ld	hl,24
	add	hl,de
	ex	de,hl
	jp	A7374
	;
A7441:	ld	hl,T7453		; ";}"  конец функции
	jp	A6489			; записать asm-строку в вых. файл


T7447:	db	0Ah,";{"		; комментарий начала функции
	db	0Ah,"M:",0		; вывод имени функции
T744E:	db	0Ah,"@D:",0		; префикс меток + их десят. номер
T7453:	db	0Ah,";}",0Ah,0		; комментарий конца функции



; Вывод в буфер T7499 ("000000") десятичного числа
; вход: b=разрядность числа
A7458:	push	bc
	ld	bc,1000h		; "b" счетчик
	ld	e,c
	ld	d,c
A745F:	add	hl,hl
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
	djnz	A745F
	ld	hl,T7499
	ld	a,c
	call	A7489
	ld	a,d
	call	A7489
	ld	a,e
	call	A7489
	ld	hl,T7499
	pop	bc
A7481:	ld	a,(hl)
	cp	"0"
	ret	nz
	inc	hl
	djnz	A7481
	ret
	;
A7489:	push	af
	rrca
	rrca
	rrca
	rrca
	call	.loc1
	pop	af
.loc1:	and	0Fh
	or	"0"
	ld	(hl),a
	inc	hl
	ret

T7499:	db	"000000",0



; Вывод строки на экран. Большие буквы - зарезервированы.
; Параметры (сколько ?) передаются через стек.
A74A0:	pop	bc
	pop	hl
	push	hl
	push	bc
	ld	ix,4
	add	ix,sp
A74AA:	ld	a,(hl)
	inc	hl
	or	a
	ret	z
	push	hl
	push	ix
	cp	"D"
	jr	z,A74EB
	cp	"W"
	jr	z,A74FC
	cp	"B"
	jr	z,A750D
	cp	"S"
	jr	z,A751D
	cp	"C"
	jr	z,A7529
	cp	"?"
	jr	z,A7532			; на вывод "compiler error: "
	cp	"F"
	jr	z,A753A
	cp	"E"
	jr	z,A7553
	cp	"M"
	jp	z,A7560
	cp	"P"
	jp	z,A757A
	cp	"A"			; конец строки
	jp	z,A7589
	jp	A7592
	;
	; "D"
A74EB:	ld	b,5
	jr	A74FE
	; "W"
A74FC:	ld	b,1
A74FE:	ld	l,(ix+0)
	ld	h,(ix+1)
	jr	A7515
	; "B"
A750D:	ld	l,(ix+0)
	ld	h,0
	ld	b,3			; разрядность числа
A7515:	call	A7458			; вывод в буфер "000000" дес. числа
	jr	A7523
	; "S"
A751D:	ld	l,(ix+0)
	ld	h,(ix+1)
A7523:	call	A011E			; вывод строки на экран
	jr	A7570
	; "C"
A7529:	ld	a,(ix+0)
	call	A0109			; вывод "a" на экран
;L752F:
	jp	A7570			; L752F+1 !
	; "?"
A7532:	ld	hl,T759B		; "compiler error: "
	call	A011E			; вывод строки на экран
	jr	A7595
	; "F" вывод имени функции (массива или др. переменной ?)
A753A:	ld	hl,(D9CCA)
	ld	a,l
	or	h
	jr	z,A7595
	ld	a,'"'
	call	A0109			; вывод "a" на экран
	ld	hl,(D9CCA)
	call	A011E			; вывод имени на экран
	ld	a,'"'
	call	A0109
	jr	A7595
	; "E"
A7553:	ld	a,true			; есть предупреждения
	ld	(warnings),a		; флаг
	ld	hl,T75AD		; "warning: "
	call	A011E			; вывод строки на экран
	jr	A7595
	; "M"
A7560:	ld	c,(ix+0)
	ld	b,(ix+1)
	push	bc
	ld	bc,T75B7		; ""
	push	bc
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	pop	bc
	pop	bc
A7570:	pop	ix
	inc	ix
	inc	ix
	pop	hl
	jp	A74AA
	; "P"
A757A:	ld	hl,(D787D)
	push	hl
	ld	hl,(D787B)
	push	hl
	ld	bc,T75C8		; ""
	push	bc
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	; "A" конец строки
A7589:	ld	hl,T75D5		; 0Ah,0
	call	A011E			; вывод строки на экран
	jp	abort			; закрыть файлы и выйти в ДОС
	; default
A7592:	call	A0109			; вывод "a" на экран
A7595:	pop	ix
	pop	hl
	jp	A74AA


T759B:	db	0Ah,"compiler error: ",0
T75AD:	db	"warning: ",0
T75B7:	db	" more than D bit",0
T75C8:	db	" in F at D:D",0
T75D5:	db	0Ah,0


A75D7:	ld	hl,T75E0		; "bad t-codeP"
A75DA:	push	hl
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	pop	bc
	ret

T75E0:	db	0Ah,"bad t-codeP",0


; S - function или symbol table
; F - имя функции (таблицы)
; S - less или more  (меньше/больше)
; D - число (заданный размер таблицы идентиф. или недост. место ?)
T75ED:	db	0Ah,"S overflow in F ... specify S than D by -rA",0
T761A:	db	"more",0		; более
T761F:	db	"less",0		; менее



A7624:	ld	e,0
	ld	hl,A765A		; "function"
	jr	A7630
	;
A762B:	ld	e,1
	ld	hl,A7663		; "symbol table"
A7630:	ld	bc,Table		; начало таблицы идентиф.
	ld	(D9C32),hl
	ld	hl,(table_end)		; конец таблицы идентиф.
	ld	a,l
	sub	c
	ld	l,a
	ld	a,h
	sbc	a,b
	ld	h,a
	push	hl
	inc	e
	dec	e
	ld	hl,T761A		; "more"
	jr	nz,A764E
	ld	hl,T761F		; "less"
A764E:	push	hl
	ld	hl,(D9C32)		; "function" или "symbol table"
	push	hl
	ld	bc,T75ED		; "S overflow in F ... specify S than D by -rA"
	push	bc
	; исправлен фирм. глюк (было "jp")
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	ret
	;
A765A:	db	"function",0
A7663:	db	"symbol table",0



A7670:	ld	de,0
A7673:	ld	a,l
	sub	2
	ld	a,h
	sbc	a,0
	jr	c,A7683
	srl	h
	rr	l
	inc	de
	jr	A7673
A7683:	ex	de,hl
	ret


A7685:	ld	b,16
	ld	de,0
A768A:	srl	h
	rr	l
	jr	nc,A7691
	inc	de
A7691:	djnz	A768A
	ex	de,hl
	ret


A7695:	ld	c,e
	ld	b,d
	ld	(D9C34),a
	ld	de,0
A769D:	ld	l,c
	ld	h,b
	add	hl,de
	ld	a,(hl)
	or	a
	jr	z,A76B5
	ld	l,c
	ld	h,b
	add	hl,de
	ld	a,(D9C34)
	cp	(hl)
	jr	nz,A76B1
	ex	de,hl
	ret
A76B1:	inc	de
	jr	A769D
A76B5:	ld	hl,-1
	ret


A76BB:	ld	hl,0
	inc	hl
	ld	(A76BB+1),hl
	ld	bc,D9C34
	add	hl,bc
	ld	(hl),a
	ret

A76C8:	ld	a,(hl)
	or	a
	ret	z
	ld	a,(hl)
	inc	hl
	push	hl
	call	A76BB
	pop	hl
	jr	A76C8

A76D5:	ld	hl,(A76BB+1)		; смещ. в буфере .tmc файла ?
	ld	a,l
	or	h
	jr	z,A76F3
	dec	hl
	ld	(A76BB+1),hl
	ld	bc,T9C35
	add	hl,bc
	ld	a,(hl)
	cp	1Ah			; код конца файла
	push	af
	jr	nz,A76EF
	call	A75D7			; вывод строки "bad t-codeP"
A76EF:	pop	af
	jr	A771B
	;
A76F3:	call	read_byte		; получить байт из буфера вход. файла
	ld	hl,(D787D)
	inc	hl
	ld	(D787D),hl
	cp	0Ah
	jr	nz,A7714
	ld	hl,(D787B)
	inc	hl
	ld	(D787B),hl
	ld	hl,0
	ld	(D787D),hl
A7714:	cp	0FFh
	jr	nz,A771B
	ld	a,1Ah
A771B:	push	af
	cp	1Ah
	jr	nz,A7726
	call	A76BB
A7726:	pop	af
	ret


A7728:	call	A76D5
	cp	0Ah
	jr	nz,A7728
	ret


A7731:	call	A76D5
	cp	9
	ret	z
	jp	A75D7			; вывод строки "bad t-codeP"


A773B:	push	hl
	call	A76D5
	pop	hl
	cp	9
	jr	z,A7759
	cp	0Ah
	jr	z,A7759
	cp	2Ch
	jr	z,A7759
	cp	22h
	jr	z,A7759
	ld	(hl),a
	inc	hl
	jr	A773B
	;
A7759:	push	hl
	call	A76BB
	xor	a
	pop	hl
	ld	(hl),a
	ret


A77A1:	ld	hl,T9C42
	ld	(D9CC8),hl
	call	A773B
	ld	hl,D9CC8
	;
A7761:	ld	(D9C3F),hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	a,(de)
	cp	2Dh			; "-"
	jr	nz,A776E
	inc	de
A776E:	ld	hl,0
	ld	(D9C41),a
A7774:	ld	a,(de)
	inc	de
	sub	"0"
	cp	0Ah
	jr	nc,A778A
	add	hl,hl
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	c,a
	ld	b,0
	add	hl,bc
	jr	A7774
	;
A778A:	dec	de
	push	hl
	ld	hl,(D9C3F)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	a,(D9C41)
	pop	hl
	cp	"-"
	ret	nz
	ld	a,l
	cpl
	ld	l,a
	ld	a,h
	cpl
	ld	h,a
	inc	hl
	ret


; Тест на нажатие Esc и вывод "a" на экран
A77B0:	ld	(A77BB+1),a
	call	test_Esc		; проверка на нажатие Esc
	ld	a,(D9CE9)		; флаг "тихого" режима
	or	a
	ret	z			; false
A77BB:	ld	a,0
	jp	A0109			; вывод "a" на экран


; Вывод строки на экран
A77C1:	ld	a,(hl)
	or	a
	ret	z
	ld	a,(hl)
	inc	hl
	push	hl
	call	A77B0			; тест на нажатие Esc и вывод "a" на экран
	pop	hl
	jr	A77C1


; Установить "cseg" тип сегмента
set_cseg:
	ld	a,(type_seg)
	or	a
	ret	z			; выйти, текущий уже "cseg"
	ld	bc,T77F4		; "	cseg"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	xor	a			; "cseg" тип
	ld	(type_seg),a
	ret


; Установить "dseg" тип сегмента
set_dseg:
	ld	a,(type_seg)
	dec	a
	ret	z			; выйти, текущий уже "dseg"
	ld	bc,T77FA		; "	dseg"
	push	bc
	call	A6225			; записать asm-строку в вых. файл
	pop	bc
	ld	a,1			; "dseg" тип
	ld	(type_seg),a
	ret

type_seg:
	db	-1			; тип тек. сегмента

T77F4:	db	"Ncseg",0		; "	cseg"
T77FA:	db	"Ndseg",0		; "	dseg"


D7800:	dw	0

T7802:	db	"call",9,0



;[]=============================================================[]
;  Запись мнемоники в вых. файл
;
A7808:	push	af
	ld	hl,1
	add	hl,sp
	ld	(hl),a
	cp	"<"
	jr	nz,A7821
	ld	hl,T7802		; "call"
	call	A7866			; записать текст. строку в вых. файл
	ld	hl,T9C4D
	ld	(D7800),hl
	jr	A7864
	;
A7821:	cp	">"
	jr	nz,A783C
	ld	hl,(D7800)
	ld	(hl),0
	ld	e,"X"
	ld	hl,T9C4D
	call	A0778
	ld	hl,0
	ld	(D7800),hl
	jr	A7864
	;
A783C:	ld	hl,(D7800)
	push	af
	ld	a,l
	or	h
	jr	z,A7854
	ld	hl,(D7800)
	push	hl
	ld	hl,5
	add	hl,sp
	ld	a,(hl)
	pop	hl
	ld	(hl),a
	inc	hl
	ld	(D7800),hl
A7854:	pop	af
	push	af
	cp	0Ah
	jr	nz,A7860
	ld	a,0Dh
	call	write_byte		; записать байт в вых. файл
A7860:	pop	af
	call	write_byte
A7864:	pop	bc
	ret


; записать десят. число
A7873:	ld	b,5			; разрядность числа
	call	A7458			; в буфер "000000" десят. число
; записать текст. строку
A7866:	ld	a,(hl)
	or	a
	ret	z
	ld	a,(hl)
	inc	hl
	push	hl
	call	A7808			; запись мнемоники в вых. файл
	pop	hl
	jr	A7866


D787B:	dw	0
D787D:	dw	0



; Знаковые константы
T787F:	dw	0
	dw	1			; -65535 ?
	dw	2
	dw	8
	dw	255			; #00FF
	dw	256			; #0100
	dw	32767			; #7FFF
	dw	-32768			; #8000
	dw	-256			; #FF00
	dw	65535			; #FFFF



T7893:	dw	L7902
	dw	L7902
	dw	L78D8
	dw	L78DD
	dw	L7902
	dw	L7902
	dw	L7902
	dw	L7902
	dw	L7902
	dw	L78E2
	dw	L78E7
	dw	L78F0
	dw	L7902
	dw	L7902
	dw	L7902
	dw	L7902
	dw	L7902
	dw	L78D3
	dw	L78D8
	dw	L78DD
	dw	L7902
	dw	L7902
	dw	L7902
	dw	L7902
	dw	L7902
	dw	L78F9
	dw	L78E7
	dw	L78F0
	dw	L7902
	dw	L7902
	dw	L7902
	dw	L7902


; коды мнемоник ?
L78D3:	db	0x37,0xC4,0x08,0x15,0xA0
L78D8:	db	0x38,0xC4,0x18,0x15,0xA0
L78DD:	db	0x39,0xC4,0x18,0x15,0xA0
L78E2:	db	0x02,0x08,0x08,0x26,0xA0
L78E7:	db	0x02,0xC4,0xC4,0x26,0x3A,0x15,0x18,0xC4,0xA0
L78F0:	db	0x02,0xC4,0xC4,0x26,0x3B,0x15,0x18,0xC4,0xA0
L78F9:	db	0x02,0xC4,0xC4,0x26,0x37,0x08,0xC4,0x15,0xA0
L7902:	db	0xA0


D7903:	dw	L7ACA
D7905:	dw	L7B33
D7907:	dw	L7BA5
D7909:	dw	L7B8F
D790B:	dw	L7CA5
D790D:	dw	L7D49


T790F:	dw	0
	dw	0
	dw	0
	dw	0
	dw	0
	dw	0FFFFh
	dw	L7DA9
	dw	L7DED
	dw	0
	dw	0
	dw	0FFFEh
	dw	L7BB1
	dw	L7BE3
	dw	L7C26
	dw	L7C5E
	dw	L7E2F
	dw	0
	dw	0
	dw	0
	dw	0
	dw	0
	dw	0
	dw	L7ACA
	dw	L7B33
	dw	L7B8F


T7941:	db	0xAB,0x77,0x02,0x20,0x00
	db	0xFF
	dw	L7E41
	db	0xAB,0x62,0x02,0x20,0x00
	db	0xFF
	dw	L7EFC
	db	0x2B,0x77,0x02,0x12,0x01,0x00
	dw	L7FBF
	db	0x2B,0x62,0x02,0x09,0x01,0x00
	dw	L7F8D
	db	0x2D,0x77,0x02,0x12,0x00,0x01
	dw	L7FFC
	db	0x2D,0x62,0x02,0x09,0x00,0x01
	dw	L8033
	db	0x2A,0x77,0x02,0x12,0x01,0x02
	dw	L806A
	db	0x2A,0x62,0x02,0x09,0x01,0x02
	dw	L80E6
	db	0x2F,0x49,0x02,0x12,0x00,0x03
	dw	L813C
	db	0x2F,0x4E,0x02,0x12,0x00,0x04
	dw	L8177
	db	0x2F,0x62,0x02,0x09,0x00,0x04
	dw	L81ED
	db	0x25,0x49,0x02,0x12,0x00,0x05
	dw	L8238
	db	0x25,0x4E,0x02,0x12,0x00,0x06
	dw	L8268
	db	0x25,0x62,0x02,0x09,0x00,0x06
	dw	L82BE
	db	0x26,0x77,0x02,0x12,0x01,0x07
	dw	L82FE
	db	0x26,0x62,0x02,0x09,0x01,0x07
	dw	L83CB
	db	0x7C,0x77,0x02,0x12,0x01,0x08
	dw	L840D
	db	0x7C,0x62,0x02,0x09,0x01,0x08
	dw	L84A5
	db	0x5E,0x77,0x02,0x12,0x01,0x09
	dw	L84E7
	db	0x5E,0x62,0x02,0x09,0x01,0x09
	dw	L853E
	db	0xF2,0x77,0x02,0x11,0x00,0x0B
	dw	L8585
	db	0xF2,0x62,0x02,0x09,0x00,0x0B
	dw	L85E7
	db	0xEC,0x77,0x02,0x11,0x00,0x0C
	dw	L861E
	db	0xEC,0x62,0x02,0x09,0x00,0x0C
	dw	L867B
	db	0x5F,0x77,0x01,0x12,0x00,0x0D
	dw	L86B2
	db	0x5F,0x62,0x01,0x09,0x00,0x0D
	dw	L86CE
	db	0x7E,0x77,0x01,0x12,0x00,0x0E
	dw	L86EA
	db	0x7E,0x62,0x01,0x09,0x00,0x0E
	dw	L8706
	db	0x3D,0x77,0x02,0x12,0x01,0x0F
	dw	L8722
	db	0x3D,0x62,0x02,0x09,0x01,0x0F
	dw	L87A6
	db	0x3C,0x49,0x02,0x12,0x00,0x10
	dw	L87E2
	db	0x3C,0x77,0x02,0x12,0x00,0x11
	dw	L883B
	db	0x3C,0x62,0x02,0x09,0x00,0x11
	dw	L888D
	db	0x6D,0x20,0x02,0x1B,0x00,0x07
	dw	L8ADB
	db	0x73,0x20,0x02,0x1B,0x00,0x08
	dw	L8B27
	db	0x6E,0x20,0x01,0x03,0x00,0x12
	dw	L8B6F
	db	0x77,0x77,0x01,0x02,0x00
	db	0xFF
	dw	L88DF
	db	0x62,0x62,0x01,0x01,0x00
	db	0xFF
	dw	L88DF
	db	0x77,0x62,0x01,0x01,0x00
	db	0xFF
	dw	L88EB
	db	0x62,0x77,0x01,0x02,0x00
	db	0xFF
	dw	L8902
	db	0x3A,0x77,0x02,0x22,0x00
	db	0xFF
	dw	L890E
	db	0x3A,0x62,0x02,0x21,0x00
	db	0xFF
	dw	L89AE
	db	0x02,0x77,0x01,0x02,0x00
	db	0xFF
	dw	L7F4D
	db	0x02,0x62,0x01,0x01,0x00
	db	0xFF
	dw	L7F6D
	db	0x40,0x20,0x01,0x02,0x00
	db	0xFF
	dw	L8A40
	db	0x61,0x20,0x01,0x00,0x00
	db	0xFF
	dw	L8A57
	db	0x2C,0x20,0x02,0x00,0x00
	db	0xFF
	dw	L8ACC
	db	0x70,0x77,0x01,0x02,0x00
	db	0xFF
	dw	L8A89
	db	0x70,0x62,0x01,0x01,0x00
	db	0xFF
	dw	L8AAB
	db	0x00
	;
L7ACA:	db	0x40,0x2C,0x08,0x40,0x02,0x50,0x00,0x07,0x10
	dw	L7B0D
	db	0x40,0x2C,0x08,0x40,0x03,0x40,0x00,0x07,0x10
	dw	L7B17
	db	0x40,0x0B,0x28,0x41,0x12,0x00,0x00,0x07,0x10
	dw	L7B20
	db	0x40,0x0B,0x28,0x41,0x13,0x00,0x00,0x07,0x10
	dw	L7B2A
	db	0x40,0x2C,0x28,0x41,0x02,0x00,0x00,0x07,0x10
	dw	L7B20
	db	0x40,0x2C,0x28,0x41,0x03,0x00,0x00,0x07,0x10
	dw	L7B2A
	db	0xFF
L7B0D:	db	0x82,0x3D,0x2D,0x09,0x15,0x40,0x2E,0x1A,0x15
	db	0xFF
L7B17:	db	0x3D,0x2E,0x0A,0x15,0x40,0x2D,0x19,0x15
	db	0xFF
L7B20:	db	0x82,0x3D,0x2D,0x09,0x15,0x40,0x2E,0x27,0x15
	db	0xFF
L7B2A:	db	0x3D,0x2E,0x0A,0x15,0x40,0x2D,0x27,0x15
L7B32:	db	0xFF
	;
L7B33:	db	0x40,0x08,0x08,0x40,0x01,0x10,0x00,0x07,0x10
	dw	L7B32
	db	0x40,0x08,0x08,0x40,0x14,0x60,0x00,0x07,0x10
	dw	L7B6B
	db	0x40,0xC4,0x08,0x42,0x04,0x00,0x00,0x07,0x10
	dw	L7B70
	db	0x40,0xC4,0x08,0x43,0x05,0x00,0x00,0x07,0x10
	dw	L7B75
	db	0x40,0xC4,0x08,0x43,0xC4,0x00,0x00,0x07,0x10
	dw	L7B7E
	db	0xFF
L7B6B:	db	0x02,0x08,0x08,0x18
	db	0xFF
L7B70:	db	0x02,0xC4,0x08,0x18
	db	0xFF
L7B75:	db	0x4B,0xC4,0x18,0x15,0x01,0xC4,0xC4,0x08
	db	0xFF
L7B7E:	db	0x56,0x15,0xC4,0x15,0x4B,0xC4,0x18,0x15
	db	0x57,0xC2,0x15,0x15,0x01,0xC4,0xC4,0xC2
	db	0xFF
	;
L7B8F:	db	0x40,0x2C,0x08,0x42,0x07,0x00,0x00,0x07,0x10
	dw	L7C96
	db	0x40,0xC4,0x08,0x43,0x07,0x00,0x00,0x07,0x10
	dw	L7C9B
	;
L7BA5:	db	0x40,0xC4,0x08,0x40,0x05,0x10,0x00,0x07,0x10
	dw	L7CA0
	db	0xFF
	;
L7BB1:	db	0x00,0x2D,0x28,0x01,0x87,0x00,0x00,0x07,0x10
	dw	L7BDE
	db	0x00,0x2E,0x28,0x01,0x47,0x00,0x00,0x07,0x10
	dw	L7BDE
	db	0x00,0x87,0x28,0x01,0x02,0x00,0x00,0x07,0x10
	dw	L7BDE
	db	0x00,0x47,0x28,0x01,0x03,0x00,0x00,0x07,0x10
	dw	L7BDE
	db	0xFF
L7BDE:	db	0x3D,0x2C,0x08,0x15
	db	0xFF
	;
L7BE3:	db	0x00,0x2C,0x08,0x00,0x02,0x50,0x00,0x07,0x10
	dw	L7B0D
	db	0x00,0x2C,0x08,0x00,0x03,0x40,0x00,0x07,0x10
	dw	L7B17
	db	0x00,0x0B,0x28,0x01,0x12,0x00,0x00,0x07,0x10
	dw	L7B20
	db	0x00,0x0B,0x28,0x01,0x13,0x00,0x00,0x07,0x10
	dw	L7B2A
	db	0x00,0x2C,0x28,0x01,0x02,0x00,0x00,0x07,0x10
	dw	L7B20
	db	0x00,0x2C,0x28,0x01,0x03,0x00,0x00,0x07,0x10
	dw	L7B2A
	db	0xFF
	;
L7C26:	db	0x00,0x08,0x08,0x00,0x01,0x10,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x08,0x08,0x00,0x14,0x60,0x00,0x07,0x10
	dw	L7B6B
	db	0x00,0xC4,0x08,0x02,0x04,0x00,0x00,0x07,0x10
	dw	L7B70
	db	0x00,0xC4,0x08,0x03,0x05,0x00,0x00,0x07,0x10
	dw	L7B75
	db	0x00,0xC4,0x08,0x03,0xC4,0x00,0x00,0x07,0x10
	dw	L7B7E
	db	0xFF
	;
L7C5E:	db	0x00,0x2C,0x08,0x02,0x07,0x00,0x00,0x07,0x10
	dw	L7C96
	db	0x00,0xC4,0x08,0x03,0x07,0x00,0x00,0x07,0x10
	dw	L7C9B
	db	0x00,0xC4,0x0C,0x00,0x05,0x10,0x00,0x07,0x10
	dw	L7CA0
	db	0x00,0xC2,0x08,0x00,0x05,0x10,0x00,0x07,0x10
	dw	L7CA0
	db	0x00,0xC2,0x08,0x00,0xC4,0x10,0x00,0x07,0x10
	dw	L7CA0
	db	0xFF
L7C96:	db	0x3C,0x2C,0x18,0x15
	db	0xFF
L7C9B:	db	0x4B,0xC4,0x18,0x15
	db	0xFF
L7CA0:	db	0x37,0x2C,0x08,0x15
	db	0xFF
	;
L7CA5:	db	0x00,0xC4,0x08,0x42,0x07,0x00,0x00,0x07,0x10
	dw	L7D09
	db	0x00,0xC4,0x08,0x43,0x07,0x00,0x00,0x07,0x10
	dw	L7D0E
	db	0x00,0xC6,0x0C,0x40,0xC4,0x10,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x2C,0x08,0x40,0xC4,0x10,0x00,0x07,0x10
	dw	L7D13
	db	0x00,0xC4,0x0C,0x08,0x07,0x10,0x00,0x07,0x10
	dw	L7D22
	db	0x00,0xC4,0x0C,0x08,0x07,0x10,0x00,0x07,0x10
	dw	L7D35
	db	0x00,0xC2,0x0C,0x08,0x07,0x10,0x00,0x07,0x10
	dw	L7D13
	db	0x00,0xC0,0x08,0x08,0x07,0x10,0x00,0x07,0x10
	dw	L7D13
	db	0x04,0xC2,0x08,0x80,0xC4,0x10,0x00,0x07,0x10
	dw	L7D40
	db	0xFF
L7D09:	db	0x38,0xC4,0x18,0x15
	db	0xFF
L7D0E:	db	0x39,0xC4,0x18,0x15
	db	0xFF
L7D13:	db	0x9C,0x46,0x2C,0xC4,0x15,0x56,0x15,0x2C,0x15
	db	0x9E,0x57,0x2C,0x15,0x15
	db	0xFF
L7D22:	db	0x9C,0x46,0xC2,0xC4,0x15,0x56,0x15,0xC2,0x15
	db	0x9E,0x57,0xC2,0x15,0x15,0x37,0xC4,0xC2,0x15
	db	0xFF
L7D35:	db	0x9C,0x46,0xC0,0xC4,0x15,0x9E,0x37,0xC4,0xC0,0x15
	db	0xFF
L7D40:	db	0x46,0x2C,0xC4,0x15,0x56,0x15,0xC4,0x15
	db	0xFF
	;
L7D49:	db	0x00,0x47,0x08,0x42,0x07,0x00,0x00,0x07,0x10
	dw	L7D8C
	db	0x00,0x46,0x08,0x40,0xC4,0x10,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x47,0x08,0x40,0x05,0x10,0x00,0x07,0x10
	dw	L7D91
	db	0x00,0x47,0x08,0x60,0x04,0x11,0x00,0x07,0x10
	dw	L7D96
	db	0x00,0x47,0x08,0x09,0x07,0x10,0x00,0x07,0x10
	dw	L7D9D
	db	0x04,0x46,0x08,0x80,0xC4,0x10,0x00,0x07,0x10
	dw	L7DA4
	db	0xFF
L7D8C:	db	0x3E,0x47,0x18,0x15
	db	0xFF
L7D91:	db	0x47,0x47,0x08,0x15
	db	0xFF
L7D96:	db	0x98,0x47,0x47,0x08,0x15,0x9A
	db	0xFF
L7D9D:	db	0x9C,0x47,0x47,0xC4,0x15,0x9E
	db	0xFF
L7DA4:	db	0x56,0x15,0xC4,0x15
	db	0xFF
	;
L7DA9:	db	0x00,0x08,0x08,0x00,0x01,0x10,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x08,0x08,0x00,0x13,0x70,0x00,0x07,0x10
	dw	L7DD6
	db	0x00,0x47,0x08,0x00,0x08,0x70,0x00,0x07,0x10
	dw	L7DDB
	db	0x00,0x47,0x08,0x00,0x03,0x20,0x00,0x07,0x10
	dw	L7DE4
	db	0xFF
L7DD6:	db	0x06,0x08,0x08,0x18
	db	0xFF
L7DDB:	db	0x3D,0x47,0x08,0x15,0x06,0x47,0x47,0x18
	db	0xFF
L7DE4:	db	0x3D,0x47,0x08,0x15,0x05,0x47,0x47,0x18
	db	0xFF
	;
L7DED:	db	0x00,0x47,0x2C,0x00,0x08,0x00,0x00,0x07,0x10
	dw	L7E25
	db	0x00,0x40,0x2C,0x00,0x03,0x00,0x00,0x07,0x10
	dw	L7E25
	db	0x00,0x42,0x2C,0x00,0x03,0x00,0x00,0x07,0x10
	dw	L7E25
	db	0x00,0x44,0x2C,0x00,0x03,0x00,0x00,0x07,0x10
	dw	L7E25
	db	0x00,0x47,0x08,0x00,0x07,0x00,0x00,0x07,0x10
	dw	L7E2A
	db	0xFF
L7E25:	db	0x3D,0x2C,0x08,0x15
	db	0xFF
L7E2A:	db	0x40,0x47,0x18,0x15
	db	0xFF
	;
L7E2F:	db	0xC0,0x15,0x08,0x00,0x06,0x10,0x00,0x07,0x10
	dw	L7E3B
	db	0xFF
L7E3B:	db	0x8C,0x4C,0x15,0x08,0x14
	db	0xFF
	;
L7E41:	db	0x20,0x08,0x0F,0x00,0x04,0x10,0x00,0x07,0x32
	dw	L7B32
	db	0x10,0x08,0x58,0x00,0x04,0x10,0x00,0x07,0x60
	dw	L7EB0
	db	0x10,0x08,0x58,0x00,0x04,0x10,0x00,0x07,0x00
	dw	L7EB5
	db	0x20,0x15,0x2F,0x41,0x07,0x00,0x00,0x07,0x32
	dw	L7B32
	db	0x10,0xC4,0x58,0x42,0x07,0x00,0x00,0x07,0x60
	dw	L7EBE
	db	0x10,0xC4,0x58,0x42,0x07,0x00,0x00,0x07,0x00
	dw	L7ECB
	db	0x10,0xC4,0x58,0x43,0x07,0x00,0x00,0x07,0x60
	dw	L7ED8
	db	0x10,0xC4,0x58,0x43,0x07,0x00,0x00,0x07,0x00
	dw	L7EE5
	db	0xF0,0x15,0x0C,0x40,0xC4,0x10,0x00,0x07,0x00
	dw	L7EF2
	db	0x10,0xC2,0x08,0x40,0xC4,0x10,0x00,0x07,0x00
	dw	L7EF7
	db	0xFF
L7EB0:	db	0x02,0x08,0x08,0x1C
	db	0xFF
L7EB5:	db	0x02,0xC4,0x08,0x1C,0x37,0x08,0xC4,0x15
	db	0xFF
L7EBE:	db	0x38,0xC4,0x18,0x15,0x02,0xC4,0xC4,0x1C
	db	0x3A,0x15,0x18,0xC4
	db	0xFF
L7ECB:	db	0x38,0xC4,0x18,0x15,0x02,0xC4,0xC4,0x1C
	db	0x3A,0x15,0x18,0xC4
	db	0xFF
L7ED8:	db	0x39,0xC4,0x18,0x15,0x02,0xC4,0xC4,0x1C
	db	0x3B,0x15,0x18,0xC4
	db	0xFF
L7EE5:	db	0x39,0xC4,0x18,0x15,0x02,0xC4,0xC4,0x1C
	db	0x3B,0x15,0x18,0xC4
	db	0xFF
L7EF2:	db	0x48,0x15,0xC4,0x1C
	db	0xFF
L7EF7:	db	0x49,0xC2,0xC4,0x1C
	db	0xFF
	;
L7EFC:	db	0x10,0x08,0x58,0x00,0x03,0x10,0x00,0x07,0x70
	dw	L7F29
	db	0x10,0x47,0x58,0x00,0x03,0x10,0x00,0x07,0x00
	dw	L7F2E
	db	0x10,0x46,0x58,0x40,0xC4,0x10,0x00,0x07,0x70
	dw	L7F3B
	db	0x10,0x47,0x58,0x40,0xC4,0x10,0x00,0x07,0x00
	dw	L7F40
	db	0xFF
L7F29:	db	0x06,0x08,0x08,0x1C
	db	0xFF
L7F2E:	db	0x3D,0x47,0x08,0x15,0x05,0x47,0x1C,0x15
	db	0x3D,0x08,0x47,0x15
	db	0xFF
L7F3B:	db	0x06,0x46,0x46,0x1C
	db	0xFF
L7F40:	db	0x3D,0x47,0x46,0x15,0x05,0x47,0x1C,0x15
	db	0x3D,0x46,0x47,0x15
	db	0xFF
	;
L7F4D:	db	0x10,0x08,0x08,0x04,0x05,0x10,0x00,0x07,0x10
	dw	L7F64
	db	0x01,0x08,0x28,0xE1,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0xFF
L7F64:	db	0x57,0xC4,0x15,0x15,0x42,0x15,0xC4,0x08
	db	0xFF
	;
L7F6D:	db	0x10,0x08,0x08,0x04,0x09,0x10,0x00,0x07,0x10
	dw	L7F84
	db	0x01,0x08,0x28,0xE1,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0xFF
L7F84:	db	0x57,0xC4,0x15,0x15,0x44,0x15,0xC4,0x08
	db	0xFF
	;
L7F8D:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x48,0x00,0x03,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x47,0x48,0x00,0x47,0x00,0x00,0x08,0x00
	dw	L7FBA
	db	0x10,0x46,0x08,0x80,0xC4,0x10,0x00,0x07,0x70
	dw	L7F3B
	db	0xFF
L7FBA:	db	0x04,0x47,0x47,0x0C
	db	0xFF
	;
L7FBF:	db	0x00,0x15,0x48,0x01,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x48,0x01,0x01,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x48,0x00,0x01,0x00,0x01,0x07,0x00
	dw	L7B32
	db	0x00,0xC4,0x48,0x01,0xC4,0x00,0x00,0x05,0x00
	dw	L7FF7
	db	0x00,0xC4,0x48,0x00,0xC4,0x00,0x01,0x05,0x00
	dw	L7FF7
	db	0xFF
L7FF7:	db	0x01,0xC4,0xC4,0x0C
	db	0xFF
	;
L7FFC:	db	0x00,0x15,0x48,0x01,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x48,0x01,0x01,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x2C,0x48,0x00,0x0F,0x00,0x00,0x0A,0x00
	dw	L8029
	db	0xF0,0x15,0x08,0x80,0xC4,0x10,0x00,0x05,0x10
	dw	L802E
	db	0xFF
L8029:	db	0x07,0x2C,0x08,0x0C
	db	0xFF
L802E:	db	0x07,0xC6,0xC6,0x0C
	db	0xFF
	;
L8033:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x48,0x00,0x03,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x47,0x48,0x00,0x47,0x00,0x00,0x08,0x00
	dw	L8060
	db	0x10,0x46,0x08,0x80,0xC4,0x10,0x00,0x07,0x70
	dw	L8065
	db	0xFF
L8060:	db	0x09,0x47,0x47,0x0C
	db	0xFF
L8065:	db	0x06,0x46,0x46,0x24
	db	0xFF
	;
L806A:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x08,0x01,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x11
	dw	L7B32
	db	0x00,0x87,0x48,0x00,0x47,0x00,0x00,0x07,0x15
	dw	L7B32
	db	0x00,0x15,0x48,0x00,0x02,0x00,0x00,0x07,0x15
	dw	L7B32
	db	0x00,0x2D,0x48,0x00,0x01,0x00,0x00,0x07,0x15
	dw	L80CE
	db	0x00,0xC4,0x48,0x00,0xC4,0x00,0x00,0x07,0x80
	dw	L80D3
	db	0x00,0xC4,0x48,0x00,0xC4,0x00,0x00,0x07,0x00
	dw	L80D8
	db	0x00,0xC4,0x08,0x00,0xC4,0x10,0x00,0xC2,0x10
	dw	L80E1
	db	0xFF
L80CE:	db	0x3D,0x2C,0x0A,0x15
	db	0xFF
L80D3:	db	0x0D,0xC4,0xC4,0x1C
	db	0xFF
L80D8:	db	0x3C,0xC2,0x1C,0x15,0x0C,0xC4,0xC4,0xC2
	db	0xFF
L80E1:	db	0x0C,0xC4,0xC4,0xC2
	db	0xFF
	;
L80E6:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x08,0x01,0x03,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x03,0x00,0x00,0x07,0x11
	dw	L7B32
	db	0x00,0x47,0x48,0x00,0x47,0x00,0x00,0x07,0x80
	dw	L8129
	db	0x00,0x47,0x48,0x00,0x47,0x00,0x00,0x07,0x00
	dw	L812E
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x40,0x10
	dw	L8137
	db	0xFF
L8129:	db	0x0F,0x47,0x47,0x1C
	db	0xFF
L812E:	db	0x40,0x40,0x1C,0x15,0x0E,0x47,0x47,0x40
	db	0xFF
L8137:	db	0x0E,0x47,0x47,0x40
	db	0xFF
	;
L813C:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x11
	dw	L7B32
	db	0x00,0xC4,0x08,0x00,0xC4,0x10,0x00,0x07,0x00
	dw	L8169
	db	0x00,0xC4,0x08,0x00,0xC4,0x10,0x00,0xC2,0x10
	dw	L8172
	db	0xFF
L8169:	db	0x3C,0xC2,0x1C,0x15,0x11,0xC4,0xC4,0xC2
	db	0xFF
L8172:	db	0x11,0xC4,0xC4,0xC2
	db	0xFF
	;
L8177:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x11
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x87,0x10,0x00,0x07,0x15
	dw	L7B32
	db	0x00,0x15,0x08,0x00,0x03,0x10,0x00,0x07,0x15
	dw	L7B32
	db	0x00,0x2E,0x08,0x00,0x01,0x10,0x00,0x07,0x15
	dw	L81D0
	db	0x00,0xC4,0x08,0x00,0xC4,0x10,0x00,0x07,0x90
	dw	L81D6
	db	0x00,0xC4,0x08,0x00,0xC4,0x10,0x00,0x07,0x00
	dw	L81DF
	db	0x00,0xC4,0x08,0x00,0xC4,0x10,0x00,0xC2,0x10
	dw	L81E8
	db	0xFF
L81D0:	db	0x82,0x3D,0x2C,0x09,0x15
	db	0xFF
L81D6:	db	0x40,0x40,0x20,0x15,0x1B,0xC4,0xC4,0x40
	db	0xFF
L81DF:	db	0x3C,0xC2,0x1C,0x15,0x10,0xC4,0xC4,0xC2
	db	0xFF
L81E8:	db	0x10,0xC4,0xC4,0xC2
	db	0xFF
	;
L81ED:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x11
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x07,0x90
	dw	L8225
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x07,0x00
	dw	L822A
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x40,0x10
	dw	L8233
	db	0xFF
L8225:	db	0x1D,0x47,0x47,0x20
	db	0xFF
L822A:	db	0x40,0x40,0x1C,0x15,0x12,0x47,0x47,0x40
	db	0xFF
L8233:	db	0x12,0x47,0x47,0x40
	db	0xFF
	;
L8238:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0xC2,0x08,0x00,0xC4,0x10,0x00,0x07,0x00
	dw	L825A
	db	0x00,0xC2,0x08,0x00,0xC4,0x10,0x00,0xC2,0x10
	dw	L8263
	db	0xFF
L825A:	db	0x3C,0xC2,0x1C,0x15,0x14,0xC2,0xC4,0xC2
	db	0xFF
L8263:	db	0x14,0xC2,0xC4,0xC2
	db	0xFF
	;
L8268:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x48,0x00,0x02,0x00,0x00,0x07,0x15
	dw	L7B32
	db	0x00,0x0A,0x08,0x00,0x01,0x10,0x00,0x07,0x15
	dw	L7B32
	db	0x00,0x2C,0x08,0x00,0xC4,0x10,0x00,0x07,0x90
	dw	L82AB
	db	0x00,0xC2,0x08,0x00,0xC4,0x10,0x00,0x07,0x00
	dw	L82B0
	db	0x00,0xC2,0x08,0x00,0xC4,0x10,0x00,0xC2,0x10
	dw	L82B9
	db	0xFF
L82AB:	db	0x1F,0x2C,0x08,0x22
	db	0xFF
L82B0:	db	0x3C,0xC2,0x1C,0x15,0x13,0xC2,0xC4,0xC2
	db	0xFF
L82B9:	db	0x13,0xC2,0xC4,0xC2
	db	0xFF
	;
L82BE:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x07,0x90
	dw	L82EB
	db	0x00,0x40,0x08,0x00,0x47,0x10,0x00,0x07,0x00
	dw	L82F0
	db	0x00,0x40,0x08,0x00,0x47,0x10,0x00,0x40,0x10
	dw	L82F9
	db	0xFF
L82EB:	db	0x21,0x47,0x47,0x22
	db	0xFF
L82F0:	db	0x40,0x40,0x1C,0x15,0x15,0x40,0x47,0x40
	db	0xFF
L82F9:	db	0x15,0x40,0x47,0x40
	db	0xFF
	;
L82FE:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x08,0x01,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x15,0x08,0x00,0x03,0x10,0x00,0x07,0x40
	dw	L7B32
	db	0x00,0x15,0x08,0x00,0x02,0x10,0x00,0x07,0x50
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x19
	dw	L7B32
	db	0x00,0x0A,0x08,0x00,0x01,0x10,0x00,0x07,0x14
	dw	L7B32
	db	0x00,0x09,0x08,0x00,0x01,0x10,0x00,0x07,0x18
	dw	L7B32
	db	0x00,0x87,0x08,0x00,0x0F,0x10,0x00,0x07,0x40
	dw	L83A4
	db	0x00,0x87,0x08,0x00,0x02,0x10,0x00,0x07,0x40
	dw	L83A4
	db	0x00,0x47,0x08,0x00,0x0F,0x10,0x00,0x07,0x50
	dw	L83AE
	db	0x00,0x47,0x08,0x00,0x03,0x10,0x00,0x07,0x50
	dw	L83AE
	db	0x00,0x2C,0x08,0x00,0x0F,0x10,0x00,0x07,0x00
	dw	L83B7
	db	0x00,0x2C,0x08,0x00,0x0F,0x10,0x00,0x0A,0x10
	dw	L83BC
	db	0xF0,0x15,0x08,0x80,0xC4,0x10,0x00,0x07,0x00
	dw	L83C1
	db	0xF0,0x15,0x08,0x80,0xC4,0x10,0x00,0x05,0x10
	dw	L83C6
	db	0xFF
L83A4:	db	0x82,0x3D,0x47,0x09,0x15,0x21,0x47,0x47,0x1D
	db	0xFF
L83AE:	db	0x3D,0x47,0x0A,0x15,0x21,0x47,0x47,0x1E
	db	0xFF
L83B7:	db	0x1F,0x2C,0x08,0x1C
	db	0xFF
L83BC:	db	0x1E,0x2C,0x08,0x0C
	db	0xFF
L83C1:	db	0x1F,0xC6,0xC6,0x1C
	db	0xFF
L83C6:	db	0x1E,0xC6,0xC6,0x0C
	db	0xFF
	;
L83CB:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x08,0x01,0x03,0x00,0x00,0x07,0x40
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x03,0x00,0x00,0x07,0x44
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x07,0x00
	dw	L8403
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x08,0x10
	dw	L8408
	db	0xFF
L8403:	db	0x21,0x47,0x47,0x1C
	db	0xFF
L8408:	db	0x20,0x47,0x47,0x0C
	db	0xFF
	;
L840D:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x38,0x01,0x01,0x00,0x00,0x07,0x19
	dw	L7B32
	db	0x00,0x15,0x38,0x00,0x03,0x10,0x00,0x07,0x44
	dw	L7B32
	db	0x00,0x15,0x38,0x00,0x02,0x10,0x00,0x07,0x54
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x0F,0x08,0x00,0x87,0x10,0x00,0x18,0x10
	dw	L8487
	db	0x00,0x0B,0x08,0x00,0x1E,0x10,0x00,0x47,0x10
	dw	L848C
	db	0x00,0x2C,0x08,0x00,0x0F,0x10,0x00,0x07,0x00
	dw	L8491
	db	0x00,0x2C,0x08,0x00,0x0F,0x10,0x00,0x0A,0x10
	dw	L8496
	db	0xF0,0x15,0x08,0x80,0xC4,0x10,0x00,0x07,0x00
	dw	L849B
	db	0xF0,0x15,0x08,0x80,0xC4,0x10,0x00,0x05,0x10
	dw	L84A0
	db	0xFF
L8487:	db	0x3D,0x2D,0x47,0x15
	db	0xFF
L848C:	db	0x3D,0x2E,0x47,0x15
	db	0xFF
L8491:	db	0x23,0x2C,0x08,0x1C
	db	0xFF
L8496:	db	0x22,0x2C,0x08,0x0C
	db	0xFF
L849B:	db	0x23,0xC6,0xC6,0x1C
	db	0xFF
L84A0:	db	0x22,0xC6,0xC6,0x0C
	db	0xFF
	;
L84A5:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x28,0x01,0x03,0x00,0x00,0x07,0x44
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x03,0x00,0x00,0x07,0x40
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x07,0x00
	dw	L84DD
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x08,0x10
	dw	L84E2
	db	0xFF
L84DD:	db	0x25,0x47,0x47,0x1C
	db	0xFF
L84E2:	db	0x24,0x47,0x47,0x0C
	db	0xFF
	;
L84E7:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x2C,0x08,0x00,0x0F,0x10,0x00,0x07,0x00
	dw	L852A
	db	0x00,0x2C,0x08,0x00,0x0F,0x10,0x00,0x0A,0x10
	dw	L852F
	db	0xF0,0x15,0x08,0x80,0xC4,0x10,0x00,0x07,0x00
	dw	L8534
	db	0xF0,0x15,0x08,0x80,0xC4,0x10,0x00,0x05,0x10
	dw	L8539
	db	0xFF
L852A:	db	0x27,0x2C,0x08,0x1C
	db	0xFF
L852F:	db	0x26,0x2C,0x08,0x0C
	db	0xFF
L8534:	db	0x27,0xC6,0xC6,0x1C
	db	0xFF
L8539:	db	0x26,0xC6,0xC6,0x0C
	db	0xFF
	;
L853E:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x03,0x00,0x00,0x07,0x40
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x07,0x44
	dw	L8576
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x07,0x00
	dw	L857B
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x08,0x10
	dw	L8580
	db	0xFF
L8576:	db	0x2B,0x47,0x47,0x15
	db	0xFF
L857B:	db	0x29,0x47,0x47,0x1C
	db	0xFF
L8580:	db	0x28,0x47,0x47,0x0C
	db	0xFF
	;
L8585:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x15,0x08,0x00,0x03,0x10,0x00,0x07,0x13
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x87,0x10,0x00,0x07,0x13
	dw	L7B32
	db	0x00,0x2E,0x08,0x00,0x01,0x10,0x00,0x07,0x13
	dw	L85D3
	db	0x00,0xC4,0x08,0x00,0xC4,0x10,0x00,0x07,0x00
	dw	L85D9
	db	0x00,0xC4,0x08,0x00,0xC4,0x10,0x00,0x40,0x10
	dw	L85E2
	db	0xFF
L85D3:	db	0x82,0x3D,0x2C,0x09,0x15
	db	0xFF
L85D9:	db	0x40,0x40,0x1C,0x15,0x1B,0xC4,0xC4,0x40
	db	0xFF
L85E2:	db	0x1B,0xC4,0xC4,0x40
	db	0xFF
	;
L85E7:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x03,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x07,0x00
	dw	L8614
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x40,0x10
	dw	L8619
	db	0xFF
L8614:	db	0x1D,0x47,0x47,0x1C
	db	0xFF
L8619:	db	0x1C,0x47,0x47,0x40
	db	0xFF
	;
L861E:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x15,0x08,0x00,0x02,0x10,0x00,0x07,0x13
	dw	L7B32
	db	0x00,0x87,0x08,0x00,0x47,0x10,0x00,0x07,0x13
	dw	L7B32
	db	0x00,0x2D,0x08,0x00,0x01,0x10,0x00,0x07,0x13
	dw	L866C
	db	0x00,0xC4,0x08,0x00,0xC4,0x10,0x00,0x07,0x00
	dw	L8671
	db	0x00,0xC4,0x08,0x00,0xC4,0x10,0x00,0x40,0x10
	dw	L8676
	db	0xFF
L866C:	db	0x3D,0x2C,0x0A,0x15
	db	0xFF
L8671:	db	0x17,0xC4,0xC4,0x1C
	db	0xFF
L8676:	db	0x16,0xC4,0xC4,0x40
	db	0xFF
	;
L867B:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x08,0x28,0x01,0x03,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x07,0x00
	dw	L86A8
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x40,0x10
	dw	L86AD
	db	0xFF
L86A8:	db	0x19,0x47,0x47,0x1C
	db	0xFF
L86AD:	db	0x18,0x47,0x47,0x40
	db	0xFF
	;
L86B2:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x2C,0x08,0x00,0x0F,0x10,0x00,0x07,0x10
	dw	L86C9
	db	0xFF
L86C9:	db	0x0A,0x2C,0x08,0x15
	db	0xFF
	;
L86CE:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x03,0x10,0x00,0x07,0x10
	dw	L86E5
	db	0xFF
L86E5:	db	0x0B,0x47,0x08,0x15
	db	0xFF
	;
L86EA:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x2C,0x08,0x00,0x0F,0x10,0x00,0x07,0x10
	dw	L8701
	db	0xFF
L8701:	db	0x2A,0x2C,0x08,0x15
	db	0xFF
	;
L8706:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x47,0x08,0x00,0x47,0x10,0x00,0x07,0x10
	dw	L871D
	db	0xFF
L871D:	db	0x2B,0x47,0x47,0x15
	db	0xFF
	;
L8722:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x49,0x08,0x00,0x03,0x10,0x00,0x07,0x10
	dw	L87D3
	db	0x00,0x49,0x08,0x00,0x47,0x10,0x00,0x07,0x50
	dw	L87D8
	db	0x00,0x15,0x08,0x00,0x47,0x10,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x49,0x08,0x00,0x47,0x10,0x00,0x08,0x10
	dw	L87DD
	db	0x00,0x49,0x08,0x00,0x02,0x10,0x00,0x07,0x10
	dw	L87D3
	db	0x00,0x49,0x08,0x00,0x87,0x10,0x00,0x07,0x40
	dw	L87D8
	db	0x00,0x15,0x08,0x00,0x87,0x10,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x49,0x08,0x00,0x87,0x10,0x00,0x0E,0x10
	dw	L87DD
	db	0x00,0x49,0x08,0x00,0x0F,0x10,0x00,0x07,0x00
	dw	L879C
	db	0x00,0x49,0x08,0x00,0x0F,0x10,0x00,0x0A,0x10
	dw	L87A1
	db	0xFF
L879C:	db	0x2D,0x49,0x08,0x1C
	db	0xFF
L87A1:	db	0x2C,0x49,0x08,0x0C
	db	0xFF
	;
L87A6:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x49,0x08,0x00,0x03,0x10,0x00,0x07,0x10
	dw	L87D3
	db	0x00,0x49,0x08,0x00,0x47,0x10,0x00,0x07,0x00
	dw	L87D8
	db	0x00,0x49,0x08,0x00,0x47,0x10,0x00,0x08,0x10
	dw	L87DD
	db	0xFF
L87D3:	db	0x30,0x49,0x08,0x1C
	db	0xFF
L87D8:	db	0x2F,0x49,0x47,0x1C
	db	0xFF
L87DD:	db	0x2E,0x49,0x47,0x0C
	db	0xFF
	;
L87E2:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x08,0x00,0x03,0x10,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x15,0x08,0x01,0x01,0x00,0x00,0x07,0x17
	dw	L7B32
	db	0x00,0x15,0x08,0x00,0x07,0x16,0x01,0x01,0x00
	dw	L7B32
	db	0x00,0x4F,0x08,0x00,0x0F,0x10,0x00,0x07,0x10
	dw	L8830
	db	0x00,0x4F,0x08,0x00,0x02,0x10,0x00,0x07,0x10
	dw	L8830
	db	0x00,0x4B,0x08,0x00,0xC4,0x10,0x00,0xC2,0x10
	dw	L8836
	db	0xFF
L8830:	db	0x82,0x36,0x4F,0x09,0x15
	db	0xFF
L8836:	db	0x33,0x4B,0xC4,0xC2
	db	0xFF
	;
L883B:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x08,0x01,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x15,0x08,0x00,0x07,0x19,0x01,0x01,0x00
	dw	L7B32
	db	0x00,0x4A,0x08,0x00,0x07,0x00,0x00,0x0F,0x10
	dw	L8888
	db	0x00,0x4B,0x08,0x00,0x0F,0x10,0x00,0x07,0x00
	dw	L887E
	db	0x00,0x4B,0x08,0x00,0x0F,0x10,0x00,0x0A,0x10
	dw	L8883
	db	0xFF
L887E:	db	0x32,0x4B,0x08,0x1C
	db	0xFF
L8883:	db	0x31,0x4B,0x08,0x0C
	db	0xFF
L8888:	db	0x32,0x4B,0x0C,0x21
	db	0xFF
	;
L888D:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x08,0x01,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x15,0x08,0x00,0x07,0x44,0x01,0x01,0x00
	dw	L7B32
	db	0x00,0x4A,0x08,0x00,0x07,0x00,0x00,0x47,0x10
	dw	L88DA
	db	0x00,0x4B,0x08,0x00,0x47,0x10,0x00,0x07,0x00
	dw	L88D0
	db	0x00,0x4B,0x08,0x00,0x47,0x10,0x00,0x08,0x10
	dw	L88D5
	db	0xFF
L88D0:	db	0x35,0x4B,0x47,0x1C
	db	0xFF
L88D5:	db	0x34,0x4B,0x47,0x0C
	db	0xFF
L88DA:	db	0x35,0x4B,0x47,0x21
	db	0xFF
	;
L88DF:	db	0x00,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0xFF
	;
L88EB:	db	0x00,0x15,0x28,0x00,0x07,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x08,0x08,0x00,0x01,0x10,0x00,0x07,0x10
	dw	L7B32
	db	0xFF
	;
L8902:	db	0x00,0x0A,0x28,0x00,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0xFF
	;
L890E:	db	0x10,0xC4,0x08,0x42,0x07,0x00,0x00,0xC4,0x10
	dw	L8972
	db	0x10,0xC4,0x08,0x43,0x07,0x00,0x00,0xC4,0x10
	dw	L8977
	db	0x10,0x08,0x08,0x00,0x0B,0x10,0x00,0x0D,0x10
	dw	L7B32
	db	0x10,0x08,0x08,0x00,0x0B,0x10,0x00,0x0D,0x60
	dw	L898B
	db	0x10,0x08,0x08,0x00,0x0B,0x10,0x00,0x04,0x10
	dw	L897C
	db	0x10,0x15,0x38,0x00,0x0B,0x10,0x02,0x07,0x00
	dw	L8981
	db	0x10,0x08,0x08,0x00,0x0B,0x10,0x40,0xC4,0x10
	dw	L8986
	db	0x10,0x15,0x38,0x08,0x07,0x10,0x00,0x07,0x00
	dw	L8990
	db	0x10,0x0C,0x08,0x08,0x07,0x10,0x00,0x05,0x10
	dw	L8997
	db	0xFF
L8972:	db	0x3A,0x15,0x18,0xC4
	db	0xFF
L8977:	db	0x3B,0x15,0x18,0xC4
	db	0xFF
L897C:	db	0x37,0x08,0x0C,0x15
	db	0xFF
L8981:	db	0x3C,0x08,0x1C,0x15
	db	0xFF
L8986:	db	0x46,0x2C,0xC4,0x15
	db	0xFF
L898B:	db	0x02,0x08,0x08,0x1C
	db	0xFF
L8990:	db	0x9C,0x43,0x15,0xC4,0x1C,0x9E
	db	0xFF
L8997:	db	0x56,0x15,0x0C,0x15,0x9C,0x57,0x0C,0x15
	db	0x15,0x41,0x15,0xC4,0x0C,0x56,0x15,0x0C
	db	0x15,0x9E,0x57,0x0C,0x15,0x15
	db	0xFF
	;
L89AE:	db	0x10,0x47,0x08,0x42,0x07,0x00,0x00,0x47,0x10
	dw	L8A07
	db	0x10,0x08,0x08,0x00,0x0C,0x10,0x00,0x0D,0x70
	dw	L8A0C
	db	0x10,0x08,0x08,0x00,0x0C,0x10,0x00,0x07,0x00
	dw	L8A11
	db	0x10,0x08,0x08,0x00,0x0C,0x10,0x00,0x03,0x10
	dw	L8A16
	db	0x10,0x0C,0x08,0x40,0x05,0x10,0x00,0x47,0x10
	dw	L8A1B
	db	0x10,0x0C,0x08,0x60,0x04,0x11,0x00,0x47,0x10
	dw	L8A1B
	db	0x10,0x15,0x38,0x09,0x07,0x10,0x00,0x07,0x00
	dw	L8A22
	db	0x10,0x0C,0x08,0x09,0x07,0x10,0x00,0x09,0x10
	dw	L8A29
	db	0xFF
L8A07:	db	0x3F,0x15,0x18,0x47
	db	0xFF
L8A0C:	db	0x06,0x08,0x08,0x1C
	db	0xFF
L8A11:	db	0x40,0x08,0x1C,0x15
	db	0xFF
L8A16:	db	0x3D,0x08,0x0C,0x15
	db	0xFF
L8A1B:	db	0x98,0x44,0x15,0x08,0x47,0x9A
	db	0xFF
L8A22:	db	0x9C,0x45,0x15,0xC4,0x1C,0x9E
	db	0xFF
L8A29:	db	0x56,0x15,0x0C,0x15,0x9C,0x57,0x0C,0x15
	db	0x15,0x44,0x15,0xC4,0x0C,0x56,0x15,0x0C
	db	0x15,0x9E,0x57,0x0C,0x15,0x15
	db	0xFF
	;
L8A40:	db	0x40,0x08,0x28,0x01,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x60,0x08,0x28,0x21,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0xFF
	;
L8A57:	db	0x00,0x08,0x28,0x41,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x20,0x08,0x28,0x61,0x01,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x10,0x15,0x68,0x00,0x0C,0x10,0x00,0x07,0x10
	dw	L8A84
	db	0x10,0x15,0x68,0x00,0x0B,0x10,0x00,0x07,0x10
	dw	L8A84
	db	0xFF
L8A84:	db	0x63,0x08,0x15,0x15
	db	0xFF
	;
L8A89:	db	0x00,0x2C,0x08,0x02,0x07,0x00,0x00,0x07,0x10
	dw	L7C96
	db	0x00,0x08,0x0C,0x00,0x04,0x10,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x2C,0x08,0x00,0x04,0x10,0x00,0x07,0x10
	dw	L7CA0
	db	0xFF
	;
L8AAB:	db	0x00,0x2E,0x08,0x00,0x07,0x00,0x00,0x07,0x10
	dw	L8AC2
	db	0x00,0x2E,0x08,0x00,0x03,0x10,0x00,0x07,0x10
	dw	L8AC7
	db	0xFF
L8AC2:	db	0x40,0x2C,0x18,0x15
	db	0xFF
L8AC7:	db	0x3D,0x2C,0x08,0x15
	db	0xFF
	;
L8ACC:	db	0x02,0x0C,0x30,0xE1,0x01,0x00,0xE1,0x01,0x00
	dw	L8AD8
	db	0xFF
L8AD8:	db	0x80,0x81
	db	0xFF
	;
L8ADB:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x00,0x00,0x07,0x10,0xC0,0x07,0x10
	dw	L7B32
	db	0x00,0x15,0x00,0xC0,0x07,0x10,0x10,0x07,0x10
	dw	L7B32
	db	0xC0,0x15,0x00,0x00,0x07,0x20,0xC0,0x07,0x10
	dw	L8B1E
	db	0xC0,0x15,0x00,0xC0,0x07,0x10,0x10,0x07,0x20
	dw	L8B20
	db	0xC0,0x15,0x00,0xC0,0x07,0x10,0xC0,0x07,0x10
	dw	L8B22
	db	0xFF
	;
L8B1E:	db	0x81
	db	0xFF
	;
L8B20:	db	0x80
	db	0xFF
	;
L8B22:	db	0x80,0x8E,0x81,0x86
	db	0xFF
	;
L8B27:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x00
	dw	L7B32
	db	0x00,0x15,0x10,0x00,0x07,0x20,0xC0,0x07,0x10
	dw	L7B32
	db	0x00,0x15,0x10,0xC0,0x07,0x10,0x10,0x07,0x20
	dw	L7B32
	db	0xC0,0x15,0x00,0x00,0x07,0x10,0xC0,0x07,0x10
	dw	L8B1E
	db	0xC0,0x15,0x00,0xC0,0x07,0x10,0x10,0x07,0x10
	dw	L8B20
	db	0xC0,0x15,0x00,0xC0,0x07,0x10,0xC0,0x07,0x10
	dw	L8B6A
	db	0xFF
L8B6A:	db	0x80,0x90,0x81,0x88
	db	0xFF
	;
L8B6F:	db	0x00,0x15,0x48,0x00,0x07,0x00,0x00,0x07,0x10
	dw	L7B32
	db	0x00,0x23,0x08,0x00,0x06,0x10,0x00,0x07,0x10
	dw	L7B32
	db	0xC0,0x15,0x00,0xC0,0x07,0x10,0x00,0x07,0x10
	dw	L8B91
	db	0xFF
L8B91:	db	0x80,0x8A
	db	0xFF


T8B94:	db	0x01,0x00,0x00,0xC4,0x10
	;
T8B99:	db	0x01,0x00,0x00,0x47,0x10
	;
T8B9E:	db	0x01,0x00,0x02,0x07,0x00
	;
T8BA3:	db	0x02,0x00,0x00,0x07,0x00,0xC0,0x07,0x10
	;
T8BAB:	db	0x01,0x00,0xE1,0x01,0x00
	;
T8BB0:	db	0x02,0x00,0x00,0x04,0x10,0x00,0x18,0x10
	;
T8BB8:	db	0x02,0x00,0x00,0x41,0x10,0x00,0xC0,0x10
	;
T8BC0:	db	0x02,0x00,0x00,0x43,0x10,0x00,0xC2,0x10
	;
T8BC8:	db	0x02,0x00,0x00,0x47,0x10,0x00,0xC4,0x10
	;
T8BD0:	db	0x02,0x00,0x42,0x07,0x00,0x40,0x04,0x10
	;
T8BD8:	db	0x03,0x00,0x40,0xC4,0x10,0x60,0x04,0x12
	db	0x61,0x07,0x12
	;
T8BE3:	db	0x02,0x00,0x40,0xC4,0x10,0x61,0x07,0x11
	;
T8BEB:	db	0x01,0x00,0x40,0xC4,0x10


T8BF0:	dw	L9265
	dw	T8CF0
	dw	L7272
	dw	abort1			;L0000  пустышка ??
	dw	L8D23
	dw	L7241
	dw	L71D4
	dw	L8D2C
	dw	L8D9B
	dw	L8DC7
	dw	L8DCE
	dw	L8DFA
	dw	L8E10
	dw	L713A
	dw	L8E1A
	dw	L70B1
	dw	L8E24
	dw	L8E2E
	dw	L8E38
	dw	L8E24
	dw	L8E2E
	dw	L8E38
	dw	L8E42
	dw	L705B
	dw	L8E4B
	dw	L6FDD
	dw	L8E54
	dw	L8E5E
	dw	L8E68
	dw	L6F60
	dw	L8E71
	dw	L6F35
	dw	L8E9B
	dw	L8EA2
	dw	L8EA9
	dw	L6ED8
	dw	L8ED1
	dw	L8ED7
	dw	L8EDD
	dw	L6E31
	dw	L8F07
	dw	L8F0E
	dw	L8F15
	dw	L8F3B
	dw	L8F40
	dw	L6B81
	dw	L8F64
	dw	L8F6A
	dw	L8F94
	dw	L8FB9
	dw	L6B1C
	dw	L8FD7
	dw	L8F64
	dw	L8F78
	dw	L8F94
	dw	L9195
	dw	L8FE1
	dw	L6AB6
	dw	L8FEC
	dw	L6A4A
	dw	L8FF7
	dw	L91A4
	dw	L8FFF
	dw	L9009
	dw	L9013
	dw	L9086
	dw	L90A2
	dw	L90BE
	dw	L90E5
	dw	L90DA
	dw	L902A
	dw	L906D
	dw	L6A0D
	dw	L697D
	dw	L917E
	dw	L90FE
	dw	L9111
	dw	L9119
	dw	L911F
	dw	L9127
	dw	L912E
	dw	L9133
	dw	L913D
	dw	L9150
	dw	L916D
	dw	L9176
	dw	L9266
	dw	L9266
	dw	L6A4E
	dw	L91AC
	dw	L6A71
	dw	L91D5
	dw	L6ABA
	dw	L9209
	dw	L6ADD
	dw	L9227
	dw	L9266
	dw	L9266
	dw	L925B
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L9266
	dw	L926D
	dw	L9288
	dw	L9266


	%include "io2.asm"		; дисковые операции


T8CF0:	db	94h,"add",9,"hl,",86h
	db	0xFF
	;
T8CFA:	db	9Dh,04h
	dw	L8D10
	db	94h,"ld",9,"hl,",8Eh
	db	94h,"add",9,"hl,",85h
	db	0xFF
	;
L8D10:	db	94h,"ld",9,"bc,",8Eh
	db	94h,"add",9,"hl,bc"
	db	0xFF
	;
L8D23:	db	94h,"add",9,"a,",82h
	db	0xFE
	;
L8D2C:	db	9Dh,04h
	dw	L8D5C
	db	94h,"ld",9,"a,",89h
	db	94h,"sub",9,8Ah
	db	94h,"ld",9,88h,",a",0A0h
	db	94h,"ld",9,"a,",81h
	db	94h,"sbc",9,"a,",82h
	db	94h,"ld",9,80h,",a"
	db	0xFF
	;
L8D5C:	db	9Ch,04h
	dw	L8D8C
	db	94h,"ld",9,"a,",89h
	db	94h,"sub",9,8Ah
	db	94h,"ld",9,88h,",a",0A0h
	db	94h,"ld",9,"a,",81h
	db	94h,"sbc",9,"a,",82h
	db	94h,"ld",9,80h,",a"
	db	0xFF
	;
L8D8C:	db	94h,"or",9,"a"
	db	94h,"sbc",9,"hl,",86h
	db	0xFF
	;
L8D9B:	db	94h,"ld",9,"a,",0A8h
	db	94h,"sub",9,8Ah
	db	94h,"ld",9,88h,",a",0A0h
	db	94h,"ld",9,"a,",0ACh
	db	94h,"sbc",9,"a,",82h
	db	94h,"ld",9,80h,",a"
	db	0xFF
	;
L8DC7:	db	94h,"sub",9,82h
	db	0xFE
	;
L8DCE:	db	94h,"ld",9,"a,",89h
	db	94h,"cpl"
	db	94h,"ld",9,88h,",a",0A0h
	db	94h,"ld",9,"a,",81h
	db	94h,"cpl"
	db	94h,"ld",9,80h,",a"
	db	94h,"inc",9,84h
	db	0xFF
	;
L8DFA:	db	9Dh,07h
	dw	L8E0B
	db	94h,"xor",9,"a"
	db	94h,"sub",9,81h
	db	0xFE
	;
L8E0B:	db	94h,"neg"
	db	0xFE
	;
L8E10:	db	94h,"<","?mulhd",">"
	db	0xFF
	;
L8E1A:	db	94h,"<","?mulab",">"
	db	0xFF
	;
L8E24:	db	94h,"<","?dvnhd",">"
	db	0xFF
	;
L8E2E:	db	94h,"<","?dvihd",">"
	db	0xFF
	;
L8E38:	db	94h,"<","?dvbab",">"
	db	0xFF
	;
L8E42:	db	94h,"<","?slhb",">"
	db	0xFF
	;
L8E4B:	db	94h,"<","?slab",">"
	db	0xFF
	;
L8E54:	db	94h,"<","?srihb",">"
	db	0xFF
	;
L8E5E:	db	94h,"<","?srnhb",">"
	db	0xFF
	;
L8E68:	db	94h,"<","?srab",">"
	db	0xFF
	;
L8E71:	db	94h,"ld",9,"a,",89h
	db	94h,"and",9,8Ah
	db	94h,"ld",9,88h,",a",0A0h
	db	94h,"ld",9,"a,",81h
	db	94h,"and",9,82h
	db	94h,"ld",9,80h,",a"
	db	0xFF
	;
L8E9B:	db	94h,"and",9,82h
	db	0xFE
	;
L8EA2:	db	94h,"and",9,0B0h
	db	0xFE
	;
L8EA9:	db	94h,"ld",9,"a,",89h
	db	94h,"or",9,8Ah
	db	94h,"ld",9,88h,",a",0A0h
	db	94h,"ld",9,"a,",81h
	db	94h,"or",9,82h
	db	94h,"ld",9,80h,",a"
	db	0xFF
	;
L8ED1:	db	94h,"or",9,82h
	db	0xFE
	;
L8ED7:	db	94h,"or",9,0B0h
	db	0xFE
	;
L8EDD:	db	94h,"ld",9,"a,",89h
	db	94h,"xor",9,8Ah
	db	94h,"ld",9,88h,",a",0A0h
	db	94h,"ld",9,"a,",81h
	db	94h,"xor",9,82h
	db	94h,"ld",9,80h,",a"
	db	0xFF
	;
L8F07:	db	94h,"xor",9,82h
	db	0xFE
	;
L8F0E:	db	94h,"xor",9,0B0h
	db	0xFE
	;
L8F15:	db	94h,"ld",9,"a,",89h
	db	94h,"cpl"
	db	94h,"ld",9,88h,",a",0A0h
	db	94h,"ld",9,"a,",81h
	db	94h,"cpl"
	db	94h,"ld",9,80h,",a"
	db	0xFF
	;
L8F3B:	db	94h,"cpl"
	db	0xFF
	;
L8F40:	db	94h,"ld",9,"a,",89h
	db	94h,"cp",9,8Ah,0A0h
	db	94h,"jr",9,"nz,$+4"
	db	94h,"ld",9,"a,",81h
	db	94h,"cp",9,82h
	db	0xFF
	;
L8F64:	db	94h,"cp",9,82h
	db	0xFF
	;
L8F6A:	db	0A1h,00h
	dw	L8F74
	db	94h,"or",9,"a"
	db	0xFF
	;
L8F74:	db	0A4h,80h
	dw	L8F7E
L8F78:	db	94h,"cp",9,0B0h
	db	0xFF
	;
L8F7E:	db	0A1h,01h
	dw	L8F89
	db	94h,"dec",9,"a"
	db	0xFF
	;
L8F89:	db	0A1h,0FFh
	dw	L8F78
	db	94h,"inc",9,"a"
	db	0xFF
	;
L8F94:	db	9Dh,06h
	dw	L8FA9
	db	9Dh,07h
	dw	L8FB3
	db	94h,"inc",9,81h
	db	94h,"dec",9,81h
	db	0xFF
	;
L8FA9:	db	94h,"ld",9,"a,(hl)"
L8FB3:	db	94h,"or",9,"a"
	db	0xFF
	;
L8FB9:	db	94h,"ld",9,"a,",89h
	db	94h,"sub",9,8Ah,0A0h
	db	94h,"ld",9,"a,",81h
	db	94h,"sbc",9,"a,",82h
	db	0xFF
	;
L8FD7:	db	94h,"<","?cpshd",">"
	db	0xFF
	;
L8FE1:	db	94h,"ld",9,"hl,(",8Dh,")"
	db	0xFF
	;
L8FEC:	db	94h,"ld",9,"(",8Dh,"),hl"
	db	0xFF
	;
L8FF7:	db	94h,"ld",9,84h,",",8Dh
	db	0xFF
	;
L8FFF:	db	94h,"ld",9,"a,(",8Dh,")"
	db	0xFF
	;
L9009:	db	94h,"ld",9,"(",8Dh,"),a"
	db	0xFF
	;
L9013:	db	9Ch,07h
	dw	L901F
L9017:	db	94h,"ld",9,80h,",",0B0h
	db	0xFF
	;
L901F:	db	0A1h,00h
	dw	L9017
	db	94h,"xor",9,"a"
	db	0xFF
	;
L902A:	db	9Ch,04h
	dw	L904A
	db	94h,"ld",9,88h,",(hl)"
	db	94h,"inc",9,"hl"
	db	94h,"ld",9,80h,",(hl)"
	db	0xFF
	;
L904A:	db	94h,"ld",9,"a,(hl)"
	db	94h,"inc",9,"hl"
	db	94h,"ld",9,"h,(hl)"
	db	94h,"ld",9,"l,a"
	db	0xFF
	;
L906D:	db	9Dh,04h
	dw	L907B
	db	94h,"ld",9,"a,(",85h,")"
	db	0xFF
	;
L907B:	db	94h,"ld",9,80h,",(hl)"
	db	0xFF
	;
L9086:	db	94h,"ld",9,"(hl),",8Ah
	db	94h,"inc",9,"hl"
	db	94h,"ld",9,"(hl),",82h
	db	0xFF
	;
L90A2:	db	94h,"ld",9,"(hl),",82h
	db	94h,"dec",9,"hl"
	db	94h,"ld",9,"(hl),",8Ah
	db	0xFF
	;
L90BE:	db	94h,"ld",9,"(hl),",0A8h
	db	94h,"inc",9,"hl"
	db	94h,"ld",9,"(hl),",0ACh
	db	0xFF
	;
L90DA:	db	94h,"ld",9,"(hl),",0B0h
	db	0xFF
	;
L90E5:	db	9Dh,04h
	dw	L90F3
	db	94h,"ld",9,"(",85h,"),a"
	db	0xFF
	;
L90F3:	db	94h,"ld",9,"(hl),",82h
	db	0xFF
	;
L90FE:	db	94h,"ld",9,"hl,",96h
	db	94h,"add",9,"hl,sp"
	db	0xFF
	;
L9111:	db	94h,"jp",9,91h,",",95h
	db	0xFF
	;
L9119:	db	94h,"jp",9,95h
	db	0xFF
	;
L911F:	db	94h,"call",9,8Dh
	db	0xFF
	;
L9127:	db	94h,"ret",9,91h
	db	0xFF
	;
L912E:	db	94h,"ret"
	db	0xFF
	;
L9133:	db	94h,"ld",9,"hl,@",8Dh
	db	0xFF
	;
L913D:	db	94h,"ret",0Ah
	db	";(call)",0Ah
	db	"@",8Dh,":",98h,98h
	db	0xFF
	;
L9150:	db	94h,"ld",9,"hl,",8Dh
	db	94h,"add",9,"hl,sp"
	db	94h,"ld",9,"sp,hl",99h
	db	0xFF
	;
L916D:	db	94h,"push",9,85h,97h
	db	0xFF
	;
L9176:	db	98h,94h,"pop",9,84h
	db	0xFF
	;
L917E:	db	98h,94h,"dec",9,"sp"
	db	94h,"pop",9,"af"
	db	94h,"inc",9,"sp"
	db	0xFF
	;
L9195:	db	94h,"ld",9,88h,",",89h
	db	94h,"ld",9,80h,",",81h
	db	0xFF
	;
L91A4:	db	94h,"ld",9,80h,",",81h
	db	0xFF
	;
L91AC:	db	9Dh,04h
	dw	L91CA
	db	9Dh,02h
	dw	L91BF
	db	94h,"ld",9,"(",8Ch,"),bc"
	db	0xFF
	;
L91BF:	db	94h,"ld",9,"(",8Ch,"),de"
	db	0xFF
	;
L91CA:	db	94h,"ld",9,"(",8Ch,"),hl"
	db	0xFF
	;
L91D5:	db	9Dh,05h
	dw	L91E1
	db	9Dh,07h
	dw	L91EA
	db	0A4h,30h
	dw	L91F6
L91E1:	db	0A5h,80h
	db	94h,"ld",9,"a,",81h
L91EA:	db	94h,"ld",9,"(",8Ch,"),a"
	db	0A6h,80h
	db	0xFF
	;
L91F6:	db	94h,"ld",9,"hl,",8Ch
	db	94h,"ld",9,"(hl),",81h
	db	0xFF
	;
L9209:	db	9Ch,04h
	dw	L8FE1
	db	9Ch,02h
	dw	L921C
	db	94h,"ld",9,"bc,(",8Dh,")"
	db	0xFF
	;
L921C:	db	94h,"ld",9,"de,(",8Dh,")"
	db	0xFF
	;
L9227:	db	9Ch,05h
	dw	L8FE1
	db	9Ch,07h
	dw	L8FFF
	db	0A4h,30h
	dw	L9248
	db	0A5h,80h
	db	94h,"ld",9,"a,(",8Dh,")"
	db	94h,"ld",9,80h,",a"
	db	0A6h,80h
	db	0xFF
	;
L9248:	db	94h,"ld",9,"hl,",8Dh
	db	94h,"ld",9,80h,",(hl)"
	db	0xFF
	;
L925B:	db	94h,"ex",9,"de,hl"
	db	0xFF
	;
L9265:	db	0FDh
L9266:	db	94h,"?bug?"
	db	0xFF
	;
L926D:	db	94h,"push",9,"ix"
	db	94h,"ld",9,"ix,0"
	db	94h,"add",9,"ix,sp"
	db	0xFF
	;
L9288:	db	94h,"ld",9,"sp,ix"
	db	94h,"pop",9,"ix"
	db	0xFF


T9299:	db	0x00,0x01,0x04,0x00,0x01,0x02,0x01,0x06
	db	0x08,0x01,0x07,0x02,0x05,0x03,0x05,0x03
	db	0x05,0x05,0x05,0x05,0x05,0x05,0x05,0x03
	db	0x05,0x03,0x05,0x05,0x05,0x03,0x06,0x08
	db	0x01,0x02,0x06,0x08,0x01,0x02,0x06,0x08
	db	0x01,0x02,0x06,0x01,0x07,0x09,0x01,0x02
	db	0x01,0x04,0x06,0x05,0x01,0x02,0x01,0x02
	db	0x03,0x05,0x03,0x05,0x03,0x01,0x03,0x03
	db	0x02,0x03,0x00,0x05,0x01,0x02,0x03,0x01
	db	0x07,0x08,0x03,0x04,0x03,0x03,0x03,0x01
	db	0x01,0x03,0x01,0x05,0x01,0x01,0x01,0x01
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
	db	0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
	db	0x00,0x00


T931B:	db	0x00,0x00,0x30,0x0C,0x00,0xCF,0x00,0x00
	db	0x80,0xCF,0x80,0xCF,0x00,0xC3,0x80,0xCF
	db	0x80,0xCF,0x80,0xCF,0x80,0x00,0x80,0xCF
	db	0xBF,0xCF,0x30,0x0C,0xBF,0xCF,0x80,0xCF
	db	0xBF,0xCF,0xBF,0xCF,0xBF,0xCF,0xBF,0xCF
	db	0xBF,0xCF,0xBF,0xCF,0x32,0x0C,0x30,0x0C
	db	0x82,0xCF,0x00,0xCF,0xB2,0xCF,0xB2,0xCF
	db	0x82,0xCF,0x00,0xCF,0x80,0xCF,0x80,0xCF
	db	0x80,0xCF,0x80,0xCF,0x80,0xCF,0x80,0xCF
	db	0x80,0xCF,0x80,0xCF,0x80,0xCF,0x80,0xCF
	db	0x80,0xCF,0x80,0xCF,0x80,0x00,0x80,0x00
	db	0x80,0xCF,0x80,0xCF,0x00,0xCF,0x00,0xCF
	db	0x00,0xCF,0x80,0xCF,0x80,0xCF,0x80,0xCF
	db	0x00,0xCF,0x00,0xCF,0x00,0xCF,0x00,0x00
	db	0x00,0x00,0x0C,0x0C,0x00,0x00,0x0C,0x0C
	db	0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
	db	0x00,0x00,0x30,0x00,0x00,0x00,0x30,0x00
	db	0x00,0x00,0x00,0x00,0x30,0x00,0x00,0x00
	db	0xBC,0xCF,0xBC,0xCF,0x80,0xCF,0x30,0x0C
	db	0x00,0x00,0x00,0x00,0xFF,0xCF,0x00,0x00
	db	0x00,0x00,0x00,0x00,0xFF,0xCF,0x30,0x0C
	ds	85



; знак. сравнение hl с de
cpshd:	ld	a,h
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


; сдвиг "a" вправо (деление на 2), счетчик "b"
A9426:	inc	b
	dec	b
	ret	z
.loc1:	srl	a
	djnz	.loc1
	ret


; сдвиг "hl" вправо (деление на 2), счетчик "b"
A942E:	inc	b
	dec	b
	ret	z
.loc1:	srl	h
	rr	l
	djnz	.loc1
	ret


; сдвиг "a" влево (умнож. на 2), счетчик "b"
A9438:	inc	b
	dec	b
	ret	z
.loc1:	add	a,a
	djnz	.loc1
	ret


; сдвиг "hl" влево (умнож. на 2), счетчик "b"
A943F:	inc	b
	dec	b
	ret	z
.loc1:	add	hl,hl
	djnz	.loc1
	ret


A9446:	ld	a,h
	or	a
	push	af
	xor	d
	push	af
	call	A9461
	ex	de,hl
	call	A9461
	ex	de,hl
	call	div_hlde		; hl/de=hl
	pop	af
	call	m,A9464
	pop	af
	ex	de,hl
	call	m,A9464
	ex	de,hl
	ret



A9461:	ld	a,h
	or	a
	ret	p
A9464:	dec	hl
	ld	a,l
	cpl
	ld	l,a
	ld	a,h
	cpl
	ld	h,a
	ret


; деление hl/de=hl
div_hlde:
	ld	b,d
	ld	c,e
	ld	de,0
	ld	a,16
A9473:	ex	af,af'
	add	hl,hl
	rl	e
	rl	d
	jr	c,A9481
	ld	a,e
	sub	c
	ld	a,d
	sbc	a,b
	jr	c,A9488
A9481:	ld	a,e
	sub	c
	ld	e,a
	ld	a,d
	sbc	a,b
	ld	d,a
	inc	l
A9488:	ex	af,af'
	dec	a
	jr	nz,A9473
	ret


; умножение hl*de=hl
mul_hlde:
	ld	b,h
	ld	c,l
	ld	hl,0
	ld	a,16
A9495:	add	hl,hl
	ex	de,hl
	add	hl,hl
	ex	de,hl
	jr	nc,A949C
	add	hl,bc
A949C:	dec	a
	jr	nz,A9495
	ret



A94AE:	ld	de,6
	jr	A94C0

A94B4:	ld	de,4
	jr	A94C0

A94BA:	ex	(sp),hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	ex	(sp),hl
A94C0:	ex	de,hl
	add	hl,sp
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ex	de,hl
	ret


A94C7:	ld	hl,10
	jr	A94EC
	;
A94D3:	ld	hl,8
	jr	A94EC
	;
A94D9:	ld	hl,6
	jr	A94EC
	;
A94DF:	ld	hl,4
	jr	A94EC

A94E5:	pop	hl
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	inc	hl
	push	hl
	ex	de,hl
A94EC:	add	hl,sp
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ex	de,hl
	ret




D9531:	db	0
D9532:	db	0
D9533:	dw	64000			; #FA00 счетчик недост. (необход.) размера таблицы идентиф.
D9535:	dw	0
D9537:	dw	0

warnings:
	db	false			; флаг наличия предупреждений



tmc_handle:
	db	0			; дескриптор tmc-файла
asm_handle:
	db	0			; дескриптор asm-файла

tmc_filename:
	ds	65			; имя .TMC файла

asm_filename:
	ds	65			; имя ASM-файла


; Буфер вход. данных .TMC файла
T95A9:	ds	512
	db	0

; Буфер вых. данных .ASM файла
T97AA:	ds	512


D99AA:	dw	0			; 0..512  число байт для чтения (ст.байт как флаг чтения блока)
D99AC:	dw	0			; 0..512  число байт для записи (ст.байт как флаг записи блока)


; Сохр. текущего диска и пути
disk:	db	"A"
dir:	ds	65



D99F0:	db	0			; false/true ?
D99F1:	dw	0
D99F3:	dw	0
T99F5:	db	0
D99F6:	db	0
D99F7:	dw	0
D99F9:	dw	0
D99FB:	dw	0
D99FD:	dw	0
D99FF:	dw	0
D9A01:	db	0
D9A02:	dw	0
D9A04:	dw	0
D9A06:	dw	0
D9A08:	dw	0
D9A0A:	dw	0
D9A0C:	db	0
D9A0D:	dw	0
D9A0F:	db	0
D9A10:	dw	0
D9A12:	dw	0
D9A14:	dw	0
D9A16:	dw	0
D9A18:	dw	0
D9A1A:	dw	0
D9A1C:	dw	0
D9A1E:	db	0
D9A1F:	dw	0
D9A21:	dw	0
D9A23:	dw	0
D9A25:	dw	0
D9A27:	dw	0
D9A29:	dw	0
D9A2B:	db	0
D9A2C:	dw	0
D9A2E:	dw	0
D9A30:	dw	0
D9A32:	db	0
D9A33:	dw	0
D9A35:	dw	0
D9A37:	db	0
D9A38:	dw	0
D9A3A:	dw	0
D9A3C:	dw	0
D9A3E:	dw	0
D9A40:	dw	0
D9A42:	db	0
D9A43:	dw	0
D9A45:	dw	0
D9A47:	dw	0
D9A49:	dw	0
D9A4B:	dw	0
D9A4D:	dw	0
D9A4F:	dw	0
D9A51:	db	0
	;
D9A52:	ds	60
	;
D9A8E:	db	0
D9A8F:	dw	0
D9A91:	dw	0
D9A93:	dw	0
D9A95:	dw	0
D9A97:	dw	0
D9A99:	dw	0
D9A9B:	db	0
T9A9C:	db	0
D9A9D:	db	0
D9A9E:	dw	0
D9AA0:	db	0
D9AA1:	dw	0
D9AA3:	dw	0
D9AA5:	dw	0
D9AA7:	dw	0
D9AA9:	dw	0
D9AAB:	dw	0
D9AAD:	dw	0
D9AAF:	dw	0
D9AB1:	dw	0
D9AB3:	dw	0
D9AB5:	dw	0
D9AB7:	db	0
D9AB8:	dw	0
D9ABA:	dw	0
D9ABC:	dw	0
D9ABE:	dw	0
D9AC0:	dw	0
D9AC2:	dw	0
D9AC4:	dw	0
D9AC6:	dw	0
D9AC8:	db	0
D9AC9:	db	0
D9ACA:	db	0
D9ACB:	dw	0
D9ACD:	db	0
D9ACE:	db	0
D9ACF:	dw	0
D9AD1:	db	0
D9AD2:	db	0
D9AD3:	db	0
D9AD4:	db	0
D9AD5:	db	0
D9AD6:	db	0
D9AD7:	dw	0
D9AD9:	db	0
D9ADA:	dw	0
D9ADC:	db	0
D9ADD:	db	0
D9ADE:	dw	0
D9AE0:	db	0
T9AE1:	db	0
D9AE2:	dw	0
D9AE4:	db	0
D9AE5:	db	0,0,0
D9AE8:	db	0
	;
T9AE9:	ds	16
	;
T9AF9:	ds	32
	;
D9B19:	dw	0
D9B1B:	dw	0
D9B1D:	dw	0
D9B1F:	db	0
D9B20:	db	0
D9B21:	dw	0
D9B23:	dw	0
D9B25:	dw	0
D9B27:	db	0
D9B28:	dw	0
T9B2A:	db	0
D9B2B:	db	0
D9B2C:	dw	0
D9B2E:	dw	0
D9B30:	dw	0
D9B32:	dw	0
D9B34:	dw	0
D9B36:	dw	0
D9B38:	db	0
D9B39:	db	0
D9B3A:	db	0
D9B3B:	db	0
D9B3C:	db	0
D9B3D:	dw	0
D9B3F:	dw	0
D9B41:	db	0
D9B42:	dw	0
D9B44:	db	0
D9B45:	db	0
D9B46:	dw	0
D9B48:	dw	0
D9B4A:	dw	0
D9B4C:	db	0
D9B4D:	db	0
D9B4E:	dw	0
D9B50:	db	0
D9B51:	db	0
D9B52:	dw	0
D9B54:	dw	0
D9B56:	dw	0
D9B58:	dw	0
D9B5A:	db	0
D9B5B:	dw	0
D9B5D:	dw	0
D9B5F:	db	0
D9B60:	db	0
D9B61:	dw	0
D9B63:	db	0
D9B64:	dw	0
D9B66:	db	0
D9B67:	dw	0
D9B69:	db	0
D9B6A:	db	0
D9B6B:	db	0
D9B6C:	db	0
D9B6D:	db	0
D9B6E:	dw	0
D9B70:	db	0
D9B71:	db	0
D9B72:	db	0
D9B73:	db	0
D9B74:	db	0
D9B75:	db	0
D9B76:	dw	0
D9B78:	dw	0
D9B7A:	db	0
D9B7B:	db	0
D9B7C:	dw	0
D9B7E:	db	0
D9B7F:	dw	0
D9B81:	dw	0
D9B83:	dw	0
D9B85:	dw	0
D9B87:	db	0
D9B88:	db	0
D9B89:	dw	0
D9B8B:	dw	0
D9B8D:	dw	0
D9B8F:	dw	0
D9B91:	dw	0
D9B93:	dw	0
D9B95:	dw	0
D9B97:	db	0
D9B98:	db	0
D9B99:	dw	0
D9B9B:	dw	0
D9B9D:	dw	0
D9B9F:	db	0
D9BA0:	dw	0
D9BA2:	db	0
D9BA3:	db	0
D9BA4:	db	0
D9BA5:	dw	0
D9BA7:	db	0
D9BA8:	db	0
T9BA9:	db	0
D9BAA:	db	0
D9BAB:	dw	0
D9BAD:	dw	0
D9BAF:	dw	0
D9BB1:	dw	0
D9BB3:	dw	0
D9BB5:	dw	0
D9BB7:	dw	0
D9BB9:	dw	0
D9BBB:	dw	0
D9BBD:	db	0
D9BBE:	db	0
D9BBF:	db	0
D9BC0:	db	0
D9BC1:	dw	0
D9BC3:	dw	0
D9BC5:	dw	0
D9BC7:	db	0
D9BC8:	dw	0
D9BCA:	dw	0
D9BCC:	dw	0
D9BCE:	db	0
D9BCF:	dw	0
D9BD1:	dw	0
D9BD3:	dw	0
	;
T9BD5:	ds	16
	;
D9BE5:	db	0
	;
D9BE6:	db	"_"			; символ постфикса имен asm-листинга
	;
D9BE7:	dw	0
D9BE9:	dw	0
D9BEB:	db	0
D9BEC:	db	0
D9BED:	db	0
D9BEE:	db	0,0,0
D9BF1:	dw	0
D9BF3:	dw	0
D9BF5:	dw	0
D9BF7:	dw	0
D9BF9:	dw	0
D9BFB:	dw	0
D9BFD:	dw	0
D9BFF:	dw	0
D9C01:	dw	0
D9C03:	dw	0
D9C05:	dw	0
D9C07:	dw	0
D9C09:	dw	0
D9C0B:	db	0
D9C0C:	db	0
D9C0D:	db	0
D9C0E:	db	0
D9C0F:	dw	0
D9C11:	dw	0
D9C13:	db	0
D9C14:	db	0,0,0
D9C17:	db	0,0,0
D9C1A:	db	0
D9C1B:	db	0
D9C1C:	db	0
D9C1D:	dw	0
D9C1F:	db	0
D9C20:	dw	0
D9C22:	db	0
D9C23:	dw	0
	;
D9C25:	ds	13
	;
D9C32:	dw	0
D9C34:	db	0
T9C35:	ds	10
	;
D9C3F:	dw	0
D9C41:	db	0
	;
T9C42:	ds	10
	;
T9C4D:	ds	40
	;
T9C75:	dw	0
T9C77:	db	0
T9C78:	db	0
	;
T9C79:	ds	76
	;
D9CC5:	db	0
D9CC6:	db	0
D9CC7:	db	0
D9CC8:	dw	0
D9CCA:	dw	0
D9CCC:	db	0
D9CCD:	db	false			; false/true ?
D9CCE:	db	0
D9CCF:	dw	0
T9CD1:	db	0
T9CD2:	dw	0
	;
T9CD4:	ds	9
	;
D9CDD:	dw	0
D9CDF:	dw	0
D9CE1:	dw	0
D9CE3:	dw	0
D9CE5:	dw	0
D9CE7:	dw	0
D9CE9:	db	false			; "тихий" режим (опция "-q")
D9CEA:	db	false			; "не удалять файл т-кода"
D9CEB:	db	0			; заносится 6
D9CEC:	dw	0
D9CEE:	dw	0
D9CF0:	dw	0
D9CF2:	dw	0
D9CF4:	dw	0
D9CF6:	dw	0
D9CF8:	dw	0
D9CFA:	dw	0
D9CFC:	dw	0
D9CFE:	dw	0

table_end:
	dw	0			; конец таблицы идентиф.

D9D02:	dw	0



; ниже метки Table "io2.asm" не опускать



; Начало таблицы идентификаторов ( 5104 байт для cp/m)
Table:	;ds	30



;[]===================================================================[]
;
;   Начало программы
;
start:	ld	(L0080),hl		; сохр. адрес ком-строки
	ld	hl,Stack		; вершина стека
	ld	bc,-6
	add	hl,bc
	ld	sp,hl
	;
	call	save_path		; сохр. тек. путь
	ld	hl,(L0080)
	ld	e,(hl)
	inc	e
	ld	d,0
	add	hl,de
	ld	(hl),d			; нуль в конец ком-строки
	;
	ld	hl,T9D8F		; "cc2"
	ld	(DA26D),hl		; ds 20  под адреса начала аргументов ком.строки ?
	ld	bc,TA22D		; ds 64  для 1-й опции ком. строки
	ld	hl,1			; ?
	ld	de,(L0080)
	inc	de
A9E5A:	ld	a,(de)
	or	a
	jr	z,A9E98
	cp	" "
	jr	nz,A9E64
	inc	de
	jr	A9E5A
	;
A9E64:	inc	hl
	ld	(DA281),hl		; ds 61
	dec	hl
	add	hl,hl
	push	bc
	ld	bc,DA26D		; ds 20  под адреса начала аргументов ком.строки ?
	add	hl,bc
	pop	bc
	ld	(hl),c
	inc	hl
	ld	(hl),b
A9E78:	ld	a,(de)
	ld	(bc),a
	or	a
	jr	z,A9E89
	cp	" "
	jr	z,A9E89
	inc	de
	inc	bc
	jr	A9E78
	;
A9E89:	ld	a,(de)
	inc	de
	ld	hl,(DA281)		; ds 61
	or	a
	jr	z,A9E98
	xor	a
	ld	(bc),a
	inc	bc
	jr	A9E5A
	;
A9E98:	ld	de,DA26D		; ds 20  под адреса начала аргументов ком.строки ?
	call	AA05D
	jp	abort1			; выход в ДОС


T9D8F:	db	"CC2",0


; Проверка имени файла на расширение и его обработка.
; Отслеживается макс. длина абсол. имени файла
; вход: de-адрес ком.строки
;       hl-буфер имени
;       iy-адрес расш.
;
A9E9F:	push	hl
	ld	b,64-3			; макс. длина "\диск\каталог\имя" (без расш.)
A9EA0:	ld	a,(de)
	inc	de
	cp	"."
	jr	z,A9EB7
	ld	(hl),a
	or	a
	jr	z,A9EAD
	inc	hl
	djnz	A9EA0
	; скопир. расш. по-умолчанию
A9EAD:	ld	a,(iy+0)
	inc	iy
	ld	(hl),a
	inc	hl
	or	a
	jr	nz,A9EAD
A9EB5:	pop	hl
	ret
	; скопир. расш.
A9EB7:	ld	(hl),a
	or	a
	jr	z,A9EB5
	inc	hl
	ld	a,(de)
	inc	de
	jr	A9EB7


; a..z -> A..Z
toupper:
	cp	"a"
	ret	c
	cp	"z"+1
	ret	nc
	sub	20h
	ret


; записать строку "hl" в вых. asm-файл
fprint_outfile:
	ld	a,(hl)
	inc	hl
	or	a
	ret	z
	push	hl
	call	write_byte		; записать байт в вых. файл
	pop	hl
	jr	fprint_outfile


T9ED5:	db	"I",02h
	db	"N",02h
	db	"R",02h
	db	"B",01h
	db	"C",01h
	db	"Z",04h
	db	"W",04h
	db	"Q",04h
	db	"H",08h
	db	0


A9EE8:	ld	hl,(table_end)		; конец таблицы идентиф.
	ld	(D9CF4),hl
	ld	hl,Table		; начало таблицы идентиф.
	ld	(D9CF0),hl
	ld	hl,T9ED5
A9EF7:	ld	a,(hl)
	or	a
	ret	z
	inc	hl
	ld	c,(hl)
	inc	hl
	push	hl
	ld	e,0
	push	de
	ld	d,e
	ld	b,e
	call	A0685
	pop	bc
	pop	hl
	jr	A9EF7


outofmemory:
	db	"Not enough memoryA",0

bad_option:
	db	"bad option: CA",0


help:	db	"syntax: cc2 [options] <filename>",0Ah
	db	"options:",0Ah
	db	9,"-k         don't delete *.tmc file",0Ah
	db	9,"-o<name>   set explicit output name",0Ah
	db	9,"-r<number> set symbol table size",0Ah
	db	9,"-u<char>   set character to replace underscore",0Ah
	db	9,"-q         quiet mode, no progress indicatorA",0Ah,0


not_open:
	db	"can't open: SA",0

not_create:
	db	"can't create: SA",0


; расш. файлов по-умолчанию
tmc_ext:db	".TMC",0
asm_ext:db	".ASM",0




AA05D:	ld	(DA2BE),hl
	ld	(DA2C0),de		; адрес ком. строки
	ld	hl,D9CEB
	ld	a,6
	ld	(hl),a
	dec	hl
	ld	(hl),false		; D9CEA  флаг опции "K"
	dec	hl
	ld	(hl),true		; D9CE9  флаг "тихого" режима
	ld	de,1500			; чем меньше число, тем больше размер таблицы идентиф.
	ld	hl,Stack		; адрес стека
	or	a
	sbc	hl,de
	ex	de,hl
	ld	(DA2C7),hl		; hl=1500
	ld	hl,TA0EC
	push	de
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	ld	hl,outofmemory		; "Not enough memory"
	call	c,A75DA			; вывод строки "hl" (большие буквы зарез.)
	pop	hl
	ld	de,Table		; начало таблицы идентиф.
	sbc	hl,de
	ld	de,9
	call	div_hlde		; hl/de=hl
	add	hl,hl
	ld	(table_size),hl		; размер таблицы идентиф.
AA0B8:	ld	de,(DA2BE)
	dec	de
	ld	(DA2BE),de
	ld	hl,(DA2C0)		; адрес ком. строки
	inc	hl
	inc	hl
	ld	(DA2C0),hl
	ld	a,e
	or	d
	jp	z,AA165
	push	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	a,(bc)
	pop	hl
	cp	"-"			; префикс опций
	jr	nz,AA165
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	inc	bc
	ld	l,c
	ld	h,b
	ld	(DA2C3),hl
AA0E3:	ld	hl,(DA2C3)
	ld	a,(hl)
	or	a
	jr	z,AA0B8
	ld	a,(hl)
TA0EC:	inc	hl
	ld	(DA2C3),hl
	call	toupper
	; switch
	cp	"K"			; не удалять файл т-кода
	jr	z,AA10F
	cp	"Q"			; не выводить индикаторы процесса
	jr	z,AA117
	cp	"O"			; задать имя asm-файла
	jr	z,AA11E
	cp	"R"			; уст. размер таблицы идентиф.
	jr	z,AA132
	cp	"U"			; задать символ постфикса имен asm-листинга
	jr	z,AA13E
	; default
	jr	AA14C
	;
	; "K" не удалять файл т-кода
AA10F:	ld	a,true			; не удалять
	ld	(D9CEA),a		; флаг
	jr	AA0E3
	;
	; "Q" "тихий" режим, не выводить индикатор процесса (---++;)
AA117:	xor	a			; false
	ld	(D9CE9),a
	jr	AA0E3
	;
	; "O" задать имя asm-файла
AA11E:	ld	hl,(DA2C3)
	ld	de,asm_filename		; ds 65
AA124:	ld	a,(hl)
	ldi
	or	a
	jr	nz,AA124
	dec	hl
	ld	(DA2C3),hl
	jr	AA0E3
	;
	; "R" уст. размер таблицы идентиф.
AA132:	ld	hl,DA2C3
	call	A7761
	ld	(table_size),hl		; уст. размер
	jr	AA0E3
	;
	; "U" задать символ постфикса имен asm-листинга
	;  (по-умолчанию "_")
AA13E:	ld	hl,(DA2C3)
	ld	a,(hl)			; взять символ
	ld	(D9BE6),a		; символ постфикса имен asm-листинга
	inc	hl
	ld	(DA2C3),hl
	jr	AA0E3
	;
	; default
AA14C:	ld	hl,(DA2C3)
	dec	hl
	ld	(DA2C3),hl
	ld	a,(hl)
	ld	c,a
	push	bc
	ld	bc,bad_option		; "bad option"
	push	bc
	ld	hl,2
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	pop	bc
	pop	bc
	jr	AA0E3
	;
AA165:	ld	hl,(table_size)		; размер таблицы идентиф.
	ld	bc,Table		; начало таблицы идентиф.
	add	hl,bc
	ld	(table_end),hl		; конец таблицы идентиф.
	ld	hl,Stack
	push	de
	ld	de,(DA2C7)
	sbc	hl,de
	ld	(D9D02),hl
	pop	de
	ld	a,e
	dec	a
	or	d
	ld	hl,help
	call	nz,A75DA		; вывод строки "hl" (большие буквы зарез.)
	; уст. имя tmc-файла
	ld	hl,(DA2C0)		; адрес ком. строки
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	iy,tmc_ext		; ".tmc" по-умолчанию
	ld	hl,tmc_filename		; ds 65 имя tmc-файла
	call	A9E9F			; добавить расш., если не задано
	call	open_file		; открыть .tmc файл
	jr	z,AA1B4			; без ошибок
	; ошибка открытия
	ld	bc,tmc_filename		; имя tmc-файла
	push	bc
	ld	bc,not_open		; "can't open: SA"
	push	bc
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	pop	bc
	pop	bc
	jr	AA1B7
	;
	; вывод имени вход. файла (конв. в большие буквы)
AA1B4:	ld	hl,tmc_filename		; имя tmc-файла
	push	hl
.loc1:	ld	a,(hl)
	or	a
	jr	z,.loc3
	cp	"A"
	jr	nc,.loc2
	inc	hl
	jr	.loc1
.loc2:	and	5Fh
	ld	(hl),a
	inc	hl
	jr	.loc1
.loc3:	pop	hl
	call	A011E			; вывод строки
	ld	a,":"
	call	A0109
	ld	hl,newline1
	call	A011E
	; уст. имя asm-файла
AA1B7:	ld	de,tmc_filename		; имя tmc-файла
	ld	bc,asm_ext		; ".asm" по-умолчанию
	ld	hl,asm_filename		; ds 65  имя ASM-файла
	ld	a,(hl)
	or	a
	jr	nz,AA1D4		; имя уже задано (по опции "o")
	; исправление фирм. ошибки
	push	hl
LA1B9:	ld	a,(de)
	inc	de
	cp	"."
	jr	z,LA1BE
	ld	(hl),a
	inc	hl
	or	a
	jr	nz,LA1B9
	dec	hl
	; скопир. расш. по-умолчанию
LA1BE:	ld	a,(bc)
	inc	bc
	ld	(hl),a
	inc	hl
	or	a
	jr	nz,LA1BE
	pop	hl
	;
AA1D4:	call	create_file		; создать .asm файл
	jr	z,AA1DA			; без ошибок
	; ошибка создания
	ld	bc,asm_filename		; ds 65  для файла *.asm
	push	bc
	ld	bc,not_create		; "can't create: SA"
	push	bc
	call	A74A0			; вывод строки на экран (больш.буквы зарез.)
	pop	bc
	pop	bc
	; вставка текста в начало asm-листинга
AA1DA:	ld	hl,_z80			; ".z80"
	call	fprint_outfile
%if DEBUG
	ld	hl,Title
%else
	call	ins_date
	ld	hl,Asm_Title
%endif
	call	fprint_outfile		; записать строку в asm-файл
	call	A9EE8
	jp	A12BC


; записать в Title текущую дату и время
ins_date:
	ld	c,21h			; получить тек. дату и время
	call	int10
	; записать дату
	push	hl			; сохр. время
	ld	h,0
	ld	l,d			; день
	ld	iy,ascdate
	call	_date
	inc	iy
	ld	l,e			; месяц
	call	_date
	inc	iy
	push	ix
	pop	hl			; год
	call	_date
	pop	de			; вернуть время
	; записать время
	ld	h,0
	ld	l,d			; часы
	ld	iy,asctime
	call	_date
	inc	iy
	ld	l,e			; минуты
	call	_date
	ld	l,b			; секунды
	inc	iy
_date:	push	hl
	push	de
	push	bc
	call	_date1
	pop	bc
	pop	de
	pop	hl
	ret
	;
_date1:	ld	a,h
	or	a
	jr	nz,_date2
	ld	a,l
	cp	9+1
	ld	a,"0"
	call	c,_date5		; вед. ноль в числах 0..9 (1-но разр.)
_date2:	ld	bc,-10
_date3:	ld	d,b
	ld	e,b
_date4:	add	hl,bc
	inc	de
	jr	c,_date4
	push	hl			; накопить числа в стеке
	ex	de,hl
	ld	a,h
	or	l
	call	nz,_date3
	ld	a,"9"+1
	pop	bc			; взять числа из стека
	add	a,c
_date5:	ld	(iy+0),a
	inc	iy
	ret				; цикл 'pop bc' и выход




_z80:	db	9,".z80",0Dh,0Ah
	db	";",0

Title:	db	9,"SOLID C Compiler ver 1.00 (pass 2)",0Dh,0Ah,0

Asm_Title:
	db	" SOLID C Compiler Version 0.01b    Date: "
ascdate:db	"  /  /    "
	db	"  Time: "
asctime:db	"  :  :  "
	db	0Dh,0Ah
	db	";"
newline1:db	0Dh,0Ah,0Dh,0Ah,0



TA22D:	ds	64			; для 1-й опции ком. строки

DA26D:	ds	20			; под адреса начала аргументов ком.строки ?

DA281:	ds	61

DA2BE:	dw	0
DA2C0:	dw	0			; адрес ком. строки
	db	0
DA2C3:	dw	0

table_size:
	dw	0			; 13F0h   размер таблицы идентиф.

DA2C7:	dw	0

f_path:
