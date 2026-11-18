// ---------------------------------------------------------------------------
// module      : domain/warung
// entry       : Warung_Boot()
// depends     : core/db, core/log, shared/messages, shared/money,
//               ui/toast, domain/world/locations, domain/inventory,
//               domain/admin (Admin_Require + Admin_Audit, kini stock)
// owns tables : warungs, warung_items (dibuat di Warung_Boot, BUKAN db.pwn)
// public api  : Warung_Boot(), Warung_OpenMenu(), Warung_Buy(),
//               Warung_Near(), Warung_Reload(), Warung_IdOf(),
//               Warung_NameOf(), Warung_ItemCountOf(), Warung_IsOpenOf(),
//               Warung_ItemCodeOf(), Warung_ItemPriceOf()
//               (perintah admin terpisah di warung_admin.pwn)// Isi         : Warung sepenuhnya data-driven (tahap 2, gaya framework):
//               tabel `warungs` (lokasi + status buka) dan `warung_items`
//               (menu + harga). Admin menambah warung & menu in-game tanpa
//               compile ulang: /buatwarung, /tambahmenu, /setharga,
//               /hapusmenu, /tutupwarung, /bukawarung. Pemain membeli lewat
//               dialog daftar (dialog hanya untuk pemilihan list - sesuai
//               aturan UI), barang masuk tas, tunai berkurang via Money_.
// Aturan      : Harga & menu tidak boleh hardcode; baca dari memori hasil
//               load DB. Warung ditargetkan lewat lokasi terdekat pemain.
// ---------------------------------------------------------------------------
#if defined _INC_DOMAIN_WARUNG
    #endinput
#endif
#define _INC_DOMAIN_WARUNG

#define WAR_MAX             (16)
#define WAR_ITEM_MAX        (8)
#define WAR_CODE_LEN        (24)
#define WAR_NAME_LEN        (40)
#define WAR_ITEM_CODE_LEN   (12)

static gWarCount = 0;
static gWarId[WAR_MAX];
static gWarLocCode[WAR_MAX][LOC_CODE_LEN];
static gWarName[WAR_MAX][WAR_NAME_LEN];
static bool:gWarOpen[WAR_MAX];
static gWarItemCount[WAR_MAX];
static gWarItemCode[WAR_MAX][WAR_ITEM_MAX][WAR_ITEM_CODE_LEN];
static gWarItemPrice[WAR_MAX][WAR_ITEM_MAX];
static gWarItemId[WAR_MAX][WAR_ITEM_MAX];

// Warung yang dialog menunya sedang terbuka per pemain.

// Bangun tabel + seed warung bawaan (sekali, INSERT OR IGNORE).
stock Warung_Boot() {
    DB_Exec(
        "CREATE TABLE IF NOT EXISTS warungs (\
            warung_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            location_code TEXT NOT NULL UNIQUE,\
            name TEXT NOT NULL,\
            is_open INTEGER NOT NULL DEFAULT 1)");
    DB_Exec(
        "CREATE TABLE IF NOT EXISTS warung_items (\
            item_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            warung_id INTEGER NOT NULL,\
            code TEXT NOT NULL,\
            price INTEGER NOT NULL,\
            UNIQUE(warung_id, code))");

    DB_Exec(
        "INSERT OR IGNORE INTO warungs (location_code, name) \
         VALUES ('WARUNG_STASIUN', 'Warung Bu Sari')");

    // Menu bawaan warung seed (harga dasar, admin bisa ubah in-game).
    DB_Exec(
        "INSERT OR IGNORE INTO warung_items (warung_id, code, price) \
         SELECT warung_id, 'MAKANAN', 5000 FROM warungs \
         WHERE location_code = 'WARUNG_STASIUN'");
    DB_Exec(
        "INSERT OR IGNORE INTO warung_items (warung_id, code, price) \
         SELECT warung_id, 'MINUMAN', 3000 FROM warungs \
         WHERE location_code = 'WARUNG_STASIUN'");
    DB_Exec(
        "INSERT OR IGNORE INTO warung_items (warung_id, code, price) \
         SELECT warung_id, 'OBAT', 8000 FROM warungs \
         WHERE location_code = 'WARUNG_STASIUN'");

    Warung_Reload();
    return 1;
}

