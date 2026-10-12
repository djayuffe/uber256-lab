#!/bin/sh
# Run demos in DOSBox, one after another: Esc ends each one and starts the next.
#   ./run-dosbox.sh galaxy             one demo
#   ./run-dosbox.sh selftex goldtex    several, in the order given
#   ./run-dosbox.sh '*tex'             a pattern (quoted), matched in the order below: SELFTEX, GOLDTEX, FLOWTEX
#   ./run-dosbox.sh all                all thirteen
set -eu
ORDER="galaxy cliff chladni fire escher julia latch order roots selftex goldtex flowtex warp"
DOSBOX_BIN=dosbox
if ! command -v "$DOSBOX_BIN" >/dev/null 2>&1; then
    MAC_APP=/Applications/dosbox.app/Contents/MacOS/DOSBox
    if [ -x "$MAC_APP" ]; then DOSBOX_BIN=$MAC_APP; else echo "ERROR: DOSBox is required." >&2; exit 1; fi
fi
[ $# -ge 1 ] || { echo "usage: $0 NAME|PATTERN|all ...   ($ORDER)" >&2; exit 1; }
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LIST=""
for arg in "$@"; do
    pat=$(echo "$arg" | tr 'A-Z' 'a-z'); [ "$pat" = all ] && pat='*'
    hit=""
    for n in $ORDER; do
        case $n in $pat) LIST="$LIST $n"; hit=1 ;; esac
    done
    [ -n "$hit" ] || { echo "ERROR: no demo matches '$arg'   ($ORDER)" >&2; exit 1; }
done
for n in $LIST; do
    [ -f "$DIR/$(echo "$n" | tr 'a-z' 'A-Z').COM" ] || { "$DIR/build.sh" >/dev/null; break; }
done
echo "running:$LIST"
# One DOSBox per demo, closed when the demo ends: a held Esc cannot leak into the next one.
TMPCONF=$(mktemp /tmp/uber256-lab.XXXXXX.conf); trap 'rm -f "$TMPCONF"' EXIT
set -- $LIST
while [ $# -gt 0 ]; do
    n=$1; shift
    grep -v '^\[autoexec\]' "$DIR/DOSBOX.CONF" > "$TMPCONF"
    {
        echo "[autoexec]"; echo "mount c \"$DIR\""; echo "c:"
        echo "$(echo "$n" | tr 'a-z' 'A-Z').COM"
        [ $# -eq 0 ] || echo "exit"       # the last one returns to the DOS prompt, as a single demo does
    } >> "$TMPCONF"
    "$DOSBOX_BIN" -conf "$TMPCONF"
done
