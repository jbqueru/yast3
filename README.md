# yast3
A dice-combo game for Atari ST

This is a game for the Atari ST family, developed by Djaybee and
Pandafox from the MegaBuSTers, in collaboration with AD from MPS.

The primary target is the STe, with a degraded experience down
to the plain ST. While the 12-bit palette naturally degrades into
a 9-bit one and DMA sound can be turned into silence, Blitter and
hardware scrolling need some fallbacks.

It's been developed with rmac 2.2.25 and tested under Hatari
v2.6.0-devel with EmuTOS 1.3.

# Timeline and design thoughts

## Apr 25 2025
Pandafox suggests building a game, a dice game in
a well-known family, but with an added strategic twist.
He and Djaybee agree on proceeding, with two specific goals:
-Using graphical effects to augment the game experience.
-Later targeting multiple platforms, with Android a stretch goal.

Discussions ensued over several days whether to target ST or STe.
Polls on social media suggested that ~92% of users expect the STe
to get an optimized experience. Within those, 6% want the ST to
also get a great experience, while 74% would accept a degraded
experience and 20% would accept having to ST version at all.

## Apr 28 2025
Notes from Pandafox:

(See design mockup)

For each scoring throw, gain as many coins as total dice pips.

At any time, those coins can be used to purchase modules
or boosters.

Modules get added before each throw, e.g. a red-6 module
increases the odds of rolling a 6. green-$ doubles the number
of coins.

Boosters are general bonuses.

The design on the top-right changes with each level, as well
as the general design.

Ultimately, there are no scores, but successful games can unlock
new modules or new boosters for future games. That can be saved
as parameters or (Djaybee suggestion) exposed as a code. That
way, there's some replay value.

## Apr 29 2025

Interrupts:
-VBL + Timer B: direct GPU handling. Primarily around page-flipping
after line 200, might also be useful for mid-screen palette change,
with caveats around interrupt latency.
-Timer C: timekeeping, multitasking backstop.
-Timer A: PCM sound
-ACIA: IKBD

## Apr 30 2025

### Interrupts, take 1

At full speed (i.e. when moving the mouse), there are about
780 ACIA IKBD packets per second. Waking up a task that often
seems unnecessary, especially since in the stress case 2/3 of
those bytes aren't enough to make a whole packet yet. Instead,
buffering the bytes and only waking up the task where there's
a whole packet makes sense.

### Interrupts, take 2

That being said, in the big picture, there's a challenge: a
cheap implementation of timer B is sensitive to timing. A more
advanced implementation of timer B might be able to withstand
some timing variations, has to pay the cost of the worst-case
scenario for every single interrupt (fire early and poll until
the expected location). Now, by varying the packet length,
timer A can be made only to fire during vblank. Similarly,
by varying the timer data register, timer C can be made only to
fire during vblank. That avoids the collisions between those
and timer B. Obviously, VBL and timer B don't collide. That leaves
the ACIA, whose timing can't be entirely controlled, but whose
impact can be minimized. If the ACIA interrupt merely gets the
necessary byte out of the buffer and then returns without ever
switching tasks, the impact on timer B is minimized, at least to
the point where timer B might only need 1 extra line of sync if
it wants to be near-perfect. The buffer of ACIA bytes can then
be handled by a tasks that fires from another interrupt, most
probably timer C.

### Interrupts, take 3

Timer B firing on the last line of the frame is the heartbeat of
graphics. That's a great time to page-flip. Any earlier and we'd
start drawing into a buffer that's still on-screen. Later (i.e. VBL)
and there's a performance penalty because the page-flip takes a
one-frame delay. (if we push further, we could imagine page-flipping
any time between the last line and the VBL, leaving some breathing
room for cases where the rendering time temporarily overflows a tiny
bit the duration of a frame).

VBL is here to ensure that timer B stays in sync - some bugs or
worst-case scenarios could cause it to get out of the sync.

As discussed above, timers A and C can be engineered to stay away
from when timer B fires, and ACIA can be kept short enough to
limit the negative impact.

Still, it gets complicated. Here's what can go wrong:
-The CPU might have been executing a DIVS, 160 clocks, though
that's not very likely.
-The blitter might be eating 256 clocks, and that's actually
quite likely if the blitter gets used. We're not even talking
about running the blitter in hog mode.
-ACIA might come first, duration 200+. A line is 508 clock
on NTSC 8MHz machines.

256 will be common. Close to 500 is not inconceivable.
The worst-case scenario is probably above 600.

