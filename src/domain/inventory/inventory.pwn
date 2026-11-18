// ---------------------------------------------------------------------------
// module      : domain/inventory
// entry       : Inv_Boot()
// depends     : core/db, core/log, shared/messages, ui/toast
// owns tables : character_items (per karakter), array barang jatuh dunia
// public api  : Inv_Boot(), Inv_Load(), Inv_Reset(), Inv_Give(), Inv_Take(),
//               Inv_CountOf(), Inv_TotalWeight(), Inv_SlotCount(),
//               Inv_SlotItem(), Inv_SlotQty(), Inv_UseSlot(), Inv_DropSlot(),
//               Inv_OnPickup(), Inv_Tick(), Inv_HandleCommand(),
//               Inv_ItemFromCode(), Inv_ItemName(), Inv_MaxWeight()
// Isi         : Inventory bobot ringan (maks 20 kg) untuk fase C2. Katalog
//               barang di kode (4 barang pertama), milik pemain di SQLite
//               (character_items: satu baris per kode barang). Barang yang
//               dibuang muncul sebagai pickup fisik di dunia dan bisa diambil
//               lagi siapa pun; kedaluwarsa 10 menit lewat Inv_Tick.
// Aturan      : Semua mutasi langsung disimpan ke DB (tanpa cache kotor).
//               Slot UI = indeks virtual atas barang berqty > 0.
// ---------------------------------------------------------------------------
#if defined _INC_DOMAIN_INVENTORY
    #endinput
#endif
#define _INC_DOMAIN_INVENTORY

#include "../../core/db.pwn"
#include "../../core/log.pwn"
#include "../../shared/messages.pwn"
#include "../../ui/theme.pwn"
#include "../../ui/toast.pwn"

#define INV_MAX_SLOTS       (12)    // grid UI 4x3
#define INV_MAX_WEIGHT      (20.0)  // kg
#define INV_MAX_DROPPED     (64)
#define INV_DROP_LIFETIME   (600)   // detik sampai barang jatuh lenyap

// Katalog barang (fase C2). Tambah barang = tambah kolom di keempat tabel.
#define INV_ITEM_PAKET      (0)
#define INV_ITEM_MAKANAN    (1)
#define INV_ITEM_MINUMAN    (2)
#define INV_ITEM_OBAT       (3)
#define INV_ITEM_COUNT      (4)

static const gInvCode[INV_ITEM_COUNT][12] = {
    "PAKET", "MAKANAN", "MINUMAN", "OBAT"
};
static const gInvName[INV_ITEM_COUNT][20] = {
    "Paket Kiriman", "Ayam Goreng", "Air Mineral", "Medkit"
};
static const gInvGlyph[INV_ITEM_COUNT][2] = {"P", "M", "A", "O"};
static const Float:gInvWeight[INV_ITEM_COUNT] = {2.0, 0.5, 0.5, 1.5};
static const gInvColor[INV_ITEM_COUNT] = {
    THEME_WARN, THEME_OK, THEME_INFO, THEME_DANGER
};
static const bool:gInvUsable[INV_ITEM_COUNT] = {false, true, true, true};
static const gInvPickupModel[INV_ITEM_COUNT] = {1210, 2768, 1544, 1240};

// Milik pemain: jumlah per kode barang (slot UI = turunan dari sini).
static gInvQty[MAX_PLAYERS][INV_ITEM_COUNT];

// Barang jatuh di dunia (tanpa plugin streamer: pickup standar).
enum E_DROPPED_ITEM {
    bool:dActive,
    dItem,
    dQty,
    dPickupId,
    dCreatedAt,
    Float:dX,
    Float:dY,
    Float:dZ
};
static gDropped[INV_MAX_DROPPED][E_DROPPED_ITEM];

