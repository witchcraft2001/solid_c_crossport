	.z80
;	SOLID C Compiler ver 1.00 (pass 2)

	dseg
errno_:	ds	1
HO_:	ds	2
HI_:	ds	2
Fname_:	ds	80
LISTname_:	ds	80
TRDname_:	ds	80
tr0_:	ds	2048
sec9_:	ds	256
pt_:	ds	2
ppt_:	ds	2
pt_line_:	ds	2
TRDOSname_:	ds	9
ftyp_:	ds	1
fstart_:	ds	2
blk_:	ds	2
flenStruct_:	ds	2
flen_:	ds	2
_tr_:	ds	2
_sec_:	ds	2
asec_:	ds	2
Nfile_:	ds	2
freesec_:	ds	2
Line_:	ds	2
TRUNC_:	ds	2
PASS_N_:	ds	2
isHEAD_:	ds	2
nnn_:	ds	2
	cseg
fTRUNC_:
	dw	0
;{
filelength_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	ld	bc,2
	push	hl
	push	bc
	ld	de,0
	ld	bc,0
	call	lseek_
	pop	bc
	ld	(ix-2),l
	ld	(ix-1),h
	pop	hl
	ld	de,0
	ld	bc,0
	call	seek_
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	sp,ix
	pop	ix
	ret
;}

;{
ini_cright_:
	ld	hl,0
@0:
	ld	de,2048
	call	?cpshd
	ret	nc
	push	hl
	ld	bc,tr0_
	add	hl,bc
	ld	(hl),0
	pop	hl
	inc	hl
	jp	@0
;}

;{
sskip_:
@2:
	ld	hl,(pt_)
	ld	a,(hl)
	cp	32
	jp	z,@1
	ld	hl,(pt_)
	ld	a,(hl)
	cp	9
	ret	nz
@1:
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	jp	@2
;}

;{
skip_end_:
@4:
	ld	hl,(pt_)
	ld	a,(hl)
	cp	13
	jp	z,@3
	ld	hl,(pt_)
	ld	a,(hl)
	cp	10
	jp	z,@3
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	jp	@4
@3:
	ld	hl,(pt_)
	ld	a,(hl)
	cp	13
	jp	z,@5
	ld	hl,(pt_)
	ld	a,(hl)
	cp	10
	ret	nz
@5:
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	jp	@3
;}

;{
skip_comma_:
@7:
	ld	hl,(pt_)
	ld	a,(hl)
	cp	44
	jp	z,@6
	ld	hl,(pt_)
	ld	a,(hl)
	cp	13
	jp	z,@6
	ld	hl,(pt_)
	ld	a,(hl)
	cp	10
	jp	z,@6
	ld	hl,(pt_)
	ld	a,(hl)
	cp	59
	jp	z,@6
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	jp	@7
@6:
	ld	hl,(pt_)
	ld	a,(hl)
	cp	44
	jp	nz,@8
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	call	sskip_
	xor	a
	ret
@8:
	ld	a,1
	ret
;}

;{
cword_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	hl
	push	bc
	ld	(ix-2),l
	ld	(ix-1),h
	call	strlen_
	ex	de,hl
	ld	bc,0
@12:
	ld	l,c
	ld	h,b
	call	?cpshd
	jp	nc,@9
	ld	hl,(pt_)
	add	hl,bc
	ld	a,(hl)
	ld	(ix-4),c
	ld	(ix-3),b
	push	de
	call	toupper_
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	c,(ix-4)
	ld	b,(ix-3)
	add	hl,bc
	pop	de
	cp	(hl)
	jp	z,@10
	ld	hl,65535
	jp	@11
@10:
	inc	bc
	jp	@12
@9:
	ld	hl,(pt_)
	add	hl,de
	ld	(pt_),hl
	call	sskip_
	ld	hl,0
@11:
	ld	sp,ix
	pop	ix
	ret
;}

?63999:
	db	69,82,82,79,82,32,40,76,105,110
	db	101,61,37,48,51,117,41,58,32,0
?63998:
	db	60,37,115,62,10,0
;{
errm_:
	push	hl
	ld	hl,(Line_)
	push	hl
	ld	bc,?63999
	push	bc
	ld	hl,2
	call	printf_
	pop	bc
	pop	bc
	pop	hl
	push	hl
	ld	bc,?63998
	push	bc
	ld	hl,2
	call	printf_
	pop	bc
	pop	bc
	ret
;}

?63997:
	db	69,82,82,76,73,78,69,32,91,0
?63996:
	db	37,99,0
?63995:
	db	93,10,69,82,82,79,82,32,40,76
	db	105,110,101,61,37,48,51,117,41,58
	db	32,0
?63994:
	db	60,37,115,62,10,0
;{
errex_:
	ld	bc,?63997
	push	hl
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
@14:
	ld	hl,(pt_line_)
	ld	a,(hl)
	cp	13
	jp	z,@13
	ld	hl,(pt_line_)
	ld	a,(hl)
	cp	10
	jp	z,@13
	ld	hl,(pt_line_)
	ld	a,(hl)
	or	a
	jp	z,@13
	ld	hl,(pt_line_)
	ld	l,(hl)
	push	hl
	ld	bc,?63996
	push	bc
	ld	hl,2
	call	printf_
	pop	bc
	pop	bc
	ld	hl,(pt_line_)
	inc	hl
	ld	(pt_line_),hl
	jp	@14
@13:
	ld	hl,(Line_)
	push	hl
	ld	bc,?63995
	push	bc
	ld	hl,2
	call	printf_
	pop	bc
	pop	bc
	pop	hl
	push	hl
	ld	bc,?63994
	push	bc
	ld	hl,2
	call	printf_
	pop	bc
	pop	bc
	ld	hl,65535
	call	exit_
	ret
;}

?63993:
	db	85,110,107,110,111,119,110,32,107,101
	db	121,119,111,114,100,0
