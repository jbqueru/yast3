; Copyright 2024 Jean-Baptiste M. "JBQ" "Djaybee" Queru
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
; ####                    Atari ST constant definitions                    ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

TRAP_GEMDOS .equ 1
TRAP_XBIOS .equ 14

GEMDOS_TERM0 .equ 0

XBIOS_SUPEXEC .equ 38


VECTOR_RESET_SR .equ $0
VECTOR_RESET_PC .equ $4
VECTOR_ACCESS .equ $8
VECTOR_ADDRESS .equ $c
VECTOR_ILLEGAL .equ $10
VECTOR_DIVZERO .equ $14
VECTOR_CHK .equ $18
VECTOR_TRAPCC .equ $1c
VECTOR_PRIV .equ $20
VECTOR_TRACE .equ $24
VECTOR_LINE_A .equ $28
VECTOR_LINE_F .equ $2c
VECTOR_HBL .equ $68
VECTOR_VBL .equ $70
VECTOR_TRAP0 .equ $80
VECTOR_TRAP1 .equ $84
VECTOR_TRAP2 .equ $88
VECTOR_TRAP3 .equ $8c
VECTOR_TRAP4 .equ $90
VECTOR_TRAP5 .equ $94
VECTOR_TRAP6 .equ $98
VECTOR_TRAP7 .equ $9c
VECTOR_TRAP8 .equ $a0
VECTOR_TRAP9 .equ $a4
VECTOR_TRAP10 .equ $a8
VECTOR_TRAP11 .equ $ac
VECTOR_TRAP12 .equ $b0
VECTOR_TRAP13 .equ $b4
VECTOR_TRAP14 .equ $b8
VECTOR_TRAP15 .equ $bc
VECTOR_MFP_CENTRONICS_BUSY .equ $100
VECTOR_MFP_RS232_DCD .equ $104
VECTOR_MFP_RS232_CTS .equ $108
VECTOR_MFP_BLITTER_DONE .equ $10c
VECTOR_MFP_TIMER_D .equ $110
VECTOR_MFP_TIMER_C .equ $114
VECTOR_MFP_ACIA .equ $118
VECTOR_MFP_FLOPPY .equ $11c
VECTOR_MFP_TIMER_B .equ $120
VECTOR_MFP_RS232_SEND_ERROR .equ $124
VECTOR_MFP_RS232_SEND_EMPTY .equ $128
VECTOR_MFP_RS232_RECV_ERROR .equ $12c
VECTOR_MFP_RS232_RECV_FULL .equ $130
VECTOR_MFP_TIMER_A .equ $134
VECTOR_MFP_RS232_RING .equ $138
VECTOR_MFP_MONO .equ $13c

SYSTEM_RESVALID .equ $426
SYSTEM_RESVECTOR .equ $42a
SYSTEM_RESVALID_MAGIC .equ $31415926

GFX_VBASE_HIGH .equ $ffff8201
GFX_VBASE_MID .equ $ffff8203

GFX_SYNC .equ $ffff820a ; ......px
                        ;       ||
                        ;       |+- external sync (1 = yes)
                        ;       +-- color refresh rate (1 = PAL - 50Hz)
GFX_SYNC_INTERN .equ %00000000
GFX_SYNC_EXTERN .equ %00000001
GFX_SYNC_60HZ .equ %00000000
GFX_SYNC_50HZ .equ %00000010

GFX_COLOR_0 .equ $ffff8240
GFX_COLOR_1 .equ $ffff8242
GFX_COLOR_2 .equ $ffff8244
GFX_COLOR_3 .equ $ffff8246
GFX_COLOR_4 .equ $ffff8248
GFX_COLOR_5 .equ $ffff824a
GFX_COLOR_6 .equ $ffff824c
GFX_COLOR_7 .equ $ffff824e
GFX_COLOR_8 .equ $ffff8250
GFX_COLOR_9 .equ $ffff8252
GFX_COLOR_10 .equ $ffff8254
GFX_COLOR_11 .equ $ffff8256
GFX_COLOR_12 .equ $ffff8258
GFX_COLOR_13 .equ $ffff825a
GFX_COLOR_14 .equ $ffff825c
GFX_COLOR_15 .equ $ffff825e
GFX_PALETTE .equ GFX_COLOR_0
GFX_MODE .equ $ffff8260 ; ......mm
                        ;       ||
                        ;       ++- (0 = 320x200x4@50/60Hz, 1 = 640x200x2@50/60Hz, 2=640x400x1@71Hz)
GFX_MODE_COLOW .equ %00000000
GFX_MODE_COMID .equ %00000001
GFX_MODE_MONO .equ %00000010

