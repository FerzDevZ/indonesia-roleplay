# 16 — Kendaraan Pribadi, STNK, Dealer

Lanjutan `docs/15`: setelah kendaraan sewaan, sekarang pemain bisa **memiliki**
kendaraan sendiri. Kendaraan pribadi disimpan permanen di DB (beda dari rental
yang sementara).

## Alur pemain

```
1. Datang ke dealer (ikon mobil di radar) -> pill [Y] / perintah /dealer
2. Dialog katalog (nama + harga) -> pilih unit -> uang tunai dipotong
3. STNK terbit otomatis dengan plat unik (contoh: B 4821 RZ)
4. /pakai <nomor>  -> kendaraan muncul di posisi parkir terakhir
                      (kalau belum pernah parkir: 4 m di depan pemain)
5. /parkir          -> posisi + kondisi disimpan, kendaraan hilang dari dunia
6. /stnk           -> daftar kendaraan, plat, status (di jalan / terparkir)
```

- Maksimal **3 kendaraan** per karakter (`OWNED_MAX`).
- Harga diambil dari tabel `vehicle_catalog`, bukan kode.
- Uang dipotong **sebelum** INSERT; kalau DB menolak, uang dikembalikan
  otomatis (tidak ada kendaraan gratis / uang hangus).
- Pintu terkunci untuk pemain lain. Pemain yang baru masuk setelah kendaraan
  muncul tetap ditolak: `OnPlayerStateChange` menendang pengemudi bukan pemilik
  (aturan sama untuk kendaraan rental, jadi tidak ada celah "join belakangan").
- Kendaraan otomatis disimpan pada: `/parkir`, autosave periodik, putus
  koneksi, dan saat pemain tewas.

## Tabel

```sql
vehicle_catalog(catalog_id, name, model, price, enabled, created_at)
vehicles(vehicle_id, character_id, model, plate,
         pos_x, pos_y, pos_z, angle, health, bought_at)
```

`vehicles.pos_* = 0` berarti belum pernah diparkir; spawn memakai posisi pemain.
`health` minimal disimpan 250.0 supaya kendaraan tidak meledak saat dipanggil
kembali.

## Perintah

| Perintah | Siapa | Fungsi |
|---|---|---|
| `/dealer` | pemain | Buka katalog dealer (harus di titik dealer) |
| `/stnk` | pemain | Daftar kendaraan + plat + status |
| `/pakai <nomor>` | pemain | Keluarkan kendaraan pribadi |
| `/parkir` | pemain | Simpan posisi & simpan kendaraan |
| `/dealerkatalog` | admin (moderator) | Lihat katalog + nomor |
| `/dealerkatalog tambah <model> <harga> <nama>` | admin | Tambah unit (model 400–611, harga Rp 1.000–100.000.000) |
| `/dealerkatalog hapus <nomor>` | admin | Nonaktifkan unit |

Seed katalog: Sepeda BMX Rp 75.000 · Motor Faggio Rp 400.000 · Elegant
Rp 900.000 · Savanna Rp 1.100.000 · Landstalker Rp 1.500.000 · Burrito
Rp 2.500.000.

## Hubungan dengan rental (docs/15)

| | Rental | Pribadi |
|---|---|---|
| Penyimpanan | memori (ephemeral) | tabel `vehicles` |
| Batas waktu | ya (menit) | tidak |
| Jumlah | 1 aktif | 3 dimiliki, 1 aktif di jalan |
| Hapus | otomatis | manual (`/parkir` menyimpan) |
| Sumber | `rental_packages` | `vehicle_catalog` |

## Catatan pemeriksaan

- `/beli` (help warung) sebelumnya hanya teks tanpa handler; sekarang benar
  membuka panel warung terdekat.
- Pemeriksaan sambungan otomatis: `scripts/wiring-check.sh` (ikut di
  `scripts/gates.sh`) menolak perintah ganda, dialog tak terdaftar, dan aksi
  lokasi tanpa dispatch/ikon.

## Belum termasuk (tahap berikut)

Pajak/STNK kedaluwarsa, jual-beli antar pemain, garasi fisik, bensin,
modifikasi, dan kendaraan dinas fraksi. Semua akan menumpang `vehicle_owner.pwn`
supaya tidak ada dua sistem kepemilikan.
