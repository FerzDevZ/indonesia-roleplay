#!/usr/bin/env bash
# Cek kesehatan tunnel playit: state dari log agent + uji query UDP publik.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Portwarp = jalur utama. playit disimpan sebagai riwayat: relay-nya tidak
# meneruskan paket client luar ke agent, jadi hanya query dari mesin ini yang lewat.
PW_HOST="ypcdhj3k.free.tryportwarp.cc"
PW_PORT="15399"
HOST="molecule-stockton.tun.ply.gg"
PORT="23592"

echo "== state agent (playit) =="
systemctl is-active playit | sed 's/^/  service : /'

last_state=$(sudo grep "tunnel state updated" /var/log/playit/playit.log 2>/dev/null | tail -1)
if [ -n "$last_state" ]; then
    count=$(printf '%s\n' "$last_state" | grep -oE '(^| )tunnel_count=[0-9]+' | head -1 | cut -d= -f2)
    acct=$(printf '%s\n' "$last_state" | sed -E 's/.*account_status="([a-z_]+)".*/\1/')
    echo "  tunnel  : $count aktif"
    echo "  akun    : $acct"
else
    echo "  tunnel  : (belum ada data)"
fi

echo "== uji UDP dari luar =="
python3 - "$HOST" "$PORT" <<'PY'
import socket, sys
host, port = sys.argv[1], int(sys.argv[2])
try:
    ip = socket.gethostbyname(host)
except Exception as exc:
    print(f"  DNS gagal: {exc}")
    sys.exit(0)
ipb = bytes(int(x) for x in ip.split("."))
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock.settimeout(6)
try:
    sock.sendto(b"SAMP" + ipb + (7777).to_bytes(2, "little") + b"i", (host, port))
    data, _ = sock.recvfrom(4096)
except Exception as exc:
    print(f"  TIDAK MENJAWAB ({exc}) -> tunnel mati / belum diaktifkan")
    sys.exit(0)
players = int.from_bytes(data[12:14], "little")
maxplayers = int.from_bytes(data[14:16], "little")
off = 16
names = []
for _ in range(3):
    n = int.from_bytes(data[off:off + 4], "little")
    off += 4
    names.append(data[off:off + n].decode("utf-8", "replace"))
    off += n
print(f"  MENJAWAB: {names[0]} | {players}/{maxplayers} pemain")
PY

echo "== uji UDP via Portwarp =="
if command -v python3 >/dev/null 2>&1; then
    python3 - "$PW_HOST" "$PW_PORT" <<'PYEOF'
import socket, sys
host, port = sys.argv[1], int(sys.argv[2])
try:
    ip = socket.gethostbyname(host)
except Exception:
    print("  DNS gagal untuk", host); raise SystemExit(1)
ipb = bytes(int(part) for part in ip.split("."))
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); sock.settimeout(5)
try:
    sock.sendto(b"SAMP" + ipb + (7777).to_bytes(2, "little") + b"i", (host, port))
    reply, _ = sock.recvfrom(2048)
    # Format balasan 'i': "SAMP" + ip(4) + port(2) + opcode(1) + version(2) + namalen(2) + nama
    name_at = reply.find(b"\x00Roleplay") + 1
    label = reply[name_at:].split(b"\x00")[0].decode("latin-1") if name_at > 0 else "(nama tidak terbaca)"
    print(f"  {host}:{port} -> MENJAWAB: {label}")
except Exception:
    print(f"  {host}:{port} -> TIDAK MENJAWAB (timeout)")
PYEOF
fi