stock Inv_Boot() {
    // Tabel milik modul ini (dibuat di sini, bukan di skema pusat db.pwn).
    if (!DB_Exec(
        "CREATE TABLE IF NOT EXISTS character_items (\
            entry_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            character_id INTEGER NOT NULL,\
            code TEXT NOT NULL,\
            qty INTEGER NOT NULL DEFAULT 1,\
            UNIQUE(character_id, code))")) {
        Log_Error("inventory", "gagal membuat tabel character_items");
        return 0;
    }
    for (new entry = 0; entry < INV_MAX_DROPPED; entry++) {
        gDropped[entry][dActive] = false;
    }
    new bootMsg[80];
    format(bootMsg, sizeof (bootMsg), "siap (katalog %d barang, maks 20.0 kg)",
        INV_ITEM_COUNT);
    Log_Info("inventory", bootMsg);
    return 1;
}

stock Float:Inv_MaxWeight() {
    return INV_MAX_WEIGHT;
}

stock Inv_ItemName(item, dest[], maxlength = sizeof (dest)) {
    if (item < 0 || item >= INV_ITEM_COUNT) return format(dest, maxlength, "-");
    return format(dest, maxlength, "%s", gInvName[item]);
}

stock Float:Inv_ItemWeight(item) {
    if (item < 0 || item >= INV_ITEM_COUNT) return 0.0;
    return gInvWeight[item];
}

stock Inv_ItemGlyph(item, dest[], maxlength = sizeof (dest)) {
    if (item < 0 || item >= INV_ITEM_COUNT) return format(dest, maxlength, " ");
    return format(dest, maxlength, "%s", gInvGlyph[item]);
}

stock Inv_ItemColor(item) {
    if (item < 0 || item >= INV_ITEM_COUNT) return THEME_MUTED;
    return gInvColor[item];
}

stock bool:Inv_ItemUsable(item) {
    if (item < 0 || item >= INV_ITEM_COUNT) return false;
    return gInvUsable[item];
}

stock Inv_ItemFromCode(const code[]) {
    for (new item = 0; item < INV_ITEM_COUNT; item++) {
        if (strcmp(code, gInvCode[item], true) == 0) return item;
    }
    return -1;
}

stock Inv_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    for (new item = 0; item < INV_ITEM_COUNT; item++) {
        gInvQty[playerid][item] = 0;
    }
    return 1;
}

// Muat tas karakter dari DB. Dipanggil tiap spawn (data selalu sinkron DB).
stock Inv_Load(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    new charId = Character_GetId(playerid);
    if (charId < 1) return 0;

    Inv_Reset(playerid);
    new query[144];
    format(query, sizeof (query),
        "SELECT code, qty FROM character_items WHERE character_id = %d", charId);
    new rows = DB_Rows(query);

    new code[12];
    for (new row = 0; row < rows; row++) {
        DB_StrAt(query, row, 0, code, sizeof (code));
        new qty = DB_IntAt(query, row, 1, 0);
        new item = Inv_ItemFromCode(code);
        if (item >= 0 && qty > 0) {
            gInvQty[playerid][item] = qty;
        }
    }
    return 1;
}

stock Float:Inv_TotalWeight(playerid) {
    new Float:total = 0.0;
    for (new item = 0; item < INV_ITEM_COUNT; item++) {
        total += gInvWeight[item] * float(gInvQty[playerid][item]);
    }
    return total;
}

stock Inv_CountOf(playerid, item) {
    if (item < 0 || item >= INV_ITEM_COUNT) return 0;
    return gInvQty[playerid][item];
}

// Jumlah slot terpakai (untuk grid UI).
stock Inv_SlotCount(playerid) {
    new used = 0;
    for (new item = 0; item < INV_ITEM_COUNT; item++) {
        if (gInvQty[playerid][item] > 0) used++;
    }
    return used;
}

// Barang pada slot virtual ke-N (-1 kalau kosong).
stock Inv_SlotItem(playerid, slot) {
    if (slot < 0 || slot >= INV_MAX_SLOTS) return -1;
    new used = 0;
    for (new item = 0; item < INV_ITEM_COUNT; item++) {
        if (gInvQty[playerid][item] > 0) {
            if (used == slot) return item;
            used++;
        }
    }
    return -1;
}