// Muat ulang semua warung + menu dari DB ke memori.
stock Warung_Reload() {
    gWarCount = 0;
    new query[160];
    new total = DB_Int("SELECT COUNT(*) FROM warungs", 0);
    if (total > WAR_MAX) total = WAR_MAX;

    for (new row = 0; row < total; row++) {
        format(query, sizeof (query),
            "SELECT warung_id, location_code, name, is_open \
             FROM warungs ORDER BY warung_id LIMIT 1 OFFSET %d", row);
        new code[WAR_CODE_LEN];
        if (!DB_StrAt(query, 0, 1, code, sizeof (code))) continue;

        gWarId[gWarCount] = DB_IntAt(query, 0, 0, 0);
        format(gWarLocCode[gWarCount], LOC_CODE_LEN, "%s", code);
        DB_StrAt(query, 0, 2, gWarName[gWarCount], WAR_NAME_LEN);
        gWarOpen[gWarCount] = (DB_IntAt(query, 0, 3, 1) != 0);
        gWarItemCount[gWarCount] = 0;
        gWarCount++;
    }

    // Muat menu tiap warung.
    for (new index = 0; index < gWarCount; index++) {
        gWarItemCount[index] = 0;
        format(query, sizeof (query),
            "SELECT COUNT(*) FROM warung_items WHERE warung_id = %d",
            gWarId[index]);
        new itemCount = DB_Int(query, 0);
        if (itemCount > WAR_ITEM_MAX) itemCount = WAR_ITEM_MAX;

        for (new row = 0; row < itemCount; row++) {
            format(query, sizeof (query),
                "SELECT item_id, code, price FROM warung_items \
                 WHERE warung_id = %d ORDER BY item_id LIMIT 1 OFFSET %d",
                gWarId[index], row);
            new itemCode[WAR_ITEM_CODE_LEN];
            if (!DB_StrAt(query, 0, 1, itemCode, sizeof (itemCode))) continue;

            new slot = gWarItemCount[index];
            gWarItemId[index][slot] = DB_IntAt(query, 0, 0, 0);
            format(gWarItemCode[index][slot], WAR_ITEM_CODE_LEN, "%s", itemCode);
            gWarItemPrice[index][slot] = DB_IntAt(query, 0, 2, 0);
            gWarItemCount[index]++;
        }
    }

    new report[48];
    format(report, sizeof (report), "warung dimuat: %d", gWarCount);
    Log_Info("warung", report);
    return 1;
}

// Indeks warung milik lokasi tertentu, atau -1.
stock Warung_FindByLocation(const locationCode[]) {
    for (new index = 0; index < gWarCount; index++) {
        if (strcmp(gWarLocCode[index], locationCode, false) == 0) return index;
    }
    return -1;
}

// Warung terdekat dari pemain (lokasinya dalam radius pemain), atau -1.
stock Warung_Near(playerid) {
    new locIndex = Locations_Near(playerid);
    if (locIndex < 0) return -1;

    new locationCode[LOC_CODE_LEN];
    Locations_Code(locIndex, locationCode, sizeof (locationCode));
    return Warung_FindByLocation(locationCode);
}

// Akses baca untuk modul admin warung (warung_admin.pwn).
stock Warung_IdOf(warung) {
    if (warung < 0 || warung >= gWarCount) return 0;
    return gWarId[warung];
}

stock Warung_NameOf(warung, dest[], maxlength = sizeof (dest)) {
    if (warung < 0 || warung >= gWarCount) return format(dest, maxlength, "-");
    return format(dest, maxlength, "%s", gWarName[warung]);
}

// Buka toko warung pada lokasi (dipanggil dari Locations_Activate).
// UI-nya panel textdraw FiveM (WarungUI), bukan dialog - menu toko adalah
// menu klik, bukan pemilihan list.
stock bool:Warung_OpenMenu(playerid, locIndex) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (locIndex < 0 || locIndex >= Locations_Count()) return false;

    new locationCode[LOC_CODE_LEN];
    Locations_Code(locIndex, locationCode, sizeof (locationCode));
    new warung = Warung_FindByLocation(locationCode);
    if (warung < 0) {
        Toast_Show(playerid, "WARUNG", "Warung belum terdaftar.", THEME_DANGER);
        return false;
    }
    if (!gWarOpen[warung]) {
        Toast_Show(playerid, "WARUNG", "Warung sedang tutup.", THEME_DANGER);
        return false;
    }
    if (gWarItemCount[warung] < 1) {
        Toast_Show(playerid, "WARUNG", "Menu kosong.", THEME_DANGER);
        return false;
    }
    return WarungUI_Open(playerid, warung);
}

