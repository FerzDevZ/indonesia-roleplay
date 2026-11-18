// ---------------------------------------------------------------------------
// module      : domain/vehicle/vehicle_rental_admin
// entry       : -
// depends     : domain/vehicle/vehicle_rental_data, domain/world/locations,
//               domain/admin (Admin_Require, Admin_Audit), shared/validate
//               (Command_NextToken), shared/messages, shared/admin_level
// owns tables : - (tabel rental_packages & rental_sites milik rental_data)
// public api  : VehicleRentalAdmin_HandleCommand()
// Isi         : Perintah admin rental kendaraan tanpa compile ulang:
//               /buatrental <nama>, /hapusrental, /rentalspawn,
//               /rentalpkg (daftar), /rentalpkg tambah <model> <harga> <menit>
//               <nama>, /rentalpkg hapus <nomor>, /rentalreload.
// Aturan      : Target selalu titik rental terdekat dari admin. Semua
//               perubahan dicatat lewat Admin_Audit dan cache di-reload.
// ---------------------------------------------------------------------------
#if defined _INC_VEHICLE_RENTAL_ADMIN
    #endinput
#endif
#define _INC_VEHICLE_RENTAL_ADMIN

static VehicleRentalAdmin_FindSite(playerid) {
    new site = Locations_NearCode(playerid, LOC_ACT_RENTAL);
    if (site < 0) {
        Messages_SendError(playerid,
            "Kamu tidak berada di titik rental. Berdiri di titik rental dulu.");
    }
    return site;
}

// /buatrental <nama> - titik rental baru di posisi admin, kendaraan muncul
// 6 meter di depan admin mengikuti arah hadap.
static VehicleRentalAdmin_Create(playerid, const rawName[]) {
    new name[LOC_NAME_LEN];
    format(name, sizeof (name), "%s", rawName);
    if (strlen(name) < 3) {
        Messages_SendError(playerid, "Nama minimal 3 huruf.");
        return 1;
    }

    new code[LOC_CODE_LEN];
    format(code, sizeof (code), "RENTAL_%d", gettime() % 100000);

    new Float:posX, Float:posY, Float:posZ;
    GetPlayerPos(playerid, posX, posY, posZ);

    new locationIndex = Locations_Add(code, name, LOC_ACT_RENTAL,
        posX, posY, posZ, 3.0);
    if (locationIndex < 0) {
        Messages_SendError(playerid, "Titik rental gagal dibuat (daftar penuh).");
        return 1;
    }

    new Float:angle;
    GetPlayerFacingAngle(playerid, angle);
    new Float:radians = angle * 3.14159265 / 180.0;
    new Float:spawnX = posX - floatsin(radians) * 6.0;
    new Float:spawnY = posY + floatcos(radians) * 6.0;
    if (!Rental_SetSiteSpawn(code, spawnX, spawnY, posZ, angle)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return 1;
    }

    new message[128];
    format(message, sizeof (message),
        "Titik rental '%s' dibuat (%s). Atur posisi kendaraan: /rentalspawn",
        name, code);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "RENTAL_CREATE", -1, code);
    return 1;
}

static VehicleRentalAdmin_Delete(playerid) {
    new site = VehicleRentalAdmin_FindSite(playerid);
    if (site < 0) return 1;

    new code[LOC_CODE_LEN], name[LOC_NAME_LEN], message[128];
    Locations_Code(site, code, sizeof (code));
    Locations_Name(site, name, sizeof (name));

    Rental_DeleteSite(code);
    if (!Locations_Delete(site)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return 1;
    }

    format(message, sizeof (message), "Titik rental '%s' dihapus.", name);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "RENTAL_DELETE", -1, code);
    return 1;
}

// /rentalspawn - posisi & arah spawn kendaraan diset dari posisi admin.
static VehicleRentalAdmin_SetSpawn(playerid) {
    new site = VehicleRentalAdmin_FindSite(playerid);
    if (site < 0) return 1;

    new code[LOC_CODE_LEN];
    Locations_Code(site, code, sizeof (code));

    new Float:posX, Float:posY, Float:posZ, Float:angle;
    GetPlayerPos(playerid, posX, posY, posZ);
    GetPlayerFacingAngle(playerid, angle);

    if (!Rental_SetSiteSpawn(code, posX, posY, posZ + 0.2, angle)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return 1;
    }

    Messages_SendSystem(playerid,
        "Posisi spawn kendaraan rental diperbarui sesuai posisimu.");
    Admin_Audit(playerid, "RENTAL_SPAWN", -1, code);
    return 1;
}

static VehicleRentalAdmin_List(playerid) {
    new total = Rental_PackageCount();
    if (total <= 0) {
        Messages_SendSystem(playerid,
            "Belum ada paket. Tambah: /rentalpkg tambah 462 5000 5 Motor Faggio");
        return 1;
    }

    new header[32];
    format(header, sizeof (header), "=== PAKET RENTAL (%d) ===", total);
    Messages_SendSystem(playerid, header);

    for (new index = 0; index < total; index++) {
        new name[24], priceText[24], line[128];
        Rental_PackageName(index, name, sizeof (name));
        Messages_Money(Rental_PackagePrice(index), priceText, sizeof (priceText));
        format(line, sizeof (line), "%d. %s | model %d | %s | %d menit",
            index + 1, name, Rental_PackageModel(index), priceText,
            Rental_PackageMinutes(index));
        Messages_SendSystem(playerid, line);
    }
    Messages_SendSystem(playerid,
        "Ubah: /rentalpkg tambah <model> <harga> <menit> <nama> | /rentalpkg hapus <nomor>");
    return 1;
}

