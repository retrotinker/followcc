*
* Copyright (c) 2013, John W. Linville <linville@tuxdriver.com>
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

	NAM	Follow Me
	TTL	Simon-like game using a rotary controller

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
VIDLINE	equ	$20
VIDSIZE	equ	$0200

SQWAVE	equ	$02

SPINP1	equ	$01
SPINP2	equ	$02

WHITE	equ	$cf
BLACK	equ	$80

MVCINIT	equ	$40
MVCDLTA	equ	$0a
MVCTMIN	equ	MVCINIT-MVCDLTA
MVCTMAX	equ	MVCINIT+MVCDLTA

TONEDLY	equ	$19ca
PAUSDLY	equ	$0312

	org	LOAD

EXEC	equ	*
* Set direct page register
	lda	#$ff
	tfr	a,dp
	setdp	$ff

* Disable IRQ and FIRQ
	orcc	#$50

* Init spinner control variables
	clr	SPNSTAT
	clr	SPNHIST
	clr	SPNHIST+1
	clr	SPNHIST+2

	lbsr	SPNREAD		Read current spinner values
	stb	SPNSTAT		Pre-load spinner state

* Init other variables
	clr	CURBOX
	clr	BTNLAST
	lda	#MVCINIT
	sta	MOVCNTR

* Init timing sources
	lda	$ff03		Disable vsync interrupt generation
	anda	#$fe
	sta	$ff03
	tst	$ff02

	lda	$ff01		Enable hsync interrupt generation
	ora	#$01
	sta	$ff01

* Init audio output
	lda	PIA1C1		Enable square wave audio output
	anda	#$fb
	sta	PIA1C1
	ldb	#SQWAVE
	orb	PIA1D1
	stb	PIA1D1
	ora	#$04
	sta	PIA1C1

* Clear the screen
	lbsr	CLRSCN

* Draw the pretty boxes...
	ldy	#BXLOCAT
	ldx	0,y
	ldy	#BXCOLOR
	lda	0,y
	lbsr	DRAWBOX

	ldy	#BXLOCAT
	ldx	2,y
	ldy	#BXCOLOR
	lda	1,y
	lbsr	DRAWBOX

	ldy	#BXLOCAT
	ldx	4,y
	ldy	#BXCOLOR
	lda	2,y
	lbsr	DRAWBOX

	ldy	#BXLOCAT
	ldx	6,y
	ldy	#BXCOLOR
	lda	3,y
	lbsr	DRAWBOX

* Wait for button press/release to start game
STRTWAI	lda	PIA0D0		Test the joystick button...
	bita	#$02
	bne	STRTWAI
STRTWA2	lda	PIA0D0		Test the joystick button...
	bita	#$02
	beq	STRTWA2

	lbsr	SEQPLAY

* Draw initial selection outline
	lda	CURBOX
	lbsr	SELECT

LOOP	tst	$ff00		Synchronize to sample frequency
	sync
	tst	$ff00
	sync
	tst	$ff00
	sync
	tst	$ff00
	sync

	bsr	BTNREAD

	lbsr	SPNDBNC

	lda	#MVCTMIN
	cmpa	MOVCNTR
	bgt	LMOV_CW
	lda	#MVCTMAX
	cmpa	MOVCNTR
	ble	LMOVCCW

	bra	LOOPEX

LMOV_CW	lda	CURBOX
	lbsr	DSELECT
	lda	CURBOX
	inca
	anda	#$03
	sta	CURBOX
	lbsr	SELECT

	lda	#MVCINIT
	sta	MOVCNTR

	bra	LOOPEX

LMOVCCW	lda	CURBOX
	lbsr	DSELECT
	lda	CURBOX
	deca
	anda	#$03
	sta	CURBOX
	lbsr	SELECT

	lda	#MVCINIT
	sta	MOVCNTR

*	bra	LOOPEX

LOOPEX	bra	CHKUART

* Check for user break (development only)
CHKUART	lda	$ff69		Check for serial port activity
	bita	#$08
	beq	LOOP
	lda	$ff68

*EXIT	jmp	$c135		Re-enter monitor (works on CoCo3?)
EXIT	jmp	[$fffe]		Re-enter monitor

*
* Test the button status and react to changes
*
*	X,A,B get clobbered
*
BTNREAD	lda	PIA0D0		Test the joystick button...
	bita	#$02
	bne	BTNEXIT

	lda	CURBOX		Select box to highlight...
	lbsr	HILIGHT		Indicate button was pressed...

	ldx	#BXDELAY	Set freq counter
	lda	CURBOX
	ldb	a,x
	pshs	b

