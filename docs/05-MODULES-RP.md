# 05 — Modul roleplay (nuansa Indonesia)

Setiap modul di bawah adalah satu domain di `src/domain/`. Format spesifikasi sama:
tujuan, state, API publik, alur pemain, dan yang **tidak** boleh dilakukan.

---

## 5.1 `auth` — akun, bukan karakter

**Tujuan:** masuk/daftar cepat, aman, dan tidak bisa dipakai untuk multiclient curang.

- Daftar: username 3–24 karakter, password ≥ 8, bcrypt cost 11.
- Login: 3 percobaan gagal → cooldown 60 detik (disimpan per akun, bukan per IP saja).
- Deteksi IP ganda untuk akun berbeda → log ke `admin_audit`, bukan auto-ban.
- Session state hidup di `PHASE_AUTHENTICATING`; `/q` di fase ini tidak menyimpan apa pun.

Public API: `Auth_Begin(playerid)`, `Auth_IsUsernameFree(name[])`, `Auth_Logout(playerid)`.

**Dilarang:** menyimpan password di variabel Pawn lebih dari satu callback; menampilkan
pesan "username tidak ada" (harus generik: "kombinasi salah").

---

## 5.2 `character` — 3 slot per akun

- Pilih karakter menampilkan nama, umur, pekerjaan, jam bermain.
- Hapus karakter = soft delete (`deleted_at`), data kendaraan/properti tidak ikut hilang
  sampai 30 hari.
- Validasi nama: hanya huruf dan `_`, panjang 4–24, tidak boleh mengandung gelar/jabatan
  (`_POLISI`, `_ADMIN` ditolak).
- Setelah pilih → `PHASE_LOADING` → muat semua domain secara paralel (bukan berurutan).

Public API: `Character_Load(playerid, characterId)`, `Character_Save(playerid)`,
`Character_GetName(playerid, dest[], len)`, `Character_GetId(playerid)`.

**Dilarang:** memuat data domain sebelum karakter dipilih (mencegah kebocoran data
antar-karakter di akun yang sama).

---

## 5.3 `identity` — KTP, SIM, STNK (pembeda utama server ini)

Ini modul yang membuat RP terasa Indonesia. Semua dokumen punya nomor, tanggal terbit,
masa berlaku, dan penerbit.

**Jenis dokumen**

| Dokumen | Kegunaan | Masa berlaku | Penerbit |
|---|---|---|---|
| KTP | Syarat urus SIM, buka usaha, beli kendaraan | seumur hidup | SAGOV |
| SIM A | Motor < 250cc, mobil pribadi | 5 tahun | PD (unit SIM) |
| SIM B1 | Truk ringan, bus kecil | 5 tahun | PD |
| SIM B2 | Truk berat, trailer | 5 tahun | PD |
| SIM C | Taksi/ojek/bus umum (angkutan umum) | 3 tahun | PD |
| Izin Usaha | Warung, resto, bengkel, toko | 1 tahun | SAGOV |

**Alur urus SIM (di kantor PD)**

```
Pemain datang ke loket → /sim urus
  → cek KTP ada? kalau tidak: arahkan /ktp buat
  → pilih golongan A/B1/B2/C
  → ujian teori 5 soal (dialog, acak dari bank soal)
  → bayar biaya ujian (lihat 06-EKONOMI)
  → lulus 4/5 → SIM terbit, nomor generate
  → gagal → cooldown 10 menit, biaya tidak kembali
```

**Alur STNK & plat**

- Setiap kendaraan wajib punya plat terdaftar; kendaraan tanpa STNK kena tilang.
- STNK berlaku 1 tahun; lewat masa berlaku → pajak progresif + denda keterlambatan.
- Plat bisa dicuri (memasang plat palsu) → `plates.is_stolen = 1`, muncul di `/mdc cek plat`.

**Tilang (dari sisi PD)**

```pawn
// domain/identity/license.pwn
stock License_Fine(issuerCharacterId, targetCharacterId, LicenseFineReason:reason) {
    new amount = License_FineAmount(reason);
    if (!Money_Take(targetCharacterId, amount, MONEY_REASON_FINE, issuerCharacterId)) {
        // tidak punya uang tunai → utang tercatat, bukan gagal diam-diam
        Money_Debt(targetCharacterId, amount, MONEY_REASON_FINE, issuerCharacterId);
    }
    Audit_Write(issuerCharacterId, "ISSUE_FINE", targetCharacterId, amount);
    return 1;
}
```

Public API: `Identity_Issue()`, `Identity_Has()`, `Identity_Revoke()`,
`Identity_CheckPlate()`, `License_Fine()`.

