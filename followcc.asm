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
	TTL	Simon-like game

	ifdef	ROM
LOAD	equ	$c000		Actual load address for binary
DATA	equ	$0600		Actual base address for variables
	else
LOAD	equ	$0e00		Actual load address for binary
	endif

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

TONDLY1	equ	$19ca
TONDLY2	equ	$13a6
TONDLY3	equ	$0d82
PPLYDLY	equ	$0312
PAUSCNT	equ	$49b0

FAILDLY	equ	$5c1c
FAILSND	equ	$bb

WONDLY	equ	$013a
WONDUR	equ	$044c

WINRDLY	equ	$1eb4

MOVTIME	equ	$2000

	org	LOAD

EXEC	equ	*

	ifndef	ROM
	sts	SAVSTK
	endif

* Disable IRQ and FIRQ
	orcc	#$50

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

* TONECNT is a special case, should be initialized here...
	clr	TONECNT

* Show title screen
	jsr	TTLSCRN

	jmp	STRTNOW

* Display game start message
GAMATTR	ldx	#SMSYSTR
	ldy	#(VIDBASE+VIDSIZE/2-22)
	lda	#SMSYLEN
	lbsr	DRAWSTR

	ldx	#PRK1STR
	ldy	#(VIDBASE+VIDSIZE/2+8)
	lda	#PRK1LEN
	lbsr	DRAWSTR

	ldy	#BXLOCAT	Restore the pristinely colored boxes
	ldx	0,y
	ldy	#BXCOLOR
	lda	0,y
	sta	,x

	ldy	#BXLOCAT
	ldx	2,y
	ldy	#BXCOLOR
	lda	1,y
	sta	11,x

	ldy	#BXLOCAT
	ldx	4,y
	ldy	#BXCOLOR
	lda	2,y
	leax	96,x
	leax	64,x
	sta	11,x

	ldy	#BXLOCAT
	ldx	6,y
	ldy	#BXCOLOR
	lda	3,y
	leax	96,x
	leax	64,x
	sta	,x

* Wait for button press/release to start game
STRTWAI	lda	TONECNT		Pre-seed TONECNT
	inca
	anda	#$03
	sta	TONECNT

	jsr	[$a000]
	beq	STRTWAI		Repeat the loop
	ifndef	ROM
	cmpa	#$03
	lbeq	EXIT
	endif

* Erase game start message
STRTNOW	ldy	#(VIDBASE+VIDSIZE/2-22)
	lda	#SMSYLEN
	lbsr	DRAWBLK

	ldy	#(VIDBASE+VIDSIZE/2+8)
	lda	#PRK1LEN
	lbsr	DRAWBLK

	ldy	#BXLOCAT	Label the keys that match the boxes
	ldx	0,y
	lda	#('I'-$40)
	sta	,x

	ldx	2,y
	lda	#('O'-$40)
	sta	11,x

	ldx	4,y
	leax	96,x
	leax	64,x
	lda	#('L'-$40)
	sta	11,x

	ldx	6,y
	leax	96,x
	leax	64,x
	lda	#('K'-$40)
	sta	,x

GAMSTRT	lbsr	VARINIT

GAMLOOP	lda	RONDNUM		Count/display the current round
	inca
	daa
	sta	RONDNUM

	lda	TONELEN		Add a tone to the sequence
	inca
	cmpa	#(TONECNT-TONESEQ)	Check for completed sequence
	lbge	GAMEWON		Player wins!
	sta	TONELEN		Otherwise, save new sequence length

	pshs	a		Save sequence offset
	cmpa	#$0d		Check for shortest sequence delay
	bgt	GMSQDL3

	cmpa	#$05		Check for mid-length sequence delay
	bgt	GMSQDL2

	bra	GAMCONT

GMSQDL3	ldd	#TONDLY3	Load shortest sequence delay
	bra	GMSQDST

GMSQDL2	ldd	#TONDLY2	Load mid-length sequence delay

GMSQDST	std	TONEDLY

GAMCONT	puls	a

	ldb	TONECNT		Use the free-running count value
	ldx	#(TONESEQ-1)	Store it at the new offset in the sequence
	stb	a,x

	jsr	DISROND		Show the round counter

	jsr	PAUSDLY		Let the user see it

	jsr	CLRROND		Clear the round counter

	lbsr	SEQPLAY

	clr	TONECHK		Restart tone sequence checking

CTLLOOP	lbsr	NEXTCHK		Synchronize to sample frequency

