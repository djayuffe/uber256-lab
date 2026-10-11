# Changelog

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
