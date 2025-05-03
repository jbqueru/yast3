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

	lea.l mouse_thread_stack_top, a0
	move.l #MouseThread, -(a0)
	move #$2300, -(a0)
	lea.l -64(a0), a0
	move.l a0, mouse_thread_stack

	lea.l yamaha_thread_stack_top, a0
	move.l #YamahaThread, -(a0)
	move #$2300, -(a0)
	lea.l -64(a0), a0
	move.l a0, yamaha_thread_stack

	lea.l pcm_thread_stack_top, a0
	move.l #PcmThread, -(a0)
	move #$2300, -(a0)
	lea.l -64(a0), a0
	move.l a0, pcm_thread_stack

	lea.l core_thread_stack_top, a0
	move.l #CoreThread, -(a0)
	move #$2300, -(a0)
	lea.l -64(a0), a0
	move.l a0, core_thread_stack

	lea.l draw_thread_stack_top, a0
	move.l #DrawThread, -(a0)
	move #$2300, -(a0)
	lea.l -64(a0), a0
	move.l a0, draw_thread_stack

	move.l #idle_stack, current_thread

	move.l #acia_rx_buffer, acia_rx_write.l
	move.l #acia_rx_buffer, acia_rx_read.l

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

	clr.w $ffff8240.w

	move.w #$2300, sr

.Forever:
	stop #$2300
	tst.b thread_exit_all.l
	beq.s .Forever
	stop #$2700

SwitchFromInt:
	move.w d0, -(sp)
	move.w 6(sp), d0
	andi.w #$0700, d0
	cmpi.w #$0400, d0
	beq.w NoSwitch
	move.w (sp)+, d0
	bra.s DoSwitch

SwitchThreads:
	tst.b delay_thread_switch.l
	bne.s SwitchThreads.l
	move.w sr, -(sp)
DoSwitch:
	move.w #$2600, sr
	movem.l d0-a6, -(sp)
	move.l usp, a0
	move.l a0, -(sp)
	move.l current_thread, a0
	move.l sp, (a0)

	tst.b mouse_thread_ready
	beq.s .not_mouse
	lea.l mouse_thread_stack, a0
	bra.s .thread_selected
.not_mouse:

	tst.b yamaha_thread_ready
	beq.s .not_yamaha
	lea.l yamaha_thread_stack, a0
	bra.s .thread_selected
.not_yamaha:

	tst.b pcm_thread_ready
	beq.s .not_pcm
	lea.l pcm_thread_stack, a0
	bra.s .thread_selected
.not_pcm:

	tst.b core_thread_ready
	beq.s .not_core
	lea.l core_thread_stack, a0
	bra.s .thread_selected
.not_core:

	tst.b draw_thread_ready
	beq.s .not_draw
	lea.l draw_thread_stack, a0
	bra.s .thread_selected
.not_draw:

	lea.l idle_stack, a0

.thread_selected:
	move.l (a0),sp
	move.l a0,current_thread
	move.l (sp)+,a0
	move.l a0,usp
	movem.l (sp)+,d0-a6
	rte

NoSwitch:
	move.w (sp)+,d0
	rte

MouseThread:
	movea.l acia_rx_read.l, a0
	movea.l acia_rx_write.l, a1
.NextByte:
	cmpa.l a0, a1
	beq.s .all_read.l
	cmp.b #$39, (a0)+
	seq.b d0
	move.b d0, thread_exit_all.l
	cmpa.l #acia_rx_buffer + 16, a0
	bne.s .NextByte
	lea.l acia_rx_buffer.l, a0
	bra.s .NextByte
.all_read:
	.rept 64
	not.w $ffff8240.w
	.endr
	clr.b mouse_thread_ready.l
	bsr.w SwitchThreads.l
	bra.w MouseThread.l

YamahaThread:
	.rept 64
	eor.w #$770, $ffff8240.w
	.endr
	clr.b yamaha_thread_ready.l
	bsr.w SwitchThreads.l
	bra.w YamahaThread.l

PcmThread:
	lea.l StartSound.l, a0
	move.w #209, d0
.FillAudioBuffer:
	clr.b (a0)+
	eor.w #$004, $ffff8240.w
	dbra.w d0, .FillAudioBuffer.l
	clr.b pcm_thread_ready.l
	bsr.w SwitchThreads.l
	bra.s PcmThread.l

CoreThread:
	move.w #199, d0
