# 19 — Arena Latihan Tembak

Tempat latihan tembak adalah **uang keluar yang menyenangkan**: pemain membayar
per sesi, mendapat skor, dan tidak ada cara mengubahnya menjadi penghasilan.
Skor hanya untuk gengsi lewat `/rekor`.

## 1. Arena

Arena dibangun dari objek, bukan mapping manual:

| Bagian | Model | Catatan |
|---|---|---|
| Lantai | 19379 (panel, `rx = 90`) | 2 panel = 9,64 x 21 m |
| Dinding | 19377 (panel) | 2,6 m di atas lantai, 2 segmen per sisi |
| Sasaran | 1224 (peti) | 2 peti bertumpuk per sasaran |
| Meja penembak | 2164 | penanda garis tembak |

Posisi origin `(2600.0, 500.0, 300.0)` — **di atas peta** dengan `VirtualWorld 900`:

- Tidak bergantung pada terrain, jadi arena tidak pernah miring atau terpotong bukit.
- Pemain di dunia normal tidak melihat arena, tidak bisa ikut menembak, dan tidak
  bisa memancing orang masuk.
- Karena memakai `VirtualWorld`, sesi banyak pemain bisa berjalan bersamaan tanpa
  saling menghalangi.

Kamera, cuaca, dan waktu tidak diubah supaya pemain tetap melihat HUD normal.

## 2. Sesi

| Mode | Senjata | Peluru | Harga |
|---|---|---|---|
| Pistol 9mm | `WEAPON_COLT45` | 48 | Rp 2.500 |
| Shotgun | `WEAPON_SHOTGUN` | 24 | Rp 4.000 |
| Rifle | `WEAPON_RIFLE` | 20 | Rp 6.000 |

- Durasi 90 detik, dihitung dari `gettime()` server (bukan timer klien).
- Sesi berakhir saat waktu habis, peluru habis, pemain memanggil
  `/latihanselesai`, keluar arena, tewas, atau putus koneksi.
- **Senjata selalu dicabut** saat sesi berakhir. Amunisi senjata sesi dinolkan
  (bukan `ResetPlayerWeapons`) agar tidak menghapus senjata sah lain — meski saat
  ini belum ada sumber senjata lain di server.
- Posisi, dunia, dan interior pemain sebelum sesi disimpan dan dikembalikan
  persis, termasuk sudut hadap dan kamera.

## 3. Skor

| Sasaran | Jarak | Poin dasar |
|---|---|---|
| Dekat | 6 m | 10 |
| Sedang | 11 m | 20 |
| Jauh | 16 m | 30 |

Poin akhir = poin sasaran x pengali senjata (pistol 1, shotgun 2, rifle 3).
Senjata mahal memberi pengali lebih besar, jadi biaya sesi sebanding dengan
potensi skor.

**Akurasi dihitung dari semua peluru**, hit hanya bila posisi peluru masuk kotak
sasaran: `|dx| ≤ 1,7 m`, `0 ≤ dz ≤ 1,6 m`, `|dy| ≤ 1,7 m`. Verifikasi terjadi di
`OnPlayerWeaponShot`, yaitu posisi peluru yang dikirim server, bukan klien.

## 4. Anti-cara-curang

| Celah | Penangkal |
|---|---|
| Tembak sasaran dari luar arena | Sesi hanya dihitung bila `VirtualWorld == 900` dan senjata = senjata sesi |
| Teleport keluar untuk kabur | Tick 1 detik mengakhiri sesi bila jarak > 25 m atau `z` melenceng |
| Ulang sesi tanpa bayar | Uang diambil lewat `Money_Take` sebelum teleport; gagal bayar = sesi tidak dimulai |
| Farming skor untuk uang | Tidak ada hadiah uang sama sekali, hanya rekor |
| Rekor turun karena sesi buruk | `MAX(best_score, excluded.best_score)` di UPSERT |

## 5. Perintah

| Perintah | Keterangan |
|---|---|
| `/latihan` | buka pilihan mode (butuh dekat lokasi `LATIHAN`, atau sedang sesi) |
| `/latihanselesai` | akhiri sesi lebih awal, skor tetap disimpan |
| `/rekor` | papan rekor 5 teratas |
| `/buatlatihan [nama]` | admin moderator, memasang lokasi latihan di posisi sendiri |

Prompt `[Y]` di lokasi `LATIHAN` langsung membuka dialog yang sama dengan
`/latihan`, jadi pemain HP tidak perlu mengetik.

## 6. Tabel

`range_scores` — satu baris per karakter:

```
character_id PRIMARY KEY, best_score, best_hits, sessions, updated_at
```

Rekor hanya ditulis saat sesi **berakhir**, bukan per tembakan, sehingga tidak ada
tulis DB per peluru.

## 7. Ide lanjutan (belum dikerjakan)

1. **Mode waktu**: skor maksimal dalam 30 detik, peluru tak terbatas — menguji
   kecepatan, bukan ketelitian.
2. **Sasaran bergerak**: peti dipindah dengan `MoveObject` tiap 2 detik; pusat
   sasaran harus ikut diperbarui agar hitbox tetap jujur.
3. **Duel PvP** memakai arena yang sama dengan `VirtualWorld` berbeda per
   pertandingan (pola *Duel & Matchmaking Arena* di
   `.agents/skills/samp-roleplay-systems-bible/SKILL.md`), lengkap dengan
   `SetPlayerTeam` dan pencabutan senjata saat keluar.
4. **Hadiah non-uang**: akses lisensi senjata (kalau nanti ada fraksi PD),
   sehingga skor latihan jadi syarat, bukan penghasilan.
