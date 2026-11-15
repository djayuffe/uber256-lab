#!/usr/bin/env python3
"""Cross-check every browser binary, thumbnail and assembly source."""

from __future__ import annotations

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from web_catalog import load_catalog  # noqa: E402
from source_catalog import source_paths  # noqa: E402

catalog = load_catalog(ROOT / "web" / "catalog.js")
standalone = catalog["standalone"]
shows = catalog["shows"]
current_source_names = {path.stem.upper() for path in (ROOT / "src").glob("*.asm")}
source_names = set(source_paths())

assert len(standalone) == 80
assert len({entry[0] for entry in standalone}) == 80
assert current_source_names <= {entry[0] for entry in standalone}
assert {entry[0] for entry in standalone} <= source_names
assert len(shows["MEGA"]) == 15 and len(shows["ATLAS"]) == 27
assert set(shows) == {"MEGA", "ATLAS", "UBERSHOW", "UBER70", "UBER40K"}

for name, image, size in [*standalone, *shows["UBERSHOW"], *shows["UBER70"], *shows["UBER40K"]]:
    assert (ROOT / f"{name}.COM").stat().st_size == size
    assert (ROOT / "docs" / image).is_file()
    assert name in source_names

html = (ROOT / "dist" / "uber256-lab.html").read_text(encoding="utf-8")
source_html = (ROOT / "web" / "index.html").read_text(encoding="utf-8")
assert 'aria-label="Skip to next part">SKIP →</button>' in source_html
assert "let activeSyncOffset = -1, currentPart = 0, pendingPart = 0;" in source_html
assert "if (hasPartControl() && !currentPart) currentPart = 1;" in source_html
assert "heap[activeSyncOffset + 2] = pendingPart;" in source_html
assert "if (!hasPartControl() || e.target.matches('input, select')) return;" in source_html
assert "if (e.code === 'ArrowLeft' || e.code === 'ArrowRight')" in source_html
assert "if (e.code === 'Space')" in source_html and "movePart(1);" in source_html
assignment = re.compile(r"^window\.([A-Z0-9_]+)=(.*);$", re.MULTILINE)
embedded = {name: json.loads(value) for name, value in assignment.findall(html)}
expected_programs = {entry[0] for entry in standalone} | set(shows)
assert set(embedded["EMBEDDED_COM"]) == expected_programs
assert set(embedded["EMBEDDED_ASM"]) == source_names
for name, _image, _size in shows["ATLAS"]:
    listing = embedded["EMBEDDED_ASM"][name]
    assert '; ---- begin atlas_effect.inc ----' in listing
    assert '; ---- begin temporal.inc ----' in listing
    assert '; ---- begin dos.inc ----' in listing
    assert '; ---- begin palettes.inc ----' in listing
for name in ("XORTUN", "PLASMA", "CAFLAME", "VOXFLOOR", "KALEIDO", "RAYMARCH"):
    listing = embedded["EMBEDDED_ASM"][name]
    assert '; ---- begin novel_effect.inc ----' in listing
    assert '; ---- begin temporal.inc ----' in listing
    assert '; ---- begin dos.inc ----' in listing
    assert '; ---- begin palettes.inc ----' in listing
assert embedded["UBER256_CATALOG"] == catalog
assert {entry[1] for entries in [standalone, *shows.values()] for entry in entries} == set(embedded["EMBEDDED_THUMBNAILS"])

print("Web catalogue: 80 standalone demos + 5 integrated programs, thumbnails, ASM and COM payloads PASS")
