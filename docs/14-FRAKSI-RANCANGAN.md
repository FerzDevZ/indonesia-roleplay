# 14 — RANCANGAN FRAKSI (desain lengkap)

Status: **rancangan**, belum ada kode. Acuan gaya: GTA5 RP (PD/EMS/gang) dengan
nuansa Indonesia. Fokus implementasi: **fraksi lebih dulu**, fitur lain menyusul.

## 1. Prinsip desain

1. **Satu sumber kebenaran**: roster fraksi ada di `faction_members`. Kolom
   `characters.faction_id/faction_rank` hanya cermin cepat untuk HUD, selalu
   ditulis ulang saat roster berubah.
2. **Semua hak akses dicek di server** berdasarkan pangkat (bukan UI). UI hanya
   menampilkan apa yang boleh dilakukan.
3. **Semua uang lewat `shared/money.pwn`**; kas fraksi lewat `Faction_AddKas()`
   (pola sama dengan kas properti) dengan alasan transaksi tercatat.
4. **Semua aksi sensitif masuk log** (`faction_logs`): rekrut, pecat, promosi,
   penangkapan, tilang, ambil senjata, tarik kas.
5. **Tidak ada UI baru di callback pickup** (invariant deferred activation):
   interaksi lewat prompt `[Y]` → modul fraksi.
6. File ≤ 400 baris (gate). Fraksi dipecah 10 file sejak awal.

## 2. Set fraksi (tahap akhir)

| Kode | Nama | Jenis | Inti mekanik |
|---|---|---|---|
| `PD` | Kepolisian | LEGAL | Patroli, tilang, tangkap, tahanan, wanted, sita barang |
| `EMS` | Dinas Kesehatan | LEGAL | Revive, ambulans, rawat inap di RS, surat sehat |
| `PEMKOT` | Pemerintah Kota | GOV | Pajak, izin usaha, lelang, kas daerah |
| `MEKANIK` | Serikat Mekanik | LEGAL | Bengkel, derek, perbaikan kendaraan |
| `GANG_*` | Geng Jalanan | ILLEGAL | Wilayah, bisnis ilegal, konflik dengan PD |
| `MEDIA` | Wartawan | MEDIA | Rilis berita, wawancara (opsional, flavor) |

Tiap fraksi punya **6 pangkat** dengan izin berbeda (contoh PD):

| Lv | Pangkat | Izin |
|---|---|---|
| 1 | Bhayangkara | duty, radio, locker dasar |
| 2 | Brigadir | + tilang, MDT cari nama |
| 3 | Inspektur | + tangkap, sita barang |
| 4 | Ajun Komisaris | + buat wanted, buka sel |
| 5 | Komisaris | + rekrut/pecat, tarik kas |
| 6 | Kapolda | + promosi, atur pangkat, armory penuh |

## 3. Data model (SQLite, dibuat di `Faction_Boot()`)