stock Inv_SlotQty(playerid, slot) {
    new item = Inv_SlotItem(playerid, slot);
    if (item < 0) return 0;
    return gInvQty[playerid][item];
}

// Simpan satu kode barang ke DB (upsert; hapus baris saat qty habis).
static Inv_SaveRow(playerid, item) {
    new charId = Character_GetId(playerid);
    if (charId < 1) return 0;

    new query[192], codeEsc[16];
    format(codeEsc, sizeof (codeEsc), "%s", gInvCode[item]);
    if (gInvQty[playerid][item] > 0) {
        new existsQuery[160];
        format(existsQuery, sizeof (existsQuery),
            "SELECT qty FROM character_items WHERE character_id = %d \
AND code = '%s'", charId, codeEsc);
        if (DB_Int(existsQuery, 0) > 0) {
            format(query, sizeof (query),
                "UPDATE character_items SET qty = %d WHERE character_id = %d \
AND code = '%s'", gInvQty[playerid][item], charId, codeEsc);
        } else {
            format(query, sizeof (query),
                "INSERT INTO character_items (character_id, code, qty) \
VALUES (%d, '%s', %d)", charId, codeEsc, gInvQty[playerid][item]);
        }
    } else {
        format(query, sizeof (query),
            "DELETE FROM character_items WHERE character_id = %d \
AND code = '%s'", charId, codeEsc);
    }
    return DB_Exec(query);
}

// Beri barang (dipakai admin /beli nanti). Cek bobot dulu, anti-exploit.
stock bool:Inv_Give(playerid, item, qty) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (item < 0 || item >= INV_ITEM_COUNT || qty < 1) return false;
    if (Character_GetId(playerid) < 1) return false;

    new Float:added = gInvWeight[item] * float(qty);
    if (Inv_TotalWeight(playerid) + added > INV_MAX_WEIGHT) {
        Messages_SendError(playerid, "Tas penuh: melebihi batas 20 kg.");
        return false;
    }

    gInvQty[playerid][item] += qty;
    if (!Inv_SaveRow(playerid, item)) {
        gInvQty[playerid][item] -= qty; // roll back memori bila DB gagal
        Messages_SendError(playerid, "Gagal menyimpan barang.");
        return false;
    }
    return true;
}

// Ambil (mengurangi) barang. Dipakai pakai/buang/drop.
stock bool:Inv_Take(playerid, item, qty) {
    if (item < 0 || item >= INV_ITEM_COUNT) return false;
    if (gInvQty[playerid][item] < qty) return false;

    gInvQty[playerid][item] -= qty;
    if (!Inv_SaveRow(playerid, item)) {
        gInvQty[playerid][item] += qty;
        return false;
    }
    return true;
}

// Pakai barang pada slot: efek sesuai jenis, kurangi 1.
stock bool:Inv_UseSlot(playerid, slot) {
    new item = Inv_SlotItem(playerid, slot);
    if (item < 0) return false;
    if (!Inv_ItemUsable(item)) {
        Messages_SendError(playerid, "Barang ini tidak bisa dipakai.");
        return false;
    }
    if (!Inv_Take(playerid, item, 1)) return false;

    if (item == INV_ITEM_MAKANAN) {
        // Efek nilai (lapar + darah) milik domain/survival.
        Survival_ConsumeFood(playerid);
        Toast_Show(playerid, "MAKAN", "Kamu makan Ayam Goreng.", THEME_OK);
    } else if (item == INV_ITEM_MINUMAN) {
        Survival_ConsumeDrink(playerid);
        Toast_Show(playerid, "MINUM", "Kamu minum Air Mineral.", THEME_INFO);
    } else if (item == INV_ITEM_OBAT) {
        SetPlayerHealth(playerid, 100.0);
        Toast_Show(playerid, "OBAT", "Kamu pakai Medkit. HP penuh.", THEME_DANGER);
    }
    return true;
}

