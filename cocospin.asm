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
	dec	SPNSTAT		Guarantee initial "transition"

	clr	SPNHIST
	clr	SPNHIST+1
	clr	SPNHIST+2

	lda	$ff03		Disable vsync interrupt generation
	anda	#$fe
	sta	$ff03
	tst	$ff02

	lda	$ff01		Enable hsync interrupt generation
	ora	#$01
	sta	$ff01

LOOP	tst	$ff00		Synchronize to sample frequency
	sync
	tst	$ff00
	sync
	tst	$ff00
	sync
	tst	$ff00
	sync

	lda	PIA0D0		Test the joystick button...
	bita	#$02
	bne	LOOPRD

	bsr	CLRSCN		...and clear screen if pressed

LOOPRD	ldd	SPNHIST		Shift historical spinner data
	std	SPNHIST+1

	bsr	SPNREAD		Read current spinner values
	stb	SPNHIST
	tfr	b,a

	anda	SPNHIST+1	Computer AND terms of debounce algorithm
	anda	SPNHIST+2
	pshs	a

	orb	SPNHIST+1	Computer OR terms of debounce algorithm
	orb	SPNHIST+2
	andb	SPNSTAT		AND the above w/ current reported value

	orb	,s		Combine the debounce algorithm components
	leas	1,s

	cmpb	SPNSTAT		If no change, restart the loop...
	beq	LOOPEX

	stb	SPNSTAT		Record new spinner status on the SG4 screen
	lslb
	lslb
	lslb
	lslb
	orb	#$8f
	stb	,x+

	cmpx	#(VIDBASE+VIDSIZE)
	blt	LOOPEX

	ldx	#VIDBASE	Wrap the screen output to the top, as necessary

LOOPEX	equ	*

* Check for user break (development only)
CHKUART	lda	$ff69		Check for serial port activity
	bita	#$08
	beq	LOOP
	lda	$ff68

EXIT	jmp	[$fffe]		Re-enter monitor

*
* Clear the screen
*
*	X gets set to #VIDBASE
*	A gets clobbered
*
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

	lda	#$3c		Read the right/left axis of the left joystick
	sta	PIA0C1
	lda	#$35
	sta	PIA0C0

SPNRDP1	lda	#$7c		Test for low value on axis
	sta	PIA1D0
	lda	PIA0D0
	bpl	SPNRDP2

	orb	#SPINP1		Indicate "high" on phase 1 input

SPNRDP2	lda	#$3d		Read the up/down axis of the left joystick
	sta	PIA0C0
	nop			Let the comparator stabilize (2x for hi-speed?)
	nop
	nop
	nop
	lda	PIA0D0		Test value still set in PIA1D0
	bpl	SPNRDEX

	orb	#SPINP2		Indicate "high" on phase 2 input

SPNRDEX	clr	PIA1D0		Reset selector switch inputs
	lda	#$35
	sta	PIA0C0
	lda	#$34
	sta	PIA0C1

	rts

SPNSTAT	rmb	1		Current spinner state value
SPNHIST	rmb	3		Historical spinner readings

	end	EXEC