```sql
CREATE TABLE IF NOT EXISTS factions (
  faction_id   INTEGER PRIMARY KEY AUTOINCREMENT,
  code         TEXT NOT NULL UNIQUE,
  name         TEXT NOT NULL,
  kind         TEXT NOT NULL,           -- LEGAL | ILLEGAL | GOV | MEDIA
  hq_x REAL, hq_y REAL, hq_z REAL, hq_angle REAL, hq_interior INTEGER DEFAULT 0,
  kas          INTEGER NOT NULL DEFAULT 0,
  max_members  INTEGER NOT NULL DEFAULT 20,
  is_active    INTEGER NOT NULL DEFAULT 1);

CREATE TABLE IF NOT EXISTS faction_ranks (
  rank_id INTEGER PRIMARY KEY AUTOINCREMENT,
  faction_id INTEGER NOT NULL, level INTEGER NOT NULL, title TEXT NOT NULL,
  salary INTEGER NOT NULL DEFAULT 0,
  can_invite INTEGER DEFAULT 0, can_fire INTEGER DEFAULT 0,
  can_promote INTEGER DEFAULT 0, can_armory INTEGER DEFAULT 0,
  can_withdraw INTEGER DEFAULT 0, can_mdt INTEGER DEFAULT 0,
  can_arrest INTEGER DEFAULT 0, can_wanted INTEGER DEFAULT 0,
  UNIQUE(faction_id, level));

CREATE TABLE IF NOT EXISTS faction_members (
  member_id INTEGER PRIMARY KEY AUTOINCREMENT,
  faction_id INTEGER NOT NULL,
  character_id INTEGER NOT NULL UNIQUE,
  rank_level INTEGER NOT NULL DEFAULT 1,
  duty INTEGER NOT NULL DEFAULT 0,
  minutes_duty INTEGER NOT NULL DEFAULT 0,
  joined_at INTEGER NOT NULL, last_seen_at INTEGER NOT NULL);

CREATE TABLE IF NOT EXISTS faction_logs (
  log_id INTEGER PRIMARY KEY AUTOINCREMENT,
  faction_id INTEGER NOT NULL, actor_character INTEGER DEFAULT NULL,
  target_character INTEGER DEFAULT NULL,
  action TEXT NOT NULL, detail TEXT, created_at INTEGER NOT NULL);

CREATE TABLE IF NOT EXISTS wanted_records (
  wanted_id INTEGER PRIMARY KEY AUTOINCREMENT,
  character_id INTEGER NOT NULL, reason TEXT NOT NULL,
  level INTEGER NOT NULL DEFAULT 1, fine INTEGER NOT NULL DEFAULT 0,
  issued_by INTEGER NOT NULL, issued_at INTEGER NOT NULL,
  cleared_by INTEGER DEFAULT NULL, cleared_at INTEGER DEFAULT NULL);

CREATE TABLE IF NOT EXISTS jail_records (
  jail_id INTEGER PRIMARY KEY AUTOINCREMENT,
  character_id INTEGER NOT NULL, seconds INTEGER NOT NULL, reason TEXT,
  officer_character INTEGER DEFAULT NULL,
  started_at INTEGER NOT NULL, released_at INTEGER DEFAULT NULL);
```

Seed: 3 fraksi awal (`PD`, `EMS`, `PEMKOT`) + pangkat 1..6 + HQ di titik peta.
Seed pakai `INSERT OR IGNORE` (pola warung/properti).

## 4. Struktur modul

| File | Isi | Perkiraan |
|---|---|---|
| `src/domain/faction/faction.pwn` | boot, seed, cache fraksi+roster, API kas, izin pangkat | 320 |
| `src/domain/faction/faction_duty.pwn` | `/dinas`, tick gaji, HUD badge, statistik jam dinas | 180 |
| `src/domain/faction/faction_roster.pwn` | rekrut, terima/tolak, pecat, promosi, cek izin | 200 |
| `src/domain/faction/faction_lockers.pwn` | locker seragam & armory (senjata, rompi, radio) | 220 |
| `src/domain/faction/faction_admin.pwn` | `/buatfraksi`, `/setpangkat`, `/kasfraksi`, `/hq` | 200 |
| `src/domain/police/wanted.pwn` | daftar buron, level, denda, pembersihan | 180 |
| `src/domain/police/arrest.pwn` | `/tangkap`, sita barang, bawa ke sel | 200 |
| `src/domain/police/jail.pwn` | tahanan, timer, jaminan, bebas, anti-escape | 220 |
| `src/domain/ems/ems.pwn` | downed state, `/revive`, ambulans, rawat inap | 220 |
| `src/ui/mdtui.pwn` | panel MDT (FiveM style) + navigasi halaman | 300 |
| `src/ui/mdtui_draw.pwn` | gambar panel, baris klik, tombol aksi | 320 |

Interior sel tahanan: blueprint baru (Blueprint 3/4) memakai aturan
`docs/13-MAPPING-INTERIOR.md`, tinggi ruangan 2.6 m, pintu keluar = pickup
`[KELUAR]` di dalam.

## 5. Alur pemain (yang harus mulus di HP)

### 5.1 Masuk fraksi
1. Leader `/rekrut <id>` → target dapat dialog konfirmasi (2 tombol besar).
2. Terima → masuk pangkat 1, `Faction_Log("RECRUIT")`, HUD nama fraksi muncul.
3. Tolak / 60 detik tanpa jawaban → undangan hangus (tidak menggantung).

