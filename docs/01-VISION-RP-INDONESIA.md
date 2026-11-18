# 01 — Visi: Roleplay Indonesia yang serius tapi tidak kaku

## 1. Posisi produk

Bukan "server RP nomor 1001 dengan fitur sama". Pembeda yang kita kejar:

> Server RP Indonesia pertama yang **terasa lokal** (surat kendaraan, tilang, warung,
> ojek, pajak, birokrasi faksi) dan **terasa adil** (ekonomi bisa diaudit, tidak ada
> admin yang bisa mencetak uang tanpa jejak).

Dua klaim itu harus bisa dibuktikan lewat kode, bukan tagline:

- **Lokal** → domain `identity` memperlakukan SIM/STNK/KTP sebagai objek kelas satu,
  bukan `bool:punyaSIM`.
- **Adil** → tabel `money_log` append-only. Setiap rupiah yang masuk/keluar punya
  `reason`, `actor_character_id`, dan timestamp. `/admin give money` tercatat sebagai
  transaksi yang bisa ditelusuri, bukan baris hilang di log chat.

## 2. Pemain target

| Segmen | Porsi realistis | Butuh apa dari server |
|---|---|---|
| Roleplayer pemula (12–17) | 45% | Onboarding cepat, bahasa Indonesia, UI jelas, tidak dipecat bug |
| Roleplayer menengah | 35% | Progresi karakter, pekerjaan bervariasi, properti/bisnis |
| Roleplayer senior / pindahan | 15% | Kokoh secara mekanik, admin responsif, faksi berjenjang |
| Non-RP (mampir) | 5% | Tetap bisa main legal job tanpa dipaksa RP berat |

Konsekuensi desain: **tidak boleh ada mekanik yang butuh 20 menit untuk dipahami**
tanpa tutorial in-game. Sistem kompleks wajib punya jalur "cepat" (`/mdc` sederhana
untuk PD baru, detail penuh untuk yang mau).

## 3. Sepuluh prinsip desain (mengikat, bukan saran)

1. **Karakter, bukan akun.** Satu akun maksimal 3 karakter. Semua gameplay melekat
   ke `character_id`, akun hanya untuk login dan admin flag.
2. **Kematian bukan tombol respawn.** Mati → `INJURED` → dirawat EMS atau habis waktu
   → rumah sakit + biaya. Ini yang membedakan RP dari DM.
3. **Surat itu nyata.** SIM punya golongan (A, B1, B2, C), STNK punya masa berlaku,
   plat nomor bisa diverifikasi. Polisi menilang berdasarkan data, bukan tebak-tebakan.
4. **Ekonomi punya sink.** Setiap faucet (gaji, job, rampasan) punya sink pasangannya
   (pajak, bahan bakar, sewa, denda, biaya RS). Rasio faucet:sink dijaga di 1.3–1.6.
5. **Uang tidak pernah ditulis dua tempat.** Lihat `shared/money`.
6. **Admin tidak punya kekuatan tanpa arsip.** Setiap tindakan admin menghasilkan baris
   di `admin_audit`.
7. **Legal job selalu tersedia.** Pemain tanpa faksi wajib punya minimal 3 pekerjaan
   legal yang bisa dimulai dalam 60 detik.
8. **Progresif, bukan pay-to-win.** Tidak ada item yang hanya bisa dibeli uang nyata.
9. **Bahasa Indonesia IC, Inggris/kode OOC.** Semua teks pemain lewat katalog pesan,
   tidak ada string mentah di tengah logika.
10. **Ramah client lama.** Tidak ada mekanik inti yang bergantung pada model kustom
    (lihat `02-DUAL-CLIENT-COMPAT`).

## 4. Budaya RP yang kita dukung (dan tolak)

**Didukung**
- `/me` `/do` `/try` — aksi dan narasi lingkungan.
- Fear RP (tidak menantang senjata api dengan tangan kosong).
- CK (Character Kill) terdaftar dan disetujui admin, tidak bisa dilakukan pemain sendiri.
- Birokrasi ringan: urus SIM di kantor, bayar pajak tahunan, urus izin bisnis.

**Ditolak sebagai mekanik**
- Sistem "level" gaya MMO yang membuat pemain senior kebal peluru.
- Item langka yang dijual lewat donasi.
- Force-RP yang memaksa pemain baru masuk adegan tanpa penjelasan.
- Rumus damager Rp yang tidak bisa dijelaskan ke pemain.

## 5. Definisi "selesai" untuk versi 1.0

Rilis dianggap layak kalau semua ini benar sekaligus:

- 200 pemain bersamaan tanpa frame drop di `OnPlayerUpdate` (budget < 0.4 ms/tick).
- Pemain bisa: daftar → buat karakter → kerja → beli kendaraan → urus STNK →
  ditilang → urus SIM → beli rumah → bayar pajak, tanpa admin menyentuh apa pun.
- Restart server tidak menghilangkan progres: semua state tersimpan, tidak ada
  karakter yang balik ke awal.
- Client 0.3.7 dan 0.3.DL bisa bermain di server yang sama tanpa error model.
- `money_log` bisa menjawab: "kenapa uang pemain ini naik 5 juta dalam 1 jam?"
