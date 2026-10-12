# Changelog

## [2.3.1]
- Refactor, same effects: the code every demo repeated is now four macros in `src/dos.inc` (`HOOK_TICK`, `ESC_OR_LOOP`, `MIDI_START`, `PENTA`); all eleven binaries that did not otherwise change are byte-identical to 2.3.0.
- GOLDTEX: x and y are loop counters instead of a division per pixel, and the row's share of the block key is computed once per row; same formula (checked pixel by pixel against it), 256 bytes.
- Comment fixes: the groove's bass walks C - A - G - E - D.

## [2.3.0]
- **GOLDTEX** (247 bytes), a new demo: the classic SELFTEX picture, `code[x*y/64 + t]` in a flowing palette, with golden blocks. The screen is a 16x16 grid; block (bx, by) is gold when the program's own byte at `bx + 16 by + t/16` is a multiple of 16, so about one block in six turns gold and the gold hops across the grid every 16 frames. Gold pixels keep their code texel in a bright gold ramp that cycles twice as fast, so the blocks glitter. Music: the program's bytes on a glockenspiel, doubled an octave up, over the groove. 22 new checks (245 in all), DOSBox recording, GIF, MIDI; gallery and showreel include it.

## [2.2.0]
- **SELFTEX is a river** (254 bytes): a perspective floor (depth = 8192 / (y - horizon), two divisions per row, none per pixel) with a river winding into the distance; the water is code bytes stretched into streaks flowing towards you, the banks are fields of code-byte blocks with a dark shore, under a sky ramp. Every texel is a byte of the program, the music is still the program's bytes on a kalimba, and time is the BIOS clock (no retrace wait). The 2.1 diagonal layer, palette flow, panning, octave doubling and drums are dropped to make room.

## [2.1.0]
- Every spare byte spent on eye candy and music (all eleven still <= 256 bytes; CLIFF and ROOTS exactly 256).
- New `src/groove.inc`, a 52-byte rhythm section for the tick handler: GM drums on channel 10 every fourth tick (kick, hi-hat, snare, hi-hat) and a bass on channel 2 with every kick, walking down the pentatonic scale. Used by FIRE, LATCH, ORDER, SELFTEX and WARP. `build.sh` passes `-Isrc/`.
- WARP: CR08 bob, pixel-panning shimmer, a flowing rainbow over all 63 text colours above black.
- LATCH: the same rainbow over its 15 colours and the panning shimmer.
- SELFTEX: a second, diagonal layer of code bytes added to the first; flowing palette; panning shiver; the kalimba doubled an octave up.
- ORDER: the shading flows inside each region's palette band.
- ESCHER: pixel panning makes the start-address drift pixel-smooth; the palette streams through the texture (still no pixel redrawn).
- JULIA: the tick handler rotates the palette (black set kept), so the bands flow 18 times a second; a low C pedal every 16 ticks.
- FIRE: a white-hot ember a frame that rises as a spark.
- CHLADNI: bells doubled an octave below. CLIFF: the orbit's x position is the marimba's velocity.
- Tests: 223 checks (the groove, the new registers, the palettes, two-layer SELFTEX).

## [2.0.0]
- **Music in every demo.** Each program hooks the 18.2 Hz timer tick (INT 1Ch, through DOS, restored on exit) and plays General MIDI through an MPU-401 in UART mode, so the tempo is the clock's, whatever the frame rate. Every score is generated from the demo's own state and quantised to C major pentatonic by `aam 5` / `aad 6` (an even number 2d becomes floor(12d/5)): GALAXY and CLIFF play their orbit (vibraphone, marimba), CHLADNI rings a tubular bell where a probe crosses a nodal line, FIRE plucks a nylon guitar when its probe is in a flame, ESCHER is a Shepard scale (an endless staircase in sound), JULIA plays each pixel as it is drawn (celesta), LATCH plays the ruler sequence of the Sierpinski triangle (music box), ORDER arpeggiates the ordering under a probe (pizzicato), ROOTS plays its coefficient T (steel drums), SELFTEX plays its own code bytes (kalimba), WARP plays the character-height wave that stretches the screen (electric piano).
- **Fixed:** GALAXY, CLIFF and CHLADNI left the PC speaker droning after Esc; the speaker is no longer used at all.
- **Fixed:** ESCHER waited only for "in retrace", so it advanced about six steps per frame (421 iterations a second measured in DOSBox); it now waits for the end of one retrace and the start of the next, one step per frame.
- **Fixed:** ESCHER's line compare had bits 8 and 9 set (mode 13h's CR07 bit 4 and CR09 bit 6), which puts the split below the screen on a real VGA; they are cleared once at start.
- **Fixed:** GALAXY and CLIFF drifted two parameters for ever; they now swing back and forth (by s*cos(s*t) per frame, from the BIOS clock), so the attractor stays an attractor after minutes.
- **Faster** (DOSBox 0.74-3, `cycles=max`, frames per second before -> after): CHLADNI 19 -> 34 (the plate is separable: 640 FSINs a frame into a sin(aX), sin(bX) table instead of four per pixel; pixel-identical for the same mode number), JULIA 2.8 -> 10 (only the top half is computed and mirrored; the centre moved half a pixel so the mirror is exact), ORDER 35 -> 56 (the three expressions are kept incrementally: no division or multiply per pixel; pixel-identical), ROOTS 21 -> 28, FIRE 52 -> 68 (DS = video, no segment prefixes; pixel-identical), ESCHER 421 -> 70 (fixed, see above).
- **CHLADNI**: the mode number follows the clock, a = 3 + sin(0.0115 t): it sweeps smoothly through [2, 4] every 30 s instead of jumping back from 4.5 to 1.5.
- **ROOTS**: rewritten to fit the music in 256 bytes: the cubic is evaluated times 16 in Horner form, T is patched into an `imul` immediate each frame and time comes from the BIOS clock (no retrace wait).
- Sizes (bytes, before -> after, music included): GALAXY 201 -> 253, CLIFF 206 -> 250, CHLADNI 221 -> 245, FIRE 123 -> 191, ESCHER 134 -> 224, JULIA 155 -> 221, LATCH 82 -> 140, ORDER 106 -> 173, ROOTS 247 -> 256, SELFTEX 73 -> 130, WARP 72 -> 125.
- Tests: a shared emulator (`tests/emu.py`) with a DOS interrupt-vector table, a BIOS timer tick that enters the hook with DS = 0040h as an IBM BIOS does, and an MPU-401 capture; 206 checks, including what each demo plays. `tools/equiv.py` compares two builds frame by frame.
- Real DOSBox recordings with sound (`docs/*.mp4`), the MIDI each demo played (`docs/music/*.mid`), new GIFs and gallery from the same runs.

