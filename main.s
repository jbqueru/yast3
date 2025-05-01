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

; Coding style:
;	- ASCII
;	- hard tabs, 8 characters wide, except in ASCII art
;	- 120-ish columns overall
;	- Standalone block comments must fit in the first 80 columns
;
;	- Assembler directives are .lowercase with a leading period
;	- Mnemomics and registers are lowercase unless otherwise required
;	- Symbols for code are CamelCase
;	- Symbols for variables are snake_case
;	- Symbols for app-specific constants are ALL_CAPS
;	- Symbols for OS constants, hardware registers are ALL_CAPS
;	- File-specific symbols start with an underscore
;	- Related symbols start with the same prefix (so they sort together)
;	- Hexadecimal constants are lowercase ($eaf00d).
;
;	- Include but comment out instructions that help readability but
;		don't do anything (e.g. redundant CLC on 6502 when the carry is
;		guaranteed already to be clear). The comment symbol should be
;		where the instruction would be, i.e. not on the first column.
;		There should be an explanation in a comment.
;	- Use the full instruction mnemonic whenever possible, and especially
;		when a shortcut would potentially cause confusion. E.g. use
;		movea instead of move on 680x0 when the code relies on the
;		flags not getting modified.

	.68000

	.bss
_main_bss_start:

	.text

	lea.l _main_bss_start.l, a0
	bra.s .EnterLoop
.Loop:
	clr.b (a0)+
.EnterLoop:
	cmpa.l #_main_bss_end, a0
	bne.s .Loop

	pea.l .MainSuper.l
	move.w #38, -(sp)
	trap #14
	addq.l #6, sp

	move.w #0, -(sp)
	trap #1

.MainSuper:

	move.w #$2700, sr

	move.l #Reset, $42a.w
	move.l #$31415926, $426.w

	move.l #VBL, $70.w

	move.l #TimerA, $134.w
	move.l #TimerB1, $120.w
	move.l #ACIA, $118.w
	move.l #TimerC, $114.w

	move.b #$40,$fffffa17.w		; table at $100, automatic end interrupt

	move.b #0, $fffffa19.w		; stop timer A
	move.b #0, $fffffa1b.w		; stop timer B
	move.b #0, $fffffa1d.w		; stop timers C-D

	move.b #$21, $fffffa07.w	; enable timers A ($20) and B ($01)
	move.b #0, $fffffa0b.w		; nothing pending
	move.b #0, $fffffa0f.w		; nothing in-service
	move.b #$ff, $fffffa13.w	; nothing masked

	move.b #$60, $fffffa09.w	; enable ACIA ($40) and timer C ($20)
	move.b #0, $fffffa0d.w		; nothing pending
	move.b #0, $fffffa11.w		; nothing in-service
	move.b #$ff, $fffffa15.w	; nothing masked

	move.b #1, $fffffa1f.w		; timer A, fire every event
	move.b #$08, $fffffa19.w	; event count

	move.b #128, $fffffa23.w	; timer C, fire every 128 ticks, i.e. 300 Hz
	move.b #$50, $fffffa1d.w	; ticks run at XTAL/64, i.e. 38400 Hz

	move.b #0, $ffff8901.w		; DMA sound off

	move.l #StartSound, d0
	move.l d0, d1
	swap d1
	move.b d1, $ffff8903.w		; high byte of start address, must come first
	move.w d0, d1
	ror.w #8, d1
	move.b d1, $ffff8905.w		; mid byte of start address
	move.b d0, $ffff8907.w		; low byte of start address, must be even

	move.l #EndSound, d0
	move.l d0, d1
	swap d1
	move.b d1, $ffff890f.w		; high byte of end address
	move.w d0, d1
	ror.w #8, d1
	move.b d1, $ffff8911.w		; mid byte of end address
	move.b d0, $ffff8913.w		; low byte of end address

	move.b #$81, $ffff8921.w	; mono ($80), 12517 kHz ($01)
	move.b #$03, $ffff8901.w	; loop ($02), enable ($01)

	move.w	#$2300, sr

.Forever:
	stop #$2300
	bra.s .Forever

VBL:
	clr.w $ffff8240.w

	move.l #TimerB1, $120.w
	move.b #0, $fffffa1b.w
	move.b #92, $fffffa21.w
	move.b #$08, $fffffa1b.w
	move.b #8, $fffffa21.w

	rte

TimerC:
;	eori.w #$400, $ffff8240.w
	rte

TimerB1:
	eori.w #$333, $ffff8240.w
	move.b #100, $fffffa21.w
	move.l #TimerB2, $120.w
	move.b #$01, $fffffa13.w
	move.b #0, $fffffa15.w
	rte

TimerB2:
	eori.w #$333, $ffff8240.w
	move.l #TimerB3, $120.w
	move.b #$ff, $fffffa13.w
	move.b #$ff, $fffffa15.w
	rte

TimerB3:
	eori.w #$333, $ffff8240.w
	rte

TimerA:
;	eori.w #$004, $ffff8240.w
	rte

ACIA:
	tst.b $fffffc02.w
	.rept 512
	nop
	.endr
;	eori.w #$040, $ffff8240.w
	rte

Reset:
	clr.l $426.l
	move.w d0, $ffff8240.w
	addq.w	#1, d0
	bra.s Reset

	.data
	.even
StartSound:
	.dcb.b 250, 0
EndSound:

	.bss

_main_bss_end:
	.end
