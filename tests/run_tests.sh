#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
./build.sh >/dev/null
if [ ! -x .venv/bin/python ]; then python3 -m venv .venv; .venv/bin/pip install -q unicorn; fi
exec .venv/bin/python tests/test_lab.py
