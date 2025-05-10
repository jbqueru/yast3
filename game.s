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

CoreThread:
	move.w #199, d0
.Core:
	eor.w #$400, $ffff8240.w
	dbra.w d0, .Core.l
	cmpi.w #639, mouse_x.l
	bne.s .NotBR
	cmpi.w #199, mouse_y.l
	bne.s .NotBR
	move.b #1, thread_exit_all.l
.NotBR:
	btst.b #1, keyboard_state + 7.l
	sne.b d0
	or.b d0, thread_exit_all.l
	clr.b core_thread_ready.l
	bsr.w SwitchThreads.l
	bra.s CoreThread.l

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
	move.l fb_render.l, render_base.l
DrawLoop:
; Remember when we started to render this frame, so that we can throttle
; ourselves in case we render faster than the screen refresh.
	move.l frame_count.l, render_start.l

; Do the actual drawing
	move.l render_base.l, a0
	move.w #199, d7
.Draw:
	eor.w #$040, $ffff8240.w
	move.l interrupt_ticks_300hz.l, d0
	move.w d0, 4(a0)
	move.w d0, 156(a0)
	swap.w d0
	move.w d0, (a0)
	move.w d0, 152(a0)
	lea.l 160(a0), a0
	moveq.l #127, d6
.Nothing:
	rol.b #8, d0
	dbra.w d6, .Nothing.l
	dbra.w d7, .Draw.l

	move.l fb_render.l, render_base.l

; Signal to the GPU-handling code that we have a new frame ready
	move.b #1, fb_next_ready.l

; Check whether we've completed the render faster than the screen refresh.
	move.l render_start.l, d0
	cmp.l frame_count.l, d0

; If we're already in a different frame, no need to throttle ourselves, the
; rendering can start immmediately, we are guaranteed to have a buffer
; available.
	bne.s DrawLoop.l

; We're still in the same thread, throttle ourselves by blocking.
; (In a world where the drawing thread is alone at the lowest non-idle
; priority, we could busy-wait, but that's not future-proof).
	clr.b draw_thread_ready.l
	bsr.w SwitchThreads.l
	bra.s DrawLoop.l

	.bss
	.even
render_base:
	.ds.l 1
