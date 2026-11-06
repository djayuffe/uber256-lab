#!/bin/sh
# Assemble MOIRE.COM with NASM and enforce two size gates:
#   class  = the size class (256 bytes) - a hard ceiling;
#   budget = the size it has been shrunk to (131 bytes) - it may not grow back.
set -eu
cd "$(dirname "$0")"
command -v nasm >/dev/null 2>&1 || { echo 'ERROR: NASM is required.' >&2; exit 1; }
nasm -f bin -Wall -Werror moire.asm -o MOIRE.COM
size=$(wc -c < MOIRE.COM | tr -d ' ')
printf '%s: %s bytes (class 256, budget 131)\n' MOIRE.COM "$size"
[ "$size" -le 256 ] || { echo 'ERROR: MOIRE.COM exceeds its 256-byte class' >&2; exit 2; }
[ "$size" -le 131 ] || { echo 'ERROR: MOIRE.COM grew past its 131-byte budget' >&2; exit 2; }
if command -v sha256sum >/dev/null 2>&1; then sha256sum MOIRE.COM > SHA256SUMS; else shasum -a 256 MOIRE.COM > SHA256SUMS; fi
cat SHA256SUMS
