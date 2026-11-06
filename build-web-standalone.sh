#!/bin/sh
# Build one HTML file containing the player, both shows, font, DOSBox JS and Wasm.
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
"$DIR/build.sh" >/dev/null
exec python3 "$DIR/tools/build_web_bundle.py" "${1:-$DIR/dist/uber256-lab.html}"
