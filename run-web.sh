#!/bin/sh
# Play the complete collection in DOS Wasm X (DOSBox-X in WebAssembly) from web/.
#   ./run-web.sh          build, serve on http://localhost:8256/web/ and open it
#   ./run-web.sh 9000     another port
# web/index.html#atlas starts with ATLAS.COM selected.
set -eu
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PORT=${1:-8256}
"$DIR/build.sh" >/dev/null
URL="http://localhost:$PORT/web/"
echo "serving $DIR on $URL  (Ctrl+C stops)"
( sleep 1; command -v open >/dev/null 2>&1 && open "$URL" || { command -v xdg-open >/dev/null 2>&1 && xdg-open "$URL"; } ) >/dev/null 2>&1 &
cd "$DIR" && exec python3 -m http.server "$PORT" --bind 127.0.0.1
