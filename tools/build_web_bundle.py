#!/usr/bin/env python3
"""Build and verify a serverless, single-file UBER256 browser player."""

from __future__ import annotations

import base64
import binascii
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
DEFAULT_OUTPUT = ROOT / "dist" / "uber256-lab.html"
BANNER_RE = re.compile(
    r"<!-- self-contained content sha256:([0-9a-f]{64}) \(excludes this comment\) -->\n"
)
ASSETS = {
    "MEGA": WEB / "MEGA.COM",
    "ATLAS": WEB / "ATLAS.COM",
    "UBER70": WEB / "UBER70.COM",
    "UBERSHOW": WEB / "UBERSHOW.COM",
    "font": WEB / "main.ttf",
    "wasm": WEB / "main.wasm",
    "main_js": WEB / "main.js",
}


def encoded(path: pathlib.Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def json_for_script(value: object, *, ascii_only: bool = True) -> str:
    """Serialize data without allowing an embedded value to end the script tag."""
    return (
        json.dumps(value, ensure_ascii=ascii_only, separators=(",", ":"))
        .replace("&", r"\u0026")
        .replace("<", r"\u003c")
        .replace(">", r"\u003e")
    )


def build(output: pathlib.Path) -> None:
    template = (WEB / "index.html").read_text(encoding="utf-8")
    thumb_names = sorted(set(re.findall(r"\['[A-Z0-9]+','([^']+\.(?:jpg|png))'\]", template)))
    thumbnails = {name: ROOT / "docs" / name for name in thumb_names}
    missing = [str(path) for path in [WEB / "index.html", WEB / "midi.js", *ASSETS.values(), *thumbnails.values()] if not path.is_file()]
    if missing:
        raise SystemExit("Missing web assets (run ./build.sh first): " + ", ".join(missing))

    midi = (WEB / "midi.js").read_text(encoding="utf-8")
    marker = '<script src="midi.js"></script>'
    if marker not in template or "</script>" in midi.lower():
        raise SystemExit("web/index.html or web/midi.js is not safe for deterministic inlining")

    payload = {
        "COM": {name: encoded(ASSETS[name]) for name in ("MEGA", "ATLAS", "UBER70", "UBERSHOW")},
        "TTF": encoded(ASSETS["font"]),
        "WASM": encoded(ASSETS["wasm"]),
        "MAIN_JS": encoded(ASSETS["main_js"]),
        "THUMBNAILS": {
            name: f"data:image/{'jpeg' if path.suffix.lower() == '.jpg' else 'png'};base64,{encoded(path)}"
            for name, path in thumbnails.items()
        },
        "ASM": {
            path.stem.upper(): path.read_text(encoding="utf-8")
            for path in sorted((ROOT / "src").glob("*.asm"))
        },
    }
    payload["ASM"].update({
        "UBER70": (ROOT / "archive" / "uber256-megademo" / "intro256.asm").read_text(encoding="utf-8"),
        "UBERSHOW": (ROOT / "archive" / "uber256-megademo" / "showcase.asm").read_text(encoding="utf-8"),
    })
    bootstrap = (
        "<script>\n"
        f"window.EMBEDDED_COM={json_for_script(payload['COM'])};\n"
        f"window.EMBEDDED_TTF={json_for_script(payload['TTF'])};\n"
        f"window.EMBEDDED_WASM={json_for_script(payload['WASM'])};\n"
        f"window.EMBEDDED_MAIN_JS={json_for_script(payload['MAIN_JS'])};\n"
        f"window.EMBEDDED_THUMBNAILS={json_for_script(payload['THUMBNAILS'])};\n"
        f"window.EMBEDDED_ASM={json_for_script(payload['ASM'], ascii_only=False)};\n"
        "</script>\n<script>\n" + midi + "\n</script>"
    )
    html = template.replace(marker, bootstrap, 1)
    html = html.replace('<script src="sources.js"></script>', '', 1)
    # The standalone build makes no network request for decorative web fonts.
    html = "\n".join(line for line in html.splitlines() if "fonts.googleapis.com" not in line)
    digest = hashlib.sha256(html.encode("utf-8")).hexdigest()
    banner = f"<!-- self-contained content sha256:{digest} (excludes this comment) -->"
    html = html.replace("<!doctype html>", f"<!doctype html>\n{banner}", 1)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(html, encoding="utf-8")
    verify(output)


def verify(output: pathlib.Path) -> None:
    html = output.read_text(encoding="utf-8")
    banner_match = BANNER_RE.search(html)
    if not banner_match:
        raise SystemExit("Invalid standalone HTML: missing content fingerprint")
    content = BANNER_RE.sub("", html, count=1)
    actual_fingerprint = hashlib.sha256(content.encode("utf-8")).hexdigest()
    if banner_match.group(1) != actual_fingerprint:
        raise SystemExit("Invalid standalone HTML: content fingerprint mismatch")

    assignment_re = re.compile(r"^window\.([A-Z_]+)=(.*);$", re.MULTILINE)
    embedded = {name: json.loads(value) for name, value in assignment_re.findall(html)}
    embedded_com = embedded.get("EMBEDDED_COM", {})
    for name in ("MEGA", "ATLAS", "UBER70", "UBERSHOW"):
        value = embedded_com.get(name)
        if not isinstance(value, str) or not value:
            raise SystemExit(f"Invalid standalone HTML: missing embedded {name}.COM")
        try:
            binary = base64.b64decode(value, validate=True)
        except (ValueError, binascii.Error) as error:
            raise SystemExit(f"Invalid standalone HTML: corrupt embedded {name}.COM") from error
        if not binary:
            raise SystemExit(f"Invalid standalone HTML: empty embedded {name}.COM")
        if ASSETS[name].is_file() and value != encoded(ASSETS[name]):
            raise SystemExit(f"Invalid standalone HTML: embedded {name}.COM mismatch")
    expected_asm = {
        path.stem.upper(): path.read_text(encoding="utf-8")
        for path in sorted((ROOT / "src").glob("*.asm"))
    }
    expected_asm.update({
        "UBER70": (ROOT / "archive" / "uber256-megademo" / "intro256.asm").read_text(encoding="utf-8"),
        "UBERSHOW": (ROOT / "archive" / "uber256-megademo" / "showcase.asm").read_text(encoding="utf-8"),
    })
    if embedded.get("EMBEDDED_ASM") != expected_asm:
        raise SystemExit("Invalid standalone HTML: assembly source map mismatch")

    template = (WEB / "index.html").read_text(encoding="utf-8")
    thumb_names = sorted(set(re.findall(r"\['[A-Z0-9]+','([^']+\.(?:jpg|png))'\]", template)))
    expected_thumbnails = {
        name: (
            f"data:image/{'jpeg' if pathlib.Path(name).suffix.lower() == '.jpg' else 'png'};base64,"
            f"{encoded(ROOT / 'docs' / name)}"
        )
        for name in thumb_names
    }
    if embedded.get("EMBEDDED_THUMBNAILS") != expected_thumbnails:
        raise SystemExit("Invalid standalone HTML: thumbnail map mismatch")

    ids = re.findall(r'\bid="([^"]+)"', html)
    duplicate_ids = sorted({item for item in ids if ids.count(item) > 1})
    if duplicate_ids:
        raise SystemExit("Invalid standalone HTML: duplicate element IDs: " + ", ".join(duplicate_ids))

    external_scripts = re.findall(r"<script\b[^>]*\bsrc\s*=", html, flags=re.IGNORECASE)
    external_styles = re.findall(
        r"<link\b(?=[^>]*\brel\s*=\s*['\"]stylesheet['\"])[^>]*\bhref\s*=",
        html,
        flags=re.IGNORECASE,
    )
    checks = {
        "main.wasm": f'window.EMBEDDED_WASM="{encoded(ASSETS["wasm"])}"',
        "main.js": f'window.EMBEDDED_MAIN_JS="{encoded(ASSETS["main_js"])}"',
        "main.ttf": f'window.EMBEDDED_TTF="{encoded(ASSETS["font"])}"',
        "MIDI engine": "const SCHEDULE_AHEAD = 0.03;",
        "thumbnail menu": "window.EMBEDDED_THUMBNAILS=",
        "assembly source map": "window.EMBEDDED_ASM=",
    }
    failed = [name for name, needle in checks.items() if needle not in html]
    if failed or external_scripts or external_styles or "fonts.googleapis.com" in html:
        raise SystemExit("Invalid standalone HTML: " + ", ".join(failed or ["external dependency remained"]))


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--verify":
        target = pathlib.Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else DEFAULT_OUTPUT
        verify(target)
        print(f"{target} verified ({target.stat().st_size:,} bytes, all runtime assets embedded)")
    else:
        target = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_OUTPUT
        build(target)
        print(f"{target} ({target.stat().st_size:,} bytes, all runtime assets embedded)")
