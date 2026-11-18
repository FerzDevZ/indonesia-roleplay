# 08 — Standar Pawn

Ditulis untuk dibaca sekali, dipatuhi selamanya. Kalau sebuah aturan tidak bisa dicek
mesin, aturan itu lemah — karena itu sebagian besar di bawah ini punya gate di CI.

## 1. Penamaan

| Entitas | Gaya | Contoh |
|---|---|---|
| Modul API publik | `Modul_Verba` | `Identity_Issue`, `Money_Take` |
| Fungsi internal | `static`, sama tapi tidak diekspor | `static bool:Vehicle_IsOwned()` |
| Enum type | `E_NAMA` | `E_PLAYER_PHASE`, `E_CLIENT_TIER` |
| Konstanta | `SCREAMING_SNAKE` | `MAX_OWNED_VEHICLES` |
| Variabel global modul | `static gNama` | `static gPhase[MAX_PLAYERS]` |
| Parameter `Float:` | tag eksplisit | `Float:x` |
| Array string | selalu dengan ukuran | `dest[MAX_PLAYER_NAME + 1]` |

**Dilarang** (dicek review): `data`, `temp`, `res`, `obj`, `item`, `x1`, `tmp`.

## 2. Ukuran dan bentuk fungsi

- Maksimum 40 baris per fungsi. Lebih dari itu = ada dua tanggung jawab.
- Maksimum 3 level indentasi. Lebih dari itu = butuh guard clause.
- Guard clause di atas, bukan `if` bersarang:

```pawn
// salah
stock bool:Vehicle_CanDrive(playerid, vehicleid) {
    if (IsPlayerInAnyVehicle(playerid)) {
        if (GetPlayerVehicleID(playerid) == vehicleid) {
            if (Phase_CanAct(playerid)) { return true; }
        }
    }
    return false;
}

// benar
stock bool:Vehicle_CanDrive(playerid, vehicleid) {
    if (!Phase_CanAct(playerid)) return false;
    if (!IsPlayerInAnyVehicle(playerid)) return false;
    if (GetPlayerVehicleID(playerid) != vehicleid) return false;
    return true;
}
```

- Satu fungsi, satu nilai balik yang konsisten (`bool` untuk sukses/gagal,
  bukan kadang `1` kadang `-1` tanpa dokumentasi).

## 3. Komentar

Komentar menjelaskan **mengapa**, bukan **apa**. Kalau kode sudah jelas, komentar
dihapus.

```pawn
// salah — mengulang kode
// cek kalau player sudah login
if (!Phase_CanAct(playerid)) return 0;

// benar — menjelaskan keputusan
// Simpan hanya saat keluar karena MySQL pool terbatas:
// query simpan per-domain akan memblokir saat 200 pemain keluar bersamaan.
if (!Character_Save(playerid)) Log_Error("character", "gagal simpan %d", playerid);
```

Dilarang total: `// TODO`, `// FIXME`, `// implement later`, `...` sebagai pengganti kode
(dicek CI, build gagal).

## 4. String dan teks

- Semua teks pemain ada di `shared/messages.pwn` sebagai entri katalog, bukan literal.
- Format uang lewat `Money_Format(value, dest, len)` → `"Rp 1.250.000"`.
- Format waktu lewat `Time_Format(seconds, dest, len)` → `"2 jam 14 menit"`.
- Bahasa: IC = Indonesia, OOC/command help = Indonesia ringkas, kode = Inggris.

```pawn
Messages_Send(playerid, MSG_LICENSE_FINE_ISSUED, amount);
// bukan
SendClientMessage(playerid, -1, "Anda ditilang!");
```

## 5. Callback dan hook

- Semua callback gameplay memakai `hook` dari `y_hooks`, tidak ada ALS manual.
- Setiap `hook` wajib mengembalikan `1` atau hasil callback aslinya — jangan `return 0`
  tanpa alasan yang didokumentasikan.
- Callback yang mahal (`OnPlayerUpdate`, `OnVehicleDamageStatusUpdate`) wajib punya
  early-exit di baris pertama:

