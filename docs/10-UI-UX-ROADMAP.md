# 10 · Blueprint UI/UX TextDraw — Roleplay Indonesia 2026

> Tujuan: menjadikan server ini setara FiveM/NoPixel 4.0 dalam rasa UI, tetap
> jalan mulus di PC (open.mp / 0.3.7 / 0.3.DL) **dan** Android, dengan PAWN
> murni (tanpa CEF wajib). Semua angka koordinat memakai kanvas 640x480;
> bentuk persegi dikoreksi aspek 16:9 (x0.75) lewat engine `ui/trxtdraw`.

---

## 1 · Fondasi (SUDAH ADA — jangan dibangun ulang)

| Komponen | Modul | Status |
|---|---|---|
| Engine primitif (sprite, teks, kartu rounded, tombol akurat) | `ui/trxtdraw` | SELESAI |
| Registry klik (handle → id aksi) | `ui/trxtdraw` | SELESAI |
| Budget pool 256 PlayerTextDraw + peringatan | `ui/trxtdraw` | SELESAI |
| Toast notifikasi 3 slot auto-dismiss | `ui/toast` | SELESAI |
| Progress bar halus (track + fill) | `ui/trxtdraw` | SELESAI |
| Preview model 3D (pemilih skin) | `ui/charcreate` | SELESAI |
| Layar masuk kartu kaca + pilih karakter | `ui/welcome`, `ui/charselect` | SELESAI |

