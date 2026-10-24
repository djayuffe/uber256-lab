# Changelog

## [Unreleased]

- Give every atlas effect an individual General MIDI voice and add a two-octave
  image-derived response while retaining the 256-byte limit. Add a four-channel
  ATLAS.COM arrangement with lead, pizzicato dyads, acoustic bass and drums.
- Add exact MIDI-stream tests and a complete score/instrument reference.
- Add TIMELENS, EMBOSS, SURGERY, BRACKET, ORBIT and CRITICAL (204–251 bytes),
  with vivid palettes, generated music, captures and independent pixel equations.
- Expand ATLAS.COM to 27 timed parts and derive show checks from the playlist.
  Track 28 adapted proposal IDs; 122 remain unimplemented.
- Verify a real two-dimensional component split in SURGERY and ORBIT's finite
  return bound for every byte seed/mask pair.
- Handle an existing test virtualenv that is missing Unicorn using python -m pip.

- Add ATLAS.COM: a continuous 27-part show with timed effects, titles, fades,
  progress, chimes, wrapped credits, Space skip and Escape exit.
- Define MEGA/ATLAS metadata and embedded binaries from shared playlist entries;
  add compile-time credits bounds and runtime show/control regression tests.
- Optimize RANK lane generation, RUNS bit counting and finite RING evolution;
  remove a redundant SIGNED assignment while preserving pixel-reference results.
- Add launcher help/listing, an atlas-show target and fresh builds before playback.
  Drop old autoexec commands when preparing the temporary DOSBox configuration.

- Give the 27 atlas demos seven vivid palette families with smooth VGA channel
  ramps and effect-specific contrast. Spectrum palettes cycle on BIOS time.
- Fold Spectrum channels without branches and reuse y*y once per scanline in
  CAUSAL/HORIZON, removing 63,800 y multiplications per rendered frame.
- Refresh atlas captures and sizes, document palette mechanisms, and test
  channel continuity, DAC bounds, cycle direction and exact wrapping.

- Add thirteen more <=256-byte atlas adaptations: HYSTER, RESIDUAL, SIGNED,
  RUNS, BYTEVM, REVERSO, BIFURC, TERRACE, LOOM, RING, PREFIX, RANK and BALLOT.
- Test every framebuffer pixel at clock boundaries, persistent history over ten
  frames, bounded interpreter/collective execution and the full 16-bit inverse.
- Add capture selection by name and preserve state for HYSTER/LOOM captures.
  Document all 150 proposals and the current adaptation status in a coverage ledger.

- Add six DOS atlas adaptations: HORIZON, COMMUTE, LIFT, MIRROR, RESFIELD
  and SHUFFLE (190–234 bytes), with standalone launcher integration.
- Add independent pixel references, exhaustive byte-pair reversibility checks,
  lane permutation tests, emulator captures and a 150-proposal coverage ledger.

- Add CAUSAL (196 bytes): distance-delayed animation and chronology shells.
- Add PHASE (224 bytes): interference of three time-shifted triangle waves.
- Include both in the DOSBox launcher and after ROOTS in the thirteen-part MEGA
  sequence, with title cards, fades, credits and skip/exit support.
- Wrap the expanded credits list at effect-name boundaries so it stays within
  the 80-column text screen; cover both rows with a regression test.
- Add pixel-reference, clock-wrap, MIDI and exit tests, plus emulator captures
  and documented mapping to atlas proposals A02, A05 and A08.

