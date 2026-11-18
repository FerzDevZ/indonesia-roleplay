// ---------------------------------------------------------------------------
// module      : domain/vehicle/vehicle
// entry       : Vehicle_Boot()
// depends     : core/log, ui/toast, shared/player_phase
// owns tables : -
// public api  : Vehicle_Boot(), Vehicle_Reset(), Vehicle_OwnerOf(),
//               Vehicle_IdOf(), Vehicle_Spawn(), Vehicle_DespawnOf(),
//               Vehicle_Despawn(), Vehicle_Tick(), Vehicle_NameOf(),
//               Vehicle_SecondsLeft(), Vehicle_DriverId()
// Aturan      : kendaraan sewa bersifat sementara (tidak ditulis ke DB) supaya
//               tidak ada kendaraan hantu setelah server restart. Semua
//               pembuatan/penghancuran kendaraan WAJIB lewat modul ini.
// ---------------------------------------------------------------------------
#if defined _INC_VEHICLE
    #endinput
#endif
#define _INC_VEHICLE

#define VEH_MAX             (6)
#define VEH_NONE            (-1)
#define VEH_WARN_SECONDS    (30)    // pengingat pertama
#define VEH_LAST_SECONDS    (10)    // pengingat terakhir
#define VEH_PLATE           "SEWAAN"
#define VEH_SPAWN_HEALTH    (1000.0)

static gVehLive[VEH_MAX];
static gVehId[VEH_MAX];
static gVehOwner[VEH_MAX];
static gVehModel[VEH_MAX];
static gVehExpire[VEH_MAX];
static gVehWarned[VEH_MAX];

stock Vehicle_Boot() {
    for (new slot = 0; slot < VEH_MAX; slot++) {
        gVehLive[slot] = 0;
        gVehId[slot] = INVALID_VEHICLE_ID;
        gVehOwner[slot] = VEH_NONE;
        gVehModel[slot] = 0;
        gVehExpire[slot] = 0;
        gVehWarned[slot] = 0;
    }
    Log_Info("vehicle", "pool kendaraan siap");
    return 1;
}

// Buang satu slot: hancurkan kendaraan fisik lalu kosongkan catatan.
static Vehicle_Clear(slot) {
    if (slot < 0 || slot >= VEH_MAX) return 0;
    if (gVehLive[slot] && IsValidVehicle(gVehId[slot])) {
        DestroyVehicle(gVehId[slot]);
    }
    gVehLive[slot] = 0;
    gVehId[slot] = INVALID_VEHICLE_ID;
    gVehOwner[slot] = VEH_NONE;
    gVehModel[slot] = 0;
    gVehExpire[slot] = 0;
    gVehWarned[slot] = 0;
    return 1;
}

stock Vehicle_Reset(playerid) {
    Vehicle_DespawnOf(playerid);
    return 1;
}

// Slot milik pemain (VEH_NONE kalau tidak menyewa).
stock Vehicle_SlotOf(playerid) {
    for (new slot = 0; slot < VEH_MAX; slot++) {
        if (!gVehLive[slot]) continue;
        if (gVehOwner[slot] == playerid) return slot;
    }
    return VEH_NONE;
}

stock Vehicle_OwnerOf(slot) {
    if (slot < 0 || slot >= VEH_MAX || !gVehLive[slot]) return VEH_NONE;
    return gVehOwner[slot];
}

stock Vehicle_IdOf(slot) {
    if (slot < 0 || slot >= VEH_MAX || !gVehLive[slot]) return INVALID_VEHICLE_ID;
    return gVehId[slot];
}

// Pemilik sewa berdasarkan id kendaraan fisik (VEH_NONE kalau bukan sewaan).
stock Vehicle_OwnerOfVehicleId(vehicleid) {
    for (new slot = 0; slot < VEH_MAX; slot++) {
        if (!gVehLive[slot]) continue;
        if (gVehId[slot] == vehicleid) return gVehOwner[slot];
    }
    return VEH_NONE;
}

stock Vehicle_ModelOfPlayer(playerid) {
    new slot = Vehicle_SlotOf(playerid);
    if (slot == VEH_NONE) return 0;
    return gVehModel[slot];
}

stock Vehicle_SecondsLeft(playerid) {
    new slot = Vehicle_SlotOf(playerid);
    if (slot == VEH_NONE) return 0;
    new remaining = gVehExpire[slot] - gettime();
    return (remaining > 0) ? remaining : 0;
}

// Pemain yang sedang menyetir kendaraan sewaan (dipakai aturan tambahan).
stock Vehicle_DriverId(slot) {
    if (slot < 0 || slot >= VEH_MAX || !gVehLive[slot]) return VEH_NONE;
    new driver = GetVehicleDriver(gVehId[slot]);
    return (driver >= 0) ? driver : VEH_NONE;
}