(IRQ) ;(44)
movem.l d0/a0, -(sp) ;(24)
move.b $fffffc00.w, d0 ;(12)
btst #0, d0 ;(12)
beq.s .notRx ;(8)
move.l ACIAbuf, a0 ;(20)
move.b $fffffc02.w, (a0)+ ;(16)
move.l a0, d0 ;(4)
andi.w #$ffe0, d0 ;(8)
move.l d0, ACIAbuf ;(20)
move.l (sp)+, d0 ;(12)
move.l (sp)+, a0 ;(12)
rte ;(20)

As a note, even ignoring questions of percise timer B, running
the blitter in hog mode quickly becomes an issue, the interval
between two ACIA data bytes is about 2560 memory cycles, less if
we take into account the overhead of other interrupts that might
be firing at the same time. The maximum size that might somewhat
fit between ACIA interrupts is along the lines of 96*96 1 bpp
in read-modify-write modes.

## May 01 2025

### Clock speeds

Clock speeds are a mess.

The MFP's timer reference is well known, 2.4576 MHz, i.e. (of
all possible decompositions) 128 * 19200. It can be used as a
true time base.

The US ST ran from a crystal at 32.04245 MHz. That value is
precisely 315 / 88 / 227 * 508 * 4, i.e. 508 pixels (1 line)
for every 227 NTSC 3.58 color cycles.

The UK ST and STe had a different clock,  32.084988 MHz, which
is 25 * 625 * (283.75+1/625) / 283 * 512 * 4, i.e. 512 pixels
(1 line) for every 283 PAL 4.43 color cycles.

The US STe moved to 32.215905 MHz, which is 315 / 88 * 9, i.e.
9 pixels for every 4 NTSC 3.58 color cycles (which means that
neither a line nor a frame are a whole number of color cycles).

Finally, the STe sound system uses the US ST clock speed, in
all regions, i.e. it never matches the CPU speed.
315 / 88 * 227 * 508 * 4 / 640.

### Building around Timer B interrupts

The interrupt handling can be thought about entirely in reverse:

We can imagine a system that has timer A for PCM sound, timer B
for palette changes, timer C for timekeeping, and an ACIA interrupt
to read data from the keyboard.

It turns out, most of those interrupts can afford some delays.

The IKBD ACIA can afford a bit more than 1ms.

Timer C can survive delays of several ms, dpending on settings.
5ms at the default 200Hz, 20+ms at 48Hz.

Timer A can deal with delays as well. Likely sizes for buffers
start at 14ms, with the understanding that the interrupt has
to fire early enough to fill the next buffer in time. Still,
several ms feels very feasible.

Timer B, however, is sensitive. The upper bound for latency
is probably about 50us on RGB/TV screens, or line-doubled VGA,
assuming that the palette change can happen mid-line.

All that means that ACIA, Timer C and Timer A interrupts can be
masked while expecting critical timer B sections. If a critical
section takes more than about 1ms, the ACIA needs to be polled,
which is not a hard issue.

Even with no other interrupt sources, there exist reasons
why the CPU might not be able respond quickly to an interrupt.
One of those is the existence of very long instructions. DIV
can exceed 20us in worst-case scenarios. The other is the
blitter, which blocks the CPU for 32us at a time. In the
worst-case scenario, those two can add up.

For the least sensitive situations, blitter + DIV only causes
a minor risk of small temporary glitches, such that there might
not be a need for any mitigation.

Toward the sensitive end of the spectrum, direct mitigations
of blitter and large instructions quickly runs into portability
issues, especially on VGA monitors. For those use cases, the
best approach is to make sure that the blitter is off when
expecting sensitive timer B interrupts, and to get the code
blocked on short instructions, ideally STOP.

The approach in that sensitive case is to make sure that the
blitter only processes small amounts at a time. 48x48 1bpp
in NFSR RMW is 528 memory accesses, slightly more than 0.5ms,
less than 10 lines of a typical PAL/NTSC display

# What's in the package

The distribution package contains this `README.md` file, the main
`LICENSE` file for the final, an alternative `LICENSE_ASSETS`
if you extract non-code assets from the program or its source tree,
and an `AGPL_DETAILS.md` file to explain the original author's
intentions for compliance with the AGPL license.

The program itself is provided under 5 forms in the package:
* A naked `YAST3.PRG` file meant to be executed e.g. from with
an emulator with GEMDOS hard drive emulation.
* A `yast3.st` uncompressed floppy image.
* A `yast3.msa` compressed floppy image.
* A copy of the source tree `src.zip` that was used to compile
the program.
* The full source history as a git bundle `yast3.bundle` which
can be cloned with `git clone yast3.bundle`.

# Building

