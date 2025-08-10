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
; ####                     In-game input-handling code                     ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.text
GameInput:

; ###########################
; ##                       ##
; ##  Process ACIA buffer  ##
; ##                       ##
; ###########################

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

	rts
