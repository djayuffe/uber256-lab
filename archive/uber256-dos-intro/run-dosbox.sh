#!/bin/sh
# Run MOIRE.COM in DOSBox. The autoexec lines go into the conf file itself: combining -conf
# with separate -c flags silently throttles cycles=max.
set -eu
DOSBOX_BIN=dosbox
if ! command -v "$DOSBOX_BIN" >/dev/null 2>&1; then
    MAC_APP=/Applications/dosbox.app/Contents/MacOS/DOSBox
    if [ -x "$MAC_APP" ]; then DOSBOX_BIN=$MAC_APP
    else echo "ERROR: DOSBox is required." >&2; exit 1; fi
fi
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
[ -f "$DIR/MOIRE.COM" ] || "$DIR/build.sh" >/dev/null
TMPCONF=$(mktemp /tmp/moire-dosbox.XXXXXX.conf)
trap 'rm -f "$TMPCONF"' EXIT
grep -v '^\[autoexec\]' "$DIR/DOSBOX.CONF" | grep -v '^#' > "$TMPCONF"
{ echo "[autoexec]"; echo "mount c $DIR"; echo "c:"; echo "MOIRE.COM"; } >> "$TMPCONF"
"$DOSBOX_BIN" -conf "$TMPCONF"
