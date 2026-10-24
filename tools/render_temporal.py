#!/usr/bin/env python3
"""Capture the actual emulated framebuffer and VGA DAC; no image dependencies."""
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'tests'))
from emu import Run
from atlas_state_reference import NAMES, STATEFUL

ALL_NAMES = ('CAUSAL', 'PHASE', 'HORIZON', 'COMMUTE', 'LIFT', 'MIRROR',
             'RESFIELD', 'SHUFFLE') + NAMES


def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))


def capture(name):
    """Write a three-frame contact sheet; preserve history for stateful kernels."""
    images = []
    ticks = (0, 8, 16) if name in STATEFUL else (0, 37, 91)
    run = None
    for tick in ticks:
        if run is None or name not in STATEFUL:
            run = Run(name + '.COM')
        run.uc.mem_write(0x46C, tick.to_bytes(4, 'little'))
        before = run.frames_seen
        run.frames(1)
        if run.frames_seen != before+1:
            raise RuntimeError(name + ': frame did not finish within instruction budget')
        palette = [round(v * 255 / 63) for v in run.dac()[:768]]
        screen = run.screen()[:64000]
        images.append(bytes(c for p in screen for c in palette[3*p:3*p+3]))
    rows = b''.join(b'\0' + b''.join(im[y*960:(y+1)*960] for im in images) for y in range(200))
    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', 960, 200, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(rows)) + chunk(b'IEND', b'')
    (ROOT / 'docs' / (name.lower() + '-atlas.png')).write_bytes(png)
    print(name, 'captured at BIOS ticks', ticks, flush=True)


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('names', nargs='*', help='Demo names; default: all atlas adaptations')
    args = parser.parse_args()
    names = [name.upper() for name in args.names] or ALL_NAMES
    for name in names:
        if name not in ALL_NAMES:
            parser.error('Unknown atlas demo: ' + name)
    for name in names:
        capture(name)
