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

catalog = load_catalog(ROOT / "web" / "catalog.js")
standalone = catalog["standalone"]
shows = catalog["shows"]
source_names = {path.stem.upper() for path in (ROOT / "src").glob("*.asm")}

assert len(standalone) == 42
assert len({entry[0] for entry in standalone}) == 42
assert {entry[0] for entry in standalone} == source_names
assert len(shows["MEGA"]) == 15 and len(shows["ATLAS"]) == 27
assert set(shows) == {"MEGA", "ATLAS", "UBERSHOW", "UBER70"}

for name, image, size in [*standalone, *shows["UBERSHOW"], *shows["UBER70"]]:
    assert (ROOT / f"{name}.COM").stat().st_size == size
    assert (ROOT / "docs" / image).is_file()
    assert name in source_names or name in {"UBERSHOW", "UBER70"}

html = (ROOT / "dist" / "uber256-lab.html").read_text(encoding="utf-8")
assignment = re.compile(r"^window\.([A-Z0-9_]+)=(.*);$", re.MULTILINE)
embedded = {name: json.loads(value) for name, value in assignment.findall(html)}
expected_programs = source_names | {"MEGA", "ATLAS", "UBERSHOW", "UBER70"}
assert set(embedded["EMBEDDED_COM"]) == expected_programs
assert set(embedded["EMBEDDED_ASM"]) == source_names | {"UBERSHOW", "UBER70"}
assert embedded["UBER256_CATALOG"] == catalog
assert {entry[1] for entries in [standalone, *shows.values()] for entry in entries} == set(embedded["EMBEDDED_THUMBNAILS"])

print("Web catalogue: 42 standalone demos + 4 integrated programs, thumbnails, ASM and COM payloads PASS")
