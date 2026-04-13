; Последняя редакция  19.11.2007
;





;
; Примечания к программе:
; ~~~~~~~~~~~~~~~~~~~~~~~
;
;  ■ Тип открываемого входного файла отслеживается не по его расширению,
;    а по внутреннему содержимому.
;
;  ■ При создании библы, если имя библиотеки совпадает с именем входного
;    файла - необходимо указать расширение библиотеки, чтобы не было
;    двойного добавления файлов. В именах rel-файлов расширение можно не
;    указывать. Имена добавляемых файлов разделяются пробелами или запятыми.
;
;  ■ Глобальные символы "*" и "?" поддерживаются только для режима
;    извлечения модулей (опция "e"). В остальных режимах необходимо
;    указывать реальное имя файла.
;
;  ■ Задание пути поддерживается только для файла библиотеки. Для rel-
;    файлов указание пути не поддерживается и используется путь расположения
;    библиотеки. Если библиотека расположена не в тек. пути программы, при
;    выходе из программы восст. путь расположения библиотекаря.
;
;  ■ В опции l(ist) (список модулей библы), размеры "Code size:"
;    и "Data size:" выводятся в десят. формате.
;
;  ■ В опциях d(ump) и l(ist) вывод на экран можно остановить/продолжить
;    при нажатии на любую клавишу. При нажатии на Esc - выход из режима.
;
;  ■ Для опции l(ist) добавил отслеживание "request" элемента.
;
;
;
;
;  √ В опции "d", для вывода "Reserved item: " вместо вывода строки,
;    поставил вывод "." для кодов < 20h.
;  √ Буферы чтения/записи увеличены с 512 до 1024 байт.
;
;
;







true		equ	1
false		equ	0

; порт страницы
PAGE_3		equ	0E2h



		org	7F00h


		db	"EXE"			; exe ID
		db	0			; exe версия
		dw	512			; 512, мл. смещ. кода
		dw	0			; ст. смещ. кода
		dw	0			; end-beg, первичный загрузчик
		dw	0,0,0			; резерв
		dw	entry			; адрес загрузки кода
		dw	entry			; адрес передачи управления
		dw	0C000h			; адрес стека
		ds	490



entry:		ld	(L0080),ix		; сохр. адрес ком-строки
		; сохр. значения портов
		in	a,(PAGE_3)
		ld	(portE2),a
		; выделить 1 стр. памяти
		ld	bc,013Dh
		rst	10h
		ld	(block),a		; хэндл выдел. блока памяти
		; подкл. страницу
		out	(PAGE_3),a
		jp	start



; Получить байт из данных библы
A016B:		push	hl
		push	bc
		ld	a,(D1201+1)
		bit	2,a			; 1024 ?
		call	nz,read_file		; да, прочитать 1024 байт
		ld	hl,A0DFF		; 1024 буфер
		ld	de,(D1201)		; тек. полож. в буфере
		add	hl,de
		ld	a,(hl)
		inc	de
		ld	(D1201),de		; ++тек. полож. в буфере
		ld	(D0D1E),a		; сохр. полученный байт
		ld	hl,(D128F)
		inc	hl			; ++размер rel-имиджа
		ld	(D128F),hl
		pop	bc
		pop	hl
		ret



; Сохранить байт в буфере вых. файла
write_file:	push	af
		ld	a,(D1203+1)
		bit	2,a			; 1024 ?
		call	nz,A01EB		; да, записать блок файла
		ld	hl,A1000		; 1024 буфер
		ld	de,(D1203)		; тек. полож. в буфере
		pop	af
		add	hl,de
		ld	(hl),a			; сохр. байт в буфере
		inc	de			; ++тек. полож. в буфере
		ld	(D1203),de
		ret



;=====================================================================
;  Открыть входной файл и в зависимости от его типа установить
;  указатель на rel-имидж. Тип файла отслеживается не по его
;  расширению, а по внутреннему содержимому.
;=====================================================================
; out: "Z"  - Ok
;      "NZ" - ошибка
A03FB:		call	A044B
		ld	a,b
		or	c
		jr	nz,A041E		; расш. задано
		dec	de
		push	de
		ld	hl,_irl			; ".IRL",0
		ld	bc,5
		ldir
		ld	hl,T1209		; ds 65
		call	open_file		; открыть файл
		pop	de
		or	a
		jr	z,A0429			; Ok
		ld	hl,_rel			; ".REL",0
		ld	bc,5
		ldir
A041E:		ld	hl,T1209		; ds 65
		call	open_file		; открыть файл
		or	a
		ret	nz			; ошибка открытия
A0429:		call	A016B			;+0 смещ.  получить 1-й байт из файла
		ld	hl,0			; нулевое полож. для rel-файла
		rla
		jr	c,A043C			; rel-файл (не индексированный)
		; индексированный файл, уст.
		; указатель на rel-имидж
		call	A016B			;+1 смещ.  получить 2-й байт из файла
		ld	h,a
		ld	l,0
		srl	h			; hl / 2
		rr	l
A043C:		ld	(fpoint+1),hl		; мл.разряд
		call	move_pointer		; уст. указатель в файле
		xor	a			; Ok
		ret


A0444:		call	A03FB			; открыть файл и встать на rel-имидж
		jp	nz,A0C7E		; вывод "File not found" и abort
		ret


A044B:		ld	de,T1209		; ds 65
		ld	bc,0
A0451:		ld	a,(hl)
		cp	"a"
		jr	c,A0453
		and	5Fh			; a..z -> A..Z
A0453:		ld	(de),a
		inc	hl
		inc	de
		or	a
		ret	z
		cp	"."
		jr	nz,A0451
		ld	b,d
		ld	c,e
		dec	bc
		jr	A0451




