// ---------------------------------------------------------------------------
// module      : domain/property
// entry       : Property_Boot()
// depends     : core/db, core/log, shared/messages, shared/money, ui/toast,
//               domain/world/locations (Locations_LabelId utk label DIJUAL),
//               domain/character (nama pemilik), domain/warung (kas toko)
// owns tables : buildings (dibuat di Property_Boot, BUKAN db.pwn)
// public api  : Property_Boot(), Property_FindByLocation(),
//               Property_OwnerOf(), Property_PriceOf(), Property_KasOf(),
//               Property_AddKasByLocation(), Property_Buy(),
//               Property_ShowSale(), Property_OpenAt(), Property_Reset()
//               (menu kelola pemilik di property_manage.pwn)
// Isi         : Sistem gedung/properti dinamis ala GTA5 RP. Gedung = properti
//               di atas lokasi: punya nama, harga jual, pemilik (0 = dijual
//               pemerintah), status buka, dan kas toko. Label 3D lokasi
//               ditambah akhiran "DIJUAL Rp X" selama belum dibeli. Belanja
//               di toko milik pemain masuk kas gedung; pemilik mengambil
//               lewat menu kelola. Admin membuat gedung via /buatgedung.
// Aturan      : Semua harga/kepemilikan hidup di DB; memori = cache hasil
//               load. Uang pemain hanya lewat Money_ (kas toko disimpan di
//               tabel buildings, bukan rekening).
// ---------------------------------------------------------------------------
#if defined _INC_DOMAIN_PROPERTY
    #endinput
#endif
#define _INC_DOMAIN_PROPERTY

#define PROP_MAX            (24)
#define PROP_CODE_LEN       (LOC_CODE_LEN)
#define PROP_NAME_LEN       (LOC_NAME_LEN)

static gPropCount = 0;
static gPropId[PROP_MAX];
static gPropLocCode[PROP_MAX][PROP_CODE_LEN];
static gPropName[PROP_MAX][PROP_NAME_LEN];
static gPropPrice[PROP_MAX];
static gPropOwner[PROP_MAX];        // character_id, 0 = dijual pemerintah
static bool:gPropOpen[PROP_MAX];
static gPropKas[PROP_MAX];          // kas toko (rupiah)
static gPropInterior[PROP_MAX];     // blueprint mapping custom (0 = tanpa)

// Mode UI yang dibuka otomatis setelah masuk interior (didefinisikan di sini
// karena property.pwn memakainya dan interiors.pwn disertakan setelahnya).
#define INT_UI_NONE         (0)
#define INT_UI_SHOP         (1)
#define INT_UI_MANAGE       (2)

// Dialog kelola/beli per pemain (index gedung).
static gPropDlgIndex[MAX_PLAYERS] = { -1, ... };
static gPropDlgMode[MAX_PLAYERS];    // mode lanjutan dialog PICKITEM
static gPropDlgSlot[MAX_PLAYERS];    // slot item terpilih untuk input harga

// Mode lanjutan dialog pilih-item (bukan dialog sungguhan).
#define PROP_MODE_NONE        (0)
#define PROP_MODE_SET_PRICE   (1)
#define PROP_MODE_DELETE      (2)

stock Property_Boot() {
    DB_Exec(
        "CREATE TABLE IF NOT EXISTS buildings (\
            building_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            location_code TEXT NOT NULL UNIQUE,\
            name TEXT NOT NULL,\
            price INTEGER NOT NULL DEFAULT 0,\
            owner_character_id INTEGER NOT NULL DEFAULT 0,\
            is_open INTEGER NOT NULL DEFAULT 1,\
            kas INTEGER NOT NULL DEFAULT 0)");
    Property_Reload();
    Property_MigrateGedungTypes();
    return 1;
}

// Migrasi: gedung yang dibuat sebelum ada tipe lokasi GEDUNG masih tercatat
// WARUNG -> yang muncul gerobak. Ubah ke GEDUNG + bangun ulang wujudnya.
static Property_MigrateGedungTypes() {
    for (new index = 0; index < gPropCount; index++) {
        new locIndex = Locations_FindByCode(gPropLocCode[index]);
        if (locIndex < 0) continue;

        new action[LOC_ACTION_LEN];
        Locations_Action(locIndex, action, sizeof (action));
        if (strcmp(action, LOC_ACT_WARUNG, false) != 0) continue;

        Locations_SetAction(locIndex, LOC_ACT_GEDUNG);
        Locations_Redress(locIndex);

        new escaped[PROP_CODE_LEN * 2 + 1];
        new query[160];
        DB_Escape(escaped, sizeof (escaped), gPropLocCode[index]);
        format(query, sizeof (query),
            "UPDATE locations SET action = '%s' WHERE code = '%s'",
            LOC_ACT_GEDUNG, escaped);
        DB_Exec(query);
    }
    return 1;
}

