// ---------------------------------------------------------------------------
// module      : domain/warung/warung_admin
// entry       : -
// depends     : domain/warung (Warung_Near, Warung_Reload, gWar* via api),
//               domain/admin (Admin_Require, Admin_Audit), core/text
//               (Command_NextToken), shared/messages, core/db, core/log,
//               domain/world/locations, domain/inventory
// owns tables : -
// public api  : WarungAdmin_HandleCommand()
// Isi         : Perintah admin warung in-game tanpa compile ulang (tahap 2):
//               /buatwarung <nama> (lokasi + warung di posisi admin),
//               /tambahmenu <KODE> <harga>, /setharga <KODE> <harga>,
//               /hapusmenu <KODE>, /tutupwarung, /bukawarung. Target selalu
//               warung terdekat dari posisi admin. Semua perubahan ditulis
//               ke DB lalu Warung_Reload(), dan dicatat lewat Admin_Audit.
// Aturan      : Parsing tanpa sscanf (Command_NextToken); harga 1..9.999.999.
// ---------------------------------------------------------------------------
#if defined _INC_DOMAIN_WARUNG_ADMIN
    #endinput
#endif
#define _INC_DOMAIN_WARUNG_ADMIN

static WarungAdmin_Create(playerid, const name[]) {
    new code[LOC_CODE_LEN];
    format(code, sizeof (code), "WARUNG_%d", gettime() % 100000);

    new Float:posX, Float:posY, Float:posZ;
    GetPlayerPos(playerid, posX, posY, posZ);
    new locIndex = Locations_Add(code, name, LOC_ACT_WARUNG,
        posX, posY, posZ, 3.0);
    if (locIndex < 0) {
        Messages_SendError(playerid, "Warung gagal dibuat (daftar penuh).");
        return 1;
    }

    new escapedName[WAR_NAME_LEN * 2 + 1];
    DB_Escape(escapedName, sizeof (escapedName), name);
    new query[256];
    format(query, sizeof (query),
        "INSERT OR IGNORE INTO warungs (location_code, name) \
         VALUES ('%s', '%s')", code, escapedName);
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return 1;
    }

    Warung_Reload();
    new message[96];
    format(message, sizeof (message), "Warung '%s' dibuat di posisimu (%s).",
        name, code);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "WARUNG_CREATE", -1, code);
    return 1;
}

static bool:WarungAdmin_RequireNear(playerid, &warung) {
    warung = Warung_Near(playerid);
    if (warung < 0) {
        Messages_SendError(playerid, "Kamu tidak berada di warung mana pun.");
        return false;
    }
    return true;
}

static WarungAdmin_AddItem(playerid, const itemCode[], price) {
    new warung, warungName[WAR_NAME_LEN];
    if (!WarungAdmin_RequireNear(playerid, warung)) return 1;
    Warung_NameOf(warung, warungName);
    if (Inv_ItemFromCode(itemCode) < 0) {
        Messages_SendError(playerid, "Kode barang tidak ada di katalog.");
        return 1;
    }

    new escapedCode[WAR_ITEM_CODE_LEN * 2 + 1];
    DB_Escape(escapedCode, sizeof (escapedCode), itemCode);
    new query[256];
    format(query, sizeof (query),
        "INSERT OR REPLACE INTO warung_items (warung_id, code, price) \
         VALUES (%d, '%s', %d)", Warung_IdOf(warung), escapedCode, price);
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return 1;
    }

    Warung_Reload();
    new message[96];
    format(message, sizeof (message), "%s ditambahkan ke %s (Rp %d).",
        itemCode, warungName, price);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "WARUNG_MENU_ADD", -1, itemCode);
    return 1;
}

static WarungAdmin_SetPrice(playerid, const itemCode[], price) {
    new warung, warungName[WAR_NAME_LEN];
    if (!WarungAdmin_RequireNear(playerid, warung)) return 1;
    Warung_NameOf(warung, warungName);

    new escapedCode[WAR_ITEM_CODE_LEN * 2 + 1];
    DB_Escape(escapedCode, sizeof (escapedCode), itemCode);
    new query[256];
    format(query, sizeof (query),
        "UPDATE warung_items SET price = %d \
         WHERE warung_id = %d AND code = '%s'",
        price, Warung_IdOf(warung), escapedCode);
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return 1;
    }

    Warung_Reload();
    new message[96];
    format(message, sizeof (message), "Harga %s di %s: Rp %d.", itemCode,
        warungName, price);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "WARUNG_PRICE", -1, itemCode);
    return 1;
}

