#!/bin/sh
# Assemble UBER256.COM with NASM and enforce two size gates:
#   class  = the size class (256 bytes) - a hard ceiling;
#   budget = the size it has been shrunk to (171 bytes) - it may not grow back.
set -eu
cd "$(dirname "$0")"
command -v nasm >/dev/null 2>&1 || { echo 'ERROR: NASM is required.' >&2; exit 1; }
nasm -f bin -Wall -Werror uber256.asm -o UBER256.COM
size=$(wc -c < UBER256.COM | tr -d ' ')
printf '%s: %s bytes (class 256, budget 171)\n' UBER256.COM "$size"
[ "$size" -le 256 ] || { echo 'ERROR: UBER256.COM exceeds its 256-byte class' >&2; exit 2; }
[ "$size" -le 171 ] || { echo 'ERROR: UBER256.COM grew past its 171-byte budget' >&2; exit 2; }
if command -v sha256sum >/dev/null 2>&1; then sha256sum UBER256.COM > SHA256SUMS; else shasum -a 256 UBER256.COM > SHA256SUMS; fi
cat SHA256SUMS
