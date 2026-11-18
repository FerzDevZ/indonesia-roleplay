#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# wiring-check.sh - pemeriksaan sambungan modul (bukan gaya kode).
# Menangkap bug yang tidak terlihat compiler:
#   1. perintah yang sama ditangani dua modul (handler pertama selalu menang)
#   2. perintah yang disebut di /help tapi tidak punya handler
#   3. dialog yang dipakai tetapi tidak terdaftar di Dialog_IsKnown
#   4. aksi lokasi yang tidak punya dispatch atau tidak punya ikon radar
# ---------------------------------------------------------------------------
set -uo pipefail
cd "$(dirname "$0")/.."

python3 - << 'PY'
import re, glob, sys

files = sorted(glob.glob('src/**/*.pwn', recursive=True)) + ['gamemode.pwn']
sources = {f: open(f).read() for f in files}
problems = []

# 1. Perintah ganda per file. Duplikat di file yang SAMA wajar (pre-check +
#    dispatch), jadi yang dicari adalah nama sama di file berbeda.
owners = {}
for path, text in sources.items():
    for name in set(re.findall(r'strcmp\(command,\s*"([a-z_]+)"', text)):
        owners.setdefault(name, set()).add(path)
for name, paths in sorted(owners.items()):
    if len(paths) > 1:
        problems.append(f'perintah /{name} ditangani {len(paths)} modul: '
                        + ', '.join(sorted(paths)))

# 2. Perintah di /help tanpa handler.
handled = set(owners)
chat = sources.get('src/domain/chat/chat.pwn', '')
for word in sorted(set(re.findall(r'(?<![\w/])/([a-z]{2,})(?=[\s,.;|)]|<)', chat))):
    if word not in handled:
        problems.append(f'/{word} disebut di /help tetapi tidak ada handler')

# 3. Dialog dipakai tetapi tidak dikenal -> OnDialogResponse menolaknya.
known_block = re.search(r'stock bool:Dialog_IsKnown.*?\n}', sources['src/shared/messages.pwn'], re.S)
known = set(re.findall(r'DIALOG_[A-Z_]+', known_block.group(0))) if known_block else set()
for path, text in sources.items():
    for dialog in set(re.findall(r'ShowPlayerDialog\([^,]+,\s*(DIALOG_[A-Z_]+)', text)):
        if dialog != 'DIALOG_NONE' and dialog not in known:
            problems.append(f'{dialog} dipakai di {path} tetapi tidak terdaftar di Dialog_IsKnown')

# 4. Aksi lokasi: definisi LOC_ACT_* harus punya dispatch & ikon.
loc_text = sources.get('src/domain/world/locations.pwn', '')
actions = set(re.findall(r'#define\s+LOC_ACT_([A-Z_]+)', loc_text))
dispatch_src = ''.join(t for f, t in sources.items() if 'locations_actions' in f)
dispatched = set(re.findall(r'strcmp\(action,\s*LOC_ACT_([A-Z_]+)', dispatch_src))
icons = set(re.findall(r'LOC_ACT_([A-Z_]+)[^)]*\)\s*==\s*0\)\s*return LOC_MAP_ICON', dispatch_src))
if not icons:
    icons = set(re.findall(r'LOC_MAP_ICON_([A-Z_]+)', dispatch_src))
for action in sorted(actions - dispatched):
    problems.append(f'aksi lokasi LOC_ACT_{action} tidak punya dispatch')
# GEDUNG: ikonnya dinamis (31 dijual / 32 dimiliki) di Locations_ShowIcons.
# LOKET_PD: sengaja memakai ikon INFO bawaan, bukan ikon khusus.
dynamic_icons = {'GEDUNG'}
default_icon = {'LOKET_PD'}
if 'LOC_MAP_ICON_GEDUNG_SELL' not in dispatch_src:
    problems.append('aksi lokasi LOC_ACT_GEDUNG kehilangan ikon dinamis jual/milik')
for action in sorted(actions - icons - dynamic_icons - default_icon):
    problems.append(f'aksi lokasi LOC_ACT_{action} tidak punya ikon radar')

if problems:
    print('WIRING GAGAL:')
    for item in problems:
        print('  - ' + item)
    sys.exit(1)

print(f'wiring ok ({len(handled)} perintah, {len(actions)} aksi lokasi, {len(known)} dialog)')
PY
