// ---------------------------------------------------------------------------
// module      : domain/property/property_manage
// entry       : -
// depends     : domain/property (state via API), domain/warung (menu toko),
//               domain/admin (Admin_Require/Audit), core/db, core/text
//               (Command_NextToken), shared/messages, shared/money, ui/toast
// owns tables : -
// public api  : Property_ManageOpen(), Property_OnDialogResponse(),
//               PropertyAdmin_HandleCommand()
// Isi         : Menu kelola gedung milik pemain (dialog list - sesuai aturan
//               UI): buka/tutup toko, tambah menu, atur harga, hapus menu,
//               ambil kas, info. Semua perubahan tulis DB lalu reload.
//               Admin: /buatgedung <nama> <harga> (lokasi + warung + gedung
//               + prop fisik otomatis di posisi admin).
// Aturan      : Parsing tanpa sscanf; dialog hanya untuk list/input.
// ---------------------------------------------------------------------------
#if defined _INC_DOMAIN_PROPERTY_MANAGE
    #endinput
#endif
#define _INC_DOMAIN_PROPERTY_MANAGE

static Property_ManageTitle(index, dest[], maxlength = sizeof (dest)) {
    new name[LOC_NAME_LEN];
    Property_NameOf(index, name, sizeof (name));
    return format(dest, maxlength, "KELOLA: %s", name);
}

// Buka menu kelola (pemilik sudah divalidasi pemanggil).
stock bool:Property_ManageOpen(playerid, index) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (index < 0 || index >= Property_Count()) return false;

    new body[192], kasText[24];
    Messages_Money(Property_KasOf(index), kasText, sizeof (kasText));
    format(body, sizeof (body),
        "Buka/Tutup Toko (status: %s)\nTambah Menu (KODE harga)\n\
         Atur Harga Menu\nHapus Menu\nAmbil Kas (%s)\nInfo Toko",
        Property_IsOpenOf(index) ? "BUKA" : "TUTUP", kasText);
    new title[LOC_NAME_LEN + 12];
    Property_ManageTitle(index, title, sizeof (title));
    ShowPlayerDialog(playerid, _:DIALOG_PROP_MENU, DIALOG_STYLE_LIST,
        title, body, "Pilih", "Tutup");
    return true;
}

// Daftar item menu toko gedung ini (untuk atur harga / hapus).
static bool:Property_ShowPickItem(playerid, index, nextMode) {
    new warung = Property_WarungOf(index);
    if (warung < 0 || Warung_ItemCountOf(warung) < 1) {
        Messages_SendError(playerid, "Menu toko kosong.");
        return false;
    }

    new list[192], line[48];
    for (new slot = 0; slot < Warung_ItemCountOf(warung); slot++) {
        new itemCode[WAR_ITEM_CODE_LEN];
        Warung_ItemCodeOf(warung, slot, itemCode, sizeof (itemCode));
        format(line, sizeof (line), "%s - Rp %d\n", itemCode,
            Warung_ItemPriceOf(warung, slot));
        strcat(list, line);
    }
    Property_SetDlg(playerid, index, nextMode, -1);
    ShowPlayerDialog(playerid, _:DIALOG_PROP_PICKITEM, DIALOG_STYLE_LIST,
        "Pilih Item", list, "Pilih", "Batal");
    return true;
}

static Property_ToggleOpen(playerid, index) {
    new isOpen = Property_IsOpenOf(index) ? 0 : 1;
    new query[128];
    format(query, sizeof (query),
        "UPDATE buildings SET is_open = %d WHERE building_id = %d",
        isOpen, Property_IdOf(index));
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return;
    }
    // Status buka harus sinkron di dua tempat: gedung (buildings.is_open) dan
    // warung yang menempel (warungs.is_open). Kalau tidak, pintu masuk toko
    // dan label 3D bisa saling bertentangan.
    new warung = Property_WarungOf(index);
    if (warung >= 0) Warung_SetOpen(warung, isOpen ? true : false);

    Property_Reload();
    new locationCode[PROP_CODE_LEN];
    Property_CodeOf(index, locationCode, sizeof (locationCode));
    if (locationCode[0] != '\0') Property_RefreshLabel(locationCode);

    Messages_SendSystem(playerid, isOpen ? "Toko dibuka." : "Toko ditutup.");
}

