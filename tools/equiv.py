#!/usr/bin/env python3
"""Run two builds of a demo side by side in the emulator and compare what reaches the screen, frame by frame:
video memory, the DAC stream, and every CRTC (3D4h), graphics-controller (3CEh) and sequencer (3C4h) write.
usage: tools/equiv.py OLD.COM NEW.COM FRAMES [--text] [--polls]
  --text seeds the B800h text page (WARP); --polls counts frames by keyboard polls instead of retraces"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / 'tests'))
from emu import Run
old, new, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
a = Run(None, pathlib.Path(old).read_bytes()); b = Run(None, pathlib.Path(new).read_bytes())
if '--text' in sys.argv:
    for r in (a, b): r.uc.mem_write(0xB8000, bytes((i * 7) & 255 for i in range(4000)))
def regs(r): return [(p, v) for p, v in r.outs if p in (0x3D4, 0x3CE, 0x3C4, 0x3C8)]
bad = 0
for f in range(n):
    if '--polls' in sys.argv: a.polls(1); b.polls(1)
    else: a.frames(1); b.frames(1)
    sa, sb = a.screen()[:64000], b.screen()[:64000]
    if '--text' in sys.argv: sa, sb = bytes(a.uc.mem_read(0xB8000, 4000)), bytes(b.uc.mem_read(0xB8000, 4000))
    d = sum(x != y for x, y in zip(sa, sb))
    if d or a.dac() != b.dac() or regs(a) != regs(b):
        bad += 1
        if bad <= 5: print(f'frame {f}: {d} pixels differ, dac equal {a.dac() == b.dac()}, regs equal {regs(a) == regs(b)}')
print('IDENTICAL' if not bad else f'{bad} of {n} frames differ', f'({len(a.com)} -> {len(b.com)} bytes)')
sys.exit(1 if bad else 0)