stock Property_Reload() {
    gPropCount = 0;
    new query[192];
    new total = DB_Int("SELECT COUNT(*) FROM buildings", 0);
    if (total > PROP_MAX) total = PROP_MAX;

    for (new row = 0; row < total; row++) {
        format(query, sizeof (query),
            "SELECT building_id, location_code, name, price, \
             owner_character_id, is_open, kas, interior_id \
             FROM buildings ORDER BY building_id LIMIT 1 OFFSET %d", row);
        new code[PROP_CODE_LEN];
        if (!DB_StrAt(query, 0, 1, code, sizeof (code))) continue;

        gPropId[gPropCount] = DB_IntAt(query, 0, 0, 0);
        format(gPropLocCode[gPropCount], PROP_CODE_LEN, "%s", code);
        DB_StrAt(query, 0, 2, gPropName[gPropCount], PROP_NAME_LEN);
        gPropPrice[gPropCount] = DB_IntAt(query, 0, 3, 0);
        gPropOwner[gPropCount] = DB_IntAt(query, 0, 4, 0);
        gPropOpen[gPropCount] = (DB_IntAt(query, 0, 5, 1) != 0);
        gPropKas[gPropCount] = DB_IntAt(query, 0, 6, 0);
        gPropInterior[gPropCount] = DB_IntAt(query, 0, 7, 0);
        gPropCount++;
    }

    new report[48];
    format(report, sizeof (report), "gedung dimuat: %d", gPropCount);
    Log_Info("property", report);
    return 1;
}

stock Property_FindByLocation(const locationCode[]) {
    for (new index = 0; index < gPropCount; index++) {
        if (strcmp(gPropLocCode[index], locationCode, false) == 0) return index;
    }
    return -1;
}

stock Property_OwnerOf(index) {
    if (index < 0 || index >= gPropCount) return 0;
    return gPropOwner[index];
}

stock Property_PriceOf(index) {
    if (index < 0 || index >= gPropCount) return 0;
    return gPropPrice[index];
}

stock Property_KasOf(index) {
    if (index < 0 || index >= gPropCount) return 0;
    return gPropKas[index];
}

stock Property_NameOf(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gPropCount) return format(dest, maxlength, "-");
    return format(dest, maxlength, "%s", gPropName[index]);
}

stock Property_IdOf(index) {
    if (index < 0 || index >= gPropCount) return 0;
    return gPropId[index];
}

// Kode lokasi gedung (dipakai untuk menyegarkan label 3D).
stock Property_CodeOf(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gPropCount) return format(dest, maxlength, "");
    return format(dest, maxlength, "%s", gPropLocCode[index]);
}

stock Property_InteriorOf(index) {
    if (index < 0 || index >= gPropCount) return 0;
    return gPropInterior[index];
}

// Akhiran label 3D sesuai status gedung (kosong bila bukan gedung/dimiliki).
stock Property_LabelSuffix(const locationCode[], dest[], maxlength) {
    dest[0] = '\0';
    new index = Property_FindByLocation(locationCode);
    if (index < 0) return 0;
    if (gPropOwner[index] == 0) {
        format(dest, maxlength, "DIJUAL Rp %d", gPropPrice[index]);
        return 1;
    }
    if (!gPropOpen[index]) {
        format(dest, maxlength, "TUTUP");
        return 1;
    }
    return 0;
}

// Segarkan label 3D lokasi (dipanggil setelah status jual/buka berubah).
stock Property_RefreshLabel(const locationCode[]) {
    new locIndex = Locations_FindByCode(locationCode);
    if (locIndex < 0) return 0;

    new suffix[40];
    Property_LabelSuffix(locationCode, suffix, sizeof (suffix));
    return Locations_SetLabel(locIndex, suffix);
}

// Uang belanja toko masuk kas gedung milik pemain (dipanggil Warung_Buy).
stock Property_AddKasByLocation(const locationCode[], amount) {
    new index = Property_FindByLocation(locationCode);
    if (index < 0 || gPropOwner[index] == 0 || amount <= 0) return 0;

    gPropKas[index] += amount;
    new query[128];
    format(query, sizeof (query),
        "UPDATE buildings SET kas = %d WHERE building_id = %d",
        gPropKas[index], gPropId[index]);
    DB_Exec(query);
    return 1;
}

