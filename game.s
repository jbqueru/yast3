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
	lsl.w #5, d6
	move.w d6, d0
	swap.w d0

; Bottom 11 bits: x coordinate
	move.w d3, d0

; Middle 11 bits: y coordinate
	swap.w d4
	clr.w d4
	lsr.l #5, d4
	or.l d4, d0

	move.l d0, acia_mouse_r_xy.l

; ##################
; ##              ##
; ##  Game logic  ##
; ##              ##
; ##################

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

; #################
; ##             ##
; ##  Rendering  ##
; ##             ##
; #################

_CoreRender:
	lea.l _chars_list.l, a2
	lea.l _chars_list_end.l, a3
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
	bsr.s _DrawChar.l
	cmpa.l a3, a2
	bne.s .loop_chars

	move.l time_render.l, d7
	moveq.l #22, d4
	bsr.w _DrawNum.l
	move.l time_vbl.l, d7
	moveq.l #23, d4
	bsr.w _DrawNum.l
	move.l time_300hz.l, d7
	moveq.l #24, d4
	bsr.w _DrawNum.l

	tst.b keyboard_state+7.l
	bne.s _CoreExit.l

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
	lea.l _font, a0
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

_chars_list_end:

_font:

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
