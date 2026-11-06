#!/usr/bin/env python3
"""Build and verify a serverless, single-file UBER256 browser player."""

from __future__ import annotations

import base64
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
DEFAULT_OUTPUT = ROOT / "dist" / "uber256-lab.html"
ASSETS = {
    "MEGA": WEB / "MEGA.COM",
    "ATLAS": WEB / "ATLAS.COM",
    "font": WEB / "main.ttf",
    "wasm": WEB / "main.wasm",
    "main_js": WEB / "main.js",
}


def encoded(path: pathlib.Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def build(output: pathlib.Path) -> None:
    missing = [str(path) for path in [WEB / "index.html", WEB / "midi.js", *ASSETS.values()] if not path.is_file()]
    if missing:
        raise SystemExit("Missing web assets (run ./build.sh first): " + ", ".join(missing))

    template = (WEB / "index.html").read_text(encoding="utf-8")
    midi = (WEB / "midi.js").read_text(encoding="utf-8")
    marker = '<script src="midi.js"></script>'
    if marker not in template or "</script>" in midi.lower():
        raise SystemExit("web/index.html or web/midi.js is not safe for deterministic inlining")

    payload = {
        "COM": {"MEGA": encoded(ASSETS["MEGA"]), "ATLAS": encoded(ASSETS["ATLAS"])},
        "TTF": encoded(ASSETS["font"]),
        "WASM": encoded(ASSETS["wasm"]),
        "MAIN_JS": encoded(ASSETS["main_js"]),
    }
    bootstrap = (
        "<script>\n"
        f"window.EMBEDDED_COM={json.dumps(payload['COM'], separators=(',', ':'))};\n"
        f"window.EMBEDDED_TTF={json.dumps(payload['TTF'])};\n"
        f"window.EMBEDDED_WASM={json.dumps(payload['WASM'])};\n"
        f"window.EMBEDDED_MAIN_JS={json.dumps(payload['MAIN_JS'])};\n"
        "</script>\n<script>\n" + midi + "\n</script>"
    )
    html = template.replace(marker, bootstrap, 1)
    # The standalone build makes no network request for decorative web fonts.
    html = "\n".join(line for line in html.splitlines() if "fonts.googleapis.com" not in line)
    digest = hashlib.sha256(html.encode("utf-8")).hexdigest()
    html = html.replace("<!doctype html>", f"<!doctype html>\n<!-- self-contained build sha256:{digest} -->", 1)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(html, encoding="utf-8")
    verify(output)


def verify(output: pathlib.Path) -> None:
    html = output.read_text(encoding="utf-8")
    checks = {
        "MEGA.COM": f'"MEGA":"{encoded(ASSETS["MEGA"])}"',
        "ATLAS.COM": f'"ATLAS":"{encoded(ASSETS["ATLAS"])}"',
        "main.wasm": f'window.EMBEDDED_WASM="{encoded(ASSETS["wasm"])}"',
        "main.js": f'window.EMBEDDED_MAIN_JS="{encoded(ASSETS["main_js"])}"',
        "main.ttf": f'window.EMBEDDED_TTF="{encoded(ASSETS["font"])}"',
        "MIDI engine": "const SCHEDULE_AHEAD = 0.03;",
    }
    failed = [name for name, needle in checks.items() if needle not in html]
    if failed or 'src="midi.js"' in html or "fonts.googleapis.com" in html:
        raise SystemExit("Invalid standalone HTML: " + ", ".join(failed or ["external dependency remained"]))


if __name__ == "__main__":
    target = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_OUTPUT
    build(target)
    print(f"{target} ({target.stat().st_size:,} bytes, all runtime assets embedded)")