// Buang satu unit ke dunia: pickup fisik di depan pemain.
stock bool:Inv_DropSlot(playerid, slot) {
    new item = Inv_SlotItem(playerid, slot);
    if (item < 0) return false;
    if (!Inv_Take(playerid, item, 1)) return false;

    new Float:x, Float:y, Float:z;
    GetPlayerPos(playerid, x, y, z);
    new Float:angle;
    GetPlayerFacingAngle(playerid, angle);
    x += 1.2 * floatsin(-angle, degrees);
    y += 1.2 * floatcos(-angle, degrees);

    new entry = -1;
    for (new scan = 0; scan < INV_MAX_DROPPED; scan++) {
        if (!gDropped[scan][dActive]) {
            entry = scan;
            break;
        }
    }
    if (entry == -1) {
        // Tabel penuh: barang kembali ke tas.
        Inv_Give(playerid, item, 1);
        Messages_SendError(playerid, "Terlalu banyak barang berserakan.");
        return false;
    }

    gDropped[entry][dActive] = true;
    gDropped[entry][dItem] = item;
    gDropped[entry][dQty] = 1;
    gDropped[entry][dX] = x;
    gDropped[entry][dY] = y;
    gDropped[entry][dZ] = z;
    gDropped[entry][dCreatedAt] = gettime();
    gDropped[entry][dPickupId] = CreatePickup(gInvPickupModel[item], 1, x, y, z, 0);

    ApplyAnimation(playerid, "BOMBER", "BOM_Plant", 4.0, false, false, false, false, 0);
    new label[64], itemName[20];
    Inv_ItemName(item, itemName, sizeof (itemName));
    format(label, sizeof (label), "Kamu membuang %s di tanah.", itemName);
    Messages_SendSystem(playerid, label);
    return true;
}

// Pemain mengambil pickup barang jatuh. Validasi jarak server-side.
stock Inv_OnPickup(playerid, pickupid) {
    for (new entry = 0; entry < INV_MAX_DROPPED; entry++) {
        if (!gDropped[entry][dActive]) continue;
        if (gDropped[entry][dPickupId] != pickupid) continue;

        new Float:x, Float:y, Float:z;
        GetPlayerPos(playerid, x, y, z);
        new Float:dist = GetPlayerDistanceFromPoint(playerid,
            gDropped[entry][dX], gDropped[entry][dY], gDropped[entry][dZ]);
        if (dist > 6.0) return 1; // anti-teleport-ambil

        new item = gDropped[entry][dItem];
        DestroyPickup(pickupid);
        gDropped[entry][dActive] = false;
        if (!Inv_Give(playerid, item, 1)) {
            // Tas penuh: barang tetap di tanah - buat ulang pickupnya.
            gDropped[entry][dActive] = true;
            gDropped[entry][dPickupId] = CreatePickup(gInvPickupModel[item], 1,
                gDropped[entry][dX], gDropped[entry][dY], gDropped[entry][dZ], 0);
            return 1;
        }
        new text[96], itemName[20];
        Inv_ItemName(item, itemName, sizeof (itemName));
        format(text, sizeof (text), "Kamu mengambil %s.", itemName);
        Toast_Show(playerid, "TAS", text, THEME_OK);
        return 1;
    }
    return 0;
}

// Kedaluwarsa barang jatuh: panggilan berkala (500 ms).
stock Inv_Tick() {
    new now = gettime();
    for (new entry = 0; entry < INV_MAX_DROPPED; entry++) {
        if (!gDropped[entry][dActive]) continue;
        if (now - gDropped[entry][dCreatedAt] < INV_DROP_LIFETIME) continue;
        DestroyPickup(gDropped[entry][dPickupId]);
        gDropped[entry][dActive] = false;
    }
    return 1;
}

// Perintah /tas: buka UI tas.
stock bool:Inv_HandleCommand(playerid, const command[], const params[]) {
    if (strcmp(command, "tas", true) != 0 && strcmp(command, "inv", true) != 0) {
        return false;
    }
    #pragma unused params
    if (!Auth_IsLoggedIn(playerid) || Character_GetId(playerid) < 1) {
        Messages_SendError(playerid, "Masuk dan pilih karakter dulu.");
        return true;
    }
    InventoryUI_Open(playerid);
    return true;
}