// Akses baca untuk UI toko & modul properti (warungui/property).
stock Warung_ItemCountOf(warung) {
    if (warung < 0 || warung >= gWarCount) return 0;
    return gWarItemCount[warung];
}

// Buka/tutup warung dari modul lain (mis. tombol kelola toko di properti).
// Cache di memori + baris DB ikut diperbarui supaya tahan restart.
stock Warung_SetOpen(warung, bool:open) {
    if (warung < 0 || warung >= gWarCount) return 0;
    gWarOpen[warung] = open;
    new query[128];
    format(query, sizeof (query),
        "UPDATE warungs SET is_open = %d WHERE warung_id = %d",
        open ? 1 : 0, gWarId[warung]);
    if (!DB_Exec(query)) {
        Log_Warn("warung", "gagal simpan status buka");
        return 0;
    }
    return 1;
}

stock bool:Warung_IsOpenOf(warung) {
    if (warung < 0 || warung >= gWarCount) return false;
    return gWarOpen[warung];
}

stock Warung_ItemCodeOf(warung, slot, dest[], maxlength = sizeof (dest)) {
    if (warung < 0 || warung >= gWarCount || slot < 0
            || slot >= gWarItemCount[warung]) {
        return format(dest, maxlength, "-");
    }
    return format(dest, maxlength, "%s", gWarItemCode[warung][slot]);
}

stock Warung_ItemPriceOf(warung, slot) {
    if (warung < 0 || warung >= gWarCount || slot < 0
            || slot >= gWarItemCount[warung]) {
        return 0;
    }
    return gWarItemPrice[warung][slot];
}

// Beli 1 barang dari warung (dipanggil UI toko saat baris item diklik).
// Uang belanja masuk kas toko bila gedungnya sudah dimiliki pemain lain.
stock bool:Warung_Buy(playerid, warung, slot) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (warung < 0 || warung >= gWarCount || !gWarOpen[warung]) return false;
    if (slot < 0 || slot >= gWarItemCount[warung]) return false;

    new itemCode[WAR_ITEM_CODE_LEN];
    format(itemCode, sizeof (itemCode), "%s", gWarItemCode[warung][slot]);
    new price = gWarItemPrice[warung][slot];
    new item = Inv_ItemFromCode(itemCode);
    if (item < 0) {
        Toast_Show(playerid, "WARUNG", "Barang tidak tersedia.", THEME_DANGER);
        return false;
    }
    if (Money_GetCash(playerid) < price) {
        Toast_Show(playerid, "WARUNG", "Uang tunai tidak cukup.", THEME_DANGER);
        return false;
    }

    // Barang dulu (validasi tas), lalu tunai; gagal tunai = tarik balik barang.
    if (!Inv_Give(playerid, item, 1)) {
        Toast_Show(playerid, "WARUNG", "Tas penuh atau kelebihan berat.",
            THEME_DANGER);
        return false;
    }
    if (!Money_Take(playerid, price, MONEY_REASON_FOOD)) {
        Inv_Take(playerid, item, 1);
        Toast_Show(playerid, "WARUNG", "Pembayaran gagal.", THEME_DANGER);
        return false;
    }

    // Kas toko: gedung milik pemain lain menerima uang belanja.
    new locationCode[LOC_CODE_LEN];
    format(locationCode, sizeof (locationCode), "%s", gWarLocCode[warung]);
    Property_AddKasByLocation(locationCode, price);

    new itemName[20], message[64], priceText[24];
    Inv_ItemName(item, itemName, sizeof (itemName));
    Messages_Money(price, priceText, sizeof (priceText));
    format(message, sizeof (message), "Beli %s - %s. Masuk tas.", itemName,
        priceText);
    Toast_Show(playerid, gWarName[warung], message, THEME_OK);
    return true;
}

// Perintah pemain /beli: buka panel warung terdekat. Pintasan teks untuk
// pemain yang belum terbiasa menekan pill [Y] (help menyebut /beli).
stock bool:Warung_HandleCommand(playerid, const command[], const params[]) {
    #pragma unused params
    if (strcmp(command, "beli", true) != 0) return false;
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }

    new locIndex = Locations_NearCode(playerid, LOC_ACT_WARUNG);
    if (locIndex < 0) {
        Messages_SendError(playerid, "Tidak ada warung di dekatmu.");
        return true;
    }
    Warung_OpenMenu(playerid, locIndex);
    return true;
}

