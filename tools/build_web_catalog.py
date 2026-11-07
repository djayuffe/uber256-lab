#!/usr/bin/env python3
"""Write the generated browser catalogue used by modular and standalone builds."""

from __future__ import annotations

import pathlib
import sys

from web_catalog import build_catalog, javascript

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTPUT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "web" / "catalog.js"

OUTPUT.write_text(javascript(), encoding="utf-8")
catalog = build_catalog()
print(f"{OUTPUT} ({len(catalog['standalone'])} standalone demos, {len(catalog['shows'])} integrated programs)")