?63992:
	db	84,111,111,32,108,111,110,103,32,112
	db	97,114,97,109,101,116,101,114,0
;{
get_string_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	hl
	push	de
	push	bc
	ld	(ix-4),e
	ld	(ix-3),d
	ld	(ix-6),c
	ld	(ix-5),b
	ld	(ix-2),l
	ld	(ix-1),h
	ld	bc,0
	push	hl
@16:
	ld	l,c
	ld	h,b
	call	?cpshd
	jp	nc,@15
	ld	l,(ix-2)
	ld	h,(ix-1)
	add	hl,bc
	ld	(hl),32
	inc	bc
	jp	@16
@15:
	ld	hl,(pt_)
	ld	a,(hl)
	pop	bc
	cp	34
	jp	z,@17
	ld	hl,?63993
	call	errm_
	ld	hl,65535
	jp	@18
@17:
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	ld	de,0
@21:
	ld	hl,(pt_)
	ld	a,(hl)
	cp	34
	jp	nz,@19
	push	de
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	call	sskip_
	ld	l,(ix-6)
	ld	h,(ix-5)
	pop	de
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,0
	jp	@18
@19:
	inc	de
	ld	l,(ix-4)
	ld	h,(ix-3)
	call	?cpshd
	jp	nc,@20
	ld	hl,?63992
	call	errm_
	ld	hl,65535
	jp	@18
@20:
	ld	hl,(pt_)
	ld	a,(hl)
	ld	(bc),a
	inc	bc
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	jp	@21
@18:
	ld	sp,ix
	pop	ix
	ret
;}

;{
dec_n_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	ld	hl,0
	ld	(ix-2),l
	ld	(ix-1),h
@23:
	push	hl
	ld	hl,(pt_)
	ld	a,(hl)
	call	isdigit_
	pop	hl
	or	a
	jp	z,@22
	ld	hl,(pt_)
	ld	e,(hl)
	ld	d,0
	ld	l,(ix-2)
	ld	h,(ix-1)
	add	hl,hl
	ld	c,l
	ld	b,h
	add	hl,hl
	add	hl,hl
	add	hl,bc
	add	hl,de
	ld	bc,65488
	add	hl,bc
	ld	(ix-2),l
	ld	(ix-1),h
	push	hl
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	pop	hl
	jp	@23
@22:
	ld	sp,ix
	pop	ix
	ret
;}

;{
hex_n_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	ld	hl,0
	ld	(ix-2),l
	ld	(ix-1),h
@27:
	push	hl
	ld	hl,(pt_)
	ld	a,(hl)
	call	isxdigit_
	pop	hl
	or	a
	jp	z,@24
	ld	hl,(pt_)
	ld	a,(hl)
	call	isdigit_
	or	a
	jp	z,@25
	ld	hl,(pt_)
	ld	c,(hl)
	ld	b,0
	ld	l,(ix-2)
	ld	h,(ix-1)
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,65488
	add	hl,bc
	ld	(ix-2),l
	ld	(ix-1),h
	jp	@26
@25:
	ld	hl,(pt_)
	ld	a,(hl)
	call	toupper_
	ld	c,a
	ld	b,0
	ld	l,(ix-2)
	ld	h,(ix-1)
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,bc
	ld	bc,65481
	add	hl,bc
	ld	(ix-2),l
	ld	(ix-1),h
@26:
	push	hl
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	pop	hl
	jp	@27
@24:
	ld	sp,ix
	pop	ix
	ret
;}

?63991:
	db	73,108,108,101,103,97,108,32,110,117
	db	109,98,101,114,0
;{
num_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	hl
	ld	(ix-2),l
	ld	(ix-1),h
	push	hl
	ld	hl,(pt_)
	ld	a,(hl)
	call	isdigit_
	pop	hl
	or	a
	jp	z,@28
	push	hl
	call	dec_n_
	ex	de,hl
	pop	hl
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,0
	jp	@29
@28:
	ld	hl,(pt_)
	ld	a,(hl)
	cp	35
	jp	nz,@30
	ld	hl,(pt_)
	inc	hl
	ld	(pt_),hl
	ld	hl,(pt_)
	ld	a,(hl)
	call	isxdigit_
	or	a
	jp	z,@30
	call	hex_n_
	ex	de,hl
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	(hl),e
	inc	hl
	ld	(hl),d
	ld	hl,0
	jp	@29
@30:
	ld	hl,?63991
	call	errm_
	ld	hl,65535
@29:
	ld	sp,ix
	pop	ix
	ret
;}

?63990:
	db	69,82,82,79,82,32,40,76,105,110
	db	101,61,37,48,51,117,44,32,70,105
	db	108,101,61,34,37,115,34,41,10,0
?63989:
	db	70,73,76,69,32,69,82,82,79,82
	db	0
?63988:
	db	66,105,110,97,114,121,32,102,105,108
	db	101,32,108,111,110,103,101,114,32,116
	db	104,101,110,32,54,53,53,51,54,32
	db	98,121,116,101,115,0
?63987:
	db	66,105,110,97,114,121,32,102,105,108
	db	101,32,104,97,115,32,122,101,114,111
	db	32,108,101,110,103,116,104,0
?63986:
	db	73,108,108,101,103,97,108,32,99,104
	db	101,99,107,115,117,109,32,105,110,32
	db	104,101,97,100,101,114,32,111,102,32
	db	104,111,98,101,116,97,0
?63985:
	db	79,117,116,32,111,102,32,109,101,109
	db	111,114,121,0
