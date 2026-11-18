# 11 — Alur Pemain (desain alur utuh dari nol)

Dokumen ini adalah PETA ALUR, bukan spesifikasi modul. Setiap fase baru wajib
menjawab satu pertanyaan: **"pemain baru bisa merasakan alur ini dalam 15 menit
pertama?"** Kalau tidak, fase itu belum selesai.

---

## 1. Prinsip desain alur

1. **Empat loop, bukan daftar fitur.** Setiap aksi pemain harus masuk salah satu:
   `BERTAHAN` (tetap hidup), `MENCARI UANG` (kerja), `MENGELUARKAN UANG` (belanja),
   `MENGEJAR STATUS` (progression). Fitur yang tidak masuk loop mana pun = tunda.
2. **Layanan = LOKASI + prompt [Y].** ATM, loket SIM, loket STNK, warung, job
   center: semuanya titik fisik di kota. Dekat → pil `[Y]` muncul → klik/tekan.
   Perintah `/` hanya jalan pintas untuk pemain lama, bukan satu-satunya jalan.
3. **Uang punya sumber dan luberan.** Setiap loop uang harus jelas: dari mana
   masuk, ke mana keluar. Uang yang hanya berputar antar pemain = inflasi.
4. **Satu kunci membuka satu pintu berikutnya.** KTP → SIM → kendaraan → STNK →
   properti → bisnis. Jangan pernah menjual pintu yang kuncinya belum ada.

---

## 2. Peta perjalanan utuh (journey map)

```
KONEK → WELCOME → DAFTAR/MASUK → PILIH KARAKTER → BUAT KARAKTER
  → SPAWN TERMINAL BUS → 15 MENIT PERTAMA → LOOP HARIAN
      (kerja)  (belanja)  (sosial)  (hukum)  → LOGOUT (autosave)
```

---

## 3. 15 menit pertama — onboarding (KRITIS, belum ada)

Menit demi menit, dari kondisi sekarang:

| Menit | Kejadian | Yang sudah ada | Yang harus dibangun |
|---|---|---|---|
| 0-2 | Spawn di Terminal Bus + sambutan | toast sambutan | **spawn point baru** + teks objektif di HUD |
| 2-4 | Objektif 1: "Cek KTP-mu" | `/ktp` sudah jalan | teks objektif + arah |
| 4-12 | Objektif 2: "Kerja pertama: kurir" | - | **job kurir** + marker + prompt [Y] |
| 12-15 | Objektif 3: "Simpan uangmu" | - | **ATM + m-banking** + prompt [Y] |

Hasil akhir menit 15: pemain paham tiga pilar server ini —
**KERJA → UANG → BANK** — dan punya Rp 15.000 di bank, bukan Rp 0 di tengah
padang pasir.

---

## 4. Loop BERTAHAN (tetap hidup)

- **Sengsara minimal, bukan simulator penderitaan.** Fase awal TIDAK menyertakan
  lapar. Hunger ringan (turun per jam IC, makan di warung) masuk saat warung ada.
- **Kesehatan:** mati → RS (alur `medical` di 05). Belum dibangun; sementara
  respawn standar open.mp cukup.
- **Tempat tinggal:** sementara "kamar kontrakan" abstrak (respawn tetap sama);
  properti nyata menyusul di P4.

---

## 5. Loop UANG (ekonomi tertutup)

**Sumber uang (masuk):**

| Sumber | Nilai target | Status |
|---|---|---|
| Kurir (job pertama) | Rp 5.000 / antaran | BELUM ADA |
| Ojek (butuh SIM C) | Rp 8.000 - 15.000 / trip | BELUM ADA |
| Gaji faksi | mingguan IC | BELUM ADA |
| Jualan bisnis | margin pemilik | BELUM ADA |

**Luberan uang (keluar) — WAJIB lebih banyak dari sumbernya:**