The build process expects to have
rmac, cc, upx, hmsa, git and zip in the path.
Rmac can be found on [the official rmac web site](https://rmac.is-slick.com/).
UPX is [the Ultimate Packer for eXecutables](https://upx.github.io/).
Hmsa is part of [the Hatari emulator](http://hatari.tuxfamily.org/).

A regular build can be done in a single script `build.sh` which is
useful during most incremental development. However, using the music
from the editable file requires some manual steps:

## Converting the music

The music in its original form is delivered as an SNDH file, which
combines player code and music data. While the music data was created
specifically for this program, the player code has licensing restrictions
that make it unsuitable for integration into Open Source binaries, and
especially copyleft ones.

To avoid those restrictions, the music data is extracted as a raw
dump of the YM2149F registers, which is a pure derivative of the
music data and contains no trace of the player itself. That dump
is generated from within an emulated ST.

The end-to-end process involved running `audioconvert.sh` to build
the dumping program `ACONVERT.PRG`, which needs to be run from within
an Atari emulator (or on real hardware for the more adventurous),
where it generates the file `AREGDUMP.BIN` that can be copied back
into the source tree. `AREGDUMP.BIN` is provided in the source
tree already such that it's possible to modify the program without
having to build and execute `ACONVERT.PRG`

# (Un)important things

## Licensing

The program in this repository is licensed under the terms of the
[AGPL, version 3](https://www.gnu.org/licenses/agpl-3.0.en.html)
or later.

As a special exception, the source assets for the program (images, text,
music, movie files) as well as output from the program (screenshots,
audio or video recordings) are also optionally licensed under the
[CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
License. That exception explicitly does not apply to source code or
object/executable code, only to assets/media files when separated
from the source code or object/executable file.

Licensees of the whole program or of the whole repository may apply
the same exception to their modified version, or may decide to
remove that exception entirely.

## Privacy

This code doesn't have any privacy implications, and has been
written without any thought about the privacy implications
that might arise from any changes made to it.

_Let's be honest, if using a program on such an old computer,
even emulated, causes significant privacy concerns or in
fact any privacy concerns, the world is coming to an end._

### Specific privacy aspects for GDPR (EU 2016/679)

None of the code in this project processes any personal data
in any way. It does not collect, record, organize, structure,
store, adapt, alter, retrieve, consult, use, disclose, transmit,
disseminate, align, combine, restrict, erase, or destroy any
personal data.

None of the code in this project identifies natural persons
in any way, directly or indirectly. It does not reference
any name, identification number, location data, online
identifier, or any factors related to the physical, psychological,
genetic, mental, economic, cultural or social identity of
any person.

None of the code in this project evaluates any aspect of
any natural person. It neither analyzes nor predicts performance
at work, economic situation, health, personal preferences,
interests, reliability, behavior, location, and movements.

_Don't use this code where GDPR might come into scope.
Seriously. Don't. Just don't.

## Security

Generally speaking, the code in this project is inappropriate
for any application where security is a concern of any kind.

_Don't even think of using any code from this project for
anything remotely security-sensitive. That would be awfully
stupid._

_In the context of the Atari ST, there are no significant
security features in place when using the original ROMs.
Worse, to the extent that primitive security features might
exist at all (protection of the top 32kB and bottom 2kB of
the address space), the code disables them as much as possible,
e.g. running in supervisor mode in order to gain direct
access to hardware registers._

_Finally, the code is developed in assembly language, which
lacks the modern language features that help security._

### Specific security aspects for CRA (EU 2022/454)

None of the code in this project involves any direct or indirect
logical or physical data connection to a device or network.

Also, all of the code in this project is provided under a free
and open source license, in a non-commercial manner. It is
developed, maintained, and distributed openly. As of April
2025, no price has been charged for any of the code in this
project, nor have any donations been accepted in connection
with this project. The author has no intention of charging a
price for this code. They also do not intend to accept donations,
but acknowledge that, in extreme situations, donations of
hardware or of access to hardware might facilitate development,
without any intent to make a profit.

_This code is intended to be used in isolated environments.
If you build a connected product from this code, the security
implications are on you. You've been warned._

### Specific security aspects for NIS2 (EU 2022/2555)

The intended use for this code is not a critical application.
This project has been developed without any attention to the
practices mandated by NIS2 for critical applications.
It is not appropriate as-is for any critical application, and,
by its very nature, no amount of paying and auditing will
ever make it reach a point where it is appropriate.
The author will immediately dismiss any request to reach the
standards set by NIS2.

_Don't even think about it. Seriously. I'm not kidding. If you
are even considering using this code or any similar code for any
critical project, you should expect to get fired.
I cannot understate how grossly inappropriate this code is for
anything that might actually matter._
