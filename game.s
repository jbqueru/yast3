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

	.text

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                     Main rendering entry point                      ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

DrawStart:
DrawLoop:
	addq.l #1, time_render.l

	movea.l acia_rx_read.l, a0
	movea.l acia_rx_write.l, a2
.NextPacket:
	cmpa.l a0, a2
	beq.w .all_read.l
	movea.l a0, a1

	move.b (a1)+, d0
	addq.l #1, a1
	cmpa.l #acia_rx_buffer + 2048, a1
	bne.s .NB1.l
	lea.l -2048(a1), a1
.NB1:

	cmpi.b #$fe, d0
	blo.s .NotJoy.l
	cmpa.l a1, a2
	beq.w .all_read.l
	move.b (a1)+, d1
	addq.l #1, a1
	bra.w .PacketDone

.NotJoy:
	cmpi.b #$f8, d0
	blo.s .NotMouse.l

	cmpa.l a1, a2
	beq.w .all_read.l
	move.b (a1)+, d1
	addq.l #1, a1
	cmpa.l #acia_rx_buffer + 2048, a1
	bne.s .NB2.l
	lea.l -2048(a1), a1
.NB2:

	cmpa.l a1, a2
	beq.w .all_read.l
	move.b (a1)+, d2
	addq.l #1, a1

	andi.w #$3, d0
	move.w d0, mouse_buttons

	ext.w d1
	add.w mouse_x, d1
	bpl.s .OkX1
	moveq.l #0, d1
	bra.s .OkX2
.OkX1:
	cmpi.w #640, d1
	blt.s .OkX2
	move.w #639, d1
.OkX2:
	move.w d1, mouse_x

	ext.w d2
	add.w mouse_y, d2
	bpl.s .OkY1
	moveq.l #0, d2
	bra.s .OkY2
.OkY1:
	cmpi.w #200, d2
	blt.s .OkY2
	move.w #199, d2
.OkY2:
	move.w d2, mouse_y

	bra.s .PacketDone.l

.NotMouse:
	moveq.l #0, d1
	move.b d0, d1
	andi.b #$7f, d1
	move.l d1, d2
	andi.w #7, d1
	lsr.w #3, d2
	lea.l keyboard_state.l, a3
	adda.w d2, a3
	moveq.l #0, d2
	bset.l d1, d2
	btst.l #7, d0
	bne.s .KeyRelease
	or.b d2, (a3)
	bra.s .KeyDone
.KeyRelease:
	not.b d2
	and.b d2, (a3)
.KeyDone:

.PacketDone:
	movea.l a1, a0
	cmpa.l #acia_rx_buffer + 2048, a0
	bne.w .NextPacket
	lea.l -2048(a0), a0
	bra.w .NextPacket
.all_read:
	move.l a0, acia_rx_read.l
.if ^^defined DEBUG_COLOR_SHOW_MOUSE
	eori.w #DEBUG_COLOR_SHOW_MOUSE, GFX_COLOR_0.w
.endif

; Check if the mouse is in one of the active zones
	lea.l mouse_zones.l, a0
	lea.l mouse_zones_end.l, a1
	moveq.l #1, d0
	move.w mouse_x.l, d1
	move.w mouse_y.l, d2

.zone_loop:
	cmp.w (a0), d1
	blt.s .not_in_zone.l
	cmp.w 2(a0), d1
	bgt.s .not_in_zone.l
	cmp.w 4(a0), d2
	blt.s .not_in_zone.l
	cmp.w 6(a0), d2
	ble.s .zone_done.l

.not_in_zone:
	addq.w #1, d0
	addq.l #8, a0
	cmpa.l a1, a0
	bne.s .zone_loop.l
	moveq.l #0, d0
.zone_done:
	move.b d0, _core_mouse_over.l

; Build the colors list based on internal state and mouse position
; TODO: build one for each framebuffer to avoid race condition

	lea.l _draw_colors, a0
	moveq.l #25, d0
.ClearColors:
	move.b #1, (a0)+
	dbra.w d0, .ClearColors
	lea.l _draw_colors, a0
	moveq.l #0, d3
	move.b _core_mouse_over, d3
	beq.s .Zone0
	move.b #2, (a0, d3.w)
