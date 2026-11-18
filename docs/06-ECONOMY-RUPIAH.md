# 06 — Ekonomi Rupiah

Semua angka dalam Rupiah, disimpan sebagai `BIGINT` (bukan `FLOAT`, tidak ada sen).

## 1. Skala uang

| Item | Nilai | Catatan |
|---|---|---|
| Uang awal karakter | Rp 25.000 | Cukup 2 hari main |
| Gaji kurir paket | Rp 350 / paket | ~12 paket/jam = Rp 4.200/jam |
| Gaji ojek | Rp 500 / trip | Butuh SIM C |
| Gaji truk | Rp 8.000 / rute | Butuh SIM B2, 20 menit |
| Gaji faksi level terendah (PD) | Rp 6.000 / jam IC | Dibayar mingguan |
| Makanan (warung) | Rp 150 | Pulihkan hunger 40 |
| Bahan bakar | Rp 12 / liter | Mobil 50 L = Rp 600 |
| Servis kendaraan | Rp 2.500 | Kembalikan health |
| Denda tilang ringan | Rp 1.500 | Tidak pakai helm |
| Denda tilang berat | Rp 15.000 | Tanpa SIM |
| Biaya ujian SIM | Rp 20.000 | Tidak kembali kalau gagal |
| Rumah kecil | Rp 2.500.000 | Target 60 jam main |
| Mobil pribadi | Rp 1.200.000 | Target 25 jam main |
| Tebusan impound | Rp 25.000 | + denda harian |
| Biaya rumah sakit | Rp 5.000 | Setelah PK |

Prinsip: **benda besar = puluhan jam main**, bukan belasan jam. Ini menjaga progresi
tanpa membuat pemain baru merasa mustahil.

## 2. Faucet (uang masuk) dan sink (uang keluar)

| Faucet | Perkiraan /jam/pemain | Sink pasangan |
|---|---|---|
| Job legal | 4.000–12.000 | Pajak 5%, BBM, servis |
| Gaji faksi | 6.000–20.000 | Pajak penghasilan faksi |
| Bisnis (pemilik) | variabel | Order stok, gaji karyawan, izin usaha |
| Rampasan/rampok | 0–50.000 (risiko) | Denda, tahanan, hilang saat PK |
| Event admin | terbatas | Wajib diumumkan + masuk audit |

Rasio target **faucet : sink = 1.3 – 1.6**. Di bawah 1.3 → deflasi (uang mati,
pemain berhenti jualan). Di atas 1.6 → inflasi (harga tidak berarti).

## 3. Pengukuran (bukan tebakan)

`domain/economy` menghitung setiap jam dari `money_log`, dan skill admin punya command
`/economy` yang menampilkan:

```
Faucet 60 mnt terakhir : Rp 4.210.500  (detail per reason)
Sink   60 mnt terakhir : Rp 3.120.000  (detail per reason)
Rasio                  : 1.35  [SEHAT]
Top faucet             : JOB_TRUCKER (Rp 1.240.000)
Top sink               : TAX (Rp 980.000)
Uang beredar (M0)      : Rp 182.400.000  (naik 3.1% / 24 jam)
```

Alarm otomatis:
- Rasio > 1.9 selama 3 jam → log peringatan ke owner.
- M0 naik > 8% / 24 jam → `admin_audit` entry "ECONOMY_ALERT".
- Satu karakter menerima > Rp 500.000 dalam 10 menit → flag `money_log` untuk ditinjau.

## 4. Aturan implementasi

1. Semua fungsi uang lewat `shared/money`:
   `Money_Add()`, `Money_Take()`, `Money_Transfer()`, `Money_Debt()`, `Money_Pay()`.
2. `Money_Take` mengembalikan `bool` — pemanggil **wajib** menangani `false`
   (bukan tagihan yang hilang diam-diam).
3. `reason` adalah enum `MONEY_REASON_*`, bukan string bebas. Nilai barunya harus
   ditambahkan di satu tempat di `shared/money.pwn`.
4. Tidak ada `float` untuk uang. Tidak ada `db_currency` ganda.
5. Setiap perubahan harga/tarif wajib disertai catatan di `docs/CHANGELOG-ECONOMY.md`
   tentang dampak yang diharapkan.

## 5. Kalibrasi awal (fase 1 rilis)

Selama 2 minggu pertama, ekonomi disetel **konservatif** (sink lebih besar) karena
pemain baru cenderung menumpuk uang di awal. Kalau M0 turun > 15%, naikkan gaji job
5–10% — jangan menurunkan harga barang, karena harga adalah jangkar persepsi pemain.
