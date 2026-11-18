// ---------------------------------------------------------------------------
// module      : domain/vehicle/vehicle_fuel
// entry       : public Timer_OnFuelTick()
// depends     : domain/vehicle/vehicle_owner, domain/world/locations,
//               shared/money, shared/messages, shared/player_phase, ui/toast
// owns tables : kolom vehicles.fuel (migrasi ringan di Fuel_Boot)
// public api  : Fuel_Boot(), Fuel_LoadOwned(), Fuel_SaveOwned(), Fuel_Tick(),
//               Fuel_Liters(), Fuel_Percent(), Fuel_HandleCommand()
// Isi         : bensin kendaraan pribadi + servis bengkel. Ini penguras uang
//               rutin pertama: bahan bakar dibakar per detik mengikuti kecepatan,
//               servis membayar kerusakan badan kendaraan.
// Aturan      : hanya kendaraan PRIBADI yang punya bensin (rental berumur pendek
//               dan selalu penuh). Bensin disimpan per slot pemilik, bukan per
//               vehicleid, supaya tidak ada kebocoran saat kendaraan di-respawn.
//               Semua pemotongan uang lewat Money_Take SEBELUM efek diterapkan.
// ---------------------------------------------------------------------------
#if defined _INC_VEHICLE_FUEL
    #endinput
#endif
#define _INC_VEHICLE_FUEL

#define FUEL_CAPACITY           (Float:50.0)   // liter per tangki
#define FUEL_PRICE_PER_LITER    (200)          // rupiah per liter
#define FUEL_BURN_IDLE          (Float:0.004)   // liter/detik saat mesin hidup
#define FUEL_BURN_PER_SPEED     (Float:0.00018) // liter/detik per km/jam
#define FUEL_LOW_PERCENT        (20.0)          // ambang peringatan
#define FUEL_SERVICE_BASE       (500)           // biaya dasar servis
#define FUEL_SERVICE_PER_DAMAGE (20)            // rupiah per poin kerusakan
#define FUEL_REACH              (8.0)           // jarak pemain ke kendaraan

static Float:gFuelLitres[MAX_PLAYERS][OWNED_MAX];
static gFuelDirty[MAX_PLAYERS];
static gFuelWarned[MAX_PLAYERS];

stock Fuel_Boot() {
    // Migrasi ringan: kolom fuel ditambahkan hanya bila belum ada, jadi DB lama
    // tetap jalan tanpa reset data kendaraan.
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('vehicles') WHERE name = 'fuel'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE vehicles ADD COLUMN fuel REAL NOT NULL DEFAULT 50.0")) {
            Log_Error("fuel", "migrasi kolom vehicles.fuel gagal");
            return 0;
        }
    }

    if (!Timer_Add("Timer_OnFuelTick", 1_000, true)) {
        Log_Error("fuel", "timer bensin gagal didaftarkan");
        return 0;
    }

    Log_Info("fuel", "bensin & servis siap");
    return 1;
}

// Baca bensin seluruh kendaraan pribadi pemain, urut sama dengan VehicleOwned.
stock Fuel_LoadOwned(playerid, characterId) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;

    for (new slot = 0; slot < OWNED_MAX; slot++) {
        gFuelLitres[playerid][slot] = FUEL_CAPACITY;
    }
    gFuelDirty[playerid] = 0;
    gFuelWarned[playerid] = 0;
    if (characterId <= 0) return 0;

    for (new slot = 0; slot < OWNED_MAX; slot++) {
        if (slot >= VehicleOwned_Count(playerid)) break;
        new rowId = VehicleOwned_IdAt(playerid, slot);
        if (rowId <= 0) continue;

        new query[128];
        format(query, sizeof (query),
            "SELECT fuel FROM vehicles WHERE vehicle_id = %d", rowId);
        new Float:litres = DB_Float(query, FUEL_CAPACITY);
        if (litres < 0.0) litres = 0.0;
        if (litres > FUEL_CAPACITY) litres = FUEL_CAPACITY;
        gFuelLitres[playerid][slot] = litres;
    }
    return 1;
}

stock Fuel_SaveOwned(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gFuelDirty[playerid]) return 0;

    for (new slot = 0; slot < VehicleOwned_Count(playerid); slot++) {
        new rowId = VehicleOwned_IdAt(playerid, slot);
        if (rowId <= 0) continue;

        new query[128];
        format(query, sizeof (query),
            "UPDATE vehicles SET fuel = %f WHERE vehicle_id = %d",
            gFuelLitres[playerid][slot], rowId);
        if (!DB_Exec(query)) return 0;
    }
    gFuelDirty[playerid] = 0;
    return 1;
}

