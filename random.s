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

; This is a 32-bit Galois Linear Shift Feedback Register (LFSR),
; shifting left, with taps at bits 2, 6, and 7. This is known to
; be a maximum-cycle Galois LFSR.

	.text

; ######################
; ##                  ##
; ##  Initialization  ##
; ##                  ##
; ######################

; Call this routine early with outside sources of randomness

; Inputs: d0: seed
; Outputs: none
; Modifies: none

RandomInit:
	move.l d0, _random_seed.l
	bne.s .seedOK.l
	move.b #1, _random_seed + 3.l
.seedOK:
	rts

; ####################
; ##                ##
; ##  Advance PRNG  ##
; ##                ##
; ####################

; Call this routine from interrupts that use different time sources

; Inputs: none
; Outputs: none
; Modifies: none

; Note: this routine isn't re-entrant, so it should only be called
; from interrupt handlers that are all at level 6, since such interrupt
; handlers don't interrupt one another.

RandomAdvance:
	lsl.w _random_seed + 2.l
	roxl.w _random_seed.l
	bcc.s .bits_done.l
	eori.b #%11000101, _random_seed + 3.l
.bits_done:
	rts

; ##################
; ##              ##
; ##  Query PRNG  ##
; ##              ##
; ##################

; Call this routine when a new pseudo-random number is needed

; Inputs: d0: bit mask containing the size of the value needed
; Outputs: d0: pseudo-random number, between 0 and mask
; Modifies: d1-d3

; Note: the global seed is read in a single instruction and written
; in a single instruction, such that it is safe for this call to be
; interrupted or pre-empted, where the risk is merely that some seed
; updates get ignored, i.e. that, possibly, two threads requesting
; random data at the same time might get the same bits.

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

; #################
; ##             ##
; ##  Variables  ##
; ##             ##
; #################

	.bss
	.even

_random_seed:
	.ds.l 1
