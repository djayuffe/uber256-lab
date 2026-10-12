#!/bin/sh
# Assemble every demo in src/ with NASM and enforce the 256-byte limit (and 8.3 file names).
set -eu
cd "$(dirname "$0")"
command -v nasm >/dev/null 2>&1 || { echo 'ERROR: NASM is required.' >&2; exit 1; }
fail=0
for src in src/*.asm; do
    name=$(basename "$src" .asm); upper=$(echo "$name" | tr 'a-z' 'A-Z')
    [ "${#name}" -le 8 ] || { echo "ERROR: $upper.COM is not a valid 8.3 DOS file name" >&2; fail=1; }
    nasm -f bin -Wall -Werror -Isrc/ "$src" -o "$upper.COM"
    size=$(wc -c < "$upper.COM" | tr -d ' ')
    printf '%-14s %s bytes (limit 256)\n' "$upper.COM" "$size"
    [ "$size" -le 256 ] || { echo "ERROR: $upper.COM is over 256 bytes" >&2; fail=1; }
done
[ "$fail" -eq 0 ] || exit 2
if command -v sha256sum >/dev/null 2>&1; then sha256sum *.COM > SHA256SUMS; else shasum -a 256 *.COM > SHA256SUMS; fi