.Zone0:

; Do the actual drawing
	movea.l fb_rendering.l, a0
	moveq.l #0, d0
	move.w #7999, d7
.ClearScreen:
	move.l d0, (a0)+
	dbra.w d7, .ClearScreen.l

.if ^^defined DEBUG_COLOR_SHOW_RENDER
	eori.w #DEBUG_COLOR_SHOW_RENDER, GFX_COLOR_0.w
.endif
	lea.l chars_list.l, a2
	lea.l chars_list_end.l, a3
	lea.l _draw_colors, a4
.loop_chars:
	moveq.l #0, d0
	move.b (a2)+, d0
	moveq.l #0, d1
	move.b (a2)+, d1
	moveq.l #0, d2
	move.b (a2)+, d2
	moveq.l #0, d3
	move.b (a2)+, d3
	move.b (a4, d3.w), d3
	bsr.s _DrawChar
	cmpa.l a3, a2
	bne.s .loop_chars

.if ^^defined DEBUG_COLOR_SHOW_RENDER
	eori.w #DEBUG_COLOR_SHOW_RENDER, GFX_COLOR_0.w
.endif

	tst.b keyboard_state+7.l
	bne.s .bye.l

	move.b #$fe, MFP_IMRA.w							; mask away timer B
	move.l fb_ready.l, d0
	move.l fb_rendering.l, fb_ready.l
	move.l fb_dirty.l, d1
	bne.s .d1_is_next_fb
	move.l d0, d1
.d1_is_next_fb:
	move.l d1, fb_rendering.l
	moveq.l #0, d0
	move.l d0, fb_dirty.l
	move.b #$ff, MFP_IMRA.w							; unmask timer B


	bra.w DrawLoop.l

.bye:
	move.w #$2700, sr
	rts

_DrawChar:
	movea.l fb_rendering.l, a1
	mulu.w #1280, d1
	adda.w d1, a1
	move.w d0, d1
	andi.w #$fffe, d0
	add.w d0, d0
	adda.w d0, a1
	andi.w #$0001, d1
	adda.w d1, a1
	lea.l font, a0
	lsl.w #3, d2
	adda.w d2, a0
	moveq.l #7, d0
.DrawCharLine:
	move.b (a0)+, d1
	btst.l #0, d3
	beq.s .bit0done
	move.b d1, (a1)
.bit0done:
	btst.l #1, d3
	beq.s .bit1done
	move.b d1, 2(a1)
.bit1done:
	lea.l 160(a1), a1
	dbra.w d0, .DrawCharLine
	rts

	.data
	.even
mouse_zones:
	.dc.w 88, 111, 16, 23
	.dc.w 96, 103, 32, 39
	.dc.w 64, 71, 48, 63
	.dc.w 80, 87, 48, 63
	.dc.w 96, 103, 48, 63
	.dc.w 112, 119, 48, 63
	.dc.w 128, 137, 48, 63
	.dc.w 480, 487, 0, 7
	.dc.w 480, 487, 8, 15
	.dc.w 480, 487, 16, 23
	.dc.w 480, 487, 24, 31
	.dc.w 480, 487, 32, 39
	.dc.w 480, 487, 40, 47
	.dc.w 464, 487, 72, 79
	.dc.w 456, 487, 80, 87
	.dc.w 448, 487, 88, 95
	.dc.w 456, 487, 96, 103
	.dc.w 448, 487, 104, 111
	.dc.w 448, 487, 112, 119
	.dc.w 448, 487, 120, 127
mouse_zones_end:

