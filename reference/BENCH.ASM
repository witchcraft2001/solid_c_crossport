	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	dseg
errno_:	ds	1
_t0_:	ds	2
	cseg
;{
timer_start_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	push	bc
	ld	hl,0
	add	hl,sp
	call	gettime_
	ld	hl,3
	add	hl,sp
	ld	a,(hl)
	ld	e,a
@0:
	push	de
	ld	hl,2
	add	hl,sp
	call	gettime_
	ld	hl,5
	add	hl,sp
	ld	a,(hl)
	pop	de
	cp	e
	jp	z,@0
	ld	hl,0
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	ld	(ix-2),l
	ld	(ix-1),h
	ld	hl,3
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	push	hl
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	de,60
	call	?mulhd
	pop	de
	add	hl,de
	ld	(_t0_),hl
	ld	sp,ix
	pop	ix
	ret
;}

;{
timer_elapsed_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	push	bc
	ld	hl,0
	add	hl,sp
	call	gettime_
	ld	hl,0
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	ld	(ix-2),l
	ld	(ix-1),h
	ld	hl,3
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	push	hl
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	de,60
	call	?mulhd
	pop	de
	add	hl,de
	ex	de,hl
	ld	hl,(_t0_)
	ld	a,e
	sub	l
	ld	a,d
	sbc	a,h
	jp	nc,@1
	ld	hl,3600
	add	hl,de
	ex	de,hl
@1:
	ld	hl,(_t0_)
	ld	a,e
	sub	l
	ld	l,a
	ld	a,d
	sbc	a,h
	ld	h,a
	ld	sp,ix
	pop	ix
	ret
;}

	dseg
rng_:	ds	1
	cseg
;{
rng_seed_:
	ld	(rng_),a
	ret
;}

;{
rng_next_:
	ld	a,(rng_)
	ld	b,a
	add	a,a
	add	a,a
	add	a,b
	inc	a
	ld	(rng_),a
	ld	a,(rng_)
	ret
;}

	dseg
sieve_:	ds	1000
arr_:	ds	256
data_:	ds	256
rc4_s_:	ds	256
	cseg
;{
bench_sieve_:
	ex	de,hl
	ld	hl,0
@9:
	call	?cpshd
	jp	nc,@2
	push	de
	ld	de,0
	push	hl
@4:
	ld	a,e
	sub	232
	ld	a,d
	sbc	a,3
	jp	nc,@3
	ld	hl,sieve_
	add	hl,de
	ld	(hl),1
	inc	de
	jp	@4
@3:
	xor	a
	ld	(sieve_),a
	xor	a
	ld	(sieve_+1),a
	ld	de,2
@8:
	ld	a,e
	sub	32
	ld	a,d
	sbc	a,0
	jp	nc,@5
	ld	hl,sieve_
	add	hl,de
	ld	a,(hl)
	or	a
	jp	z,@6
	ld	l,e
	ld	h,d
	push	de
	call	?mulhd
	pop	de
@7:
	ld	a,l
	sub	232
	ld	a,h
	sbc	a,3
	jp	nc,@6
	push	hl
	ld	bc,sieve_
	add	hl,bc
	ld	(hl),0
	pop	hl
	add	hl,de
	jp	@7
@6:
	inc	de
	jp	@8
@5:
	pop	hl
	inc	hl
	pop	de
	jp	@9
@2:
	ld	bc,0
	ld	de,0
@12:
	ld	a,e
	sub	232
	ld	a,d
	sbc	a,3
	jp	nc,@10
	ld	hl,sieve_
	add	hl,de
	ld	a,(hl)
	or	a
	jp	z,@11
	inc	bc
@11:
	inc	de
	jp	@12
@10:
	ld	l,c
	ld	h,b
	ret
;}

