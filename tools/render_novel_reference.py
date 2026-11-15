#!/usr/bin/env python3
"""Render deterministic reference contact sheets for the six 256.md effects."""

from __future__ import annotations

import argparse
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tests"))
from novel_reference import NAMES, STATEFUL, frame  # noqa: E402

PALETTES = {
    "XORTUN": 7,
    "PLASMA": 7,
    "CAFLAME": 1,
    "VOXFLOOR": 5,
    "KALEIDO": 6,
    "RAYMARCH": 4,
}


def channel(kind: str, value: int) -> int:
    if kind == "fast":
        return min(value >> 1, 63)
    if kind == "linear":
        return value >> 2
    if kind == "quarter":
        return value >> 4
    shifts = {"square": 10, "squarehalf": 11, "squarequarter": 12}
    return (value * value) >> shifts[kind]


def wave(value: int, phase: int) -> int:
    folded = (value + phase) & 255
    if folded & 128:
        folded ^= 255
    return max(0, folded - 64)


def palette(family: int, tick: int) -> list[int]:
    kinds = {
        1: ("fast", "square", "quarter"),
        4: ("squarehalf", "fast", "linear"),
        5: ("fast", "linear", "squarequarter"),
        6: ("fast", "squarequarter", "linear"),
    }
    rgb = []
    for index in range(256):
        if family == 7:
            value = (index + (tick >> 2)) & 255
            colour = (wave(value, 0), wave(value, 85), wave(value, 170))
        else:
            colour = tuple(channel(kind, index) for kind in kinds[family])
        rgb.extend(round(component * 255 / 63) for component in colour)
    return rgb


def contact_sheet(name: str) -> Image.Image:
    ticks = (31, 47, 63) if name in STATEFUL else (0, 37, 91)
    previous = None
    frames = []
    timeline = range(0, ticks[-1] + 1) if name in STATEFUL else ticks
    for tick in timeline:
        indices = frame(name, tick, previous)
        if name in STATEFUL:
            previous = indices
        if tick not in ticks:
            continue
        image = Image.frombytes("P", (320, 200), indices)
        image.putpalette(palette(PALETTES[name], tick))
        frames.append(image.convert("RGB"))
    sheet = Image.new("RGB", (960, 200))
    for index, image in enumerate(frames):
        sheet.paste(image, (320 * index, 0))
    return sheet


def render(name: str, check: bool) -> bool:
    sheet = contact_sheet(name)
    output = ROOT / "docs" / f"{name.lower()}-atlas.png"
    if check:
        if not output.exists() or Image.open(output).convert("RGB").tobytes() != sheet.tobytes():
            print(f"stale reference image: {output.relative_to(ROOT)}", file=sys.stderr)
            return False
        print(f"verified {output.relative_to(ROOT)}")
        return True
    sheet.save(output, optimize=True)
    print(f"wrote {output.relative_to(ROOT)}")
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if not all(render(effect, args.check) for effect in NAMES):
        raise SystemExit(1)
