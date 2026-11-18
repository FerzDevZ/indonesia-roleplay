// ---------------------------------------------------------------------------
// module      : domain/vehicle/vehicle_rental
// entry       : VehicleRental_Boot()
// depends     : domain/vehicle/vehicle, domain/vehicle/vehicle_rental_data,
//               domain/world/locations, shared/money, shared/messages,
//               shared/player_phase, ui/toast, ui/uimodal
// owns tables : - (paket & titik spawn milik vehicle_rental_data)
// public api  : VehicleRental_Boot(), VehicleRental_Open(),
//               VehicleRental_OnDialogResponse(), VehicleRental_HandleCommand()
// Aturan      : harga, durasi, dan model kendaraan TIDAK hardcode di file ini -
//               semuanya dibaca dari `rental_packages` lewat Rental_* sehingga
//               admin bisa mengubah layanan tanpa compile ulang. Titik rental
//               adalah lokasi beraksi RENTAL di tabel `locations`.
// ---------------------------------------------------------------------------
#if defined _INC_VEHICLE_RENTAL
    #endinput
#endif
#define _INC_VEHICLE_RENTAL

#define RENTAL_RETURN_RANGE (25.0)  // jarak maksimal saat /kembalikan
#define RENTAL_SLOT_STEP    (3.2)   // jarak antar kendaraan dalam satu titik

// Lokasi sewa terakhir yang dibuka per pemain (dipakai saat memilih paket).
static gRentalSite[MAX_PLAYERS] = { -1, ... };

stock VehicleRental_Boot() {
    Rental_Boot();
    Log_Info("vehicle", "layanan rental siap");
    return 1;
}

// Daftar paket untuk dialog. Setiap baris = satu item dialog.
static VehicleRental_BuildList(dest[], maxlength) {
    dest[0] = EOS;
    for (new index = 0; index < Rental_PackageCount(); index++) {
        new name[24], priceText[24], line[96];
        Rental_PackageName(index, name, sizeof (name));
        Messages_Money(Rental_PackagePrice(index), priceText, sizeof (priceText));
        format(line, sizeof (line), "%s - %s / %d menit\n",
            name, priceText, Rental_PackageMinutes(index));
        strcat(dest, line, maxlength);
    }
    return 1;
}

stock bool:VehicleRental_Open(playerid) {
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return false;
    }
    if (UIModal_Active(playerid) != UI_NONE) {
        Messages_SendError(playerid, "Tutup tampilan yang terbuka dulu.");
        return false;
    }
    if (Vehicle_SecondsLeft(playerid) > 0) {
        Messages_SendError(playerid,
            "Kamu masih menyewa kendaraan. Kembalikan dengan /kembalikan.");
        return false;
    }
    if (Rental_PackageCount() <= 0) {
        Messages_SendError(playerid,
            "Belum ada paket rental. Hubungi admin server.");
        return false;
    }

    new site = Locations_NearCode(playerid, LOC_ACT_RENTAL);
    if (site < 0) {
        Messages_SendError(playerid,
            "Rental kendaraan hanya bisa di titik rental (ikon mobil di radar).");
        return false;
    }

    gRentalSite[playerid] = site;

    new body[384], siteName[LOC_NAME_LEN];
    VehicleRental_BuildList(body, sizeof (body));
    Locations_Name(site, siteName, sizeof (siteName));
    ShowPlayerDialog(playerid, DIALOG_RENTAL_LIST, DIALOG_STYLE_LIST, siteName,
        body, "Sewa", "Batal");
    return true;
}

