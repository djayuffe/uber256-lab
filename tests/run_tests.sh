#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./build.sh >/dev/null
if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi
if ! .venv/bin/python -c 'import unicorn' >/dev/null 2>&1; then
    if ! .venv/bin/python -m pip --version >/dev/null 2>&1; then
        .venv/bin/python -m ensurepip --upgrade
    fi
    .venv/bin/python -m pip install -q unicorn
fi
.venv/bin/python tests/test_lab.py
.venv/bin/python tests/test_temporal.py
.venv/bin/python tests/test_atlas_state.py
.venv/bin/python tests/test_atlas_palettes.py
.venv/bin/python tests/test_atlas_show.py
.venv/bin/python tests/test_launcher.py
exec .venv/bin/python tests/test_atlas_catalog.py