.Core:
	eor.w #$400, $ffff8240.w
	dbra.w d0, .Core.l
	clr.b core_thread_ready.l
	bsr.w SwitchThreads.l
	bra.s CoreThread.l

DrawThread:
	move.w #999, d0
.Draw:
	eor.w #$040, $ffff8240.w
	dbra.w d0, .Draw.l
	clr.b draw_thread_ready.l
	bsr.w SwitchThreads.l
	bra.s DrawThread.l

VBL:
	move.l #TimerB1, $120.w
	move.b 0, $fffffa1b.w
	move.b #92, $fffffa21.w
	move.b #$08, $fffffa1b.w
	move.b #8, $fffffa21.w

	move.w #$2300, sr
	bra SwitchFromInt.l

TimerC:
	addq.l #1, timer_c_count
	eori.w #$440, $ffff8240.w
	.rept 122
	nop
	.endr
	eori.w #$440, $ffff8240.w
	subq.b #1, timer_c_d5.l
	bpl.s not_d5
	move.b #4, timer_c_d5.l
	move.b #1, core_thread_ready.l
not_d5:
	subq.b #1, timer_c_d6.l
	bpl.s not_d6
	move.b #5, timer_c_d6.l
	move.b #1, yamaha_thread_ready.l
not_d6:
	bra.w SwitchFromInt.l

TimerB1:
	eori.w #$333, $ffff8240.w
	.rept 122
	nop
	.endr
	eori.w #$333, $ffff8240.w
	move.b #100, $fffffa21.w
	move.l #TimerB2, $120.w
	move.b #$01, $fffffa13.w
	move.b #0, $fffffa15.w
	move.b #1, delay_thread_switch.l
	rte

TimerB2:
	eori.w #$333, $ffff8240.w
	.rept 122
	nop
	.endr
	eori.w #$333, $ffff8240.w
	move.l #TimerB3, $120.w
	move.b #$ff, $fffffa13.w
	move.b #$ff, $fffffa15.w
	clr.b delay_thread_switch.l
	rte

TimerB3:
	addq.l #1, frame_count
	eori.w #$333, $ffff8240.w
	.rept 122
	nop
	.endr
	eori.w #$333, $ffff8240.w
	move.b #1, mouse_thread_ready.l
	move.b #1, draw_thread_ready.l
	bra SwitchFromInt.l

TimerA:
	eori.w #$003, $ffff8240.w
	.rept 122
	nop
	.endr
	eori.w #$003, $ffff8240.w
	move.b #1, pcm_thread_ready.l
	bra.w SwitchFromInt.l

ACIA:
	eori.w #$444, $ffff8240.w
	btst.b #0, $fffffc00.w
	beq.s .NotRx.l
	move.l a0, -(sp)
	move.l acia_rx_write.l, a0
	move.b $fffffc02.w, (a0)+
	cmpa.l #acia_rx_buffer + 16, a0
	bne.s .InBuffer
	lea.l acia_rx_buffer, a0
.InBuffer:
	move.l a0, acia_rx_write.l
	move.l (sp)+, a0
.NotRx:
	.rept 512
	nop
	.endr
	eori.w #$444, $ffff8240.w
	rte

Reset:
	clr.l $426.l
	move.w d0, $ffff8240.w
	addq.w	#1, d0
	bra.s Reset

	.data
	.even
StartSound:
	.dcb.b 210, 0
EndSound:

	.bss

	.even
current_thread:
	ds.l 1

mouse_thread_stack:
	.ds.l 251
mouse_thread_stack_top:

yamaha_thread_stack:
	.ds.l 251
yamaha_thread_stack_top:

pcm_thread_stack:
	.ds.l 251
pcm_thread_stack_top:

core_thread_stack:
	.ds.l 251
core_thread_stack_top:

draw_thread_stack:
	.ds.l 251
draw_thread_stack_top:

idle_stack:
	ds.l 1

acia_rx_write:
	.ds.l 1
acia_rx_read:
	.ds.l 1

timer_c_count:
	.ds.l 1
frame_count:
	.ds.l 1

mouse_thread_ready:
	.ds.b 1
yamaha_thread_ready:
	.ds.b 1
pcm_thread_ready:
	.ds.b 1
core_thread_ready:
	.ds.b 1
draw_thread_ready:
	.ds.b 1

delay_thread_switch:
	.ds.b 1

thread_exit_all:
	.ds.b 1

timer_c_d5:
	.ds.b 1
timer_c_d6:
	.ds.b 1

acia_rx_buffer:
	.ds.b 16

_main_bss_end:
	.end
