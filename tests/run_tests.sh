#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./build-web-standalone.sh >/dev/null
python3 tests/test_web_catalog.py
if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; fi
if ! .venv/bin/python -c 'import unicorn' >/dev/null 2>&1; then
    if ! .venv/bin/python -m pip --version >/dev/null 2>&1; then
        .venv/bin/python -m ensurepip --upgrade
    fi
    .venv/bin/python -m pip install -q unicorn
fi
if ! .venv/bin/python -c 'from unicorn import Uc, UC_ARCH_X86, UC_MODE_16; u=Uc(UC_ARCH_X86, UC_MODE_16); u.mem_map(0, 0x1000)' >/dev/null 2>&1; then
    echo 'ERROR: installed Unicorn cannot initialize its x86 engine on this CPU.' >&2
    echo 'Use a compatible native Unicorn build, then rerun tests/run_tests.sh.' >&2
    exit 3
fi
(cd archive/uber-micro-demos && ../../.venv/bin/python tests/test_micro.py)
(cd archive/uber10-dos-demo && ../../.venv/bin/python tests/test_demo.py)
(cd archive/uber128-dos-demo && ../../.venv/bin/python tests/test_demo.py)
(cd archive/uber40k-dos-demo && ../../.venv/bin/python tests/emu_test.py)
.venv/bin/python tests/test_lab.py
.venv/bin/python tests/test_temporal.py
.venv/bin/python tests/test_atlas_state.py
.venv/bin/python tests/test_atlas_palettes.py
.venv/bin/python tests/test_atlas_show.py
.venv/bin/python tests/test_launcher.py
if command -v node >/dev/null 2>&1; then
    node --check web/midi.js
    node tests/test_web_midi.js
fi
exec .venv/bin/python tests/test_atlas_catalog.py
