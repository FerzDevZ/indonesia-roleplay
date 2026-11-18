# 09 — Menjalankan Server & Main dari HP

Dokumen ini menjawab satu pertanyaan: *"gimana caranya orang lain main ke server ini dari HP?"*
Jawabannya jujur dulu, lalu langkah teknisnya.

---

## 1. Fakta yang harus diterima lebih dulu

| Klien | Platform | Bisa connect ke server ini? |
|---|---|---|
| SA-MP 0.3.7 (asli, R* / sa-mp.com) | Windows only | Ya — `network.allow_037_clients: true` |
| SA-MP 0.3.DL | Windows only | Ya — server yang sama |
| open.mp launcher | Windows only | Ya |
| Klien Android (launcher pihak ketiga) | Android | Ya, **tapi** bukan buatan R* / SA-MP team |

**Tidak ada klien SA-MP/open.mp resmi untuk Android.** Semua app "SA-MP Android" di Play Store
adalah launcher pihak ketiga yang mengimplementasi ulang protokol 0.3.7. Konsekuensinya:

- Mereka butuh **GTA: San Andreas versi Android yang asli** (beli di Play Store) sudah terpasang di HP.
- Kontrol (mouse/keyboard virtual) lebih buruk dari PC; RP berbasis chat tetap bisa, tapi memuaskan
  hanya untuk pemain yang biasa.
- Tidak ada jaminan update; kalau launcher-nya berhenti dikembangkan, pemain Android hilang.
- Server tidak perlu diubah sama sekali: server hanya melihat "client 0.3.7".

Rekomendasi realistis: **target utama tetap PC (0.3.7/0.3.DL/open.mp), Android sebagai bonus
akses**, dan jangan pernah membuat fitur yang hanya jalan di Android atau hanya di 0.3.DL.

---

## 2. Jalankan server

```bash
cd /home/boxd/project-samp
./scripts/build.sh      # compile gamemode -> server/gamemodes/rp-indonesia.amx
./scripts/start.sh      # start di background lewat supervisor (auto-restart)
./scripts/status.sh     # proses, port, isi database, query publik, log terakhir
./scripts/stop.sh       # berhenti rapi
./scripts/run.sh        # start di foreground (untuk lihat log langsung)
```

Operasional lain:

| Skrip | Fungsi |
|---|---|
| `scripts/backup.sh` | backup `rp.db` konsisten (sqlite backup API), simpan 14 terakhir di `backups/`; sudah dijadwalkan cron 04:17 |
| `scripts/promote-admin.sh <username> [level]` | jadikan akun admin (default level 5). Jalankan **setelah** akun register di server |
| `scripts/gates.sh` | 9 gate lokal termasuk compile |

Tanda server siap (di console):

```
[INFO] [boot] siap
[INFO] [boot] backend database: sqlite, server siap menerima pemain
Legacy Network started on port 7777
```

Data runtime ada di `server/scriptfiles/`:

| File | Isi |
|---|---|
| `rp.db` | SQLite: accounts, characters, money_log, identity_docs, plates, admin_audit |
| `server.log` | log modul |
| `settings.ini` | `log_level`, `debug`, `db_path` |

**Penting:** `fopen()` dan `DB_Open()` di open.mp di-sandbox ke `scriptfiles/`. Jangan pernah
menulis path absolut atau `"scriptfiles/..."` di kode Pawn.

---

## 3. Main dari HP di jaringan yang sama (LAN / WiFi)

1. Cari IP server:
   ```bash
   hostname -I
   ```
   Misal `192.168.1.10`.
2. Izinkan port di firewall mesin ini:
   ```bash
   sudo ufw allow 7777/udp
   ```
3. Di HP: buka launcher SA-MP Android → Add Server →
   - Host: `192.168.1.10`
   - Port: `7777`
4. HP dan server harus di WiFi yang sama. Kalau HP pakai data seluler, lanjut ke bagian 4.

Uji bahwa port UDP benar-benar terbuka (dari mesin lain, bukan dari server sendiri):

```bash
nc -zvu 192.168.1.10 7777      # "succeeded" = port terbuka
```

open.mp **tidak** menyediakan halaman web di port 7777; semuanya UDP. Jadi kalau client
menampilkan "Retrieving info..." terus, itu masalah UDP/firewall, bukan gamemode.

---

## 4. Main dari mana saja (internet)

Tiga pilihan, dari paling cepat ke paling benar:

### a. Port forward di router (paling murah)
- Router → Port Forwarding → UDP `7777` → IP LAN mesin server (`192.168.1.10`).
- Beri IP statis/DHCP reservation untuk mesin server, kalau tidak IP-nya berpindah.
- Cari IP publik: `curl -s ifconfig.me`. Pemain connect ke `IP_PUBLIK:7777`.
- Butuh IP publik asli. Kalau ISP memakai CGNAT (IP publik router ≠ hasil `ifconfig.me`),
  port forward tidak akan pernah jalan.