;=====================================================================
;  Проверка на неопределенные внешние метки (опция "t")
;=====================================================================
test_extrn_missing:
		ld	hl,(D0D4F)
		call	A0444
		ld	hl,L1296		; буфер
		ld	(D0D21),hl		; начало rel-имиджа
A0476:		call	A0D02			; раскрутка rel-битов
		jr	c,A0476			; байт данных
		jr	z,A0476			; слово данных
		ld	a,c			; тип спец-поля
		cp	6			; элемент "внешняя метка"
		jr	z,A0476
		cp	7			; элемент "адрес метки"
		jr	z,A0476
		cp	15			; элемент "конец файла"
		jr	nz,A0476
		ld	a,(D0D23)		; флаг наличия "Externals missing"
		or	a
		ld	hl,T04A3		; "Externals missing:"
		call	nz,A02FB		; вывод строки
		call	close_file		; закрыть входной файл
		jp	exit			; выход в ДОС





;=====================================================================
;  Добавить модуль в библиотеку
;=====================================================================
add_module:	ld	hl,(D0D51)
		ld	a,h
		or	l
		jp	z,usage
		ld	hl,tmp_name1		; "OLTMP1.$$$", имя библы до ре-индексации
		call	create_file		; создать файл
		ld	hl,(D0D4F)
		call	A03FB			; открыть файл и встать на rel-имидж
		ld	de,D0D51
		ld	hl,T0552		; "Creating new library: "
		jr	nz,A04DD		; ошибка открытия
		call	close_file		; закрыть файл
		ld	de,D0D4F
		ld	hl,T0569		; "Updating library: "
A04DD:		push	de
		call	A02FB			; вывод строки
		ld	hl,(D0D4F)		; имя библы
		call	A02FB			; вывод строки
		;call	A02ED			; новая строка (и обнул. ячейку D0D20)
		call	nline
		ld	hl,0F800h		; константа
		ld	(D0D24),hl		; сбр. ячейки
A04F0:		pop	de
		ld	a,(de)
		inc	de
		ld	l,a
		ld	a,(de)
		inc	de
		ld	h,a
		ld	a,h
		or	l
		jr	z,A0517			; имен добавл. файлов больше нет
		push	de
		call	A0444
		ld	hl,T057C		; "Adding: "
		call	A02FB			; вывод строки
		ld	hl,T1209		; ds 65  имя библы
		call	A02FB			; вывод строки
		;call	A02ED			; новая строка (и обнул. ячейку D0D20)
		call	nline
		call	A06A6			; запись всего rel-имиджа
		call	close_file		; закрыть файл
		jp	A04F0
		;
A0517:		ld	c,15			; элемент "конец файла"
		call	put_item		; записать элемент в вых. буфер
		call	put_item
		call	A0236			; дописать и закрыть файл библы
		ld	hl,(D0D4F)
		call	A044B
		ld	a,b
		or	c
		jr	nz,A0535
		dec	de
		ld	hl,_irl			; ".IRL",0
		ld	bc,5
		ldir
A0535:		ld	hl,T1209		; ds 65
		call	del_file		; удалить файл
		ld	hl,tmp_name1		; "OLTMP1.$$$", имя библы до ре-индексации
		ld	de,T1209		; ds 65 новое имя
		call	rename_file		; переименовать файл
		jp	reindexing		; переиндексация библы




;=====================================================================
;  Переиндексация библиотеки или индексация rel-файла
;=====================================================================
reindexing:	ld	hl,(D0D4F)
		call	A0444
		ld	hl,T068B		; "Reindexing..."
		call	A02FB			; вывод строки
		; подготовить IRL-заголовок
		ld	hl,L1296		; начало заголовка
		ld	d,h
		ld	e,l
		inc	de
		ld	bc,128			; размер заголовка
		ld	(hl),0
		ldir
		ld	(D0D21),hl		; L1296+128 начало тек.записи в симв.таблице
		xor	a
		ld	h,a
		ld	l,a
		ld	(D128F),hl		; размер rel-имиджа
		ld	(D1291),a		; смещ. от начала rel-имиджа
		ld	(D1292),a		; до rel-модуля, содержащего
		ld	(D1293),a		; имя метки.
		; заполнить записями буфер
		; символьной таблицы
A05B0:		call	A0D02			; раскрутка rel-битов
		jr	c,A05B0			; байт данных
		jr	z,A05B0			; слово данных
		ld	a,c			; тип спец-поля
		or	a			; элемент "имя метки" (уже в буфере)
		jp	z,A063D
		cp	14			; элемент "конец прогр. модуля"
		jp	z,A0665
		cp	15			; элемент "конец файла"
		jr	nz,A05B0
		ld	hl,tmp_name2		; "OLTMP2.$$$", имя библы при ре-индексации
		call	create_file		; создать файл
		; заключительная запись в симв. таблице
		ld	hl,(D0D21)		; адрес начала тек.записи в симв.таблице
		ld	(hl),0
		inc	hl
		ld	(hl),0
		inc	hl
		ld	(hl),0
		inc	hl
		ld	(hl),0FFh
		inc	hl
		; выровнить таблицу до границы 128 байт
		ld	de,L1296		; начало IRL-заголовка
A05DD:		ld	a,l
		sub	e
A05DF:		and	7Fh
		jr	z,A05E8			; дошли до границы
		ld	(hl),0			; байт заполнения
		inc	hl
		jr	A05DD
		;
		; вычислить смещ. до rel-имиджа,
		; т.е. размер заголовка + симв.таблица
