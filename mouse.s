; Copyright 2025 Jean-Baptiste M. "JBQ" "Djaybee" Queru
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU Affero General Public License as
; published by the Free Software Foundation, either version 3 of the
; License, or (at your option) any later version.
;
; As an added restriction, if you make the program available for
; third parties to use on hardware you own (or co-own, lease, rent,
; or otherwise control,) such as public gaming cabinets (whether or
; not in a gaming arcade, whether or not coin-operated or otherwise
; for a fee,) the conditions of section 13 will apply even if no
; network is involved.
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
	move.l d0, d3
	andi.w #$7ff, d3			; mouse x position at beginning of lookahead

; middle 11 bits: y coordinate
	move.l d0, d4
	lsl.l #5, d4
	swap.w d4
	andi.w #$7ff, d4			; mouse y position at beginning of lookahead

; *******************
; * process packets *
; *******************

; d3.w: mouse x
; d4.w: mouse y
; d6.w: read position
; d7.w: max read position (next write position)
.StartPacket:
	cmp.w d6, d7				; end of available data?
	beq.w .AllRead.l			; yes: all done

	move.b 0(a0, d6.w), d0		; Read first ACIA byte of IKBD packet

	addq.w #2, d6				; Move to next ACIA byte
	cmpi.w #2048, d6
	bne.s .NB1.l
	subi.w #2048, d6
.NB1:

	cmpi.b #$fe, d0				; Check if joystick (fe-ff)
	blo.s .NotJoy.l				; Not joystick

	cmp.w d6, d7				; End of ACIA buffer?
	beq.s .AllRead.l			; Stop ACIA processing
	addq.w #2, d6				; Skip joystick data byte
	bra.s .PacketDone.l
.NotJoy:


	cmpi.b #$f8, d0				; Check if mouse (f8-fb)
	blo.s .PacketDone.l			; Not mouse

	cmp.w d6, d7				; End of ACIA buffer?
	beq.s .AllRead.l			; Stop ACIA processing
	move.b 0(a0, d6.w), d1		; Read mouse x data byte
	addq.w #2, d6				; Move to next ACIA byte
	cmpi.w #2048, d6
	bne.s .NB2.l
	subi.w #2048, d6
.NB2:

	cmp.w d6, d7				; End of ACIA buffer?
	beq.s .AllRead.l			; Stop ACIA processing
	move.b 0(a0, d6.w), d2		; Read mouse y data byte
	addq.w #2, d6				; Move to next ACIA byte

; Constrain X coordinate 0-639
	ext.w d1
	add.w d3, d1
	bpl.s .OkX1.l
	moveq.l #0, d1
	bra.s .OkX2.l
.OkX1:
	cmpi.w #640, d1
	blt.s .OkX2.l
	move.w #639, d1
.OkX2:
	move.w d1, d3

; Constrain Y coordinate 0-199
	ext.w d2
	add.w d4, d2
	bpl.s .OkY1.l
	moveq.l #0, d2
	bra.s .OkY2.l
.OkY1:
	cmpi.w #200, d2
	blt.s .OkY2.l
	move.w #199, d2
.OkY2:
	move.w d2, d4

.PacketDone:
	cmpi.w #2048, d6
	bne.w .StartPacket.l
	subi.w #2048, d6
	bra.w .StartPacket.l
.AllRead:




	movea.l fb_display.l, a0
	move.w d4, d0
	cmpi.w #183, d0
	blt.s .InSY
	move.w #183, d0
.InSY:
	mulu.w #160, d0
	adda.w d0, a0
	move.w d3, d0
	cmpi.w #623, d0
	blt.s .InSX
	move.w #623, d0
.InSX:
	move.w d0, d1
	andi.w #$fff0, d0
	lsr.w #2, d0
	adda.w d0, a0
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
