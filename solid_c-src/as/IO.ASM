; Ассемблер AS.EXE
;
;  ДОС функции
;






; вывести "a" на экран
A41A3:	push	hl
	push	de
	push	bc
	push	af
	ld	c,5Bh
	call	int10
	pop	af
	pop	bc
	pop	de
	pop	hl
	or	a
	ret


; вывод строки на экран
A40AE:	ld	a,(hl)
	or	a
	ret	z
	call	A41A3			; вывод "a" на экран
	inc	hl
	jp	A40AE


; на новую строку
newline:ld	a,0Dh
	call	A41A3			; вывод "a" на экран
	ld	a,0Ah
	jp	A41A3




; найти файл
; вх: hl=имя файла (диск+путь)
found_first:
	push	hl
	ld	de,f_path		; буфер 65 байт
	ld	bc,0119h
	ld	a,20h			; "архивный"
	call	int10
	pop	hl
	ret


; создать .rel файл
create_file:
	push	af
	push	bc
	push	de
	push	hl
	ld	hl,0			; сбр. число байт (тек.полож. в буфере)
	ld	(rel_ptr),hl
	ld	hl,T3A2F		; имя .rel файла
	;call	PR;
	ld	c,0Ah			; создать файл
	ld	a,20h			; атрибут "архивный"
	call	int10
	jp	c,A40C4			; ошибка создания
	ld	(handle_rel),a
	;call	HEXA;
	; сохр. расположение .rel файла
	ld	c,2			; узнать тек. диск
	call	int10
	ld	(disk1),a
	ld	hl,dir1
	ld	c,1Eh			; узнать тек. каталог
	call	int10
	;ld	hl,0
	;ld	(D3A50),hl
	;ld	(D3A52),hl
	;inc	l
	;ld	(D3A3D),hl
done:	pop	hl
	pop	de
	pop	bc
	pop	af
	ret


; открыть .asm файл
open_file:
	push	af
	push	bc
	push	de
	push	hl
	ld	hl,1024			; число чит. байт
	ld	(asm_ptr),hl
	ld	hl,T3A54		; имя .asm файла
	call	found_first
	;call	PR;
	ld	a,1			; на чтение
	ld	c,11h			; открыть файл
	call	int10
	jp	c,A40BE			; ошибка открытия
	ld	(handle_asm),a
	;call	HEXA;
	;ld	hl,0
	;ld	(D3A75),hl
	;ld	(D3A77),hl
	;inc	l
	;ld	(D3A62),hl
	jp	done


; закрыть .asm файл
close_file:
	push	af
	push	bc
	push	de
	push	hl
	ld	a,(handle_asm)
	;call	HEXB;
	ld	c,12h
	call	int10
	jp	done


; дописать конец .REL файла и закрыть
A421D:	push	af
	push	bc
	push	de
	push	hl
	ld	a,0FFh			; последний байт .rel файла
	call	A4263			; записать готовый байт в "outrel"
	ld	hl,outrel		; 512, буфер .asm файла
	ld	de,(rel_ptr)		; число запис. байт
	ld	a,d
	or	e
	jr	z,A4225			; записывать нечего
	ld	a,(handle_rel)
	ld	c,14h			; запись файла
	call	int10
A4225:	; уст. путь .rel файла
	ld	a,(disk1)
	ld	c,1			; уст. диск
	call	int10
	ld	hl,dir1
	ld	c,1Dh			; уст. каталог
	call	int10
	ld	a,(handle_rel)
	ld	c,12h
	;call	HEXB;
	call	int10
	jp	done


; записать блок 512 байт .rel файла
A4246:	push	bc
	ld	hl,outrel		; 512, буфер .asm файла
	ld	de,512			; число запис. байт
	ld	a,(handle_rel)
	ld	c,14h			; запись файла
	call	int10
	pop	bc
	ld	hl,0
	ret	nc
	; ошибка записи
	ld	hl,disk_full
	cp	0Ah			; код ошибки "disk full"
	jr	z,_full
	ld	hl,write_error
