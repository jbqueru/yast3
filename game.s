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

_CoreProcessInput:
	lea.l acia_rx_buffer.l, a0			; a0: base address for the buffer
	move.w acia_rx_woffset.l, d7		; d7: offset until which to read

; **********************************
; * Separate combined read / x / y *
; **********************************
	move.l acia_mouse_r_xy.l, d0

; Top 10 bits: read offset in words (byte pairs)
	move.l d0, d6
	swap.w d6
	lsr.w #5, d6
	andi.w #$3ff << 1, d6				; d6: offset from which to read, on event boundary
	move.w d6, d5						; d5: current read offset, including partial events

; Bottom 11 bits: x coordinate
	move.l d0, d3
	andi.w #$7ff, d3					; d3: mouse x position at beginning of processing

; Middle 11 bits: y coordinate
	move.l d0, d4
	lsl.l #5, d4
	swap.w d4
	andi.w #$7ff, d4					; d4: mouse y position at beginning of processing

; **************************
; * Start processing event *
; **************************
.StartEvent:
	cmp.w d5, d7						; End of available data?
	beq.w .AllEventsRead.l				; Yes: all done

	move.b 0(a0, d5.w), d0				; Read first byte from the event

	addq.w #2, d5						; Advance read location to next byte
	andi.w #IKBD_QUEUE_SIZE - 2, d5		; Wrap within buffer

; ***********************************
; * Process event if joystick event *
; ***********************************
.CheckJoystick:
	cmpi.b #$fe, d0						; Check if this is a joystick event (fe-ff)
	blo.s .CheckMouse.l					; No: check for another packet type

	cmp.w d5, d7						; End of available data?
	beq.w .AllEventsRead.l				; Yes: all done

	; Joystick data is currently ignored

	addq.w #2, d5						; Advance read location to next byte
	andi.w #IKBD_QUEUE_SIZE - 2, d5		; Wrap within buffer
	move.w d5, d6						; Commit that we have processed this event

	bra.w .StartEvent.l					; This event is done, wrap up and keep processing

; ********************************
; * Process event if mouse event *
; ********************************
.CheckMouse:
	cmpi.b #$f8, d0						; Check if this is a mouse event (f8-fb)
	blo.s .DoKeyboard.l					; No: go to next possible event type

; Read first extra byte of mouse event
	cmp.w d5, d7						; End of available data?
	beq.s .AllEventsRead.l				; Yes: all done

	move.b 0(a0, d5.w), d1				; d1: first mouse extra byte (delta x)

	addq.w #2, d5						; Advance read location to next byte
	andi.w #IKBD_QUEUE_SIZE - 2, d5		; Wrap within buffer

; Read second extra byte of mouse event
	cmp.w d5, d7						; End of available data?
	beq.s .AllEventsRead.l				; Yes: all done

	move.b 0(a0, d5.w), d2				; d2: second mouse extra byte (delta y)

	addq.w #2, d5						; Advance read location to next byte
	andi.w #IKBD_QUEUE_SIZE - 2, d5		; Wrap within buffer
	move.w d5, d6						; Commit that we have processed this event

; Handle mouse buttons
	andi.w #$3, d0						; Top 2 bits of first byte are mouse buttons
	move.w d0, mouse_buttons.l

; Handle mouse x
	ext.w d1							; Sign-extend delta-x to word
	add.w d1, d3						; Update x accordingly
	bpl.s .X_GE_0.l						; Constrain to x >= 0
	moveq.l #0, d3
	bra.s .X_GE_0_LT_640.l
.X_GE_0:
	cmpi.w #640, d3
	blt.s .X_GE_0_LT_640.l				; Constrain to x <= 639
	move.w #639, d3
.X_GE_0_LT_640:

; Handle mouse y
	ext.w d2							; Sign-extend delta-y to word
	add.w d2, d4						; Update y accordingly
	bpl.s .Y_GE_0.l						; Constrain to y >= 0
	moveq.l #0, d4
	bra.s .Y_GE_0_LT_200.l
.Y_GE_0:
	cmpi.w #200, d4
	blt.s .Y_GE_0_LT_200.l				; Constrain to y <= 199
	move.w #199, d4
.Y_GE_0_LT_200:

	bra.w .StartEvent.l					; This event is done, wrap up and keep processing

; **********************************
; * Process default keyboard event *
; **********************************
.DoKeyboard:
	move.w d5, d6						; Commit that we have processed this event

	lea.l keyboard_state.l, a3

	moveq.l #0, d1
	move.b d0, d1
	andi.b #$7f, d1						; Get the key number (bottom 7 bits of event)
	move.l d1, d2
	andi.w #7, d1						; Key number modulo 8
	lsr.w #3, d2						; Key number / 8

	btst.l #7, d0						; Top bit of keyboard event: key release
	bne.s .KeyRelease.l
	bset.b d1, 0(a3, d2.w)				; Set bit that matches pressed key
	bra.s .KeyDone.l
.KeyRelease:
	bclr.b d1, 0(a3, d2.w)				; Clear bit that matches pressed key
.KeyDone:

	bra.w .StartEvent.l

; ********************************************
; * Done all events, recombined read / x / y *
; ********************************************
.AllEventsRead:
; Top 10 bits: read offset in words (byte pairs)
	lsl.w #5, d6				; Shift to top of word, bits 0-5 clear
	swap.w d6					; Then to top of long, bits 16-21 clear

; Bottom 11 bits: x coordinate
	move.w d3, d6				; Straight copy, bits 11-15 + 16-21 clear

; Middle 11 bits: y coordinate
	swap.w d4					; Move to bits 16-26, with bits 27-31 clear
	clr.w d4					; Clear bits 0-15
	lsr.l #5, d4				; Data in bits 11-21
	or.l d4, d6					; Insert into free bits

; Store final result
	move.l d6, acia_mouse_r_xy.l

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

; #################
; ##             ##
; ##  Rendering  ##
; ##             ##
; #################

_CoreRender:
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

	.include "font.s"
