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
; ####                         Rendering routines                          ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.text

; #################
; ##             ##
; ##  Rendering  ##
; ##             ##
; #################

GameRender:
	lea.l _chars_list.l, a2
	lea.l _chars_list_end.l, a3
	movea.l screen_rendering.l, a4
	movea.l 4(a4), a4
	movea.l colors_spare.l, a5
.loop_chars:
	moveq.l #0, d0
	move.b (a2)+, d0
	moveq.l #0, d1
	move.b (a2)+, d1
	moveq.l #0, d2
	move.b (a2)+, d2
	moveq.l #0, d3
	move.b (a2)+, d3
	move.b (a4, d3.w), d4
	move.b (a5, d3.w), d3
	cmp.b d3, d4
	beq.s .same_color.l
	bsr.w _DrawChar.l
.same_color:
	cmpa.l a3, a2
	bne.s .loop_chars

	lea.l _variable_locations.l, a2
	movea.l screen_rendering.l, a3
	movea.l 4(a3), a3
	lea.l _display_variable_values(a3), a3
	movea.l colors_spare.l, a4
	lea.l _display_variable_values(a4), a4
	moveq.l #21, d4
.display_score:
	move.w (a3)+, d0
	cmp.w (a4), d0
;	beq.s .unchanged.l
	moveq.l #0, d6
	cmpi.w #21, d4
	bge.s .read16.l
	move.b (a4), d6
	move.b 1(a4), d7
	bra.s .gotnc.l
.read16:
	move.w (a4), d6
	moveq.l #1, d7
.gotnc:
	moveq.l #0, d0
	move.b (a2), d0
	moveq.l #0, d1
	move.b 1(a2), d1
	divu.w #10, d6
	swap.w d6
	move.w d6, d2
	clr.w d6
	swap.w d6
	move.b d7, d3
	bsr.w _DrawChar.l

	tst.w d6
	beq.s .unchanged.l

	moveq.l #0, d0
	move.b #-1, d0
	add.b (a2), d0
	moveq.l #0, d1
	move.b 1(a2), d1
	divu.w #10, d6
	swap.w d6
	move.w d6, d2
	swap.w d6
	move.b d7, d3
	bsr.w _DrawChar.l

	tst.w d6
	beq.s .unchanged.l

	moveq.l #0, d0
	move.b #-2, d0
	add.b (a2), d0
	moveq.l #0, d1
	move.b 1(a2), d1
	move.w d6, d2
	move.b d7, d3
	bsr.w _DrawChar.l

.unchanged:
	addq.l #2, a4
	addq.l #2, a2
	dbra.w d4, .display_score.l


	move.l time_render.l, d7
	moveq.l #22, d4
	bsr.w _DrawNum.l
	move.l time_vbl.l, d7
	moveq.l #23, d4
	bsr.w _DrawNum.l
	move.l time_300hz.l, d7
	moveq.l #24, d4
	bsr.w _DrawNum.l

	movea.l screen_rendering.l, a4
	movea.l 4(a4), a0
	move.l colors_spare.l, 4(a4)
	move.l a0, colors_spare.l

	rts

; d0 = x in characters
; d1 = y in characters
; d2 = character to display
; d3 = color (0-3)
_DrawChar:
	movea.l screen_rendering.l, a1
	movea.l (a1), a1
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
	beq.s .bit0clear.l
	move.b d1, (a1)
	bra.s .bit0done.l
.bit0clear:
	clr.b (a1)
.bit0done:
	btst.l #1, d3
	beq.s .bit1clear.l
	move.b d1, 2(a1)
	bra.s .bit1done.l
.bit1clear:
	clr.b 2(a1)
.bit1done:
	lea.l 160(a1), a1
	dbra.w d0, .DrawCharLine
	rts

_DrawNum:
	cmpi.l #10000 * 10000 - 1, d7
	bls.s .InRange
	move.l #10000 * 10000 - 1, d7
.InRange:
	divu.w #10000, d7
	move.l d7, d6
	clr.w d6
	swap.w d6

	divu.w #10, d6
	swap.w d6
	moveq.l #7, d0
	move.l d4, d1
	move.w d6, d2
	moveq.l #1, d3
	bsr.s _DrawChar.l

	clr.w d6
	swap.w d6
	divu.w #10, d6
	swap.w d6
	moveq.l #6, d0
	move.l d4, d1
	move.w d6, d2
	moveq.l #1, d3
	bsr.w _DrawChar.l

	clr.w d6
	swap.w d6
	divu.w #10, d6
	swap.w d6
	moveq.l #5, d0
	move.l d4, d1
	move.w d6, d2
	moveq.l #1, d3
	bsr.w _DrawChar.l

	clr.w d6
	swap.w d6
	divu.w #10, d6
	swap.w d6
	moveq.l #4, d0
	move.l d4, d1
	move.w d6, d2
	moveq.l #1, d3
	bsr.w _DrawChar.l

	moveq.l #0, d6
	move.w d7, d6
	divu.w #10, d6
	swap.w d6
	moveq.l #3, d0
	move.l d4, d1
	move.w d6, d2
	moveq.l #1, d3
	bsr.w _DrawChar.l

	clr.w d6
	swap.w d6
	divu.w #10, d6
	swap.w d6
	moveq.l #2, d0
	move.l d4, d1
	move.w d6, d2
	moveq.l #1, d3
	bsr.w _DrawChar.l

	clr.w d6
	swap.w d6
	divu.w #10, d6
	swap.w d6
	moveq.l #1, d0
	move.l d4, d1
	move.w d6, d2
	moveq.l #1, d3
	bsr.w _DrawChar.l

	clr.w d6
	swap.w d6
	divu.w #10, d6
	swap.w d6
	moveq.l #0, d0
	move.l d4, d1
	move.w d6, d2
	moveq.l #1, d3
	bsr.w _DrawChar.l

	rts

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                          Data For Display                           ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.data

_chars_list:
	.dc.b 11, 2, 0, 1
	.dc.b 12, 2, 0, 1
	.dc.b 13, 2, 0, 1

	.dc.b 12, 4, 1, 2

	.dc.b 8, 6, 6, 3
	.dc.b 10, 6, 6, 4
	.dc.b 12, 6, 6, 5
	.dc.b 14, 6, 6, 6
	.dc.b 16, 6, 6, 7

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

	.dc.b 56, 11, 3, 16
	.dc.b 57, 11, 3, 16
	.dc.b 58, 11, 3, 16
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

_chars_list_end:

_variable_locations:
	.dc.b 64, 16

	.dc.b 8, 7
	.dc.b 10, 7
	.dc.b 12, 7
	.dc.b 14, 7
	.dc.b 16, 7

	.dc.b 64, 0
	.dc.b 64, 1
	.dc.b 64, 2
	.dc.b 64, 3
	.dc.b 64, 4
	.dc.b 64, 5
	.dc.b 64, 6
	.dc.b 64, 7
	.dc.b 64, 8
	.dc.b 64, 9
	.dc.b 64, 10
	.dc.b 64, 11
	.dc.b 64, 12
	.dc.b 64, 13
	.dc.b 64, 14
	.dc.b 64, 15