KYBDCHK	jsr	[$a000]
	lbeq	KYBDCKX
	cmpa	#'I'
	bne	KYBDCK1

	lda	#$00
	bra	KYBDSEL

KYBDCK1	cmpa	#'O'
	bne	KYBDCK2

	lda	#$01
	bra	KYBDSEL

KYBDCK2	cmpa	#'L'
	bne	KYBDCK3

	lda	#$02
	bra	KYBDSEL

KYBDCK3	cmpa	#'K'
	ifdef	ROM
	bne	KYBDCKX
	else
	bne	KYBDCK4
	endif

	lda	#$03
	ifndef	ROM
	bra	KYBDSEL

KYBDCK4	cmpa	#$03
	bne	KYBDCKX

	jmp	EXIT
	endif

KYBDSEL
	pshs	a		LOLIGHT clobbers A
	lda	CURBOX		Deselect current box
	lbsr	LOLIGHT

	puls	a		Restore A
	sta	CURBOX		Select new box
	lbsr	HILIGHT		Indicate key was pressed...

	lda	TONECHK		Compare next tone in seq to current selection
	ldx	#TONESEQ
	ldb	CURBOX
	cmpb	a,x
	lbne	GAMEOVR		No match!  Game over...

	ldx	#BXDELAY	Set freq counter
	lda	CURBOX
	ldb	a,x
	pshs	b

KYBDSYN	lda	PIA0D0		Clear hsync indicator...
	sync			Wait for next hsync clock...
	decb			Decrement freq counter
	bne	KYBDSYN

	lda	PIA1D1		Toggle square wave output...
	eora	#SQWAVE
	sta	PIA1D1

	ldb	,s		Reset freq counter

	clr	PIA0D1		Check for key release
	lda	PIA0D0
	anda	#$7f
	cmpa	#$7f
	bne	KYBDSYN

KYBDRLS	leas	1,s		Clean-up stack...
	lda	CURBOX
	lbsr	LOLIGHT		Indicate key no longer pressed...

	ldd	#MOVTIME	Reset move timeout counter
	std	MOVTIMO

	lda	TONECHK		Increment sequence check cursor
	inca
	sta	TONECHK

	cmpa	TONELEN		Compare sequence check to sequence length
	blt	KYBDCKX		Not done, continue checking...

	lda	CURBOX		Deselect current box
	lbsr	LOLIGHT

	jmp	GAMLOOP		Now, extend sequence and continue

KYBDCKX	lda	#$ff
	sta	PIA0D1

	jmp	CTLLOOP

*
* Wait for next hsync-clocked controller check term
*	-- also check for input timeout
*
*	A gets clobbered
*	B,X get clobbered if there is a timeout
*
NEXTCHK	dec	MOVTIMO+1	Check for timeout
	bne	NXTCHK1
	dec	MOVTIMO
	bne	NXTCHK1

	lda	CURBOX		Deselect current box
	lbsr	LOLIGHT

	ldb	TONECHK		Get next in sequence
	ldx	#TONESEQ
	lda	b,x
	sta	CURBOX		Save as CURBOX, so GAMEOVR deselects
	lbsr	HILIGHT		Highlight next in sequence

	leas	2,s		Simulate a return to clean-up stack...
	jmp	GAMEOVR

NXTCHK1	lda	TONECNT		Not timeout, advance TONECNT...
	inca
	anda	#$03
	sta	TONECNT

	tst	PIA0D0		...and wait...
	sync
	tst	PIA0D0
	sync
	tst	PIA0D0
	sync
	tst	PIA0D0
	sync

	rts

*
* Play sequence of tones
*
*	X,A get clobbered
*
*
SEQPLAY	lda	TONELEN		Get current sequence length
	pshs	a

	ldx	#TONESEQ

SEQLOOP	lda	,x+		Get next tone in sequence
	pshs	a,x		Save A,X since they get clobbered...
	lbsr	HILIGHT		Highlight color matching this tone...
	lda	,s		Restore A from stack for input to TONEPLY
	ldx	TONEDLY		Set tone duration
	bsr	TONEPLY		Play it!
	lda	,s		Restore A from stack for input to LOLIGHT
	bsr	LOLIGHT		Un-highlight this color...
	puls	a,x

	dec	,s		Decrement remaining sequence length
	beq	SEQPLEX		Exit if last tone played

	ldd	#PPLYDLY	Set time counter for pause
	bsr	PAUSPLY		Pause between tones...
	bra	SEQLOOP		Play the next tone

SEQPLEX	leas	1,s		Clean-up stack
	rts