| Luberan | Nilai target | Status |
|---|---|---|
| Makan warung | Rp 5.000 - 15.000 | BELUM ADA |
| Pulsa HP | Rp 10.000 - 50.000 | BELUM ADA (butuh smartphone) |
| Ujian SIM (B umum) | Rp 100.000 | ADA - fase C0: harga dikoreksi + gerbang Loket PD |
| Pajak kendaraan | tahunan | BELUM ADA |
| Tilang | Rp 10rb - 5jt | ADA (sink, benar) |
| Sewa kamar | Rp 20.000 / hari IC | BELUM ADA |
| Transportasi NPC | Rp 2.000 - 10.000 / trip | BELUM ADA |

**Koreksi angka yang sudah ada:** ujian SIM Rp 250.000 tidak masuk akal untuk
pemain yang baru punya Rp 15.000. Turunkan ujian SIM C ke Rp 50.000; SIM A
Rp 100.000; SIM B2 Rp 150.000. Tilang tetap.

**Aturan transfer:** antar pemain hanya lewat m-banking (biaya admin 1%, min
Rp 1.000) atau tunai lewat prompt `[Y] Beri Uang` saat dekat. Tidak ada
`/transfer` melayang.

---

## 6. Loop IDENTITAS & HUKUM (diperbaiki alurnya)

```
KTP (otomatis saat buat karakter)  [SELESAI]
  → butuh SIM: datangi LOKET PD (lokasi) → [Y] Daftar Ujian
      → ujian teori ringan → SIM C terbit           [lokasi: BELUM]
  → beli motor (dealership) → STNK di SAGOV (lokasi) [BELUM SEMUA]
  → pajak STNK tahunan (SAGOV / m-banking)           [BELUM]
  → pelanggaran → tilang polisi (poin +1)            [versi admin: ADA]
  → 3 poin → SIM dicabut → ulang ujian               [ADA]
```

**Koreksi alur sekarang:** `/ujisim` hari ini bisa dieksekusi dari mana saja.
Itu merusak alur "kota hidup". Perbaikan: perintah tetap ada, tapi menolak
kalau pemain tidak dalam radius loket PD. Prompt `[Y]` di loket jadi cara utama.

---

## 7. Loop SOSIAL

- Chat kanal (selesai), `/me` `/do` (selesai).
- Prompt `[Y]` antar pemain: Tunjukkan KTP (selesai) → nanti: Tunjukkan SIM,
  Beri Uang, Tukar Kontak (masuk smartphone).
- Smartphone: SMS persisten, telepon, kontak. Semua interaksi sosial jarak
  jauh lewat HP, bukan lewat perintah admin-like.

---

## 8. Tangga progresi (ladder)

| Tahap | Punya | Butuh | Buka akses |
|---|---|---|---|
| 1 | Rp 0, KTP | - | kurir, makan, jalan kaki |
| 2 | Rp 100rb | kerja 6-10 antaran | SIM (B umum) - SIM C menyusul bersama kendaraan |
| 3 | SIM C + motor Rp 150rb | tabungan | job ojek (lebih untung) |
| 4 | Rp 500rb | tabungan | kamar kontrakan + pulsa |
| 5 | Rp 1-2jt | tabungan | mobil + STNK + pajak |
| 6 | stabil | - | bisnis warung / izin usaha |

Setiap anak tangga HARUS tercapai dalam 2-4 jam bermain. Kalau lebih lama,
angkanya salah — turunkan, jangan naikkan.

---

## 9. Peta lokasi layanan (anchor kota)

| Titik | Layanan | Prompt [Y] |
|---|---|---|
| Terminal Bus (spawn) | objektif onboarding | - |
| Job Center (dekat spawn) | ambil job kurir/ojek | Ambil Paket / Mulai Trip |
| ATM (3 titik kota) | setor/tarik/transfer | Akses ATM |
| Loket PD | daftar ujian SIM | Daftar Ujian |
| Kantor SAGOV | STNK, pajak, izin usaha | Urus Dokumen |
| Warung | makan, beli kecil | Beli |
| RS | perawatan | Periksa |
| Bengkel | servis kendaraan | Servis |

