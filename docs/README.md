# Blueprint: Roleplay Indonesia di open.mp (dual-client)

Dokumen ini adalah rancangan lengkap sebelum satu baris kode ditulis. Urutan baca
penting karena dokumen berikutnya bergantung pada keputusan di atasnya.

| # | Dokumen | Isi | Baca kalau |
|---|---|---|---|
| 01 | [VISION-RP-INDONESIA](01-VISION-RP-INDONESIA.md) | Posisi produk, pemain target, 10 prinsip desain yang tidak boleh dilanggar | Mau tahu "ini server RP seperti apa" |
| 02 | [DUAL-CLIENT-COMPAT](02-DUAL-CLIENT-COMPAT.md) | Matriks open.mp + client 0.3.7/0.3.DL, capability tier, budget objek | Mau ubah apa pun yang berhubungan model/skin/artwork |
| 03 | [ARCHITECTURE](03-ARCHITECTURE.md) | Layering, struktur folder, kontrak modul, urutan boot, gate CI | Menambah modul atau file baru |
| 04 | [DATA-MODEL](04-DATA-MODEL.md) | Skema MySQL, tabel, indeks, aturan migrasi | Menyentuh query atau kolom |
| 05 | [MODULES-RP](05-MODULES-RP.md) | Spesifikasi tiap domain: auth, identitas, kendaraan, properti, faksi, medis, chat | Mengerjakan fitur gameplay |
| 06 | [ECONOMY-RUPIAH](06-ECONOMY-RUPIAH.md) | Skala Rupiah, faucet/sink, gaji, harga, pajak | Menyentuh angka uang |
| 07 | [ROADMAP](07-ROADMAP.md) | 9 fase, gate verifikasi per fase | Mulai implementasi |
| 08 | [PAWN-STANDARDS](08-PAWN-STANDARDS.md) | Konvensi nama, guard clause, larangan, `static` sebagai pagar modul | Menulis Pawn |
| 09 | [RUN-AND-CONNECT](09-RUN-AND-CONNECT.md) | Cara start server, main dari HP/Android, LAN vs port forward vs VPS | Mau server ini diakses orang lain |
| 10 | [UI-UX-ROADMAP](10-UI-UX-ROADMAP.md) | Peta UI/UX: modal manager, HUD, katalog fitur P1-P5, ergonomi Android | Membangun UI baru |
| 13 | [Mapping Interior](13-MAPPING-INTERIOR.md) | aturan geometri blueprint interior |
| 14 | [Rancangan Fraksi](14-FRAKSI-RANCANGAN.md) | desain lengkap PD/EMS/PEMKOT/gang, data model, tahapan |
| 15 | [Kendaraan Rental](15-KENDARAAN-RENTAL.md) | rental dinamis: paket, lokasi, ephemeral pool | Menjual/menyewa kendaraan |
| 16 | [Kendaraan Pribadi](16-KENDARAAN-PRIBADI.md) | dealer, STNK, parkir, kepemilikan permanen | Kendaraan milik pemain |
| 17 | [Musik & Radio](17-MUSIK-RADIO.md) | radio in-game (audio nyata) + rencana hybrid Spotify | Fitur musik |
| 12 | [Rencana Powerful](12-RENCANA-POWERFUL.md) | roadmap fitur lanjutan |
| 11 | [ALUR-PLAYER](11-ALUR-PLAYER.md) | Alur pemain utuh: 15 menit pertama, 4 loop, tangga progresi, peta lokasi, urutan fase terkoreksi | Menentukan fase berikutnya |

## Artefak yang sudah ada di repo

- `pawn.json` — package sampctl preset `openmp`
- `config.json.example` — config server dengan `allow_037_clients` aktif
- `.github/workflows/build.yml` — CI compile + gate anti-slop otomatis
- `server/` — runtime open.mp 1.6.7.3218 + `qawno/` (pawncc & include) siap pakai
- `server/config.json`, `server/scriptfiles/settings.ini` — config aktif
- `scripts/build.sh` — compile nyata (warning dihitung gagal)
- `scripts/run.sh` — start server dengan cwd yang benar
- `scripts/gates.sh` — 9 gate lokal, termasuk compile
- `MEMORY.md` — post-mortem kegagalan yang sudah diheal + invariant-nya

## Tiga keputusan yang sudah dikunci

1. **Server tunggal.** open.mp 1.6.x, bukan dua deployment. Client lama masuk lewat
   `network.allow_037_clients`, jadi tidak ada codebase kedua untuk dipelihara.
2. **Modular per domain, bukan per folder kosmetik.** Batas modul dipaksa compiler
   lewat `static`, bukan sekadar konvensi nama file.
3. **Uang hanya ditulis oleh satu modul.** `shared/money` adalah satu-satunya penulis
   saldo, dan setiap mutasi masuk ke `money_log`.
