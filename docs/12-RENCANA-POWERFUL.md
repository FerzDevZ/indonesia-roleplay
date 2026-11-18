# 12 — RENCANA POWERFUL (Fase E dst.)

Rencana perubahan lengkap: prioritas, file, tabel DB, dan kriteria lulus.
Semua modul mengikuti invariant yang sudah ada (lihat `MEMORY.md`).

Aturan wajib untuk setiap fitur baru:
1. Tabel milik modul dibuat di `Xxx_Boot()` sendiri (bukan `db.pwn`).
2. Uang hanya lewat `src/shared/money.pwn` + alasan `MONEY_REASON_*` baru.
3. Wujud dunia (objek/pickup/label) di `Boot`, jangan di callback event.
4. UI tampilan = textdraw (tema `src/ui/theme.pwn`); dialog hanya input teks/list.
5. Tidak boleh `SelectTextDraw` di jalur prompt (menyebabkan "freeze").
6. Admin command wajib punya format + contoh di pesan error.
7. File ≤ 400 baris; kalau lewat → pecah (`Xxx_draw.pwn`, `Xxx_admin.pwn`).
8. Setelah selesai: `./scripts/build.sh` + `./scripts/gates.sh` LULUS, server restart, uji in-game.

---

## 0. SELESAI — Interaksi & Gedung (baseline)

| Fitur | Status | Catatan |
|---|---|---|
| Prompt `[Y]` tanpa mode kursor | SELESAI | bug "freeze" hilang |
| Hysteresis radius + cache teks | SELESAI | pil tidak kedip di Android |
| Tipe lokasi `GEDUNG` + penanda pintu | SELESAI | gedung = pickup + label `[Y] Interaksi` + ikon radar 31/32 di depan bangunan map yang sudah ada; TIDAK merakit bangunan baru (dulu ada shell DIY yang lantainya bolong - dibuang) |
| Instans interior unik per gedung | SELESAI | grid 8x3 (X/Y) + pita Z -> 24 ruang berbeda; pemain dari gedung berbeda tidak pernah ketemu di ruang sama |
| Ikon radar 31 (dijual) / 32 (dimiliki) | SELESAI | flip otomatis saat dibeli |
| Prompt dinamis gedung | SELESAI | Beli Gedung / Kelola Toko / Masuk Toko |
| Migrasi WARUNG → GEDUNG | SELESAI | otomatis saat boot |

---

## 1. KENDARAAN + STNK (prioritas tertinggi)

**Ringkas:** kendaraan pribadi yang benar-benar bisa dipakai, disimpan, dan punya surat.

- Tabel `vehicles`: `vehicle_id`, `owner_character_id`, `model`, `plate`, `color1`,
  `color2`, `fuel`, `condition` (0–1000), `park_x/y/z/rot`, `spawned`.
- Modul baru:
  - `src/domain/vehicle/vehicle.pwn` — data + memori + reload + park/unpark.
  - `src/domain/vehicle/vehicle_admin.pwn` — `/kendaraan <model> <plat>` (admin).
  - `src/domain/vehicle/vehicle_doc.pwn` — STNK (lihat `ktpcard.pwn` sebagai pola).
  - `src/ui/vehicleui.pwn` — panel kendaraan (mesin, lampu, bagasi, jual).
- Alur pemain: `/kendaraan` → daftar kendaraan → [Panggil] (spawn di titik park
  terdekat, biaya per panggil) → masuk → `[Y]` di dekat kendaraan = buka panel.
- Ekonomi: beli di dealer (`/belikendaraan`), pajak harian dipotong dari cash,
  bahan bakar habis → mesin mati (isi di pompa bensin, lokasi baru `POMPA`).
- Gate: kendaraan tidak bisa dipanggil kalau `owner != character`, atau
  `condition < 100` (harus perbaiki di bengkel).

## 2. KEBUTUHAN TUBUH (hunger / thirst / stamina) — SELESAI (v1)

Status: **sudah jalan**. Modul `src/domain/survival/survival.pwn` (379 baris),
HUD survival milik modul sendiri (bukan hud.pwn, supaya hud.pwn tetap kecil).

- 3 nilai per karakter: lapar, haus, energi (0..100), disimpan di kolom
  `characters.hunger/thirst/stamina`, dimuat saat spawn, disimpan saat keluar.
- Turun bertahap: lapar 1 poin / 90 detik, haus 1 poin / 60 detik, energi pulih
  1 poin / 5 detik.
