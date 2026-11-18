// ---------------------------------------------------------------------------
// module      : domain/vehicle/vehicle_rental_data
// entry       : Rental_Boot()
// depends     : core/db, core/log, domain/world/locations (fallback posisi)
// owns tables : rental_packages, rental_sites
// public api  : Rental_Boot(), Rental_Reload(), Rental_PackageCount(),
//               Rental_PackageId(), Rental_PackageName(), Rental_PackageModel(),
//               Rental_PackagePrice(), Rental_PackageMinutes(),
//               Rental_AddPackage(), Rental_RemovePackage(),
//               Rental_SiteSpawn(), Rental_SetSiteSpawn(), Rental_DeleteSite()
// Aturan      : paket sewa & titik spawn disimpan di DB supaya admin bisa
//               menambah/mengubah tanpa compile ulang. Semua akses tabel ini
//               lewat modul ini (domain lain tidak menulis SQL-nya).
// ---------------------------------------------------------------------------
#if defined _INC_VEHICLE_RENTAL_DATA
    #endinput
#endif
#define _INC_VEHICLE_RENTAL_DATA

#define RENTAL_PKG_MAX      (8)
#define RENTAL_NAME_LEN     (24)
#define RENTAL_DEFAULT_OFFSET_X (5.0)

static gRentalCount = 0;
static gRentalPackageId[RENTAL_PKG_MAX];
static gRentalPackageModel[RENTAL_PKG_MAX];
static gRentalPackagePrice[RENTAL_PKG_MAX];
static gRentalPackageMinutes[RENTAL_PKG_MAX];
static gRentalPackageName[RENTAL_PKG_MAX][RENTAL_NAME_LEN];

// Titik rental hasil seed wajib langsung bisa dipakai: kalau baris spawn belum
// ada, isi dari posisi lokasinya (digeser 5 m) supaya /rental tidak menolak
// pemain pertama dengan "spawn belum diatur admin".
static Rental_EnsureSeedSite(const code[]) {
    new query[192];
    format(query, sizeof (query),
        "SELECT COUNT(*) FROM rental_sites WHERE location_code = '%s'", code);
    if (DB_Int(query, 0) > 0) return 1;

    new locationIndex = Locations_FindByCode(code);
    if (locationIndex < 0) return 0;

    new Float:posX, Float:posY, Float:posZ;
    Locations_Pos(locationIndex, posX, posY, posZ);
    return Rental_SetSiteSpawn(code, posX + RENTAL_DEFAULT_OFFSET_X, posY, posZ, 0.0);
}

stock Rental_Boot() {
    if (!DB_Exec("CREATE TABLE IF NOT EXISTS rental_packages (\
            package_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            name TEXT NOT NULL,\
            model INTEGER NOT NULL,\
            price INTEGER NOT NULL,\
            minutes INTEGER NOT NULL,\
            enabled INTEGER NOT NULL DEFAULT 1,\
            created_at TEXT DEFAULT (datetime('now')))")) {
        Log_Error("rental", "gagal membuat tabel rental_packages");
        return 0;
    }
    if (!DB_Exec("CREATE TABLE IF NOT EXISTS rental_sites (\
            location_code TEXT PRIMARY KEY,\
            spawn_x REAL NOT NULL,\
            spawn_y REAL NOT NULL,\
            spawn_z REAL NOT NULL,\
            spawn_angle REAL NOT NULL DEFAULT 0.0,\
            created_at TEXT DEFAULT (datetime('now')))")) {
        Log_Error("rental", "gagal membuat tabel rental_sites");
        return 0;
    }

    // Seed hanya saat tabel masih kosong: harga yang sudah diubah admin tidak
    // pernah ditimpa saat server restart.
    if (DB_Int("SELECT COUNT(*) FROM rental_packages", 0) == 0) {
        DB_Exec("INSERT INTO rental_packages (name, model, price, minutes) \
                 VALUES ('Motor Faggio', 462, 5000, 5)");
        DB_Exec("INSERT INTO rental_packages (name, model, price, minutes) \
                 VALUES ('Mobil Elegant', 507, 12000, 5)");
        DB_Exec("INSERT INTO rental_packages (name, model, price, minutes) \
                 VALUES ('Van Burrito', 482, 20000, 10)");
    }

    Rental_EnsureSeedSite("RENTAL_STASIUN");
    Rental_Reload();
    return 1;
}

stock Rental_Reload() {
    new total = DB_Int("SELECT COUNT(*) FROM rental_packages WHERE enabled = 1", 0);
    if (total > RENTAL_PKG_MAX) total = RENTAL_PKG_MAX;

    gRentalCount = 0;
    for (new row = 0; row < total; row++) {
        new query[192];
        format(query, sizeof (query),
            "SELECT package_id, name, model, price, minutes \
             FROM rental_packages WHERE enabled = 1 \
             ORDER BY package_id LIMIT 1 OFFSET %d", row);
        new packageId = DB_IntAt(query, 0, 0, 0);
        if (packageId <= 0) continue;

        gRentalPackageId[gRentalCount] = packageId;
        DB_StrAt(query, 0, 1, gRentalPackageName[gRentalCount], RENTAL_NAME_LEN);
        gRentalPackageModel[gRentalCount] = DB_IntAt(query, 0, 2, 0);
        gRentalPackagePrice[gRentalCount] = DB_IntAt(query, 0, 3, 0);
        gRentalPackageMinutes[gRentalCount] = DB_IntAt(query, 0, 4, 0);
        if (gRentalPackageModel[gRentalCount] <= 0) continue;
        if (gRentalPackagePrice[gRentalCount] <= 0) continue;
        if (gRentalPackageMinutes[gRentalCount] <= 0) continue;
        gRentalCount++;
    }

    new report[64];
    format(report, sizeof (report), "paket rental dimuat: %d", gRentalCount);
    Log_Info("rental", report);
    return gRentalCount;
}

