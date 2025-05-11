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
	move.w d0, _core_mouse_over.l

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

	moveq.l #60, d0
	moveq.l #0, d1
	moveq.l #1, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #1, d1
	moveq.l #2, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #2, d1
	moveq.l #3, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #3, d1
	moveq.l #4, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #4, d1
	moveq.l #5, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #5, d1
	moveq.l #6, d2
	moveq.l #0, d3
	bsr _DrawChar.l

	moveq.l #59, d0
	moveq.l #7, d1
	moveq.l #3, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #7, d1
	moveq.l #5, d2
	moveq.l #0, d3
	bsr _DrawChar.l

	moveq.l #58, d0
	moveq.l #9, d1
	moveq.l #3, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #59, d0
	moveq.l #9, d1
	moveq.l #3, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #9, d1
	moveq.l #3, d2
	moveq.l #0, d3
	bsr _DrawChar.l

	moveq.l #57, d0
	moveq.l #10, d1
	moveq.l #4, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #58, d0
	moveq.l #10, d1
	moveq.l #4, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #59, d0
	moveq.l #10, d1
	moveq.l #4, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #10, d1
	moveq.l #4, d2
	moveq.l #0, d3
	bsr _DrawChar.l

	moveq.l #56, d0
	moveq.l #11, d1
	moveq.l #1, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #57, d0
	moveq.l #11, d1
	moveq.l #1, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #58, d0
	moveq.l #11, d1
	moveq.l #1, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #59, d0
	moveq.l #11, d1
	moveq.l #2, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #11, d1
	moveq.l #2, d2
	moveq.l #0, d3
	bsr _DrawChar.l

	moveq.l #57, d0
	moveq.l #12, d1
	moveq.l #1, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #58, d0
	moveq.l #12, d1
	moveq.l #2, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #59, d0
	moveq.l #12, d1
	moveq.l #3, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #12, d1
	moveq.l #4, d2
	moveq.l #0, d3
	bsr _DrawChar.l

	moveq.l #56, d0
	moveq.l #13, d1
	moveq.l #2, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #57, d0
	moveq.l #13, d1
	moveq.l #3, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #58, d0
	moveq.l #13, d1
	moveq.l #4, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #59, d0
	moveq.l #13, d1
	moveq.l #5, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #13, d1
	moveq.l #6, d2
	moveq.l #0, d3
	bsr _DrawChar.l

	moveq.l #56, d0
	moveq.l #14, d1
	moveq.l #5, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #57, d0
	moveq.l #14, d1
	moveq.l #5, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #58, d0
	moveq.l #14, d1
	moveq.l #5, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #59, d0
	moveq.l #14, d1
	moveq.l #5, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #14, d1
	moveq.l #5, d2
	moveq.l #0, d3
	bsr _DrawChar.l

	moveq.l #56, d0
	moveq.l #15, d1
	moveq.l #3, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #57, d0
	moveq.l #15, d1
	moveq.l #1, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #58, d0
	moveq.l #15, d1
	moveq.l #4, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #59, d0
	moveq.l #15, d1
	moveq.l #1, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #60, d0
	moveq.l #15, d1
	moveq.l #5, d2
	moveq.l #0, d3
	bsr _DrawChar.l

	moveq.l #11, d0
	moveq.l #2, d1
	moveq.l #0, d2
	cmpi.w #1, _core_mouse_over.l
	seq.b d3
	andi.w #1, d3
	bsr _DrawChar.l
	moveq.l #12, d0
	moveq.l #2, d1
	moveq.l #0, d2
	cmpi.w #1, _core_mouse_over.l
	seq.b d3
	andi.w #1, d3
	bsr _DrawChar.l
	moveq.l #13, d0
	moveq.l #2, d1
	moveq.l #0, d2
	cmpi.w #1, _core_mouse_over.l
	seq.b d3
	andi.w #1, d3
	bsr _DrawChar.l

	moveq.l #12, d0
	moveq.l #4, d1
	moveq.l #1, d2
	moveq.l #0, d3
	bsr _DrawChar.l

	moveq.l #8, d0
	moveq.l #6, d1
	moveq.l #6, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #10, d0
	moveq.l #6, d1
	moveq.l #6, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #12, d0
	moveq.l #6, d1
	moveq.l #6, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #14, d0
	moveq.l #6, d1
	moveq.l #6, d2
	moveq.l #0, d3
	bsr _DrawChar.l
	moveq.l #16, d0
	moveq.l #6, d1
	moveq.l #6, d2
	moveq.l #0, d3
	bsr _DrawChar.l


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
mouse_zones_end:

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
	dc.b %00111000
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

_core_mouse_over:
	.ds.w 1
_core_mouse_click:
	.ds.w 1