;{
bench_bubble_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	ex	de,hl
	ld	hl,0
@21:
	call	?cpshd
	jp	nc,@13
	push	de
	push	hl
	ld	hl,66
	call	rng_seed_
	ld	hl,0
@15:
	ld	de,256
	call	?cpshd
	jp	nc,@14
	ld	(ix-4),l
	ld	(ix-3),h
	push	hl
	call	rng_next_
	ld	l,(ix-4)
	ld	h,(ix-3)
	ld	bc,arr_
	add	hl,bc
	ld	(hl),a
	pop	hl
	inc	hl
	jp	@15
@14:
	ld	hl,0
	ld	(ix-4),l
	ld	(ix-3),h
@20:
	ld	de,255
	call	?cpshd
	jp	nc,@16
	ld	bc,0
	push	hl
@19:
	ld	de,255
	ld	l,(ix-4)
	ld	h,(ix-3)
	ld	a,e
	sub	l
	ld	e,a
	ld	a,d
	sbc	a,h
	ld	d,a
	ld	l,c
	ld	h,b
	call	?cpshd
	jp	nc,@17
	ld	hl,arr_+1
	add	hl,bc
	ld	a,(hl)
	ld	hl,arr_
	add	hl,bc
	cp	(hl)
	jp	nc,@18
	ld	hl,arr_
	add	hl,bc
	ld	e,(hl)
	ld	hl,arr_+1
	add	hl,bc
	ld	a,(hl)
	ld	hl,arr_
	add	hl,bc
	ld	(hl),a
	ld	hl,arr_+1
	add	hl,bc
	ld	(hl),e
@18:
	inc	bc
	jp	@19
@17:
	pop	hl
	inc	hl
	ld	(ix-4),l
	ld	(ix-3),h
	jp	@20
@16:
	pop	hl
	inc	hl
	pop	de
	jp	@21
@13:
	xor	a
	ld	(ix-2),a
	ld	hl,0
@23:
	ld	de,256
	call	?cpshd
	jp	nc,@22
	push	hl
	ld	bc,arr_
	add	hl,bc
	ld	a,(ix-2)
	add	a,(hl)
	ld	(ix-2),a
	pop	hl
	inc	hl
	jp	@23
@22:
	ld	a,(ix-2)
	ld	l,a
	ld	h,0
	ld	sp,ix
	pop	ix
	ret
;}

;{
bench_shell_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	push	bc
	push	bc
	ex	de,hl
	ld	hl,0
@33:
	call	?cpshd
	jp	nc,@24
	push	de
	push	hl
	ld	hl,66
	call	rng_seed_
	ld	hl,0
@26:
	ld	de,256
	call	?cpshd
	jp	nc,@25
	ld	(ix-8),l
	ld	(ix-7),h
	push	hl
	call	rng_next_
	ld	l,(ix-8)
	ld	h,(ix-7)
	ld	bc,arr_
	add	hl,bc
	ld	(hl),a
	pop	hl
	inc	hl
	jp	@26
@25:
	ld	de,128
	ld	(ix-4),e
	ld	(ix-3),d
@32:
	ld	hl,0
	call	?cpshd
	jp	nc,@27
	ld	c,e
	ld	b,d
	push	de
@31:
	ld	l,c
	ld	h,b
	ld	de,256
	call	?cpshd
	jp	nc,@28
	ld	hl,arr_
	add	hl,bc
	ld	a,(hl)
	ld	(ix-2),a
	ld	(ix-6),c
	ld	(ix-5),b
	push	bc
	push	af
@30:
	ld	l,(ix-4)
	ld	h,(ix-3)
	ex	de,hl
	ld	l,c
	ld	h,b
	call	?cpshd
	jp	c,@29
	ld	e,(ix-4)
	ld	d,(ix-3)
	ld	a,c
	sub	e
	ld	l,a
	ld	a,b
	sbc	a,d
	ld	h,a
	ld	e,c
	ld	d,b
	ld	bc,arr_
	add	hl,bc
	ld	a,(ix-2)
	cp	(hl)
	jp	nc,@29
	ld	l,(ix-4)
	ld	h,(ix-3)
	push	hl
	ld	a,e
	sub	l
	ld	l,a
	ld	a,d
	sbc	a,h
	ld	h,a
	ld	bc,arr_
	add	hl,bc
	ld	a,(hl)
	ld	hl,arr_
	add	hl,de
	ld	(hl),a
	pop	bc
	ld	a,e
	sub	c
	ld	c,a
	ld	a,d
	sbc	a,b
	ld	b,a
	ld	(ix-6),c
	ld	(ix-5),b
	jp	@30
@29:
	ld	c,(ix-6)
	ld	b,(ix-5)
	ld	hl,arr_
	add	hl,bc
	pop	af
	ld	(hl),a
	pop	bc
	inc	bc
	jp	@31
@28:
	pop	hl
	ld	de,2
	call	?dvihd
	ex	de,hl
	ld	(ix-4),e
	ld	(ix-3),d
	jp	@32
@27:
	pop	hl
	inc	hl
	pop	de
	jp	@33
@24:
	xor	a
	ld	(ix-1),a
	ld	hl,0
@35:
	ld	de,256
	call	?cpshd
	jp	nc,@34
	push	hl
	ld	bc,arr_
	add	hl,bc
	ld	a,(ix-1)
	add	a,(hl)
	ld	(ix-1),a
	pop	hl
	inc	hl
	jp	@35
@34:
	ld	a,(ix-1)
	ld	l,a
	ld	h,0
	ld	sp,ix
	pop	ix
	ret
;}