```pawn
hook OnPlayerUpdate(playerid) {
    if (!Phase_CanAct(playerid)) return 1;
    AntiCheat_TrackPosition(playerid);   // hanya ini, tidak ada logika lain
    return 1;
}
```

## 6. Dialog

- ID dialog **wajib** dari enum `E_DIALOG_ID` di satu file (`shared/messages.pwn`).
  Literal angka di `ShowPlayerDialog` ditolak CI.
- `OnDialogResponse` wajib:
  1. validasi `dialogid` dikenal,
  2. validasi `Phase_CanAct`,
  3. validasi `listitem` terhadap data server (jangan percaya client),
  4. `return 1` di akhir, dan `return 0` untuk dialog yang bukan miliknya.

## 7. Query dan data

- Query hanya lewat `DB_QueryAsync`. Tidak ada exception.
- Semua nilai yang masuk query lewat escape (`%e` untuk string) — tidak ada
  `format("... '%s'", input)`.
- Callback query diberi nama `OnXLoaded` dan dideklarasikan `public` dengan komentar
  penanda `// callback: DB_QueryAsync`.

## 8. Memori dan pool

- Semua entitas dinamis (rumah, bisnis, kendaraan milik pemain) memakai iterasi
  `Iterator:` dari `y_iterate`, bukan loop `MAX_*`.
- Slot bebas dicari dengan `Iter_Free()`, bukan counter increment yang tumbuh terus.
- Setiap `Create` punya `Destroy` pasangan di modul yang sama, dan `Destroy` selalu
  idempoten (aman dipanggil dua kali).

## 9. Kesalahan

- Tidak ada `catch` kosong / `if (!x) {}` tanpa log.
- Pola wajib kegagalan:

```pawn
if (!DB_QueryAsync(query, "OnVehicleLoaded", "i", vehicleid)) {
    Log_Error("vehicle", "query gagal untuk kendaraan %d", vehicleid);
    Messages_Send(playerid, MSG_INTERNAL_ERROR);
    return 0;
}
```

- Log wajib menyertakan modul dan id entitas. Tidak ada `print("error")` telanjang.

## 10. Tag compile yang dipakai

```
-d3           # debug info penuh (dev dan CI; boleh -d2 di prod untuk memangkas ukuran)
-;+           # wajib titik koma
-(+           # wajib tanda kurung
-w+           # tampilkan semua warning
-O1           # optimasi sedang; jangan -O2 di awal, sulit debug
```

Warning diperlakukan sebagai error di CI: compiler gagal kalau ada warning. Argumen:
warning di Pawn hampir selalu berarti bug nyata (tag mismatch, unused symbol, arity).

## 11. Daftar periksa sebelum commit

- [ ] `sampctl package build` exit 0, tanpa warning
- [ ] Tidak menambah file > 400 baris
- [ ] Fungsi baru internal memakai `static`
- [ ] Tidak ada literal uang/dialog/model di domain
- [ ] Kalau menyentuh uang: ada baris `money_log` dengan `reason` yang benar
- [ ] Kalau menyentuh waktu/timer: terdaftar di `Timer_Boot()`
- [ ] Kalau menyentuh UI: diuji di client 0.3.7, bukan hanya 0.3.DL

## Gate sambungan modul (`scripts/wiring-check.sh`)

Compiler tidak bisa menangkap perintah yang tidak pernah dicapai, dialog yang
ditolak `Dialog_IsKnown`, atau aksi lokasi tanpa dispatch. Karena itu gate ini
wajib lolos bersama build:

1. **Satu perintah satu pemilik.** Nama perintah yang muncul di dua file berbeda
   ditolak, karena handler pertama di `callbacks.pwn` selalu menang dan handler
   kedua menjadi kode mati.
2. **/help = kenyataan.** Setiap perintah yang disebut di bantuan wajib punya
   handler.
3. **Dialog terdaftar.** Setiap `DIALOG_*` yang dipakai `ShowPlayerDialog` wajib
   ada di `Dialog_IsKnown`, kalau tidak `OnDialogResponse` menolaknya.
4. **Aksi lokasi lengkap.** Setiap `LOC_ACT_*` wajib punya dispatch dan ikon
   radar (ikon dinamis gedung dan ikon bawaan loket PD dikecualikan eksplisit).