- Lapar atau haus habis → darah turun 2 HP per 10 detik per bar kosong (tidak
  mati mendadak; batas bawah 1 HP).
- Makan/minum: `/makan`, `/minum`, atau tombol PAKAI di UI tas → lapar +45,
  haus +55, darah +10/+5. Item diambil dari tas (hasil beli di warung/gedung).
- `/tubuh` untuk melihat nilai sekarang; HUD kiri atas menampilkan 3 baris,
  warna bahaya saat < 25.
- Sisa untuk iterasi berikut: tidur di properti (pulihkan energi), efek
  kecepatan saat energi rendah, dan hukuman stamina untuk pekerjaan berat
  (API `Survival_TakeStamina()` sudah tersedia).

## 3. PEKERJAAN (multi-job, data-driven)

| Job | Mekanik | Modul |
|---|---|---|
| Kurir (ada) | ambil paket → antar | `job_kurir.pwn` |
| Ojek online | antar penumpang antar titik, tarif per meter | `job_ojek.pwn` |
| Sopir truk | kargo A→B, trailer, damage | `job_truk.pwn` |
| Nelayan | spot ikan, mini-game tarik, jual hasil | `job_nelayan.pwn` |
| Mekanik | perbaiki kendaraan pemain lain, upah dari pemilik | `job_mekanik.pwn` |

Pola seragam: tabel `job_progress` (character_id, job_code, level, xp), titik kerja
= lokasi `JOB_*`, UI panel FiveM, payout lewat `Money_Add(MONEY_REASON_JOB)`.

## 4. PROPERTI LANJUTAN

- **Gudang penyimpanan**: tabel `property_storage` (building_id, slot, item_code,
  amount). Kapasitas per tipe gedung.
- **Dekorasi**: owner pilih blueprint (1/2/3) → `Interiors_SetForBuilding`.
- **Karyawan**: tabel `property_staff` (building_id, character_id, wage, duty).
  Gaji harian dipotong dari `kas`; karyawan bisa buka/tutup toko.
- **Pajak gedung**: tiap 24 jam potong dari `kas`; kalau kas kurang → `is_open = 0`.
- **Sewa (rent)**: pemain sewa per hari, tidak dapat hak kelola.

## 5. SMARTPHONE (app)

- Sudah: kontak, pesan, bank (v3). Tambah: Marketplace, Ojek, Katalog Toko,
  Pengaturan (tema, notifikasi), Kamera (ambil foto → item foto).
- Setiap app = modul `src/ui/phone_app_<nama>.pwn`, dispatch di `phone.pwn`.

## 6. PD & EMS (faksi) — rancangan lengkap di [14-FRAKSI-RANCANGAN.md](14-FRAKSI-RANCANGAN.md)

- `/duty` (PD/EMS), MDT ringan (daftar Wanted/Tilang), `/tangkap` → penjara
  (koordinat + timer), EMS `/revive`.
- Tabel `factions` + `faction_members` (character_id, faction_code, rank).

## 7. ANTI-CHEAT & PERFORMA

- Validasi server: jarak interaksi (sudah), kecepatan kendaraan, uang (sudah),
  klik textdraw id tak dikenal (sudah di `TrxTd_ResolveClick`).
- Tick 500 ms: semua sistem yang menyentuh textdraw WAJIB hanya update kalau
  nilai berubah (pola `Prompt_Present` cache).
- Budget: ≤ 1000 objek, ≤ 256 player textdraw, file ≤ 400 baris.

## 8. URUTAN EKSEKUSI YANG DISARANKAN

1. Kendaraan + STNK (paling terasa "GTA5 RP").
2. Survival (lapar/haus) + item warung berfungsi.
3. Ojek online (job kedua, cepat).
4. Gudang properti + dekorasi.
5. PD/EMS + penjara.
6. Marketplace di HP.

Setiap langkah: tabel → API data → world dressing → UI → admin command → gate →
build+gates+hapus server+uji in-game → catat invariant di `MEMORY.md`.

## 7. Status kendaraan (diperbarui)

Rental kendaraan **v1 SELESAI** (lihat `docs/15-KENDARAAN-RENTAL.md`): paket
sewa dinamis dari DB, titik rental dibuat admin in-game, batas waktu, kunci
pintu, dan pembersihan otomatis. Belum masuk: kendaraan pribadi, STNK, pajak,
garasi, bahan bakar - semuanya menumpang modul `vehicle.pwn` yang sama.
