#!/usr/bin/env bash
# Jadikan sebuah akun admin (default level 5 = owner).
# Pakai SETELAH akunnya register di server, karena akun dibuat saat login pertama.
#
#   ./scripts/promote-admin.sh budi            -> level 5
#   ./scripts/promote-admin.sh budi 3          -> level 3 (admin)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="$ROOT/server/scriptfiles/rp.db"
USERNAME="${1:-}"
LEVEL="${2:-5}"

if [ -z "$USERNAME" ]; then
    echo "pakai: $0 <username> [level 1-5]" >&2
    exit 1
fi
if [ ! -f "$DB" ]; then
    echo "database belum ada: $DB" >&2
    echo "jalankan server dulu sampai [boot] siap" >&2
    exit 1
fi
case "$LEVEL" in
    1|2|3|4|5) ;;
    *) echo "level harus 1-5" >&2; exit 1 ;;
esac

python3 - "$DB" "$USERNAME" "$LEVEL" <<'PY'
import sqlite3, sys
db, username, level = sys.argv[1], sys.argv[2], int(sys.argv[3])
c = sqlite3.connect(db)
# Nama akun disimpan apa adanya (case-insensitive lookup), jadi cari dulu.
row = c.execute("select account_id, username from accounts where lower(username) = lower(?)",
                (username,)).fetchone()
if row is None:
    print(f"akun '{username}' belum ada. Register dulu di dalam game, lalu ulangi.")
    print("akun yang ada:", ", ".join(r[0] for r in c.execute("select username from accounts")) or "(kosong)")
    sys.exit(1)
c.execute("update accounts set admin_level = ? where account_id = ?", (level, row[0]))
c.commit()
print(f"OK: {row[1]} (account_id {row[0]}) sekarang admin_level={level}")
print("logout/login ulang atau reconnect supaya level terbaca di server.")
PY
