// ---------------------------------------------------------------------------
// module      : domain/vehicle/vehicle_owner
// entry       : VehicleOwned_Boot()
// depends     : domain/vehicle/vehicle (nama model), domain/vehicle/vehicle_catalog,
//               shared/money, shared/messages, core/db, core/log, ui/toast
// owns tables : vehicles
// public api  : VehicleOwned_Boot(), VehicleOwned_Reset(), VehicleOwned_Load(),
//               VehicleOwned_Save(), VehicleOwned_Count(), VehicleOwned_IdAt(),
//               VehicleOwned_ModelAt(), VehicleOwned_PlateAt(),
//               VehicleOwned_Buy(), VehicleOwned_Spawn(), VehicleOwned_Park(),
//               VehicleOwned_Active()
// Aturan      : kendaraan pribadi DISIMPAN di DB (beda dari rental). Posisi &
//               kondisi disimpan saat /parkir, putus koneksi, dan autosave.
// ---------------------------------------------------------------------------
#if defined _INC_VEHICLE_OWNER
    #endinput
#endif
#define _INC_VEHICLE_OWNER

#define OWNED_MAX           (3)
#define OWNED_PLATE_LEN     (16)

static gOwnedCount[MAX_PLAYERS];
static gOwnedId[MAX_PLAYERS][OWNED_MAX];
static gOwnedModel[MAX_PLAYERS][OWNED_MAX];
static gOwnedPlate[MAX_PLAYERS][OWNED_MAX][OWNED_PLATE_LEN];
static gOwnedSpawned[MAX_PLAYERS];
static gOwnedActive[MAX_PLAYERS];

stock VehicleOwned_Boot() {
    if (!DB_Exec("CREATE TABLE IF NOT EXISTS vehicles (\
            vehicle_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            character_id INTEGER NOT NULL,\
            model INTEGER NOT NULL,\
            plate TEXT NOT NULL,\
            pos_x REAL NOT NULL DEFAULT 0.0,\
            pos_y REAL NOT NULL DEFAULT 0.0,\
            pos_z REAL NOT NULL DEFAULT 0.0,\
            angle REAL NOT NULL DEFAULT 0.0,\
            health REAL NOT NULL DEFAULT 1000.0,\
            bought_at TEXT DEFAULT (datetime('now')))")) {
        Log_Error("vehicle", "gagal membuat tabel vehicles");
        return 0;
    }
    if (!DB_Exec("CREATE INDEX IF NOT EXISTS idx_vehicles_owner \
            ON vehicles (character_id)")) {
        Log_Error("vehicle", "gagal membuat index vehicles");
        return 0;
    }

    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        gOwnedCount[playerid] = 0;
        gOwnedSpawned[playerid] = INVALID_VEHICLE_ID;
        gOwnedActive[playerid] = -1;
    }
    Log_Info("vehicle", "kendaraan pribadi siap");
    return 1;
}

static VehicleOwned_ClearCache(playerid) {
    gOwnedCount[playerid] = 0;
    gOwnedSpawned[playerid] = INVALID_VEHICLE_ID;
    gOwnedActive[playerid] = -1;
    for (new index = 0; index < OWNED_MAX; index++) {
        gOwnedId[playerid][index] = 0;
        gOwnedModel[playerid][index] = 0;
        gOwnedPlate[playerid][index][0] = EOS;
    }
    return 1;
}

// Lepas kendaraan fisik (tanpa menyimpan posisi).
stock VehicleOwned_Destroy(playerid) {
    if (gOwnedSpawned[playerid] != INVALID_VEHICLE_ID) {
        if (IsValidVehicle(gOwnedSpawned[playerid])) {
            DestroyVehicle(gOwnedSpawned[playerid]);
        }
    }
    gOwnedSpawned[playerid] = INVALID_VEHICLE_ID;
    gOwnedActive[playerid] = -1;
    return 1;
}

stock VehicleOwned_Reset(playerid) {
    VehicleOwned_Destroy(playerid);
    VehicleOwned_ClearCache(playerid);
    return 1;
}

