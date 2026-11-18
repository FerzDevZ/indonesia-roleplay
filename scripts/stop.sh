#!/usr/bin/env bash
# Hentikan server dengan rapi. Tidak memakai `pkill -f` supaya tidak salah
# membunuh shell pemanggil (pernah kejadian: exit 143).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/server/scriptfiles"

touch "$STATE/.supervisor-stop"

supervisor_pid=$(cat "$STATE/.supervisor.pid" 2>/dev/null || true)
if [ -n "$supervisor_pid" ] && kill -0 "$supervisor_pid" 2>/dev/null; then
    kill "$supervisor_pid" 2>/dev/null
fi

for pid in $(pgrep -x omp-server); do
    kill "$pid" 2>/dev/null
done

sleep 2
rm -f "$STATE/.supervisor-stop"
echo "server dihentikan"
