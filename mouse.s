; Copyright 2025 Jean-Baptiste M. "JBQ" "Djaybee" Queru
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU Affero General Public License as
; published by the Free Software Foundation, either version 3 of the
; License, or (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
; GNU Affero General Public License for more details.
;
; You should have received a copy of the GNU Affero General Public License
; along with this program. If not, see <https://www.gnu.org/licenses/>.
;
; SPDX-License-Identifier: AGPL-3.0-or-later

; See main.s for more information

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                            Mouse thread                             ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.text

MouseCore:
.if ^^defined DEBUG_COLOR_SHOW_MOUSE
	eori.w #DEBUG_COLOR_SHOW_MOUSE, GFX_COLOR_0.w
.endif

; ######################################
; ##                                  ##
; ##  Restore background under mouse  ##
; ##                                  ##
; ######################################

_MouseRestore:
	movea.l _mouse_save_address.l, a1
	cmpa.w #0, a1							; cmpa sign-extends 16-bit arguments
	beq.s .RestoreDone.l
	lea.l _mouse_save.l, a0
	moveq.l #16, d7							; 17 lines (!)
.RestoreLoop:
	move.l (a0)+, (a1)+						; 16 pixels, 2 bitplanes
	move.l (a0)+, (a1)+						; 16 pixels, 2 bitplanes
	move.l (a0)+, (a1)+						; 16 pixels, 2 bitplanes
	lea.l 148(a1), a1						; next framebuffer line
	dbra.w d7, .RestoreLoop.l
.RestoreDone:

; #################################
; ##                             ##
; ##  Look ahead in ACIA buffer  ##
; ##                             ##
; #################################

_MouseLookAhead:
	lea.l acia_rx_buffer.l, a0				; base address for the buffer
	move.w acia_rx_woffset.l, d7			; offset until which to read

; **********************************
; * Separate combined read / x / y *
; **********************************
	move.l acia_mouse_r_xy.l, d0

; top 10 bits: read offset in words (byte pairs)
	move.l d0, d6
	swap.w d6
	lsr.w #5, d6
	andi.w #$3ff << 1, d6		; offset from which to read

; bottom 11 bits: x coordinate
	move.l d0, d4
	andi.w #$7ff, d4			; mouse x position at beginning of lookahead

; middle 11 bits: y coordinate
	move.l d0, d5
	lsl.l #5, d5
	swap.w d5
	andi.w #$7ff, d5			; mouse y position at beginning of lookahead

; *******************
; * Process packets *
; *******************

; d4.w: mouse x
; d5.w: mouse y
; d6.w: read position
; d7.w: max read position (next write position)
.StartPacket:
; Stop if we've processed all the data
	cmp.w d6, d7				; end of available data?
	beq.s .AllRead.l			; yes: all done

; Read first byte from packet
	move.b 0(a0, d6.w), d0		; Read first ACIA byte of IKBD packet

; Advance to next byte
	addq.w #2, d6				; Move to next ACIA byte
	andi.w #IKBD_QUEUE_SIZE - 2, d6			; Wrap within buffer

; Check if joystick packet
	cmpi.b #$fe, d0				; joystick is fe-ff
	blo.s .NotJoy.l				; Not joystick

; Process joystick
	cmp.w d6, d7				; End of ACIA buffer?
	beq.s .AllRead.l			; Stop ACIA processing

; Don't do anything with the data

; Advance to next byte
	addq.w #2, d6				; Move to next ACIA byte
	andi.w #IKBD_QUEUE_SIZE - 2, d6			; Wrap within buffer

	bra.s .StartPacket.l

.NotJoy:

; Check if mouse packet
	cmpi.b #$f8, d0				; mouse is f8-fb
	blo.s .StartPacket.l		; Not mouse

; Process mouse part 1
	cmp.w d6, d7				; End of ACIA buffer?
	beq.s .AllRead.l			; Stop ACIA processing

; Read delta x
	move.b 0(a0, d6.w), d0		; Read mouse x data byte

; Advance to next byte
	addq.w #2, d6				; Move to next ACIA byte
	andi.w #IKBD_QUEUE_SIZE - 2, d6			; Wrap within buffer

; Process mouse part 2
	cmp.w d6, d7				; End of ACIA buffer?
	beq.s .AllRead.l			; Stop ACIA processing

; Read delta y
	move.b 0(a0, d6.w), d1		; Read mouse y data byte

; Advance to next byte
	addq.w #2, d6				; Move to next ACIA byte
	andi.w #IKBD_QUEUE_SIZE - 2, d6			; Wrap within buffer

; **********************
; * Apply mouse motion *
; **********************

; Constrain X coordinate 0-639
	ext.w d0					; Received delta x as 1 signed byte from IKBD
	add.w d0, d4				; Add to running count
	bpl.s .OkX1.l				; Positive, no need to handle the negative case
	moveq.l #0, d4				; If negative, clamp to 0
	bra.s .OkX2.l				; In that case, we're done
.OkX1:
	cmpi.w #640, d4				; Check if already within screen
	blt.s .OkX2.l				; We are within screen, no need to clamp
	move.w #639, d4				; Clamp to rightmost pixel
.OkX2:

; Constrain Y coordinate 0-199
	ext.w d1					; Received delta y as 1 signed byte from IKBD
	add.w d1, d5				; Add to running count
	bpl.s .OkY1.l				; Positive, no need to handle the negative case
	moveq.l #0, d5				; If negative, clamp to 0
	bra.s .OkY2.l				; In that case, we're done
.OkY1:
	cmpi.w #200, d5				; Check if already within screen
	blt.s .OkY2.l				; We are within screen, no need to clamp
	move.w #199, d5				; Clamp to bottommost pixel
.OkY2:

	bra.w .StartPacket.l

.AllRead:

; ######################
; ##                  ##
; ##  Display cursor  ##
; ##                  ##
; ######################

; TODO: skip display if mouse hasn't moved.

_MouseDisplay:
	movea.l fb_display.l, a0		; framebuffer base address

; *************************************
; * Clamp so entire cursor is visible *
; *************************************
	cmpi.w #639-32, d4
	blt.s .InSX
	move.w #639-32, d4
.InSX:

	cmpi.w #183, d5
	blt.s .InSY
	move.w #183, d5
.InSY:

	mulu.w #160, d5
	adda.w d5, a0

; ******************************
; * Compute display parameters *
; ******************************
	move.w d4, d1
	andi.w #$fff0, d4
	lsr.w #2, d4
	adda.w d4, a0
	andi.w #$f, d1
	lea.l _mouse_mask.l, a1
	lea.l _mouse_pattern.l, a2
	lea.l _mouse_save.l, a3
	move.l a0, _mouse_save_address.l

; **************************
; * Display mouse onscreen *
; **************************
	moveq.l #16, d7			; Mouse is currently 17 lines (!)
.DrawMouseLine:

; Save mouse data
	move.l (a0), (a3)+
	move.l 4(a0), (a3)+
	move.l 8(a0), (a3)+

; Mask, first 16 pixels
	move.l (a1), d0
	lsr.l d1, d0
	not.w d0
	and.w d0, (a0)
	and.w d0, 2(a0)

; Mask, middle 16 pixels
	move.l 2(a1), d0
	lsr.l d1, d0
	not.w d0
	and.w d0, 4(a0)
	and.w d0, 6(a0)

; Mask, last 16 pixels
	move.l 4(a1), d0
	lsr.l d1, d0
	not.w d0
	and.w d0, 8(a0)
	and.w d0, 10(a0)

; Advance mask read
	addq.l #8, a1

	move.l (a2), d0
	lsr.l d1, d0
	or.w d0, (a0)

	move.l 2(a2), d0
	lsr.l d1, d0
	or.w d0, 4(a0)

	move.l 4(a2), d0
	lsr.l d1, d0
	or.w d0, 8(a0)

	addq.l #8, a2

	lea 160(a0), a0
	dbra.w d7, .DrawMouseLine.l
.if ^^defined DEBUG_COLOR_SHOW_MOUSE
	eori.w #DEBUG_COLOR_SHOW_MOUSE, GFX_COLOR_0.w
.endif

	rts

	.data
	.even

_mouse_mask:
	.dc.w 0, %1111111000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %1111111000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %1111111000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %1111100000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %1111110000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %1110111000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %1110011100000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000001110000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000111000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000011100000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000001110000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000111000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000011100, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000001110, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000000111, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000000011, %1000000000000000, %1000000000000000
	.dc.w 0, %0000000000000001, %1000000000000000, %1000000000000000

_mouse_pattern:
	.dc.w 0, %0000000000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0111110000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0110000000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0101000000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0100100000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0100010000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000001000000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000100000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000010000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000001000000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000100000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000010000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000001000, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000000100, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000000010, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000000001, %0000000000000000, %1000000000000000
	.dc.w 0, %0000000000000000, %0000000000000000, %1000000000000000

	.bss
	.even

_mouse_save_address:
	.ds.l 1
_mouse_save:
	.ds.w 6 * 17