static VehicleRentalAdmin_AddPackage(playerid, const params[]) {
    new modelText[12], priceText[12], rest[96], minutesText[12], tail[64];

    if (!Command_NextToken(params, modelText, sizeof (modelText),
            priceText, sizeof (priceText))
        || !Command_NextToken(priceText, rest, sizeof (rest),
            rest, sizeof (rest))) {
        Messages_SendError(playerid,
            "Pakai: /rentalpkg tambah 462 5000 5 Motor Faggio");
        return 1;
    }
    if (!Command_NextToken(rest, minutesText, sizeof (minutesText),
            tail, sizeof (tail)) || tail[0] == '\0') {
        Messages_SendError(playerid,
            "Pakai: /rentalpkg tambah 462 5000 5 Motor Faggio");
        return 1;
    }

    new model = strval(modelText);
    new price = strval(priceText);
    new minutes = strval(minutesText);

    if (model < 400 || model > 611) {
        Messages_SendError(playerid,
            "Model kendaraan darat 400 - 611. Contoh: 462 (Faggio), 507 (Elegant).");
        return 1;
    }
    if (price < 100 || price > 10000000) {
        Messages_SendError(playerid, "Harga Rp 100 - Rp 10.000.000.");
        return 1;
    }
    if (minutes < 1 || minutes > 120) {
        Messages_SendError(playerid, "Durasi 1 - 120 menit.");
        return 1;
    }

    if (!Rental_AddPackage(tail, model, price, minutes)) {
        Messages_SendError(playerid,
            "Paket gagal ditambah (slot penuh atau DB menolak).");
        return 1;
    }

    new message[128];
    format(message, sizeof (message),
        "Paket '%s' ditambah: model %d, Rp %d, %d menit.",
        tail, model, price, minutes);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "RENTAL_PKG_ADD", -1, tail);
    return 1;
}

static VehicleRentalAdmin_RemovePackage(playerid, const params[]) {
    if (params[0] == '\0') {
        Messages_SendError(playerid, "Pakai: /rentalpkg hapus <nomor>");
        return 1;
    }

    new number = strval(params);
    new index = number - 1;
    if (index < 0 || index >= Rental_PackageCount()) {
        Messages_SendError(playerid, "Nomor paket tidak ada. Lihat /rentalpkg.");
        return 1;
    }

    new name[24];
    Rental_PackageName(index, name, sizeof (name));
    if (!Rental_RemovePackage(index)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return 1;
    }

    new message[96];
    format(message, sizeof (message), "Paket '%s' dinonaktifkan.", name);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "RENTAL_PKG_DEL", -1, name);
    return 1;
}

static VehicleRentalAdmin_HandlePackage(playerid, const params[]) {
    if (params[0] == '\0') {
        VehicleRentalAdmin_List(playerid);
        return 1;
    }

    new action[12], rest[128];
    if (!Command_NextToken(params, action, sizeof (action),
            rest, sizeof (rest))) {
        VehicleRentalAdmin_List(playerid);
        return 1;
    }

    if (!strcmp(action, "tambah", true)) {
        VehicleRentalAdmin_AddPackage(playerid, rest);
        return 1;
    }
    if (!strcmp(action, "hapus", true)) {
        VehicleRentalAdmin_RemovePackage(playerid, rest);
        return 1;
    }

    Messages_SendError(playerid,
        "Pakai: /rentalpkg | /rentalpkg tambah <model> <harga> <menit> <nama> | /rentalpkg hapus <nomor>");
    return 1;
}

stock bool:VehicleRentalAdmin_HandleCommand(playerid, const command[],
    const params[]) {
    new bool:matched = false;
    if (!strcmp(command, "buatrental", true)
            || !strcmp(command, "hapusrental", true)
            || !strcmp(command, "rentalspawn", true)
            || !strcmp(command, "rentalpkg", true)
            || !strcmp(command, "rentalreload", true)) {
        matched = true;
    }
    if (!matched) return false;

    if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;

    if (!strcmp(command, "buatrental", true)) {
        if (params[0] == '\0') {
            Messages_SendError(playerid,
                "Pakai: /buatrental <nama> | contoh: /buatrental Rental Stasiun");
            return true;
        }
        VehicleRentalAdmin_Create(playerid, params);
        return true;
    }
    if (!strcmp(command, "hapusrental", true)) {
        VehicleRentalAdmin_Delete(playerid);
        return true;
    }
    if (!strcmp(command, "rentalspawn", true)) {
        VehicleRentalAdmin_SetSpawn(playerid);
        return true;
    }
    if (!strcmp(command, "rentalpkg", true)) {
        VehicleRentalAdmin_HandlePackage(playerid, params);
        return true;
    }
    if (!strcmp(command, "rentalreload", true)) {
        new total = Rental_Reload();
        new message[64];
        format(message, sizeof (message), "%d paket rental dimuat ulang.", total);
        Messages_SendSystem(playerid, message);
        Admin_Audit(playerid, "RENTAL_RELOAD", -1, message);
        return true;
    }
    return false;
}