_full:	call	A40AE			; вывод строки на экран
	jp	abort			; выход в ДОС



; прочитать блок asm-файла
A4296:	ld	hl,D3C8D		; 1024 буфер асм-файла
	ld	de,1024			; число чит. байт
	push	bc			; сохр. "b"
	push	hl
	ld	a,(handle_asm)		; дескриптор .asm файла
	ld	c,13h			; чтение файла
	call	int10
	pop	hl
	add	hl,de
	ld	(hl),1Ah		; концовка блока данных
	pop	bc
	ld	hl,0
	ret
	;ld	de,D3C8D		; 1024 буфер асм-файла
	;push	de
	;ld	c,1Ah			; уст. DMA
	;call	L0005
	;ld	de,T3A54		; FCB asm-файла
	;ld	hl,1024			; число чит. байт
	;ld	c,27h			; чтение блока
	;call	L0005
	;pop	de
	;add	hl,de
	;ld	(hl),1Ah		; концовка файла
	;ld	hl,0
	;ret





; открыть include-файл
open_include:
	push	hl
	push	de
	push	bc
	ld	de,T42EC		; FCB  куда
	ld	iy,T43F9		; ".asm" расш. по-умолчанию
	call	A9E9F			; добавить расш., если не задано
	ld	hl,T42EC		; имя файла
	call	found_first
	;call	PR;
	ld	c,11h			; открыть файл
	ld	a,1			; на чтение
	call	int10
	ld	b,a
	ld	a,-1
	jr	c,A437B			; ошибка открытия
	ld	a,b
	ld	(handle_incl),a		; сохр. дескриптор
	;call	HEXA;
	; сохр. расположение include-файла
	ld	c,2			; узнать тек. диск
	call	int10
	ld	(disk2),a
	ld	hl,dir2
	ld	c,1Eh			; узнать тек. каталог
	call	int10
	xor	a
	ld	(D4311),a
	;ld	l,a
	;ld	h,a
	;ld	(D430D),hl
	;ld	(D430F),hl
	;inc	l
	;ld	(D42FA),hl
A437B:	pop	bc
	pop	de
	pop	hl
	ret


; чтение include-файла
read_include:
	push	hl
	push	de
	push	bc
	ld	a,(D4311)		; 00,FF,FE,...80h
	dec	a
	jp	p,A43E2			; прочитано не 128 байт
	;
	ld	hl,T4314		; буфер 65 байт
	push	hl
	ld	de,64			; число чит. байт
	ld	a,(handle_incl)		; дескриптор include-файла
	ld	c,13h			; чтение файла
	call	int10
	pop	hl
	ld	a,e
	;ld	de,T4314		; DMA, 65 байт
	;push	de
	;ld	c,1Ah			; уст. DMA
	;call	L0005
	;ld	de,T42EC		; FCB
	;ld	hl,64			; число чит. байт
	;ld	c,27h
	;call	L0005
	;pop	de
	;ld	a,l
	add	hl,de
	ld	(hl),1Ah		; концовка asm-строки (порции данных)
	ld	hl,T4314
	ld	(D4312),hl
	dec	a
A43E2:	ld	(D4311),a
	ld	hl,(D4312)
	ld	a,(hl)
	cp	1Ah			; код конца файла
	jr	nz,A43F0
	; уст. путь include-файла
	ld	a,(disk2)
	ld	c,1			; уст. диск
	call	int10
	ld	hl,dir2
	ld	c,1Dh			; уст. каталог
	call	int10
	; закрыть файл
	ld	a,(handle_incl)
	ld	c,12h
	;call	HEXB;
	call	int10
	scf
	jr	A43F5
	;
A43F0:	inc	hl
	ld	(D4312),hl
	or	a
A43F5:	pop	bc
	pop	de
	pop	hl
	ret



