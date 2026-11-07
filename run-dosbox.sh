#!/bin/sh
# Run demos in DOSBox, one after another: Esc ends each one and starts the next.
#   ./run-dosbox.sh galaxy             one demo
#   ./run-dosbox.sh selftex goldtex    several, in the order given
#   ./run-dosbox.sh '*tex'             a pattern (quoted), matched in the order below: SELFTEX, GOLDTEX, FLOWTEX
#   ./run-dosbox.sh all                all seventy-four standalone demos
#   ./run-dosbox.sh micro              all thirty 4–8 byte demos
#   ./run-dosbox.sh atlas              the twenty-seven atlas adaptations
#   ./run-dosbox.sh atlas-show         continuous atlas show: timed parts, Space skips
#   ./run-dosbox.sh --list             list demos without starting DOSBox
#   ./run-dosbox.sh mega               the current megademo (MEGA.COM): fifteen parts
#   ./run-dosbox.sh ubershow           the preserved earlier 18-scene engine
#   ./run-dosbox.sh uber40k            the 20-scene 3D/OPL2 show
set -eu
ORDER="galaxy cliff chladni fire escher julia latch order roots selftex goldtex flowtex moire rotozoom causal phase horizon commute lift mirror resfield shuffle hyster residual signed runs bytevm reverso bifurc terrace loom ring prefix rank ballot timelens emboss surgery bracket orbit critical warp"
MICRO="overlap overmax oversub overhear stackmap stkrain bullets snow breath buzz static ticker geiger typer mirror8 spectrum stripe big tall keyscan pspback state flux weave codepal psppal noisepal mode3 evo1 evo2"
FAMILY="overlap overmax oversub overhear stackmap stkrain bullets snow breath buzz static ticker geiger typer mirror8 spectrum stripe big tall keyscan pspback state flux weave codepal psppal noisepal mode3 evo1 evo2 uber10 uber128"
ATLAS="causal phase horizon commute lift mirror resfield shuffle hyster residual signed runs bytevm reverso bifurc terrace loom ring prefix rank ballot timelens emboss surgery bracket orbit critical"
usage() {
    echo "usage: $0 NAME|PATTERN|all|micro|atlas|atlas-show|mega|ubershow|uber40k ..."
    echo "       $0 --list | --help"
}
[ $# -ge 1 ] || { usage >&2; exit 1; }
case $1 in
    --help|-h) usage; exit 0 ;;
    --list) printf '%s\n' $ORDER $FAMILY; echo 'mega (15-part show)'; echo 'atlas-show (27-part show)'; echo 'uber70 (preserved 70-byte intro)'; echo 'ubershow (preserved 18-scene engine)'; echo 'uber40k (20-scene 3D/OPL2 show)'; exit 0 ;;
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
    [ "$pat" = micro ] && { LIST="$LIST $MICRO"; continue; }
    [ "$pat" = atlas-show ] && { LIST="$LIST atlas"; continue; }
    [ "$pat" = atlas ] && { LIST="$LIST $ATLAS"; continue; }
    [ "$pat" = mega ] && { LIST="$LIST mega"; continue; }   # the megademo: all of them in one program
    [ "$pat" = uber70 ] && { LIST="$LIST uber70"; continue; }
    [ "$pat" = ubershow ] && { LIST="$LIST ubershow"; continue; }
    [ "$pat" = uber40k ] && { LIST="$LIST uber40k"; continue; }
    hit=""
    for n in $ORDER; do
        case $n in $pat) LIST="$LIST $n"; hit=1 ;; esac
    done
    for n in $FAMILY; do
        case $n in $pat) LIST="$LIST $n"; hit=1 ;; esac
    done
    [ -n "$hit" ] || { echo "ERROR: no demo matches '$arg'   ($ORDER $FAMILY)" >&2; exit 1; }
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