BTNPLAY	sync			Wait for next hsync clock...
	lda	PIA0D0		Clear hsync indicator...
	decb			Decrement freq counter
	bne	BTNPLAY

BTNSND	lda	PIA1D1		Toggle square wave output...
	eora	#SQWAVE
	sta	PIA1D1

	ldb	,s		Reset freq counter

	lda	PIA0D0		Check for button release...
	bita	#$02
	beq	BTNPLAY

	leas	1,s		Clean-up stack...
	lda	CURBOX
	lbsr	SELECT		Indicate button no longer pressed...

	lda	#MVCINIT	Reset movement counter
	sta	MOVCNTR

BTNEXIT	rts

*
* Debounce the spinner, accumulate left/right movement
*
*	Y,A,B get clobbered
*
SPNDBNC	ldd	SPNHIST		Shift historical spinner data
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

	lda	SPNSTAT		Read old spinner status
	stb	SPNSTAT		Save new spinner status

	lsla			Prepare vector by combining old and new status
	lsla
	ora	SPNSTAT
	lsla
	ldy	#SPNDBCK
	jmp	a,y		Choose proper action for current state

SPNDBCK	bra	SPNDBEX		00 -> 00 : No change, exit
	bra	SPNM_CW		00 -> 01 : Record state change
	bra	SPNMCCW		00 -> 10 : Record state change
	bra	SPNDBAD		00 -> 11 : Invalid state change!
	bra	SPNMCCW		01 -> 00 : Record state change
	bra	SPNDBEX		01 -> 01 : No change, exit
	bra	SPNDBAD		01 -> 10 : Invalid state change!
	bra	SPNM_CW		01 -> 11 : Record state change
	bra	SPNM_CW		10 -> 00 : Record state change
	bra	SPNDBAD		10 -> 01 : Invalid state change!
	bra	SPNDBEX		10 -> 10 : No change, exit
	bra	SPNMCCW		10 -> 11 : Record state change
	bra	SPNDBAD		11 -> 00 : Invalid state change!
	bra	SPNMCCW		11 -> 01 : Record state change
	bra	SPNM_CW		11 -> 10 : Record state change
	bra	SPNDBEX		11 -> 11 : No change, exit

SPNM_CW	dec	MOVCNTR
	bra	SPNDBEX

SPNMCCW	inc	MOVCNTR
	bra	SPNDBEX

SPNDBAD	equ	*
SPNDBEX	rts

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

*
* Play sequence of tones
*
*	X,A get clobbered
*
*
SEQPLAY	lda	TONELEN		Get current sequence length
	beq	SEQPLEX		Exit if zero-length sequence
	pshs	a

	ldx	#TONESEQ

SEQLOOP	lda	,x+		Get next tone in sequence
	pshs	a,x		Save A,X since they get clobbered...
	bsr	HILIGHT		Highlight color matching this tone...
	lda	,s		Restore A from stack for input to TONEPLY
	bsr	TONEPLY		Play it!
	bsr	PAUSPLY		Pause between tones...
	lda	,s		Restore A from stack for input to DSELECT
	bsr	DSELECT		Un-highlight this color...
	puls	a,x

	dec	,s		Decrement remaining sequence length
	bne	SEQLOOP		Continue if not done

	leas	1,s		Clean-up stack

SEQPLEX	rts

*
* Timed play of selected tone
*
*	A input tone to play, clobbered
*	X,B get clobbered
*
TONEPLY	ldx	#BXDELAY	Set freq counter
	ldb	a,x
	pshs	b

	ldd	#TONEDLY	Set time counter
	pshs	d

	ldb	2,s		Reset freq counter
	lda	PIA0D0		Clear hsync indicator...
TNPLYLP	sync			Wait for next hsync clock...
	lda	PIA0D0		Clear hsync indicator...

	dec	1,s		Decrement time counter
	bne	TNPLYL1
	dec	,s
	beq	TNPLYEX

TNPLYL1	decb			Decrement freq counter
	bne	TNPLYLP

	lda	PIA1D1		Toggle square wave output...
	eora	#SQWAVE
	sta	PIA1D1

	ldb	2,s		Reset freq counter
	bra	TNPLYLP

TNPLYEX	leas	3,s		Clean-up stack
	rts

