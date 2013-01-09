*
* Copyright (c) 2009-2011, John W. Linville <linville@tuxdriver.com>
*
* Permission to use, copy, modify, and/or distribute this software for any
* purpose with or without fee is hereby granted, provided that the above
* copyright notice and this permission notice appear in all copies.
*
* THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
* WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
* MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
* ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
* WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
* ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
* OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*

	NAM	CoCoSpin
	TTL	Demo code for using a rotary controller

LOAD	equ	$4000		Actual load address for binary

PIA0D0	equ	$ff00
PIA0C0	equ	$ff01
PIA0D1	equ	$ff02
PIA0C1	equ	$ff03

PIA1D0	equ	$ff20
PIA1C0	equ	$ff21
PIA1D1	equ	$ff22
PIA1C1	equ	$ff23

VIDBASE	equ	$0400
VIDSIZE	equ	$0200

SPINP1	equ	$01
SPINP2	equ	$02

	org	LOAD

EXEC	equ	*
* Set direct page register
	lda	#$ff
	tfr	a,dp
	setdp	$ff

* Disable IRQ and FIRQ
	orcc	#$50

	bsr	CLRSCN

	clr	SPNSTAT
	clr	SPNLAST

	lda	$ff03	Disable vsync interrupt generation
	anda	#$fe
	sta	$ff03
	tst	$ff02

	lda	$ff01	Enable hsync interrupt generation
	ora	#$01
	sta	$ff01

LOOP	tst	$ff00
	sync
	tst	$ff00
	sync
	tst	$ff00
	sync
	tst	$ff00
	sync

	lda	PIA0D0
	bita	#$02
	bne	LOOPRD

	bsr	CLRSCN

LOOPRD	bsr	SPNREAD

	cmpb	SPNLAST
	beq	LOOPTST

	stb	SPNLAST
	ldb	#$02
	stb	SPNLCNT
	bra	LOOPEX

LOOPTST	dec	SPNLCNT
	bne	LOOPEX

	cmpb	SPNSTAT
	beq	LOOPEX

	stb	SPNSTAT
	lslb
	lslb
	lslb
	lslb
	orb	#$8f
	stb	,x+

	cmpx	#(VIDBASE+VIDSIZE)
	blt	LOOPEX

	ldx	#VIDBASE

LOOPEX	equ	*

* Check for user break (development only)
CHKUART	lda	$ff69		Check for serial port activity
	bita	#$08
	beq	LOOP
	lda	$ff68

EXIT	jmp	[$fffe]		Re-enter monitor

* ...clear screen...
CLRSCN	ldx	#VIDBASE
	lda	#$80
CLSLOOP	sta	,x+
	cmpx	#(VIDBASE+VIDSIZE)
	bne	CLSLOOP

	ldx	#VIDBASE
	rts

*
* Read the spinner
*
*	A gets clobbered
*	B holds spinner state info
*
SPNREAD	clrb

	lda	#$35		Read the right/left axis of the left joystick
	sta	PIA0C0
	lda	#$3c
	sta	PIA0C1

SPNRDP1	lda	#$7c		Test for low value on axis
	sta	PIA1D0
	lda	PIA0D0
	bpl	SPNRDP2

	orb	#SPINP1

SPNRDP2	lda	#$3d		Read the up/down axis of the left joystick
	sta	PIA0C0
	nop			Let the comparator stabilize (2x for hi-speed?)
	nop
	nop
	nop
	lda	PIA0D0		Test value still set in PIA1D0
	bpl	SPNRDEX

	orb	#SPINP2

SPNRDEX	clr	PIA1D0
	lda	#$35
	sta	PIA0C0
	lda	#$34
	sta	PIA0C1

	rts

SPNSTAT	rmb	1
SPNLAST	rmb	1
SPNLCNT	rmb	1

	end	EXEC