*
* Timed play of selected tone
*
*	X time counter, clobbered
*	A input tone to play, clobbered
*	B gets clobbered
*
TONEPLY	pshs	x		Save time counter
	inc	,s		Offset MSB value for proper delay counting

	ldx	#BXDELAY	Set freq counter
	ldb	a,x
	pshs	b

	ldb	,s		Reset freq counter
TNPLYLP	lda	PIA0D0		Clear hsync indicator...
	sync			Wait for next hsync clock...

	dec	2,s		Decrement time counter
	bne	TNPLYL1
	dec	1,s
	beq	TNPLYEX

TNPLYL1	decb			Decrement freq counter
	bne	TNPLYLP

	lda	PIA1D1		Toggle square wave output...
	eora	#SQWAVE
	sta	PIA1D1

	ldb	,s		Reset freq counter
	bra	TNPLYLP

TNPLYEX	leas	3,s		Clean-up stack
	rts

*
* Timed pause between tones
*
*	A,B time counter, clobbered
*
PAUSPLY	pshs	d		Save time counter
	inc	,s		Offset MSB value for proper delay counting

PPLYLOP	lda	PIA0D0		Clear hsync indicator...
	sync			Wait for next hsync clock...

	dec	1,s		Decrement time counter
	bne	PPLYLOP
	dec	,s
	bne	PPLYLOP

	leas	2,s		Clean-up stack
	rts

*
* Timed pause
*
*	A,B get clobbered
*
PAUSDLY	ldd	#PAUSCNT	Set time counter
	pshs	d

PBTNLOP	lda	PIA0D0		Clear hsync indicator...
	sync			Wait for next hsync clock...

	dec	1,s		Decrement time counter
	bne	PBTNLOP
	dec	,s
	bne	PBTNLOP

	leas	2,s		Clean-up stack
	rts

*
* Outline selected box in black
*
*	A box to deselect, clobbered
*	X gets clobbered
*
LOLIGHT	ldx	#BXOUTLN
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
* Draw the pretty boxes...
*
*	A,X,Y clobbered
*
DRWBOXS	ldy	#BXLOCAT
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
* Draw a normal text string on the display
*
* 	X points to the source, clobbered
*	Y points to the dest, clobbered
*	A length of the string, clobbered
*	B gets clobbered
*	Do not pass-in a zero length!
*
DRAWSTR	ldb	,x+
	stb	,y+

	deca			More characters?
	bne	DRAWSTR

	rts

*
* Draw black characters on the display
*
*	Y points to the dest, clobbered
*	A length of the string, clobbered
*	B gets clobbered
*	Do not pass-in a zero length!
*
DRAWBLK	ldb	#$80
	stb	,y+

	deca			More characters?
	bne	DRAWBLK

	rts

*
* Game won
*
GAMEWON	lda	CURBOX		Get current selection
	pshs	a		Save for later...

	lbsr	HILIGHT		Highlight color matching this tone...
	lda	,s		Restore A from stack for input to TONEPLY
	ldx	#WONDLY		Set tone duration (yes, WONDLY is intended)
	lbsr	TONEPLY		Play it!
	lda	,s		Restore A from stack for input to LOLIGHT
	lbsr	LOLIGHT		Un-highlight this color...
	ldd	#WONDLY		Set time counter for pause
	lbsr	PAUSPLY		Pause between tones...

	lda	#$05		Set loop counter
	pshs	a

GMWLOOP	lda	1,s		Restore A from stack for input to HILIGHT
	lbsr	HILIGHT		Highlight color matching this tone...
	lda	1,s		Restore A from stack for input to TONEPLY
	ldx	#WONDUR		Set tone duration
	lbsr	TONEPLY		Play it!
	lda	1,s		Restore A from stack for input to LOLIGHT
	lbsr	LOLIGHT		Un-highlight this color...
	ldd	#WONDLY		Set time counter for pause
	lbsr	PAUSPLY		Pause between tones...

	dec	,s		Decrement loop counter
	bne	GMWLOOP

	leas	2,s		Clean-up the stack

	ldx	#SMSYSTR	Display game winning message!
	ldy	#(VIDBASE+VIDSIZE/2-22)
	lda	#SMSYLEN
	bsr	DRAWSTR

	ldx	#YUWNSTR
	ldy	#(VIDBASE+VIDSIZE/2+11)
	lda	#YUWNLEN
	bsr	DRAWSTR

	ldd	#WINRDLY
	pshs	d
	inc	,s		Offset MSB value for proper delay counting

