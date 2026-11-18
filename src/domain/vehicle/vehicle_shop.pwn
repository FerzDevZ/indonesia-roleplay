// ---------------------------------------------------------------------------
// module      : domain/vehicle/vehicle_shop
// entry       : -
// depends     : domain/vehicle/vehicle_catalog, domain/vehicle/vehicle_owner,
//               domain/world/locations (titik DEALER), shared/messages,
//               shared/player_phase, ui/toast
// owns tables : - (katalog milik vehicle_catalog, kendaraan milik vehicle_owner)
// public api  : VehicleShop_Open(), VehicleShop_OnDialogResponse(),
//               VehicleShop_HandleCommand()
// Isi         : Dealer kendaraan (beli), daftar STNK (/stnk), keluarkan
//               kendaraan pribadi (/pakai), parkir (/parkir).
// Aturan      : Dealer hanya bisa dipakai di lokasi beraksi DEALER; semua
//               transaksi uang lewat shared/money (MONEY_REASON_VEHICLE).
// ---------------------------------------------------------------------------
#if defined _INC_VEHICLE_SHOP
    #endinput
#endif
#define _INC_VEHICLE_SHOP

static VehicleShop_BuildList(dest[], maxlength) {
    dest[0] = EOS;
    for (new index = 0; index < VehicleCatalog_Count(); index++) {
        new name[24], priceText[24], line[96];
        VehicleCatalog_Name(index, name, sizeof (name));
        Messages_Money(VehicleCatalog_Price(index), priceText, sizeof (priceText));
        format(line, sizeof (line), "%s - %s\n", name, priceText);
        strcat(dest, line, maxlength);
    }
    return 1;
}

stock bool:VehicleShop_Open(playerid) {
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return false;
    }
    if (UIModal_Active(playerid) != UI_NONE) {
        Messages_SendError(playerid, "Tutup tampilan yang terbuka dulu.");
        return false;
    }
    if (Locations_NearCode(playerid, LOC_ACT_DEALER) < 0) {
        Messages_SendError(playerid,
            "Dealer kendaraan hanya di titik dealer (ikon mobil di radar).");
        return false;
    }
    if (VehicleCatalog_Count() <= 0) {
        Messages_SendError(playerid, "Katalog dealer kosong. Hubungi admin.");
        return false;
    }
    if (VehicleOwned_Count(playerid) >= OWNED_MAX) {
        Messages_SendError(playerid,
            "Slot kendaraanmu penuh (3). Jual atau parkir permanen dulu.");
        return false;
    }

    new body[384];
    VehicleShop_BuildList(body, sizeof (body));
    ShowPlayerDialog(playerid, DIALOG_DEALER_LIST, DIALOG_STYLE_LIST,
        "Dealer Kendaraan", body, "Beli", "Batal");
    return true;
}

stock bool:VehicleShop_OnDialogResponse(playerid, dialogid, response,
    listitem, const inputtext[]) {
    #pragma unused inputtext
    if (dialogid != DIALOG_DEALER_LIST) return false;

    if (!response) {
        Messages_SendSystem(playerid, "Pembelian dibatalkan.");
        return true;
    }
    VehicleOwned_Buy(playerid, listitem);
    return true;
}

// /stnk - daftar kendaraan milik karakter beserta plat & status parkir.
static bool:VehicleShop_ShowStnk(playerid) {
    new total = VehicleOwned_Count(playerid);
    if (total <= 0) {
        Messages_SendError(playerid,
            "Kamu belum punya kendaraan. Beli di dealer (ikon mobil di radar).");
        return true;
    }

    Messages_SendSystem(playerid, "=== STNK KENDARAAN ===");
    new active = VehicleOwned_Active(playerid);
    for (new index = 0; index < total; index++) {
        new name[24], plate[OWNED_PLATE_LEN], line[128];
        Vehicle_NameOf(VehicleOwned_ModelAt(playerid, index), name, sizeof (name));
        VehicleOwned_PlateAt(playerid, index, plate, sizeof (plate));
        format(line, sizeof (line), "%d. %s | plat %s | %s",
            index + 1, name, plate,
            (index == active) ? "di jalan" : "terparkir");
        Messages_SendSystem(playerid, line);
    }
    Messages_SendSystem(playerid,
        "Keluarkan: /pakai <nomor> | Parkir: /parkir");
    return true;
}

