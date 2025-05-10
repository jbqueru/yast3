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
; ####                        Modifiable parameters                        ####
; ####                                                                     ####
; ####                                                                     ####
; #############################################################################
; #############################################################################

DEBUG .equ 0
DEBUG_COLOR_SHOW_ALL .equ 0

.if DEBUG
DEBUG_COLOR_SHOW_ALL .equ 1
.endif

.if DEBUG_COLOR_SHOW_ALL
DEBUG_COLOR_SHOW_TIMER_A .equ $003
DEBUG_COLOR_SHOW_TIMER_B .equ $333
DEBUG_COLOR_SHOW_TIMER_C .equ $440
DEBUG_COLOR_SHOW_ACIA .equ $444
DEBUG_COLOR_SHOW_MOUSE .equ $777
DEBUG_COLOR_SHOW_PSG .equ $770
DEBUG_COLOR_SHOW_PCM .equ $004
DEBUG_COLOR_SHOW_CORE .equ $400
DEBUG_COLOR_SHOW_RENDER .equ $040
.endif
