#!/bin/sh
# Run one demo in DOSBox:  ./run-dosbox.sh galaxy
set -eu
DOSBOX_BIN=dosbox
if ! command -v "$DOSBOX_BIN" >/dev/null 2>&1; then
    MAC_APP=/Applications/dosbox.app/Contents/MacOS/DOSBox
    if [ -x "$MAC_APP" ]; then DOSBOX_BIN=$MAC_APP; else echo "ERROR: DOSBox is required." >&2; exit 1; fi
fi
[ $# -eq 1 ] || { echo "usage: $0 NAME   (galaxy cliff selftex)" >&2; exit 1; }
TARGET=$(echo "$1" | tr 'a-z' 'A-Z').COM
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ -f "$DIR/$TARGET" ] || "$DIR/build.sh" >/dev/null
TMPCONF=$(mktemp /tmp/uber256-lab.XXXXXX.conf); trap 'rm -f "$TMPCONF"' EXIT
grep -v '^\[autoexec\]' "$DIR/DOSBOX.CONF" > "$TMPCONF"
{ echo "[autoexec]"; echo "mount c $DIR"; echo "c:"; echo "$TARGET"; } >> "$TMPCONF"
"$DOSBOX_BIN" -conf "$TMPCONF"