A05E8:		or	a
		sbc	hl,de			; конец таблицы - начало irl-заголовка
		add	hl,hl			; размер таблицы+заголовок * 2
		ld	a,h
		ld	(start),a		;+1  байт смещ. до rel-имиджа
		ld	l,0
		srl	h			; hl / 2 = размер запис. блока
		rr	l
		; записать irl-заголовок
		; и всю симв. таблицу
		ld	de,L1296		; начало IRL-заголовка
A05F9:		ld	a,(de)			; взять байт из буфера
		inc	de
		push	hl
		push	de
		call	write_file		; байт в вых. буфер (с записью файла)
		pop	de
		pop	hl
		dec	hl
		ld	a,h
		or	l
		jr	nz,A05F9
		; записать REL-имидж
fpoint:		ld	hl,0			; сохр. мл.разряд
		call	move_pointer		; уст. указатель в файле
		ld	hl,0F800h		; константа
		ld	(D0D24),hl		; сбр. ячейки
		call	A06A6			; запись всего rel-имиджа
		ld	c,15			; элемент "конец файла"
		call	put_item		; записать элемент в вых. буфер
		call	put_item
		call	A0236			; дописать и закрыть файл библы
		ld	hl,T069B		; " complete"
		call	A02FB			; вывод строки
		call	close_file		; закрыть файл
		ld	hl,T1209		; ds 65
		call	del_file		; удалить файл
		ld	hl,tmp_name2		; "OLTMP2.$$$", имя библы при ре-индексации
		ld	de,T1209		; ds 65  новое имя
		call	rename_file		; переименовать файл
		jp	exit			; выход в ДОС
		;
; Скопировать из буфера "field_B" в буфер
; символьной таблицы имя идентификатора
A063D:		ld	hl,(D0D21)		; адрес начала тек.записи в симв.таблице
		ld	a,(D1291)		; ст. байт смещ. от начала
		ld	(hl),a			; rel-имиджа до rel-модуля
		inc	hl
		ld	a,(D1292)		; средн. байт
		ld	(hl),a
		inc	hl
		ld	a,(D1293)		; мл. байт
		ld	(hl),a
		inc	hl
		ld	de,field_B		; буфер B-поля (имя идентиф.), 33 байта
		ld	a,(de)			; длина имени
		ld	b,a
		inc	de
		; скопировать тек. имя в симв. таблицу
A0656:		ld	a,(de)			; имя идентиф.
		inc	de
		ld	(hl),a
		inc	hl
		djnz	A0656
		ld	(hl),0FEh		; концовка имени
		inc	hl
		ld	(D0D21),hl		; начало новой записи в симв. таблице
		jp	A05B0
		;
; элемент "конец прогр. модуля"
A0665:		ld	hl,(D128F)		; размер rel-имиджа
		; вычислить смещ. от начала
		; rel-имиджа до rel-модуля
		xor	a
		add	hl,hl
		rla
		rl	h
		rla
		srl	h
		srl	l
		ld	(D1291),a		; ст. байт смещения
		ld	a,h
		ld	(D1292),a		; средн. байт
		ld	a,l
		ld	(D1293),a		; мл. байт
		jp	A05B0


;=====================================================================
;  Запись всего rel-имиджа
;=====================================================================
A06A6:		call	A0D02			; раскрутка rel-битов
		jr	c,A06B7			; байт данных
		jr	z,A06BD			; слово данных
		ld	a,c			; тип спец-поля
		cp	15			; элемент "конец файла"
		ret	z
		call	put_item		; записать элемент в вых. буфер
		jr	A06A6
		;
A06B7:		call	A09BE			; записать байт в rel-поток
		jr	A06A6
		;
A06BD:		call	A09B3			; записать слово в rel-поток
		jr	A06A6




;=====================================================================
;  Извлечь модуль из библиотеки
;=====================================================================
extracting_module:
		ld	hl,(D0D51)
		ld	a,h
		or	l
		jr	nz,A06D6
		ld	hl,0
		ld	(T0D53),hl		; ds 60 буфер списка имен извлек. модулей
		ld	hl,T07BC		; "*"  метасимвол
		ld	(D0D51),hl
A06D6:		ld	hl,(D0D4F)
		call	A0444
A06DC:		call	A0D02			; раскрутка rel-битов
		jr	c,A06DC			; байт данных
		jr	z,A06DC			; слово данных
		ld	a,c			; тип спец-поля
		cp	15			; элемент "конец файла"
		jp	z,A0815			; "End of library" и закрыть файл
		cp	2			; элемент "имя модуля"
		jr	nz,A06DC
		call	compare			; сравнение имен модулей (заданного и текущего) ?
		jr	nz,A0713		; true, нашли
		ld	hl,T0797		; "Module Skipped: "
		call	A02FB			; вывод строки
		ld	hl,field_B		; буфер B-поля (имя идентиф.), 33 байта
		ld	b,(hl)			; длина имени
		inc	hl			; имя
		call	A0305			; вывод строки на экран, "b" счетчик
		;call	A02ED			; новая строка (и обнул. ячейку D0D20)
		call	nline
A0705:		call	A0D02			; раскрутка rel-битов
		jr	c,A0705			; байт данных
		jr	z,A0705			; слово данных
		ld	a,c			; тип спец-поля
		cp	14			; элемент "конец модуля (программы)"
		jr	nz,A0705
		jr	A06DC			; на след. модуль
		;
		; нашли модуль, создать из него rel-файл
