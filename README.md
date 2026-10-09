# uber256-lab

**Experiments in the 256-byte class: strange attractors on the x87 FPU, and a texture made of the program's own code.**

[![CI](https://github.com/djayuffe/uber256-lab/actions/workflows/ci.yml/badge.svg)](https://github.com/djayuffe/uber256-lab/actions/workflows/ci.yml)

![GALAXY, CLIFF and SELFTEX running in DOSBox](docs/gallery.jpg)

Three real-mode DOS `.COM` programs in NASM, each under 256 bytes. All three were run in
real DOSBox for the screenshots and are checked by an emulated-CPU test suite.

| Program | Size | What it is |
|---|---|---|
| `GALAXY.COM` | 205 B | de Jong attractor, 6000 orbit points per frame, accumulated into a fading glow buffer. Two parameters drift, so the shape slowly morphs. The orbit also tunes the PC speaker. |
| `CLIFF.COM` | 210 B | The same engine with Clifford-attractor equations and parameters: two wings and a ring of caustics. |
| `SELFTEX.COM` | 77 B | Pixel = a byte of the program's own machine code, indexed by `x*y/64 + time`. The hyperbolic bands are the code's byte pattern. |

## Run it

```sh
./build.sh              # NASM build, enforces the 256-byte limit
./run-dosbox.sh galaxy  # galaxy | cliff | selftex
```

**Esc** exits to text mode. GALAXY and CLIFF need a 386+ with an FPU (`fninit`, `fsin`, `fcos`);
any emulator or machine from the 486DX on is fine. Use `cycles=max` (shipped in `DOSBOX.CONF`).
The speaker tone is generated, but I have not listened to it, so its sound is untested by ear.

## How the attractor fits in 205 bytes

- The palette is streamed to the DAC (port 3C9h) with a `shr` chain: one loop, no table.
- Each orbit step is `x' = sin(a*y) - cos(b*x)`, `y' = sin(c*x) - cos(d*y)` with the four
  constants in a 28-byte data block. `fxch` / `fstp st2` swap the new point in without temporaries.
- `fistp` turns the point into a pixel offset (`y*320 + x` with `imul ax,ax,320`) and the pixel
  gets `add byte [es:di], 4`, so hot regions glow.
- After each frame the whole 64 KB segment is faded with `v -= v>>4; v -= 1` in one `stosb` loop
  run by `loop` with CX already 0, so 65536 passes cover the segment exactly once.
- Scratch words for the pixel position live just past the end of the file, inside the segment.

## Ideas from the 256-byte brief: what was tried

| Idea | Result |
|---|---|
| Dynamical systems / attractors on the FPU | **Works** (GALAXY, CLIFF). |
| Accumulation buffer with fade (feedback) | **Works**, used by both attractors. |
| Parameter morphing | **Works**: two constants drift per frame. |
| Orbit-driven PIT sound | Implemented; unheard. |
| Code as texture / lookup table | **Works** (SELFTEX). Verified in DOSBox. |
| Neighbour-averaging feedback ("nebula") | Failed: averaging halves the energy, the screen goes black. Dropped. |
| Carry-flag cellular automaton | Prototyped (six variants); not good enough to ship. |
| Integer equation search scored by compressibility | Ran; candidates not better than the attractors, none shipped. |
| Genetic search over tiny programs | Earlier work in [uber-micro-demos](https://github.com/djayuffe/uber-micro-demos) (EVO1/EVO2). |
| VGA latch / CRTC scroll tricks, single phase-transition system | Not attempted yet. |

## Testing

`tests/run_tests.sh` builds and runs every `.COM` in an emulated 16-bit CPU (Unicorn, x87 included):
size limit, mode 13h first, all 768 DAC values, the picture is drawn and stays on screen, many
brightness levels, the picture changes between frames, FPU opcodes present, speaker programmed,
no stray memory access, and Esc returns to text mode.

## Layout

```
src/*.asm           the demos
build.sh            NASM build + 256-byte gate
run-dosbox.sh       DOSBox launcher
tests/              emulator tests
docs/               real DOSBox screenshots
.github/workflows/  CI and tag-driven releases
```

MIT licence. Sibling projects: [uber-micro-demos](https://github.com/djayuffe/uber-micro-demos) (under 9 bytes),
[uber-tiny-demos](https://github.com/djayuffe/uber-tiny-demos) (index).
