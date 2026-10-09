# Changelog

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
