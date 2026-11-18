#!/usr/bin/env bash
# Start server di background lewat supervisor (auto-restart).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/server/scriptfiles"

if pgrep -x omp-server >/dev/null; then
    echo "server sudah jalan (pid $(pgrep -x omp-server | head -1))"
    exit 0
fi

rm -f "$STATE/.supervisor-stop"
setsid nohup "$ROOT/scripts/supervise.sh" >/dev/null 2>&1 </dev/null &
sleep 8
if pgrep -x omp-server >/dev/null; then
    echo "server jalan (pid $(pgrep -x omp-server | head -1)), supervisor $(cat "$STATE/.supervisor.pid" 2>/dev/null)"
else
    echo "server GAGAL start, cek $STATE/console.log" >&2
    tail -5 "$STATE/console.log" >&2
    exit 1
fi