### b. VPS (paling stabil untuk server publik)
- VPS Linux kecil (1 vCPU / 1 GB) cukup untuk 50–100 pemain RP.
- Upload folder `server/` (tanpa `qawno/` kalau tidak perlu compile di sana), jalankan dengan
  systemd supaya auto-restart:
  ```ini
  [Unit]
  Description=Roleplay Indonesia
  After=network.target

  [Service]
  WorkingDirectory=/opt/rp/server
  ExecStart=/opt/rp/server/omp-server
  Restart=always
  User=rpserver

  [Install]
  WantedBy=multi-user.target
  ```
- Buka UDP 7777 di firewall VPS.

### c. Tunnel UDP (satu-satunya jalan kalau mesin di balik NAT/CGNAT)

Mesin ini ada di balik NAT: IP lokal `10.122.253.104`, IP keluar `185.209.179.229`,
dan **tidak ada inbound UDP 7777** (dibuktikan announce open.mp: `connection refused`
ke IP publik itu sendiri). Domain `sure-cove.nyc.boxd.sh` **tidak bisa dipakai** untuk
SA-MP: domain itu menunjuk ke `206.223.233.65` dan hanya melayani HTTP port 80
(nginx → `/var/www/codegames`). SA-MP murni UDP.

Yang dipakai: **playit.gg** (agent sudah terpasang, terklaim, dan tunnel sudah hidup).

**Alamat publik server ini (sudah diuji dari luar NAT):**

```
Host : molecule-stockton.tun.ply.gg
Port : 23592
```

Bukti uji (query UDP dari luar): `hostname=Roleplay Indonesia`, `0/100 pemain`,
`allowed_clients = 0.3.7, 0.3.DL`, `version = omp 1.6.7.3218`.

```bash
systemctl status playit          # agent harus "active"
sg playit -c "playit"            # cetak link claim kalau belum diklaim
```

Langkah sekali saja:
1. Buka link claim yang dicetak (`https://playit.gg/claim/<kode>`), login/buat akun,
   setujui agent. Agent jadi online di dashboard.
   **Wajib: verifikasi email akun playit.** Tanpa verifikasi, playit mematikan tunnel
   berulang tiap ~3 detik dan client hanya melihat "The server didn't respond".
2. Dashboard → **Tunnels → Add Tunnel → UDP** (bukan TCP+UDP, itu berbayar) →
   Local port `7777`, local address `127.0.0.1` → Create.
3. playit memberi alamat seperti `nama.playit.gg:12345`. Pemain mengetik **alamat itu
   dan port yang diberikan** di client SA-MP / launcher Android, bukan `sure-cove...`.

Tunnel tetap hidup setelah server reboot (`systemctl enable --now playit`). Kalau
playit memindahkan UDP ke paket berbayar, alternatifnya Portwarp (free-nya termasuk UDP).

---

## 5. Sebelum publik

- [x] `rcon.password` sudah diganti acak (ada di `server/config.json`, jangan di-commit).
- [x] Backup harian otomatis + rotasi 14 file.
- [x] Server auto-restart lewat supervisor + entri `@reboot`.
- [ ] Set `name` server dan `max_players` sesuai kapasitas.
- [ ] `network.allow_037_clients: true` — wajib kalau ingin client 0.3.7/0.3.DL ikut masuk.
- [ ] Backup `server/scriptfiles/rp.db` terjadwal (cron harian, simpan di luar folder server).
- [ ] Turunkan `log_level` ke `1` kalau server ramai (log debug membanjiri disk).
- [ ] Pastikan `/asay` dan `/agive` hanya bisa dipakai account dengan `admin_level` yang benar.

---

## 5b. Menjaga server tetap hidup

systemd **tidak bisa** dipakai untuk omp-server di mesin ini: manager menanamkan
`SystemCallFilter=~` bawaan dan binary `omp-server` adalah 32-bit (i386), sehingga proses
dibunuh `SIGSYS` tepat setelah start (`code=killed, signal=SYS`). Menjalankan manual sebagai
user biasa normal. Karena itu dipakai supervisor sendiri:

```bash
./scripts/supervise.sh      # loop: jalankan server, restart 5 detik kalau mati
./scripts/stop.sh           # berhenti rapi
crontab -l                  # sudah ada entri @reboot untuk supervise.sh
tail -f server/scriptfiles/console.log
```

---

## 6. Batas yang sudah diketahui

- **Objek fisik dibatasi 1000** selama client 0.3.7 diizinkan. Dunia dinamis wajib lewat
  streamer/dynamic object, bukan objek statis.
- Model kustom (`artconfig`) hanya terlihat oleh client 0.3.DL; client 0.3.7 tidak. Karena itu
  model kustom hanya hiasan, tidak boleh jadi syarat gameplay.
- SQLite cukup untuk satu server (single writer). Kalau nanti butuh multi-server/panel web,
  migrasi ke MySQL lewat `core/db` — hanya modul itu yang perlu diubah.
