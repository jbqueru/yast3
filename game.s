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
; ####                     Main game logic entry point                     ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.text

CoreStart:
.if ^^defined DEBUG_COLOR_SHOW_CORE
	move.w #199, d0
.Core:
	eori.w #DEBUG_COLOR_SHOW_CORE, GFX_COLOR_0.w
	dbra.w d0, .Core.l
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

	btst.b #1, keyboard_state + 7.l
	sne.b d0
	or.b d0, thread_exit_all.l
	clr.b core_thread_ready.l
	bsr.w SwitchThreads.l
	bra.w CoreStart.l

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
	move.l fb_render.l, _draw_base.l
DrawLoop:
; Remember when we started to render this frame, so that we can throttle
; ourselves in case we render faster than the screen refresh.
	move.l frame_count.l, render_start.l

; Do the actual drawing
	movea.l _draw_base.l, a0
	moveq.l #0, d0
	move.w #7999, d7
.ClearScreen:
	move.l d0, (a0)+
	dbra.w d7, .ClearScreen.l

.if ^^defined DEBUG_COLOR_SHOW_RENDER
	eori.w #DEBUG_COLOR_SHOW_RENDER, GFX_COLOR_0.w
.endif
	lea.l _draw_colors, a4
	moveq.l #0, d3
	move.b _core_mouse_over, d3
	move.b #1, (a4, d3.w)


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
	bsr.w _DrawChar
	cmpa.l a3, a2
	bne.s .loop_chars

.if ^^defined DEBUG_COLOR_SHOW_RENDER
	eori.w #DEBUG_COLOR_SHOW_RENDER, GFX_COLOR_0.w
.endif

	move.l fb_render.l, _draw_base.l

; Signal to the GPU-handling code that we have a new frame ready
	move.b #1, fb_next_ready.l

; Check whether we've completed the render faster than the screen refresh.
; If we're already in a different frame, no need to throttle ourselves, the
; rendering can start immmediately, we are guaranteed to have a buffer
; available.
	move.l render_start.l, d0
	cmp.l frame_count.l, d0
	bne.w DrawLoop.l

; We're faster than the screen refresh, throttle ourselves by blocking.
; (In a world where the drawing thread is alone at the lowest non-idle
; priority, we could busy-wait, but that's not future-proof).
	clr.b draw_thread_ready.l
	bsr.w SwitchThreads.l
	bra.w DrawLoop.l

_DrawChar:
	movea.l _draw_base, a1
	mulu.w #1280, d1
	adda.w d1, a1
	move.w d0, d1
	andi.w #$fffe, d0
	add.w d0, d0
	adda.w d0, a1
	andi.w #$0001, d1
	adda.w d1, a1
	add.w d3, d3
	adda.w d3, a1
	lea.l font, a0
	lsl.w #3, d2
	adda.w d2, a0
	moveq.l #7, d0
.DrawCharLine:
	move.b (a0)+, (a1)
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
	dc.b %01100000
	dc.b %01111100
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
_draw_base:
	.ds.l 1

_draw_colors:
	.ds.b 26

_core_mouse_over:
	.ds.b 1
_core_mouse_click:
	.ds.b 1