;{
bench_crc_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	hl
	push	bc
	ld	(ix-2),l
	ld	(ix-1),h
	ld	de,0
@37:
	ld	a,d
	cp	1
	jp	nc,@36
	ld	hl,data_
	add	hl,de
	ld	(hl),e
	inc	de
	jp	@37
@36:
	ld	hl,0
@45:
	push	hl
	ld	l,(ix-2)
	ld	h,(ix-1)
	ex	de,hl
	pop	hl
	call	?cpshd
	jp	nc,@38
	push	hl
	ld	hl,65535
	ld	(ix-4),l
	ld	(ix-3),h
	ld	de,0
@44:
	ld	a,d
	cp	1
	jp	nc,@39
	ld	hl,data_
	add	hl,de
	push	de
	ld	e,(hl)
	xor	a
@43:
	cp	8
	jp	nc,@40
	push	af
	ld	c,e
	ld	b,0
	ld	l,(ix-4)
	ld	h,(ix-3)
	ld	a,l
	xor	c
	ld	c,a
	ld	a,h
	xor	b
	ld	b,a
	ld	a,c
	and	1
	jp	z,@41
	ld	b,1
	call	?srnhb
	ld	a,l
	xor	8
	ld	l,a
	ld	a,h
	xor	132
	ld	h,a
	ld	(ix-4),l
	ld	(ix-3),h
	jp	@42
@41:
	ld	b,1
	call	?srnhb
	ld	(ix-4),l
	ld	(ix-3),h
@42:
	ld	a,e
	rrca
	and	127
	ld	e,a
	pop	af
	inc	a
	jp	@43
@40:
	pop	de
	inc	de
	jp	@44
@39:
	pop	hl
	inc	hl
	jp	@45
@38:
	ld	l,(ix-4)
	ld	h,(ix-3)
	ld	a,l
	cpl
	ld	l,a
	ld	a,h
	cpl
	ld	h,a
	ld	sp,ix
	pop	ix
	ret
;}

;{
bench_rc4_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	ex	de,hl
	ld	hl,0
@53:
	call	?cpshd
	jp	nc,@46
	push	de
	ld	de,0
	push	hl
@48:
	ld	a,d
	cp	1
	jp	nc,@47
	ld	hl,rc4_s_
	add	hl,de
	ld	(hl),e
	inc	de
	jp	@48
@47:
	xor	a
	ld	(ix-3),a
	ld	hl,0
@50:
	ld	a,h
	cp	1
	jp	nc,@49
	ld	a,l
	push	hl
	ld	c,l
	ld	b,h
	add	hl,hl
	ld	e,l
	ld	d,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	e,a
	ld	a,l
	add	a,31
	ld	l,e
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	push	de
	ld	e,a
	ld	a,(ix-3)
	add	a,(hl)
	add	a,e
	ld	(ix-3),a
	pop	de
	ld	l,e
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	push	af
	ld	a,(hl)
	ld	(ix-2),a
	pop	af
	ld	l,a
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	push	af
	ld	a,(hl)
	ld	l,e
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	ld	(hl),a
	pop	af
	ld	l,a
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	ld	a,(ix-2)
	ld	(hl),a
	pop	hl
	inc	hl
	jp	@50
@49:
	ld	e,0
	ld	(ix-4),e
	xor	a
	ld	(ix-3),a
	ld	de,0
@52:
	ld	a,d
	cp	1
	jp	nc,@51
	push	de
	ld	e,(ix-4)
	inc	e
	ld	(ix-4),e
	ld	l,e
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	ld	a,(ix-3)
	add	a,(hl)
	ld	l,e
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	push	af
	ld	a,(hl)
	ld	(ix-2),a
	pop	af
	ld	l,a
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	push	af
	ld	a,(hl)
	ld	l,e
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	ld	(hl),a
	pop	af
	ld	l,a
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	ld	(ix-3),a
	ld	a,(ix-2)
	ld	(hl),a
	ld	l,e
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	ld	a,(hl)
	push	af
	ld	a,(ix-3)
	ld	l,a
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	pop	af
	add	a,(hl)
	ld	l,a
	ld	h,0
	ld	bc,rc4_s_
	add	hl,bc
	ld	b,(hl)
	pop	de
	ld	hl,data_
	add	hl,de
	ld	(hl),b
	inc	de
	jp	@52
@51:
	pop	hl
	inc	hl
	pop	de
	jp	@53
@46:
	ld	c,0
	ld	de,0
@55:
	ld	a,d
	cp	1
	jp	nc,@54
	ld	hl,data_
	add	hl,de
	ld	a,c
	add	a,(hl)
	ld	c,a
	inc	de
	jp	@55
@54:
	ld	l,c
	ld	h,0
	ld	sp,ix
	pop	ix
	ret
;}

