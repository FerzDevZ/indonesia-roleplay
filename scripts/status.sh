#!/usr/bin/env bash
# Ringkasan status server dalam satu layar.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="molecule-stockton.tun.ply.gg"
PORT="23592"

echo "== proses =="
if pgrep -x omp-server >/dev/null; then
    printf '  server   : hidup (pid %s)\n' "$(pgrep -x omp-server | head -1)"
else
    echo "  server   : MATI (jalankan ./scripts/supervise.sh)"
fi
if pgrep -f "scripts/supervise.sh" >/dev/null; then
    echo "  supervisor: jalan"
else
    echo "  supervisor: tidak jalan (server tidak akan auto-restart)"
fi
printf '  playit   : %s (riwayat, tidak dipakai)\n' "$(systemctl is-active playit 2>/dev/null || echo unknown)"
if command -v pwrp >/dev/null 2>&1; then
    pw=$(pwrp ps --once 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -oE "● (live|down)" | head -1)
    printf '  portwarp : %s\n' "${pw:-tidak ada sesi}"
fi

# State tunnel playit: tunnel_count=0 berarti playit mematikan tunnel (biasanya
# karena email akun belum diverifikasi), walau daemon-nya "active".
# "tunnels loaded" (saat agent connect) juga membawa tunnel_count; pakai baris terbaru
# dari kedua jenis supaya status tidak terbaca basi.
last_tunnel=$(sudo grep -E "tunnel state updated|tunnels loaded" /var/log/playit/playit.log 2>/dev/null | tail -1)
if [ -n "$last_tunnel" ]; then
    # Regex harus tidak-greedy secara efektif: baris juga memuat pending_tunnel_count
    # dan disabled_tunnel_count, jadi ambil token pertama yang persis "tunnel_count=".
    tcount=$(printf '%s\n' "$last_tunnel" | grep -oE '(^| )tunnel_count=[0-9]+' | head -1 | cut -d= -f2)
    tstate=$(printf '%s\n' "$last_tunnel" | sed -E 's/.*account_status="([a-z_]+)".*/\1/')
    if [ "$tcount" = "0" ]; then
        printf '  tunnel   : MATI (akun=%s) -> aktifkan tunnel di dashboard playit\n' "$tstate"
    else
        printf '  tunnel   : aktif (akun=%s)\n' "$tstate"
    fi
else
    echo "  tunnel   : (state belum ada)"
fi

echo "== port lokal =="
if ss -lun 2>/dev/null | grep -q ':7777'; then
    echo "  UDP 7777 : listen"
else
    echo "  UDP 7777 : tidak listen"
fi

echo "== data =="
DB="$ROOT/server/scriptfiles/rp.db"
if [ -f "$DB" ]; then
    printf '  rp.db    : %s\n' "$(du -h "$DB" | cut -f1)"
    python3 - "$DB" <<'PY' 2>/dev/null
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
for label, sql in (
    ("akun", "select count(*) from accounts"),
    ("karakter", "select count(*) from characters where deleted_at is null"),
    ("entri uang", "select count(*) from money_log"),
):
    try:
        print(f"  {label:9}: {c.execute(sql).fetchone()[0]}")
    except Exception:
        print(f"  {label:9}: (tabel belum ada)")
PY
else
    echo "  rp.db    : belum ada"
fi
printf '  backup   : %s\n' "$(ls -1 "$ROOT/backups" 2>/dev/null | wc -l) file"

echo "== query publik =="
python3 - "$HOST" "$PORT" <<'PY' 2>/dev/null || echo "  TIDAK MENJAWAB"
import socket, sys
host, port = sys.argv[1], int(sys.argv[2])
ip = socket.gethostbyname(host)
ipb = bytes(int(x) for x in ip.split("."))
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.settimeout(6)
s.sendto(b"SAMP" + ipb + (7777).to_bytes(2, "little") + b"i", (host, port))
d, _ = s.recvfrom(4096)
players = int.from_bytes(d[12:14], "little")
maxplayers = int.from_bytes(d[14:16], "little")
off = 16
names = []
for _ in range(3):
    n = int.from_bytes(d[off:off + 4], "little")
    off += 4
    names.append(d[off:off + n].decode("utf-8", "replace"))
    off += n
print(f"  {host}:{port} -> {names[0]} | {players}/{maxplayers} pemain")
print(f"  mode     : {names[1]}")
PY

echo "== log terakhir =="
tail -3 "$ROOT/server/scriptfiles/console.log" 2>/dev/null | sed 's/^/  /'
