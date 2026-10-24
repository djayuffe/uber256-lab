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
# The megademo: every part again with -DMEGA (its exit also ends on a time limit), then MEGA.COM around them.
mkdir -p build
: > build/sizes.inc
for src in src/*.asm; do
    name=$(basename "$src" .asm); upper=$(echo "$name" | tr 'a-z' 'A-Z')
    nasm -f bin -Wall -Werror -DMEGA -Isrc/ "$src" -o "build/$upper.MEG"
    size=$(wc -c < "$upper.COM" | tr -d ' ')
    printf '%%define SZ_%s "%s"\n' "$upper" "$size" >> build/sizes.inc
done
for show in mega atlas; do
    total=0; count=0
    for name in $(sed -n 's/^ *ENTRY \([a-z]*\),.*/\1/p' "src/mega/${show}_program.inc"); do
        total=$((total + $(wc -c < "$(echo "$name" | tr 'a-z' 'A-Z').COM" | tr -d ' '))); count=$((count + 1))
    done
    prefix=""
    [ "$show" = mega ] || prefix="ATLAS_"
    printf '%%define SZ_%sTOTAL "%s"\n%%define SZ_%sCOUNT "%s"\n' "$prefix" "$total" "$prefix" "$count" >> build/sizes.inc
done
nasm -f bin -Wall -Werror -Isrc/ -Ibuild/ src/mega/mega.asm -o MEGA.COM
printf '%-14s %s bytes (the megademo: its parts, with titles and fades)\n' MEGA.COM "$(wc -c < MEGA.COM | tr -d ' ')"
nasm -f bin -Wall -Werror -DATLAS_SHOW -Isrc/ -Ibuild/ src/mega/mega.asm -o ATLAS.COM
printf '%-14s %s bytes (the continuous atlas show)\n' ATLAS.COM "$(wc -c < ATLAS.COM | tr -d ' ')"
if command -v sha256sum >/dev/null 2>&1; then sha256sum *.COM > SHA256SUMS; else shasum -a 256 *.COM > SHA256SUMS; fi