static bool:VehicleShop_Pakai(playerid, const params[]) {
    if (params[0] == '\0') {
        Messages_SendError(playerid,
            "Pakai: /pakai <nomor> | contoh: /pakai 1 (lihat nomor di /stnk)");
        return true;
    }

    new index = strval(params) - 1;
    if (index < 0 || index >= VehicleOwned_Count(playerid)) {
        Messages_SendError(playerid, "Nomor kendaraan tidak ada. Lihat /stnk.");
        return true;
    }
    VehicleOwned_Spawn(playerid, index);
    return true;
}

stock bool:VehicleShop_HandleCommand(playerid, const command[],
    const params[]) {
    if (!strcmp(command, "dealer", true)) {
        VehicleShop_Open(playerid);
        return true;
    }
    if (!strcmp(command, "stnk", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        return VehicleShop_ShowStnk(playerid);
    }
    if (!strcmp(command, "pakai", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        return VehicleShop_Pakai(playerid, params);
    }
    if (!strcmp(command, "parkir", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        VehicleOwned_Park(playerid);
        return true;
    }
    return false;
}

// Perintah admin katalog dealer (level moderator): /dealerkatalog ...
stock bool:VehicleShop_AdminCommand(playerid, const command[],
    const params[]) {
    if (strcmp(command, "dealerkatalog", true) != 0) return false;
    if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;

    if (params[0] == '\0') {
        new header[48];
        format(header, sizeof (header), "=== KATALOG DEALER (%d) ===",
            VehicleCatalog_Count());
        Messages_SendSystem(playerid, header);
        for (new index = 0; index < VehicleCatalog_Count(); index++) {
            new name[24], priceText[24], line[96];
            VehicleCatalog_Name(index, name, sizeof (name));
            Messages_Money(VehicleCatalog_Price(index), priceText,
                sizeof (priceText));
            format(line, sizeof (line), "%d. %s | model %d | %s", index + 1,
                name, VehicleCatalog_Model(index), priceText);
            Messages_SendSystem(playerid, line);
        }
        Messages_SendSystem(playerid,
            "Tambah: /dealerkatalog tambah <model> <harga> <nama> | Hapus: /dealerkatalog hapus <nomor>");
        return true;
    }

    new action[12], rest[96];
    Command_NextToken(params, action, sizeof (action), rest, sizeof (rest));

    if (!strcmp(action, "tambah", true)) {
        new modelText[12], priceText[12], name[CATALOG_NAME_LEN], tail[32];
        if (!Command_NextToken(rest, modelText, sizeof (modelText),
                priceText, sizeof (priceText))
            || !Command_NextToken(priceText, name, sizeof (name),
                tail, sizeof (tail))
            || !Command_NextToken(name, tail, sizeof (tail), tail, sizeof (tail))
            || tail[0] == '\0') {
            Messages_SendError(playerid,
                "Pakai: /dealerkatalog tambah 507 900000 Mobil Elegant");
            return true;
        }

        new model = strval(modelText);
        new price = strval(priceText);
        if (model < 400 || model > 611) {
            Messages_SendError(playerid, "Model kendaraan 400 - 611.");
            return true;
        }
        if (price < 1000 || price > 100000000) {
            Messages_SendError(playerid, "Harga Rp 1.000 - Rp 100.000.000.");
            return true;
        }

        new fullName[CATALOG_NAME_LEN];
        format(fullName, sizeof (fullName), "%s %s", name, tail);
        if (!VehicleCatalog_Add(fullName, model, price)) {
            Messages_SendError(playerid, "Katalog gagal ditambah (penuh/DB).");
            return true;
        }
        Messages_SendSystem(playerid, "Katalog dealer diperbarui.");
        Admin_Audit(playerid, "DEALER_CATALOG_ADD", -1, fullName);
        return true;
    }

    if (!strcmp(action, "hapus", true)) {
        new index = strval(rest) - 1;
        if (index < 0 || index >= VehicleCatalog_Count()) {
            Messages_SendError(playerid, "Nomor tidak ada. Lihat /dealerkatalog.");
            return true;
        }
        new name[24];
        VehicleCatalog_Name(index, name, sizeof (name));
        if (!VehicleCatalog_Remove(index)) {
            Messages_SendError(playerid, MSG_DB_ERROR);
            return true;
        }
        Messages_SendSystem(playerid, "Entri katalog dinonaktifkan.");
        Admin_Audit(playerid, "DEALER_CATALOG_DEL", -1, name);
        return true;
    }

    Messages_SendError(playerid,
        "Pakai: /dealerkatalog | tambah <model> <harga> <nama> | hapus <nomor>");
    return true;
}
