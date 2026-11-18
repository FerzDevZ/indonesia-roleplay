# 03 — Arsitektur

## 1. Lapisan dan arah dependensi

```
┌─────────────────────────────────────────────┐
│ gememode.pwn   bootstrap, tanpa gameplay    │
└──────────────────┬──────────────────────────┘
                   │ boleh import semua
┌──────────────────▼──────────────────────────┐
│ domain/        aturan bisnis per fitur      │
│    auth · identity · vehicle · property     │
│    faction · economy · job · medical        │
└──────────────────┬──────────────────────────┘
                   │ boleh import shared + core
┌──────────────────▼──────────────────────────┐
│ shared/        primitif lintas domain       │
│    player_phase · money · pools · messages  │
└──────────────────┬──────────────────────────┘
                   │ boleh import core
┌──────────────────▼──────────────────────────┐
│ core/          infrastruktur, nol gameplay  │
│    settings · log · db · timer · telemetry  │
└─────────────────────────────────────────────┘
```

Arah panah **satu arah**. `core` tidak boleh tahu `shared`; `shared` tidak boleh tahu
`domain`; `domain` tidak saling import kecuali lewat API publik yang didokumentasikan
di header file penerima.

## 2. Struktur folder

```
gamemode.pwn                     # 30-60 baris: include + main()
src/
  core/
    settings.pwn                 # env + config.json, typed getter
    log.pwn                      # log terstruktur: file, chat admin, webhook
    db.pwn                       # SQLite + migrasi kolom + DB_Int/DB_Str
    timer.pwn                    # named timer: Timer_Add(name, ms, cb)
    telemetry.pwn                # counter runtime, budget alarm
    callbacks.pwn                # semua public callback + routing klik/dialog
    text.pwn                     # helper format teks
  shared/
    player_phase.pwn             # state machine pemain
    client_tier.pwn              # TIER_037 / TIER_DL
    money.pwn                    # SATU-SATUNYA penulis saldo
    messages.pwn                 # katalog teks (IC/OOC) + id dialog
    validate.pwn                 # guard input: angka, jarak, ownership
  ui/
    theme.pwn                    # SEMUA token visual (warna/font/sprite)
    trxtdraw.pwn                 # engine textdraw: pool 256, klik, progress
    uimodal.pwn                  # SATU pemain = SATU modal (open/close/destroy)
    welcome.pwn  hud.pwn  toast.pwn
    charselect.pwn
    charcreate.pwn  charcreate_draw.pwn  charcreate_input.pwn
    prompt.pwn                   # pil interaksi [Y] dekat pemain lain
    ktpcard.pwn  simcard.pwn     # kartu dokumen bergaya e-KTP/SIM Nasional
  domain/
    auth/        auth.pwn
    character/   character.pwn  character_create.pwn
    identity.pwn                 # KTP/SIM: terbit, NIK, /ktp /sim /ujisim
    identity_datadiri.pwn        # /datadiri: 7 field data pribadi
    identity_simcard.pwn         # builder data kartu SIM
    tilang.pwn                   # tilang admin: denda sink + poin SIM
    chat/        chat.pwn
    admin/       admin.pwn
  data/                          # (rencana) katalog skin/kendaraan
```

Catatan kondisi (Fase B selesai): modul `identity`, `tilang`, dan UI kartu
(`ktpcard`, `simcard`, `prompt`) sudah hidup; `vehicle`, `property`, `business`,
`faction`, `economy/atm`, `job`, `medical` masih sesuai roadmap fase berikutnya.

Aturan ukuran: **satu file maksimum 400 baris**. Lebih dari itu artinya ada dua
tanggung jawab yang menempel dan harus dipisah.

## 3. Kontrak modul (wajib, ditulis di kepala file)

```pawn
// ---------------------------------------------------------------------------
// module      : domain/identity
// entry       : Identity_Boot()
// depends     : core/db, shared/money, shared/player_phase
// owns tables : identity_docs, vehicle_licenses, plates
// public api  : Identity_Issue(), Identity_Has(), Identity_Revoke(),
//               Identity_ShowCard()
// hooks       : OnPlayerSpawn (apply docs default)
// ---------------------------------------------------------------------------
```

`Boot` bukan `Init`. Semua modul mengekspos satu fungsi masuk bernama `X_Boot()`, dan
`gamemode.pwn` memanggilnya **berurutan eksplisit** — tidak ada auto-load, tidak ada
include yang "kebetulan" jalan duluan.

```pawn
// gamemode.pwn
#include <open.mp>
#include <YSI_Coding\y_hooks>
#include <YSI_Data\y_iterate>
#include <YSI_Coding\y_commands>
#include <sscanf2>

#include "src/core/settings.pwn"
#include "src/core/log.pwn"
#include "src/core/db.pwn"
#include "src/core/timer.pwn"
#include "src/core/telemetry.pwn"

#include "src/shared/player_phase.pwn"
#include "src/shared/client_tier.pwn"
#include "src/shared/money.pwn"
#include "src/shared/pools.pwn"
#include "src/shared/messages.pwn"

#include "src/domain/auth/auth.pwn"
#include "src/domain/character/character.pwn"
#include "src/domain/identity/identity.pwn"
// ... domain lain, urutan sesuai fase roadmap

main() {
    Settings_Load();
    Log_Boot();
    DB_Boot();
    Timer_Boot();

    Auth_Boot();
    Character_Boot();
    Identity_Boot();
    // ...
    print("[boot] siap");
}
```

