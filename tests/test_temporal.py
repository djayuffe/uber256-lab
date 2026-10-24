"""Behavioral checks for the atlas-inspired DOS adaptations."""
import pathlib
import re

from emu import Run, BIOS_1C

ROOT = pathlib.Path(__file__).resolve().parent.parent


def triangle(value):
    signed = ((value + 128) & 255) - 128
    return (2 * abs(signed)) & 255


def pixel(name, x, y, tick):
    t = (tick * 2) & 65535
    if name == 'CAUSAL':
        radius = (x*x + y*y) >> 8
        return triangle(t - radius - (radius & ~15) + x - y)
    if name == 'HORIZON':
        return triangle((t * (((x*x+y*y) >> 8)+1) >> 8) + x-y)
    if name == 'COMMUTE':
        a, b = (2*x+y, x+y) if t & 128 else (x+y, x+2*y)
        return triangle(a+t) ^ triangle(b-t)
    if name == 'LIFT':
        n = (t >> 3) & 31
        a, b = x & 255, y & 255
        for _ in range(min(n, 32-n)):
            a = (a+b) & 255
            b ^= a
        return a ^ b
    if name == 'MIRROR':
        a, b = x & 65535, y & 65535
        if (x+y+t) & 64:
            a ^= 255
            b ^= 127
        return triangle(((a*b) & 65535) >> 3)
    if name == 'RESFIELD':
        n = ((x+y+t) >> 5) & 3
        a, b = (x >> n) << n, (y >> n) << n
        return triangle((((a*b) & 65535) >> 4) + t)
    if name == 'SHUFFLE':
        a = x+160
        lane = (a & 31) ^ ((t >> 2) & 31)
        return ((triangle((a & ~31)+lane+y) ^ triangle(x-y+t)) + x) & 255
    return (triangle(x+t) + triangle(y-t) - triangle(x+y+(t >> 1))) & 255


for name in ('CAUSAL', 'PHASE', 'HORIZON', 'COMMUTE', 'LIFT', 'MIRROR', 'RESFIELD', 'SHUFFLE'):
    source = (ROOT / 'src' / f'{name.lower()}.asm').read_text()
    instrument = int(re.search(r'^%define INSTRUMENT (\d+)', source, re.M).group(1))
    snapshots = []
    for tick in (0, 37, 32767, 32768, 65535):
        r = Run(name + '.COM')
        r.uc.mem_write(0x46C, tick.to_bytes(4, 'little'))
        r.frames(1)
        screen = r.screen()[:64000]
        assert len(r.com) <= 256
        assert r.ints[0] == (0x10, 0x13)
        assert len(r.dac()) == 768 and max(r.dac()) <= 63
        assert not r.unmapped and not r.high
        assert all(screen[y*320+x] == pixel(name, x-160, y-100, tick)
                   for y in range(0, 200, 7) for x in range(0, 320, 7)), (name, tick)
        assert len(set(screen)) >= 64, (name, tick, 'colour diversity')
        snapshots.append(screen)
    assert sum(a != b for a, b in zip(snapshots[0], snapshots[1])) > 10000, (name, 'animation')
    r = Run(name + '.COM').frames(1)
    for _ in range(64):
        r.tick(1)
    assert r.isr_back and not r.isr_clobbers
    assert r.uart and r.programs() and set(r.programs()) == {(0, instrument)}
    notes = r.note_ons()
    assert len(notes) == 128
    assert all(ch == 0 and 36 <= note <= 96 and note % 12 in {0, 2, 4, 7, 9}
               and 0 < vel < 128 for _, ch, note, vel in notes)
    assert all(lead[0] == response[0] and lead[2] - response[2] == 24
               for lead, response in zip(notes[0::2], notes[1::2]))
    assert not any(p in (0x42, 0x43, 0x61) for p, _ in r.outs)
    r.run_until_exit(1)
    assert r.exited and r.vector(0x1C) == BIOS_1C and (0x10, 3) in r.ints
    print(f'{name}: size, pixel reference, clock wrap, animation, MIDI and exit PASS')

# Exhaustive byte-pair checks: the lifting step loses no state, even on overflow.
for a in range(256):
    for b in range(256):
        c = (a+b) & 255
        d = b ^ c
        recovered_b = d ^ c
        assert ((c-recovered_b) & 255, recovered_b) == (a, b)
        assert ((a ^ 255) ^ 255, (b ^ 127) ^ 127) == (a, b)
for mask in range(32):
    assert sorted(lane ^ mask for lane in range(32)) == list(range(32))
print('Lifting inverse, mirror involution and lane bijection invariants PASS')
