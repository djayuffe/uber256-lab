#!/bin/sh
# Assemble UBER128.COM with NASM and enforce two size gates:
#   class  = the size class (128 bytes) - a hard ceiling;
#   budget = the size it has been shrunk to (77 bytes) - it may not grow back.
set -eu
cd "$(dirname "$0")"
command -v nasm >/dev/null 2>&1 || { echo 'ERROR: NASM is required.' >&2; exit 1; }
nasm -f bin -Wall -Werror uber128.asm -o UBER128.COM
size=$(wc -c < UBER128.COM | tr -d ' ')
printf '%s: %s bytes (class 128, budget 77)\n' UBER128.COM "$size"
[ "$size" -le 128 ] || { echo 'ERROR: UBER128.COM exceeds its 128-byte class' >&2; exit 2; }
[ "$size" -le 77 ] || { echo 'ERROR: UBER128.COM grew past its 77-byte budget' >&2; exit 2; }
if command -v sha256sum >/dev/null 2>&1; then sha256sum UBER128.COM > SHA256SUMS; else shasum -a 256 UBER128.COM > SHA256SUMS; fi
cat SHA256SUMS