chars_list:
	.dc.b 11, 2, 0, 1
	.dc.b 12, 2, 0, 1
	.dc.b 13, 2, 0, 1

	.dc.b 12, 4, 1, 2

	.dc.b 8, 6, 6, 3
	.dc.b 10, 6, 6, 4
	.dc.b 12, 6, 6, 5
	.dc.b 14, 6, 6, 6
	.dc.b 16, 6, 6, 7

	.dc.b 8, 7, 6, 21
	.dc.b 10, 7, 6, 22
	.dc.b 12, 7, 6, 23
	.dc.b 14, 7, 6, 24
	.dc.b 16, 7, 6, 25

	.dc.b 60, 0, 1, 8
	.dc.b 60, 1, 2, 9
	.dc.b 60, 2, 3, 10
	.dc.b 60, 3, 4, 11
	.dc.b 60, 4, 5, 12
	.dc.b 60, 5, 6, 13

	.dc.b 59, 7, 3, 0
	.dc.b 60, 7, 5, 0

	.dc.b 58, 9, 3, 14
	.dc.b 59, 9, 3, 14
	.dc.b 60, 9, 3, 14

	.dc.b 57, 10, 4, 15
	.dc.b 58, 10, 4, 15
	.dc.b 59, 10, 4, 15
	.dc.b 60, 10, 4, 15

	.dc.b 56, 11, 1, 16
	.dc.b 57, 11, 1, 16
	.dc.b 58, 11, 1, 16
	.dc.b 59, 11, 2, 16
	.dc.b 60, 11, 2, 16

	.dc.b 57, 12, 1, 17
	.dc.b 58, 12, 2, 17
	.dc.b 59, 12, 3, 17
	.dc.b 60, 12, 4, 17

	.dc.b 56, 13, 2, 18
	.dc.b 57, 13, 3, 18
	.dc.b 58, 13, 4, 18
	.dc.b 59, 13, 5, 18
	.dc.b 60, 13, 6, 18

	.dc.b 56, 14, 5, 19
	.dc.b 57, 14, 5, 19
	.dc.b 58, 14, 5, 19
	.dc.b 59, 14, 5, 19
	.dc.b 60, 14, 5, 19

	.dc.b 56, 15, 3, 20
	.dc.b 57, 15, 1, 20
	.dc.b 58, 15, 4, 20
	.dc.b 59, 15, 1, 20
	.dc.b 60, 15, 5, 20

chars_list_end:

font:

	dc.b %00111100
	dc.b %01100110
	dc.b %01100110
	dc.b %01100110
	dc.b %01100110
	dc.b %01100110
	dc.b %00111100
	dc.b %00000000

	dc.b %00011000
	dc.b %00111000
	dc.b %00011000
	dc.b %00011000
	dc.b %00011000
	dc.b %00011000
	dc.b %00111100
	dc.b %00000000

	dc.b %00111100
	dc.b %01100110
	dc.b %00000110
	dc.b %00111100
	dc.b %01100000
	dc.b %01100000
	dc.b %01111110
	dc.b %00000000

	dc.b %00111100
	dc.b %01100110
	dc.b %00000110
	dc.b %00011100
	dc.b %00000110
	dc.b %01100110
	dc.b %00111100
	dc.b %00000000

	dc.b %01100000
	dc.b %01100000
	dc.b %01100000
	dc.b %01101100
	dc.b %01111110
	dc.b %00001100
	dc.b %00001100
	dc.b %00000000

	dc.b %01111110
	dc.b %01100000
	dc.b %01111100
	dc.b %00000110
	dc.b %00000110
	dc.b %01100110
	dc.b %00111100
	dc.b %00000000

	dc.b %00111100
	dc.b %01100110
	dc.b %01100000
	dc.b %01111100
	dc.b %01100110
	dc.b %01100110
	dc.b %00111100
	dc.b %00000000

	dc.b %01111110
	dc.b %00000110
	dc.b %00001100
	dc.b %00011000
	dc.b %00011000
	dc.b %00011000
	dc.b %00011000
	dc.b %00000000

	dc.b %00111100
	dc.b %01100110
	dc.b %01100110
	dc.b %00111100
	dc.b %01100110
	dc.b %01100110
	dc.b %00111100
	dc.b %00000000

	dc.b %00111100
	dc.b %01100110
	dc.b %01100110
	dc.b %00111110
	dc.b %00000110
	dc.b %01100110
	dc.b %00111100
	dc.b %00000000

	.bss
	.even
_draw_colors:
	.ds.b 26

_core_mouse_over:
	.ds.b 1
_core_mouse_click:
	.ds.b 1
