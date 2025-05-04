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

; See main.s for more information

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                     Save/restore machine state                      ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

; ##################
; ##              ##
; ##  Save state  ##
; ##              ##
; ##################

	.text

MachineStateSave:
; *******************************
; * Save SR, disable interrupts *
; *******************************
	move.w sr, machine_state_sr.l
	move.w #$2700, sr

; *********************
; * Save reset vector *
; *********************
	move.l SYSTEM_RESVALID.w, machine_state_system_resvalid.l
	move.l SYSTEM_RESVECTOR.w, machine_state_system_resvector.l

; ****************************
; * Save framebuffer address *
; ****************************
	move.b GFX_VBASE_HIGH.w, machine_state_gfx_vbase_high.l
	move.b GFX_VBASE_MID.w, machine_state_gfx_vbase_mid.l
; TODO: save low byte on STe+?
; TODO: save other STe registers?

; ****************
; * Save palette *
; ****************
	movem.l GFX_PALETTE.w, d0-d7
	movem.l d0-d7, machine_state_gfx_palette.l

; **************************
; * Save interrupt vectors *
; **************************
	move.l VECTOR_VBL.w, machine_state_vector_vbl.l
	move.l VECTOR_MFP_TIMER_A.w, machine_state_vector_mfp_timer_a.l
	move.l VECTOR_MFP_TIMER_B.w, machine_state_vector_mfp_timer_b.l
	move.l VECTOR_MFP_TIMER_C.w, machine_state_vector_mfp_timer_c.l
	move.l VECTOR_MFP_ACIA.w, machine_state_vector_mfp_acia.l

; ******************
; * Save MFP state *
; ******************
	move.b MFP_IERA.w, machine_state_mfp_iera.l
	move.b MFP_IERB.w, machine_state_mfp_ierb.l
	move.b MFP_IPRA.w, machine_state_mfp_ipra.l
	move.b MFP_IPRB.w, machine_state_mfp_iprb.l
	move.b MFP_ISRA.w, machine_state_mfp_isra.l
	move.b MFP_ISRB.w, machine_state_mfp_isrb.l
	move.b MFP_IMRA.w, machine_state_mfp_imra.l
	move.b MFP_IMRB.w, machine_state_mfp_imrb.l
	move.b MFP_VR.w, machine_state_mfp_vr.l
	move.b MFP_TACR.w, machine_state_mfp_tacr.l
	move.b MFP_TBCR.w, machine_state_mfp_tbcr.l
	move.b MFP_TCDCR.w, machine_state_mfp_tcdcr.l
	move.b MFP_TADR.w, machine_state_mfp_tadr.l
	move.b MFP_TBDR.w, machine_state_mfp_tbdr.l
	move.b MFP_TCDR.w, machine_state_mfp_tcdr.l
	move.b #192, machine_state_mfp_tcdr.l		; likely system value
; TODO: infer real value of MFP data registers?

; ******************
; * Save PSG state *
; ******************
; TODO: do it

; ******************
; * Save PCM state *
; ******************
; TODO: do it

	rts

; #####################
; ##                 ##
; ##  Restore state  ##
; ##                 ##
; #####################

MachineStateRestore:

; **********************
; * Disable interrupts *
; **********************
	move.w #$2700, sr

; *********************
; * Restore PCM state *
; *********************
	move.b #0, $ffff8901.w		; DMA sound off

; *********************
; * Restore PSG state *
; *********************

; *********************
; * Restore MFP state *
; *********************
	move.b machine_state_mfp_iera.l, MFP_IERA.w
	move.b machine_state_mfp_ierb.l, MFP_IERB.w
	move.b machine_state_mfp_ipra.l, MFP_IPRA.w
	move.b machine_state_mfp_iprb.l, MFP_IPRB.w
	move.b machine_state_mfp_isra.l, MFP_ISRA.w
	move.b machine_state_mfp_isrb.l, MFP_ISRB.w
	move.b machine_state_mfp_imra.l, MFP_IMRA.w
	move.b machine_state_mfp_imrb.l, MFP_IMRB.w
	move.b machine_state_mfp_vr.l, MFP_VR.w
	move.b machine_state_mfp_tacr.l, MFP_TACR.w
	move.b machine_state_mfp_tbcr.l, MFP_TBCR.w
	move.b machine_state_mfp_tcdcr.l, MFP_TCDCR.w
	move.b machine_state_mfp_tadr.l, MFP_TADR.w
	move.b machine_state_mfp_tbdr.l, MFP_TBDR.w
	move.b machine_state_mfp_tcdr.l, MFP_TCDR.w

; *****************************
; * Restore interrupt vectors *
; *****************************
	move.l machine_state_vector_vbl.l, VECTOR_VBL.w
	move.l machine_state_vector_mfp_timer_a.l, VECTOR_MFP_TIMER_A.w
	move.l machine_state_vector_mfp_timer_b.l, VECTOR_MFP_TIMER_B.w
	move.l machine_state_vector_mfp_timer_c.l, VECTOR_MFP_TIMER_C.w
	move.l machine_state_vector_mfp_acia.l, VECTOR_MFP_ACIA.w

; *******************
; * Restore palette *
; *******************
	movem.l machine_state_gfx_palette.l, d0-d7
	movem.l d0-d7, GFX_PALETTE.w

; *******************************
; * Restore framebuffer address *
; *******************************
	move.b machine_state_gfx_vbase_high.l, GFX_VBASE_HIGH.w
	move.b machine_state_gfx_vbase_mid.l, GFX_VBASE_MID.w

; ************************
; * Restore reset vector *
; ************************
	move.l machine_state_system_resvalid.l, SYSTEM_RESVALID.w
	move.l machine_state_system_resvector.l, SYSTEM_RESVECTOR.w

; **************
; * Restore SR *
; **************
	move.w machine_state_sr.l, sr
	rts

; ###########################
; ##                       ##
; ##  Variables for state  ##
; ##                       ##
; ###########################

	.bss
	.even
machine_state_sr:
	.ds.w 1

machine_state_system_resvalid:
	.ds.l 1
machine_state_system_resvector:
	.ds.l 1

machine_state_gfx_palette:
	.ds.w 16

machine_state_vector_vbl:
	.ds.l 1
machine_state_vector_mfp_timer_a:
	.ds.l 1
machine_state_vector_mfp_timer_b:
	.ds.l 1
machine_state_vector_mfp_timer_c:
	.ds.l 1
machine_state_vector_mfp_acia:
	.ds.l 1

machine_state_gfx_vbase_high:
	.ds.b 1
machine_state_gfx_vbase_mid:
	.ds.b 1

machine_state_mfp_iera:
	.ds.b 1
machine_state_mfp_ierb:
	.ds.b 1
machine_state_mfp_ipra:
	.ds.b 1
machine_state_mfp_iprb:
	.ds.b 1
machine_state_mfp_isra:
	.ds.b 1
machine_state_mfp_isrb:
	.ds.b 1
machine_state_mfp_imra:
	.ds.b 1
machine_state_mfp_imrb:
	.ds.b 1
machine_state_mfp_vr:
	.ds.b 1
machine_state_mfp_tacr:
	.ds.b 1
machine_state_mfp_tbcr:
	.ds.b 1
machine_state_mfp_tcdcr:
	.ds.b 1
machine_state_mfp_tadr:
	.ds.b 1
machine_state_mfp_tbdr:
	.ds.b 1
machine_state_mfp_tcdr:
	.ds.b 1
