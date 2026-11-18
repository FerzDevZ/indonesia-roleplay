# 15 — Kendaraan & Rental (dinamis)

Sistem kendaraan tahap pertama: **kendaraan sewaan (rental)** yang seluruh
paket dan titik sewanya bisa diatur dari dalam game, tanpa compile ulang.

## Prinsip

1. **Tidak ada kendaraan permanen di DB (tahap ini).** Kendaraan sewa bersifat
   sementara: hilang saat waktu habis, pemain keluar, atau pemain tewas. Ini
   mencegah "kendaraan hantu" setelah restart tanpa sistem garasi.
2. **Satu modul memiliki pool kendaraan.** `vehicle.pwn` satu-satunya tempat
   `CreateVehicle`/`DestroyVehicle` untuk kendaraan sewa.
3. **Data-driven.** Paket (model, harga, durasi, nama) hidup di tabel
   `rental_packages`; titik sewa hidup di tabel `locations` (action `RENTAL`)
   dan posisi spawn kendaraan di tabel `rental_sites`.
4. **Uang hanya lewat `shared/money.pwn`** dengan alasan `MONEY_REASON_RENTAL`.

## Tabel

```sql
rental_packages(package_id, name, model, price, minutes, enabled, created_at)
rental_sites(location_code, spawn_x, spawn_y, spawn_z, spawn_angle, created_at)
```

- Seed paket hanya dijalankan **saat tabel kosong**, jadi harga yang sudah
  diubah admin tidak pernah ditimpa saat restart.
- Titik rental hasil seed otomatis mendapat baris spawn sendiri
  (`RENTAL_STASIUN` diisi +5 m dari lokasi) saat boot pertama, supaya `/rental`
  tidak pernah menolak pemain dengan "spawn belum diatur admin".
- `rental_sites.location_code` = kode lokasi rental di tabel `locations`.
  Kalau baris belum ada, posisi spawn memakai offset bawaan
  (`lokasi.x + 5.0`) supaya layanan tetap jalan.

## Alur pemain

```
pemain mendekati titik rental (ikon mobil di radar)
  -> pill [Y] "Rental" muncul (interaksi manual, bukan otomatis)
  -> Y / klik pill  => dialog daftar paket (nama, harga, durasi)
  -> pilih paket     => uang dicek, kendaraan spawn, saldo dipotong
  -> /kendaraan      => sisa waktu sewa
  -> /kembalikan     => kendaraan dihapus (butuh <= 25 m dari kendaraan)
```

- Harga sewa **tidak dikembalikan** saat mengembalikan lebih awal.
- Pengingat otomatis: 30 detik sebelum habis, lalu saat waktu habis.
- Pintu dikunci untuk pemain lain; pemilik membuka kuncinya saat masuk.
- Pemain hanya boleh menyewa satu kendaraan pada satu waktu.

## Perintah admin

| Perintah | Fungsi |
|---|---|
| `/buatrental <nama>` | Buat titik rental di posisi admin; kendaraan muncul 6 m di depan |
| `/rentalspawn` | Set posisi & arah spawn kendaraan sesuai posisi admin |
| `/hapusrental` | Hapus titik rental terdekat (lokasi + baris `rental_sites`) |
| `/rentalpkg` | Daftar paket beserta nomornya |
| `/rentalpkg tambah <model> <harga> <menit> <nama>` | Tambah paket (model 400–611, harga Rp 100–10.000.000, 1–120 menit) |
| `/rentalpkg hapus <nomor>` | Nonaktifkan paket (baris DB tetap, `enabled = 0`) |
| `/rentalreload` | Muat ulang cache paket setelah edit DB manual |

Semua perintah butuh level admin >= `ADMIN_MODERATOR` dan dicatat di
`admin_audit`.

## Batasan yang disengaja

- Tidak ada STNK/pajak/garasi pribadi — tahap berikutnya (lihat `docs/12`).
- Kendaraan sewa tidak punya bahan bakar; sistem BBM akan masuk bersama
  kendaraan pribadi supaya tidak ada dua implementasi konsumsi.
- Penumpang bisa ikut masuk hanya kalau pemilik sudah membuka pintu (kunci
  dipasang saat spawn untuk pemain lain yang sedang online).