;{
load_file_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	hl
	ld	hl,65516
	add	hl,sp
	ld	sp,hl
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	de,2
	push	hl
	ld	hl,Fname_
	call	open_
	ld	(HI_),hl
	ld	hl,(HI_)
	ld	a,l
	and	h
	inc	a
	jp	nz,@31
	ld	bc,Fname_
	push	bc
	ld	hl,(Line_)
	push	hl
	ld	bc,?63990
	push	bc
	ld	hl,3
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	ld	hl,?63989
	call	perror_
	ld	hl,65535
	call	exit_
@31:
	pop	hl
	ld	a,l
	or	h
	jp	nz,@32
	ld	hl,(HI_)
	call	filelength_
	ld	(flenStruct_),hl
	ld	hl,(flenStruct_)
	inc	hl
	inc	hl
	ld	a,(hl)
	sub	1
	inc	hl
	ld	a,(hl)
	sbc	a,0
	jp	c,@33
	ld	hl,?63988
	call	errex_
@33:
	ld	hl,(flenStruct_)
	inc	hl
	inc	hl
	ld	a,(hl)
	inc	hl
	or	(hl)
	jp	nz,@34
	ld	hl,(flenStruct_)
	ld	a,(hl)
	inc	hl
	or	(hl)
	jp	nz,@34
	ld	hl,?63987
	call	errex_
@34:
	ld	hl,(flenStruct_)
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	ld	(flen_),hl
	ld	hl,(flen_)
	ld	l,h
	ld	h,0
	ld	(blk_),hl
	ld	hl,(flen_)
	ld	h,0
	ld	a,l
	sub	1
	ld	a,h
	sbc	a,0
	jp	c,@35
	ld	hl,(blk_)
	inc	hl
	ld	(blk_),hl
	jp	@35
@32:
	ld	bc,17
	ld	hl,0
	add	hl,sp
	ex	de,hl
	ld	hl,(HI_)
	call	read_
	ld	de,0
@37:
	ld	a,e
	sub	8
	ld	a,d
	sbc	a,0
	jp	nc,@36
	ld	hl,0
	add	hl,sp
	add	hl,de
	ld	a,(hl)
	ld	hl,TRDOSname_
	add	hl,de
	ld	(hl),a
	inc	de
	jp	@37
@36:
	ld	hl,8
	add	hl,sp
	ld	a,(hl)
	ld	(ftyp_),a
	ld	hl,10
	add	hl,sp
	ld	b,(hl)
	ld	c,0
	ld	hl,9
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	add	hl,bc
	ld	(fstart_),hl
	ld	hl,12
	add	hl,sp
	ld	b,(hl)
	ld	c,0
	ld	hl,11
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	add	hl,bc
	ld	(flen_),hl
	ld	hl,14
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	ld	(blk_),hl
	ld	hl,16
	add	hl,sp
	ld	b,(hl)
	ld	c,0
	ld	hl,15
	add	hl,sp
	ld	l,(hl)
	ld	h,0
	add	hl,bc
	ld	de,0
	push	hl
	ld	hl,0
@39:
	ld	a,e
	sub	15
	ld	a,d
	sbc	a,0
	jp	nc,@38
	push	hl
	ld	hl,4
	add	hl,sp
	add	hl,de
	ld	l,(hl)
	ld	h,0
	ld	c,l
	ld	b,h
	ld	h,l
	ld	l,0
	add	hl,bc
	add	hl,de
	pop	bc
	add	hl,bc
	inc	de
	jp	@39
@38:
	pop	de
	ld	a,l
	cp	e
	jr	nz,$+4
	ld	a,h
	cp	d
	jp	z,@35
	ld	hl,?63986
	call	errex_
@35:
	ld	hl,(PASS_N_)
	ld	a,l
	or	h
	jp	z,@40
	ld	hl,4096
	call	malloc_
	ld	(ix-5),l
	ld	(ix-4),h
	ld	a,l
	or	h
	jp	nz,@41
	ld	hl,?63985
	call	errex_
@41:
	ld	l,(ix-5)
	ld	h,(ix-4)
	ld	e,l
	ld	d,h
	push	hl
	ld	bc,4096
	ld	hl,(HI_)
	call	read_
	pop	de
	ld	a,l
	sub	1
	ld	a,h
	sbc	a,0
	jp	c,@42
	ld	c,l
	ld	b,h
	ld	hl,(HO_)
	call	write_
	jp	@41
@42:
	ex	de,hl
	call	free_
@40:
	ld	hl,(HI_)
	call	close_
	ld	hl,0
	ld	sp,ix
	pop	ix
	ret
;}

;{
tr_sec_:
	ld	de,16
	push	hl
	call	?dvihd
	ld	(_tr_),hl
	pop	hl
	ld	de,16
	call	?dvihd
	ex	de,hl
	ld	(_sec_),hl
	ret
;}

?63984:
	db	83,116,97,110,100,97,114,116,32,46
	db	84,82,68,32,109,111,114,101,32,116
	db	104,97,110,32,54,53,53,51,54,48
	db	32,98,121,116,101,115,32,33,0
?63983:
	db	69,120,116,101,110,100,101,100,32,46
	db	84,82,68,32,109,111,114,101,32,116
	db	104,97,110,32,50,48,56,56,57,54
	db	48,32,98,121,116,101,115,32,33,0
?63982:
	db	91,37,99,37,48,51,117,93,32,78
	db	97,109,101,61,34,37,115,37,99,34
	db	32,76,101,110,61,37,48,53,117,32
	db	83,116,97,114,116,61,37,48,53,117
	db	32,66,108,107,61,37,48,51,117,32
	db	84,114,107,61,37,48,51,117,32,83
	db	101,99,61,37,48,50,117,10,0
