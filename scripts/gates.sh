#!/usr/bin/env bash
# Gate lokal: jalankan sebelum commit. Exit != 0 berarti ada yang harus diperbaiki.
set -uo pipefail

fail=0
check() { # check <nama> <perintah...>
    local name="$1"; shift
    if out=$("$@" 2>&1); then
        printf '  PASS  %s\n' "$name"
    else
        printf '  FAIL  %s\n' "$name"
        printf '%s\n' "$out" | sed 's/^/        /'
        fail=1
    fi
}

echo "gate: struktur"

check "pawn.json valid"      node -e "JSON.parse(require('fs').readFileSync('pawn.json','utf8'))"
check "config.json valid"    node -e "JSON.parse(require('fs').readFileSync('config.json.example','utf8'))"

if [ -d src ]; then
    echo "gate: kode"
    check "tanpa loop MAX_PLAYERS" bash -c '! grep -rn "i < MAX_PLAYERS" src/'
    # Domain boleh memakai API core/db (DB_Exec/DB_Int/...), tapi tidak boleh
    # menyentuh native database mentah atau handle DB langsung.
    check "tanpa native DB mentah di domain" bash -c '! grep -rnE "mysql_|db_query|db_open|DB_ExecuteQuery|DB_Open" src/domain'
    check "tanpa fopen di domain" bash -c '! grep -rn "fopen(" src/domain'
    check "dialog id dari enum" bash -c '! grep -rnE "ShowPlayerDialog\([^,]+, *[0-9]+," src/'
    check "tanpa stub" bash -c '! grep -rn "TODO\|FIXME\|implement later" src/'
    # Sambungan modul: perintah ganda, dialog tak terdaftar, aksi lokasi tanpa
    # dispatch/ikon. Bug jenis ini lolos compiler tapi mati saat dimainkan.
    check "wiring modul" ./scripts/wiring-check.sh
    check "file <= 400 baris" bash -c '! find src -name "*.pwn" -exec wc -l {} + | awk "\$2 != \"total\" && \$1 > 400 {print; found=1} END {exit !found}"'
    # Semua warna UI wajib lewat token ui/theme (satu sumber kebenaran).
    # trxtdraw bebas karena hanya memakai warna yang dikirim pemanggil;
    # 0x7FFFFFFF adalah sentinel waktu, bukan warna.
    check "tanpa warna literal di ui" bash -c '! grep -rn "0x[0-9A-Fa-f]\{8\}" src/ui --include="*.pwn" | grep -v theme.pwn | grep -v trxtdraw.pwn | grep -v 0x7FFFFFFF'
    # Setiap modul wajib punya header dokumentasi (module/depends/api).
    check "header modul lengkap" bash -c 'missing=0; for f in $(find src -name "*.pwn"); do head -2 "$f" | grep -q "module" || { echo "$f"; missing=1; }; done; exit $missing'
else
    echo "gate: src/ belum ada, gate kode dilewati"
fi

if [ -x server/qawno/pawncc ]; then
    echo "gate: compile"
    check "build gamemode" ./scripts/build.sh
else
    echo "gate: pawncc tidak ada, compile dilewati (INI BUKAN PASS)"
    fail=1
fi

echo
if [ "$fail" -ne 0 ]; then
    echo "HASIL: GAGAL"
    exit 1
fi

echo "HASIL: LULUS"
