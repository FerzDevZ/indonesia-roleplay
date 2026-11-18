# indonesia-roleplay

Gamemode SA-MP / open.mp bertema roleplay Indonesia, ditulis murni dalam PAWN
tanpa plugin dan tanpa YSI. Satu server melayani klien **open.mp 1.6.x** dan
**SA-MP 0.3.7 / 0.3.DL**.

## Fitur saat ini

- Autentikasi akun + 3 slot karakter, pembuatan karakter, HUD, chat IC/OOC.
- Ekonomi rupiah: uang tunai, bank, mutasi, tilang, gaji pekerjaan.
- Identitas: KTP, SIM (ujian di Loket PD), data diri, kartu operator.
- Inventory berbasis item + UI tas yang bisa dipakai dari HP.
- Kebutuhan tubuh: lapar, haus, energi (`/makan`, `/minum`, `/tidur`).
- Warung & gedung data-driven: beli, kelola, menu, kas toko, buka/tutup.
- Interior custom per gedung (blueprint geometri, lihat `docs/13`).
- Pekerjaan kurir, layanan ATM, rumah sakit, job center, ikon radar.
- Rental kendaraan dinamis: paket & titik sewa diatur admin in-game, batas
  waktu, kunci pintu, pembersihan otomatis (`docs/15`).
- Dealer + kendaraan pribadi + STNK: katalog dari DB, plat unik, parkir
  menyimpan posisi, maksimal 3 unit per karakter (`docs/16`).
- Radio in-game: stasiun dari DB, tile MUSIK di ponsel, radio mobil otomatis
  (`docs/17`). Fase 2 menyiapkan lapisan metadata Spotify (bukan audio).
- Admin: level 1-5, audit setiap tindakan, pembuatan ATM/warung/gedung runtime.

## Teknologi

| Bagian | Pilihan |
|---|---|
| Bahasa | PAWN (open.mp compiler) |
| Server | open.mp 1.6.x (kompatibel 0.3.7/0.3.DL) |
| Database | SQLite (bawaan open.mp) |
| Build | `scripts/build.sh` |
| Mutu | `scripts/gates.sh` (9 gate, warning = error) |

## Struktur

```
gamemode.pwn            titik masuk, urutan include & boot
src/core/               db, log, settings, timer, text, telemetry
src/shared/             uang, pesan, fase pemain, validasi
src/domain/             aturan main per domain (auth, karakter, dunia, dst.)
src/ui/                 textdraw & panel (semua token visual di theme.pwn)
docs/                   arsitektur, data model, roadmap, standar, rancangan
scripts/                build, gates, status, supervisor, tunnel
```

## Build & jalankan

```bash
./scripts/build.sh      # kompilasi -> server/gamemodes/rp-indonesia.amx
./scripts/gates.sh      # 9 gate mutu (harus LULUS sebelum commit)
./scripts/start.sh      # jalankan server (atau ./scripts/supervise.sh)
./scripts/status.sh     # cek server + supervisor hidup
```

Konfigurasi server tidak disertakan di repo (berisi kredensial). Salin
`config.json.example` ke `server/config.json` lalu sesuaikan.

## Standar kode

Ringkasnya (lengkap di `docs/08-PAWN-STANDARDS.md`):

- Uang hanya ditulis oleh `src/shared/money.pwn`.
- Tabel milik modul dibuat di `Xxx_Boot()` modul itu, bukan di `db.pwn`.
- Satu file maksimal 400 baris, tanpa stub/TODO, tanpa variabel generik.
- Interaksi pemain lewat prompt `[Y]`, dialog hanya untuk input teks/daftar.
- Semua teks textdraw memakai token di `src/ui/theme.pwn`.

## Dokumentasi

| Dokumen | Isi |
|---|---|
| `docs/01-VISION-RP-INDONESIA.md` | visi & pilar permainan |
| `docs/02-DUAL-CLIENT-COMPAT.md` | aturan kompatibilitas klien lama |
| `docs/03-ARCHITECTURE.md` | arsitektur modul & alur data |
| `docs/04-DATA-MODEL.md` | skema database |
| `docs/08-PAWN-STANDARDS.md` | standar penulisan PAWN |
| `docs/09-RUN-AND-CONNECT.md` | cara menjalankan & terhubung |
| `docs/12-RENCANA-POWERFUL.md` | roadmap fitur |
| `docs/13-MAPPING-INTERIOR.md` | geometri mapping interior |
| `docs/14-FRAKSI-RANCANGAN.md` | rancangan fraksi (PD/EMS/gang) |
| `docs/15-KENDARAAN-RENTAL.md` | kendaraan sewaan dinamis |
| `docs/16-KENDARAAN-PRIBADI.md` | dealer, kendaraan pribadi, STNK |
| `docs/17-MUSIK-RADIO.md` | radio in-game & rencana hybrid Spotify |
