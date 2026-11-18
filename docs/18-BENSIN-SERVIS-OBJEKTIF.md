# 18 — Bensin, Servis, dan Objektif Pemain Baru

Dua hal yang ditambahkan bersamaan karena saling menutup lubang: **penguras
uang rutin pertama** dan **arah untuk 15 menit pertama**.

## 1. Bensin kendaraan pribadi

| Data | Nilai |
|---|---|
| Kapasitas tangki | 50 liter (`FUEL_CAPACITY`) |
| Harga | Rp 200/liter (`FUEL_PRICE_PER_LITER`) |
| Konsumsi idle | 0,004 liter/detik |
| Konsumsi per km/jam | 0,00018 liter/detik |
| Peringatan | sisa ≤ 20% |

Perhitungan: pada 80 km/jam konsumsi ≈ 0,0184 liter/detik, jadi satu tangki
penuh bertahan sekitar 45 menit mengemudi. Isi penuh = Rp 10.000 (setara dua
upah kurir), cukup terasa tanpa membuat pemain bangkrut.

- Kolom baru `vehicles.fuel` (migrasi otomatis saat boot, DB lama tidak reset).
- Bensin disimpan **per slot pemilik**, bukan per `vehicleid`, supaya tidak
  bocor saat kendaraan di-respawn atau pemain relog.
- Rental **tidak** memakai bensin: umurnya pendek dan selalu penuh.
- Tangki kosong hanya memunculkan peringatan sekali; klien 0.3.7 tidak punya
  native mematikan mesin lintas versi, jadi tidak ada pemaksaan engine state.

### Perintah

| Perintah | Syarat |
|---|---|
| `/isi penuh` | di lokasi `BENSIN`, kendaraan sendiri keluar, ≤ 8 m |
| `/isi <liter>` | sama, mengisi sebagian |
| `/servis` | di lokasi `BENGKEL`, biaya `500 + damage × 20` |
| `/buatbensin [nama]` | admin moderator, memasang lokasi di posisi sendiri |
| `/buatbengkel [nama]` | admin moderator, memasang lokasi di posisi sendiri |

Uang **selalu** dipotong sebelum efek diterapkan. Gagal bayar = tangki tidak
bertambah, kendaraan tidak diperbaiki.

## 2. Objektif pemain baru (onboarding)

Lima langkah, disimpan di `characters.onboard_step`, tampil sebagai satu baris
HUD bawah layar dan bisa dicek kapan saja lewat `/tujuan`:

1. Buka ponsel (`/hp`).
2. Ambil paket pertama di Job Center.
3. Antar paket, tekan `[Y]` di tujuan.
4. Beli makan atau minum di warung.
5. Cek saldo di ATM (`[Y]`).

Aturan keras: **objektif hanya maju berurutan**. Kalau pemain lama membeli
makan sebelum mengambil paket, langkahnya tidak melompat — teks HUD tidak
pernah menyesatkan. Saat semua selesai, HUD hilang sendiri dan pemain diberi
tahu bahwa sekarang tujuannya bebas.

HUD dibuat lewat pola *deferred activation* (timer 1 detik), bukan di dalam
callback spawn, dan nilainya di-cache (`gOnboardTextValue`) supaya
`PlayerTextDrawSetString` tidak dipanggil setiap detik.

## 3. Lokasi baru

Seed `locations_seed.pwn`:

| Kode | Aksi | Posisi |
|---|---|---|
| `BENSIN_STASIUN` | `BENSIN` | 1730.0, -1902.0, 13.0 |
| `BENGKEL_STASIUN` | `BENGKEL` | 1740.0, -1918.0, 13.0 |

Ikon radar: bensin = ikon dolar (52, layanan berbayar), bengkel = ikon mobil
(55). Prompt `[Y]` di lokasi ini hanya memberi petunjuk perintah, karena
interaksi bensin/servis butuh kendaraan yang sudah keluar.

## 4. Yang belum dikerjakan

- **Garasi fisik**: menunda sampai ada keputusan desain. `/pakai` sekarang sudah
  memanggil kendaraan dari posisi parkir terakhir, sehingga garasi hanya
  berguna kalau ia menjadi tempat penyimpanan yang berbeda dari parkir bebas —
  itu butuh perubahan API `VehicleOwned_Spawn`, bukan sekadar UI baru.
- Bensin untuk rental, dan pemakaian bahan bakar per model kendaraan.