**Status implementasi (Fase B SELESAI):**

- KTP otomatis terbit saat karakter dibuat; NIK format nasional
  `3175` + DDMMYY + 6 digit serial (`Identity_GetNik`).
- `/ktp` menampilkan kartu e-KTP (`ui/ktpcard.pwn`) dengan layout asli:
  header provinsi, foto + NIK, dua kolom label-nilai, alamat, kewarganegaraan.
- `/sim` menampilkan SIM Nasional (`ui/simcard.pwn`); `/ujisim` biaya
  Rp 250.000, syarat usia 17+, berlaku 5 tahun.
- `/datadiri` mengubah 7 field: nama wajib tetap, NIK/TTL tak bisa diubah;
  agama, gol. darah, tinggi, berat, pekerjaan, alamat, status perkawinan.
- `/tilang <nama> <denda>` (admin >= 1 sementara, sampai faksi PD ada):
  denda 10rb-5jt = **sink** lewat `Money_Take`/`Money_Debt`, poin SIM +1,
  3 poin = SIM dicabut.
- Prompt `[Y]` (`ui/prompt.pwn`): dekat pemain lain <= 3 m muncul pil
  "[Y] Tunjukkan KTP" - tombol Y atau klik badge (Android).

**Aturan UI yang lahir dari fase ini (wajib untuk dokumen baru):**

- Setiap jenis dokumen punya modul UI sendiri dengan layout autentik
  (jangan kartu generik) - token warna di `theme.pwn`.
- Modal klik WAJIB `SelectTextDraw` saat show, `CancelSelectTextDraw`
  saat destroy, dan re-arm di `OnPlayerCancelSelectTextDraw` (sentuhan
  Android di luar tombol memicu cancel).
- Jangan redraw penuh di dalam `OnPlayerClickPlayerTextDraw`; update
  teks yang berubah saja (`PlayerTextDrawSetString` + Show).
- `TrxTd_Kill` selalu hide sebelum destroy (render basi klien Android).

**Dilarang:** menganggap `bool:punyaSIM` di level karakter. SIM adalah baris di
`identity_docs` yang bisa dicabut pengadilan.

---

## 5.4 `vehicle` — kepemilikan, bahan bakar, odometer

- Bahan bakar realistis: konsumsi per km dari tabel model, bukan angka seragam.
- Odometer naik → pengaruh ke harga jual dan kebutuhan servis.
- Mesin mati kalau bahan bakar 0; tidak bisa di-start tanpa `/mesin`.
- Kunci kendaraan: hanya pemilik + faksi berwenang; `/kunci` untuk lock/unlock.
- Impound: ditilang berat atau ditinggal → masuk `is_impounded`, tebusan di kantor PD.

Public API: `Vehicle_SpawnOwned()`, `Vehicle_Assign()`, `Vehicle_Refuel()`,
`Vehicle_GetOwner()`.

---

## 5.5 `property` dan `business`

**Properti (rumah/garasi/gudang)**

- Harga per unit; sewa harian untuk yang tidak beli.
- Pajak properti tahunan (`properties.tax_due_at`). Telat 14 hari → disita dan dilelang.
- Furniture minimal: kasur (tidur → pulihkan health), lemari (simpan item), garasi (spawn kendaraan).

**Bisnis**

| Jenis | Mekanik inti |
|---|---|
| Warung / Resto | Beli stok dari supplier, jual ke pemain, makanan memulihkan hunger |
| Bengkel | Servis kendaraan, jual sparepart, cat |
| Toko | Jual item umum (senter, rokok, air) |
| Pompa bensin | Beli bahan bakar dari depot, jual ke pemain |
| Laundry | Cuci pakaian → status bersih, pengaruh kecil ke RP |

- Stok habis → bisnis tidak bisa jual, harus order ke supplier (ada lead time 5 menit).
- Semua penjualan masuk `businesses.balance`, penarikan oleh pemilik tercatat.

---

## 5.6 `faction` — PD, EMS, SAGOV, gang

| Kode | Faksi | Peran | Kanal chat |
|---|---|---|---|
| PD | Kepolisian | Tilang, tangkap, MDC, warrant, patroli | `/r` radio PD |
| EMS | Medis | Revive, CPR, ambulans, rumah sakit | `/r` radio EMS |
| SAGOV | Pemerintahan | SIM, izin usaha, pajak, lelang | `/gov` |
| MECH | Bengkel resmi | Servis kota, derek | `/r` |
| GANG_* | Gang | Klaim wilayah, pasar gelap | `/g` |

**Rank & permission**