;{
putFAT_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	af
	ld	hl,(Nfile_)
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	bc,tr0_
	add	hl,bc
	push	af
	push	hl
	ld	hl,(asec_)
	call	tr_sec_
	pop	hl
	ld	de,TRDOSname_
	push	hl
	call	strcpy_
	pop	de
	ld	hl,8
	add	hl,de
	ld	a,(ftyp_)
	ld	(hl),a
	ld	hl,(fstart_)
	ld	a,l
	ld	hl,9
	add	hl,de
	ld	(hl),a
	ld	hl,(fstart_)
	ld	a,h
	ld	hl,10
	add	hl,de
	ld	(hl),a
	ld	hl,(flen_)
	ld	a,l
	ld	hl,11
	add	hl,de
	ld	(hl),a
	ld	hl,(flen_)
	ld	a,h
	ld	hl,12
	add	hl,de
	ld	(hl),a
	ld	hl,(blk_)
	ld	a,l
	ld	hl,13
	add	hl,de
	ld	(hl),a
	ld	hl,(_sec_)
	ld	a,l
	ld	hl,14
	add	hl,de
	ld	(hl),a
	ld	hl,(_tr_)
	ld	a,l
	ld	hl,15
	add	hl,de
	ld	(hl),a
	ld	hl,(blk_)
	ex	de,hl
	ld	hl,(asec_)
	add	hl,de
	ld	(asec_),hl
	ld	hl,(TRUNC_)
	ld	a,l
	or	h
	jp	z,@43
	ld	hl,255
	jp	@44
@43:
	ld	hl,80
@44:
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ex	de,hl
	ld	hl,(asec_)
	call	?cpshd
	jp	c,@45
	ld	hl,(TRUNC_)
	ld	a,l
	or	h
	jp	nz,@46
	ld	hl,?63984
	call	errex_
	jp	@45
@46:
	ld	hl,?63983
	call	errex_
@45:
	ld	hl,(Nfile_)
	inc	hl
	ld	(Nfile_),hl
	ld	hl,(PASS_N_)
	pop	bc
	ld	c,b
	ld	a,l
	or	h
	jp	z,@47
	ld	(ix-1),c
	ld	hl,(_sec_)
	push	hl
	ld	hl,(_tr_)
	push	hl
	ld	hl,(blk_)
	push	hl
	ld	hl,(fstart_)
	push	hl
	ld	hl,(flen_)
	push	hl
	ld	a,(ftyp_)
	ld	c,a
	push	bc
	ld	bc,TRDOSname_
	push	bc
	ld	hl,(Nfile_)
	push	hl
	ld	c,(ix-1)
	push	bc
	ld	bc,?63982
	push	bc
	ld	hl,10
	call	printf_
	ex	de,hl
	ld	hl,20
	add	hl,sp
	ld	sp,hl
	ex	de,hl
@47:
	ld	sp,ix
	pop	ix
	ret
;}

;{
get_default_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	push	bc
	push	bc
	ld	hl,Fname_
	ld	(ix-2),l
	ld	(ix-1),h
	call	strlen_
	ex	de,hl
	ld	(ix-8),e
	ld	(ix-7),d
@49:
	ld	hl,0
	call	?cpshd
	jp	nc,@48
	dec	de
	ld	(ix-8),e
	ld	(ix-7),d
	ld	l,(ix-2)
	ld	h,(ix-1)
	add	hl,de
	ld	a,(hl)
	cp	92
	jp	nz,@49
@48:
	push	de
	ld	l,(ix-2)
	ld	h,(ix-1)
	call	strlen_
	pop	de
	ld	a,l
	sub	e
	ld	c,a
	ld	a,h
	sbc	a,d
	ld	b,a
	ld	hl,0
	ld	(ix-4),l
	ld	(ix-3),h
	ld	hl,0
@55:
	ld	de,8
	call	?cpshd
	jp	nc,@50
	push	bc
	ld	(ix-6),l
	ld	(ix-5),h
	ld	c,(ix-8)
	ld	b,(ix-7)
	add	hl,bc
	ld	e,(ix-2)
	ld	d,(ix-1)
	add	hl,de
	ld	a,(hl)
	cp	46
	jp	nz,@51
	ld	hl,1
	ld	(ix-4),l
	ld	(ix-3),h
@51:
	ld	(ix-2),e
	ld	(ix-1),d
	pop	bc
	ld	e,c
	ld	d,b
	ld	l,(ix-6)
	ld	h,(ix-5)
	push	bc
	push	hl
	call	?cpshd
	jp	c,@52
	ld	hl,1
	ld	(ix-4),l
	ld	(ix-3),h
@52:
	ld	l,(ix-4)
	ld	h,(ix-3)
	ld	e,(ix-2)
	ld	d,(ix-1)
	ld	a,l
	or	h
	jp	nz,@53
	ld	l,(ix-6)
	ld	h,(ix-5)
	push	hl
	ld	c,(ix-8)
	ld	b,(ix-7)
	add	hl,bc
	add	hl,de
	ld	a,(hl)
	pop	hl
	ld	bc,TRDOSname_
	add	hl,bc
	ld	(hl),a
	jp	@54
@53:
	ld	l,(ix-6)
	ld	h,(ix-5)
	ld	bc,TRDOSname_
	add	hl,bc
	ld	(hl),32
@54:
	pop	hl
	inc	hl
	pop	bc
	jp	@55
@50:
	ld	a,67
	ld	(ftyp_),a
	ld	hl,0
	ld	(fstart_),hl
	ld	sp,ix
	pop	ix
	ret
;}

?63981:
	db	68,101,115,99,114,105,112,116,111,114
	db	32,109,117,115,116,32,104,97,118,101
	db	32,84,82,76,32,101,120,116,101,110
	db	116,105,111,110,0
