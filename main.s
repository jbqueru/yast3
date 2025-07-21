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

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                                                                     ####
; ####                                                                     ####
; ####                 YY  YY   AA    SSSS  TTTTTT  3333                   ####
; ####                 YY  YY  AAAA  SS  SS   TT   33  33                  ####
; ####                 YY  YY AA  AA SS       TT       33                  ####
; ####                  YYYY  AA  AA  SSSS    TT     333                   ####
; ####                   YY   AAAAAA     SS   TT       33                  ####
; ####                   YY   AA  AA SS  SS   TT   33  33                  ####
; ####                   YY   AA  AA  SSSS    TT    3333                   ####
; ####                                                                     ####
; ####                                                                     ####
; ####                    A DICE GAME FOR THE ATARI STE                    ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                            Coding style                             ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

;	- ASCII
;	- hard tabs, 8 characters wide, except in ASCII art
;	- 120-ish columns overall
;	- Standalone block comments should fit in the first 80 columns
;
;	- Assembler directives are .lowercase with a leading period
;	- Mnemomics and registers are lowercase unless otherwise required
;	- Symbols for code are CamelCase
;	- Symbols for data and variables are snake_case
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

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                  OS interactions / initializations                  ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.68000

	.include "defines.s"
	.include "params.s"

; #########################
; ##                     ##
; ##  BSS guard address  ##
; ##                     ##
; #########################

	.bss
_main_bss_start:		; Guard to know where BSS starts and ends
						; TODO: investigate getting that from OS API
						; WARN: OS API might be unreliable with compression

	.text

_Main:

; TODO: Return memory to OS as needed

; #################
; ##             ##
; ##  Clear BSS  ##
; ##             ##
; #################

; TODO: Optimize

	lea.l _main_bss_start.l, a0
.ClearBssLoop:
	clr.b (a0)+
	cmpa.l #_main_bss_end, a0
	bne.s .ClearBssLoop.l

; #################################
; ##                             ##
; ##  Switch to supervisor mode  ##
; ##                             ##
; #################################

	pea.l _MainSuper.l
	move.w #XBIOS_SUPEXEC, -(sp)
	trap #TRAP_XBIOS
	addq.l #6, sp

; ####################
; ##                ##
; ##  Exit program  ##
; ##                ##
; ####################

	move.w #GEMDOS_TERM0, -(sp)
	trap #TRAP_GEMDOS

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####         Setup before turning interrupts / multithreading on         ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.text

_MainSuper:
; ##########################
; ##                      ##
; ##  Save machine state  ##
; ##                      ##
; ##########################

	jsr MachineStateSave.l

; ################################
; ##                            ##
; ##  Get A/V to a clean state  ##
; ##                            ##
; ################################

; *****************
; * Clear palette *
; *****************
	moveq.l #0, d0
	lea.l $ffff8240.w, a0
	moveq.l #15, d7
.ClearPalette:
	move.w d0, (a0)+
	dbra.w d7, .ClearPalette.l

; ************
; * Stop PSG *
; ************
; TODO: do it!

; ************
; * Stop PCM *
; ************
	move.b #0, $ffff8901.w		; DMA sound off

; ***************************************
; * Get framebuffer addresses, clear FB *
; ***************************************

	moveq.l #0, d0
	move.b $ffff8201.w, d0
	lsl.l #8, d0
	move.b $ffff8203.w, d0
	lsl.l #8, d0
	move.l d0, fb_display.l					; the address of the OS framebuffer

	move.l #framebuffers + 255, d0
	clr.b d0
	move.l d0, fb_rendering.l				; the first of our framebuffers
	add.l #32000, d0
	move.l d0, fb_dirty.l					; the second of our framebuffers

	movea.l fb_display.l, a0
	move.w #7999, d7
	moveq.l #0, d0
.ClearFB:
	move.l d0, (a0)+
	dbra.w d7, .ClearFB.l

; ###############################################
; ##                                           ##
; ##  Prepare variables to support interrupts  ##
; ##                                           ##
; ###############################################

