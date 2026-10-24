#!/bin/sh
# Run demos in DOSBox, one after another: Esc ends each one and starts the next.
#   ./run-dosbox.sh galaxy             one demo
#   ./run-dosbox.sh selftex goldtex    several, in the order given
#   ./run-dosbox.sh '*tex'             a pattern (quoted), matched in the order below: SELFTEX, GOLDTEX, FLOWTEX
#   ./run-dosbox.sh all                all forty standalone demos
#   ./run-dosbox.sh atlas              the twenty-seven atlas adaptations
#   ./run-dosbox.sh atlas-show         continuous atlas show: timed parts, Space skips
#   ./run-dosbox.sh --list             list demos without starting DOSBox
#   ./run-dosbox.sh mega               the megademo (MEGA.COM): thirteen with title cards, fades and credits
set -eu
ORDER="galaxy cliff chladni fire escher julia latch order roots selftex goldtex flowtex causal phase horizon commute lift mirror resfield shuffle hyster residual signed runs bytevm reverso bifurc terrace loom ring prefix rank ballot timelens emboss surgery bracket orbit critical warp"
ATLAS="causal phase horizon commute lift mirror resfield shuffle hyster residual signed runs bytevm reverso bifurc terrace loom ring prefix rank ballot timelens emboss surgery bracket orbit critical"
usage() {
    echo "usage: $0 NAME|PATTERN|all|atlas|atlas-show|mega ..."
    echo "       $0 --list | --help"
}
[ $# -ge 1 ] || { usage >&2; exit 1; }
case $1 in
    --help|-h) usage; exit 0 ;;
    --list) printf '%s\n' $ORDER; echo 'mega (13-part show)'; echo 'atlas-show (27-part show)'; exit 0 ;;
esac
DOSBOX_BIN=${DOSBOX_BIN:-dosbox}
if ! command -v "$DOSBOX_BIN" >/dev/null 2>&1; then
    MAC_APP=/Applications/dosbox.app/Contents/MacOS/DOSBox
    if [ -x "$MAC_APP" ]; then DOSBOX_BIN=$MAC_APP; else echo "ERROR: DOSBox is required." >&2; exit 1; fi
fi
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
LIST=""
for arg in "$@"; do
    pat=$(echo "$arg" | tr 'A-Z' 'a-z'); [ "$pat" = all ] && pat='*'
    [ "$pat" = atlas-show ] && { LIST="$LIST atlas"; continue; }
    [ "$pat" = atlas ] && { LIST="$LIST $ATLAS"; continue; }
    [ "$pat" = mega ] && { LIST="$LIST mega"; continue; }   # the megademo: all of them in one program
    hit=""
    for n in $ORDER; do
        case $n in $pat) LIST="$LIST $n"; hit=1 ;; esac
    done
    [ -n "$hit" ] || { echo "ERROR: no demo matches '$arg'   ($ORDER)" >&2; exit 1; }
done
"$DIR/build.sh" >/dev/null    # rebuild includes and playlists, even if old .COMs exist
echo "running:$LIST"
# One DOSBox per demo, closed when the demo ends: a held Esc cannot leak into the next one.
TMPCONF=$(mktemp /tmp/uber256-lab.XXXXXX.conf); trap 'rm -f "$TMPCONF"' EXIT
set -- $LIST
while [ $# -gt 0 ]; do
    n=$1; shift
    awk 'tolower($0) ~ /^[[:space:]]*\[autoexec\]/ { exit } { print }' "$DIR/DOSBOX.CONF" > "$TMPCONF"
    {
        echo "[autoexec]"; echo "mount c \"$DIR\""; echo "c:"
        echo "$(echo "$n" | tr 'a-z' 'A-Z').COM"
        [ $# -eq 0 ] || echo "exit"       # the last one returns to the DOS prompt, as a single demo does
    } >> "$TMPCONF"
    "$DOSBOX_BIN" -conf "$TMPCONF"
done
