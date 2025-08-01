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

DrawStart:
DrawLoop:
	addq.l #1, time_render.l			; Count number of rendered frames

; ###########################
; ##                       ##
; ##  Process ACIA buffer  ##
; ##                       ##
; ###########################

DrawProcessInput:
	lea.l acia_rx_buffer.l, a0			; a0: base address for the buffer
	move.w acia_rx_woffset.l, d7		; d7: offset until which to read

; **********************************
; * Separate combined read / x / y *
; **********************************
	move.l acia_mouse_r_xy.l, d0

; top 10 bits: read offset in words (byte pairs)
	move.l d0, d6
	swap.w d6
	lsr.w #5, d6
	andi.w #$3ff << 1, d6				; d6: offset from which to read, on event boundary

; bottom 11 bits: x coordinate
	move.l d0, d3
	andi.w #$7ff, d3					; d3: mouse x position at beginning of processing

; middle 11 bits: y coordinate
	move.l d0, d4
	lsl.l #5, d4
	swap.w d4
	andi.w #$7ff, d4					; d4: mouse y position at beginning of processing

.NextEvent:
	cmp.w d6, d7						; End of available data?
	beq.w .all_read.l					; Yes: all done
	move.w d6, d5						; d5: current read offset, including partial events

	move.b 0(a0, d5.w), d0				; Read first byte from the event

	addq.w #2, d5						; Advance read location to next byte
	andi.w #IKBD_QUEUE_SIZE - 2, d5		; Wrap within buffer

.CheckJoystick:
	cmpi.b #$fe, d0						; Check if this is a joystick event (fe-ff)
	blo.s .CheckMouse.l					; No: check for another packet type

	cmp.w d5, d7						; End of available data?
	beq.w .all_read.l					; Yes: all done

	; Read extra joystick byte here

	addq.w #2, d5						; Advance read location to next byte
	andi.w #IKBD_QUEUE_SIZE - 2, d5		; Wrap within buffer

	bra.w .EventDone					; This event is done, wrap up and keep processing

.CheckMouse:
	cmpi.b #$f8, d0						; Check if this is a mouse event (f8-fb)
	blo.s .DoKeyboard.l					; No: go to next possible event type

	cmp.w d5, d7						; End of available data?
	beq.w .all_read.l					; Yes: all done

	move.b 0(a0, d5.w), d1				; d1: first mouse extra byte (delta x)

	addq.w #2, d5						; Advance read location to next byte
	andi.w #IKBD_QUEUE_SIZE - 2, d5		; Wrap within buffer

	cmp.w d5, d7						; End of available data?
	beq.w .all_read.l					; Yes: all done

	move.b 0(a0, d5.w), d2				; d2: second mouse extra byte (delta y)

	addq.w #2, d5						; Advance read location to next byte
	andi.w #IKBD_QUEUE_SIZE - 2, d5		; Wrap within buffer

	andi.w #$3, d0						; Top 2 bits of first byte are mouse buttons
	move.w d0, mouse_buttons

	ext.w d1							; Sign-extend delta-x to word
	add.w d3, d1						; Update x accordingly
	bpl.s .OkX1							; Constrain to x >= 0
	moveq.l #0, d1
	bra.s .OkX2
.OkX1:
	cmpi.w #640, d1
	blt.s .OkX2							; Constrain to x <= 639
	move.w #639, d1
.OkX2:
	move.w d1, d3

	ext.w d2							; Sign-extend delta-y to word
	add.w d4, d2						; Update y accordingly
	bpl.s .OkY1							; Constrain to y >= 0
	moveq.l #0, d2
	bra.s .OkY2
.OkY1:
	cmpi.w #200, d2
	blt.s .OkY2							; Constrain to y <= 199
	move.w #199, d2
.OkY2:
	move.w d2, d4

	bra.s .EventDone.l					; This event is done, wrap up and keep processing

.DoKeyboard:
	moveq.l #0, d1						; At this point we're handling a keyboard event
	move.b d0, d1
	andi.b #$7f, d1						; Get the key number (bottom 7 bits of event)
	move.l d1, d2
	andi.w #7, d1						; Key number modulo 8
	lsr.w #3, d2						; Key number / 8
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

.EventDone:
	move.w d5, d6
	andi.w #IKBD_QUEUE_SIZE - 2, d6			; Wrap within buffer
	bra.w .NextEvent
.all_read:

	lsl.w #5, d6
	move.w d6, d0
	swap.w d0

	move.w d3, d0

	swap.w d4
	clr.w d4
	lsr.l #5, d4
	or.l d4, d0

	move.l d0, acia_mouse_r_xy.l

; Check if the mouse is in one of the active zones
	lea.l mouse_zones.l, a0
	lea.l mouse_zones_end.l, a1
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

; Do the actual drawing
	movea.l fb_rendering.l, a0
	moveq.l #0, d0
	move.w #7999, d7
.ClearScreen:
	move.l d0, (a0)+
	dbra.w d7, .ClearScreen.l

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

; d0 = x in characters
; d1 = y in characters
; d2 = character to display
; d3 = color (0-3)
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