;{
set_TRD_name_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	ld	hl,LISTname_
	ld	(ix-2),l
	ld	(ix-1),h
	push	hl
	call	strlen_
	ex	de,hl
	ld	bc,0
@57:
	ld	l,c
	ld	h,b
	call	?cpshd
	jp	nc,@56
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	(ix-2),l
	ld	(ix-1),h
	add	hl,bc
	ld	a,(hl)
	ld	(ix-4),c
	ld	(ix-3),b
	push	de
	call	tolower_
	ld	l,(ix-2)
	ld	h,(ix-1)
	ld	c,(ix-4)
	ld	b,(ix-3)
	add	hl,bc
	ld	(hl),a
	inc	bc
	pop	de
	jp	@57
@56:
	ld	c,e
	ld	b,d
	ld	hl,65533
	add	hl,bc
	pop	de
	add	hl,de
	ld	a,(hl)
	push	bc
	cp	116
	jp	nz,@58
	ld	hl,65534
	add	hl,bc
	add	hl,de
	ld	a,(hl)
	cp	114
	jp	nz,@58
	ld	hl,65535
	add	hl,bc
	add	hl,de
	ld	a,(hl)
	cp	108
	jp	z,@59
@58:
	ld	hl,?63981
	call	errm_
	ld	hl,65535
	call	exit_
@59:
	ld	de,LISTname_
	ld	hl,TRDname_
	call	strcpy_
	pop	bc
	ld	hl,TRDname_-1
	add	hl,bc
	ld	(hl),100
	ld	sp,ix
	pop	ix
	ret
;}

?63980:
	db	73,108,108,101,103,97,108,32,116,121
	db	112,101,32,111,102,32,84,82,45,68
	db	79,83,32,102,105,108,101,0
;{
get_TYP_:
	call	skip_comma_
	or	a
	jp	nz,@60
	ld	hl,(pt_)
	ld	a,(hl)
	cp	44
	jp	nz,@61
	ld	hl,0
	ret
@61:
	ld	bc,nnn_
	ld	de,1
	ld	hl,ftyp_
	call	get_string_
	ld	a,l
	or	h
	jp	nz,@60
	ld	hl,0
	ret
@60:
	ld	hl,?63980
	call	errex_
	ld	hl,65535
	ret
;}

?63979:
	db	78,97,109,101,32,111,102,32,102,105
	db	108,101,32,101,120,112,101,99,116,101
	db	100,0
?63978:
	db	69,114,114,111,114,32,105,110,32,110
	db	97,109,101,32,111,102,32,102,105,108
	db	101,0
;{
get_MSDOSname_:
	ld	hl,(pt_)
	ld	a,(hl)
	cp	33
	jp	c,@62
	ld	hl,(pt_)
	ld	a,(hl)
	cp	59
	jp	nz,@63
@62:
	ld	hl,?63979
	call	errex_
@63:
	ld	bc,nnn_
	ld	de,79
	ld	hl,Fname_
	call	get_string_
	ld	a,l
	or	h
	jp	z,@64
	ld	hl,?63978
	call	errex_
@64:
	ld	hl,(nnn_)
	ld	bc,Fname_
	add	hl,bc
	ld	(hl),0
	ld	hl,0
	ret
;}

?63977:
	db	69,114,114,111,114,32,105,110,32,110
	db	97,109,101,32,111,102,32,84,82,68
	db	79,83,32,102,105,108,101,0
;{
get_TRDOSname_:
	call	skip_comma_
	or	a
	jp	nz,@65
	ld	hl,(pt_)
	ld	a,(hl)
	cp	44
	jp	nz,@66
	ld	hl,0
	ret
@66:
	ld	hl,0
@68:
	ld	de,8
	call	?cpshd
	jp	nc,@67
	push	hl
	ld	bc,TRDOSname_
	add	hl,bc
	ld	(hl),32
	pop	hl
	inc	hl
	jp	@68
@67:
	ld	bc,nnn_
	ld	de,8
	ld	hl,TRDOSname_
	call	get_string_
	ld	a,l
	or	h
	jp	nz,@65
	ld	hl,0
	ret
@65:
	ld	hl,?63977
	call	errex_
	ld	hl,65535
	ret
;}

?63976:
	db	69,114,114,111,114,32,105,110,32,60
	db	115,116,97,114,116,62,32,112,97,114
	db	97,109,101,116,101,114,0
;{
get_STRT_:
	call	skip_comma_
	or	a
	jp	nz,@69
	ld	hl,fstart_
	call	num_
	ld	a,l
	or	h
	jp	nz,@69
	ld	hl,0
	ret
@69:
	ld	hl,?63976
	call	errex_
	ld	hl,65535
	ret
;}

?63975:
	db	83,101,99,111,110,100,32,104,101,97
	db	100,101,114,32,111,102,32,100,105,115
	db	107,0
?63974:
	db	73,108,108,101,103,97,108,32,110,97
	db	109,101,32,111,102,32,84,82,68,79
	db	83,32,100,105,115,107,0
;{
d_disk_:
	push	hl
	ld	hl,(isHEAD_)
	ld	a,l
	or	h
	jp	z,@70
	ld	hl,?63975
	call	errex_
@70:
	ld	hl,(isHEAD_)
	inc	hl
	ld	(isHEAD_),hl
	pop	hl
	ld	(TRUNC_),hl
	ld	hl,(pt_)
	ld	a,(hl)
	cp	33
	jp	c,@71
	ld	hl,(pt_)
	ld	a,(hl)
	cp	59
	jp	nz,@72
@71:
	ld	hl,0
	ret
@72:
	ld	bc,nnn_
	ld	de,8
	ld	hl,sec9_+245
	call	get_string_
	ld	a,l
	or	h
	jp	z,@73
	ld	hl,?63974
	call	errex_
@73:
	ld	hl,0
	ret
;}

?63973:
	db	77,111,114,101,32,116,104,101,110,32
	db	49,50,56,32,102,105,108,101,115,0