Koordinat ditetapkan saat fase masing-masing dibangun; daftar ini adalah
kontrak bahwa lokasinya HARUS ada.

---

## 10. Gap → fase bangun (urutan kerja terkoreksi)

| # | Gap | Fase | Ukuran |
|---|---|---|---|
| 1 | Spawn point layak + teks objektif onboarding | C0 | kecil |
| 2 | Koreksi harga `/ujisim` + gerbang lokasi loket PD | C0 | kecil |
| 3 | Smartphone + M-Banking (saldo/transfer/mutasi) | C | besar |
| 4 | ATM sebagai lokasi + prompt [Y] | C | sedang |
| 5 | Job kurir (loop uang pertama, penuh state) | C1 | sedang |
| 6 | Inventory grid + barang fisik di dunia | C2 | sedang - **ADA** (`/tas`, `/beriitem`) |
| 6b | Warung data-driven (beli makanan/minuman/obat masuk tas) | D | sedang - **ADA** (`/buatwarung`, `/tambahmenu`, `/setharga`, `/tutupwarung`) |
| 6c | Gedung/properti dinamis: beli, kelola toko, kas | D | sedang - **ADA** (`/buatgedung`, beli via prompt, menu kelola pemilik) |
| 7 | Warung + makan + hunger ringan | D | sedang |
| 8 | Kendaraan + STNK + dealership | E | besar |
| 9 | Faksi PD sungguhan (tilang pindah dari admin) | F | besar |

C0 = sesi kecil sebelum C supaya 15 menit pertama langsung masuk akal.

---

## 11. Gerbang alur (checklist wajib tiap fase selesai)

1. Dari spawn, pemain BARU (tanpa dibantu) sampai ke loop uang dalam 15 menit?
2. Setiap layanan baru punya LOKASI + prompt [Y] (bukan hanya perintah)?
3. Uang yang masuk lewat fitur ini, ke mana keluar? (kalau tidak ada luberan,
   tambahkan luberan di fase yang sama)
4. Setiap kunci baru (SIM/STNK/izin) membuka akses konkret, bukan sekadar kartu?
5. Lolos 9 gates + uji sentuh Android?

## Kebutuhan tubuh, tidur, bantuan, laporan (v1)

| Aksi | Perintah | Syarat |
|---|---|---|
| Makan | `/makan` atau tombol PAKAI di `/tas` | punya item MAKANAN |
| Minum | `/minum` atau tombol PAKAI di `/tas` | punya item MINUMAN |
| Cek kondisi | `/tubuh` | — |
| Tidur | `/tidur` | berada **di dalam** interior gedung, jeda 60 detik |
| Bantuan | `/help`, `/help toko`, `/help admin` | admin: level ≥ 1 |
| Laporan | `/lapor <masalah>` | karakter aktif |

Lapar turun 1 poin / 90 detik, haus 1 poin / 60 detik, energi pulih 1 poin /
5 detik. Lapar atau haus 0 → darah turun 2 HP / 10 detik per bar kosong
(batas bawah 1 HP). Nilai disimpan ke DB saat keluar.

## Status toko

- Label pintu gedung menampilkan `DIJUAL Rp X` (belum dimiliki),
  `TUTUP` (pemilik menutup toko), atau tanpa baris tambahan (buka).
- Menutup toko menyinkronkan dua penanda: `buildings.is_open` dan
  `warungs.is_open`; pemain yang mencoba masuk mendapat pesan
  "Toko sedang tutup" tanpa teleport.
- `/buatgedung` menolak lokasi yang berjarak kurang dari 6 meter dari gedung
  lain supaya pickup & label tidak bertumpuk.