## [1.11.0]
- GALAXY 205 -> 201 and CLIFF 210 -> 206, output-identical: the scratch slot in the data block moved past the end of the file.

## [1.10.0]
- Size pass, output-identical in the emulator except SELFTEX: ESCHER 137 -> 134, CHLADNI 224 -> 221, JULIA 161 -> 155, ROOTS 251 -> 247, ORDER 108 -> 106, SELFTEX 77 -> 73 (one `xlat`). 22 bytes in all. README: a table of the size passes.

## [1.9.0]
- **ROOTS** expanded and recoloured (232 -> 251 B): a second, slower coefficient S tilts the cubic so crossings happen in new places each sweep; the two linear terms are folded into one per-frame constant; roots drawn in the brightest shade of their own side (no special white palette branch); column 0 and row 0 no longer draw false roots.
- **ORDER** shrunk 123 -> 108 B with pixel-identical output (time in BP, expressions in 16-bit registers compared by their low bytes).

## [1.8.0]
- **ROOTS** (232 B): polynomial root migration, the sign changes of a cubic as white curves that cross and reconnect. 10 new checks (111 in all). Rendered GIF and DOSBox still.
- README: the twenty mechanisms prototyped from the 100-effects list and why only two were built.

## [1.7.0]
- **ORDER** (123 B): regions defined only by the ordering of three per-pixel expressions. 10 new checks (101 in all).
- Rendered GIFs for LATCH, WARP and ORDER; gallery shows all demos.
- README: EUCLID and ORBIT tried and not shipped.

## [1.6.0]
- **WARP** (72 B): the DOS screen squashed, stretched and sheared by CRTC registers 09h and 13h, with no drawing. 6 new checks (91 in all).
- README: three ideas from the same brief that did not work (mode-13h stride shear, mode-13h CR09 zoom that flickers in DOSBox, LATCH with a rotating read map).

## [1.5.0]
- **LATCH** (82 B): a rule-60 cellular automaton computed by the VGA graphics controller (latches, write mode 3, XOR, set/reset). 7 new checks (85 in all).
- Found: in DOSBox 0.74 the graphics controller's data rotate appeared to have no effect in write mode 3; LATCH shifts the mask with `rcr` instead.

## [1.4.0]
- **ESCHER** (137 B): the picture is drawn once; only the CRTC start address and line compare move. 12 new emulator checks.
- **CHLADNI** (224 B): FPU Chladni nodal lines with drifting mode numbers and speaker tone. 11 new emulator checks (78 in all).
- README: a section on the second brief's candidates, with the results of the ones tried (including two that did not work: a palette cellular automaton and the carry-flag recurrence).

## [1.3.0]
- **JULIA** (161 B): integer-only (8.8 fixed point) Julia set whose constant orbits on a Minsky oscillator; 11 new emulator checks (55 in all).

## [1.2.0]
- **FIRE** (123 B): framebuffer-feedback fire with an LCG noise source and a generated fire palette; 11 new emulator checks (44 in all).
- README: FIRE write-up, updated gallery and experiment table.

## [1.1.0]
- Shrunk: GALAXY 208 -> 205 bytes, CLIFF 213 -> 210 bytes (`loop` for both loops, one folded pixel-address `imul`/`add`, `xchg ax,di`, plain `mov al,3` for the speaker).
- Improved: two parameters morph instead of one; the fade now covers the whole segment evenly (brightness retuned).

## [1.0.0]
- GALAXY (208 B): de Jong attractor with glow accumulation, morphing and orbit-driven speaker tone.
- CLIFF (213 B): Clifford-attractor variant of the same engine.
- SELFTEX (77 B): the program's own code bytes as a scrolling texture.
- Emulator tests and CI; real DOSBox screenshots.
