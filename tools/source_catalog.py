#!/usr/bin/env python3
"""Return every assembly source exposed by the browser workbench."""

from __future__ import annotations

import pathlib
import re

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


INCLUDE = re.compile(r'^\s*%include\s+"([^"]+)"\s*(?:;.*)?$', re.MULTILINE)


def expanded_atlas_source(path: pathlib.Path) -> str:
    """Inline the ATLAS shared engine for the browser listing, never for builds."""
    seen: set[pathlib.Path] = set()

    def expand(current: pathlib.Path) -> str:
        current = current.resolve()
        if current in seen:
            return f"; [already listed: {current.name}]"
        seen.add(current)
        text = current.read_text(encoding="utf-8")

        def replace(match: re.Match[str]) -> str:
            include = current.parent / match.group(1)
            if not include.is_file():
                include = ROOT / "src" / match.group(1)
            if not include.is_file():
                return match.group(0)
            return (f"; ---- begin {include.name} ----\n"
                    f"{expand(include)}\n"
                    f"; ---- end {include.name} ----")

        return INCLUDE.sub(replace, text)

    return expand(path)


def source_text() -> dict[str, str]:
    result = {}
    for name, path in source_paths().items():
        text = path.read_text(encoding="utf-8")
        result[name] = expanded_atlas_source(path) if '%include "atlas_effect.inc"' in text else text
    return result