WINRWAI	lda	PIA0D0		Clear hsync indicator...
	sync			Wait for next hsync clock...

	lda	TONECNT		Not doing full re-init, so update TONECNT too
	inca
	anda	#$03
	sta	TONECNT

	dec	1,s		Count-down to next flash...
	bne	WINRWAI
	dec	,s
	bne	WINRWAI

	lda	PIA1D1		Invert CSS signal
	eora	#$08
	sta	PIA1D1

	ldd	#WINRDLY	Reset delay counter
	std	,s
	inc	,s		Offset MSB value for proper delay counting

	jsr	[$a000]
	beq	WINRWAI		Repeat the loop
	ifndef	ROM
	cmpa	#$03
	lbeq	EXIT
	endif

	ldy	#(VIDBASE+VIDSIZE/2-22)
	lda	#SMSYLEN
	lbsr	DRAWBLK

	ldy	#(VIDBASE+VIDSIZE/2+11)
	lda	#YUWNLEN
	lbsr	DRAWBLK

	lda	PIA1D1		Restore CSS value
	anda	#$f7
	sta	PIA1D1

	jmp	GAMATTR		Restart the game!

*
* Game lost
*
GAMEOVR	ldb	#FAILSND	Set freq counter
	pshs	b

	ldd	#FAILDLY	Set time counter
	pshs	d
	inc	,s		Offset MSB value for proper delay counting

	ldb	2,s		Reset freq counter
GOVPLAY	lda	PIA0D0		Clear hsync indicator...
	sync			Wait for next hsync clock...

	dec	1,s		Decrement time counter
	bne	GOVLOOP
	dec	,s
	beq	GOBTCLR

GOVLOOP	decb			Decrement freq counter
	bne	GOVPLAY

	lda	PIA1D1		Toggle square wave output...
	eora	#SQWAVE
	sta	PIA1D1

	ldb	2,s		Reset freq counter
	bra	GOVPLAY

GOBTCLR	lda	CURBOX		Deselect current box
	lbsr	LOLIGHT

	leas	3,s		Clean-up the stack...
	jmp	GAMATTR		Restart the game!

*
* Display round number
*
DISROND	pshs	a,x

	ldx	#RONDSTR
	ldy	#(VIDBASE+15*VIDLINE+12)
	lda	#RONDLEN
	lbsr	DRAWSTR

	ldx	#(VIDBASE+15*VIDLINE+18)
	lda	RONDNUM
	pshs	a
	anda	#$f0
	lsra
	lsra
	lsra
	lsra
	adda	#$30
	sta	,x+
	puls	a
	anda	#$0f
	adda	#$30
	sta	,x
	puls	a,x,pc

*
* Clear round number
*
CLRROND	pshs	d,x
	ldx	#(VIDBASE+15*VIDLINE+12)
	lda	#$80
	ldb	#$08
.1?	sta	,x+
	decb
	bne	.1?
	puls	d,x,pc

*
* Show the title screen
*
TTLSCRN	jsr	CLRSCN

	jsr	DRWBOXS

	ldx	#FLWCSTR	Display the program name
	ldy	#(VIDBASE+3*VIDLINE+9)
	lda	#FLWCSLN
	jsr	DRAWSTR

	ldx	#CPYSTR1	Display the copyright info
	ldy	#(VIDBASE+7*VIDLINE+10)
	lda	#CPYS1LN
	jsr	DRAWSTR

	ldx	#CPYSTR2
	ldy	#(VIDBASE+8*VIDLINE+9)
	lda	#CPYS2LN
	jsr	DRAWSTR

	ldx	#CPYSTR3
	ldy	#(VIDBASE+9*VIDLINE+11)
	lda	#CPYS3LN
	jsr	DRAWSTR

	ldx	#PRAKSTR
	ldy	#(VIDBASE+14*VIDLINE+8)
	lda	#PRAKLEN
	lbsr	DRAWSTR

	ldx	#CONTSTR
	ldy	#(VIDBASE+15*VIDLINE+9)
	lda	#CONTLEN
	lbsr	DRAWSTR

.1?	lda	TONECNT		Pre-seed TONECNT
	inca
	anda	#$03
	sta	TONECNT
	jsr	[$a000]
	beq	.1?
	ifndef	ROM
	cmpa	#$03
	beq	EXIT
	endif

	lbsr	CLRSCN		Clear the screen

	jsr	DRWBOXS		Draw the colored squares

	rts