; Сохранить тек. путь
save_path:
	ld	c,2			; узнать тек. диск
	call	int10
	ld	(disk),a
	ld	hl,dir
	ld	c,1Eh			; узнать тек. каталог
	jp	int10



; сохр. тек. диск и путь ассемблера
disk:	db	0
dir:	ds	65

; сохр. расположение .rel файла
disk1:	db	0
dir1:	ds	65

; сохр. расположение include-файла(ов)
disk2:	db	0
dir2:	ds	65

; буфер "found_first"
f_path:	ds	65





T04A4:	db	"000000",0


msg_name:db	0Dh,0Ah,"Assembling file:  ",0
msg_err: db	"Error messages:   ",0
msg_warn:db	"Warning messages: ",0
msg_none:db	"None",0Dh,0Ah,0

T01B5:	db	0Dh,0Ah,"-- PASS 1 --",0Dh,0Ah,0
T01C3:	db	0Dh,0Ah,"-- PASS 2 --",0Dh,0Ah,0

T0467:	db	0Dh,0Ah,"line ",0
T055A:	db	"Argument out of range",0
T0570:	db	"Bad conditional",0
T0580:	db	"Duplicate definition",0
T0595:	db	"Invalid use of external",0
T05AD:	db	"Error in number",0
T05BD:	db	"Syntax error",0
T05CA:	db	"Pass 1/2 phase error",0
T05DF:	db	"Error in relocatable value",0
T05FA:	db	"Error in value",0
T0609:	db	"Warning: maybe mistake!",0
T0621:	db	"Undefined symbol",0
T0632:	db	"Multiple symbol definition",0
T064D:	db	"Mistake!",0
T0656:	db	"Divide by zero",0
T2D5A:	db	"Stack overflow, aborting.",0Dh,0Ah,0

T294E:	db	"macro constuction",0
T2960:	db	"Unterminated ",0
T2980:	db	"conditional",0

T408E:	db	"File not found",0
T409D:	db	"Can't create file",0

disk_full:
	db	0Dh,0Ah,"Disk full !",0Dh,0Ah,0
write_error:
	db	0Dh,0Ah,"Write error !",0Dh,0Ah,0

T0D0B:	db	"Symbol table full",0Dh
T0D1D:	db	0Ah,0




	ds	80
stack1:	db	0			; адрес стека при вызове DSS



abort:	ld	b,-1			; код возврата
; Выход в ДОС
exit:	ld	sp,0BFFFh
	push	bc
	; освоб. выделенный блок памяти
	ld	a,(block)
	ld	c,3Eh
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
	;
	ld	a,(portA2)
	out	(PAGE_1),a
	ld	a,(portE2)
	out	(PAGE_3),a
	ld	a,(port89)
	out	(89h),a
	;
	pop	bc
	ld	c,41h
	rst	10h
	ret



; порядок ячеек не менять
block:	db	-1			; дескриптор выдел. блока памяти
	;
page0:	db	-1			; 0 стр.
page1:	db	-1			; 1 стр.
	db	-1
	;
port89:	db	-1
portA2:	db	-1
portE2:	db	-1


L0080:	dw	0			; адрес ком-строки




; вызов функций DSS
int10:	ld	(_stack+1),sp
	ld	sp,stack1
	rst	10h
	ex	af,af'
	ld	a,0C0h
	out	(89h),a			; закрыть порт 89h
	ex	af,af'
_stack:	ld	sp,0
	ret






%if .comment
PR:	push	af
	push	bc
	push	de
	push	hl
	push	ix
	push	iy
	call	A40AE
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
	push	af
	call	HEX1
	;call	NewLine
	pop	af
	pop	iy
	pop	ix
	pop	bc
	pop	de
	pop	hl
	ret

HEXB:	push	hl
	push	de
	push	bc
	push	ix
	push	iy
	push	af
	call	HEX1
	ld	a,"-"
	call	SYMB
	call	NewLine
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