stock VehicleOwned_Load(playerid, characterId) {
    VehicleOwned_ClearCache(playerid);
    if (characterId <= 0) return 0;

    new query[192];
    format(query, sizeof (query),
        "SELECT COUNT(*) FROM vehicles WHERE character_id = %d", characterId);
    new total = DB_Int(query, 0);
    if (total > OWNED_MAX) total = OWNED_MAX;

    for (new row = 0; row < total; row++) {
        format(query, sizeof (query),
            "SELECT vehicle_id, model, plate FROM vehicles \
             WHERE character_id = %d ORDER BY vehicle_id LIMIT 1 OFFSET %d",
            characterId, row);
        new vehicleId = DB_IntAt(query, 0, 0, 0);
        if (vehicleId <= 0) continue;
        gOwnedId[playerid][gOwnedCount[playerid]] = vehicleId;
        gOwnedModel[playerid][gOwnedCount[playerid]] = DB_IntAt(query, 0, 1, 0);
        DB_StrAt(query, 0, 2, gOwnedPlate[playerid][gOwnedCount[playerid]],
            OWNED_PLATE_LEN);
        gOwnedCount[playerid]++;
    }
    return gOwnedCount[playerid];
}

stock VehicleOwned_Count(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return gOwnedCount[playerid];
}

stock VehicleOwned_IdAt(playerid, index) {
    if (index < 0 || index >= gOwnedCount[playerid]) return 0;
    return gOwnedId[playerid][index];
}

stock VehicleOwned_ModelAt(playerid, index) {
    if (index < 0 || index >= gOwnedCount[playerid]) return 0;
    return gOwnedModel[playerid][index];
}

stock VehicleOwned_PlateAt(playerid, index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gOwnedCount[playerid]) return format(dest, maxlength, "");
    return format(dest, maxlength, "%s", gOwnedPlate[playerid][index]);
}

// Indeks kendaraan yang sedang keluar di dunia (-1 kalau tidak ada).
stock VehicleOwned_Active(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    return gOwnedActive[playerid];
}

// Id kendaraan fisik yang sedang keluar untuk pemain ini (0 kalau tidak ada).
stock VehicleOwned_VehicleIdOf(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return INVALID_VEHICLE_ID;
    return gOwnedSpawned[playerid];
}

// Pemilik kendaraan pribadi berdasarkan id kendaraan fisik (-1 kalau bukan).
stock VehicleOwned_OwnerOfVehicleId(vehicleid) {
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        new index = gOwnedActive[playerid];
        if (index < 0) continue;
        if (gOwnedSpawned[playerid] != vehicleid) continue;
        return playerid;
    }
    return -1;
}

// Simpan posisi & kondisi kendaraan yang sedang dipakai ke DB.
stock VehicleOwned_Save(playerid) {
    new index = gOwnedActive[playerid];
    if (index < 0) return 0;

    new vehicleid = gOwnedSpawned[playerid];
    if (vehicleid == INVALID_VEHICLE_ID || !IsValidVehicle(vehicleid)) {
        VehicleOwned_Destroy(playerid);
        return 0;
    }

    new Float:posX, Float:posY, Float:posZ, Float:angle, Float:health;
    GetVehiclePos(vehicleid, posX, posY, posZ);
    GetVehicleZAngle(vehicleid, angle);
    GetVehicleHealth(vehicleid, health);
    if (health < 250.0) health = 250.0;

    new query[256];
    format(query, sizeof (query),
        "UPDATE vehicles SET pos_x = %f, pos_y = %f, pos_z = %f, angle = %f, \
         health = %f WHERE vehicle_id = %d",
        posX, posY, posZ, angle, health, gOwnedId[playerid][index]);
    if (!DB_Exec(query)) return 0;
    return 1;
}

// Beli kendaraan dari katalog dealer: uang dipotong dulu, baru INSERT, supaya
// tidak ada kendaraan gratis saat DB menolak.
stock bool:VehicleOwned_Buy(playerid, catalogIndex) {
    if (catalogIndex < 0 || catalogIndex >= VehicleCatalog_Count()) return false;
    if (gOwnedCount[playerid] >= OWNED_MAX) {
        Messages_SendError(playerid, "Slot kendaraanmu penuh (3 maksimal).");
        return false;
    }

    new characterId = Character_GetId(playerid);
    if (characterId <= 0) {
        Messages_SendError(playerid, MSG_NOT_LOGGED_IN);
        return false;
    }

    new price = VehicleCatalog_Price(catalogIndex);
    if (Money_GetCash(playerid) < price) {
        Messages_SendError(playerid, "Uang tunai tidak cukup. Ambil di ATM dulu.");
        return false;
    }
    if (!Money_Take(playerid, price, MONEY_REASON_VEHICLE)) {
        Messages_SendError(playerid, "Pembayaran gagal. Pembelian dibatalkan.");
        return false;
    }

    new model = VehicleCatalog_Model(catalogIndex);
    new plate[OWNED_PLATE_LEN];
    format(plate, sizeof (plate), "B %04d RZ", gettime() % 10000);

    new query[256];
    format(query, sizeof (query),
        "INSERT INTO vehicles (character_id, model, plate) VALUES (%d, %d, '%s')",
        characterId, model, plate);
    if (!DB_Exec(query)) {
        Money_Add(playerid, price, MONEY_REASON_VEHICLE);
        Messages_SendError(playerid, MSG_DB_ERROR);
        return false;
    }

    VehicleOwned_Load(playerid, characterId);

    new name[24], priceText[24], message[128];
    VehicleCatalog_Name(catalogIndex, name, sizeof (name));
    Messages_Money(price, priceText, sizeof (priceText));
    format(message, sizeof (message), "%s dibeli (%s). Plat: %s", name,
        priceText, plate);
    Toast_Show(playerid, "DEALER", message, THEME_OK);
    Messages_SendSystem(playerid, message);
    Messages_SendSystem(playerid, "Keluarkan kendaraan: /pakai <nomor> | Lihat: /stnk");
    return true;
}