static Property_CollectKas(playerid, index) {
    new kas = Property_KasOf(index);
    if (kas < 1) {
        Messages_SendError(playerid, "Kas toko kosong.");
        return;
    }
    new query[128];
    format(query, sizeof (query),
        "UPDATE buildings SET kas = 0 WHERE building_id = %d",
        Property_IdOf(index));
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return;
    }
    Property_Reload();
    Money_Add(playerid, kas, MONEY_REASON_JOB);
    new kasText[24];
    Messages_Money(kas, kasText, sizeof (kasText));
    new message[64];
    format(message, sizeof (message), "Kas toko diambil: %s.", kasText);
    Toast_Show(playerid, "GEDUNG", message, THEME_OK);
}

static Property_ShowInfo(playerid, index) {
    new name[LOC_NAME_LEN], kasText[24];
    Property_NameOf(index, name, sizeof (name));
    Messages_Money(Property_KasOf(index), kasText, sizeof (kasText));
    new message[128];
    format(message, sizeof (message),
        "~%s~ kas %s ~ status %s", name, kasText,
        Property_IsOpenOf(index) ? "BUKA" : "TUTUP");
    Messages_SendSystem(playerid, message);
}

static Property_SetItemPrice(playerid, index, slot, price) {
    new warung = Property_WarungOf(index);
    if (warung < 0) return;
    new itemCode[WAR_ITEM_CODE_LEN];
    Warung_ItemCodeOf(warung, slot, itemCode, sizeof (itemCode));

    new escapedCode[WAR_ITEM_CODE_LEN * 2 + 1];
    DB_Escape(escapedCode, sizeof (escapedCode), itemCode);
    new query[192];
    format(query, sizeof (query),
        "UPDATE warung_items SET price = %d WHERE warung_id = %d \
         AND code = '%s'", price, Warung_IdOf(warung), escapedCode);
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return;
    }
    Warung_Reload();
    new message[80];
    format(message, sizeof (message), "Harga %s sekarang Rp %d.", itemCode,
        price);
    Messages_SendSystem(playerid, message);
}

static Property_DeleteItem(playerid, index, slot) {
    new warung = Property_WarungOf(index);
    if (warung < 0) return;
    new itemCode[WAR_ITEM_CODE_LEN];
    Warung_ItemCodeOf(warung, slot, itemCode, sizeof (itemCode));

    new escapedCode[WAR_ITEM_CODE_LEN * 2 + 1];
    DB_Escape(escapedCode, sizeof (escapedCode), itemCode);
    new query[192];
    format(query, sizeof (query),
        "DELETE FROM warung_items WHERE warung_id = %d AND code = '%s'",
        Warung_IdOf(warung), escapedCode);
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return;
    }
    Warung_Reload();
    new message[64];
    format(message, sizeof (message), "%s dihapus dari menu.", itemCode);
    Messages_SendSystem(playerid, message);
}

