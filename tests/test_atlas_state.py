"""Full-frame and history checks, with no dependence on the assembly formulas."""
import pathlib
import re

from emu import Run, BIOS_1C
from atlas_state_reference import NAMES, STATEFUL, pixel, rotate

ROOT = pathlib.Path(__file__).resolve().parent.parent


def frame(name, tick, previous=None):
    previous = previous or bytes(64000)
    return bytes(pixel(name, i % 320-160, i // 320-100, tick, previous[i])
                 for i in range(64000))


def components(image):
    """Count four-connected occupied regions, without joining opposite row edges."""
    occupied = {(i % 320, i // 320) for i, value in enumerate(image) if value}
    count = 0
    while occupied:
        count += 1
        pending = [occupied.pop()]
        while pending:
            x, y = pending.pop()
            for neighbour in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if neighbour in occupied:
                    occupied.remove(neighbour)
                    pending.append(neighbour)
    return count


for name in NAMES:
    source = (ROOT / 'src' / f'{name.lower()}.asm').read_text()
    instrument = int(re.search(r'^%define INSTRUMENT (\d+)', source, re.M).group(1))
    snapshots = []
    for tick in (0, 37, 32767, 32768, 65535):
        r = Run(name+'.COM')
        r.uc.mem_write(0x46C, tick.to_bytes(4, 'little'))
        r.frames(1)
        actual = r.screen()[:64000]
        assert r.frames_seen == 1, (name, 'instruction budget exhausted')
        assert r.ints[0] == (0x10, 0x13)
        assert actual == frame(name, tick), (name, tick, 'frame mismatch')
        assert len(r.com) <= 256 and len(r.dac()) == 768 and max(r.dac()) <= 63
        assert not r.high and not r.unmapped
        assert len(set(actual)) >= 2, (name, 'constant frame')
        snapshots.append(actual)
    assert snapshots[0] != snapshots[1], (name, 'no animation')
    if name == 'SURGERY':
        assert [components(image) for image in snapshots[:2]] == [1, 2], 'topology did not split'
    if name in STATEFUL:
        r = Run(name+'.COM')
        previous = bytes(64000)
        for tick in (0, 8, 16, 24, 40, 56, 72, 96, 65535, 0):
            r.uc.mem_write(0x46C, tick.to_bytes(4, 'little'))
            r.frames(1)
            previous = frame(name, tick, previous)
            assert r.screen()[:64000] == previous, (name, tick, 'history mismatch')
        assert not r.unmapped and not r.high
    r = Run(name+'.COM').frames(1)
    for _ in range(64):
        r.tick(1)
    assert r.isr_back and not r.isr_clobbers
    assert r.uart and r.programs() and set(r.programs()) == {(0, instrument)}
    assert not any(port in (0x42, 0x43, 0x61) for port, _ in r.outs)
    notes = r.note_ons()
    assert len(notes) == 128
    assert all(ch == 0 and 36 <= note <= 96 and note % 12 in {0, 2, 4, 7, 9}
               and 0 < vel < 128 for _, ch, note, vel in notes)
    assert all(lead[0] == response[0] and lead[2] - response[2] == 24
               for lead, response in zip(notes[0::2], notes[1::2]))
    r.run_until_exit(1)
    assert r.exited and r.vector(0x1C) == BIOS_1C and (0x10, 3) in r.ints
    print(name, 'full-frame, wrap, history, MIDI and exit PASS', flush=True)

for a in range(65536):
    b = rotate(a+1973, 5, 16) ^ 0xA53C
    recovered = (rotate(b ^ 0xA53C, 11, 16)-1973) & 65535
    assert recovered == a
print('REVERSO exhaustive 16-bit inverse PASS')

# The hysteresis dead band really depends on history, not just the current clock.
assert pixel('HYSTER', 60, 0, 0, 0) == 0
assert pixel('HYSTER', 60, 0, 0, 255) == 255
assert rotate((1+17) & 255, 1, 8) != (rotate(1, 1, 8)+17) & 255
print('Hysteresis history dependence and loom noncommutativity PASS')

for mask in range(256):
    for initial in range(256):
        state = initial
        for _ in range(16):
            state = rotate(state, 1, 8) ^ mask
        assert state == initial
print('ORBIT: bounded return for all 65,536 mask/seed pairs PASS')
