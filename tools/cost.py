#!/usr/bin/env python3
"""Instructions per frame of each demo, counted in the emulator between keyboard polls (every demo polls once per
frame), and the DOSBox 'cycles' setting that gives a full 70 frames a second: DOSBox's normal core, the one real-mode
code runs on, charges one cycle per instruction, so cycles = instructions per frame * 70.086 / 1000.
usage: tools/cost.py [NAME.COM ...]   (default: every demo)"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / 'tests'))
from emu import Run, ROOT
from unicorn import UC_HOOK_CODE
names = sys.argv[1:] or sorted(p.name for p in ROOT.glob('*.COM'))
for name in names:
    r = Run(None, pathlib.Path(name if '/' in name else ROOT / name).read_bytes())
    if name.upper().startswith('WARP'): r.uc.mem_write(0xB8000, bytes((i * 7) & 255 for i in range(4000)))
    n = [0]
    def count(uc, a, s, d): n[0] += 1
    r.uc.hook_add(UC_HOOK_CODE, count)             # (before the first run: Unicorn caches translated blocks)
    r.polls(2); n0 = n[0]                          # settle: set-up and the first frame
    k = 3; r.polls(k)
    per = (n[0] - n0) / k
    print(f'{pathlib.Path(name).stem:8} {per:10,.0f} instructions a frame   70 fps from cycles={per * 70.086 / 1000:,.0f}')
