"""Full-frame, palette, music and cleanup checks for all six 256.md effects."""

import pathlib
import re

from emu import BIOS_1C, Run
from novel_reference import NAMES, STATEFUL, frame

ROOT = pathlib.Path(__file__).resolve().parent.parent

for name in NAMES:
    source = (ROOT / "src" / f"{name.lower()}.asm").read_text(encoding="utf-8")
    instrument = int(re.search(r"^%define INSTRUMENT (\d+)", source, re.MULTILINE).group(1))
    snapshots = []
    for tick in (0, 37, 32767, 32768, 65535):
        run = Run(name + ".COM")
        run.uc.mem_write(0x46C, tick.to_bytes(4, "little"))
        run.frames(1)
        actual = run.screen()[:64000]
        expected = frame(name, tick)
        assert run.frames_seen == 1, (name, "instruction budget exhausted")
        assert actual == expected, (name, tick, "frame mismatch")
        assert len(run.com) <= 256 and not run.unmapped and not run.high
        assert len(run.dac()) == 768 and max(run.dac()) <= 63
        assert len(set(actual)) >= 2, (name, "constant frame")
        snapshots.append(actual)
    assert snapshots[0] != snapshots[1], (name, "no animation")

    if name in STATEFUL:
        run = Run(name + ".COM")
        previous = bytes(64000)
        for tick in (0, 8, 16, 24, 40, 56, 72, 96):
            run.uc.mem_write(0x46C, tick.to_bytes(4, "little"))
            run.frames(1)
            previous = frame(name, tick, previous)
            assert run.screen()[:64000] == previous, (name, tick, "history mismatch")

    run = Run(name + ".COM").frames(1)
    for _ in range(64):
        run.tick(1)
    assert run.isr_back and not run.isr_clobbers
    assert run.uart and set(run.programs()) == {(0, instrument)}
    assert not any(port in (0x42, 0x43, 0x61) for port, _value in run.outs)
    notes = run.note_ons()
    assert len(notes) == 128
    assert all(channel == 0 and 36 <= note <= 96 and note % 12 in {0, 2, 4, 7, 9}
               and 0 < velocity < 128
               for _tick, channel, note, velocity in notes)
    run.run_until_exit(1)
    assert run.exited and run.vector(0x1C) == BIOS_1C and (0x10, 3) in run.ints
    print(name, "full-frame, wrap, history, MIDI and exit PASS", flush=True)

print("Six 256.md effects PASS", flush=True)
