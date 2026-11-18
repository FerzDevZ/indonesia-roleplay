#!/usr/bin/env bash
# Build gamemode dengan pawncc open.mp yang sudah ada di server/qawno.
# Tidak butuh sampctl, tidak butuh internet.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAWNCC="$ROOT/server/qawno/pawncc"
INCLUDE="$ROOT/server/qawno/include"
OUTPUT="$ROOT/server/gamemodes/rp-indonesia.amx"

if [ ! -x "$PAWNCC" ]; then
    echo "pawncc tidak ditemukan di $PAWNCC" >&2
    echo "jalankan: bash scripts/install-toolchain.sh" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT")"

export LD_LIBRARY_PATH="$ROOT/server/qawno:${LD_LIBRARY_PATH:-}"

cd "$ROOT"
"$PAWNCC" gamemode.pwn \
    "-i$INCLUDE" \
    "-o$OUTPUT" \
    -d3 '-;+' '-(+' -w+ 2>&1 | tee /tmp/pawn-build.log

# pawncc keluar 0 walau ada error; hitung error dari output.
if grep -qE '^[0-9]+ Error' /tmp/pawn-build.log; then
    echo "BUILD GAGAL" >&2
    exit 1
fi
if grep -qE '^[0-9]+ Warning' /tmp/pawn-build.log; then
    echo "BUILD GAGAL: ada warning (aturan: warning = error)" >&2
    exit 1
fi

echo "BUILD OK -> $OUTPUT"
