# 07 — Roadmap dan gate verifikasi

Setiap fase punya **gate** yang harus lulus sebelum fase berikutnya dimulai. Gate di
sini adalah perintah nyata dengan exit code, bukan penilaian subjektif.

---

## Fase 0 — Fondasi (target: 1–2 hari)

Buat: `pawn.json`, `config.json`, `.github/workflows/build.yml`, `gamemode.pwn`,
`src/core/*` (settings, log, db, timer, telemetry).

**Gate**
```bash
sampctl package ensure
sampctl package build        # exit 0, gamemodes/main.amx terbentuk
sampctl package run          # server naik, log "[boot] siap", DB terhubung
```

---

## Fase 1 — Akun, karakter, sesi (3–5 hari)

`auth`, `character`, `shared/player_phase`, `shared/client_tier`, `chat` dasar.

**Gate**
- Daftar → login → buat karakter → spawn → disconnect → login lagi: data utuh.
- Restart server di tengah sesi: karakter tidak kembali ke nilai awal.
- 3 percobaan login salah → cooldown aktif.
- Test manual: dua akun berbeda IP, sesi tidak tercampur.

---

## Fase 2 — Identitas dan uang (4–6 hari)

`identity` (KTP/SIM/STNK/plat), `shared/money`, `economy/salary`, `economy/atm`.

**Gate**
- `/ktp buat` → nomor KTP terbit, tercatat di `identity_docs`.
- `/sim urus` tanpa KTP → ditolak dengan pesan jelas, bukan diam.
- `/mdc cek plat "B 1234 XYZ"` mengembalikan pemilik + status STNK.
- Semua mutasi uang menghasilkan baris `money_log` dengan `reason` yang benar.
- `/economy` menampilkan rasio faucet:sink.

---

## Fase 3 — Kendaraan (4–6 hari)

`vehicle` + `plate` + bahan bakar + odometer + impound.

**Gate**
- Beli kendaraan → plat terbit otomatis → STNK punya `expires_at`.
- BBM habis → mesin mati, tidak bisa start.
- Ditilang berat → `is_impounded = 1`, tidak bisa spawn sebelum tebus.
- Relog: posisi, BBM, odometer, plate tetap.

---

## Fase 4 — Properti dan bisnis (5–7 hari)

`property`, `business`, `interior`, pajak properti.

**Gate**
- Beli rumah → bisa masuk/keluar, spawn di dalam tersimpan.
- Tidak bayar pajak 14 hari → status tersita muncul di `/property` milik SAGOV.
- Warung: stok habis → penjualan ditolak; order stok → stok kembali setelah lead time.

---

## Fase 5 — Faksi dan MDC (5–7 hari)

`faction`, `faction_ranks`, `mdc`, `warrants`.

**Gate**
- Rekrut anggota → pangkat default sesuai `faction_ranks.rank_index = 0`.
- `PERM_MDC` hanya berlaku untuk pangkat yang punya bit tersebut.
- Warrant bisa dibuat, dicari, dan dicabut; semua tercatat.
- Gaji faksi terbayar mingguan ke `money_log` dengan `reason = SALARY_FACTION`.

---

## Fase 6 — Medis (3–4 hari)

`medical/injury`, `medical/hospital`, animasi, bleedout, PK/CK.

**Gate**
- Mati → `PHASE_INJURED`, tidak bisa spawn sendiri.
- EMS `/revive` menyelamatkan; bleedout habis → rumah sakit + biaya.
- CK hanya bisa lewat admin, dan menghasilkan baris `admin_audit` + karakter ter-soft-delete.

---

## Fase 7 — Job dan ekonomi lanjutan (5–7 hari)

`job_*` (kurir, ojek, truk, nelayan, petani), `economy/tax`.

**Gate**
- Tiap job bisa dimulai < 60 detik oleh pemain baru tanpa bantuan admin.
- Job tersimpan kalau pemain disconnect (bisa dilanjut, bukan hangus).
- Rasio faucet:sink tetap 1.3–1.6 setelah 24 jam simulasi.

---

## Fase 8 — Admin, audit, anti-cheat (4–5 hari)

`admin`, `audit`, `sanction`, anti-cheat ringan di `core/telemetry`.

**Gate**
- Setiap command admin menulis `admin_audit` dengan alasan wajib.
- `/admin give` tercatat lengkap dengan `actor_character_id` di `money_log`.
- Anti-cheat menangkap simulasi teleport > 500 m dalam 1 detik (test dengan client palsu).
- Tidak ada query DB di `OnPlayerUpdate` (dicek CI).

---

## Fase 9 — Hardening dan rilis (5–7 hari)

- Load test 200 koneksi (bot open.mp bawaan) selama 1 jam.
- Audit budget objek, tick time, memori AMX.
- Uji ulang dengan **client 0.3.7** dan **0.3.DL** untuk semua alur inti.
- Dokumentasi pemain: `/help`, panduan SIM, panduan pajak.

**Gate rilis**
```bash
sampctl package build
# 200 bot 60 menit: tick ≤ 0.4 ms, memori AMX stabil, 0 crash
# 0.3.7 client: login→kerja→beli kendaraan→tilang→urus SIM tanpa error model
# 0.3.DL client : alur sama + model kustom tampil
```

---

## Ringkasan urutan dependensi

```
F0 fondasi
 └─ F1 akun/karakter
     ├─ F2 identitas+uang  ─┬─ F3 kendaraan ─┐
     │                      └─ F4 properti/bisnis ─┤
     ├─ F5 faksi+MDC ────────┴──────────────────┬─┘
     ├─ F6 medis ───────────────────────────────┤
     └─ F7 job ─────────────────────────────────┴─ F8 admin/audit ─ F9 rilis
```

F2 wajib sebelum F3/F4 (uang dan identitas adalah fondasi kepemilikan).
F5 dan F6 bisa paralel. F7 bisa mulai setelah F2.

## Estimasi total

± 6–8 minggu kalender untuk satu orang yang bekerja fokus, atau ± 3 minggu dengan dua
orang (satu core+backend data, satu domain gameplay+UI).