;{
bench_math_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	ex	de,hl
	ld	hl,0
	ld	(ix-2),l
	ld	(ix-1),h
	ld	hl,0
@59:
	call	?cpshd
	jp	nc,@56
	ld	bc,1
	push	de
	ld	de,1
	push	hl
@58:
	ld	a,e
	sub	233
	ld	a,d
	sbc	a,3
	jp	nc,@57
	ld	l,c
	ld	h,b
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	c,l
	ld	b,h
	ld	l,(ix-2)
	ld	h,(ix-1)
	add	hl,bc
	ld	(ix-2),l
	ld	(ix-1),h
	inc	de
	jp	@58
@57:
	pop	hl
	inc	hl
	pop	de
	jp	@59
@56:
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	sp,ix
	pop	ix
	ret
;}

?63999:
	db	90,56,48,32,66,101,110,99,104,109
	db	97,114,107,32,118,49,46,48,32,40
	db	83,79,76,73,68,32,67,41,10,0
?63998:
	db	61,61,61,61,61,61,61,61,61,61
	db	61,61,61,61,61,61,61,61,61,61
	db	61,61,61,61,61,61,61,61,10,10
	db	0
?63997:
	db	32,32,84,101,115,116,32,32,32,32
	db	32,32,32,32,32,32,82,117,110,115
	db	32,32,67,104,101,99,107,32,32,84
	db	105,109,101,10,0
?63996:
	db	32,32,45,45,45,45,45,45,45,45
	db	45,45,45,45,32,45,45,45,45,45
	db	32,45,45,45,45,45,45,32,45,45
	db	45,45,45,10,0
?63995:
	db	32,32,83,105,101,118,101,32,32,32
	db	32,32,32,32,32,120,50,48,48,32
	db	32,0
?63994:
	db	32,37,53,117,32,32,37,50,117,58
	db	37,48,50,117,10,0
?63993:
	db	32,32,66,117,98,98,108,101,32,115
	db	111,114,116,32,32,120,49,48,32,32
	db	32,0
?63992:
	db	32,37,53,117,32,32,37,50,117,58
	db	37,48,50,117,10,0
?63991:
	db	32,32,83,104,101,108,108,32,115,111
	db	114,116,32,32,32,120,54,48,32,32
	db	32,0
?63990:
	db	32,37,53,117,32,32,37,50,117,58
	db	37,48,50,117,10,0
?63989:
	db	32,32,67,82,67,45,49,54,32,32
	db	32,32,32,32,32,120,52,48,48,32
	db	32,0
?63988:
	db	32,37,53,117,32,32,37,50,117,58
	db	37,48,50,117,10,0
?63987:
	db	32,32,82,67,52,32,32,32,32,32
	db	32,32,32,32,32,120,53,48,48,32
	db	32,0
?63986:
	db	32,37,53,117,32,32,37,50,117,58
	db	37,48,50,117,10,0
?63985:
	db	32,32,73,110,116,32,109,97,116,104
	db	32,32,32,32,32,120,50,48,48,32
	db	32,0
?63984:
	db	32,37,53,117,32,32,37,50,117,58
	db	37,48,50,117,10,0
?63983:
	db	32,32,45,45,45,45,45,45,45,45
	db	45,45,45,45,32,45,45,45,45,45
	db	32,45,45,45,45,45,45,32,45,45
	db	45,45,45,10,0
?63982:
	db	32,32,84,79,84,65,76,32,32,32
	db	32,32,32,32,32,32,32,32,32,32
	db	32,32,32,32,32,32,32,32,37,50
	db	117,58,37,48,50,117,10,0
