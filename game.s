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

CoreStart:
	movea.l screen_display.l, a0
	move.l #_display_state_1, 4(a0)
	movea.l screen_rendering.l, a0
	move.l #_display_state_2, 4(a0)
	movea.l screen_dirty.l, a0
	move.l #_display_state_3, 4(a0)
	move.l #_display_state_4, colors_spare.l

	move.b #1, _game_dice_values.l
	move.b #3, _game_dice_values + 1.l
	move.b #3, _game_dice_values + 2.l
	move.b #4, _game_dice_values + 3.l
	move.b #4, _game_dice_values + 4.l

	move.b #1, _game_dice_locked + 3.l

	move.b #2, _game_line_score.l
	move.b #1, _game_line_locked.l
	move.b #20, _game_line_score + 3.l
	move.b #1, _game_line_locked + 3.l
	move.b #25, _game_line_score + 4.l
	move.b #1, _game_line_locked + 4.l
	move.b #30, _game_line_score + 5.l
	move.b #1, _game_line_locked + 5.l

	move.b #25, _game_line_score + 8.l
	move.b #1, _game_line_locked+ 8.l
	move.b #3, _game_line_locked+ 12.l

_CoreLoop:
	addq.l #1, time_render.l			; Count number of rendered frames

; ###########################
; ##                       ##
; ##  Process ACIA buffer  ##
; ##                       ##
; ###########################

	bsr.w GameInput.l

; ################################
; ##                            ##
; ##  Exit when we're all done  ##
; ##                            ##
; ################################

	btst.b #1, keyboard_state + 7.l
	bne.w _CoreExit.l

; ##################
; ##              ##
; ##  Game logic  ##
; ##              ##
; ##################

	tst.w mouse_buttons.l
	beq.s .clickdone.l
.again:
	moveq.l #7, d0
	bsr.w Random.l
	tst.b d0
	beq.s .again.l
	cmpi.b #7, d0
	beq.s .again.l
	move.b d0, _game_dice_values.l
.clickdone:

_CoreLogic:
; Check if the mouse is in one of the active zones
	lea.l _mouse_zones.l, a0
	lea.l _mouse_zones_end.l, a1
	moveq.l #1, d0

	move.l acia_mouse_r_xy.l, d1
	move.l d1, d2
	andi.w #$7ff, d1
	lsl.l #5, d2
	swap.w d2
	andi.w #$7ff, d2

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

	movea.l colors_spare.l, a0
	moveq.l #25, d0
.ClearColors:
	move.b #1, (a0)+
	dbra.w d0, .ClearColors
	movea.l colors_spare.l, a0
	moveq.l #0, d3
	move.b _core_mouse_over, d3
	beq.s .Zone0
	move.b #2, (a0, d3.w)
.Zone0:

	movea.l colors_spare.l, a0
	lea.l _display_variable_values + 2(a0), a0

	lea.l _game_dice_values.l, a1
	lea.l _game_dice_locked.l, a2
	moveq.l #4, d7
.dieloop:
	move.b (a2)+, d1
	move.b (a1)+, d0
	beq.s .nodie.l
	addq.b #1, d1
	move.b d0, (a0)+
	move.b d1, (a0)+
	bra.s .diedone.l
.nodie:
	move.b #0, (a0)+
	move.b #0, (a0)+
.diedone:
	dbra.w d7, .dieloop.l

	lea.l _game_line_score.l, a1
	lea.l _game_line_locked.l, a2
	moveq.l #5, d7
	moveq.l #0, d0
	moveq.l #0, d1
	moveq.l #0, d2
	moveq.l #0, d3
.valuescore:
	move.b (a1)+, d0
	move.b (a2)+, d1
	add.b d0, d2
	add.b d1, d3
	move.b d0, (a0)+
	move.b d1, (a0)+
	dbra.w d7, .valuescore.l

	move.b d2, (a0)+
	move.b #1, (a0)+

	cmpi.b #63, d2
	bge.s .hasbonus.l
	cmpi.b #6, d3
	bne.s .incomplete.l
	move.b #0, (a0)+
	move.b #1, (a0)+
	bra.s .bonusdone.l