A0713:		ld	hl,T07A8		; "Extracting module: "
		call	A02FB			; вывод строки
		ld	hl,field_B		; буфер B-поля (имя идентиф.), 33 байта
		ld	b,(hl)			; длина имени
		inc	hl			; имя
		call	A0305			; вывод имени модуля на экран, "b" счетчик
		;call	A02ED			; новая строка (и обнул. ячейку D0D20)
		call	nline
		; имя модуля для имени файла
		ld	hl,field_B		; буфер B-поля (имя идентиф.), 33 байта
		ld	c,(hl)			; длина имени
		ld	b,0
		inc	hl			; имя
		ld	de,T124A		; ds 65
		ldir
		ld	hl,_rel			; ".REL",0
		ld	c,5
		ldir
		ld	hl,T124A		; ds 65  имя файла извлеч. модуля
		call	create_file		; создать файл модуля
		ld	hl,0F800h		; константа
		ld	(D0D24),hl		; сбр. счетчик границы байта
		ld	a,(extnd_rel)		; флаг "расш. rel-формат"
		push	af
		; записать номер элемента "имя модуля"
		xor	a			; false
		ld	(extnd_rel),a		; сбр. флаг "расш. rel-формат"
		ld	c,2			; элемент
		call	put_item		; записать элемент в вых. буфер
		pop	af
		or	a
		jr	z,A076C			; обычный rel-формат
		; записать элемент расширения (C-поле)
		ld	a,1
		ld	(field_B),a		; длина имени
		ld	a,0FEh			; тип элемента расширения (у асма SOLID)
		ld	(field_B+1),a		; строка имени
		ld	c,4			; элемент "расш. формат"
		call	put_item		; записать элемент в вых. буфер
		ld	a,true
		ld	(extnd_rel),a		; флаг "расш. rel-формат"
A076C:		call	A0D02			; раскрутка rel-битов
		jr	c,A078B			; байт данных
		jr	z,A0791			; слово данных
		ld	a,c			; тип спец-поля
		push	af
		call	put_item		; записать элемент в вых. буфер
		pop	af
		cp	14			; элемент "конец модуля (программы)"
		jr	nz,A076C
		ld	c,15			; элемент "конец файла"
		call	put_item		; записать элемент в вых. буфер
		call	put_item
		call	A0236			; дописать и закрыть файл библы
		jp	A06DC
		;
A078B:		call	A09BE			; записать байт
		jr	A076C
		;
A0791:		call	A09B3			; записать слово
		jr	A076C


; сравнение имен модулей (заданного и текущего)
compare:	ld	ix,D0D51
A07C2:		ld	l,(ix+0)		; продвижение
		inc	ix			; по списку,
		ld	h,(ix+0)		; на начало
		inc	ix			; тек. слов
		ld	a,h
		or	l
		ret	z			; конец списка заданных имен
		ld	de,field_B		; буфер B-поля (имя идентиф.), 33 байта
		ld	a,(de)			; длина имени
		ld	b,a
		inc	de			; тек. имя модуля в библе
A07D6:		ld	a,(hl)
		cp	"*"			; мета-символ
		jr	z,A07E9
		cp	"?"			; мета-символ
		jr	z,A07E5
		ld	a,(de)
		xor	(hl)
		and	5Fh
		jr	nz,A07C2
A07E5:		inc	hl
		inc	de
		djnz	A07D6
A07E9:		or	1
		ret



;=====================================================================
;  Вывести дамп библиотеки
;=====================================================================
dump_library:	ld	hl,(D0D4F)
		call	A0444
A07F2:		;call	A02ED			; новая строка (и обнул. ячейку D0D20)
		call	nline
		call	pause
		jr	c,A081B			; отмена режима
		call	A0D02			; раскрутка rel-битов
		jr	c,A0821			; байт данных
		jr	z,A082D			; слово данных
		ld	a,c			; тип спец-поля
		cp	15			; элемент "конец файла"
		jr	z,A0815
		ld	l,a
		ld	h,0
		add	hl,hl
		push	de
		ld	de,T0849		; массив адресов строк
		add	hl,de
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a
		pop	de
		call	A098A
		jr	A07F2
		;
A0815:		ld	hl,T0AA9		; "End of library."
		call	A02FB			; вывод строки
A081B:		call	close_file		; закрыть файл
		jp	exit			; выход в ДОС
		;
A0821:		ld	hl,T083A		; "Byte="
		call	A02FB			; вывод строки
		ld	a,b
		call	A0B91			; вывод "a" в hex-формате
		jr	A07F2
		;
A082D:		push	de
		ld	hl,T0840		; "Address="
		call	A02FB			; вывод строки
		pop	hl			; значение метки
		call	A0BBF			; вывод типа сегмента/адреса тек. метки
		jr	A07F2


; Индекс. список (по номерам элементов)
T0849:		dw	L0867			; 0  "Entry symbol (name for search) &"
		dw	L088A			; 1  "Select /&/ COMMON"
		dw	L089C			; 2  "Start module &"
		dw	L08AD			; 3  "Search & library"
		dw	L08BE			; 4  "Reserved item: &"
		dw	L08CF			; 5  "Set /&/ size to #"
		dw	L08E1			; 6  "External chain at # for &"
		dw	L08FD			; 7  "Define & as #"
		dw	L090D			; 8  "External - # offset"
		dw	L0921			; 9  "External + # offset"
		dw	L0935			; 10 "DSEG length = #"
		dw	L0945			; 11 "ORG #"
		dw	L094B			; 12 "Address chain at #"
		dw	L095E			; 13 "CSEG length = #"
		dw	L096E			; 14 "Module end, run address #"



A098A:		ld	a,(hl)
		inc	hl
		or	a
		ret	z
		cp	"&"			; вывод строки
A0990:		jr	z,A099B
		cp	"#"			; вывод в hex-формате
		jr	z,A09AB
		cp	"$"			; вывод в десят. формате
		jr	z,A09AD
		cp	"%"			; вывод строки в hex-формате
		jr	z,A09AF
		call	A02D6			; вывод "a" на экран
		jr	A098A
		;