*
* Timed pause between tones
*
*	A,B get clobbered
*
PAUSPLY	ldd	#PAUSDLY	Set time counter
	pshs	d

	lda	PIA0D0		Clear hsync indicator...
PAUSLOP	sync			Wait for next hsync clock...
	lda	PIA0D0		Clear hsync indicator...

	dec	1,s		Decrement time counter
	bne	PAUSLOP
	dec	,s
	bne	PAUSLOP

	leas	2,s		Clean-up stack
	rts

*
* Outline selected box in white
*
*	A box to select, clobbered
*	X gets clobbered
*
SELECT	ldx	#BXOUTLN
	lsla
	ldx	a,x
	lda	#WHITE
	bsr	DRWOUTL
	rts

*
* Outline selected box in black
*
*	A box to deselect, clobbered
*	X gets clobbered
*
DSELECT	ldx	#BXOUTLN
	lsla
	ldx	a,x
	lda	#BLACK
	bsr	DRWOUTL
	rts

*
* Outline selected box in it's color
*
*	A box to higlight, clobbered
*	X,Y get clobbered
*
HILIGHT	ldx	#BXOUTLN
	lsla
	ldx	a,x
	ldy	#BXCOLOR
	lsra
	lda	a,y
	bsr	DRWOUTL
	rts

*
* Draw a box outline
*
*	X location for outline, clobbered
*	A character for outline
*
DRWOUTL	leas	-2,s		Pre-allocate stack variables
	sta	1,s		Save character value
	lda	#16		Init counter for top row
	sta	,s
	lda	1,s		Re-load character value
DROLOP1	sta	,x+		Store character, increment X
	dec	,s		Decrement counter
	bne	DROLOP1		If not zero, loop...
	leax	16,x		Advance cursor to next row
	lda	#6		Re-init counter for sides
	sta	,s
	lda	1,s		Re-load character value
DROLOP2	sta	,x		Store character, left side
	sta	1,x
	sta	14,x		Store character, right side
	sta	15,x		Store character, right side
	leax	32,x		Advace cursor to next row
	dec	,s		Decrement counter
	bne	DROLOP2		If not zero, loop...
	lda	#16		Re-init counter for bottom row
	sta	,s
	lda	1,s		Re-load character value
DROLOP3	sta	,x+		Store character, increment X
	dec	,s		Decrement counter
	bne	DROLOP3		If not zero, loop...
	leas	2,s		De-allocate stack variables
	rts

*
* Draw a filled box
*
*	X location for box, clobbered
*	A character for box
*
DRAWBOX	leas	-3,s		Pre-allocate stack variables
	sta	2,s		Save character value
	lda	#6		Init row counter
	sta	1,s
	lda	#12		Init column counter
	sta	,s
	lda	2,s		Re-load character value
DRBLOOP	sta	,x+		Store character, increment X
	dec	,s		Decrement column counter
	bne	DRBLOOP		If not zero, loop...
	lda	#12		Reset column counter
	sta	,s
	lda	2,s		Re-load character value
	leax	20,x		Advance cursor to next row start
	dec	1,s		Decrement row counter
	bne	DRBLOOP		If not zero, loop...
	leas	3,s		De-allocate stack variables
	rts

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

BXLOCAT	fdb	VIDBASE+VIDLINE+2
	fdb	VIDBASE+VIDLINE+VIDLINE/2+2
	fdb	VIDBASE+VIDSIZE/2+VIDLINE+VIDLINE/2+2
	fdb	VIDBASE+VIDSIZE/2+VIDLINE+2

BXOUTLN	fdb	VIDBASE
	fdb	VIDBASE+VIDLINE/2
	fdb	VIDBASE+VIDSIZE/2+VIDLINE/2
	fdb	VIDBASE+VIDSIZE/2

*
* Constants
*
BXCOLOR	fcb	$8f,$bf,$af,$9f

*BXDELAY	fcb	$28,$1e,$14,$18		Actual bugle notes
BXDELAY	fcb	$26,$1f,$13,$19		Original Simon appoximation

*
* Pre-allocated variables
*
SPNSTAT	rmb	1		Current spinner state value
SPNHIST	rmb	3		Historical spinner readings

BTNLAST	rmb	1		Previous button status

CURBOX	rmb	1		Currently selected box

MOVCNTR	rmb	1		Accumulated movement

TONESEQ	fcb	$03,$01,$02,$03,$00,$00,$03
TONELEN	fcb	7

	end	EXEC
