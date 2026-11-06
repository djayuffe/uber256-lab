# Browser MIDI architecture

The browser player has two deliberately separate audio paths:

1. DOS Wasm X writes emulated PCM into its ring buffer. `web/index.html` copies that
   buffer into a Web Audio `ScriptProcessorNode`.
2. `web/midi.js` generates the musical companion directly with Web Audio. It does not
   pretend that the vendored Wasm build exposes MIDI: that build accepts an MPU-401
   configuration but was compiled without a host MIDI backend.

Native DOSBox remains the reference for the exact bytes emitted at port `330h`. The
browser path follows the same musical rules while staying dependency-free and usable
from a static web server.

## Data flow

```text
DOS frame -> RGBA framebuffer -> deterministic pixel sampler
                                      |
BIOS-rate scheduler (18.2 Hz) -> MidiSequence -> MIDI-shaped messages
                                                   |
                                            WebAudioMidiSynth
                                                   |
                                  oscillators + filters + noise -> master gain
```

The web-specific MEGA.COM and ATLAS.COM builds update a signed `UBSYNC` record in
their own emulated DOS memory: an event counter, either zero for a title card or the
one-based part number, and a browser-command byte. The page locates that record in the Wasm heap and checks it
every 10 ms. This makes show selection, title cards, timed transitions and Space skips
authoritative; the browser never guesses a part from elapsed time. Release COM files are
built without this channel. Rerun/show selection reloads a clean emulator instance with
the selection preserved in the URL. This deliberately requires another user start gesture,
which both satisfies Web Audio policy and prevents stale DOS vectors or queued shell input.

The third byte is the reverse control path. Thumbnail clicks, previous/next buttons and
←/→ keys write a bounded one-based target part there. The DOS host consumes it at its
next frame boundary, restores the current part's timer hook, shows the requested title
card and emits a new transition record. Visuals, instrument choice and score tick therefore
change together; the controls never fake a browser-only part number.

At every active-part score tick the sampler reads one deterministic point from the current logical
320x200 image. Brightness is quantised to the C-major pentatonic scale. The sequence
adds a response two octaves below the lead. ATLAS also adds a tick hi-hat, alternating
kick/snare, acoustic bass, and pizzicato root/fifth harmony. Program changes follow the
MEGA or ATLAS playlist and wrap with the show.

`BrowserMidi` uses the exact PC PIT-derived BIOS rate, `1193182 / 65536` Hz. It schedules
30 ms ahead and pumps every 20 ms, keeping jitter low without letting old-part notes be
queued far beyond a real transition. A card marker stops the score and rings its chime;
a part marker resets the tick and selects the matching playlist voice. Hiding the tab
stops the scheduler instead of releasing a burst of overdue notes. Calling `start()`
twice cannot create a second timer.

## Synthesizer

`WebAudioMidiSynth` accepts the subset of MIDI used by the companion:

- channel program changes;
- note-on messages for melodic channels;
- General MIDI channel 10 kick, snare and closed hi-hat.

Instrument families select sine, triangle, saw or square oscillators, filtered and
shaped with short envelopes. Drums use a swept oscillator or a cached noise buffer.
Every voice stops itself, so the engine cannot accumulate sustained oscillators. The
master gain is controlled by the player volume slider and mute button.

## Testing

`tests/test_web_midi.js` verifies:

- all 27 ATLAS and 13 MEGA program slots and their exact boundaries;
- program maps derived back to the assembly playlists and each effect's `INSTRUMENT` value;
- the exact PIT-derived clock and maximum scheduling horizon;
- playlist wraparound;
- every possible framebuffer sample maps into C-major pentatonic notes;
- the two-octave lead response;
- all expected channels, bass/harmony and drum voices.

Run it directly with `node tests/test_web_midi.js`, or as part of `tests/run_tests.sh`.

## Limitations

This is a synchronized visual companion score, not captured MPU-401 output. Part/card
boundaries come from the running DOS show and the score uses its exact timer rate, but
browser oscillator timbres are not a
General MIDI soundfont and the player cannot intercept the port writes inside the
current Wasm binary. Rebuilding DOS Wasm X with a FluidSynth or Web MIDI host backend
would be the route to byte-for-byte browser playback. Until then, use native DOSBox and
the recordings under `docs/music/` when exact MIDI output matters.