static Property_AddItem(playerid, index, const inputtext[]) {
    new itemCode[WAR_ITEM_CODE_LEN], priceText[16], tail[32];
    if (!Command_NextToken(inputtext, itemCode, sizeof (itemCode), priceText,
            sizeof (priceText)) || priceText[0] == '\0'
            || Command_NextToken(priceText, tail, sizeof (tail),
                tail, sizeof (tail))) {
        Messages_SendError(playerid, "Format: KODE harga (contoh: MAKANAN 5000)");
        return;
    }
    new price = strval(priceText);
    if (price < 1 || price > 9999999) {
        Messages_SendError(playerid, "Harga Rp 1 - Rp 9.999.999.");
        return;
    }
    if (Inv_ItemFromCode(itemCode) < 0) {
        Messages_SendError(playerid, "Kode barang tidak ada di katalog.");
        return;
    }

    new warung = Property_WarungOf(index);
    if (warung < 0) {
        Messages_SendError(playerid, "Gedung ini tidak punya toko.");
        return;
    }
    new escapedCode[WAR_ITEM_CODE_LEN * 2 + 1];
    DB_Escape(escapedCode, sizeof (escapedCode), itemCode);
    new query[192];
    format(query, sizeof (query),
        "INSERT OR REPLACE INTO warung_items (warung_id, code, price) \
         VALUES (%d, '%s', %d)", Warung_IdOf(warung), escapedCode, price);
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return;
    }
    Warung_Reload();
    new message[80];
    format(message, sizeof (message), "%s masuk menu (Rp %d).", itemCode,
        price);
    Messages_SendSystem(playerid, message);
}

// Router dialog kelola + pembelian gedung.
stock bool:Property_OnDialogResponse(playerid, dialogid, response, listitem,
    const inputtext[]) {
    if (dialogid == DIALOG_PROP_SALE) {
        new index = Property_DlgIndex(playerid);
        Property_Reset(playerid);
        if (!response || index < 0) return true;
        Property_Buy(playerid, index);
        return true;
    }
    if (dialogid == DIALOG_PROP_MENU) {
        if (!response) return true;
        new index = Property_DlgIndex(playerid);
        if (index < 0) return true;
        switch (listitem) {
            case 0: Property_ToggleOpen(playerid, index);
            case 1: ShowPlayerDialog(playerid, _:DIALOG_PROP_ADDITEM,
                        DIALOG_STYLE_INPUT, "Tambah Menu",
                        "Format: KODE harga\nContoh: MAKANAN 5000",
                        "Simpan", "Batal");
            case 2: Property_ShowPickItem(playerid, index, PROP_MODE_SET_PRICE);
            case 3: Property_ShowPickItem(playerid, index, PROP_MODE_DELETE);
            case 4: Property_CollectKas(playerid, index);
            case 5: Property_ShowInfo(playerid, index);
        }
        return true;
    }
    if (dialogid == DIALOG_PROP_PICKITEM) {
        new index = Property_DlgIndex(playerid);
        new mode = Property_DlgMode(playerid);
        if (!response) {
            Property_Reset(playerid);
            Property_ManageOpen(playerid, index);
            return true;
        }
        if (mode == PROP_MODE_SET_PRICE) {
            Property_SetDlg(playerid, index, mode, listitem);
            ShowPlayerDialog(playerid, _:DIALOG_PROP_PRICE, DIALOG_STYLE_INPUT,
                "Atur Harga", "Masukkan harga baru (rupiah):",
                "Simpan", "Batal");
        } else if (mode == PROP_MODE_DELETE) {
            Property_DeleteItem(playerid, index, listitem);
            Property_ManageOpen(playerid, index);
        }
        return true;
    }
    if (dialogid == DIALOG_PROP_PRICE) {
        new index = Property_DlgIndex(playerid);
        new slot = Property_DlgSlot(playerid);
        Property_Reset(playerid);
        if (!response || index < 0 || slot < 0) return true;
        new price = strval(inputtext);
        if (price < 1 || price > 9999999) {
            Messages_SendError(playerid, "Harga Rp 1 - Rp 9.999.999.");
        } else {
            Property_SetItemPrice(playerid, index, slot, price);
        }
        Property_ManageOpen(playerid, index);
        return true;
    }
    if (dialogid == DIALOG_PROP_ADDITEM) {
        new index = Property_DlgIndex(playerid);
        Property_Reset(playerid);
        if (!response || index < 0) return true;
        Property_AddItem(playerid, index, inputtext);
        Property_ManageOpen(playerid, index);
        return true;
    }
    return false;
}

