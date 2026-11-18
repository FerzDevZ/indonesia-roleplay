# 13 — MAPPING INTERIOR (aturan geometri)

Dokumen acuan untuk blueprint interior custom (`src/domain/world/interiors.pwn`).

## 1. Data model terverifikasi

| Model | Nama | Lebar (X) | Tinggi (Z) | Tebal (Y) | Collision |
|---|---|---|---|---|---|
| **19377** | wall025 | 9.63762 m | 10.50146 m | 0.1787764 m | Ya |
| **19379** | wall027 | 9.63762 m | 10.50146 m | 0.1787764 m | Ya |
| 19364 | window | — | — | — | Ya |
| 1843 | shop_shelf02 | — | — | — | Ya |
| 2164 | kasir/kabinet | — | — | — | Ya |
| 1775 / 1776 | vending machine | — | — | — | Ya |
| 1224 / 1221 | kardus stok | — | — | — | Ya |

Sumber: `dev.prineside.com/en/gtasa_samp_model_id/model/19377-wall025/` dan
`.../19379-wall027/`.

**Penting:** panel dinding 10.5 m TINGGI, bukan slab lantai. Tidak ada scaling
di SA-MP/open.mp, jadi tinggi panel tidak bisa dikecilkan — harus ditanam.

## 2. Rumus geometri (WAJIB dipakai, jangan angka manual)

```
INT_ROOM_H  = 2.6                          // tinggi ruangan yang terlihat
INT_HALF_W  = 9.63762 / 2 = 4.81881        // setengah lebar panel
INT_WALL_Z  = 2.6 - 10.50146/2 = -2.65073  // pusat dinding (ditanam 7.9 m)
INT_ROOF_Z  = 2.6 + 0.1787764/2 = 2.68939  // plafon menempel di atas dinding
INT_FLOOR_Z = -0.1787764/2 = -0.08939      // permukaan lantai tepat z = 0
```

Aturan turunan:

1. **Lantai & plafon** = model 19379 dengan `rx = 90` (menjadi slab horizontal
   9.64 × 10.5 m, tebal 0.18 m). Gunakan `Bp_Slab()`.
2. **Dinding** = model 19377 vertikal dengan `z = INT_WALL_Z`. Gunakan
   `Bp_Wall()`. Hanya 2.6 m bagian atas yang tampak; 7.9 m sisanya di bawah
   lantai sehingga sambungan tidak pernah bolong.
3. **Dinding** ditempatkan di `x = ±INT_HALF_W` atau `y = ±INT_HALF_W`.
   JANGAN pakai baris dinding dengan koordinat tetap di 0 (bug lama: dinding
   muncul di tengah ruangan dan sisi ruangan terbuka).
4. **Ruangan tertutup penuh** (tanpa lubang pintu). Keluar-masuk lewat
   teleport + pickup `[KELUAR]` **di dalam** ruangan. Jangan taruh pickup keluar
   ruangan — pemain akan jatuh ke void.
5. Slab lantai boleh lebih panjang dari ruangan (10.5 m vs 9.64 m); kelebihan
   tersembunyi di balik dinding. Jangan pernah lebih pendek.
6. Setiap gedung = instans sendiri: `Interiors_OriginOf(index)` memakai grid
   8 (X) × 3 (Y) + pita Z, jadi 24 gedung punya 24 ruang berbeda.

## 3. Blueprint yang ada

| # | Nama | Ukuran | Objek | Spawn | Pintu keluar |
|---|---|---|---|---|---|
| 1 | Warung Kelontong | 9.64 × 9.64 × 2.6 m | 13 | (0, −2.6) hadap utara | (0, −4.3) |
| 2 | Minimarket | 19.28 × 9.64 × 2.6 m | 21 | (0, −2.6) hadap utara | (0, −4.3) |

Budget objek: `INT_OBJ_MAX` 48 per blueprint, `PROP_MAX` 24 gedung →
maksimal 1152 objek; jaga tetap di bawah batas 1000 objek server. Saat ini
worst case 24 × 21 = 504 objek.

## 4. Menambah blueprint baru (template)

```pawn
// === BLUEPRINT 3: NAMA (ruang W x D x 2.6 m) ===
Bp_Slab(2, 0.0, 0.0, INT_FLOOR_Z);
Bp_Slab(2, 0.0, 0.0, INT_ROOF_Z);
Bp_Wall(2, 0.0,  INT_HALF_W, 0.0);
Bp_Wall(2, 0.0, -INT_HALF_W, 0.0);
Bp_Wall(2, -INT_HALF_W, 0.0, 90.0);
Bp_Wall(2,  INT_HALF_W, 0.0, 90.0);
// ...furnitur (Bp_Add) ...
gBpSpawnX[2] = 0.0; gBpSpawnY[2] = -2.6; gBpSpawnA[2] = 0.0;
gBpExitX[2]  = 0.0; gBpExitY[2]  = -4.3;
```

Lalu: naikkan `INT_BLUEPRINT_MAX`, tambahkan nama di `Interiors_NameOf()`,
dan sediakan di `/setinterior <0-3>`.

## 5. Checklist sebelum rilis mapping

- [ ] Lantai menutup seluruh luas ruangan (tidak terlihat void saat melihat ke bawah).
- [ ] Semua 4 dinding ada; tidak ada dinding di tengah ruangan.
- [ ] Plafon menempel tepat di atas dinding (tidak ada celah cahaya).
- [ ] Pintu keluar berada DI DALAM ruangan.
- [ ] Furnitur tidak menembus dinding (≤ lebar ruangan − 0.5 m dari dinding).
- [ ] Spawn ≥ 1 m dari pickup keluar (anti masuk-keluar berulang).
- [ ] `./scripts/build.sh` + `./scripts/gates.sh` LULUS.
