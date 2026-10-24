"""The atlas host must play every listed part and restore the DOS environment."""
import pathlib
import re

from emu import Run, BIOS_1C

ROOT = pathlib.Path(__file__).resolve().parent.parent
playlist = (ROOT / 'src' / 'mega' / 'atlas_program.inc').read_text()
names = re.findall(r'^\s+ENTRY ([a-z]+),', playlist, re.M)
assert names and len(names) == len(set(names))
instruments = []
for name in names:
    source = (ROOT / 'src' / f'{name}.asm').read_text()
    instruments.append(int(re.search(r'^%define INSTRUMENT (\d+)', source, re.M).group(1)))


def run_show(escape=False):
    r = Run('ATLAS.COM')
    for step in range(3000):
        if r.exited:
            return r
        r.step(3_000_000)
        r.tick(30)
        if escape and r.vec_sets:
            r.p60 = 1
    raise AssertionError('atlas show did not finish within the execution budget')


r = run_show()
chimes = sum(program == 14 for _, program in r.programs())
assert chimes == len(names)+2, ('missing title cards', chimes)
hooks = [event for event in r.vec_sets if event[0] == 0x1C]
assert len(hooks) == 2*len(names), ('missing part or timer restoration', len(hooks))
sequence = []
for channel, program in r.programs():
    if channel:
        continue
    if not sequence or sequence[-1] != program:
        sequence.append(program)
assert [p for p in sequence if p != 14] == instruments
assert {(channel, program) for channel, program in r.programs() if channel} == {(1, 32), (2, 45)}
notes = r.note_ons()
assert {channel for _, channel, _, _ in notes} == {0, 1, 2, 9}
assert {note for _, channel, note, _ in notes if channel == 9} >= {36, 38, 42}
assert all(note % 12 in {0, 2, 4, 7, 9} for _, channel, note, _ in notes if channel == 1)
assert all(36 <= note <= 62 for _, channel, note, _ in notes if channel == 1)
assert r.vector(0x1C) == BIOS_1C and not r.unmapped and r.exited
text = bytes(r.uc.mem_read(0xB8000, 4000))[0::2]
words = set(re.findall(rb'[A-Z]+', text))
assert all(name.upper().encode() in words for name in names), 'credits omitted an effect'
assert b'A T L A S   S H O W' in text
rows = [text[i:i+80].strip(b' \0') for i in range(0, 2000, 80)]
assert sum(any(n.upper().encode() in row.split() for n in names) for row in rows) >= 3
print(f'ATLAS: {len(names)} parts, {len(names)+2} cards, wrapped credits, timer restoration and DOS exit PASS', flush=True)

r = run_show(escape=True)
assert r.exited and r.vector(0x1C) == BIOS_1C and not r.unmapped
assert len([v for v in r.vec_sets if v[0] == 0x1C]) <= 2
print('ATLAS: Escape exits cleanly during playback PASS', flush=True)

# Start the first part and skip it with Space; the host must continue to the next card.
r = Run('ATLAS.COM')
for _ in range(300):
    r.step(3_000_000)
    r.tick(1)
    if r.vec_sets:
        break
assert len(r.vec_sets) == 1, 'first atlas part did not start'
r.p60 = 0x39
for _ in range(80):
    r.step(3_000_000)
    if len(r.vec_sets) >= 2:
        break
assert len(r.vec_sets) == 2 and not r.exited, 'Space failed to skip the current part'
r.p60 = 1
for _ in range(80):
    if r.exited:
        break
    r.step(3_000_000)
assert r.exited and r.vector(0x1C) == BIOS_1C
print('ATLAS: Space skips a part and returns to the show PASS', flush=True)