PSG_REG .equ $ffff8800
PSG_READ .equ $ffff8800
PSG_WRITE .equ $ffff8802


BLIT_HALFTONE0 .equ $ffff8a00
BLIT_HALFTONE1 .equ $ffff8a02
BLIT_HALFTONE2 .equ $ffff8a04
BLIT_HALFTONE3 .equ $ffff8a06
BLIT_HALFTONE4 .equ $ffff8a08
BLIT_HALFTONE5 .equ $ffff8a0a
BLIT_HALFTONE6 .equ $ffff8a0c
BLIT_HALFTONE7 .equ $ffff8a0e
BLIT_HALFTONE8 .equ $ffff8a10
BLIT_HALFTONE9 .equ $ffff8a12
BLIT_HALFTONE10 .equ $ffff8a14
BLIT_HALFTONE11 .equ $ffff8a16
BLIT_HALFTONE12 .equ $ffff8a18
BLIT_HALFTONE13 .equ $ffff8a1a
BLIT_HALFTONE14 .equ $ffff8a1c
BLIT_HALFTONE15 .equ $ffff8a1e
BLIT_HALFTONE .equ BLIT_HALFTONE0
BLIT_SRC_XINC .equ $ffff8a20
BLIT_SRC_YINC .equ $ffff8a22
BLIT_SRC_ADDR .equ $ffff8a24
BLIT_ENDMASK1 .equ $ffff8a28
BLIT_ENDMASK2 .equ $ffff8a2a
BLIT_ENDMASK3 .equ $ffff8a2c
BLIT_DST_XINC .equ $ffff8a2e
BLIT_DST_YINC .equ $ffff8a30
BLIT_DST_ADDR .equ $ffff8a32
BLIT_XCOUNT .equ $ffff8a36
BLIT_YCOUNT .equ $ffff8a38
BLIT_HOP .equ $ffff8a3a ; ......sh
                        ;       ||
                        ;       |+- 1 = clear bits from halftone
                        ;       +-- 1 = clear bits from source
BLIT_HOP_HTONE .equ %00000001
BLIT_HOP_SRC .equ %00000010
BLIT_OP .equ $ffff8a3b ; ....abcd
                       ;     ||||
                       ;     |||+- 1 = include bits from source and target
                       ;     ||+-- 1 = include bits from source and not target
                       ;     |+--- 1 = include bits from not source and target
                       ;     +---- 1 = include bits from not source and not target
BLIT_OP_ST .equ %00000001
BLIT_OP_SNT .equ %00000010
BLIT_OP_NST .equ %00000100
BLIT_OP_NSNT .equ %00001000
BLIT_HOPOP .equ BLIT_HOP
BLIT_CTRL .equ $ffff8a3c ; bhs.llll
                         ; ||| ||||
                         ; ||| ++++- start line for halftone
                         ; ||+------ 1 = smudge
                         ; |+------- 1 = hog bus
                         ; +-------- 1 = blitter start / busy
BLIT_CTRL_SMUDGE .equ %00100000
BLIT_CTRL_HOG .equ %01000000
BLIT_CTRL_BUSY .equ %10000000
BLIT_SHIFT .equ $ffff8a3d ; if..ssss
                          ; ||  ||||
                          ; ||  ++++- shift amount
                          ; |+------- 0 = include final source read, 1 = no final source read
                          ; +-------- 0 = no initial source read, 1 = include initial source read
BLIT_SHIFT_NISR .equ %00000000
BLIT_SHIFT_IISR .equ %10000000
BLIT_SHIFT_NFSR .equ %01000000
BLIT_SHIFT_IFSR .equ %00000000


MFP_GPDR .equ $fffffa01
MFP_AER .equ $fffffa03
MFP_DDR .equ $fffffa05
MFP_IERA .equ $fffffa07
MFP_IERB .equ $fffffa09
MFP_IPRA .equ $fffffa0b
MFP_IPRB .equ $fffffa0d
MFP_ISRA .equ $fffffa0f
MFP_ISRB .equ $fffffa11
MFP_IMRA .equ $fffffa13
MFP_IMRB .equ $fffffa15
MFP_VR .equ $fffffa17
MFP_TACR .equ $fffffa19
MFP_TBCR .equ $fffffa1b
MFP_TCDCR .equ $fffffa1d
MFP_TADR .equ $fffffa1f
MFP_TBDR .equ $fffffa21
MFP_TCDR .equ $fffffa23
MFP_TDDR .equ $fffffa25
MFP_SCR .equ $fffffa27
MFP_UCR .equ $fffffa29
MFP_RSR .equ $fffffa2b
MFP_TSR .equ $fffffa2d
MFP_UDR .equ $fffffa2f
