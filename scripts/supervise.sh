#!/usr/bin/env bash
# Supervisor sederhana untuk open.mp.
# Dipakai karena systemd di mesin ini membunuh proses 32-bit (SIGSYS dari
# SystemCallFilter bawaan manager), sementara omp-server adalah binary i386.
# Loop ini menjaga server tetap hidup: kalau crash, dijalankan ulang.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STOP_FILE="$ROOT/server/scriptfiles/.supervisor-stop"
PID_FILE="$ROOT/server/scriptfiles/.supervisor.pid"
mkdir -p "$ROOT/server/scriptfiles"
rm -f "$STOP_FILE"
printf '%s\n' "$$" > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT

cd "$ROOT/server"

while [ ! -f "$STOP_FILE" ]; do
    ./omp-server >> "$ROOT/server/scriptfiles/console.log" 2>&1 &
    server_pid=$!
    wait "$server_pid"
    code=$?
    if [ -f "$STOP_FILE" ]; then
        break
    fi
    printf '[supervisor] server berhenti (exit %s), restart 5 detik\n' "$code" \
        >> "$ROOT/server/scriptfiles/console.log"
    sleep 5
done

printf '[supervisor] berhenti sesuai permintaan\n' >> "$ROOT/server/scriptfiles/console.log"
