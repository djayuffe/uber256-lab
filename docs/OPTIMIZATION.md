# Integer-kernel optimizations

The rendering formulas and palette indices are preserved by these changes.
The independent Python references compare complete frames for the affected
effects, including doubled-clock wrap boundaries and multi-frame history.
The byte counts below include palette generation, generated music and exit.

| Effect | Before | After | Change |
|---|---:|---:|---|
| RANK | 238 B | 238 B | Replace eight inner-loop multiplications with successive additions |
| RUNS | 205 B | 227 B | Count transition bits with a fixed sequence of integer masks and sums |
| RING | 212 B | 221 B | Skip generations whose exact result is already known to be zero |
| SIGNED | 191 B | 189 B | Remove a redundant clear before a full-byte assignment |

## RANK: generate successive values

The old inner loop recomputed `37*k` for k=0..7 for every pixel. The new loop
holds successive values 0,37,...,259 and stops at 296. It still compares the
low-byte candidate against the selected lane and counts strictly smaller values.
This removes 512,000 inner-loop multiplications and 512,000 instructions per
320x200 frame. The selected lane's one initial multiplication remains.

## RUNS: count several bits at once

The field derives fifteen adjacent-bit changes from a sixteen-bit word. Instead
of shifting and counting one bit at a time, the new kernel sums bit pairs using
0x5555, nibbles using 0x3333, then combines bytes using 0x0F0F. This is SWAR
(SIMD within a register) using ordinary 386-compatible integer instructions.

After the common transition-mask calculation, the count/output sequence falls
from 50 instructions to 16, saving 2,176,000 executed instructions per frame.
The 22-byte size increase is an explicit speed/size tradeoff; the complete demo
still fits comfortably within 256 bytes. The output still encodes 16 runs as
palette index zero by deliberate byte wrapping.

## RING: use the finite ring's algebra

For rule 90, an update is left-rotate-one XOR right-rotate-one. After eight
updates on a sixteen-cell ring, both rotations reach the same opposite cell
and cancel. Thus F^8(state)=0 for every initial state, and all later states
remain zero. Generation requests 8..15 now return zero immediately. Requests
0..7 retain the original updates. Tests use an independent cell-neighbour model.

## SIGNED: remove a redundant write

`MOV AL,AH` overwrites the complete low byte. Clearing AL immediately before it
cannot change that assignment or the following XOR. Removing the clear saves
two bytes and one instruction per pixel without changing the signed product.

## Measurement limits

The instruction savings above follow from the fixed loop bounds, not hardware
timing measurements. CPU multipliers, branch timing, emulation, DAC output and
interrupt overhead determine the actual frame rate. No physical-hardware speed
ratio or DOSBox cycles setting is inferred from these counts. The separate
[palette guide](PALETTES.md) documents radial row reuse and colour-generation
optimizations already applied to CAUSAL, HORIZON and Spectrum.

For reproducible instruction counts, use:

```sh
.venv/bin/python tools/cost.py --frames 1 --tick 37 SIGNED.COM RUNS.COM RANK.COM
```

The tool excludes startup and verifies completed frame polls. Its default input
is standalone effects only; MEGA and ATLAS are rejected because a whole show
has no single repeating frame. A fixed tick samples one workload, not every
possible animation state or worst-case execution path.

For the current binaries, one measured frame after two warmup frames at tick 37
produced these Unicorn instruction counts:

| Effect | Instructions/frame |
|---|---:|
| SIGNED | 960,815 |
| RUNS | 1,792,815 |
| RANK | 4,679,094 |

These counts include the frame traversal and polling path, not just the pixel
kernel. Instrumentation time on the host is not part of the reported metric.