### 5.2 Dinas (duty)
1. Di HQ, prompt `[Y] Mulai Dinas` (bukan otomatis).
2. Duty aktif → badge `DINAS` di HUD, akses locker/armory, gaji berjalan.
3. Gaji: **Rp 500 per menit dinas aktif**, hanya dihitung kalau pemain bergerak
   atau melakukan aksi (anti-AFK), dibayar per 5 menit ke rekening, dicatat
   `GAJI` dengan aktor = karakter pemain.
4. `/dinas` lagi → selesai; rekap "Dinas 1j 20m, gaji Rp 40.000".

### 5.3 PD: tilang & tangkap
1. Prompt `[Y]` pada pemain terdekat → menu aksi (Tilang / Tangkap / Cek ID).
2. Tilang memakai `Tilang_Issue()` yang sudah ada (denda masuk kas daerah/kas PD
   sesuai konfigurasi) + catatan `faction_logs`.
3. Tangkap: butuh pangkat ≥ 3 dan target tidak di dalam kendaraan cepat;
   target dipindah ke sel (teleport deferred 500 ms), timer mulai.
4. Tahanan: HUD besar sisa waktu + alasan; `/jaminan` untuk bayar; bebas
   otomatis saat habis. Kabur (keluar area sel) → wanted level +1.

### 5.4 EMS: revive
1. Target HP 0 → state `PHASE_DOWNED` (tidak bisa chat IC, bisa `/teriak`).
2. EMS dengan pangkat ≥ 2 mendekat, prompt `[Y] Revive` → HP 40, biaya
   ditanggung pasien (masuk kas EMS) atau gratis bila dinas.
3. Pasien mati total (30 detik tanpa revive) → rumah sakit, biaya Rp 25.000.

### 5.5 MDT (panel, bukan dialog)
- Halaman: `WARGA` (cari nama/ID) · `KENDARAAN` (plat → pemilik, STNK) ·
  `BURON` (wanted aktif) · `LAPORAN` (riwayat aksi).
- Baris bisa diklik; tombol aksi hanya muncul kalau pangkat mengizinkan
  (`can_mdt`, `can_arrest`, `can_wanted`).
- Tutup lewat `[X]`; satu pemain satu modal (`UI_MDT = 15`).
- Data kendaraan menyusul saat modul kendaraan ada; halaman menampilkan
  "belum tersedia" sampai itu selesai (jangan bikin data palsu).

### 5.6 Gang (fase akhir)
1. Wilayah = poligon (4–8 titik) per gang, warna di radar (`GangZone`).
2. Penghasilan wilayah tiap 10 menit masuk kas gang, hanya bila ada anggota
   online di area (anti-bot).
3. Aksi ilegal: rampok toko (butuh properti), jual barang selundupan.
4. PD bisa menyita barang bukti → log + kas PD.

## 6. Perintah (semua wajib punya contoh, sesuai aturan proyek)

| Perintah | Siapa | Contoh |
|---|---|---|
| `/fraksi` | anggota | `/fraksi` → daftar anggota + pangkat |
| `/dinas` | anggota | `/dinas` → mulai/selesai dinas |
| `/r <pesan>` | anggota | `/r Posisi di Jefferson, minta backup` |
| `/rekrut <id>` | leader | `/rekrut 12` |
| `/pecat <id>` | leader | `/pecat 12` |
| `/promosi <id>` | leader | `/promosi 12` |
| `/kasfraksi` | leader | `/kasfraksi` → saldo + 10 transaksi terakhir |
| `/tarikkas <jumlah>` | leader | `/tarikkas 5000` |
| `/locker` | anggota | `/locker` → seragam sesuai pangkat |
| `/armory` | pangkat ≥ 3 | `/armory` → senjata + amunisi |
| `/mdt` | PD/EMS | `/mdt` → buka panel |
| `/tilang <id> <jumlah>` | PD ≥ 2 | `/tilang 5 25000` |
| `/tangkap <id> <alasan>` | PD ≥ 3 | `/tangkap 5 Merampok toko` |
| `/wanted <id> <level> <alasan>` | PD ≥ 4 | `/wanted 5 2 Melawan petugas` |
| `/jaminan` | tahanan | `/jaminan` → bayar & bebas |
| `/revive` | EMS ≥ 2 | `/revive` (target terdekat) |
| `/buatfraksi <kode> <nama> <jenis>` | admin | `/buatfraksi GANG_JS Geng Jaya Sakti ILLEGAL` |
| `/setpangkat <luar> <id> <level>` | admin | `/setpangkat PD 12 4` |
| `/kasfraksi <kode> set <jumlah>` | admin | `/kasfraksi PD set 100000` |

