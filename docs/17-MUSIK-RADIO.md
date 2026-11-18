# 17 — Musik & Radio (fase 1 dari rencana hybrid Spotify)

Fitur musik in-game memakai **stream audio nyata** milik/server, dengan UX ala
aplikasi musik modern. Spotify **tidak** bisa diputar langsung: audionya DRM
(Widevine), bukan URL stream. Karena itu rencananya hybrid — fase 1 radio,
fase 2 lapisan metadata Spotify.

## Kenapa bukan Spotify langsung

| Pendekatan | Hasil |
|---|---|
| URL Spotify di `PlayAudioStreamForPlayer` | Diam total (bukan MP3 publik) |
| Relay audio Spotify lewat server | Melanggar ToS + butuh dekripsi DRM |
| Stream milik sendiri (AzuraCast/Icecast) | Berbunyi, legal jika lisensi beres |
| Spotify Web API (metadata) | "Now playing", playlist, tautan — tanpa audio |

## Arsitektur fase 1

```
smartphone: tile MUSIK ──┐
/radio ──────────────────┼─> domain/media/radio (arbitrase + PlayAudioStream)
/radiostop, /musik ──────┘            │
                                      └─> domain/media/radio_data (tabel)
```

- `radio_data.pwn` — tabel `radio_stations(station_id, name, genre, stream_url,
  bitrate, enabled, created_at)`, cache + seed + CRUD. URL **tidak** di kode UI.
- `radio.pwn` — satu pintu `Radio_Play()`: stream lama dihentikan lebih dulu
  (`StopAudioStreamForPlayer`) supaya tidak ada dua lagu menumpuk. Sumber
  dicatat sebagai `PHONE` atau `CAR` (radio mobil otomatis saat di kendaraan).
- **Tanpa posisi 3D** di fase 1: sumber bergerak (mobil) akan membuat stream
  restart setiap kali posisi diperbarui. Audio 3D disiapkan untuk boombox
  statis di fase 1b (`usepos = true`, jarak 30 m).

## Perintah

| Perintah | Siapa | Fungsi |
|---|---|---|
| `/radio` | pemain | Daftar stasiun (dialog) lalu putar |
| `/musik` | pemain | Status musik |
| `/musik off` / `on` | pemain | Senyapkan / izinkan lagi |
| `/radiostop` | pemain | Hentikan stream |
| `/radiostation` | admin (moderator) | Daftar stasiun + nomor |
| `/radiostation tambah <nama> <genre> <url>` | admin | Tambah stasiun (http/https) |
| `/radiostation hapus <nomor>` | admin | Nonaktifkan stasiun |
| `/radiostation reload` | admin | Muat ulang cache setelah edit DB |

Seed bawaan: Groove Salad, Lush, Secret Agent, Deep Space One (SomaFM, 128 kbps,
gratis untuk didengarkan). **Untuk produksi** ganti ke AzuraCast milik sendiri —
seed hanya jalan saat tabel kosong, jadi stasiun buatan admin tidak tertimpa.

## Catatan operasional

- **Satu stream per pemain** adalah batas klien. Semua pemutaran lewat
  `Radio_Play()`; jangan panggil native langsung dari modul lain.
- **Mobile**: dukungan audio stream bervariasi antar klien Android. Selalu
  sediakan `/musik off`; kalau klien menolak stream, pemain mendapat pesan
  error, bukan diam tanpa penjelasan.
- **Bandwidth**: 128 kbps x 50 pemain = 6,4 Mbps. Turunkan bitrate stasiun
  (64 kbps) atau host stream di VPS terpisah dari server game.
- **Lisensi**: memutar musik komersial di server publik butuh lisensi (di
  Indonesia lewat LMKN). Opsi aman: stasiun royalty-free, radio komunitas yang
  mengizinkan relay, atau lisensi langsung.
- Stream dihentikan otomatis saat pemain tewas dan putus koneksi.

## Fase 2 (belum dikerjakan): lapisan Spotify

1. Backend kecil (Node/PHP) memegang OAuth PKCE + refresh token; **jangan** di
   gamemode (token tidak boleh ada di server game).
2. Gamemode cukup memanggil native `HTTP()` open.mp ke backend tersebut untuk
   metadata "now playing" DJ klub, lalu menampilkannya di textdraw.
3. Data di DB: `radio_favorites` (station per karakter), `radio_plays`
   (statistik "paling sering diputar"), playlist klub.
4. Tidak ada audio Spotify yang disiarkan — hanya metadata + tautan.

## Fase 1b (belum dikerjakan): boombox

Item `boombox` di inventory, diletakkan sebagai objek + pickup, audio
`usepos = true` radius 30 m, mati saat baterai habis atau objek diambil.
Menumpang `inventory` + `streamer`, tanpa sistem audio kedua.
