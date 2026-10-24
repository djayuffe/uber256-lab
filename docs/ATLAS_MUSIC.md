# Atlas music engine

The atlas score is generated live from the framebuffer and the BIOS clock. No
MIDI file, sample or prerecorded track is embedded. Every standalone remains at
most 256 bytes and restores INT 1Ch before returning to DOS.

## Standalone score

At each 18.2 Hz timer tick, the handler samples framebuffer byte
`[(BIOS_tick * 321) mod 65536]`. It masks that value to an even degree, offsets
it and maps it to C-major pentatonic with `aam 5` / `aad 6`. The resulting lead
is 60..96. The same voice immediately answers two octaves below at 36..72. Both
notes use pitch as velocity, giving brighter pixels a higher and louder sound.
The four-byte response is the only size increase; the largest atlas binaries,
CRITICAL and the original CHLADNI, are 251 bytes.

The instrument numbers below are zero-based General MIDI program values, which
is what the MPU-401 stream carries.

| Effect | Program | Voice |
|---|---:|---|
| CAUSAL | 10 | Music box |
| TIMELENS | 11 | Vibraphone |
| HORIZON | 12 | Marimba |
| EMBOSS | 13 | Xylophone |
| PHASE | 9 | Glockenspiel |
| SURGERY | 15 | Dulcimer |
| COMMUTE | 24 | Nylon guitar |
| BRACKET | 25 | Steel guitar |
| MIRROR | 26 | Jazz guitar |
| SIGNED | 27 | Clean guitar |
| RESFIELD | 28 | Muted guitar |
| TERRACE | 29 | Overdriven guitar |
| RESIDUAL | 30 | Distortion guitar |
| BIFURC | 31 | Guitar harmonics |
| CRITICAL | 45 | Pizzicato strings |
| HYSTER | 46 | Orchestral harp |
| LOOM | 104 | Sitar |
| LIFT | 105 | Banjo |
| REVERSO | 106 | Shamisen |
| ORBIT | 107 | Koto |
| RUNS | 108 | Kalimba |
| BYTEVM | 114 | Steel drums |
| SHUFFLE | 115 | Woodblock |
| BALLOT | 116 | Taiko drum |
| PREFIX | 117 | Melodic tom |
| RANK | 118 | Synth drum |
| RING | 119 | Reverse cymbal |

The sequence deliberately moves from bells and mallets through guitars and
strings into world instruments and tuned percussion, so successive parts have
audibly different identities without storing a score.

## Continuous-show arrangement

`ATLAS.COM` retains the effect-specific lead and low response on channel 1, then
adds three synchronized layers in its shared MIDI service:

- Channel 10 plays a closed hi-hat every tick. Velocity cycles from 32 to 47.
  Every fourth tick it also alternates kick 36 and snare 38.
- Channel 2 uses acoustic bass program 32. Every fourth tick it walks through
  clock-derived C-major-pentatonic roots at velocity 72.
- Channel 3 uses pizzicato strings program 45. With each bass step it plays the
  root one octave higher and its fifth, at velocities 52 and 44.

All layers derive from the same BIOS tick, so rendering speed cannot change the
tempo or separate the voices. The lead remains coupled to the current visual:
changing pixels changes its pitch while the rhythm section keeps time. Title
cards retain their tubular-bell fifth and therefore mark transitions clearly.

## MIDI and lifecycle details

The handler enters MPU-401 UART mode, selects the current effect's channel-1
program and emits note-on messages using MIDI running status where possible.
Voices were chosen for natural or short decay, allowing the 256-byte standalones
to omit explicit note-off state. The interrupt preserves all general registers,
uses FS=0 for the BIOS data area instead of trusting the interrupted DS, and is
unhooked on normal exit, timed show transitions, Space skip and Escape.

The emulator tests decode the actual port-330h byte stream. They verify each
effect's program, exact octave pairing, pitch class, range and velocity. The
full-show test additionally requires channels 1, 2, 3 and 10; both alternating
drums; the hi-hat; bass scale/range; every programmed lead voice; all timer-hook
pairs; and clean DOS exit. These are structural MIDI checks, not an assertion
about a particular synthesizer's subjective sound or latency.