stock Rental_PackageCount() {
    return gRentalCount;
}

stock Rental_PackageId(index) {
    if (index < 0 || index >= gRentalCount) return 0;
    return gRentalPackageId[index];
}

stock Rental_PackageName(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gRentalCount) return format(dest, maxlength, "-");
    return format(dest, maxlength, "%s", gRentalPackageName[index]);
}

stock Rental_PackageModel(index) {
    if (index < 0 || index >= gRentalCount) return 0;
    return gRentalPackageModel[index];
}

stock Rental_PackagePrice(index) {
    if (index < 0 || index >= gRentalCount) return 0;
    return gRentalPackagePrice[index];
}

stock Rental_PackageMinutes(index) {
    if (index < 0 || index >= gRentalCount) return 0;
    return gRentalPackageMinutes[index];
}

// Tambah paket baru. Model wajib kendaraan darat yang dikenal game (400..611),
// harga 100..10.000.000, durasi 1..120 menit.
stock bool:Rental_AddPackage(const name[], model, price, minutes) {
    if (model < 400 || model > 611) return false;
    if (price < 100 || price > 10000000) return false;
    if (minutes < 1 || minutes > 120) return false;
    if (gRentalCount >= RENTAL_PKG_MAX) return false;

    new escapedName[RENTAL_NAME_LEN * 2 + 1];
    DB_Escape(escapedName, sizeof (escapedName), name);
    new query[256];
    format(query, sizeof (query),
        "INSERT INTO rental_packages (name, model, price, minutes) \
         VALUES ('%s', %d, %d, %d)", escapedName, model, price, minutes);
    if (!DB_Exec(query)) return false;

    Rental_Reload();
    return true;
}

// Nonaktifkan paket (baris tetap ada supaya riwayat & id stabil).
stock bool:Rental_RemovePackage(index) {
    new packageId = Rental_PackageId(index);
    if (packageId <= 0) return false;

    new query[128];
    format(query, sizeof (query),
        "UPDATE rental_packages SET enabled = 0 WHERE package_id = %d", packageId);
    if (!DB_Exec(query)) return false;

    Rental_Reload();
    return true;
}

// Titik spawn kendaraan untuk satu lokasi rental. Kalau admin belum mengatur,
// pakai offset bawaan dari posisi lokasi supaya layanan tetap bisa dipakai.
stock bool:Rental_SiteSpawn(const code[], &Float:spawnX, &Float:spawnY,
    &Float:spawnZ, &Float:angle) {
    spawnX = 0.0;
    spawnY = 0.0;
    spawnZ = 0.0;
    angle = 0.0;

    new escaped[RENTAL_NAME_LEN * 2 + 1];
    DB_Escape(escaped, sizeof (escaped), code);
    new query[192];
    format(query, sizeof (query),
        "SELECT spawn_x, spawn_y, spawn_z, spawn_angle FROM rental_sites \
         WHERE location_code = '%s'", escaped);
    if (DB_Rows(query) > 0) {
        spawnX = DB_FloatAt(query, 0, 0, 0.0);
        spawnY = DB_FloatAt(query, 0, 1, 0.0);
        spawnZ = DB_FloatAt(query, 0, 2, 0.0);
        angle = DB_FloatAt(query, 0, 3, 0.0);
        return true;
    }

    new locationIndex = Locations_FindByCode(code);
    if (locationIndex < 0) return false;
    new Float:locX, Float:locY, Float:locZ;
    Locations_Pos(locationIndex, locX, locY, locZ);
    spawnX = locX + RENTAL_DEFAULT_OFFSET_X;
    spawnY = locY;
    spawnZ = locZ + 0.2;
    return true;
}

stock bool:Rental_SetSiteSpawn(const code[], Float:spawnX, Float:spawnY,
    Float:spawnZ, Float:angle) {
    new escaped[RENTAL_NAME_LEN * 2 + 1];
    DB_Escape(escaped, sizeof (escaped), code);
    new query[512];
    format(query, sizeof (query),
        "INSERT INTO rental_sites (location_code, spawn_x, spawn_y, spawn_z, spawn_angle) \
         VALUES ('%s', %f, %f, %f, %f) \
         ON CONFLICT(location_code) DO UPDATE SET spawn_x = excluded.spawn_x, \
         spawn_y = excluded.spawn_y, spawn_z = excluded.spawn_z, \
         spawn_angle = excluded.spawn_angle",
        escaped, spawnX, spawnY, spawnZ, angle);
    if (!DB_Exec(query)) return false;
    return true;
}

stock bool:Rental_DeleteSite(const code[]) {
    new escaped[RENTAL_NAME_LEN * 2 + 1];
    DB_Escape(escaped, sizeof (escaped), code);
    new query[160];
    format(query, sizeof (query),
        "DELETE FROM rental_sites WHERE location_code = '%s'", escaped);
    if (!DB_Exec(query)) return false;
    return true;
}