; & вывод строки
A099B:		push	de
		push	hl
		ld	hl,field_B		; буфер B-поля (имя идентиф.), 33 байта
		ld	b,(hl)			; длина имени
		inc	hl			; имя
		call	A0305			; вывод строки на экран, "b" счетчик
		pop	hl
		pop	de
		jr	A098A
		;
; # вывод в hex-формате
A09AB:		push	hl
		ex	de,hl			; hl=значение метки
		call	A0BBF			; вывод типа сегмента/адреса тек. метки
		pop	hl
		jr	A098A
		;
; $ вывод в десят. формате
A09AD:		push	hl
		ex	de,hl			; hl=значение метки
		call	L0BA8			; вывод в десят. формате
		pop	hl
		jr	A098A
		;
; % вывод строки в hex-формате
A09AF:		push	de
		push	hl
		ld	hl,field_B		; буфер B-поля (имя идентиф.), 33 байта
		ld	b,(hl)			; длина имени
		inc	hl			; имя
A09B0:		ld	a,(hl)
		push	hl
		push	bc
		call	A0B91			; вывод "a" в hex-формате
		pop	bc
		pop	hl
		inc	hl
		djnz	A09B0
		pop	hl
		pop	de
		jr	A098A




; Записать слово в rel-поток
A09B3:		call	A09CF
		ld	b,e
		call	A09C2
		ld	b,d
		jp	A09C2

; Записать байт в rel-поток
A09BE:		xor	a
		call	A09DB
A09C2:		push	bc
		ld	c,b
		ld	b,8
A09C6:		rl	c
		call	A09DB
		djnz	A09C6
		pop	bc
		ret

; записать 3 бита ?
A09CF:		scf
A09D0:		call	A09DB
		ld	a,b
		rra
		rra
		call	A09DB
		ld	a,b
		rra
A09DB:		push	hl
		ld	hl,D0D24
		rl	(hl)			; продвинуть бит
		inc	hl
		inc	(hl)
		jr	nz,A09F5
		push	bc
		push	de
		ld	a,(D0D24)
		call	write_file		; байт в вых.буфер (и записать файл)
A09ED:		ld	hl,0F800h		; константа
		ld	(D0D24),hl		; сбр. байт и счетчик границы байта
		pop	de
		pop	bc
A09F5:		pop	hl
		ret



;=====================================================================
;  Вывести список модулей библиотеки
;=====================================================================
list_modules:	ld	hl,(D0D4F)
		call	A0444
A09FD:		call	A0D02			; раскрутка rel-битов
		jr	c,A09FD			; байт данных
		jr	z,A09FD			; слово данных
		ld	a,c			; тип спец-поля
		cp	2			; элемент "имя модуля" (program name)
		jr	z,A0A2E
		cp	3			; элемент "request имя" (search library)
		jr	z,request
		cp	6			; элемент "внешняя метка"
		jr	z,A0A33
		cp	7			; элемент "адрес метки"
		jr	z,A0A48
		cp	10			; элемент "размер области Данных" (A-поле: размер)
		jr	z,A0A58
		cp	13			; элемент "размер области Кода" (A-поле: размер)
		jr	z,A0A5E
		cp	14			; элемент "конец модуля (программы)"
		jr	z,A0A64
		cp	15			; элемент "конец файла"
		jr	nz,A09FD
		ld	hl,T0AA9		; "End of library."
		call	A02FB			; вывод строки
A0A28:		call	close_file		; закрыть файл
		jp	exit			; выход в ДОС
		;
A0A2E:		ld	hl,T0A82		; "Program module: "
		jr	A0A36
		;
request:	ld	hl,reqname		; "request "
		jr	A0A36
		;
A0A33:		ld	hl,T0A95		; "external "
A0A36:		call	A02FB			; вывод строки
		ld	hl,field_B		; буфер B-поля (имя идентиф.), 33 байта
		ld	b,(hl)			; длина имени
		inc	hl			; имя
		call	A0305			; вывод строки на экран, "b" счетчик
		;call	A02ED			; новая строка (и обнул. ячейку D0D20)
		call	nline
		call	pause
		jr	c,A0A28			; отмена режима
		jr	A09FD
		;
pause:		push	hl
		push	de
		ld	c,31h
		rst	10h
		jr	z,paus1			; не нажата
		cp	1Bh
		jr	z,paus2
		ld	c,30h
		rst	10h
		cp	1Bh
		jr	z,paus2
		; очистить буфер клавы
		ld	bc,3135h
		rst	10h
paus1:		xor	a
		jr	paus3
paus2:		scf
paus3:		pop	de
		pop	hl
		ret
		;
A0A48:		push	de
		ld	hl,T0A9F		; "Public   "
		call	A02FB			; вывод строки
		pop	hl			; hl=значение метки
		call	A0BBF			; вывод типа сегмента/адреса тек. метки
		ld	hl,T0AD5		; " = "
		jr	A0A36
		;
A0A58:		ld	(D128D),de		; размер "Data size: ..."
		jp	A09FD
		;
A0A5E:		ld	(D128B),de		; размер "Code size: ..."
		jp	A09FD
		;
A0A64:		ld	hl,T0AB9		; "Code size: "
		call	A02FB			; вывод строки
		ld	hl,(D128B)
		;call	A0B8C			; вывод "hl" в hex-формате
		call	L0BA8			; вывод "hl" в десят. формате
		ld	hl,T0AC8		; "Data size: "
		call	A02FB			; вывод строки
		ld	hl,(D128D)
		;call	A0B8C			; вывод "hl" в hex-формате
		call	L0BA8			; вывод "hl" в десят. формате
		;call	A02ED			; новая строка (и обнул. ячейку D0D20)
		call	nline
		jp	A09FD