// Keluarkan kendaraan pribadi ke dunia pada posisi parkir terakhirnya. Kalau
// belum pernah diparkir (posisi 0,0,0), kendaraan muncul 4 m di depan pemain.
stock bool:VehicleOwned_Spawn(playerid, index) {
    if (index < 0 || index >= gOwnedCount[playerid]) {
        Messages_SendError(playerid, "Nomor kendaraan tidak ada. Lihat /stnk.");
        return false;
    }
    if (gOwnedActive[playerid] >= 0) {
        Messages_SendError(playerid,
            "Kendaraanmu sudah keluar. Parkir dulu dengan /parkir.");
        return false;
    }

    new vehicleId = gOwnedId[playerid][index];
    new query[192];
    format(query, sizeof (query),
        "SELECT pos_x, pos_y, pos_z, angle, health FROM vehicles WHERE vehicle_id = %d",
        vehicleId);

    new Float:posX = DB_FloatAt(query, 0, 0, 0.0);
    new Float:posY = DB_FloatAt(query, 0, 1, 0.0);
    new Float:posZ = DB_FloatAt(query, 0, 2, 0.0);
    new Float:angle = DB_FloatAt(query, 0, 3, 0.0);
    new Float:health = DB_FloatAt(query, 0, 4, 1000.0);

    if (posX == 0.0 && posY == 0.0 && posZ == 0.0) {
        new Float:playerX, Float:playerY, Float:playerZ, Float:facing;
        GetPlayerPos(playerid, playerX, playerY, playerZ);
        GetPlayerFacingAngle(playerid, facing);
        new Float:radians = facing * 3.14159265 / 180.0;
        posX = playerX - floatsin(radians) * 4.0;
        posY = playerY + floatcos(radians) * 4.0;
        posZ = playerZ + 0.2;
        angle = facing;
    }

    new vehicleid = CreateVehicle(gOwnedModel[playerid][index], posX, posY, posZ,
        angle, 1, 1, -1);
    if (vehicleid == INVALID_VEHICLE_ID) {
        Messages_SendError(playerid, "Kendaraan gagal dikeluarkan. Coba lagi.");
        return false;
    }

    SetVehicleNumberPlate(vehicleid, gOwnedPlate[playerid][index]);
    if (health > 0.0) SetVehicleHealth(vehicleid, health);

    for (new other = 0; other < MAX_PLAYERS; other++) {
        if (!IsPlayerConnected(other)) continue;
        if (other == playerid) continue;
        SetVehicleParamsForPlayer(vehicleid, other, 0, 1);
    }

    gOwnedSpawned[playerid] = vehicleid;
    gOwnedActive[playerid] = index;

    new name[24], message[96];
    Vehicle_NameOf(gOwnedModel[playerid][index], name, sizeof (name));
    format(message, sizeof (message), "%s keluar. Plat %s.", name,
        gOwnedPlate[playerid][index]);
    Messages_SendSystem(playerid, message);
    return true;
}

// Parkir: simpan posisi lalu hilangkan kendaraan dari dunia.
stock bool:VehicleOwned_Park(playerid) {
    if (gOwnedActive[playerid] < 0) {
        Messages_SendError(playerid, "Tidak ada kendaraanmu yang keluar.");
        return false;
    }
    if (!VehicleOwned_Save(playerid)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return false;
    }
    VehicleOwned_Destroy(playerid);
    Messages_SendSystem(playerid,
        "Kendaraan diparkir. Keluarkan lagi dengan /pakai <nomor>.");
    return true;
}