.hasbonus:
	addi.b #35, d2
	move.b #35, (a0)+
	move.b #1, (a0)+
	bra.s .bonusdone.l

.incomplete:
	move.b #0, (a0)+
	move.b #3, (a0)+
.bonusdone:

	move.b d2, (a0)+
	move.b #1, (a0)+

	moveq.l #6, d7
.comboscore:
	move.b (a1)+, d0
	add.w d0, d2
	move.b (a2)+, d1
	move.b d0, (a0)+
	move.b d1, (a0)+
	dbra.w d7, .comboscore.l

	movea.l colors_spare.l, a0
	lea.l _display_variable_values(a0), a0
	move.w d2, (a0)

	bsr.w GameRender.l

; #########################
; ##                     ##
; ##  Swap framebuffers  ##
; ##                     ##
; #########################

_CoreSwapFB:

; Wait until we're not in a critical timing section
	bsr.w InterruptWaitCritical.l

; Mask timer B interrupts, so that the interrupt that swaps physical
; framebuffers doesn't run while we're modifying these variables (which
; would otherwise run the risk of osing track of which framebuffer is
; which since the operation here isn't atomic). This is why we need to
; make sure that we're not in a critical timing section, because in such
; sections the timer B interrupt must be able to fire with extremely
; low latency.
	move.b #$fe, MFP_IMRA.w

; Make the most recently rendered framebuffer ready
; The next framebuffer to render into is whichever
; of ready or dirty is available.
	move.l screen_ready.l, d0
	move.l screen_rendering.l, screen_ready.l
	move.l screen_dirty.l, d1
	bne.s .DeterminedNextFb.l
	move.l d0, d1
.DeterminedNextFb:
	move.l d1, screen_rendering.l
	moveq.l #0, d0
	move.l d0, screen_dirty.l

	move.b #$ff, MFP_IMRA.w

	bra.w _CoreLoop.l

_CoreExit:
	move.w #$2700, sr
	rts


; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                         Data for Animation                          ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.data
	.even
_mouse_zones:
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
_mouse_zones_end:

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                              Variables                              ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.bss

; ###################
; ##               ##
; ##  Input state  ##
; ##               ##
; ###################

	.even

_core_mouse_over:
	.ds.b 1
;_core_mouse_click:
	.ds.b 1

; ##################
; ##              ##
; ##  Game state  ##
; ##              ##
; ##################

	.even

_game_dice_rolls:
	.ds.b 1
_game_dice_values:
	.ds.b 5
_game_dice_locked:
	.ds.b 5

_game_line_score:
	.ds.b 13
_game_line_locked:
	.ds.b 13
_game_yahtzee_bonuses:
	.ds.b 1

; #####################
; ##                 ##
; ##  Display state  ##
; ##                 ##
; #####################

; **************************************
; * Structure that holds display state *
; **************************************
	.abs

; the colors of the zones of fixed text
_display_fixed_colors:
	.ds.b 26

; the values of variable text
_display_variable_values:
; word value, always displayed
	.ds.w 1
; byte values, optional
	.ds.b 21 * 2

_display_state_size:

	.bss
	.even

; ********************************
; * Storage for 4 display states *
; ********************************
	.even
_display_state_1:
	.ds.b _display_state_size
	.even
_display_state_2:
	.ds.b _display_state_size
	.even
_display_state_3:
	.ds.b _display_state_size
	.even
_display_state_4:
	.ds.b _display_state_size

; *******************************************************************
; * Address of the display state that doesn't match any framebuffer *
; *******************************************************************
colors_spare:
	.ds.l 1

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                            Dependencies                             ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.include "input.s"
	.include "render.s"
	.include "font.s"