## 4. Pagar modul: `static` sebagai alat arsitektur

Pawn tidak punya `private` per file. Tapi kita bisa memaksa batas **saat compile**,
bukan saat runtime: setiap fungsi internal modul **wajib** `static`.

```pawn
// domain/vehicle/vehicle.pwn
static bool:Vehicle_IsOwnedBy(vehicleid, characterid) { ... }   // internal
stock Vehicle_Assign(vehicleid, characterid) { ... }            // API publik
```

Kalau file lain memanggil `Vehicle_IsOwnedBy`, hasilnya **error compiler "function not
found"** — bukan bug diam-diam. Ini satu-satunya mekanisme nyata yang membuat "modular
rapi" bisa diverifikasi mesin, bukan sekadar niat baik.

Aturan pendukung:
- Nama fungsi publik berprefiks nama modul (`Identity_`, `Vehicle_`, `Money_`).
- State global modul juga `static` dan diakses lewat getter.
- Tidak ada `new` global di luar deklarasi modul pemiliknya.

## 5. State pemain: satu mesin, bukan boolean berserakan

```pawn
// shared/player_phase.pwn
enum E_PLAYER_PHASE {
    PHASE_NONE = 0,
    PHASE_CONNECTING,      // baru connect, belum auth
    PHASE_AUTHENTICATING,  // dialog login/register
    PHASE_CHAR_SELECT,     // pilih karakter
    PHASE_LOADING,         // load data karakter dari DB
    PHASE_SPAWNING,        // layar spawn
    PHASE_ALIVE,           // bisa beraksi
    PHASE_INJURED,         // mati, menunggu EMS
    PHASE_ADMIN_SPECTATE
}

stock bool:Phase_CanAct(playerid)  { return gPhase[playerid] == PHASE_ALIVE; }
stock bool:Phase_CanChat(playerid) { return Phase_IsInWorld(playerid); }
static bool:Phase_IsInWorld(playerid) {
    switch (gPhase[playerid]) {
        case PHASE_ALIVE, PHASE_INJURED, PHASE_ADMIN_SPECTATE: return true;
    }
    return false;
}
```

Setiap command, setiap `OnDialogResponse`, setiap timer gameplay memanggil guard ini di
baris pertama. Tidak ada command yang boleh menulis `if (IsPlayerLogged[playerid])`.

## 6. Kebijakan database

- Query hanya lewat `DB_QueryAsync(query[], callback[], format[], ...)` di `core/db`.
- Tidak ada `mysql_tquery`, `mysql_pquery`, `mysql_query` di `src/domain/**`. Dijaga CI.
- Setiap callback query mengembalikan `cache_id` yang tidak valid setelah callback
  selesai → semua pembacaan terjadi **di dalam** callback.
- Query penulisan wajib menyertakan `character_id` untuk audit trail.
- Tidak ada query di `OnPlayerUpdate`. Tidak ada query di `OnPlayerKeyStateChange`.

```pawn
// core/db.pwn
stock DB_QueryAsync(const query[], const callback[], const format[], {Float,Fixed,_}:...) {
    if (gDB == MYSQL_INVALID_HANDLE) {
        Log_Error("db", "query tanpa koneksi: %s", query);
        return 0;
    }
    // format + dispatch, callback wajib terdaftar di registry
    return 1;
}
```

## 7. Timer: satu registry, tanpa angka ajaib

```pawn
Timer_AddMillis(TIMER_SAVE_ALL, 120_000, OnAutoSaveTick);
Timer_AddSeconds(TIMER_TAX_DAILY, 86_400, OnDailyTaxTick);
```

Tidak ada `SetTimer` langsung di domain. Semua timer mati otomatis saat GMX, dan
didaftarkan di `Timer_Boot()` supaya bisa diaudit dalam satu daftar.

## 8. Gate verifikasi (Gate 1 nyata, bukan "saya sudah cek")

```bash
sampctl package ensure
sampctl package build          # exit 0, 0 error, .amx terbentuk
```

Gate tambahan yang dijalankan CI (semua harus exit 0):

| Gate | Perintah | Menangkap |
|---|---|---|
| Build | `sampctl package build` | error compile, include hilang |
| Loop terlarang | `! grep -rn "i < MAX_PLAYERS" src/` | iterasi boros |
| DB bocor | `! grep -rn "mysql_tquery\|mysql_query" src/domain` | query di luar core |
| Dialog ID liar | `! grep -rn "ShowPlayerDialog(.*, [0-9]\{1,\}," src/domain` | ID dialog hardcode |
| Stub terlarang | `! grep -rn "TODO\|FIXME\|implement later" src/` | kode separuh jadi |
| Ukuran file | `find src -name '*.pwn' -exec wc -l {} +` ≤ 400/file | modul gemuk |
| Budget objek | `grep -c "CreateObject(" src/` ≤ budget | objek fisik meledak |

## 9. Yang sengaja tidak kita pakai

- **Auto-include glob.** Sulit dilacak, urutan jadi takdir.
- **Semua modul YSI.** Hanya `y_hooks`, `y_iterate`, `y_commands`; sisanya beban compile
  dan permukaan konflik makro.
- **FCNPC.** open.mp 1.5.8+ punya NPC bawaan; FCNPC adalah workaround era SA-MP.
- **Query sinkron di jalur pemain.** Tidak ada pengecualian.
- **`OnPlayerUpdate` sebagai tempat logika.** Hanya untuk anti-cheat ringan dan
  telemetri; sisanya timer.