## 7. Tahapan implementasi

### F1 — Fondasi fraksi (tanpa UI besar)
- Tabel + seed + cache; `/fraksi`, `/dinas` + gaji, `/rekrut /pecat /promosi`,
  HUD badge, `faction_logs`.
- **Selesai bila**: rekrut → duty → gaji masuk rekening → rekap; promosi
  mengubah izin; semua aksi muncul di log; build + gates LULUS.

### F2 — Polisi (inti permainan)
- `wanted.pwn`, `arrest.pwn`, `jail.pwn`, Blueprint 3 (sel), HUD tahanan.
- **Selesai bila**: tilang tercatat, tangkap → sel → timer → bebas, kabur →
  wanted, denda masuk kas, tidak ada jalan keluar sel selain pintu resmi.

### F3 — MDT
- `mdtui.pwn` + draw, halaman WARGA/BURON/LAPORAN, izin per pangkat.
- **Selesai bila**: buka/tutup di HP tanpa freeze, tidak ada baris yang bisa
  diklik tanpa izin, satu modal per pemain.

### F4 — EMS + PEMKOT
- Downed state, revive, biaya, rawat inap; izin usaha + pajak dasar.
- **Selesai bila**: pasien tidak bisa bergerak sendiri, revive memulihkan,
  biaya masuk kas fraksi, pajak mengurangi kas properti secara tercatat.

### F5 — Gang & wilayah (paling akhir, butuh properti + kendaraan)
- Zona, penghasilan, penyitaan, konflik.
- **Selesai bila**: penghasilan hanya saat anggota online di area; sita
  barang bukti masuk log; tidak ada uang tercipta tanpa sumber.

### F6 — Mekanik, MEDIA, polish
- Bengkel/derek (butuh modul kendaraan), radio panel, statistik fraksi.

## 8. Anti-abuse (wajib, bukan opsional)

1. Gaji dinas butuh aktivitas: minimal 30 m perjalanan atau 1 aksi per 5 menit.
2. Tarik kas hanya pangkat tertinggi, maksimal 50% kas per 24 jam, tercatat.
3. Setiap senjata dari armory mengurangi kas fraksi; senjata hilang saat
   keluar/mati tidak dikembalikan dana.
4. Tahanan tidak bisa teleport/keluar sel; semua pintu sel adalah marker resmi.
5. Denda dan jaminan hanya masuk lewat `Money_Take`/`Money_Add` (tidak ada
   `UPDATE characters SET cash` langsung).
6. Wanted level 3+ membuat PD bisa masuk area gang tanpa peringatan (catat log).

## 9. Risiko teknis & jawabannya

| Risiko | Jawaban |
|---|---|
| Pool textdraw MDT habis di HP | maksimal 40 textdraw panel, daftar 6 baris + scroll halaman |
| File membengkak > 400 baris | sudah dipecah 11 file; UI dipisah `_draw` |
| Ketergantungan modul kendaraan | MDT halaman kendaraan & bengkel ditunda sampai modul itu ada |
| Simulasi "downed" mengganggu login | state baru hanya dipakai setelah karakter aktif; reset saat spawn |
| Konflik pemanggilan `Phase_CanAct` | tambah `PHASE_DOWNED` tanpa mengubah nilai lama |
| Gaji jadi sumber uang liar | batas waktu, aktivitas wajib, kas fraksi harus punya pemasukan |

## 10. Urutan kerja yang disarankan (setelah kendaraan)

Kendaraan + STNK → **F1 Fondasi fraksi** → **F2 Polisi** → **F3 MDT** →
**F4 EMS/PEMKOT** → F5 Gang → F6 sisanya.

Alasan: F2 butuh STNK untuk cek kendaraan; F1 tidak butuh apa pun selain
sistem uang yang sudah ada, jadi bisa dikerjakan paralel kalau kendaraan
tertunda.
