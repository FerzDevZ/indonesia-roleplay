#!/usr/bin/env bash
# Hentikan supervisor DULU, baru server. Urutan ini wajib: kalau server dibunuh
# lebih dulu, supervisor akan langsung menghidupkannya kembali.
#
# Kenapa tidak `pkill -f omp-server`: pola itu juga mencocokkan command line
# supervisor dan shell pemanggil (pernah mematikan shell sendiri). Di sini
# server dicari dengan nama proses persis (`pgrep -x`), dan supervisor disaring
# dari /proc/<pid>/cmdline: hanya `bash <path>/supervise.sh` (2 argumen) yang
# dianggap supervisor. Shell yang kebetulan memuat teks "supervise.sh" di
# command line-nya (mis. `bash -c "...; ./scripts/supervise.sh &"`) tidak ikut
# dimatikan.
set -uo pipefail

Supervisor_List() {
    local pid argv=()
    for pid in $(pgrep -f 'supervise\.sh' 2>/dev/null); do
        [ "$pid" = "$$" ] && continue
        mapfile -t argv < <(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null)
        [ "${#argv[@]}" -eq 2 ] || continue
        case "${argv[0]##*/}" in bash|sh|dash) ;; *) continue ;; esac
        case "${argv[1]}" in *supervise.sh) echo "$pid" ;; esac
    done
}

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME="$ROOT/server/scriptfiles"
STOP_FILE="$RUNTIME/.supervisor-stop"
PID_FILE="$RUNTIME/.supervisor.pid"

echo "== menghentikan supervisor =="
mkdir -p "$RUNTIME"
: > "$STOP_FILE"

if [ -f "$PID_FILE" ]; then
    sup_pid=$(tr -dc '0-9' < "$PID_FILE")
    if [ -n "$sup_pid" ] && kill -0 "$sup_pid" 2>/dev/null; then
        kill "$sup_pid" 2>/dev/null
        echo "  sinyal stop -> supervisor pid $sup_pid"
    fi
fi

# Supervisor sisa dari sesi lama (mis. dijalankan sebelum ada penjaga single
# instance) tetap dimatikan, satu per satu.
for other in $(Supervisor_List); do
    kill "$other" 2>/dev/null && echo "  supervisor sisa dimatikan (pid $other)"
done

for _ in $(seq 1 10); do
    [ -n "$(Supervisor_List)" ] || break
    sleep 1
done

echo "== menghentikan server =="
server_pids=$(pgrep -x omp-server | tr '\n' ' ')
if [ -n "$server_pids" ]; then
    echo "  sigterm -> $server_pids"
    kill $server_pids 2>/dev/null
    for _ in $(seq 1 10); do
        pgrep -x omp-server >/dev/null 2>&1 || break
        sleep 1
    done
fi

leftover=$(pgrep -x omp-server | tr '\n' ' ')
if [ -n "$leftover" ]; then
    echo "  tidak berhenti sopan, sigkill -> $leftover"
    kill -9 $leftover 2>/dev/null
    sleep 2
fi

rm -f "$STOP_FILE" "$PID_FILE"

echo "== hasil =="
if pgrep -x omp-server >/dev/null 2>&1; then
    echo "  server    : MASIH HIDUP (periksa manual: pgrep -x omp-server)"
    exit 1
fi
echo "  server    : mati"

if [ -n "$(Supervisor_List)" ]; then
    echo "  supervisor: MASIH JALAN (server bisa dihidupkan lagi)"
    exit 1
fi
echo "  supervisor: mati"

if ss -lun 2>/dev/null | grep -q ':7777 '; then
    echo "  UDP 7777  : masih listen (proses lain memakai port)"
else
    echo "  UDP 7777  : bebas"
fi