; Смещает влево байт rel-потока с выдачей
; признака установки 7-го бита.
;
; out: "CY" - 7-й бит был "1"
A0AD9:		push	hl
		ld	hl,D0D1E
		ld	a,(hl)			; взять 8 бит (байт) rel-потока
		inc	hl
		inc	(hl)			; ++счетчик границы байта
		jr	nz,A0AE9		; байт не "кончился"
		push	de
		call	A016B			; получить байт из данных библы
		pop	de
		ld	(hl),0F8h		; сбр. счетчик границы байта
A0AE9:		dec	hl
		rl	(hl)			; байт rel-потока сдвинуть влево
		pop	hl
		ret


; развернуть 8 бит (1 байт)
A0AEE:		ld	c,8
		;
;=====================================================================
; Развернуть битовое поле, длиной в "c" бит.
;=====================================================================
; in: c=число бит
; out: a,b = значение
A0AF0:		ld	b,0
A0AF2:		call	A0AD9			; сместить влево байт rel-потока
		rl	b
		dec	c
		jr	nz,A0AF2
		ld	a,b
		ret


;=====================================================================
;  Разворачивание rel-потока
;=====================================================================
; out: "CY" - b = байт данных
;      "Z"  - de = слово данных
;      "NC" - c = номер элемента
;             b = тип сегмента
A0AFC:		xor	a			; aseg (начать с начального)
		ld	(type_seg),a		; тип сегмента
		call	A0AD9			; сместить влево байт rel-потока
		jr	c,A0B0A			; 7-й бит был "1" (осн.тип - "перемещаемый")
		; осн.тип - "абсолютный",
		; вернуть абс.байт данных
		call	A0AEE			; развернуть один байт (8 бит)
		scf				; вернуть "CY"
		ret
		;
		; узнать тип сегмента
A0B0A:		ld	c,2			; длина поля 2 бита
		call	A0AF0			; развернуть битовое поле
		or	a
		jr	z,A0B18			; спец-элемент
		; cseg, dseg, common
		; вернуть слово данных
		call	A0B7E			; развернуть 2 байта значения сегмента
		ld	b,a			; тип сегмента
		xor	a			; вернуть "Z"
		ret
		;
; Спец-элемент
A0B18:		push	hl
		; прочитать контр. поле
		ld	c,4			; длина поля
		call	A0AF0
		; a=номер элемента
		; далее нужна инфа о флаге "extnd_rel"
		cp	5
		push	af
		jr	c,A0B3C			; элементы только B-поля
		cp	15			; элемент "конец файла"
		jr	z,A0B55
		; A-поле
		ld	c,2			; 2 бита типа адресации (cseg,dseg,common)
		call	A0AF0			; развернуть битовое поле
		call	A0B7E			; развернуть 2 байта значения сегмента
		; вых: de=значение поля
		ld	a,(extnd_rel)
		or	a			; имеем расш. rel-формат ?
		jr	z,A0B3C			; нет
		; просто пройти дополн. 2 байта (16 бит)
		push	bc
		ld	c,16			; 16 бит поля
		call	A0AF0			; прочитать битовое поле
		pop	bc
		;
A0B3C:		pop	af
		; B-поле (0..4 и 6,7 номера)
		; A-поле (5..14 номера)
		push	af
		cp	9
		jr	nc,A0B55		; выйти
		push	de			; сохр. 16-bit значение A-поля
		call	A0B69			; развернуть поле длины имени (нужен rel-формат)
		ld	hl,field_B		; буфер B-поля (имя идентиф.), 33 байта
		ld	(hl),a			; длина имени
		inc	hl
		ld	e,a
