#!/usr/bin/env bash
# Backup harian rp.db, simpan 14 terakhir.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="$ROOT/server/scriptfiles/rp.db"
DEST="$ROOT/backups"
mkdir -p "$DEST"
[ -f "$DB" ] || { echo "database belum ada"; exit 0; }
stamp=$(date +%Y%m%d-%H%M)
python3 - "$DB" "$DEST/rp-$stamp.db" <<'PY'
import sqlite3, sys
src, dst = sys.argv[1], sys.argv[2]
with sqlite3.connect(src) as s, sqlite3.connect(dst) as d:
    s.backup(d)          # backup konsisten walau server sedang menulis
PY
gzip -f "$DEST/rp-$stamp.db"
ls -1t "$DEST"/rp-*.db.gz | tail -n +15 | xargs -r rm -f
echo "backup: $DEST/rp-$stamp.db.gz"