;{
main_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	push	bc
	ld	hl,0
	ld	bc,?63999
	push	bc
	ld	(ix-6),l
	ld	(ix-5),h
	ld	hl,1
	call	printf_
	pop	bc
	ld	bc,?63998
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	bc,?63997
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	bc,?63996
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	bc,?63995
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	call	timer_start_
	ld	hl,200
	call	bench_sieve_
	ld	(ix-4),l
	ld	(ix-3),h
	call	timer_elapsed_
	ex	de,hl
	ld	l,(ix-6)
	ld	h,(ix-5)
	add	hl,de
	push	hl
	ld	l,e
	ld	h,d
	ld	(ix-2),e
	ld	(ix-1),d
	ld	de,60
	call	?dvnhd
	push	de
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	de,60
	call	?dvnhd
	push	hl
	ld	l,(ix-4)
	ld	h,(ix-3)
	push	hl
	ld	bc,?63994
	push	bc
	ld	hl,4
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	bc,?63993
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	call	timer_start_
	ld	hl,10
	call	bench_bubble_
	ld	(ix-4),l
	ld	(ix-3),h
	call	timer_elapsed_
	ex	de,hl
	pop	hl
	add	hl,de
	push	hl
	ld	l,e
	ld	h,d
	ld	(ix-2),e
	ld	(ix-1),d
	ld	de,60
	call	?dvnhd
	push	de
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	de,60
	call	?dvnhd
	push	hl
	ld	l,(ix-4)
	ld	h,(ix-3)
	push	hl
	ld	bc,?63992
	push	bc
	ld	hl,4
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	bc,?63991
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	call	timer_start_
	ld	hl,60
	call	bench_shell_
	ld	(ix-4),l
	ld	(ix-3),h
	call	timer_elapsed_
	ex	de,hl
	pop	hl
	add	hl,de
	push	hl
	ld	l,e
	ld	h,d
	ld	(ix-2),e
	ld	(ix-1),d
	ld	de,60
	call	?dvnhd
	push	de
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	de,60
	call	?dvnhd
	push	hl
	ld	l,(ix-4)
	ld	h,(ix-3)
	push	hl
	ld	bc,?63990
	push	bc
	ld	hl,4
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	bc,?63989
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	call	timer_start_
	ld	hl,400
	call	bench_crc_
	ld	(ix-4),l
	ld	(ix-3),h
	call	timer_elapsed_
	ex	de,hl
	pop	hl
	add	hl,de
	push	hl
	ld	l,e
	ld	h,d
	ld	(ix-2),e
	ld	(ix-1),d
	ld	de,60
	call	?dvnhd
	push	de
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	de,60
	call	?dvnhd
	push	hl
	ld	l,(ix-4)
	ld	h,(ix-3)
	push	hl
	ld	bc,?63988
	push	bc
	ld	hl,4
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	bc,?63987
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	call	timer_start_
	ld	hl,500
	call	bench_rc4_
	ld	(ix-4),l
	ld	(ix-3),h
	call	timer_elapsed_
	ex	de,hl
	pop	hl
	add	hl,de
	push	hl
	ld	l,e
	ld	h,d
	ld	(ix-2),e
	ld	(ix-1),d
	ld	de,60
	call	?dvnhd
	push	de
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	de,60
	call	?dvnhd
	push	hl
	ld	l,(ix-4)
	ld	h,(ix-3)
	push	hl
	ld	bc,?63986
	push	bc
	ld	hl,4
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	bc,?63985
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	call	timer_start_
	ld	hl,200
	call	bench_math_
	ld	(ix-4),l
	ld	(ix-3),h
	call	timer_elapsed_
	ex	de,hl
	pop	hl
	add	hl,de
	push	hl
	ld	l,e
	ld	h,d
	ld	(ix-2),e
	ld	(ix-1),d
	ld	de,60
	call	?dvnhd
	push	de
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	de,60
	call	?dvnhd
	push	hl
	ld	l,(ix-4)
	ld	h,(ix-3)
	push	hl
	ld	bc,?63984
	push	bc
	ld	hl,4
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	bc,?63983
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	pop	hl
	ld	de,60
	ld	(ix-6),l
	ld	(ix-5),h
	call	?dvnhd
	push	de
	ld	l,(ix-6)
	ld	h,(ix-5)
	ld	de,60
	call	?dvnhd
	push	hl
	ld	bc,?63982
	push	bc
	ld	hl,3
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	ld	sp,ix
	pop	ix
	ret
;}


	public	errno_
	public	_t0_
	public	timer_start_
	extrn	gettime_
	extrn	?mulhd
	public	timer_elapsed_
	public	rng_
	public	rng_seed_
	public	rng_next_
	public	sieve_
	public	arr_
	public	data_
	public	rc4_s_
	public	bench_sieve_
	extrn	?cpshd
	public	bench_bubble_
	public	bench_shell_
	extrn	?dvihd
	public	bench_crc_
	extrn	?srnhb
	public	bench_rc4_
	public	bench_math_
	public	main_
	extrn	printf_
	extrn	?dvnhd

	end