```pawn
// shared/pools.pwn
#define PERM_MDC        (1 << 0)
#define PERM_TICKET     (1 << 1)
#define PERM_ARREST     (1 << 2)
#define PERM_IMPOUND    (1 << 3)
#define PERM_REVIVE     (1 << 4)
#define PERM_HIRE       (1 << 5)
#define PERM_TREASURY   (1 << 6)
```

Nama pangkat IC (bukan "Rank 3"): PD → `Brigadir`, `Inspektur`, `AKP`, `Komisaris`.
EMS → `Perawat`, `Dokter`, `Dokter Spesialis`, `Kepala Medis`.

**MDC (Mobile Data Computer)**

`/mdc` membuka dialog Tablist dengan menu: cari orang, cek plat, daftar warrant,
riwayat tilang, APB. Setiap pencarian dicatat agar tidak disalahgunakan untuk metagaming
(cek pemain tanpa alasan RP → terlihat di audit).

---

## 5.7 `economy` — gaji, pajak, bank, ATM

- Gaji faksi dibayar mingguan IC (bukan tiap menit), otomatis, masuk `money_log`.
- Pajak: properti tahunan, kendaraan tahunan, pajak penjualan bisnis 5%.
- Bank: setor/tarik di ATM atau teller; transfer antar pemain dengan biaya admin.
- Utang: saldo boleh minus, dan minus membatasi aksi (tidak bisa beli kendaraan,
  tidak bisa urus izin usaha) sampai dilunasi.

---

## 5.8 `job` — legal job yang langsung bisa dimulai

| Job | Prasyarat | Loop inti | Risiko |
|---|---|---|---|
| Kurir paket | Tidak ada | Ambil paket → antar 3 titik → bayaran per paket | Waktu, kendaraan rusak |
| Ojek | SIM C | Antar penumpang NPC/pemain | Kecelakaan lalu lintas |
| Sopir truk | SIM B2 | Trailer + rute + muatan | Kerusakan muatan, denda overload |
| Nelayan | Tidak ada | Pergi ke dermaga → jaring → jual ikan | Cuaca |
| Petani | Tidak ada | Tanam → tunggu → panen → jual | Waktu, harga pasar |
| Mekanik | Sertifikat bengkel | Servis kendaraan pemain | Reputasi |

Semua job: bisa dimulai dalam 60 detik, ada instruksi `/job mulai`, dan ada progres
yang tersimpan kalau pemain disconnect.

---

## 5.9 `medical` — mati tidak sama dengan respawn

```pawn
// alur kematian
OnPlayerDeath → Medical_SetInjured(playerid, cause, killerCharacterId)
  PHASE_INJURED
  → animasi terluka, timer bleedout (default 8 menit IC)
  → EMS bisa /cpr (memperlambat) dan /revive (menyelamatkan)
  → bleedout habis → /pk di rumah sakit, biaya RS, item hilang sebagian
```

- Pemain tidak bisa chat IC saat `INJURED`, hanya `/do` lemah dan `/b` (OOC).
- PK (Player Kill) = lupa kejadian terakhir, bukan hapus karakter.
- CK (Character Kill) = hapus karakter, wajib disetujui admin + tercatat di `admin_audit`.

---

## 5.10 `chat` dan `action`

| Channel | Perintah | Siapa yang lihat | Jarak |
|---|---|---|---|
| Bicara | `/s` (shout) | sekitar | 20 m |
| Normal | ketik langsung | sekitar | 8 m |
| Whisper | `/w` | sekitar | 2 m |
| OOC | `/b` | sekitar | 8 m |
| Faksi | `/r` | anggota faksi | global |
| Pemerintah | `/gov` | SAGOV + PD | global |
| Iklan | `/ad` | semua | global, berbayar |
| PM | `/pm` | target | global |

- `/me` dan `/do` wajib punya validasi: tidak boleh kosong, maksimal 100 karakter,
  dan anti-spam (1 aksi per 2 detik).
- Setiap teks keluar lewat `Messages_Format()`, tidak ada string literal di logika.

---

## 5.11 `admin`

Level: `1 Helper`, `2 Moderator`, `3 Administrator`, `4 Developer`, `5 Owner`.

- Setiap aksi admin → `admin_audit` (termasuk alasan wajib).
- `GIVE_MONEY` mengisi `actor_character_id` di `money_log`, jadi pencetakan uang
  selalu terlacak. Ini bukan kemewahan: tanpa ini, ekonomi server tidak bisa dipercaya.
- Sanksi: warn (dengan poin akumulatif), mute, jail IC, ban akun, ban IP.
- `/admins` menampilkan admin online — transparansi untuk pemain.