stock Vehicle_NameOf(model, dest[], maxlength = sizeof (dest)) {
    switch (model) {
        case 462: return format(dest, maxlength, "Motor Faggio");
        case 507: return format(dest, maxlength, "Mobil Elegant");
        case 482: return format(dest, maxlength, "Van Burrito");
        case 400: return format(dest, maxlength, "Mobil Landstalker");
        case 481: return format(dest, maxlength, "Sepeda BMX");
        case 567: return format(dest, maxlength, "Mobil Savanna");
        default:  return format(dest, maxlength, "Kendaraan");
    }
}

// Buat kendaraan sewaan. Mengembalikan slot (>= 0) atau VEH_NONE kalau gagal.
// Pemain hanya boleh punya satu kendaraan sewaan; yang lama dibuang dulu.
stock Vehicle_Spawn(playerid, model, Float:x, Float:y, Float:z, Float:angle,
    seconds) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return VEH_NONE;
    if (!IsPlayerConnected(playerid)) return VEH_NONE;
    if (seconds <= 0 || model <= 0) return VEH_NONE;

    Vehicle_DespawnOf(playerid);

    new slot = VEH_NONE;
    for (new candidate = 0; candidate < VEH_MAX; candidate++) {
        if (gVehLive[candidate]) continue;
        slot = candidate;
        break;
    }
    if (slot == VEH_NONE) return VEH_NONE;

    new vehicleid = CreateVehicle(model, x, y, z, angle, 1, 1, -1);
    if (vehicleid == INVALID_VEHICLE_ID) return VEH_NONE;

    SetVehicleNumberPlate(vehicleid, VEH_PLATE);
    SetVehicleHealth(vehicleid, VEH_SPAWN_HEALTH);

    gVehLive[slot] = 1;
    gVehId[slot] = vehicleid;
    gVehOwner[slot] = playerid;
    gVehModel[slot] = model;
    gVehExpire[slot] = gettime() + seconds;
    gVehWarned[slot] = 0;

    // Kunci pintu untuk pemain lain supaya kendaraan sewaan tidak dibawa kabur.
    for (new other = 0; other < MAX_PLAYERS; other++) {
        if (!IsPlayerConnected(other)) continue;
        if (other == playerid) continue;
        SetVehicleParamsForPlayer(vehicleid, other, 0, 1);
    }
    return slot;
}

stock Vehicle_DespawnOf(playerid) {
    new slot = Vehicle_SlotOf(playerid);
    if (slot == VEH_NONE) return 0;
    Vehicle_Clear(slot);
    return 1;
}

stock Vehicle_Despawn(slot) {
    if (slot < 0 || slot >= VEH_MAX) return 0;
    if (!gVehLive[slot]) return 0;
    Vehicle_Clear(slot);
    return 1;
}

// Tick 500 ms: buang kendaraan yang sudah tidak sah, pemiliknya keluar, atau
// waktunya habis. Pengingat dikirim sekali per ambang, bukan tiap tick.
stock Vehicle_Tick() {
    for (new slot = 0; slot < VEH_MAX; slot++) {
        if (!gVehLive[slot]) continue;

        if (!IsValidVehicle(gVehId[slot])) {
            Vehicle_Clear(slot);
            continue;
        }

        new owner = gVehOwner[slot];
        if (owner == VEH_NONE || !IsPlayerConnected(owner)) {
            Vehicle_Clear(slot);
            continue;
        }

        new remaining = gVehExpire[slot] - gettime();
        if (remaining <= 0) {
            new body[64];
            Vehicle_NameOf(gVehModel[slot], body, sizeof (body));
            Vehicle_Clear(slot);
            new message[96];
            format(message, sizeof (message),
                "Waktu sewa habis, %s dikembalikan.", body);
            Toast_Show(owner, "RENTAL", message, THEME_DANGER);
            continue;
        }

        if (!gVehWarned[slot] && remaining <= VEH_WARN_SECONDS) {
            gVehWarned[slot] = 1;
            new message[80];
            format(message, sizeof (message),
                "Sisa waktu sewa %d detik. Kembalikan dengan /kembalikan.",
                remaining);
            Toast_Show(owner, "RENTAL", message, THEME_WARN);
        }

        // Pemilik masuk kendaraan: buka kunci pintu untuk dirinya.
        if (GetPlayerVehicleID(owner) == gVehId[slot]) {
            SetVehicleParamsForPlayer(gVehId[slot], owner, 0, 0);
        }
    }
    return 1;
}
