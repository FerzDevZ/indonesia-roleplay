#!/usr/bin/env bash
# Supervisor sederhana untuk open.mp.
# Dipakai karena systemd di mesin ini membunuh proses 32-bit (SIGSYS dari
# SystemCallFilter bawaan manager), sementara omp-server adalah binary i386.
# Loop ini menjaga server tetap hidup: kalau crash, dijalankan ulang.
#
# SINGLE INSTANCE: hanya satu supervisor boleh hidup. Tanpa penjagaan ini,
# setiap `./scripts/supervise.sh &` menambah satu supervisor + satu omp-server
# baru, semuanya mengikat UDP 7777 (pernah menumpuk 17 proses).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/server/scriptfiles"
STOP_FILE="$RUNTIME/.supervisor-stop"
PID_FILE="$RUNTIME/.supervisor.pid"
mkdir -p "$RUNTIME"

# Penjaga single instance: PID lama dipakai hanya kalau prosesnya benar-benar
# supervisor (bukan PID yang sudah dipakai ulang proses lain).
if [ -f "$PID_FILE" ]; then
    other_pid=$(tr -dc '0-9' < "$PID_FILE")
    if [ -n "$other_pid" ] && kill -0 "$other_pid" 2>/dev/null \
            && tr '\0' ' ' < "/proc/$other_pid/cmdline" 2>/dev/null | grep -q 'supervise\.sh'; then
        printf 'supervisor SUDAH JALAN (pid %s). Hentikan dulu: ./scripts/stop.sh\n' "$other_pid"
        exit 1
    fi
    rm -f "$PID_FILE"
fi

rm -f "$STOP_FILE"
printf '%s\n' "$$" > "$PID_FILE"
trap 'rm -f "$PID_FILE"' EXIT
printf '[supervisor] mulai (pid %s)\n' "$$" >> "$RUNTIME/console.log"

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
