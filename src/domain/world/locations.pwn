// ---------------------------------------------------------------------------
// module      : domain/world/locations
// entry       : Locations_Boot()
// depends     : core/db, core/log, ui/toast, ui/bankui, domain/identity,
//               domain/job/job_kurir, domain/warung
// owns tables : locations
// public api  : Locations_Boot(), Locations_Count(), Locations_Near(),
//               Locations_NearCode(), Locations_FindByCode(),
//               Locations_Name(), Locations_Code(), Locations_Add(),
//               Locations_Action(), Locations_Pos(),
//               Locations_Radius(), Locations_ShowIcons(), Locations_Activate()
// Aturan      : Semua titik layanan (ATM, loket, warung, dsb.) hidup di tabel
//               `locations` - DILARANG hardcode koordinat layanan di modul
//               lain. Aksi lokasi didispatch lewat kode aksi (teks), bukan id.
// ---------------------------------------------------------------------------
#if defined _INC_WORLD_LOCATIONS
    #endinput
#endif
#define _INC_WORLD_LOCATIONS

#define LOC_MAX             (24)
#define LOC_CODE_LEN        (24)
#define LOC_NAME_LEN        (40)
#define LOC_ACTION_LEN      (24)
#define LOC_MAP_ICON_ATM    (52)    // ikon dollar hijau di radar
#define LOC_MAP_ICON_WARUNG (50)    // ikon makanan (hotdog)
#define LOC_MAP_ICON_RS     (22)    // ikon palang RS
#define LOC_MAP_ICON_JOB    (30)    // ikon tanda tanya
#define LOC_MAP_ICON_INFO   (17)    // ikon info
#define LOC_MAP_ICON_RENTAL (55)    // ikon mobil (titik rental)

// Model pickup fisik di dunia (terlihat & bisa disentuh = buka layanan).
#define LOC_PICKUP_ATM      (1274)  // ikon dollar berputar
#define LOC_PICKUP_INFO     (1239)  // ikon tanda tanya kuning
#define LOC_PICKUP_HEALTH   (1240)  // ikon palang putih

// Model objek mesin ATM (berdiri di lantai) & gerobak warung.
#define LOC_OBJECT_ATM      (2942)
#define LOC_OBJECT_WARUNG   (1341)

// Ikon radar gedung (rumah GTA): hijau = dijual, merah = sudah dimiliki.
#define LOC_MAP_ICON_GEDUNG_SELL    (31)
#define LOC_MAP_ICON_GEDUNG_OWNED   (32)

// Kode aksi lokasi (tabel locations.action).
#define LOC_ACT_ATM         "ATM"
#define LOC_ACT_LOKET_PD    "LOKET_PD"
#define LOC_ACT_JOB_CENTER  "JOB_CENTER"
#define LOC_ACT_WARUNG      "WARUNG"
#define LOC_ACT_GEDUNG      "GEDUNG"
#define LOC_ACT_RS          "RS"
#define LOC_ACT_RENTAL      "RENTAL"
#define LOC_ACT_DEALER      "DEALER"

#define LOC_MAP_ICON_DEALER (55)    // ikon mobil (dealer)

#define RS_PRICE            (10000)

static gLocCount = 0;
static gLocCode[LOC_MAX][LOC_CODE_LEN];
static gLocName[LOC_MAX][LOC_NAME_LEN];
static gLocAction[LOC_MAX][LOC_ACTION_LEN];
static Float:gLocX[LOC_MAX];
static Float:gLocY[LOC_MAX];
static Float:gLocZ[LOC_MAX];
static Float:gLocRadius[LOC_MAX];

// Wujud dunia per lokasi: pickup + label 3D (+ objek mesin untuk ATM).
static gLocPickupId[LOC_MAX];
static Text3D:gLocLabelId[LOC_MAX];
static gLocObjectId[LOC_MAX];

