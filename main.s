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
.Loop:
	clr.b (a0)+
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

	move.l #TimerB, $120.w
	move.l #TimerC, $114.w

	move.b #$40,$fffffa17.w

	move.b #$01, $fffffa07.w
	move.b #0, $fffffa0b.w
	move.b #0, $fffffa0f.w
	move.b #$01, $fffffa13.w

	move.b #$20, $fffffa09.w
	move.b #0, $fffffa0d.w
	move.b #0, $fffffa11.w
	move.b #$20, $fffffa15.w

	move.b #0, $fffffa1b.w
	move.b #200, $fffffa21.w
	move.b #$08, $fffffa1b.w

	move.b #0, $fffffa1d.w
	move.b #128, $fffffa23.w
	move.b #$50, $fffffa1d.w

	move.w	#$2300, sr

.Forever:
	bra.s .Forever

VBL:
	move.w bgcolor.l, $ffff8240.w
	addq.w #1, bgcolor.l

	move.b #0, $fffffa1b.w
	move.b #200, $fffffa21.w
	move.b #$08, $fffffa1b.w

	rte

TimerC:
	not.w $ffff8240.w
	rte

TimerB:
	eori.w #$f0, $ffff8240.w
	rte

Reset:
	clr.l $426.l
	move.w d0, $ffff8240.w
	addq.w	#1, d0
	bra.s Reset

	.bss
	.even
bgcolor:
	ds.w	1

_main_bss_end:
	.end
