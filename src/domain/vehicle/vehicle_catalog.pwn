// ---------------------------------------------------------------------------
// module      : domain/vehicle/vehicle_catalog
// entry       : VehicleCatalog_Boot()
// depends     : core/db, core/log
// owns tables : vehicle_catalog
// public api  : VehicleCatalog_Boot(), VehicleCatalog_Reload(),
//               VehicleCatalog_Count(), VehicleCatalog_Id(), VehicleCatalog_Name(),
//               VehicleCatalog_Model(), VehicleCatalog_Price(),
//               VehicleCatalog_Add(), VehicleCatalog_Remove()
// Aturan      : harga dealer tidak boleh hardcode di kode UI; semua lewat tabel
//               ini supaya admin bisa mengubah katalog tanpa compile ulang.
// ---------------------------------------------------------------------------
#if defined _INC_VEHICLE_CATALOG
    #endinput
#endif
#define _INC_VEHICLE_CATALOG

#define CATALOG_MAX         (10)
#define CATALOG_NAME_LEN    (24)

static gCatalogCount = 0;
static gCatalogId[CATALOG_MAX];
static gCatalogModel[CATALOG_MAX];
static gCatalogPrice[CATALOG_MAX];
static gCatalogName[CATALOG_MAX][CATALOG_NAME_LEN];

stock VehicleCatalog_Boot() {
    if (!DB_Exec("CREATE TABLE IF NOT EXISTS vehicle_catalog (\
            catalog_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            name TEXT NOT NULL,\
            model INTEGER NOT NULL,\
            price INTEGER NOT NULL,\
            enabled INTEGER NOT NULL DEFAULT 1,\
            created_at TEXT DEFAULT (datetime('now')))")) {
        Log_Error("vehicle", "gagal membuat tabel vehicle_catalog");
        return 0;
    }

    if (DB_Int("SELECT COUNT(*) FROM vehicle_catalog", 0) == 0) {
        DB_Exec("INSERT INTO vehicle_catalog (name, model, price) \
                 VALUES ('Sepeda BMX', 481, 75000)");
        DB_Exec("INSERT INTO vehicle_catalog (name, model, price) \
                 VALUES ('Motor Faggio', 462, 400000)");
        DB_Exec("INSERT INTO vehicle_catalog (name, model, price) \
                 VALUES ('Mobil Elegant', 507, 900000)");
        DB_Exec("INSERT INTO vehicle_catalog (name, model, price) \
                 VALUES ('Mobil Savanna', 567, 1100000)");
        DB_Exec("INSERT INTO vehicle_catalog (name, model, price) \
                 VALUES ('Mobil Landstalker', 400, 1500000)");
        DB_Exec("INSERT INTO vehicle_catalog (name, model, price) \
                 VALUES ('Van Burrito', 482, 2500000)");
    }

    VehicleCatalog_Reload();
    return 1;
}

stock VehicleCatalog_Reload() {
    new total = DB_Int("SELECT COUNT(*) FROM vehicle_catalog WHERE enabled = 1", 0);
    if (total > CATALOG_MAX) total = CATALOG_MAX;

    gCatalogCount = 0;
    for (new row = 0; row < total; row++) {
        new query[192];
        format(query, sizeof (query),
            "SELECT catalog_id, name, model, price FROM vehicle_catalog \
             WHERE enabled = 1 ORDER BY price LIMIT 1 OFFSET %d", row);
        new catalogId = DB_IntAt(query, 0, 0, 0);
        if (catalogId <= 0) continue;

        gCatalogId[gCatalogCount] = catalogId;
        DB_StrAt(query, 0, 1, gCatalogName[gCatalogCount], CATALOG_NAME_LEN);
        gCatalogModel[gCatalogCount] = DB_IntAt(query, 0, 2, 0);
        gCatalogPrice[gCatalogCount] = DB_IntAt(query, 0, 3, 0);
        if (gCatalogModel[gCatalogCount] <= 0) continue;
        if (gCatalogPrice[gCatalogCount] <= 0) continue;
        gCatalogCount++;
    }

    new report[64];
    format(report, sizeof (report), "katalog dealer dimuat: %d", gCatalogCount);
    Log_Info("vehicle", report);
    return gCatalogCount;
}

stock VehicleCatalog_Count() {
    return gCatalogCount;
}

stock VehicleCatalog_Id(index) {
    if (index < 0 || index >= gCatalogCount) return 0;
    return gCatalogId[index];
}

stock VehicleCatalog_Name(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gCatalogCount) return format(dest, maxlength, "-");
    return format(dest, maxlength, "%s", gCatalogName[index]);
}

stock VehicleCatalog_Model(index) {
    if (index < 0 || index >= gCatalogCount) return 0;
    return gCatalogModel[index];
}

stock VehicleCatalog_Price(index) {
    if (index < 0 || index >= gCatalogCount) return 0;
    return gCatalogPrice[index];
}

stock bool:VehicleCatalog_Add(const name[], model, price) {
    if (model < 400 || model > 611) return false;
    if (price < 1000 || price > 100000000) return false;
    if (gCatalogCount >= CATALOG_MAX) return false;

    new escapedName[CATALOG_NAME_LEN * 2 + 1];
    DB_Escape(escapedName, sizeof (escapedName), name);
    new query[256];
    format(query, sizeof (query),
        "INSERT INTO vehicle_catalog (name, model, price) VALUES ('%s', %d, %d)",
        escapedName, model, price);
    if (!DB_Exec(query)) return false;

    VehicleCatalog_Reload();
    return true;
}

stock bool:VehicleCatalog_Remove(index) {
    new catalogId = VehicleCatalog_Id(index);
    if (catalogId <= 0) return false;

    new query[128];
    format(query, sizeof (query),
        "UPDATE vehicle_catalog SET enabled = 0 WHERE catalog_id = %d", catalogId);
    if (!DB_Exec(query)) return false;

    VehicleCatalog_Reload();
    return true;
}