stock Locations_Boot() {
    // Seed bawaan: INSERT OR IGNORE, jadi posisi di DB tidak pernah ditimpa.
    // Pemilik server bebas memindah/menambah lokasi lewat DB tanpa compile.
    Locations_Seed("ATM_STASIUN", "ATM Stasiun Unity", LOC_ACT_ATM,
        1770.5, -1896.0, 13.5, 3.0);
    Locations_Seed("ATM_IDLEWOOD", "ATM Idlewood", LOC_ACT_ATM,
        1834.5, -1853.0, 13.5, 3.0);
    Locations_Seed("ATM_JEFFERSON", "ATM Jefferson", LOC_ACT_ATM,
        2087.0, -1394.0, 15.0, 3.0);
    Locations_Seed("LOKET_PD", "Loket PD", LOC_ACT_LOKET_PD,
        1552.51, -1675.73, 15.5, 30.0);
    Locations_Seed("JOB_CENTER", "Job Center", LOC_ACT_JOB_CENTER,
        1782.0, -1894.0, 13.5, 4.0);
    Locations_Seed("WARUNG_STASIUN", "Warung Bu Sari", LOC_ACT_WARUNG,
        1796.0, -1890.0, 13.5, 3.0);
    Locations_Seed("RS_ALL_SAINTS", "RS All Saints", LOC_ACT_RS,
        1173.0, -1323.5, 15.0, 4.0);
    Locations_Seed("RENTAL_STASIUN", "Rental Stasiun Unity", LOC_ACT_RENTAL,
        1766.4, -1906.0, 13.5, 3.0);
    Locations_Seed("DEALER_STASIUN", "Dealer Stasiun Unity", LOC_ACT_DEALER,
        1750.0, -1898.0, 13.5, 3.0);

    gLocCount = 0;
    new query[128];
    format(query, sizeof (query), "SELECT COUNT(*) FROM locations");
    new total = DB_Int(query, 0);
    if (total > LOC_MAX) total = LOC_MAX;

    for (new row = 0; row < total; row++) {
        format(query, sizeof (query),
            "SELECT code, name, action, pos_x, pos_y, pos_z, radius \
             FROM locations ORDER BY location_id LIMIT 1 OFFSET %d", row);
        new code[LOC_CODE_LEN];
        if (!DB_StrAt(query, 0, 0, code, sizeof (code))) continue;

        format(gLocCode[gLocCount], LOC_CODE_LEN, "%s", code);
        DB_StrAt(query, 0, 1, gLocName[gLocCount], LOC_NAME_LEN);
        DB_StrAt(query, 0, 2, gLocAction[gLocCount], LOC_ACTION_LEN);
        gLocX[gLocCount] = DB_FloatAt(query, 0, 3);
        gLocY[gLocCount] = DB_FloatAt(query, 0, 4);
        gLocZ[gLocCount] = DB_FloatAt(query, 0, 5);
        gLocRadius[gLocCount] = DB_FloatAt(query, 0, 6);
        if (gLocRadius[gLocCount] < 2.0) gLocRadius[gLocCount] = 2.0;
        Locations_Dress(gLocCount);
        gLocCount++;
    }

    new report[64];
    format(report, sizeof (report), "lokasi layanan dimuat: %d", gLocCount);
    Log_Info("locations", report);
    return 1;
}

static Locations_Seed(const code[], const name[], const action[],
    Float:x, Float:y, Float:z, Float:radius) {
    new escapedName[LOC_NAME_LEN * 2 + 1];
    DB_Escape(escapedName, sizeof (escapedName), name);

    new query[320];
    format(query, sizeof (query),
        "INSERT OR IGNORE INTO locations (code, name, action, pos_x, pos_y, pos_z, radius) \
         VALUES ('%s', '%s', '%s', %f, %f, %f, %f)",
        code, escapedName, action, x, y, z, radius);
    if (!DB_Exec(query)) {
        Log_Error("locations", "gagal seed lokasi");
        return 0;
    }
    return 1;
}

// Model pickup sesuai jenis layanan.
static Locations_PickupModelOf(const action[]) {
    if (strcmp(action, LOC_ACT_ATM, false) == 0) return LOC_PICKUP_ATM;
    if (strcmp(action, LOC_ACT_RS, false) == 0) return LOC_PICKUP_HEALTH;
    return LOC_PICKUP_INFO;
}

// Model prop fisik sesuai jenis layanan. Gedung memakai shell bangunan
// (modul props) - bukan satu objek tunggal.
static Locations_PropModelOf(const action[]) {
    if (strcmp(action, LOC_ACT_ATM, false) == 0) return LOC_OBJECT_ATM;
    if (strcmp(action, LOC_ACT_WARUNG, false) == 0) return LOC_OBJECT_WARUNG;
    return 0;
}

// Pasang wujud dunia satu lokasi: pickup + label 3D + objek prop.
static Locations_Dress(index) {
    new labelText[LOC_NAME_LEN + 24];
    format(labelText, sizeof (labelText), "%s\n[Y] Interaksi",
        gLocName[index]);

    gLocPickupId[index] = CreatePickup(
        Locations_PickupModelOf(gLocAction[index]), 1,
        gLocX[index], gLocY[index], gLocZ[index], 0);
    gLocLabelId[index] = Create3DTextLabel(labelText, 0xFFFFFFFF,
        gLocX[index], gLocY[index], gLocZ[index] + 0.9, 25.0, 0);

    gLocObjectId[index] = INVALID_OBJECT_ID;
    Locations_Redress(index);
    return 1;
}