static WarungAdmin_RemoveItem(playerid, const itemCode[]) {
    new warung, warungName[WAR_NAME_LEN];
    if (!WarungAdmin_RequireNear(playerid, warung)) return 1;
    Warung_NameOf(warung, warungName);

    new escapedCode[WAR_ITEM_CODE_LEN * 2 + 1];
    DB_Escape(escapedCode, sizeof (escapedCode), itemCode);
    new query[256];
    format(query, sizeof (query),
        "DELETE FROM warung_items WHERE warung_id = %d AND code = '%s'",
        Warung_IdOf(warung), escapedCode);
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return 1;
    }

    Warung_Reload();
    new message[96];
    format(message, sizeof (message), "%s dihapus dari %s.", itemCode,
        warungName);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "WARUNG_MENU_DEL", -1, itemCode);
    return 1;
}

static WarungAdmin_ToggleOpen(playerid, bool:open) {
    new warung, warungName[WAR_NAME_LEN];
    if (!WarungAdmin_RequireNear(playerid, warung)) return 1;
    Warung_NameOf(warung, warungName);

    new query[128];
    format(query, sizeof (query),
        "UPDATE warungs SET is_open = %d WHERE warung_id = %d",
        open ? 1 : 0, Warung_IdOf(warung));
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return 1;
    }

    Warung_Reload();
    new message[64];
    format(message, sizeof (message), "%s sekarang %s.", warungName,
        open ? "BUKA" : "TUTUP");
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "WARUNG_TOGGLE", -1, open ? "open" : "closed");
    return 1;
}

// Router perintah admin warung (rantai OnPlayerCommandText, sebelum Admin).
stock bool:WarungAdmin_HandleCommand(playerid, const command[], const params[]) {
    new bool:matched = false;
    if (!strcmp(command, "buatwarung", true)
            || !strcmp(command, "tambahmenu", true)
            || !strcmp(command, "setharga", true)
            || !strcmp(command, "hapusmenu", true)
            || !strcmp(command, "tutupwarung", true)
            || !strcmp(command, "bukawarung", true)) {
        matched = true;
    }
    if (!matched) return false;

    if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;

    if (!strcmp(command, "buatwarung", true)) {
        if (params[0] == '\0') {
            Messages_SendError(playerid, "Pakai: /buatwarung <nama>");
            return true;
        }
        WarungAdmin_Create(playerid, params);
        return true;
    }
    if (!strcmp(command, "tambahmenu", true)) {
        new itemCode[WAR_ITEM_CODE_LEN], priceText[12], tail[32];
        if (!Command_NextToken(params, itemCode, sizeof (itemCode),
                priceText, sizeof (priceText)) || priceText[0] == '\0'
                || Command_NextToken(priceText, tail, sizeof (tail),
                    tail, sizeof (tail))) {
            Messages_SendError(playerid, "Pakai: /tambahmenu <KODE> <harga>");
            return true;
        }
        new price = strval(priceText);
        if (price < 1 || price > 9999999) {
            Messages_SendError(playerid, "Harga Rp 1 - Rp 9.999.999.");
            return true;
        }
        WarungAdmin_AddItem(playerid, itemCode, price);
        return true;
    }
    if (!strcmp(command, "setharga", true)) {
        new itemCode[WAR_ITEM_CODE_LEN], priceText[12], tail[32];
        if (!Command_NextToken(params, itemCode, sizeof (itemCode),
                priceText, sizeof (priceText)) || priceText[0] == '\0'
                || Command_NextToken(priceText, tail, sizeof (tail),
                    tail, sizeof (tail))) {
            Messages_SendError(playerid, "Pakai: /setharga <KODE> <harga>");
            return true;
        }
        new price = strval(priceText);
        if (price < 1 || price > 9999999) {
            Messages_SendError(playerid, "Harga Rp 1 - Rp 9.999.999.");
            return true;
        }
        WarungAdmin_SetPrice(playerid, itemCode, price);
        return true;
    }
    if (!strcmp(command, "hapusmenu", true)) {
        if (params[0] == '\0') {
            Messages_SendError(playerid, "Pakai: /hapusmenu <KODE>");
            return true;
        }
        WarungAdmin_RemoveItem(playerid, params);
        return true;
    }
    if (!strcmp(command, "tutupwarung", true)) {
        WarungAdmin_ToggleOpen(playerid, false);
        return true;
    }
    WarungAdmin_ToggleOpen(playerid, true);
    return true;
}
