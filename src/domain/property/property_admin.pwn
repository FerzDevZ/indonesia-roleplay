// ---------------------------------------------------------------------------
// module      : domain/property/property_admin
// entry       : -
// depends     : domain/property (API), domain/world/interiors, domain/admin
//               (Admin_Require/Audit), core/db, core/text (Command_NextToken),
//               shared/messages, ui/toast
// owns tables : -
// public api  : PropertyAdmin_HandleCommand()
// Isi         : Perintah admin gedung: /buatgedung <nama> <interior> <harga>
//               (nama boleh pakai spasi; interior 0-2; otomatis membuat
//               lokasi + warung + gedung + mapping), /setinterior <0-2>
//               (berdiri dekat gedung), daftar blueprint tanpa angka.
// Aturan      : Parsing tanpa sscanf; semua aksi tercatat di Admin_Audit.
// ---------------------------------------------------------------------------
#if defined _INC_DOMAIN_PROPERTY_ADMIN
    #endinput
#endif
#define _INC_DOMAIN_PROPERTY_ADMIN

// --- Admin: interior mapping custom ---
static PropertyAdmin_FindNear(playerid) {
    new locIndex = Locations_Near(playerid);
    if (locIndex < 0) return -1;
    new code[LOC_CODE_LEN];
    Locations_Code(locIndex, code, sizeof (code));
    return Property_FindByLocation(code);
}

static bool:PropertyAdmin_SetInterior(playerid, const params[]) {
    new index = PropertyAdmin_FindNear(playerid);
    if (index < 0) {
        Messages_SendError(playerid, "Berdiri di dekat gedung dulu.");
        return true;
    }
    if (params[0] == '\0') {
        new list[96], line[48];
        for (new bp = 1; bp <= INT_BLUEPRINT_MAX; bp++) {
            new name[24];
            Interiors_NameOf(bp, name, sizeof (name));
            format(line, sizeof (line), "%d = %s\n", bp, name);
            strcat(list, line);
        }
        Messages_SendSystem(playerid, list);
        return true;
    }
    new blueprint = strval(params);
    if (blueprint < 0 || blueprint > INT_BLUEPRINT_MAX) {
        Messages_SendError(playerid, "Blueprint 0-2 saja (0 = hapus).");
        return true;
    }
    if (!Interiors_SetForBuilding(index, blueprint)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return true;
    }
    new name[24], message[80];
    Interiors_NameOf(blueprint, name, sizeof (name));
    format(message, sizeof (message), "Interior gedung: %s.", name);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "GEDUNG_INTERIOR", -1, name);
    return true;
}

#define PROP_MIN_SPACING (6.0)   // jarak minimum antar gedung (meter)

// Tolak gedung baru yang menumpuk dengan gedung lain: pickup + label bertumpuk
// membuat pemain tidak bisa memilih interaksi yang benar.
static bool:PropertyAdmin_TooNear(Float:posX, Float:posY) {
    for (new locIndex = 0; locIndex < Locations_Count(); locIndex++) {
        new code[LOC_CODE_LEN];
        Locations_Code(locIndex, code, sizeof (code));
        if (Property_FindByLocation(code) < 0) continue;

        new Float:otherX, Float:otherY, Float:otherZ;
        Locations_Pos(locIndex, otherX, otherY, otherZ);
        new Float:deltaX = otherX - posX;
        new Float:deltaY = otherY - posY;
        if (floatsqroot(deltaX * deltaX + deltaY * deltaY) < PROP_MIN_SPACING) {
            return true;
        }
    }
    return false;
}