**Aturan besi yang sudah tercatat di MEMORY.md:**
1. `SetSelectable` SEBELUM `Show`.
2. Dilarang karakter non-ASCII (·, —, ') di string textdraw.
3. Semua warna lewat token `ui/theme` — dilarang warna literal.
4. Simbol lintas file = `stock`/`new`; `static` hanya untuk state satu file.

---

## 2 · Manajer UI Modal (PREREQUISITE FASE BERIKUTNYA)

Aturan pool: semua modal **mutually exclusive**. Satu pemain hanya boleh
membuka satu modal; buka modal baru = wajib tutup modal lama.

```pawn
enum E_ACTIVE_UI {
    UI_NONE, UI_PHONE, UI_BANK, UI_INVENTORY, UI_DEALERSHIP,
    UI_GARAGE, UI_HOUSE, UI_MDT, UI_ADMIN, UI_HELP
}
```

- `UIModal_Open(playerid, E_ACTIVE_UI:which)` — tutup modal aktif, buka baru.
- `UIModal_Close(playerid)` — hancurkan SEMUA PlayerTextDraw modal aktif,
  `CancelSelectTextDraw`, kembalikan kamera bila perlu.
- Semua modal WAJIB punya tombol `[X]` tutup (min 28x28, pojok kanan-atas
  kartu) — pengguna Android tidak punya ESC yang nyaman.
- Budget per modal maks 140 PlayerTextDraw; headroom total >= 60.

---

## 3 · HUD Persisten (target <= 22 PlayerTextDraw)

| Elemen | Posisi (mobile-safe) | Catatan |
|---|---|---|
| Saldo Rp (Pricedown hijau) | kanan-atas | sudah ada |
| Jam WIB | kanan-atas bawah saldo | sudah ada |
| Pil HP + Armour | kiri-atas, kapsul vertikal | update dirty-flag (ubah >= 1%) |
| Pil Lapar + Haus | kiri-atas bawah HP | sistem needs (fase ekonomi) |
| Ikon sinyal phone | kanan-atas | dekoratif, menyala saat di dalam gedung? tidak — saat punya HP |
| Tag server | kiri-bawah | sudah ada, DIAMANKAN di atas zona joystick: pindah ke kiri-atas bawah pil |
| Wanted level (bintang) | kanan-atas bawah jam | hanya tampil bila > 0 |
| Speedometer | bawah-tengah (x 240..400) | HANYA saat jadi driver; 16 TD |

Larangan: jangan taruh apa pun di `x: 0..165, y: 310..480` (joystick Android)
dan `x: 475..640, y: 280..480` (tombol sentuh Android).

### Speedometer (16 TD, hidup saat driver, mati saat turun)
- Digit kecepatan besar (Bank Gothic 0.48/2.0) + label `KM/H` redup.
- Bar bahan bakar isi-halus (Progress engine) + indikator mesin.
- Badge status: `ENG` `LCK` `BELT` `LGT` — redup default, menyala hijau saat aktif.
- Update timer 200ms hanya saat `PLAYER_STATE_DRIVER`.

---

## 4 · Katalog Fitur UI (urutan prioritas)

### P1 — Identitas & Hukum (SELESAI - Fase B)
1. **Kartu KTP / SIM** — SELESAI: `ui/ktpcard.pwn` (layout e-KTP asli:
   provinsi, NIK 16 digit di bawah foto, dua kolom, alamat, WNI/SEUMUR HIDUP)
   dan `ui/simcard.pwn` (SIM Nasional: band biru tua, Inggris kanan,
   golongan, berlaku s.d.). STNK menyusul bersama sistem kendaraan.
2. **Tilang** — SELESAI (versi admin): `/tilang <nama> <denda>`, denda sink
   ke kas, poin SIM +1, 3 poin = SIM dicabut. Versi modal polisi menyusul
   di P3 (faksi).
3. **Prompt interaksi `[Y]`** — SELESAI: pil bawah-tengah, badge merah bisa
   diklik (Android) atau tombol Y, deteksi tetangga tiap 500 ms, radius 3 m.

### P2 — Ekonomi Produktif
4. **Smartphone** (modal terbesar, layar penuh kanan atau tengah):
   - Home: grid ikon (sprite) 2x4: Kontak, Pesan, Bank, Peta, Galeri Iklan,
     Dispatch, Garasi, Pengaturan.
   - M-Banking: saldo, transfer via nomor HP/rekening, mutasi 10 terakhir.
   - Pesan: thread SMS persisten (DB), balas cepat.
   - Dispatch: panggil Taksi/Mekanik/EMS/Polisi dengan tombol satu-klik.
5. **Inventory grid** — modal 5x4 slot, ikon item = sprite txd, klik slot =
   detail + aksi (Pakai / Jatuhkan / Simpan). Berat maksimum di header.
6. **Job HUD** — panel kiri-atas saat bekerja: nama job, target, upah, dan
   **skill-check minigame** (bar + zona target kuning + jarum bergerak; tekan
   Y / klik pil `SIKRON` saat jarum di zona) untuk tambang/memancing/lockpick.
7. **Dealership & Garasi** — kartu kendaraan: preview model 3D (font 5),
   harga, spesifikasi; garasi: daftar kendaraan + status (pajak, bahan bakar,
   impound).

### P3 — Faksi & Darurat
8. **MDT Polisi** — modal: cari warga (nama), cek plat, tilang aktif, BOLO,
   antrian 911 dengan tombol `TERIMA` + pin GPS.
9. **Layar terluka (downed state)** — vignette merah + timer bls
   `KAMU TERLUKA - 90s` + tombol `PANGGIL BANTUAN` (bisa diklik Android).
10. **HUD faksi** — badge faksi + pangkat di kiri-atas bila bertugas.

### P4 — Hunian & Sosial
11. **Menu rumah** — status sewa/pajak, gudang, pintu kunci, editor furnitur
    (mode edit: panah geser + rotasi + konfirmasi).
12. **Papan iklan kota** — daftar iklan jual-beli dari marketplace HP.
13. **Onboarding quest tracker** — 3 objektif pertama di kanan-tengah
    (`1. Sewa Faggio  2. Buka rekening  3. 1x delivery`) dengan ceklis.

### P5 — Polesan
14. **Cinematic login** — kamera interpolasi melambat di landmark LS di
    belakang kartu masuk (sudah ada kartunya; tinggal kamera).
15. **Spawn selector** — kartu pilih titik spawn (terakhir / bandara / rumah).
16. **Menu bantuan `/help`** — modal daftar perintah per kategori, clickable.
17. **Admin panel textdraw** — daftar pemain online + aksi cepat (kick, warn,
    teleport), log audit tetap ke DB.

---

## 5 · Ergonomi Android (wajib di SEMUA fitur baru)

1. Target sentuh min 28x22 (primer 36x24) — sudah dijaga `TrxTd_Button`.
2. Jarak antar tombol >= 6 unit.
3. Setiap modal punya `[X]` tutup yang bisa diklik.
4. Setiap aksi berbasis tombol keyboard (Y/N/H/ALT) PUNYA padanan:
   pil textdraw yang bisa diklik + alias perintah pendek (`/e`, `/inv`).
5. Uji dua perangkat: layar 16:9 dan 19.5:9 — kartu tetap di tengah,
   tidak ada elemen di zona kendali sentuh.

## 6 · Disiplin Teknis (berlaku permanen)

- Update HUD via **dirty-flag** + timer berkala (1s HUD, 200ms speedo) —
  DILARANG render ulang di `OnPlayerUpdate`.
- Satu pemain = satu modal (`UIModal_*`), tutup sebelum buka.
- Setiap modal punya `*_Destroy` yang menghancurkan SEMUA draw-nya
  (TrxTd_Kill semua handle) — dipanggil di disconnect juga.
- Semua warna/font dari `ui/theme`; kalau butuh token baru, TAMBAHKAN di
  theme, jangan hardcode.
- Kontras: teks utama >= 12:1, sekunder >= 5:1 di atas panel gelap.
- Anggaran pool per fitur (lihat tabel di skill textdraw): HUD 22, speedo 16,
  toast 12, progress 6, modal <= 140, headroom 60.

## 7 · Urutan Eksekusi yang Disarankan

1. **UIModal manager** (fondasi semua modal, ~1 modul kecil).
2. **P1**: KTP/SIM/STNK + tilang + prompt `[Y]` (skema DB sudah siap:
   `identity_docs`, `plates`).
3. **P2**: smartphone (bank dulu, lalu pesan/dispatch), inventory, job HUD.
4. **P3-P5** mengikuti fase konten (faksi, hunian, polesan).

Setiap fitur selesai = wajib lolos 9 gates + uji sentuh Android.

Aturan tambahan yang lahir dari P1 (berlaku permanen):

- Modal klik: `SelectTextDraw` saat show, `CancelSelectTextDraw` saat
  destroy, re-arm di `OnPlayerCancelSelectTextDraw`.
- Tanpa redraw penuh di dalam callback klik - update teks saja.
- `TrxTd_Kill` = hide sebelum destroy (Android render basi).
- `OnPlayerSpawn` menjalankan jaring pengaman: tutup semua modal layar.
