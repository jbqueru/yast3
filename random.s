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
; ####                    Pseudorandom Number Generator                    ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.text

RandomInit:
	move.l #1, _random_seed.l
	rts

RandomAdvance:
	lsl.w _random_seed + 2.l
	roxl.w _random_seed.l
	bcc.s .bits_done.l
	eori.b #%11000101, _random_seed + 3.l
.bits_done:
	rts

Random:
	move.l _random_seed.l, d1
	moveq.l #%11000101, d2
	move.l d0, d3
.gen_bit:
	lsl.l d1
	bcc.s .bits_done.l
	eor.b d2, d1
.bits_done:
	lsr.l d3
	bne.s .gen_bit.l
	move.l d1, _random_seed.l
	and d1, d0
	rts

	.bss
	.even

_random_seed:
	.ds.l 1