// Bangun ulang wujud fisik lokasi (prop tunggal / shell gedung) tanpa
// menyentuh pickup & label. Dipakai saat jenis lokasi berubah (migrasi).
stock Locations_Redress(index) {
    if (index < 0 || index >= gLocCount) return 0;
    if (gLocObjectId[index] != INVALID_OBJECT_ID) {
        DestroyObject(gLocObjectId[index]);
        gLocObjectId[index] = INVALID_OBJECT_ID;
    }
    new propModel = Locations_PropModelOf(gLocAction[index]);
    if (propModel > 0) {
        gLocObjectId[index] = CreateObject(propModel,
            gLocX[index], gLocY[index], gLocZ[index] - 0.1, 0.0, 0.0, 0.0);
    }
    return 1;
}

// Handle label 3D (untuk modul yang mau memperbarui teks label, mis. status
// DIJUAL/MILIK pada gedung).
stock Text3D:Locations_LabelId(index) {
    if (index < 0 || index >= gLocCount) return Text3D:INVALID_3DTEXT_ID;
    return gLocLabelId[index];
}

// Pasang handle label baru (dipakai locations_label.pwn untuk mengganti teks).
stock Locations_SetLabelHandle(index, Text3D:label) {
    if (index < 0 || index >= gLocCount) return 0;
    if (gLocLabelId[index] != Text3D:INVALID_3DTEXT_ID) {
        Delete3DTextLabel(gLocLabelId[index]);
    }
    gLocLabelId[index] = label;
    return 1;
}

// Hapus lokasi (dipakai admin saat membongkar titik layanan). Wujud dunia
// dibersihkan dulu, baris DB dihapus, lalu array dimampatkan.
stock Locations_Delete(index) {
    if (index < 0 || index >= gLocCount) return 0;

    new query[128];
    format(query, sizeof (query), "DELETE FROM locations WHERE code = '%s'",
        gLocCode[index]);
    if (!DB_Exec(query)) {
        Log_Error("locations", "gagal hapus lokasi");
        return 0;
    }

    if (gLocPickupId[index] > 0) DestroyPickup(gLocPickupId[index]);
    if (gLocLabelId[index] != Text3D:INVALID_3DTEXT_ID) {
        Delete3DTextLabel(gLocLabelId[index]);
    }
    if (gLocObjectId[index] != INVALID_OBJECT_ID) {
        DestroyObject(gLocObjectId[index]);
    }

    for (new move = index; move < gLocCount - 1; move++) {
        format(gLocCode[move], LOC_CODE_LEN, "%s", gLocCode[move + 1]);
        format(gLocName[move], LOC_NAME_LEN, "%s", gLocName[move + 1]);
        format(gLocAction[move], LOC_ACTION_LEN, "%s", gLocAction[move + 1]);
        gLocX[move] = gLocX[move + 1];
        gLocY[move] = gLocY[move + 1];
        gLocZ[move] = gLocZ[move + 1];
        gLocRadius[move] = gLocRadius[move + 1];
        gLocPickupId[move] = gLocPickupId[move + 1];
        gLocLabelId[move] = gLocLabelId[move + 1];
        gLocObjectId[move] = gLocObjectId[move + 1];
    }
    gLocCount--;
    Locations_RefreshIconsAll();
    return 1;
}

// --- Akses baca ------------------------------------------------------------

stock Locations_Count() {
    return gLocCount;
}

stock Locations_Code(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gLocCount) return format(dest, maxlength, "");
    return format(dest, maxlength, "%s", gLocCode[index]);
}

stock Locations_Name(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gLocCount) return format(dest, maxlength, "-");
    return format(dest, maxlength, "%s", gLocName[index]);
}

stock Locations_Action(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gLocCount) return format(dest, maxlength, "");
    return format(dest, maxlength, "%s", gLocAction[index]);
}

stock Locations_Pos(index, &Float:x, &Float:y, &Float:z) {
    x = 0.0;
    y = 0.0;
    z = 0.0;
    if (index < 0 || index >= gLocCount) return 0;
    x = gLocX[index];
    y = gLocY[index];
    z = gLocZ[index];
    return 1;
}

stock Float:Locations_Radius(index) {
    if (index < 0 || index >= gLocCount) return 0.0;
    return gLocRadius[index];
}