;{
d_file_:
	ld	de,128
	push	hl
	ld	hl,(Nfile_)
	call	?cpshd
	jp	c,@74
	ld	hl,?63973
	call	errex_
@74:
	call	get_MSDOSname_
	call	get_default_
	pop	hl
	push	hl
	call	load_file_
	ld	hl,(pt_)
	ld	a,(hl)
	cp	33
	jp	c,@75
	ld	hl,(pt_)
	ld	a,(hl)
	cp	59
	jp	z,@75
	call	get_TRDOSname_
@75:
	ld	hl,(pt_)
	ld	a,(hl)
	cp	33
	jp	c,@76
	ld	hl,(pt_)
	ld	a,(hl)
	cp	59
	jp	z,@76
	call	get_TYP_
@76:
	ld	hl,(pt_)
	ld	a,(hl)
	cp	33
	jp	c,@77
	ld	hl,(pt_)
	ld	a,(hl)
	cp	59
	jp	z,@77
	call	get_STRT_
@77:
	pop	hl
	ld	a,l
	or	h
	jp	z,@78
	ld	a,72
	jp	@79
@78:
	ld	a,66
@79:
	call	putFAT_
	ld	hl,0
	ret
;}

;{
ini_pass_:
	ld	hl,16
	ld	(asec_),hl
	ld	hl,0
	ld	(Nfile_),hl
	ld	hl,1
	ld	(Line_),hl
	ld	hl,0
	ld	(isHEAD_),hl
	ret
;}

?63972:
	db	78,79,82,77,65,76,0
?63971:
	db	69,88,84,69,78,68,69,68,0
?63970:
	db	66,73,78,65,82,89,0
?63969:
	db	72,79,66,69,84,65,0
?63968:
	db	84,82,85,78,67,65,84,69,68,0
?63967:
	db	85,110,107,110,111,119,110,32,107,101
	db	121,119,111,114,100,0
;{
com_type_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	call	sskip_
	ld	hl,(pt_)
	ld	a,(hl)
	cp	33
	jp	c,@80
	ld	hl,(pt_)
	ld	a,(hl)
	cp	59
	jp	nz,@81
@80:
	xor	a
	jp	@82
@81:
	ld	a,255
	ld	(ix-2),a
	ld	hl,(pt_)
	ld	a,(hl)
	call	toupper_
	cp	78
	jp	z,@83
	cp	69
	jp	z,@84
	cp	66
	jp	z,@85
	cp	72
	jp	z,@86
	cp	84
	jp	z,@87
	jp	@88
@83:
	ld	hl,?63972
	call	cword_
	ld	a,l
	or	h
	jp	nz,@88
	ld	a,1
	ld	(ix-2),a
	jp	@88
@84:
	ld	hl,?63971
	call	cword_
	ld	a,l
	or	h
	jp	nz,@88
	ld	a,2
	ld	(ix-2),a
	jp	@88
@85:
	ld	hl,?63970
	call	cword_
	ld	a,l
	or	h
	jp	nz,@88
	ld	a,3
	ld	(ix-2),a
	jp	@88
@86:
	ld	hl,?63969
	call	cword_
	ld	a,l
	or	h
	jp	nz,@88
	ld	a,4
	ld	(ix-2),a
	jp	@88
@87:
	ld	hl,?63968
	call	cword_
	ld	a,l
	or	h
	jp	nz,@88
	ld	a,5
	ld	(ix-2),a
@88:
	ld	a,(ix-2)
	push	af
	inc	a
	jp	nz,@89
	ld	hl,?63967
	call	errex_
@89:
	pop	af
@82:
	ld	sp,ix
	pop	ix
	ret
;}

?63966:
	db	70,105,108,101,32,111,112,101,110,32
	db	69,82,82,79,82,0
?63965:
	db	73,110,112,117,116,32,102,105,108,101
	db	58,32,37,115,32,40,37,117,32,98
	db	121,116,101,115,41,10,10,0
?63964:
	db	79,117,116,32,111,102,32,77,101,109
	db	111,114,121,33,10,0
;{
pass_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	ld	(PASS_N_),hl
	call	ini_pass_
	ld	de,2
	ld	hl,LISTname_
	call	open_
	push	hl
	ld	a,l
	and	h
	inc	a
	jp	nz,@90
	ld	hl,?63966
	call	perror_
	ld	hl,65535
	call	exit_
@90:
	pop	hl
	ld	(ix-2),l
	ld	(ix-1),h
	push	hl
	call	filelength_
	push	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	push	bc
	ld	bc,LISTname_
	push	bc
	ld	bc,?63965
	push	bc
	ld	hl,3
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	pop	hl
	push	hl
	ld	a,(hl)
	inc	hl
	ld	h,(hl)
	ld	l,a
	inc	hl
	inc	hl
	call	malloc_
	ld	(pt_),hl
	ld	(ppt_),hl
	ld	hl,(ppt_)
	ld	a,l
	or	h
	jp	nz,@91
	ld	bc,?63964
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	hl,65535
	call	exit_
@91:
	pop	hl
	push	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(ppt_)
	ex	de,hl
	ld	l,(ix-2)
	ld	h,(ix-1)
	call	read_
	pop	hl
	push	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(ppt_)
	add	hl,bc
	ld	(hl),10
	pop	hl
	ld	c,(hl)
	inc	hl
	ld	b,(hl)
	ld	hl,(ppt_)
	add	hl,bc
	inc	hl
	ld	(hl),0
	pop	hl
	call	close_
@101:
	ld	hl,(pt_)
	ld	a,(hl)
	or	a
	jp	nz,@92
	ld	hl,(ppt_)
	call	free_
	ld	hl,0
	jp	@93
@92:
	ld	hl,(pt_)
	ld	(pt_line_),hl
	call	com_type_
	or	a
	jp	z,@94
	cp	1
	jp	z,@95
	cp	2
	jp	z,@96
	cp	3
	jp	z,@97
	cp	4
	jp	z,@98
	cp	5
	jp	z,@99
	jp	@100
@95:
	ld	hl,0
	call	d_disk_
	ld	a,l
	or	h
	jp	z,@94
	ld	hl,65535
	jp	@93
@96:
	ld	hl,1
	call	d_disk_
	ld	a,l
	or	h
	jp	z,@94
	ld	hl,65535
	jp	@93
@97:
	ld	hl,0
	call	d_file_
	ld	a,l
	or	h
	jp	z,@94
	ld	hl,65535
	jp	@93
@98:
	ld	hl,1
	call	d_file_
	ld	a,l
	or	h
	jp	z,@94
	ld	hl,65535
	jp	@93
@99:
	ld	hl,1
	ld	(fTRUNC_),hl
	jp	@94
@100:
	ld	hl,65535
	jp	@93
@94:
	call	skip_end_
	ld	hl,(Line_)
	inc	hl
	ld	(Line_),hl
	jp	@101
@93:
	ld	sp,ix
	pop	ix
	ret
;}

