# 02 — Dual-client: open.mp + client 0.3.7 / 0.3.DL

## 1. Klarifikasi yang menentukan segalanya

"Support client SA-MP lama" **bukan** berarti dua codebase, dua build, atau dua
gamemode. Yang terjadi:

- Server tetap **satu**: open.mp 1.6.7.x.
- Client 0.3.7-R5, 0.3.DL, dan launcher modern masuk ke binary yang sama.
- Saklarnya satu field config: `network.allow_037_clients` (default `true`).

Yang harus dibayar: begitu client 0.3.7 diizinkan, server **turun ke batas client
terendah** — termasuk **maksimum 1000 objek fisik**. Ini konsekuensi keras, bukan
opsional.

```json
{
  "network": {
    "allow_037_clients": true,
    "public_addr": "203.0.113.10"
  },
  "artwork": {
    "enable": true,
    "models_path": "models",
    "cdn": "https://cdn.example.id/models/",
    "show_crc_logs": false
  }
}
```

`artwork.enable` **aman dinyalakan** — open.mp hanya mengirim model kustom ke client
yang mengaku 0.3.DL. Artinya client 0.3.7 tetap dapat versi vanilla tanpa error.

### Catatan tentang `config.json.example`

File contoh di root repo adalah **titik awal, bukan kebenaran**. Selalu hasilkan config
otoritatif dari binary yang benar-benar dipakai, lalu bandingkan:

```bash
./omp-server --default-config
```

Kunci yang berubah antar versi (mis. `network.mtu`, `game.lag_compensation_mode`)
harus diverifikasi dari hasil perintah itu, bukan dari dokumentasi lama.

**Kredensial MySQL tidak masuk `config.json`.** open.mp tidak mengelola koneksi MySQL;
koneksi dibuka di `src/core/db.pwn` (`MySQL_Connect`) dengan nilai dari environment
(`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`) lewat `core/settings.pwn`. Jangan
pernah menaruh password database di file yang di-commit.

## 2. Matriks kapabilitas

| Fitur | 0.3.7-R5 | 0.3.DL | Penanganan kita |
|---|---|---|---|
| Natives server standar | Ya | Ya | Pakai semua |
| Objek streamer (`CreateDynamicObject`) | Ya | Ya | Satu-satunya jalan untuk dunia dinamis |
| Skin kustom (`AddCharModel`) | **Tidak** | Ya | Skip untuk 0.3.7, fallback skin vanilla |
| Objek kustom (`AddSimpleModel`) | **Tidak** | Ya | Hanya untuk dekorasi, bukan gameplay |
| Batas objek fisik | 1000 | 1000+ | Budget dashboard di `core/telemetry` |
| TextDraw / UI server-side | Ya | Ya | Pilar UI utama kita |
| NPC bawaan open.mp | Ya | Ya | Untuk pekerjaan ambient |
| FastDL/artwork CDN | Tidak | Ya | Tidak pernah jadi syarat mekanik |

Kesimpulan arsitektural: **art kustom = progressive enhancement, tidak pernah syarat
gameplay.** Pemain 0.3.7 harus bisa mengalami 100% mekanik.

## 3. Capability tier (inti desain dual-client)

Satu fungsi, satu tempat, dipakai di seluruh domain:

```pawn
// shared/client_tier.pwn
enum E_CLIENT_TIER {
    TIER_UNKNOWN = 0,   // sebelum download selesai / tidak diketahui
    TIER_037,           // client lama, vanilla only
    TIER_DL             // 0.3.DL, model kustom tersedia
}

static gClientTier[MAX_PLAYERS] = { TIER_UNKNOWN, ... };

stock ClientTier_Set(playerid, E_CLIENT_TIER:tier) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gClientTier[playerid] = tier;
    return 1;
}

stock E_CLIENT_TIER:ClientTier_Get(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return TIER_UNKNOWN;
    return gClientTier[playerid];
}

stock bool:ClientTier_HasCustomArt(playerid) {
    return ClientTier_Get(playerid) == TIER_DL;
}
```

Penentuan tier memakai `OnPlayerFinishedDownloading` sebagai sinyal DL; tanpa sinyal
itu dalam N detik, anggap `TIER_037`.

## 4. Aturan penulisan kode yang tidak bisa dilanggar

**Dilarang**
```pawn
SetPlayerSkin(playerid, SKIN_PAK_HAJI_KUSTOM);  // id > 311 = crash di 0.3.7
CreateObject(MODEL_KUSTOM, x, y, z);            // memakan budget 1000 & tak terlihat
```

**Wajib**
```pawn
stock Identity_ApplySkin(playerid, characterSkinId) {
    new skin = (ClientTier_HasCustomArt(playerid))
        ? characterSkinId
        : SkinCatalog_VanillaFallback(characterSkinId);

    if (!SkinCatalog_IsValid(skin)) {
        skin = SKIN_DEFAULT_CIVILIAN;
    }
    SetPlayerSkin(playerid, skin);
    return 1;
}
```

Aturan turunan:

1. Semua ID model kustom hidup di `data/catalog/` sebagai konstanta bernama. Tidak ada
   literal `-1003` di kode domain.
2. Setiap model kustom **wajib** punya pasangan fallback vanilla di tabel yang sama.
3. Objek dunia statis (gedung, peta) memakai `CreateObject` seminimal mungkin; yang
   dinamis wajib `CreateDynamicObject` dengan `stream_distance` eksplisit.
4. Budget objek dicek CI: jumlah `CreateObject(` di `src/` tidak boleh lebih dari
   angka di `docs/BUDGET.md`, dan runtime melaporkan `GetObjectCount()` tiap 60 detik.

## 5. Budget runtime yang dijaga

| Sumber | Target | Alarm |
|---|---|---|
| Objek fisik global | ≤ 400 | 700 |
| Objek streamer aktif total | ≤ 20.000 | 35.000 |
| Label 3D | ≤ 1.500 | 2.500 |
| Pickup | ≤ 800 | 1.200 |
| Tick `OnPlayerUpdate` total | ≤ 0.4 ms | 0.8 ms |

Melewati alarm = modul penyumbang dimatikan dulu, bukan seluruh server.

## 6. Konsekuensi UX untuk client lama

Pemain 0.3.7 tidak boleh merasa jadi warga kelas dua:

- Login/character select memakai TextDraw server-side, bukan model preview.
  (Model preview `Font 5` hanya untuk DL; 0.3.7 dapat panel teks.)
- Warnet/motor/mobil kustom diganti model vanilla yang paling mendekati, dengan nama
  IC tetap sama ("Vespa" tetap dipanggil Vespa walau modelnya Faggio).
- Tidak ada dialog "update client Anda" — server tidak pernah menagih itu.