; **********************************
; * Buffer addresses for IKBD data *
; **********************************

	move.l #acia_rx_buffer, acia_rx_write.l
	move.l #acia_rx_buffer, acia_rx_read.l

; ************************
; * Set up thread system *
; ************************

	lea.l _stack_mouse_top.l, a0
	clr.w -(a0)							; 68020-style frame. TODO: make conditional
	move.l #_ThreadEntryMouse, -(a0)	; return address = thread start
	move.w #$2300, -(a0)				; SR
	lea.l -64(a0), a0					; D0-A6/USP
	move.l a0, _thread_stack_mouse.l

	lea.l _stack_sound_top.l, a0
	clr.w -(a0)
	move.l #_ThreadEntrySound, -(a0)
	move.w #$2300, -(a0)
	lea.l -64(a0), a0
	move.l a0, _thread_stack_sound.l

; TODO: Add a background thread

	move.l #_thread_stack_core, _thread_current.l

; #####################################
; ##                                 ##
; ##  Set up interrupts and vectors  ##
; ##                                 ##
; #####################################

	move.l #Reset, SYSTEM_RESVECTOR.w
	move.l #SYSTEM_RESVALID_MAGIC, SYSTEM_RESVALID.w

	move.l #_Interrupt_Vertical_Blank, VECTOR_VBL.w

	move.l #TimerA, VECTOR_MFP_TIMER_A.w
	move.l #_Interrupt_End_Line_92, VECTOR_MFP_TIMER_B.w
	move.l #ACIA, VECTOR_MFP_ACIA.w
	move.l #_Interrupt_300Hz, VECTOR_MFP_TIMER_C.w

	move.b #$40,MFP_VR.w		; table at $100, automatic end interrupt

	move.b #0, MFP_TACR.w		; stop timer A
	move.b #0, MFP_TBCR.w		; stop timer B
	move.b #0, MFP_TCDCR.w		; stop timers C-D

	move.b #$21, MFP_IERA.w		; enable timers A ($20) and B ($01)
	move.b #0, MFP_IPRA.w		; nothing pending
	move.b #0, MFP_ISRA.w		; nothing in-service
	move.b #$ff, MFP_IMRA.w		; nothing masked

	move.b #$60, MFP_IERB.w		; enable ACIA ($40) and timer C ($20)
	move.b #0, MFP_IPRB.w		; nothing pending
	move.b #0, MFP_ISRB.w		; nothing in-service
	move.b #$ff, MFP_IMRB.w		; nothing masked

	move.b #1, MFP_TADR.w		; timer A, fire every event
	move.b #$08, MFP_TACR.w		; event count

	move.b #128, MFP_TCDR.w		; timer C, fire every 128 ticks, i.e. 300 Hz
	move.b #$50, MFP_TCDCR.w	; ticks run at XTAL/64, i.e. 38400 Hz

; ############################################
; ##                                        ##
; ##  Start things up that need interrupts  ##
; ##                                        ##
; ############################################

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

	clr.w $ffff8240.w
	move.w #$777, $ffff8242.w

	tst.b $fffffc02.w

; #################################
; ##                             ##
; ##  All setup done, get going  ##
; ##                             ##
; #################################

	move.l sp, a0					; remember old stack
	move.l #_stack_core_top, sp		; set stack to reserved area
	move.l a0, -(sp)				; store old stack value
	move.w #$2300, sr				; start interrupts, off we go!!!
	bsr.w _ThreadEntryCore.l		; run the core loop

; ######################
; ##                  ##
; ##  Restore system  ##
; ##                  ##
; ######################

	move.l (sp)+, sp				; restore the old stack
	bsr.w MachineStateRestore.l		;
	rts

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                         Interrupt handling                          ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

; ####################################################################
; ##                                                                ##
; ##  300Hz Heartbeat, running from MFP timer C, interrupt level 6  ##
; ##                                                                ##
; ####################################################################

_Interrupt_300Hz:
	addq.l #1, interrupt_ticks_300hz			; increment count of 300Hz time base