?63963:
	db	69,114,114,111,114,32,111,102,32,100
	db	105,115,107,32,105,109,97,103,101,32
	db	109,97,107,105,110,103,10,0
?63962:
	db	37,115,32,84,82,45,68,79,83,32
	db	68,105,115,107,32,40,68,68,56,48
	db	41,32,32,76,97,98,101,108,58,32
	db	34,37,56,115,34,10,70,105,108,101
	db	115,58,32,37,117,32,32,70,114,101
	db	101,32,115,101,99,116,111,114,115,58
	db	32,37,117,9,10,10,0
?63961:
	db	69,120,116,101,110,100,101,100,0
?63960:
	db	78,111,114,109,97,108,0
;{
open_trd_:
	ld	de,13
	ld	hl,TRDname_
	call	open_
	ld	(HO_),hl
	ld	hl,(HO_)
	ld	a,l
	and	h
	inc	a
	jp	nz,@102
	ld	hl,?63963
	call	perror_
	ld	hl,65535
	ret
@102:
	ld	hl,(asec_)
	call	tr_sec_
	ld	hl,(TRUNC_)
	ld	a,l
	or	h
	jp	z,@103
	ld	hl,255
	jp	@104
@103:
	ld	hl,80
@104:
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ex	de,hl
	ld	hl,(asec_)
	ld	a,e
	sub	l
	ld	l,a
	ld	a,d
	sbc	a,h
	ld	h,a
	ld	(freesec_),hl
	ld	hl,0
@106:
	ld	de,9
	call	?cpshd
	jp	nc,@105
	push	hl
	ld	bc,sec9_+234
	add	hl,bc
	ld	(hl),32
	pop	hl
	inc	hl
	jp	@106
@105:
	ld	hl,(_sec_)
	ld	a,l
	ld	(sec9_+225),a
	ld	hl,(_tr_)
	ld	a,l
	ld	(sec9_+226),a
	ld	a,22
	ld	(sec9_+227),a
	ld	hl,(Nfile_)
	ld	a,l
	ld	(sec9_+228),a
	ld	hl,(freesec_)
	ld	de,256
	call	?dvihd
	ld	a,e
	ld	(sec9_+229),a
	ld	hl,(freesec_)
	ld	de,256
	call	?dvihd
	ld	a,l
	ld	(sec9_+230),a
	ld	a,16
	ld	(sec9_+231),a
	xor	a
	ld	(sec9_+244),a
	ld	bc,2048
	ld	de,tr0_
	ld	hl,(HO_)
	call	write_
	ld	bc,256
	ld	de,sec9_
	ld	hl,(HO_)
	call	write_
	ld	hl,0
@108:
	ld	de,2048
	call	?cpshd
	jp	nc,@107
	push	hl
	ld	bc,tr0_
	add	hl,bc
	ld	(hl),221
	pop	hl
	inc	hl
	jp	@108
@107:
	ld	bc,1792
	ld	de,tr0_
	ld	hl,(HO_)
	call	write_
	ld	hl,(freesec_)
	push	hl
	ld	hl,(Nfile_)
	push	hl
	ld	bc,sec9_+245
	push	bc
	ld	hl,(TRUNC_)
	ld	a,l
	or	h
	jp	z,@109
	ld	hl,?63961
	jp	@110
@109:
	ld	hl,?63960
@110:
	push	hl
	ld	bc,?63962
	push	bc
	ld	hl,5
	call	printf_
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	pop	bc
	ld	hl,0
	ret
;}

;{
close_trd_:
	push	ix
	ld	ix,0
	add	ix,sp
	push	bc
	push	bc
	ld	hl,(TRUNC_)
	ld	a,l
	or	h
	jp	nz,@111
	ld	hl,16
	ld	(ix-4),l
	ld	(ix-3),h
	ld	hl,4096
	call	malloc_
	ld	(ix-2),l
	ld	(ix-1),h
	ld	de,0
@113:
	ld	a,d
	cp	16
	jp	nc,@112
	push	hl
	add	hl,de
	ld	(hl),207
	inc	de
	pop	hl
	jp	@113
@112:
	push	hl
	ld	hl,(fTRUNC_)
	ld	a,l
	or	h
	jp	nz,@114
	ld	de,2560
	ld	hl,(asec_)
	call	?cpshd
	jp	nc,@114
	ld	hl,(asec_)
	ld	bc,2560
	ld	a,c
	sub	l
	ld	c,a
	ld	a,b
	sbc	a,h
	ld	b,a
@116:
	ld	l,(ix-4)
	ld	h,(ix-3)
	ld	a,l
	sub	c
	ld	a,h
	sbc	a,b
	jp	nc,@115
	push	hl
	push	bc
	ld	l,(ix-2)
	ld	h,(ix-1)
	ex	de,hl
	ld	bc,4096
	ld	hl,(HO_)
	call	write_
	pop	bc
	pop	hl
	ld	a,c
	sub	l
	ld	c,a
	ld	a,b
	sbc	a,h
	ld	b,a
	jp	@116
@115:
	ld	a,c
	sub	1
	ld	a,b
	sbc	a,0
	jp	c,@114
	ld	b,c
	ld	c,0
	ld	l,(ix-2)
	ld	h,(ix-1)
	ex	de,hl
	ld	hl,(HO_)
	call	write_
@114:
	pop	hl
	call	free_
@111:
	ld	hl,(HO_)
	call	close_
	ld	hl,0
	ld	sp,ix
	pop	ix
	ret
;}

