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

MouseDisplay:
.if ^^defined DEBUG_COLOR_SHOW_MOUSE
	eori.w #DEBUG_COLOR_SHOW_MOUSE, GFX_COLOR_0.w
.endif

; ######################################
; ##                                  ##
; ##  Restore background under mouse  ##
; ##                                  ##
; ######################################

MouseRestore:
	movea.l mouse_save_address.l, a1
	cmpa.w #0, a1							; cmpa sign-extends 16-bit arguments
	beq.s .RestoreDone.l
	lea.l mouse_save.l, a0
	moveq.l #16, d7							; 17 lines (!)
.RestoreLoop:
	move.l (a0)+, (a1)+						; 16 pixels, 2 bitplanes
	move.l (a0)+, (a1)+						; 16 pixels, 2 bitplanes
	lea.l 152(a1), a1						; next framebuffer line
	dbra.w d7, .RestoreLoop.l
.RestoreDone:

; #################################
; ##                             ##
; ##  Look ahead in ACIA buffer  ##
; ##                             ##
; #################################

	lea.l acia_rx_buffer.l, a0				; base address for the buffer
	move.w acia_rx_woffset.l, d7			; offset until which to read

; **********************************
; * separate combined read / x / y *
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
; * process packets *
; *******************

; d4.w: mouse x
; d5.w: mouse y
; d6.w: read position
; d7.w: max read position (next write position)
.StartPacket:
; Stop if we've processed all the data
	cmp.w d6, d7				; end of available data?
	beq.w .AllRead.l			; yes: all done

; Read first byte from packet
	move.b 0(a0, d6.w), d0		; Read first ACIA byte of IKBD packet

; Advance to next byte
	addq.w #2, d6				; Move to next ACIA byte
	cmpi.w #2048, d6			; Wrap within buffer
	bne.s .NB0.l
	subi.w #2048, d6
.NB0:

; Check if joystick packet
	cmpi.b #$fe, d0				; joystick is fe-ff
	blo.s .NotJoy.l				; Not joystick

; Process joystick
	cmp.w d6, d7				; End of ACIA buffer?
	beq.s .AllRead.l			; Stop ACIA processing

; Don't do anything with the data

; Advance to next byte
	addq.w #2, d6				; Move to next ACIA byte
	cmpi.w #2048, d6			; Wrap within buffer
	bne.s .NB1.l
	subi.w #2048, d6
.NB1:
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
	cmpi.w #2048, d6
	bne.s .NB2.l
	subi.w #2048, d6
.NB2:

; Process mouse part 2
	cmp.w d6, d7				; End of ACIA buffer?
	beq.s .AllRead.l			; Stop ACIA processing

; Read delta y
	move.b 0(a0, d6.w), d1		; Read mouse y data byte

; Advance to next byte
	addq.w #2, d6				; Move to next ACIA byte
	cmpi.w #2048, d6
	bne.s .NB3.l
	subi.w #2048, d6
.NB3:

; Apply mouse motion

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

	movea.l fb_display.l, a0
	cmpi.w #183, d5
	blt.s .InSY
	move.w #183, d5
.InSY:
	mulu.w #160, d5
	adda.w d5, a0
	cmpi.w #623, d4
	blt.s .InSX
	move.w #623, d4
.InSX:
	move.w d4, d1
	andi.w #$fff0, d4
	lsr.w #2, d4
	adda.w d4, a0
	andi.w #$f, d1
	lea.l mouse_mask.l, a1
	lea.l mouse_pattern.l, a2
	lea.l mouse_save.l, a3
	move.l a0, mouse_save_address.l
	moveq.l #16, d7
.DrawMouse:
	move.l (a0), (a3)+
	move.l 4(a0), (a3)+

	move.l (a1)+, d0
	ror.l d1, d0
	and.w d0, 4(a0)
	and.w d0, 6(a0)
	swap.w d0
	and.w d0, (a0)
	and.w d0, 2(a0)
	move.l (a2)+, d0
	ror.l d1, d0
	or.w d0, 4(a0)
	swap.w d0
	or.w d0, (a0)
	lea 160(a0), a0
	dbra.w d7, .DrawMouse.l
.if ^^defined DEBUG_COLOR_SHOW_MOUSE
	eori.w #DEBUG_COLOR_SHOW_MOUSE, GFX_COLOR_0.w
.endif

	rts

	.data
	.even

mouse_mask:
	.dc.l %00000001111111111111111111111111
	.dc.l %00000001111111111111111111111111
	.dc.l %00000001111111111111111111111111
	.dc.l %00000111111111111111111111111111
	.dc.l %00000011111111111111111111111111
	.dc.l %00010001111111111111111111111111
	.dc.l %00011000111111111111111111111111
	.dc.l %11111100011111111111111111111111
	.dc.l %11111110001111111111111111111111
	.dc.l %11111111000111111111111111111111
	.dc.l %11111111100011111111111111111111
	.dc.l %11111111110001111111111111111111
	.dc.l %11111111111000111111111111111111
	.dc.l %11111111111100011111111111111111
	.dc.l %11111111111110001111111111111111
	.dc.l %11111111111111000111111111111111
	.dc.l %11111111111111100111111111111111

mouse_pattern:
	.dc.l %00000000000000000000000000000000
	.dc.l %01111100000000000000000000000000
	.dc.l %01100000000000000000000000000000
	.dc.l %01010000000000000000000000000000
	.dc.l %01001000000000000000000000000000
	.dc.l %01000100000000000000000000000000
	.dc.l %00000010000000000000000000000000
	.dc.l %00000001000000000000000000000000
	.dc.l %00000000100000000000000000000000
	.dc.l %00000000010000000000000000000000
	.dc.l %00000000001000000000000000000000
	.dc.l %00000000000100000000000000000000
	.dc.l %00000000000010000000000000000000
	.dc.l %00000000000001000000000000000000
	.dc.l %00000000000000100000000000000000
	.dc.l %00000000000000010000000000000000
	.dc.l %00000000000000000000000000000000

	.bss
	.even

mouse_save_address:
	.ds.l 1
mouse_save:
	.ds.w 4 * 17