A0B4C:		call	A0AEE			; развернуть один байт (поле в 8 бит)
		ld	(hl),a			; field_B+1 (#FE при расш. rel-формате)
		inc	hl
		dec	e
		jr	nz,A0B4C
		;
		pop	de			; восст. 16-bit значение A-поля
A0B55:		pop	af			; восст. номер элемента
		ld	hl,0FF00h		; константа
		cp	14			; элемент "конец прогр. модуля"
		jr	nz,A0B60
		ld	(D0D1E),hl		; уст. счетчик "граница байта" ?
A0B60:		ld	c,a			; вернуть номер элемента
		ld	a,(type_seg)		; тип сегмента
		ld	b,a
		inc	a
		or	a			; сбросить "CY"
		pop	hl
		ret


;=====================================================================
;  Развернуть поле длины имени идентификатора из rel-потока
;=====================================================================
; out: a=длина имени идентиф.
;
A0B69:		ld	a,(extnd_rel)		; флаг "расш. rel-формат"
		or	a
		jr	nz,A0B79		; да
		ld	c,3			; длина поля 3 бита
		call	A0AF0			; развернуть битовое поле
		or	a			; было 000b ?
		ret	nz
		ld	a,8			; длина имени (кодируется как 000b)
		ret
A0B79:		ld	c,5			; длина поля 5 бит
		jp	A0AF0			; развернуть битовое поле



;=====================================================================
; Развернуть 2 байта данных (значения метки) из rel-потока
;=====================================================================
; in: a=тип сегмента
; out: de=значение
;
A0B7E:		push	af
		ld	(type_seg),a		; тип сегмента
		call	A0AEE			; развернуть один байт (поле в 8 бит)
		ld	e,b
		call	A0AEE
		ld	d,b
		pop	af
		ret



; вывод "hl" в hex-формате
A0B8C:		ld	a,h
		call	A0B91
		ld	a,l
A0B91:		push	af
		rra
		rra
		rra
		rra
		call	A0B9A
		pop	af
A0B9A:		and	0Fh
		add	a,"0"
		cp	"9"+1
		jp	c,A02D6			; вывод "a" на экран
		add	a,7
		jp	A02D6			; вывод "a" на экран


; вывод "hl" в десят. формате
L0BA8:		ld	bc,-10			; к метке нет обращения
A0BAB:		ld	d,b
		ld	e,b
A0BAD:		add	hl,bc
		inc	de
		jr	c,A0BAD
		push	hl
		ex	de,hl
		ld	a,h
		or	l
		call	nz,A0BAB
		ld	a,3Ah
		pop	bc
		add	a,c
		jp	A02D6			; вывод "a" на экран


; Вывод буквы типа сегмента и адреса тек. глоб. метки
; in: hl=значение метки
A0BBF:		push	hl
		ld	hl,L0BDA-1		; "PDC"
		ld	a,(type_seg)		; тип сегмента
		or	a
		jr	z,A0BD6			; aseg
		ld	c,a
		ld	b,0
		add	hl,bc
		ld	a,(hl)			; буква типа сегмента
		call	A02D6			; вывод "a" на экран
		ld	a,":"			; разделитель
		call	A02D6			; вывод "a" на экран
A0BD6:		pop	hl			; hl=адрес метки (точка входа)
		call	A0B8C			; вывод "hl" в hex-формате
		ld	a,"h"
		jp	A02D6


; буквы типов сегментов
L0BDA:		db	"P"			; (P)rogram
		db	"D"			; (D)ata
		db	"C"			; (C)ommon




;=====================================================================
;  Записать полный спец. элемент в rel-поток
;=====================================================================
; in: c=номер элемента
;     для A-поля (5..14 номера):
;        de=значение
;        b=байт типа адресации сегмента (от A0D02)
put_item:	push	bc
		; записать биты 1 00b начала спец. элемента
		ld	b,0
		call	A09CF
		; записать контр. поле
		ld	b,c			; номер элемента контр. поля
		ld	a,4			; 4 бита контр. поля
		call	A0C59			; записать контр. поле в rel-поток
		pop	bc
		;
		ld	a,c
		cp	5
		jr	c,A0C17			; элементы только B-поля
		cp	15			; номер элемента "конец файла"
		ret	z
		; A-поле (5..14 номера)
		; записать 2 бита типа адресации
		ld	a,2			; 2 бита типа адресации, b=тип адресации
		call	A0C59			; записать тип адресации в rel-поток
		; записать 16 бит значения
		ld	b,e
		call	A09C2
		ld	b,d
		call	A09C2
		ld	a,(extnd_rel)		; флаг "расш. rel-формат"
		or	a
		jr	z,A0C0F			; нет
		; записать дополнительные 16 бит
		ld	b,0
		call	A09C2
		ld	b,0
		call	A09C2
		;
A0C0F:		ld	a,c
		cp	14			; номер элемента "конец модуля"
		jr	z,A0C2C
		cp	9
		ret	nc
		; A-поле (5..8 номера)
		; B-поле (0..4 и 6,7 номера)
A0C17:		ld	a,(field_B)		; длина имени
		ld	b,a
		call	A0C3F			; записать длину имени в B-поле
		push	hl
		ld	hl,field_B+1		; имя идентиф. (или байт типа элемента расширения)
A0C22:		ld	b,(hl)
		call	A09C2			; записать имя (байт(ы))
		inc	hl
		dec	d
		jr	nz,A0C22
		pop	hl
		ret
		; выровнить на границу байта
A0C2C:		ld	a,(D0D25)
		cp	0F8h
		jr	z,A0C3A			; дошли до границы байта
		scf
		call	A09DB
		jr	A0C2C
		;
A0C3A:		xor	a			; false
		ld	(extnd_rel),a		; сбр. флаг "расш. rel-формат"
		ret



;=====================================================================
;  Записать длину имени идентификатора в B-поле
;=====================================================================
; in: b=длина имени
; out: d=длина имени идентиф.
;
A0C3F:		ld	d,b			; длина имени
		ld	a,(extnd_rel)		; флаг "расш. rel-формат"
		or	a
		jr	nz,A0C53		; да
		ld	a,3			; размер бит. поля, b=длина имени
		call	A0C59			; записать поле в rel-поток
		ld	a,d
		and	7
		ld	d,a
		ret	nz
		ld	d,8			; макс. длина имени идентиф.
		ret
		;
A0C53:		ld	a,5			; длина бит. поля, b=длина имени
		jr	A0C59			; записать поле в rel-поток



;=====================================================================
;  Записать поле (номер элемента/длину имени) в rel-поток
;=====================================================================
; in: a=размер битового поля
;     b=номер элемента (длина имени для B-поля)
A0C59:		push	de
		ld	d,b			; номер элемента
		ld	b,a			; длина битового поля
A0C5C:		rrc	d
		djnz	A0C5C
		ld	b,a
A0C61:		rlc	d
		call	A09DB
		djnz	A0C61
		pop	de
		ret



A0C6D:		call	A02FB			; вывод строки
		;call	A02ED			; новая строка (и обнул. ячейку D0D20)
		call	nline
		ld	a,-1			; возвр. код
		jp	abort			; выход в ДОС


L0C78:		ld	hl,T0C96		; "File read error"
		jr	A0C6D


A0C7E:		ld	hl,T1209		; ds 65  имя файла
		call	A02FB			; вывод строки
		ld	hl,T0CA6		; ": file not found"
		jr	A0C6D


A0C90:		ld	hl,T0CC8		; "Library write error"
		jr	A0C6D



;=================================================================
;  Раскрутка rel-данных
;=================================================================
; out: a,c = номер спец-элемента
;        b = байт данных
;       de = слово данных
;
A0D02:		call	A0AFC
		ret	c			; байт данных
		ret	z			; слово данных
		push	af
		ld	a,c
		cp	4			; номер элемента "расш. rel-формат"
		jr	nz,A0D1C
		ld	a,(field_B+1)		; имя идентиф.
		and	0FCh			; выделить 7..2 биты
		cp	0FCh			; (была сигнатура 0FEh ?)
		jr	nz,A0D1C		; нет
		ld	a,true
		ld	(extnd_rel),a		; флаг "расш. rel-формат"
A0D1C:		pop	af
		ret



		include "io.asm"


D0D1E:		db	0			; байт из rel-потока
		db	0			; счетчик границы байта (F8)

;D0D20:		db	0			; нужна ?
D0D21:		dw	0
D0D23:		db	0			; флаг наличия "Externals missing"

; заносится константа 0F800h
D0D24:		db	0
D0D25:		db	0			; 0F8h


; буфер B-поля rel-формата
field_B:	db	0			; длина имени
		ds	33			; имя идентиф.


type_seg:	db	0			; 0,1,2,3 тип сегмента

D0D4E:		db	0
D0D4F:		dw	0

D0D51:		dw	0

T0D53:		ds	60			; буфер списка имен извлек. модулей


extnd_rel:	db	false			; флаг "расш. rel-формат"


T0D90:		db	0			; дескриптор

; файл библы или временный ?
T0DB5:		db	0			; дескриптор

; временный файл (переимен. файла?)
T0DDA:		db	0			; дескриптор


; буфер	входного файла
A0DFF:		ds	1024+1

; буфер	выходного файла
A1000:		ds	1024+1

D1201:		dw	0			; тек. полож. в буфере "A0DFF" (вх.файл)
D1203:		dw	0			; тек. полож. в буфере "A1000" (вых.файл)


T1209:		ds	65			; имена файлов

T124A:		ds	65			; имя файла для извлеченного модуля


; сохр. тек. диск и путь
disk:		db	0
dir:		ds	65


f_path:		ds	65			; буфер функции found_first


D128B:		dw	0			; размер "Code size: ..."
D128D:		dw	0			; размер "Data size: ..."


D128F:		dw	0			; размер rel-имиджа
		;
; 3 байта смещения от начала rel-имиджа до rel-модуля,
; содержащего символьную строку (имя).
D1291:		db	0
D1292:		db	0
D1293:		db	0




; используется под буфер при реиндексации
L1296:		db	0			;+0
		;
start:		; сохр. тек. диск/путь		;+1
		ld	c,2			; узнать тек. диск
		rst	10h
		ld	(disk),a
		ld	hl,dir
		ld	c,1Eh			; узнать тек. каталог
		rst	10h
		;
		ld	hl,(L0080)
		ld	c,(hl)			; длина ком-строки
		ld	b,0
		inc	hl
		add	hl,bc
		ld	(hl),b			; нуль в конец ком-строки
		ld	hl,Title		; титл программы
		call	A02FB			; вывод строки
		ld	hl,(L0080)
		inc	hl
A12CC:		ld	a,(hl)
		inc	hl
		cp	" "
		jr	z,A12CC
		cp	9			; Tab
		jr	z,A12CC
		and	5Fh
		ld	(D0D4E),a
		ld	a,(hl)
		cp	" "
		jr	nz,usage
		ld	iy,D0D4F
A12E4:		ld	a,(hl)
		inc	hl
		cp	" "
		jr	z,A12E4
		cp	9			; Tab
		jr	z,A12E4
		or	a
		jr	z,A1314
		dec	hl
		ld	(iy+0),l
		inc	iy
		ld	(iy+0),h
		inc	iy
A12FC:		ld	a,(hl)
		inc	hl
		or	a
		jr	z,A1314
		cp	" "
		jr	z,A130D
		cp	9			; Tab
		jr	z,A130D
		cp	","			; разделитель имен
		jr	nz,A12FC
A130D:		dec	hl
		ld	(hl),0
		inc	hl
		jr	A12E4
		;
A1314:		ld	(iy+0),0
		ld	(iy+1),0
		ld	a,(D0D4E)
		cp	"A"			; добавить модуль в библу
		jp	z,add_module
		cp	"D"			; дамп содержимого библы
		jp	z,dump_library
		cp	"E"			; извлечь модуль из библы
		jp	z,extracting_module
		cp	"L"			; вывести список и параметры модулей библы
		jp	z,list_modules
		cp	"R"			; переиндексация библы (индекс. блока в начале библы)
		jp	z,reindexing
		cp	"T"			; проверка на неопред. внешние метки
		jp	z,test_extrn_missing
		; default
usage:		ld	hl,Help
		call	A02FB			; вывод строки
		ld	a,-1			; возвр. код
		jp	abort			; выход в ДОС




Help:		db	"Syntax: OL <option> <library-file> [<module-file> ...]",0Dh,0Ah
		db	"options:",0Dh,0Ah
		db	9,"A  - add modules to library",0Dh,0Ah
		db	9,"D  - dump contents of library",0Dh,0Ah
		db	9,"E  - extract modules from library",0Dh,0Ah
		db	9,"L  - list library",0Dh,0Ah
		db	9,"R  - reindex library",0Dh,0Ah
		db	9,"T  - test unresolved externals",0Dh,0Ah,0

Title:		db	"Object LIBRARIAN v0.02  Ported by Vasil Ivanov",0Dh,0Ah
		db	"Based on OL version 1.00  (c) 1995, SOLiD Inc.",0Dh,0Ah,0
