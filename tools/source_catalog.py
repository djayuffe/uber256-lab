#!/usr/bin/env python3
"""Return every assembly source exposed by the browser workbench."""

from __future__ import annotations

import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent


def source_paths() -> dict[str, pathlib.Path]:
    sources = {
        path.stem.upper(): path
        for path in sorted((ROOT / "src").glob("*.asm"))
    }
    micro = ROOT / "archive" / "uber-micro-demos" / "src"
    for path in sorted(micro.glob("*.asm")):
        key = "MIRROR8" if path.stem.lower() == "mirror" else path.stem.upper()
        sources[key] = path
    sources.update({
        "UBER10": ROOT / "archive" / "uber10-dos-demo" / "uber10.asm",
        "UBER128": ROOT / "archive" / "uber128-dos-demo" / "uber128.asm",
        "UBER70": ROOT / "archive" / "uber256-megademo" / "intro256.asm",
        "UBERSHOW": ROOT / "archive" / "uber256-megademo" / "showcase.asm",
        "UBER40K": ROOT / "archive" / "uber40k-dos-demo" / "showcase.asm",
    })
    return sources


def source_text() -> dict[str, str]:
    return {name: path.read_text(encoding="utf-8") for name, path in source_paths().items()}
