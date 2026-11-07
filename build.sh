#!/bin/sh
# Assemble every demo in src/ with NASM and enforce the 256-byte limit (and 8.3 file names).
set -eu
cd "$(dirname "$0")"
command -v nasm >/dev/null 2>&1 || { echo 'ERROR: NASM is required.' >&2; exit 1; }
# NASM 3.x reports intentional absolute 16-bit COM label addresses as
# reloc-abs-word. The flat binary resolves them correctly; keep every other
# warning fatal and demote only this documented compatibility warning when the
# installed assembler knows the class (older NASM rejects unknown classes).
set -- -Wall -Werror
case "$(nasm -v)" in
    "NASM version 3."*) set -- "$@" -Wno-error=reloc-abs-word ;;
esac
fail=0
for src in src/*.asm; do
    name=$(basename "$src" .asm); upper=$(echo "$name" | tr 'a-z' 'A-Z')
    [ "${#name}" -le 8 ] || { echo "ERROR: $upper.COM is not a valid 8.3 DOS file name" >&2; fail=1; }
    nasm -f bin "$@" -Isrc/ "$src" -o "$upper.COM"
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
    nasm -f bin "$@" -DMEGA -Isrc/ "$src" -o "build/$upper.MEG"
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
nasm -f bin "$@" -Isrc/ -Ibuild/ src/mega/mega.asm -o MEGA.COM
printf '%-14s %s bytes (the megademo: its parts, with titles and fades)\n' MEGA.COM "$(wc -c < MEGA.COM | tr -d ' ')"
nasm -f bin "$@" -DATLAS_SHOW -Isrc/ -Ibuild/ src/mega/mega.asm -o ATLAS.COM
printf '%-14s %s bytes (the continuous atlas show)\n' ATLAS.COM "$(wc -c < ATLAS.COM | tr -d ' ')"
# Preserve and build the complete earlier UBER256/UBERSHOW line that was merged
# from uber256-megademo. UBER70 avoids the historical UBER256.COM name collision
# with the independently developed rotozoomer.
python3 archive/uber256-megademo/audit.py >/dev/null
python3 archive/uber256-megademo/audit_final.py >/dev/null
nasm -f bin "$@" archive/uber256-megademo/intro256.asm -o UBER70.COM
nasm -f bin "$@" archive/uber256-megademo/showcase.asm -o UBERSHOW.COM
[ "$(wc -c < UBER70.COM | tr -d ' ')" -le 256 ] || { echo "ERROR: UBER70.COM is over 256 bytes" >&2; exit 2; }
printf '%-14s %s bytes (preserved original tiny intro)\n' UBER70.COM "$(wc -c < UBER70.COM | tr -d ' ')"
printf '%-14s %s bytes (preserved 18-scene engine)\n' UBERSHOW.COM "$(wc -c < UBERSHOW.COM | tr -d ' ')"
# Browser-only variants publish exact card/part transitions through a signed
# record in emulated memory.
# The release COM files above do not contain this integration channel.
nasm -f bin "$@" -DWEB_SYNC -Isrc/ -Ibuild/ src/mega/mega.asm -o web/MEGA.COM
nasm -f bin "$@" -DWEB_SYNC -DATLAS_SHOW -Isrc/ -Ibuild/ src/mega/mega.asm -o web/ATLAS.COM
cp UBER70.COM web/UBER70.COM
cp UBERSHOW.COM web/UBERSHOW.COM
for src in src/*.asm; do
    name=$(basename "$src" .asm); upper=$(echo "$name" | tr 'a-z' 'A-Z')
    cp "$upper.COM" "web/$upper.COM"
done
python3 tools/build_web_sources.py web/sources.js >/dev/null
python3 tools/build_web_catalog.py web/catalog.js >/dev/null
if command -v sha256sum >/dev/null 2>&1; then sha256sum *.COM > SHA256SUMS; else shasum -a 256 *.COM > SHA256SUMS; fi