stock Locations_FindByCode(const code[]) {
    for (new index = 0; index < gLocCount; index++) {
        if (strcmp(gLocCode[index], code, false) == 0) return index;
    }
    return -1;
}

// --- Pencarian terdekat ----------------------------------------------------

// Lokasi terdekat dalam radius (+ margin). `extraMargin` dipakai prompt untuk
// hysteresis supaya pil tidak kedip di batas radius. Beda ketinggian dibatasi
// agar pemain di lantai atas tidak dianggap berada di lokasi lantai dasar.
stock Locations_NearWithin(playerid, Float:extraMargin) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;

    new Float:posX, Float:posY, Float:posZ;
    GetPlayerPos(playerid, posX, posY, posZ);

    new best = -1;
    new Float:bestDistance = 0.0;
    for (new index = 0; index < gLocCount; index++) {
        new Float:deltaZ = posZ - gLocZ[index];
        if (deltaZ > 6.0 || deltaZ < -6.0) continue;

        new Float:deltaX = posX - gLocX[index];
        new Float:deltaY = posY - gLocY[index];
        new Float:distance = floatsqroot(deltaX * deltaX + deltaY * deltaY);
        if (distance > gLocRadius[index] + extraMargin) continue;
        if (best >= 0 && distance >= bestDistance) continue;
        best = index;
        bestDistance = distance;
    }
    return best;
}

stock Locations_Near(playerid) {
    return Locations_NearWithin(playerid, 0.0);
}

// Lokasi terdekat dengan kode aksi tertentu (mis. gerbang ujian SIM).
stock Locations_NearCode(playerid, const action[]) {
    new nearest = Locations_Near(playerid);
    if (nearest < 0) return -1;
    if (strcmp(gLocAction[nearest], action, false) == 0) return nearest;

    // Cari kandidat lain yang aksinya cocok dalam radius masing-masing.
    new Float:posX, Float:posY, Float:posZ;
    GetPlayerPos(playerid, posX, posY, posZ);
    for (new index = 0; index < gLocCount; index++) {
        if (strcmp(gLocAction[index], action, false) != 0) continue;
        new Float:deltaX = posX - gLocX[index];
        new Float:deltaY = posY - gLocY[index];
        if (floatsqroot(deltaX * deltaX + deltaY * deltaY) > gLocRadius[index]) {
            continue;
        }
        return index;
    }
    return -1;
}

// --- Penambahan runtime ----------------------------------------------------

// Tambah lokasi baru (dipakai /buatatm, /buatwarung, /buatgedung). Gagal bila
// daftar penuh atau DB menolak; memori hanya diisi setelah DB sukses.
stock Locations_Add(const code[], const name[], const action[],
    Float:x, Float:y, Float:z, Float:radius) {
    if (gLocCount >= LOC_MAX) return -1;
    if (Locations_FindByCode(code) >= 0) return -1;

    new escapedName[LOC_NAME_LEN * 2 + 1];
    DB_Escape(escapedName, sizeof (escapedName), name);
    new Float:safeRadius = radius;
    if (safeRadius < 2.0) safeRadius = 2.0;

    new query[320];
    format(query, sizeof (query),
        "INSERT INTO locations (code, name, action, pos_x, pos_y, pos_z, radius) \
         VALUES ('%s', '%s', '%s', %f, %f, %f, %f)",
        code, escapedName, action, x, y, z, safeRadius);
    if (!DB_Exec(query)) {
        Log_Error("locations", "gagal tambah lokasi");
        return -1;
    }

    new index = gLocCount;
    format(gLocCode[index], LOC_CODE_LEN, "%s", code);
    format(gLocName[index], LOC_NAME_LEN, "%s", name);
    format(gLocAction[index], LOC_ACTION_LEN, "%s", action);
    gLocX[index] = x;
    gLocY[index] = y;
    gLocZ[index] = z;
    gLocRadius[index] = safeRadius;
    gLocCount++;
    Locations_Dress(index);
    Locations_RefreshIconsAll();
    return index;
}

// Ubah jenis layanan lokasi (mis. WARUNG -> GEDUNG saat migrasi).
stock Locations_SetAction(index, const action[]) {
    if (index < 0 || index >= gLocCount) return 0;

    new query[160];
    format(query, sizeof (query),
        "UPDATE locations SET action = '%s' WHERE code = '%s'",
        action, gLocCode[index]);
    if (!DB_Exec(query)) return 0;

    format(gLocAction[index], LOC_ACTION_LEN, "%s", action);
    Locations_Redress(index);
    Locations_RefreshIconsAll();
    return 1;
}