;{
bin2trd_:
	ld	hl,0
	call	pass_
	ld	a,l
	or	h
	jp	z,@117
	ld	hl,65535
	ret
@117:
	call	open_trd_
	ld	a,l
	or	h
	jp	z,@118
	ld	hl,65535
	ret
@118:
	ld	hl,1
	call	pass_
	ld	a,l
	or	h
	jp	z,@119
	ld	hl,65535
	ret
@119:
	call	close_trd_
	ld	a,l
	or	h
	jp	z,@120
	ld	hl,65535
	ret
@120:
	ld	hl,0
	ret
;}

?63959:
	db	10,77,97,107,105,110,103,32,84,82
	db	68,32,102,105,108,101,32,102,114,111
	db	109,32,98,105,110,97,114,105,101,115
	db	32,111,114,47,97,110,100,32,104,111
	db	98,101,116,97,32,102,105,108,101,115
	db	32,40,118,49,46,48,46,50,48,50
	db	49,41,0
?63958:
	db	10,40,99,41,32,49,57,57,57,32
	db	32,67,111,112,112,101,114,32,70,101
	db	101,116,32,40,86,121,97,99,104,101
	db	115,108,97,118,32,77,101,100,110,111
	db	110,111,103,111,118,41,0
?63957:
	db	10,32,32,32,32,50,48,48,50,32
	db	32,77,111,100,105,102,105,99,97,116
	db	105,111,110,32,98,121,32,65,108,101
	db	120,97,110,100,101,114,32,83,104,97
	db	98,97,114,115,104,105,110,32,60,109
	db	101,64,115,104,97,111,115,46,110,101
	db	116,62,0
?63956:
	db	10,32,32,32,32,50,48,50,49,32
	db	32,83,112,114,105,110,116,101,114,32
	db	118,101,114,115,105,111,110,32,98,121
	db	32,68,109,105,116,114,121,32,77,105
	db	107,104,97,108,116,99,104,101,110,107
	db	111,118,32,60,109,105,107,104,97,108
	db	116,99,104,101,110,107,111,118,64,103
	db	109,97,105,108,46,99,111,109,62,10
	db	10,0
?63955:
	db	32,32,32,85,115,97,103,101,58,10
	db	9,98,105,110,50,116,114,100,32,60
	db	102,105,108,101,110,97,109,101,62,46
	db	116,114,108,10,10,0
?63954:
	db	110,111,110,97,109,101,100,32,0
?63953:
	db	10,84,82,68,32,102,105,108,101,32
	db	119,97,115,32,116,114,117,110,99,97
	db	116,101,100,10,0
?63952:
	db	10,79,107,33,10,10,0
;{
main_:
	ld	bc,?63959
	push	de
	push	hl
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	bc,?63958
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	bc,?63957
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	bc,?63956
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	pop	hl
	pop	de
	ld	a,l
	dec	a
	or	h
	jp	nz,@121
	ld	bc,?63955
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
	ld	hl,65535
	ret
@121:
	ld	hl,2
	add	hl,de
	ld	e,(hl)
	inc	hl
	ld	d,(hl)
	ld	hl,LISTname_
	call	strcpy_
	ld	de,?63954
	ld	hl,sec9_+245
	call	strcpy_
	call	set_TRD_name_
	call	ini_cright_
	call	bin2trd_
	push	hl
	ld	hl,(fTRUNC_)
	ld	a,l
	or	h
	jp	z,@122
	ld	bc,?63953
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
@122:
	pop	hl
	push	hl
	ld	a,l
	or	h
	jp	nz,@123
	ld	bc,?63952
	push	bc
	ld	hl,1
	call	printf_
	pop	bc
@123:
	pop	hl
	ret
;}


	public	errno_
	public	HO_
	public	HI_
	public	Fname_
	public	LISTname_
	public	TRDname_
	public	tr0_
	public	sec9_
	public	pt_
	public	ppt_
	public	pt_line_
	public	TRDOSname_
	public	ftyp_
	public	fstart_
	public	blk_
	public	flenStruct_
	public	flen_
	public	_tr_
	public	_sec_
	public	asec_
	public	Nfile_
	public	freesec_
	public	Line_
	public	TRUNC_
	public	PASS_N_
	public	isHEAD_
	public	nnn_
	public	fTRUNC_
	public	filelength_
	extrn	lseek_
	extrn	seek_
	public	ini_cright_
	extrn	?cpshd
	public	sskip_
	public	skip_end_
	public	skip_comma_
	public	cword_
	extrn	strlen_
	extrn	toupper_
	public	errm_
	extrn	printf_
	public	errex_
	extrn	exit_
	public	get_string_
	public	dec_n_
	extrn	isdigit_
	public	hex_n_
	extrn	isxdigit_
	public	num_
	public	load_file_
	extrn	open_
	extrn	perror_
	extrn	read_
	extrn	malloc_
	extrn	write_
	extrn	free_
	extrn	close_
	public	tr_sec_
	extrn	?dvihd
	public	putFAT_
	extrn	strcpy_
	public	get_default_
	public	set_TRD_name_
	extrn	tolower_
	public	get_TYP_
	public	get_MSDOSname_
	public	get_TRDOSname_
	public	get_STRT_
	public	d_disk_
	public	d_file_
	public	ini_pass_
	public	com_type_
	public	pass_
	public	open_trd_
	public	close_trd_
	public	bin2trd_
	public	main_

	end