## [2.10.0]
- **MEGA.COM: eye candy and controls.** The title cards sit on a bronze background that flows: one field of four sines, computed on the x87 once at start-up into its own segment, coloured 1..63 and palette-cycled through a sine table every frame, so it moves under the text at no cost. Every line of text has a drop shadow. Each card says `PART n OF 11` over a gold progress bar; the opening card shows the keys (`SPACE: NEXT PART   ESC: QUIT`), the closing card a full bar and `THANKS FOR WATCHING`. **Space** ends the part now playing (or cuts a card's hold short) and goes on to the next; Esc still ends the show. 6,205 bytes.
- Tests: 277 (Space during a part unhooks it and the show goes on). The emulator maps 448 KB for the program's segments.
- New recording, contact sheet (a frame every four seconds), MIDI, and `docs/mega-wipes.gif` (GALAXY's card burning in and out).

## [2.9.0]
- **MEGA.COM: transitions.** Out of every mode-13h part the last frame drains to sepia (a 24-frame DAC crossfade to each colour's luminance, then a race-the-beam remap into colours 128..191 that changes nothing on screen and frees the palette). Each title card is drawn off screen and burns in through a shaped wipe, a threshold over a per-pixel map with a 16-wide burning edge from white-gold to deep orange, and burns out to black through another. Seven shapes computed on the x87 per wipe (star iris, paper burn, spiral sweep, petalled close, drips, rippled diamond, sparkling fizzle), with a new phase each time. 5,502 bytes.
- Fixed while building it: the card kept its strings' pointer in SI, which the new drain clobbered.
- The emulator answers INT 10h AH = 0Fh with the mode last set, so the tests run the sepia drain. Tests: 276 (every card burns in and out; the nine mode-13h parts drain).
- New recording, contact sheet, MIDI, and `docs/mega-wipes.gif` (the opening wipes).

## [2.8.3]
- MEGA.COM: every part fades in from black. The part starts with the PEL mask at 0 (its first frame drawn unseen), then the shared frame check reads the DAC at the end of each of its first 32 frames, takes whatever palette the part has written since the last step, and writes it at k/32 brightness, so it works for parts that set their palette once and for those that rewrite it every frame. 4,507 bytes.
- Tests: 274 (the fade-in: masked start, first palette at 1/32). New recording, contact sheet, MIDI.

## [2.8.2]
- MEGA.COM 5,133 -> 4,389 bytes, and better. The code every intro repeats is shared: in the `-DMEGA` build the frame check, the MIDI header and the groove are far calls into the megademo through vectors in each part's PSP (50h, 54h, 58h), so one copy serves all eleven (the groove alone was five copies). The programme is packed (no 80-byte padding), the credits read the list of parts from it, and the cards share one frame routine. Each title card rings a chime (tubular bells, a fifth). The MPU-401 is put in UART mode before the first note, so the first chime's instrument is not lost.
- Fixed while rewriting it: a card could return with the carry flag left by the palette code and end the show.
- The 256-byte intros are byte-for-byte unchanged. Tests: 273 (the chimes). New recording, contact sheet, MIDI.

## [2.8.1]
- The megademo drops ESCHER and CHLADNI: eleven parts (FLOWTEX, SELFTEX, GOLDTEX, ORDER, GALAXY, CLIFF, FIRE, ROOTS, JULIA, LATCH, WARP), about four minutes, 5.1 KB. Both stay in the collection as standalone 256-byte intros. The intro and closing cards and the credits count the parts; `build.sh` takes the count and the total (2,724 bytes) from the `ENTRY` list in `src/mega/mega.asm`.
- New megademo recording, contact sheet and MIDI.

## [2.8.0]
- **MEGA.COM, the megademo**: all thirteen intros in one 5.8 KB program, about four and a half minutes. Each part is the intro itself, assembled again with `-DMEGA` so its exit macro also ends it at a tick count the megademo sets (and flags Esc, and leaves the screen to be faded); the megademo runs each one the way DOS runs a .COM, in a fresh segment with a far jump home at PSP:0. Between parts: a DAC fade to black (any video mode), then a title card in the BIOS font scaled five times in a gold gradient with a band of light running down it, the part's size and a line on what it is and what plays. WARP comes last and bends the credits; a closing card gives the total, 3,218 bytes. Esc ends the show at any point.
- `./run-dosbox.sh mega` runs it; `build.sh` builds it after the 256-byte binaries (unchanged).
- Tests: 6 new checks (272): the thirteen parts in order, cards and modes, timer hooks, credits, Esc, exit.
- `docs/mega.mp4` (a DOSBox recording with its music), `docs/mega-sheet.jpg`, `docs/music/mega.mid`.

## [2.7.0]
- **FLOWTEX** (219 bytes), a new demo cloned from the classic SELFTEX with fewer colours and bigger flows: `code[x*y/1024 + t]`, sixteen times the area per code byte, linearly interpolated in 32 steps between neighbouring bytes (a 64 KB table built at start-up in the segment above the program), in one sepia-to-ivory ramp, so the machine code flows past as smooth satin ridges. Five instructions a pixel, 70 fps from 22,600 DOSBox cycles. Music: a harp arpeggio of the four code bytes flowing in at the corner, doubled two octaves down.
- `run-dosbox.sh '*tex'` runs SELFTEX, GOLDTEX, FLOWTEX; `all` runs thirteen.
- Tests: 20 new checks (266); the emulator maps the 64 KB above the program and checks only FLOWTEX writes there.
- DOSBox recording, GIF, still, MIDI; gallery (now 7 x 2) and showreel include it.

## [2.6.1]
- `run-dosbox.sh` runs several demos in order: names, a quoted pattern (`'*tex'` is SELFTEX then GOLDTEX) or `all`. Each runs in its own DOSBox, closed when Esc ends it, because a held Esc would otherwise also end the next demo before it was seen.

## [2.6.0]
- **GOLDTEX: polished gold.** Gold blocks are smooth diagonal ramps (colour 132 + 4(u + v)) instead of code texture, and colours 129..255 are a triangle wave one tile-diagonal long, R = s (32..63), G = s - 8, B = s - 32: a band of white-gold light sweeps over every tile from corner to corner every 1.8 s, over deep gold. Gold runs are three instructions a pixel (440,788 instructions a frame, was 555,123). 253 bytes.
- Tests: the gold-tile formula, the gold palette (R >= 32, G = R - 8, B = R - 32, a smooth band), the sweeping light. 246 checks.
- New GOLDTEX recording, GIF, MIDI, gallery tile and showreel.

## [2.5.0]
- **Speed.** Every demo that missed 70 frames a second at DOSBox `cycles=fixed 60000` now reaches it; instructions per frame (counted by the new `tools/cost.py`) and DOSBox frames per second at 60000 cycles, 2.4 -> 2.5:
  - CHLADNI 965,431 -> 548,810, 35 -> 70: the lattice is centred between pixels, so the left half is computed and each value written twice (at x and 319 - x); the table holds only the 260 entries used (520 FSINs). The mode number runs on a per-frame phase kept on the FPU stack (same 30 s period) instead of the 18.2 Hz clock, so the figure changes every frame. 251 bytes.
  - GOLDTEX 1,168,736 -> 555,123, 35 -> 70: 16-pixel runs, each inside one block, set up once (block test, gold mask, texel accumulator); seven instructions a pixel. Same formula. 255 bytes.
  - ORDER 1,029,147 -> 709,347, 35 -> 70: `a` is the high byte of one accumulator (256t + 4xy), and the comparison carries are rotated straight into the colour; eleven instructions a pixel. Pixel-identical. 240 bytes.
  - ROOTS 2,421,665 -> 1,543,942, 25 -> 39: nested loops instead of a division per pixel, per-row terms out of the pixel loop, and the row above the screen drawn past its end instead of a row-0 test (the top row now has a real upper neighbour). Identical below row 0. 252 bytes.
  - JULIA 14.2M -> 9.8M, 5.6 -> 13.7: 32-bit products with no shifts until they are combined (15 instructions an iteration instead of 22); no retrace wait. About 2% of pixels change band (one rounding instead of two). 254 bytes.
  - FIRE 831,697 -> 768,018: the four-pixel average as halves of halves with `rcr`, and `loop`. The flames are a few rows shorter. 250 bytes.
  - GALAXY 692,315 -> 626,779 and CLIFF 704,315 -> 638,779: the fade's `v - v/16` is `aam 16` / `aad 15`. Pixel-identical. 248 and 253 bytes.
- **Fixed before release:** the first fast GOLDTEX left CH holding the frame counter's high byte, so after 256 frames its runs became thousands of pixels long; found in DOSBox. A test now draws a frame at t = 1234h.
- Tests: 246 checks (CHLADNI's mirror and per-frame phase, ROOTS's top row against the row above the screen, GOLDTEX past 8-bit time; JULIA now counts frames by keyboard polls, having no retrace wait).
- New DOSBox recordings, GIFs, stills and MIDI of the eight changed demos, and a new showreel. README: a [Speed](README.md#speed) section and each demo's 2.5 changes.

## [2.4.0]
- CHLADNI: the sine table is 16-bit integers scaled by K = 6271 (K^2 = 600 x 65536), so each pixel is two 16-bit `imul`s whose high words are already 600 sin sin: no FPU in the pixel loop. Same picture (12% of pixels differ by one brightness step, none by more). 250 bytes.
- WARP: the electric piano plays every other tick (16th notes over the groove) instead of every tick; it was 10 dB louder than the other melodies. 256 bytes.
- FIRE: the ember is two pixels wide, so the rising sparks are visible. 256 bytes.

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
