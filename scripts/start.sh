#!/usr/bin/env bash
# Start server di background lewat supervisor (auto-restart).
# Aman dijalankan berulang: kalau supervisor sudah hidup, skrip ini hanya
# melaporkan status. Penjaga sesungguhnya ada di supervise.sh (single instance).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/server/scriptfiles"
PID_FILE="$STATE/.supervisor.pid"

Supervisor_Pid() {
    local pid=""
    [ -f "$PID_FILE" ] && pid=$(tr -dc '0-9' < "$PID_FILE")
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null \
            && tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q 'supervise\.sh'; then
        printf '%s' "$pid"
    fi
}

sup=$(Supervisor_Pid)
if [ -n "$sup" ]; then
    # Supervisor hidup tetapi server mungkin sedang dijeda 5 detik sebelum
    # restart: beri waktu, jangan langsung menyatakan gagal.
    for _ in $(seq 1 8); do
        pgrep -x omp-server >/dev/null 2>&1 && break
        sleep 1
    done
    if pgrep -x omp-server >/dev/null 2>&1; then
        echo "server sudah jalan (pid $(pgrep -x omp-server | head -1)), supervisor $sup"
    else
        echo "supervisor sudah jalan (pid $sup), server belum hidup; cek $STATE/console.log"
    fi
    exit 0
fi

rm -f "$STATE/.supervisor-stop"
setsid nohup "$ROOT/scripts/supervise.sh" >/dev/null 2>&1 </dev/null &
sleep 8
if pgrep -x omp-server >/dev/null 2>&1; then
    echo "server jalan (pid $(pgrep -x omp-server | head -1)), supervisor $(cat "$PID_FILE" 2>/dev/null)"
else
    echo "server GAGAL start, cek $STATE/console.log" >&2
    tail -5 "$STATE/console.log" >&2
    exit 1
fi