// --- Admin: /buatgedung <nama bisa spasi> <interior> <harga> ---
// Contoh: /buatgedung Toko Sinar Jaya 1 500000
//   nama = "Toko Sinar Jaya", interior = 1, harga = 500000.
// Interior: 0 = tanpa interior, 1 = Warung Kelontong, 2 = Minimarket.
static bool:PropertyAdmin_Create(playerid, const params[]) {
    // Pecah semua token: token terakhir = harga, sebelumnya = interior,
    // sisanya digabung jadi nama gedung (boleh pakai spasi).
    new tokens[10][24], tokenCount = 0, remaining[96];
    format(remaining, sizeof (remaining), "%s", params);
    while (tokenCount < 10) {
        new token[24], rest[96];
        if (!Command_NextToken(remaining, token, sizeof (token), rest,
                sizeof (rest))) break;
        format(tokens[tokenCount], 24, "%s", token);
        format(remaining, sizeof (remaining), "%s", rest);
        tokenCount++;
    }
    if (tokenCount < 3) {
        Messages_SendError(playerid,
            "Pakai: /buatgedung <nama> <interior> <harga>");
        Messages_SendSystem(playerid,
            "Contoh: /buatgedung Toko Sinar 1 500000");
        Messages_SendSystem(playerid,
            "Interior: 0 = kosong, 1 = Warung Kelontong, 2 = Minimarket");
        return true;
    }

    new price = strval(tokens[tokenCount - 1]);
    new blueprint = strval(tokens[tokenCount - 2]);
    if (price < 1 || price > 999999999) {
        Messages_SendError(playerid, "Harga Rp 1 - Rp 999.999.999.");
        return true;
    }
    if (blueprint < 0 || blueprint > INT_BLUEPRINT_MAX) {
        Messages_SendError(playerid,
            "Interior 0-2 saja (0 kosong, 1 warung, 2 minimarket).");
        return true;
    }

    // Gabungkan token nama (semua kecuali 2 token terakhir).
    new name[LOC_NAME_LEN];
    for (new i = 0; i < tokenCount - 2; i++) {
        if (i > 0) strcat(name, " ");
        strcat(name, tokens[i]);
    }
    if (strlen(name) < 3) {
        Messages_SendError(playerid, "Nama gedung minimal 3 huruf.");
        return true;
    }

    new code[LOC_CODE_LEN];
    format(code, sizeof (code), "GEDUNG_%d", gettime() % 100000);
    new Float:posX, Float:posY, Float:posZ;
    GetPlayerPos(playerid, posX, posY, posZ);
    if (PropertyAdmin_TooNear(posX, posY)) {
        Messages_SendError(playerid,
            "Terlalu dekat gedung lain (minimal 6 meter).");
        return true;
    }
    new locIndex = Locations_Add(code, name, LOC_ACT_GEDUNG,
        posX, posY, posZ, 3.0);
    if (locIndex < 0) {
        Messages_SendError(playerid, "Gedung gagal dibuat (daftar penuh).");
        return true;
    }

    new escapedName[LOC_NAME_LEN * 2 + 1];
    DB_Escape(escapedName, sizeof (escapedName), name);
    new query[256];
    format(query, sizeof (query),
        "INSERT OR IGNORE INTO warungs (location_code, name) \
         VALUES ('%s', '%s')", code, escapedName);
    DB_Exec(query);
    format(query, sizeof (query),
        "INSERT OR IGNORE INTO buildings (location_code, name, price) \
         VALUES ('%s', '%s', %d)", code, escapedName, price);
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return true;
    }

    Warung_Reload();
    Property_Reload();
    if (blueprint > 0) {
        Interiors_SetForBuilding(Property_Count() - 1, blueprint);
    }

    new message[128], priceMsg[24], interiorName[24];
    Messages_Money(price, priceMsg, sizeof (priceMsg));
    Interiors_NameOf(blueprint, interiorName, sizeof (interiorName));
    format(message, sizeof (message),
        "Gedung '%s' dibuat: dijual %s, interior %s.", name, priceMsg,
        interiorName);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "GEDUNG_CREATE", -1, code);
    return true;
}

stock bool:PropertyAdmin_HandleCommand(playerid, const command[],
    const params[]) {
    if (strcmp(command, "buatgedung", true) == 0) {
        if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;
        return PropertyAdmin_Create(playerid, params);
    }
    if (strcmp(command, "setinterior", true) == 0) {
        if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;
        return PropertyAdmin_SetInterior(playerid, params);
    }
    return false;
}
