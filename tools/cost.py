#!/usr/bin/env python3
"""Count emulated instructions per frame at a fixed BIOS tick, excluding startup.

Instruction counts compare kernels; they do not predict hardware cycles or FPS.
The default includes standalone demos only, excluding MEGA.COM and ATLAS.COM.
"""
import argparse
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / 'tests'))
from emu import Run, ROOT
from unicorn import UC_HOOK_CODE
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('names', nargs='*', help='Standalone .COM files (default: all)')
parser.add_argument('--frames', type=int, default=3, help='Measured frames after two warmup frames')
parser.add_argument('--tick', type=int, default=37, help='Fixed unsigned 32-bit BIOS clock value')
args = parser.parse_args()
if args.frames < 1 or not 0 <= args.tick <= 0xFFFFFFFF:
    parser.error('frames must be positive and tick must fit an unsigned 32-bit value')
names = args.names or sorted(p.stem.upper()+'.COM' for p in (ROOT / 'src').glob('*.asm'))
for name in names:
    if pathlib.Path(name).stem.upper() in ('MEGA', 'ATLAS'):
        parser.error('Choose standalone effects; show hosts have no single repeating frame')
for name in names:
    r = Run(None, pathlib.Path(name if '/' in name else ROOT / name).read_bytes())
    if name.upper().startswith('WARP'): r.uc.mem_write(0xB8000, bytes((i * 7) & 255 for i in range(4000)))
    r.uc.mem_write(0x46C, args.tick.to_bytes(4, 'little'))
    n = [0]
    def count(uc, a, s, d): n[0] += 1
    r.uc.hook_add(UC_HOOK_CODE, count)             # (before the first run: Unicorn caches translated blocks)
    r.polls(2); n0 = n[0]                          # settle: set-up and the first frame
    if r.kb_reads != 2:
        raise RuntimeError(name + ': warmup did not complete within the instruction budget')
    k = args.frames; r.polls(k)
    if r.kb_reads != 2+k:
        raise RuntimeError(name + ': measurement did not complete within the instruction budget')
    per = (n[0] - n0) / k
    print(f'{pathlib.Path(name).stem:8} {per:10,.0f} instructions/frame at BIOS tick {args.tick}', flush=True)