stock Float:Fuel_Liters(playerid, slot) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0.0;
    if (slot < 0 || slot >= OWNED_MAX) return 0.0;
    return gFuelLitres[playerid][slot];
}

stock Float:Fuel_Percent(playerid, slot) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0.0;
    if (slot < 0 || slot >= OWNED_MAX) return 0.0;
    return gFuelLitres[playerid][slot] / FUEL_CAPACITY * 100.0;
}

// Pemilik > kendaraan aktif > kendaraan fisik. Dipakai tick dan /isi.
static bool:Fuel_ResolveVehicle(playerid, &slot, &vehicleid) {
    slot = VehicleOwned_Active(playerid);
    if (slot < 0 || slot >= OWNED_MAX) return false;

    vehicleid = VehicleOwned_VehicleIdOf(playerid);
    if (vehicleid == INVALID_VEHICLE_ID || !IsValidVehicle(vehicleid)) return false;
    return true;
}

// Dijalankan tiap detik: bakar bensin hanya saat mesin hidup dan ada pengemudi.
stock Fuel_Tick() {
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;
        if (!Phase_CanAct(playerid)) continue;

        new slot, vehicleid;
        if (!Fuel_ResolveVehicle(playerid, slot, vehicleid)) continue;
        if (GetPlayerState(playerid) != PLAYER_STATE_DRIVER) continue;

        new Float:litres = gFuelLitres[playerid][slot];
        if (litres <= 0.0) {
            // Tangki kosong: mesin mati sekali, bukan spam pesan tiap detik.
            if (!gFuelWarned[playerid]) {
                gFuelWarned[playerid] = 1;
                Toast_Show(playerid, "BENSIN", "Tangki kosong. Isi di pom bensin (/isi).",
                    THEME_DANGER);
                Messages_SendSystem(playerid,
                    "Bensin habis. Cari ikon pom bensin lalu ketik /isi.");
            }
            continue;
        }

        new Float:speedX, Float:speedY, Float:speedZ;
        GetVehicleVelocity(vehicleid, speedX, speedY, speedZ);
        new Float:speedKmh = floatsqroot(speedX * speedX + speedY * speedY
            + speedZ * speedZ) * 180.0;

        new Float:burn = FUEL_BURN_IDLE + speedKmh * FUEL_BURN_PER_SPEED;
        litres -= burn;
        if (litres < 0.0) litres = 0.0;
        gFuelLitres[playerid][slot] = litres;
        gFuelDirty[playerid] = 1;

        new Float:percent = litres / FUEL_CAPACITY * 100.0;
        if (percent <= FUEL_LOW_PERCENT && !gFuelWarned[playerid]) {
            gFuelWarned[playerid] = 1;
            Toast_Show(playerid, "BENSIN", "Bensin tinggal sedikit. Cari pom bensin.",
                THEME_WARN);
        } else if (percent > FUEL_LOW_PERCENT + 5.0 && gFuelWarned[playerid]) {
            gFuelWarned[playerid] = 0;
        }
    }
    return 1;
}

// /isi [liter|penuh] - hanya di lokasi pom bensin, hanya untuk kendaraan sendiri.
static bool:Fuel_Fill(playerid, const params[]) {
    if (Locations_NearCode(playerid, LOC_ACT_BENSIN) < 0) {
        Messages_SendError(playerid,
            "Kamu tidak di pom bensin. Cari ikon pom di radar lalu /isi.");
        return true;
    }

    new slot, vehicleid;
    if (!Fuel_ResolveVehicle(playerid, slot, vehicleid)) {
        Messages_SendError(playerid, "Kendaraanmu tidak sedang keluar. Pakai /pakai dulu.");
        return true;
    }

    new Float:posX, Float:posY, Float:posZ, Float:vehX, Float:vehY, Float:vehZ;
    GetPlayerPos(playerid, posX, posY, posZ);
    GetVehiclePos(vehicleid, vehX, vehY, vehZ);
    new Float:deltaX = posX - vehX;
    new Float:deltaY = posY - vehY;
    if (floatsqroot(deltaX * deltaX + deltaY * deltaY) > FUEL_REACH
            && GetPlayerVehicleID(playerid) != vehicleid) {
        Messages_SendError(playerid, "Dekati kendaraanmu dulu (maksimal 8 meter).");
        return true;
    }

    new Float:current = gFuelLitres[playerid][slot];
    new Float:missing = FUEL_CAPACITY - current;
    if (missing <= 0.5) {
        Messages_SendSystem(playerid, "Tangki masih penuh.");
        return true;
    }

    new Float:want;
    if (params[0] == EOS || !strcmp(params, "penuh", true)
            || !strcmp(params, "full", true)) {
        want = missing;
    } else {
        want = float(strval(params));
    }
    if (want <= 0.0) {
        Messages_SendError(playerid, "Pakai: /isi 10  atau  /isi penuh");
        return true;
    }
    if (want > missing) want = missing;
    if (want < 1.0) want = 1.0;

    new cost = floatround(want * float(FUEL_PRICE_PER_LITER), floatround_ceil);
    new costText[24];
    Text_FormatNumber(cost, costText, sizeof (costText));
    if (!Money_Take(playerid, cost, MONEY_REASON_FUEL)) {
        new message[96];
        format(message, sizeof (message),
            "Uang tidak cukup. Butuh Rp %s untuk %d liter.", costText, floatround(want));
        Messages_SendError(playerid, message);
        return true;
    }

    gFuelLitres[playerid][slot] = current + want;
    gFuelDirty[playerid] = 1;
    gFuelWarned[playerid] = 0;

    new message[128];
    format(message, sizeof (message), "Isi %d liter, bayar Rp %s. Tangki %d%%.",
        floatround(want), costText, floatround(Fuel_Percent(playerid, slot)));
    Toast_Show(playerid, "BENSIN", message, THEME_OK);
    Messages_SendSystem(playerid, message);
    return true;
}