// Sewa kendaraan: cek uang dulu, baru spawn, baru potong saldo. Kalau spawn
// gagal, saldo tidak pernah tersentuh.
static bool:VehicleRental_Rent(playerid, packageIndex) {
    if (packageIndex < 0 || packageIndex >= Rental_PackageCount()) return false;

    // Indeks lokasi bisa bergeser kalau admin menghapus titik saat dialog
    // terbuka, jadi resolusi ulang dari posisi pemain (fallback: indeks lama).
    new site = Locations_NearCode(playerid, LOC_ACT_RENTAL);
    if (site < 0) site = gRentalSite[playerid];
    if (site < 0 || !Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return false;
    }

    new price = Rental_PackagePrice(packageIndex);
    if (Money_GetCash(playerid) < price) {
        Messages_SendError(playerid, "Uang tunai tidak cukup. Ambil di ATM dulu.");
        return false;
    }

    new code[LOC_CODE_LEN];
    Locations_Code(site, code, sizeof (code));

    new Float:spawnX, Float:spawnY, Float:spawnZ, Float:angle;
    if (!Rental_SiteSpawn(code, spawnX, spawnY, spawnZ, angle)) {
        Messages_SendError(playerid, "Titik spawn rental belum diatur admin.");
        return false;
    }

    // Kendaraan berdampingan tegak lurus arah hadap titik rental, supaya paket
    // kedua/ketiga tidak menumpuk di posisi yang sama.
    new Float:radians = angle * 3.14159265 / 180.0;
    new Float:step = RENTAL_SLOT_STEP * float(packageIndex);
    new Float:offsetX = floatcos(radians) * step;
    new Float:offsetY = floatsin(radians) * step;

    new slot = Vehicle_Spawn(playerid, Rental_PackageModel(packageIndex),
        spawnX + offsetX, spawnY + offsetY, spawnZ, angle,
        Rental_PackageMinutes(packageIndex) * 60);
    if (slot == VEH_NONE) {
        Messages_SendError(playerid, "Kendaraan gagal disiapkan. Coba lagi.");
        return false;
    }

    if (!Money_Take(playerid, price, MONEY_REASON_RENTAL)) {
        Vehicle_Despawn(slot);
        Messages_SendError(playerid, "Pembayaran gagal. Sewa dibatalkan.");
        return false;
    }

    new name[24], priceText[24], message[128];
    Rental_PackageName(packageIndex, name, sizeof (name));
    Messages_Money(price, priceText, sizeof (priceText));
    format(message, sizeof (message),
        "%s siap dipakai selama %d menit (%s). Kembalikan: /kembalikan",
        name, Rental_PackageMinutes(packageIndex), priceText);
    Toast_Show(playerid, "RENTAL", message, THEME_OK);
    Messages_SendSystem(playerid, message);
    return true;
}

// Kembalikan kendaraan lebih awal. Tanpa refund: harga sewa sudah hangus.
static bool:VehicleRental_Return(playerid) {
    new slot = Vehicle_SlotOf(playerid);
    if (slot < 0) {
        Messages_SendError(playerid, "Kamu tidak sedang menyewa kendaraan.");
        return false;
    }

    new vehicleid = Vehicle_IdOf(slot);
    if (IsValidVehicle(vehicleid)) {
        new Float:vehicleX, Float:vehicleY, Float:vehicleZ;
        GetVehiclePos(vehicleid, vehicleX, vehicleY, vehicleZ);
        new Float:playerX, Float:playerY, Float:playerZ;
        GetPlayerPos(playerid, playerX, playerY, playerZ);
        new Float:deltaX = playerX - vehicleX;
        new Float:deltaY = playerY - vehicleY;
        new Float:distance = floatsqroot(deltaX * deltaX + deltaY * deltaY);
        if (distance > RENTAL_RETURN_RANGE) {
            Messages_SendError(playerid,
                "Mendekatlah ke kendaraanmu dulu (maksimal 25 meter).");
            return false;
        }
    }

    new name[24], message[96];
    Vehicle_NameOf(Vehicle_ModelOfPlayer(playerid), name, sizeof (name));
    Vehicle_Despawn(slot);
    format(message, sizeof (message), "%s sudah dikembalikan.", name);
    Toast_Show(playerid, "RENTAL", message, THEME_INFO);
    Messages_SendSystem(playerid, message);
    return true;
}

stock bool:VehicleRental_OnDialogResponse(playerid, dialogid, response,
    listitem, const inputtext[]) {
    #pragma unused inputtext
    if (dialogid != DIALOG_RENTAL_LIST) return false;

    if (!response) {
        gRentalSite[playerid] = -1;
        Messages_SendSystem(playerid, "Sewa kendaraan dibatalkan.");
        return true;
    }
    VehicleRental_Rent(playerid, listitem);
    gRentalSite[playerid] = -1;
    return true;
}

stock bool:VehicleRental_HandleCommand(playerid, const command[],
    const params[]) {
    #pragma unused params

    if (!strcmp(command, "rental", true) || !strcmp(command, "sewa", true)) {
        VehicleRental_Open(playerid);
        return true;
    }
    if (!strcmp(command, "kembalikan", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        VehicleRental_Return(playerid);
        return true;
    }
    if (!strcmp(command, "kendaraan", true)) {
        new slot = Vehicle_SlotOf(playerid);
        if (slot < 0) {
            Messages_SendError(playerid,
                "Kamu tidak menyewa kendaraan. Cari titik rental di radar.");
            return true;
        }
        new name[24], message[128];
        Vehicle_NameOf(Vehicle_ModelOfPlayer(playerid), name, sizeof (name));
        format(message, sizeof (message), "%s sewaan, sisa waktu %d detik.",
            name, Vehicle_SecondsLeft(playerid));
        Messages_SendSystem(playerid, message);
        return true;
    }
    return false;
}