// Beli gedung yang sedang dijual (dipanggil dari dialog konfirmasi).
stock bool:Property_Buy(playerid, index) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (index < 0 || index >= gPropCount) return false;
    if (gPropOwner[index] != 0) {
        Toast_Show(playerid, "GEDUNG", "Gedung ini sudah ada pemiliknya.",
            THEME_DANGER);
        return false;
    }
    if (gPropPrice[index] < 1) {
        Toast_Show(playerid, "GEDUNG", "Gedung ini tidak dijual.", THEME_DANGER);
        return false;
    }
    if (Money_GetCash(playerid) < gPropPrice[index]) {
        Toast_Show(playerid, "GEDUNG", "Uang tunai tidak cukup.", THEME_DANGER);
        return false;
    }
    if (!Money_Take(playerid, gPropPrice[index], MONEY_REASON_PROPERTY)) {
        return false;
    }

    gPropOwner[index] = Character_GetId(playerid);
    new query[128];
    format(query, sizeof (query),
        "UPDATE buildings SET owner_character_id = %d WHERE building_id = %d",
        gPropOwner[index], gPropId[index]);
    if (!DB_Exec(query)) {
        gPropOwner[index] = 0;
        Money_Add(playerid, gPropPrice[index], MONEY_REASON_PROPERTY);
        Toast_Show(playerid, "GEDUNG", MSG_DB_ERROR, THEME_DANGER);
        return false;
    }

    Property_RefreshLabel(gPropLocCode[index]);
    // Ikon radar pemain: rumah hijau (dijual) -> rumah merah (dimiliki).
    Locations_ShowIcons(playerid);
    new message[96], priceText[24];
    Messages_Money(gPropPrice[index], priceText, sizeof (priceText));
    format(message, sizeof (message), "Kamu membeli %s seharga %s. Selamat!",
        gPropName[index], priceText);
    Toast_Show(playerid, "GEDUNG", message, THEME_OK);
    return true;
}

// Dialog konfirmasi pembelian gedung (MSGBOX Beli/Batal).
stock bool:Property_ShowSale(playerid, index) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (index < 0 || index >= gPropCount) return false;
    if (gPropOwner[index] != 0) return false;

    gPropDlgIndex[playerid] = index;
    new body[128], priceText[24];
    Messages_Money(gPropPrice[index], priceText, sizeof (priceText));
    format(body, sizeof (body), "%s\n\nHarga: %s\nTunai kamu: Rp %d\n\nBeli gedung ini?",
        gPropName[index], priceText, Money_GetCash(playerid));
    ShowPlayerDialog(playerid, _:DIALOG_PROP_SALE, DIALOG_STYLE_MSGBOX,
        gPropName[index], body, "Beli", "Batal");
    return true;
}

stock Property_Count() {
    return gPropCount;
}

// Warung (toko) yang menempel pada gedung ini, atau -1.
stock Property_WarungOf(index) {
    if (index < 0 || index >= gPropCount) return -1;
    return Warung_FindByLocation(gPropLocCode[index]);
}

stock bool:Property_IsOpenOf(index) {
    if (index < 0 || index >= gPropCount) return false;
    return gPropOpen[index];
}

stock Property_DlgIndex(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    return gPropDlgIndex[playerid];
}

stock Property_DlgMode(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return PROP_MODE_NONE;
    return gPropDlgMode[playerid];
}

stock Property_DlgSlot(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    return gPropDlgSlot[playerid];
}

stock Property_SetDlg(playerid, index, mode, slot) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gPropDlgIndex[playerid] = index;
    gPropDlgMode[playerid] = mode;
    gPropDlgSlot[playerid] = slot;
    return 1;
}

// Titik masuk interaksi gedung dari lokasi (dipanggil Locations_Activate).
// Milik sendiri -> menu kelola; dijual -> konfirmasi beli; milik orang ->
// belanja di tokonya.
stock bool:Property_OpenAt(playerid, locIndex) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (locIndex < 0 || locIndex >= Locations_Count()) return false;

    new locationCode[PROP_CODE_LEN];
    Locations_Code(locIndex, locationCode, sizeof (locationCode));
    new index = Property_FindByLocation(locationCode);
    if (index < 0) return false; // bukan gedung: lanjut perilaku lokasi biasa

    if (gPropOwner[index] == 0) return Property_ShowSale(playerid, index);

    new uiMode = INT_UI_SHOP;
    if (gPropOwner[index] == Character_GetId(playerid)) {
        uiMode = INT_UI_MANAGE;
    } else {
        // Validasi toko sebelum masuk: tutup / menu kosong = jangan teleport.
        new warung = Property_WarungOf(index);
        if (!Property_IsOpenOf(index) || warung < 0
                || !Warung_IsOpenOf(warung)
                || Warung_ItemCountOf(warung) < 1) {
            Toast_Show(playerid, "TOKO", "Toko sedang tutup.", THEME_DANGER);
            return true;
        }
    }

    // Gedung punya mapping custom: masuk ke dalam, UI dibuka setelah sampai.
    if (Property_InteriorOf(index) > 0) {
        return Interiors_Enter(playerid, index, uiMode);
    }
    if (uiMode == INT_UI_MANAGE) return Property_ManageOpen(playerid, index);
    return false; // milik orang lain tanpa interior: lanjut belanja ke warung
}

stock Property_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gPropDlgIndex[playerid] = -1;
    gPropDlgMode[playerid] = PROP_MODE_NONE;
    gPropDlgSlot[playerid] = -1;
    return 1;
}