.if ^^defined DEBUG_COLOR_SHOW_TIMER_C
	eori.w #DEBUG_COLOR_SHOW_TIMER_C, GFX_COLOR_0.w
	.rept 122
	nop
	.endr
	eori.w #DEBUG_COLOR_SHOW_TIMER_C, GFX_COLOR_0.w
.endif
	bra.w SwitchFromInt.l

; ############################################
; ##                                        ##
; ##  Vertical blank, autovectored level 4  ##
; ##                                        ##
; ############################################

; While this is technical the vblank interrupt, in practice, we run
; most typical vblank tasks at the end of the last visible line,
; called _Interrupt_End_Line_200. Running at the end of line 200
; allows us to swap the base framebuffer address before it gets
; latched (it's too late during vblank), and gives us more time to
; run things before the first line of the next frame, such as
; displaying the mouse pointer.
; Vblank still exists to prevent drift in end-of-line interrupts,
; and to change the palette at a point that is invisible.

_Interrupt_Vertical_Blank:
	move.l #_Interrupt_End_Line_92, VECTOR_MFP_TIMER_B.w		; handler for the first line interrupt that'll fire
	move.b #$00, MFP_TBCR.w						; turn timer off
	move.b #92, MFP_TBDR.w						; count 92 ticks. written both to data and main register, since timer is off
	move.b #$08, MFP_TBCR.w						; turn timer on, event counting mode
	move.b #8, MFP_TBDR.w						; write to data register. written only to data register, since timer is on

	move.w #$102, GFX_COLOR_0.w
	move.w #$574, GFX_COLOR_1.w
	move.w #$607, GFX_COLOR_2.w
	move.w #$334, GFX_COLOR_3.w

	move.w #$2300, sr							; lower interrupt level so that the thread switching code isn't suppressed
												; TODO: jump to a point where the suppression is ineffective
	bra SwitchFromInt.l							; switch threads in case a thread-switching interrupt fired on top of us
												; TODO: only switch if there is a switch pending

; ################################################################
; ##                                                            ##
; ##  End of visible line, from MFP timer B, interrupt level 6  ##
; ##                                                            ##
; ################################################################

; ***********
; * Line 92 *
; ***********

_Interrupt_End_Line_92:
.if ^^defined DEBUG_COLOR_SHOW_TIMER_B
	eori.w #DEBUG_COLOR_SHOW_TIMER_B, GFX_COLOR_0.w
	.rept 122
	nop
	.endr
	eori.w #DEBUG_COLOR_SHOW_TIMER_B, GFX_COLOR_0.w
.endif

	move.b #100, MFP_TBDR.w							; number of lines between next interrupt and subsequent one
	move.l #_Interrupt_End_Line_100, VECTOR_MFP_TIMER_B.w	; handler for next interrupt
	move.b #$01, MFP_IMRA.w							; mask away all interrupts except timer B, so that the next
	move.b #$00, MFP_IMRB.w							; 			interrupt has a precise timing
	move.b #1, delay_thread_switch.l				; tell the scheduler not to reschedule yet
	rte

; ************
; * Line 100 *
; ************

_Interrupt_End_Line_100:
.if ^^defined DEBUG_COLOR_SHOW_TIMER_B
	eori.w #DEBUG_COLOR_SHOW_TIMER_B, GFX_COLOR_0.w
	.rept 122
	nop
	.endr
	eori.w #DEBUG_COLOR_SHOW_TIMER_B, GFX_COLOR_0.w
.endif

	move.l #_Interrupt_End_Line_200, VECTOR_MFP_TIMER_B.w
	move.b #$ff, MFP_IMRA.w							; unmask all interrupts back in
	move.b #$ff, MFP_IMRB.w
	clr.b delay_thread_switch.l						; tell the scheduler to so its things again
	rte

; ************
; * Line 200 *
; ************

_Interrupt_End_Line_200:
.if ^^defined COLOR_SHOW_TIMER_B
	eori.w #DEBUG_COLOR_SHOW_TIMER_B, GFX_COLOR_0.w
	.rept 122
	nop
	.endr
	eori.w #DEBUG_COLOR_SHOW_TIMER_B, GFX_COLOR_0.w
.endif

	addq.l #1, frame_count							; increment frame counter

	move.l d0, -(sp)

	move.l fb_ready.l, d0							; check if framebuffers ready to swap
	beq.s .DoneFbSwap
	move.l fb_display.l, fb_dirty.l					; the framebuffer that was displayed is now dirty
	move.l d0, fb_display.l							; the framebuffer that was ready is now the one getting displayed

	lsr.w #8, d0									; set the live framebuffer address into the GPU
	move.b d0, $ffff8203.w
	swap.w d0
	move.b d0, $ffff8201.w

	moveq.l #0, d0
	move.l d0, fb_ready.l							; there's no framebuffer ready

	.DoneFbSwap:
	move.l (sp)+, d0
	move.b #1, _thread_ready_mouse.l				; unblock mouse thread, to update mouse cursor
	bra.s SwitchFromInt.l							; switch threads

; #####################################################################
; ##                                                                 ##
; ##  End of DMA for PCM sound, from MFP timer A, interrupt level 6  ##
; ##                                                                 ##
; #####################################################################

TimerA:
.if ^^defined COLOR_SHOW_TIMER_A
	eori.w #DEBUG_COLOR_SHOW_TIMER_A, GFX_COLOR_0.w
	.rept 122
	nop
	.endr
	eori.w #DEBUG_COLOR_SHOW_TIMER_A, GFX_COLOR_0.w
.endif
	move.b #1, _thread_ready_sound.l
	bra.s SwitchFromInt.l

; ###############################################
; ##                                           ##
; ##  ACIA, from MFP GPIP4, interrupt level 6  ##
; ##                                           ##
; ###############################################

ACIA:
.if ^^defined DEBUG_COLOR_SHOW_ACIA
	eori.w #DEBUG_COLOR_SHOW_ACIA, GFX_COLOR_0.w
.endif
	btst.b #0, $fffffc00.w
	beq.s .NotRx.l
	move.l a0, -(sp)
	move.l acia_rx_write.l, a0
	move.b $fffffc02.w, (a0)+
	cmpa.l #acia_rx_buffer + 48, a0
	bne.s .InBuffer
	lea.l acia_rx_buffer, a0
.InBuffer:
	move.l a0, acia_rx_write.l
	move.l (sp)+, a0
.NotRx:
.if ^^defined DEBUG_COLOR_SHOW_ACIA
	.rept 512
	nop
	.endr
	eori.w #DEBUG_COLOR_SHOW_ACIA, GFX_COLOR_0.w
.endif
	rte

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                          Thread management                          ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

SwitchFromInt:			; TODO: rename, make private
	move.w d0, -(sp)
	move.w 2(sp), d0
	andi.w #$0700, d0
	cmpi.w #$0400, d0
	beq.s NoSwitch
	move.w (sp)+, d0
	bra.s DoSwitch

SwitchThreads:			; TODO: rename
	tst.b delay_thread_switch.l
	bne.s SwitchThreads.l
	move.w sr, -(sp)
	tst.w $59e.w
	beq.s .shortframe
	subq.l #2, sp
	move.w 2(sp), (sp)
	move.w 4(sp), 2(sp)
	move.w 6(sp), 4(sp)
	clr.w 6(sp)
.shortframe:
DoSwitch:			; TODO: rename, make private, re-oder code to make local
	move.w #$2600, sr
	movem.l d0-a6, -(sp)		; TODO: don't save on yield
	move.l usp, a0
	move.l a0, -(sp)
	move.l _thread_current.l, a0
	move.l sp, (a0)

	tst.b _thread_ready_mouse
	beq.s .not_mouse
	lea.l _thread_stack_mouse, a0
	bra.s .thread_selected
.not_mouse:

	tst.b _thread_ready_sound
	beq.s .not_pcm
	lea.l _thread_stack_sound, a0
	bra.s .thread_selected
.not_pcm:

	lea.l _thread_stack_core, a0

.thread_selected:
	move.l (a0),sp
	move.l a0,_thread_current
	move.l (sp)+,a0
	move.l a0,usp
	movem.l (sp)+,d0-a6
	rte

NoSwitch:
	move.w (sp)+,d0
	rte

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                         Thread entry points                         ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.text

_ThreadEntryMouse:
	movea.l acia_rx_read.l, a0
	movea.l acia_rx_write.l, a2
.NextPacket:
	cmpa.l a0, a2
	beq.w .all_read.l
	movea.l a0, a1

	move.b (a1)+, d0
	cmpa.l #acia_rx_buffer + 48, a1
	bne.s .NB1.l
	lea.l -48(a1), a1
.NB1:

	cmpi.b #$fe, d0
	blo.s .NotJoy.l
	cmpa.l a1, a2
	beq.w .all_read.l
	move.b (a1)+, d1
	bra.w .PacketDone

.NotJoy:
	cmpi.b #$f8, d0
	blo.s .NotMouse.l

	cmpa.l a1, a2
	beq.w .all_read.l
	move.b (a1)+, d1
	cmpa.l #acia_rx_buffer + 48, a1
	bne.s .NB2.l
	lea.l -48(a1), a1
.NB2:

	cmpa.l a1, a2
	beq.w .all_read.l
	move.b (a1)+, d2

	andi.w #$3, d0
	move.w d0, mouse_buttons

	ext.w d1
	add.w mouse_x, d1
	bpl.s .OkX1
	moveq.l #0, d1
	bra.s .OkX2
.OkX1:
	cmpi.w #640, d1
	blt.s .OkX2
	move.w #639, d1
.OkX2:
	move.w d1, mouse_x

	ext.w d2
	add.w mouse_y, d2
	bpl.s .OkY1
	moveq.l #0, d2
	bra.s .OkY2
.OkY1:
	cmpi.w #200, d2
	blt.s .OkY2
	move.w #199, d2
.OkY2:
	move.w d2, mouse_y

	bra.s .PacketDone.l

.NotMouse:
	moveq.l #0, d1
	move.b d0, d1
	andi.b #$7f, d1
	move.l d1, d2
	andi.w #7, d1
	lsr.w #3, d2
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

.PacketDone:
	movea.l a1, a0
	cmpa.l #acia_rx_buffer + 48, a0
	bne.w .NextPacket
	lea.l -48(a0), a0
	bra.w .NextPacket
.all_read:
	move.l a0, acia_rx_read.l
.if ^^defined DEBUG_COLOR_SHOW_MOUSE
	eori.w #DEBUG_COLOR_SHOW_MOUSE, GFX_COLOR_0.w
.endif

	movea.l fb_display.l, a0
	move.w mouse_y, d0
	cmpi.w #183, d0
	blt.s .InSY
	move.w #183, d0
.InSY:
	mulu.w #160, d0
	adda.w d0, a0
	move.w mouse_x, d0
	cmpi.w #623, d0
	blt.s .InSX
	move.w #623, d0
.InSX:
	move.w d0, d1
	andi.w #$fff0, d0
	lsr.w #2, d0
	adda.w d0, a0
	andi.w #$f, d1
	lea.l mouse_mask.l, a1
	lea.l mouse_pattern.l, a2
	moveq.l #16, d7
.DrawMouse:
	move.l (a1)+, d0
	ror.l d1, d0
	and.w d0, 4(a0)
	and.w d0, 6(a0)
	swap.w d0
	and.w d0, (a0)
	and.w d0, 2(a0)
	move.l (a2)+, d0
	ror.l d1, d0
	or.w d0, 4(a0)
	swap.w d0
	or.w d0, (a0)
	lea 160(a0), a0
	dbra.w d7, .DrawMouse.l
.if ^^defined DEBUG_COLOR_SHOW_MOUSE
	eori.w #DEBUG_COLOR_SHOW_MOUSE, GFX_COLOR_0.w
.endif

	clr.b _thread_ready_mouse.l
	bsr.w SwitchThreads.l
	bra.w _ThreadEntryMouse.l

_ThreadEntrySound:
	lea.l StartSound.l, a0
	move.w #209, d0
.FillAudioBuffer:
	clr.b (a0)+
.if ^^defined DEBUG_COLOR_SHOW_PCM
	eori.w #$004, GFX_COLOR_0.w
.endif
	dbra.w d0, .FillAudioBuffer.l
	clr.b _thread_ready_sound.l
	bsr.w SwitchThreads.l
	bra.s _ThreadEntrySound.l

_ThreadEntryCore:
	bra.w DrawStart.l

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                            Reset vector                             ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

	.text
Reset:
	jsr MachineStateRestoreReset.l

	move.w d0, $ffff8240.w
	addq.w	#1, d0
	bra.s Reset

	.data
	.even
StartSound:
	.dcb.b 250, 0
EndSound:

mouse_mask:
	.dc.l %00000001111111111111111111111111
	.dc.l %00000001111111111111111111111111
	.dc.l %00000001111111111111111111111111
	.dc.l %00000111111111111111111111111111
	.dc.l %00000011111111111111111111111111
	.dc.l %00010001111111111111111111111111
	.dc.l %00011000111111111111111111111111
	.dc.l %11111100011111111111111111111111
	.dc.l %11111110001111111111111111111111
	.dc.l %11111111000111111111111111111111
	.dc.l %11111111100011111111111111111111
	.dc.l %11111111110001111111111111111111
	.dc.l %11111111111000111111111111111111
	.dc.l %11111111111100011111111111111111
	.dc.l %11111111111110001111111111111111
	.dc.l %11111111111111000111111111111111
	.dc.l %11111111111111100111111111111111

mouse_pattern:
	.dc.l %00000000000000000000000000000000
	.dc.l %01111100000000000000000000000000
	.dc.l %01100000000000000000000000000000
	.dc.l %01010000000000000000000000000000
	.dc.l %01001000000000000000000000000000
	.dc.l %01000100000000000000000000000000
	.dc.l %00000010000000000000000000000000
	.dc.l %00000001000000000000000000000000
	.dc.l %00000000100000000000000000000000
	.dc.l %00000000010000000000000000000000
	.dc.l %00000000001000000000000000000000
	.dc.l %00000000000100000000000000000000
	.dc.l %00000000000010000000000000000000
	.dc.l %00000000000001000000000000000000
	.dc.l %00000000000000100000000000000000
	.dc.l %00000000000000010000000000000000
	.dc.l %00000000000000000000000000000000

	.bss

	.even

_thread_current:
	ds.l 1

_thread_stack_mouse:
	ds.l 1
_thread_stack_sound:
	ds.l 1
_thread_stack_core:
	ds.l 1

_stack_mouse:
	.ds.l STACK_SIZE_MOUSE
_stack_mouse_top:

_stack_sound:
	.ds.l STACK_SIZE_SOUND
_stack_sound_top:

_stack_core:
	.ds.l STACK_SIZE_CORE
_stack_core_top:

acia_rx_write:
	.ds.l 1
acia_rx_read:
	.ds.l 1

;TODO: rename for consistency
frame_count:
	.ds.l 1
interrupt_ticks_300hz:
	.ds.l 1

fb_display:
	.ds.l 1
fb_ready:
	.ds.l 1
fb_rendering:
	.ds.l 1
fb_dirty:
	.ds.l 1

mouse_buttons:
	.ds.w 1
mouse_x:
	.ds.w 1
mouse_y:
	.ds.w 1

_thread_ready_mouse:
	.ds.b 1
_thread_ready_sound:
	.ds.b 1

delay_thread_switch:
	.ds.b 1

acia_rx_buffer:
	.ds.b 48

keyboard_state:
	.ds.b 16

framebuffers:
	.ds.b 64255

.include "machine_state.s"
.include "game.s"

; #############################################################################
; #############################################################################
; ####                                                                     ####
; ####                                                                     ####
; ####                         That's all, folks!                          ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

; #########################
; ##                     ##
; ##  BSS guard address  ##
; ##                     ##
; #########################

	.bss
_main_bss_end:
	.end
