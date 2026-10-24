# Vivid palettes and VGA colour cycling

The 27 atlas adaptations use seven palette families selected for their structure.
The original thirteen demos retain their established palettes. Every palette is
generated inside the executable; there are no stored image or colour assets.

| Family | Demos | Visual purpose |
|---|---|---|
| Fire | CAUSAL, RESIDUAL, BIFURC, CRITICAL | Red through orange and yellow; sparse residual lines remain bright against black. |
| Ice | HORIZON, HYSTER, PREFIX, TIMELENS | Blue through cyan; a bright endpoint separates binary state from its black background. |
| Orchid | LIFT, REVERSO, RING, BRACKET | Violet through lavender; consistent brightness progression preserves fine integer structure. |
| Emerald | RESFIELD, LOOM, ORBIT | Green through mint; exposes resolution boundaries and accumulated strand state. |
| Gold | RUNS, TERRACE, EMBOSS | Amber through gold; ordered levels keep run-count and terrace comparisons readable. |
| Rose | MIRROR, SIGNED, BALLOT, SURGERY | Crimson through pink; strong separation for reinterpretation and mask fields. |
| Spectrum | PHASE, COMMUTE, SHUFFLE, BYTEVM, RANK | A continuous three-channel hue field that slowly cycles through the VGA DAC. |

## Smooth ramps with useful contrast

Each component is a legal 6-bit VGA DAC value (0..63). The six noncyclic
families begin at black, increase in brightness, and reach a bright coloured
endpoint. The binary HYSTER/RING states therefore retain strong separation.
Neighbouring palette entries change each channel by at most one DAC step.
Spectrum also joins entry 255 to entry 0 continuously.

The compile-time `PALETTE` setting in each wrapper selects macros from
`src/palettes.inc`. With i=0..255, channel primitives are:

```text
fast          = min(i>>1,63)
linear        = i>>2
quarter       = i>>4
square        = (i*i)>>10
squarehalf    = (i*i)>>11
squarequarter = (i*i)>>12
wave(i)       = max(min(i,255-i)-64,0)
```

Fire uses (fast,square,quarter), Ice (squarehalf,linear,fast), Orchid
(linear,squarehalf,fast), Emerald (squarehalf,fast,linear), Gold
(fast,linear,squarequarter), and Rose (fast,squarequarter,linear).
These are artistic integer ramps; no colour-space calibration is assumed.

## VGA DAC as an animation stage

Spectrum evaluates wave(i), wave(i+85), wave(i+170), with byte wrapping.
Clipping the low half of each triangle produces saturated primaries and deeper
separation between hues while keeping every adjacent channel step at most one.
At each frame it adds `phase=((2*BIOS_tick mod 65536)>>3) mod 256` to the
source colour index before writing all 256 RGB triplets to VGA ports 3C8h/3C9h.
This changes the displayed colours without altering the framebuffer's field,
its stored history or the sampled MIDI note values. The cycle advances one
entry every four BIOS ticks and wraps after 1024 ticks, approximately 56 seconds.
Its speed follows the BIOS clock rather than the achieved frame rate.

The palette loop counts exactly 256 writes even when the initial phase is
nonzero. `CBW / XOR AL,AH` folds the triangular channel without a conditional
branch, saving nine bytes over the three conditional folds. Only Spectrum
rewrites the DAC per frame; static ramps are generated once at startup.
No frame-rate gain is asserted for the extra palette writes.

## Radial rendering optimization

CAUSAL and HORIZON reuse y*y for a whole scanline. The y multiply now runs
200 times instead of 64,000 times per frame, eliminating 63,800 multiplications
and 63,800 associated register moves. Pixel-reference tests verify unchanged
indices at clock and wrap boundaries. This is an instruction-count reduction,
not a measured speedup on physical hardware.

## Verification and captures

`tests/test_atlas_palettes.py` checks all 27 assembled binaries for complete DAC
writes, legal components, distinct families, vivid channel separation, adjacent
colour continuity and bright ramp endpoints. It verifies the Spectrum cycle
by comparing a later frame to an exact one-entry rotation and checks exact wrap.
The existing pixel, history, MIDI, exit and MEGA tests cover the shared engine.

Regenerate the actual binary captures with:

```sh
./build.sh
.venv/bin/python tools/render_temporal.py
./run-dosbox.sh atlas
./run-dosbox.sh atlas-show
```

![CAUSAL: Fire](causal-atlas.png)
![PHASE: cycling Spectrum](phase-atlas.png)
![LIFT: Orchid](lift-atlas.png)
![RESFIELD: Emerald](resfield-atlas.png)
![TERRACE: Gold](terrace-atlas.png)
![MIRROR: Rose](mirror-atlas.png)
![HORIZON: Ice](horizon-atlas.png)

The sheets show emulator framebuffer/DAC captures. The Spectrum sheets include
both field motion and colour phase; they are three still frames, not video.
