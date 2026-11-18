#!/usr/bin/env bash
# Jalankan server dari folder server/ (cwd wajib di situ: scriptfiles/ relatif
# terhadap cwd, dan fopen()/DB_Open() open.mp tidak bisa keluar dari scriptfiles/).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/server"
exec ./omp-server