// /servis - perbaiki badan kendaraan di bengkel; biaya mengikuti kerusakan.
static bool:Fuel_Service(playerid, const params[]) {
    #pragma unused params
    if (Locations_NearCode(playerid, LOC_ACT_BENGKEL) < 0) {
        Messages_SendError(playerid,
            "Kamu tidak di bengkel. Cari ikon bengkel di radar lalu /servis.");
        return true;
    }

    new slot, vehicleid;
    if (!Fuel_ResolveVehicle(playerid, slot, vehicleid)) {
        Messages_SendError(playerid, "Kendaraanmu tidak sedang keluar. Pakai /pakai dulu.");
        return true;
    }

    new Float:health;
    GetVehicleHealth(vehicleid, health);
    new damage = floatround(1000.0 - health);
    if (damage <= 5) {
        Messages_SendSystem(playerid, "Kendaraanmu masih mulus, belum perlu servis.");
        return true;
    }

    new cost = FUEL_SERVICE_BASE + damage * FUEL_SERVICE_PER_DAMAGE;
    new costText[24];
    Text_FormatNumber(cost, costText, sizeof (costText));
    if (!Money_Take(playerid, cost, MONEY_REASON_SERVICE)) {
        new message[96];
        format(message, sizeof (message), "Servis butuh Rp %s (kerusakan %d poin).",
            costText, damage);
        Messages_SendError(playerid, message);
        return true;
    }

    SetVehicleHealth(vehicleid, 1000.0);
    new message[112];
    format(message, sizeof (message), "Kendaraan diservis, bayar Rp %s.", costText);
    Toast_Show(playerid, "BENGKEL", message, THEME_OK);
    Messages_SendSystem(playerid, message);
    return true;
}

// Admin: pasang pom bensin / bengkel di posisi sendiri.
static bool:Fuel_CreateStation(playerid, const params[], const action[],
    const prefix[], const label[]) {
    if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;

    new name[LOC_NAME_LEN];
    if (params[0] == EOS) {
        format(name, sizeof (name), "%s", label);
    } else {
        format(name, sizeof (name), "%s %s", label, params);
    }

    new code[LOC_CODE_LEN];
    format(code, sizeof (code), "%s_%d", prefix, gettime() % 100000);

    new Float:posX, Float:posY, Float:posZ;
    GetPlayerPos(playerid, posX, posY, posZ);
    new locIndex = Locations_Add(code, name, action, posX, posY, posZ, 4.0);
    if (locIndex < 0) {
        Messages_SendError(playerid, "Gagal dipasang: daftar lokasi penuh.");
        return true;
    }

    new message[96];
    format(message, sizeof (message), "%s '%s' dipasang.", label, name);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "STATION_CREATE", -1, code);
    return true;
}

stock bool:Fuel_HandleCommand(playerid, const command[], const params[]) {
    if (!strcmp(command, "isi", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        return Fuel_Fill(playerid, params);
    }
    if (!strcmp(command, "servis", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        return Fuel_Service(playerid, params);
    }
    if (!strcmp(command, "buatbensin", true)) {
        return Fuel_CreateStation(playerid, params, LOC_ACT_BENSIN, "BENSIN", "Pom Bensin");
    }
    if (!strcmp(command, "buatbengkel", true)) {
        return Fuel_CreateStation(playerid, params, LOC_ACT_BENGKEL, "BENGKEL", "Bengkel");
    }
    return false;
}

public Timer_OnFuelTick() {
    Fuel_Tick();
    return 1;
}