*
* Initialize game variables
*
VARINIT	clr	CURBOX		Init other variables
	clr	TONELEN
	clr	RONDNUM

	ldd	#TONDLY1
	std	TONEDLY

	ldd	#MOVTIME	Reset move timeout counter
	std	MOVTIMO

	rts

	ifndef	ROM
*
* Exit the game
*
EXIT	lds	SAVSTK

* Restore timing sources
	lda	$ff01		Disable hsync interrupt generation
	anda	#$fe
	sta	$ff01
	tst	$ff00

	lda	$ff03		Enable vsync interrupt generation
	ora	#$01
	sta	$ff03

	andcc	#$ef		Re-enable IRQ

	rts
	endif

*
* Constants
*
BXCOLOR	fcb	$8f,$bf,$af,$9f

*BXDELAY	fcb	$28,$1e,$14,$18		Actual bugle notes
BXDELAY	fcb	$26,$1f,$13,$19		Original Simon appoximation

*
* Data for "SIMON SAYS"
*
SMSYSTR	fcb	$20,$13,$09,$0d,$0f,$0e,$20,$13
	fcb	$01,$19,$13,$20
SMSYEND	equ	*
SMSYLEN	equ	(SMSYEND-SMSYSTR)

*
* Data for "PRESS ANY KEY!"
*
PRK1STR	fcb	$20,$10,$12,$05,$13,$13,$20,$01
	fcb	$0e,$19,$20,$0b,$05,$19,$21,$20
PRK1END	equ	*
PRK1LEN	equ	(PRK1END-PRK1STR)

*
* Data for "FOLLOW COCO!"
*
FLWCSTR	fcb	$20,$06,$0f,$0c,$0c,$0f,$17,$20
	fcb	$03,$0f,$03,$0f,$21,$20
FLWCSND	equ	*
FLWCSLN	equ	(FLWCSND-FLWCSTR)

*
* Data for "PROGRAM BY"
*
CPYSTR1	fcb	$20,$10,$12,$0f,$07,$12,$01,$0d
	fcb	$20,$02,$19,$20
CPYS1ND	equ	*
CPYS1LN	equ	(CPYS1ND-CPYSTR1)

*
* Data for "J.W.LINVILLE"
*
CPYSTR2	fcb	$20,$0a,$2e,$17,$2e,$0c,$09,$0e
	fcb	$16,$09,$0c,$0c,$05,$20
CPYS2ND	equ	*
CPYS2LN	equ	(CPYS2ND-CPYSTR2)

*
* Data for "(C) 2015"
*
CPYSTR3	fcb	$20,$28,$03,$29,$20,$32,$30,$31
	fcb	$35,$20
CPYS3ND	equ	*
CPYS3LN	equ	(CPYS3ND-CPYSTR3)

*
* Data for "PRESS ANY KEY"
*
PRAKSTR	fcb	$20,$10,$12,$05,$13,$13,$20,$01
	fcb	$0e,$19,$20,$0b,$05,$19,$20,$20
PRAKEND	equ	*
PRAKLEN	equ	(PRAKEND-PRAKSTR)

*
* Data for "TO CONTINUE"
*
CONTSTR	fcb	$20,$14,$0f,$20,$03,$0f,$0e,$14
	fcb	$09,$0e,$15,$05,$20,$20
CONTEND	equ	*
CONTLEN	equ	(CONTEND-CONTSTR)

*
* Data for "YOU WIN!"
*
YUWNSTR	fcb	$20,$19,$0f,$15,$20,$17,$09,$0e
	fcb	$21,$20
YUWNEND	equ	*
YUWNLEN	equ	(YUWNEND-YUWNSTR)

*
* Data for "ROUND "
*
RONDSTR	fcb	$12,$0f,$15,$0e,$04,$20
RONDEND	equ	*
RONDLEN	equ	(RONDEND-RONDSTR)

*
* Pre-allocated variables
*
	ifdef	ROM
	org	DATA
	endif
CURBOX	rmb	1		Currently selected box

TONELEN	rmb	1		Length of tone sequence
TONESEQ	rmb	32		Tone sequence data (TONECNT _must_ be next)
TONECNT	rmb	1		Running counter used to generate tone seq

TONECHK	rmb	1		Cursor used to keep track of tone matching
TONEDLY	rmb	2		Delay time between tone playback

MOVTIMO	rmb	2		Timeout counter for next move

RONDNUM	rmb	1		Counter of current round

	ifndef	ROM
SAVSTK	rmb	2
	endif

	end	EXEC
