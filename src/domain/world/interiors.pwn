// ---------------------------------------------------------------------------
// module      : domain/world/interiors
// entry       : Interiors_Boot()
// depends     : core/db, core/log, domain/property (API gedung), ui/toast
// owns tables : - (menambah kolom buildings.interior_id)
// public api  : Interiors_Boot(), Interiors_Enter(), Interiors_Exit(),
//               Interiors_OnPickup(), Interiors_PendingTick(),
//               Interiors_Reset(), Interiors_SetForBuilding(),
//               Interiors_NameOf()
// Isi         : MAPPING CUSTOM (bukan interior vanilla). Setiap gedung yang
//               punya interior_id > 0 mendapat salinan interior buatan sendiri
//               di langit (skybox) pada koordinat terpisah per gedung:
//               X = 500 + (index gedung * 150), Y = 500, Z = 400.
//               Pemisahan pakai jarak (bukan virtual world) supaya aman untuk
//               klien 0.3.7 lama. Blueprint tersedia: 1 = Warung Kelontong,
//               2 = Minimarket. Masuk lewat prompt lokasi gedung, keluar
//               lewat pickup di depan pintu.
// Aturan      : Objek dibuat sekali saat boot/set; UI toko TIDAK dibuka di
//               dalam callback pickup - ditunda ke tick berikutnya.
// ---------------------------------------------------------------------------
#if defined _INC_DOMAIN_WORLD_INTERIORS
    #endinput
#endif
#define _INC_DOMAIN_WORLD_INTERIORS

#define INT_BLUEPRINT_MAX   (2)
#define INT_OBJ_MAX         (48)
#define INT_ORIGIN_X        (500.0)
#define INT_ORIGIN_Y        (500.0)
#define INT_ORIGIN_Z        (400.0)
#define INT_STEP_X          (150.0)
#define INT_STEP_Y          (150.0)
#define INT_STEP_Z          (45.0)
#define INT_EXIT_PICKUP     (1239)

// INT_UI_NONE/SHOP/MANAGE didefinisikan di domain/property/property.pwn
// (disertakan lebih dulu).

// --- Struktur blueprint (dipusat di 0,0,0; digeser saat spawn) ---
static gBpCount[INT_BLUEPRINT_MAX];
static gBpModel[INT_BLUEPRINT_MAX][INT_OBJ_MAX];
static Float:gBpX[INT_BLUEPRINT_MAX][INT_OBJ_MAX];
static Float:gBpY[INT_BLUEPRINT_MAX][INT_OBJ_MAX];
static Float:gBpZ[INT_BLUEPRINT_MAX][INT_OBJ_MAX];
static Float:gBpRz[INT_BLUEPRINT_MAX][INT_OBJ_MAX];
static Float:gBpRx[INT_BLUEPRINT_MAX][INT_OBJ_MAX];

// --- Geometri panel dinding SA-MP (wall025 = 19377, wall027 = 19379) ---
// Ukuran asli model: 9.63762 lebar x 10.50146 tinggi x 0.1787764 tebal.
//  - Dinding: panel tegak, DITANAM ke bawah supaya hanya INT_ROOM_H (2.6 m)
//    yang terlihat di atas lantai (tinggi panel 10.5 m tidak bisa diskala).
//  - Lantai/plafon: panel diputar rx=90 menjadi slab horizontal 9.64 x 10.5.
#define INT_PANEL_W     (9.63762)
#define INT_PANEL_H     (10.50146)
#define INT_PANEL_T     (0.1787764)
#define INT_ROOM_H      (2.6)
#define INT_HALF_W      (INT_PANEL_W / 2.0)
#define INT_WALL_Z      (INT_ROOM_H - INT_PANEL_H / 2.0)
#define INT_ROOF_Z      (INT_ROOM_H + INT_PANEL_T / 2.0)
#define INT_FLOOR_Z     (-INT_PANEL_T / 2.0)
static Float:gBpSpawnX[INT_BLUEPRINT_MAX], Float:gBpSpawnY[INT_BLUEPRINT_MAX];
static Float:gBpSpawnA[INT_BLUEPRINT_MAX];
static Float:gBpExitX[INT_BLUEPRINT_MAX], Float:gBpExitY[INT_BLUEPRINT_MAX];

// --- Objek & pickup per gedung ---
static gIntObjectId[PROP_MAX][INT_OBJ_MAX];
static gIntExitPickup[PROP_MAX];
static Text3D:gIntExitLabel[PROP_MAX];

// --- State pemain ---
static gIntInside[MAX_PLAYERS] = { -1, ... };   // index gedung, -1 = di luar
static gIntPendingUi[MAX_PLAYERS];
static gIntPendingExit[MAX_PLAYERS];
static Float:gIntRetX[MAX_PLAYERS], Float:gIntRetY[MAX_PLAYERS],
    Float:gIntRetZ[MAX_PLAYERS], Float:gIntRetA[MAX_PLAYERS];
static gIntRetInterior[MAX_PLAYERS], gIntRetWorld[MAX_PLAYERS];

static Bp_AddEx(bp, model, Float:dx, Float:dy, Float:dz, Float:rx, Float:rz) {
    if (bp < 0 || bp >= INT_BLUEPRINT_MAX) return 0;
    if (gBpCount[bp] >= INT_OBJ_MAX) {
        Log_Warn("interiors", "blueprint penuh");
        return 0;
    }
    new slot = gBpCount[bp];
    gBpModel[bp][slot] = model;
    gBpX[bp][slot] = dx;
    gBpY[bp][slot] = dy;
    gBpZ[bp][slot] = dz;
    gBpRx[bp][slot] = rx;
    gBpRz[bp][slot] = rz;
    gBpCount[bp]++;
    return 1;
}

static Bp_Add(bp, model, Float:dx, Float:dy, Float:dz, Float:rz) {
    return Bp_AddEx(bp, model, dx, dy, dz, 0.0, rz);
}

// Slab horizontal (lantai / plafon) dari panel dinding yang diputar rx=90.
static Bp_Slab(bp, Float:dx, Float:dy, Float:dz) {
    return Bp_AddEx(bp, 19379, dx, dy, dz, 90.0, 0.0);
}

// Dinding tegak: hanya 2.6 m bagian atas yang tampak, sisanya di bawah lantai.
static Bp_Wall(bp, Float:dx, Float:dy, Float:rz) {
    return Bp_AddEx(bp, 19377, dx, dy, INT_WALL_Z, 0.0, rz);
}

static Interiors_BuildBlueprints() {
    // === BLUEPRINT 1: WARUNG KELONTONG (ruang 9.64 x 9.64 m, tinggi 2.6 m) ===
    Bp_Slab(0, 0.0, 0.0, INT_FLOOR_Z);            // lantai
    Bp_Slab(0, 0.0, 0.0, INT_ROOF_Z);             // plafon
    Bp_Wall(0, 0.0, INT_HALF_W, 0.0);             // dinding utara
    Bp_Wall(0, 0.0, -INT_HALF_W, 0.0);            // dinding selatan
    Bp_Wall(0, -INT_HALF_W, 0.0, 90.0);           // dinding barat
    Bp_Wall(0, INT_HALF_W, 0.0, 90.0);            // dinding timur
    // Meja kasir menghadap pintu + rak dinding belakang.
    Bp_Add(0, 2164, 0.0, -3.2, 0.45, 180.0);
    Bp_Add(0, 1843, -2.4, 4.4, 1.0, 180.0);
    Bp_Add(0, 1843, 2.4, 4.4, 1.0, 180.0);
    // Mesin minuman & snack di dinding barat, kardus stok di pojok timur.
    Bp_Add(0, 1775, -4.5, 0.5, 0.9, 90.0);
    Bp_Add(0, 1776, -4.5, -1.6, 0.9, 90.0);
    Bp_Add(0, 1224, 4.2, 3.9, 0.4, 20.0);
    Bp_Add(0, 1221, 4.0, 2.2, 0.55, -15.0);
    gBpSpawnX[0] = 0.0;  gBpSpawnY[0] = -2.6; gBpSpawnA[0] = 0.0;
    gBpExitX[0] = 0.0;   gBpExitY[0] = -4.3;

    // === BLUEPRINT 2: MINIMARKET (ruang 19.28 x 9.64 m, tinggi 2.6 m) ===
    Bp_Slab(1, -INT_HALF_W, 0.0, INT_FLOOR_Z);
    Bp_Slab(1, INT_HALF_W, 0.0, INT_FLOOR_Z);
    Bp_Slab(1, -INT_HALF_W, 0.0, INT_ROOF_Z);
    Bp_Slab(1, INT_HALF_W, 0.0, INT_ROOF_Z);
    Bp_Wall(1, -INT_HALF_W, INT_HALF_W, 0.0);
    Bp_Wall(1, INT_HALF_W, INT_HALF_W, 0.0);
    Bp_Wall(1, -INT_HALF_W, -INT_HALF_W, 0.0);
    Bp_Wall(1, INT_HALF_W, -INT_HALF_W, 0.0);
    Bp_Wall(1, -2.0 * INT_HALF_W, 0.0, 90.0);     // dinding barat
    Bp_Wall(1, 2.0 * INT_HALF_W, 0.0, 90.0);      // dinding timur
    // Rak dinding belakang + gondola tengah.
    Bp_Add(1, 1843, -7.0, 4.3, 1.0, 180.0);
    Bp_Add(1, 1843, -3.0, 4.3, 1.0, 180.0);
    Bp_Add(1, 1843, 1.0, 4.3, 1.0, 180.0);
    Bp_Add(1, 1843, 5.0, 4.3, 1.0, 180.0);
    Bp_Add(1, 1843, -6.5, 0.0, 1.0, 90.0);
    Bp_Add(1, 1843, -2.5, 0.0, 1.0, 90.0);
    Bp_Add(1, 1843, 1.5, 0.0, 1.0, 90.0);
    // Kasir, mesin minuman/snack, stok.
    Bp_Add(1, 2164, 6.5, -3.2, 0.45, 180.0);
    Bp_Add(1, 1775, -9.0, 2.2, 0.9, 90.0);
    Bp_Add(1, 1776, -9.0, 0.6, 0.9, 90.0);
    Bp_Add(1, 1224, 8.6, 3.6, 0.4, 20.0);
    Bp_Add(1, 1221, 7.4, 3.7, 0.55, -15.0);
    gBpSpawnX[1] = 0.0;  gBpSpawnY[1] = -2.6; gBpSpawnA[1] = 0.0;
    gBpExitX[1] = 0.0;   gBpExitY[1] = -4.3;
    return 1;
}

stock Interiors_Boot() {
    // Kolom interior_id pada buildings (0 = tanpa interior).
    new hasColumn = DB_Int(
        "SELECT COUNT(*) FROM pragma_table_info('buildings') \
         WHERE name = 'interior_id'", 0);
    if (hasColumn < 1) {
        DB_Exec("ALTER TABLE buildings ADD COLUMN interior_id \
            INTEGER NOT NULL DEFAULT 0");
    }
    Interiors_BuildBlueprints();

    for (new index = 0; index < Property_Count(); index++) {
        Interiors_DressBuilding(index);
    }
    Log_Info("interiors", "mapping custom siap");
    return 1;
}

static Interiors_OriginOf(index, &Float:originX, &Float:originY, &Float:originZ) {
    // Setiap gedung punya RUANG SENDIRI: grid 8x3 pada X/Y + pita Z berbeda,
    // jadi pemain dari gedung berbeda tidak mungkin bertemu di ruang sama
    // meski blueprint-nya identik.
    new col = index % 8;
    new row = (index / 8) % 3;
    originX = INT_ORIGIN_X + col * INT_STEP_X;
    originY = INT_ORIGIN_Y + row * INT_STEP_Y;
    originZ = INT_ORIGIN_Z + (index % 3) * INT_STEP_Z;
    return 1;
}

// Bangun (atau bongkar) salinan interior satu gedung + pickup keluar.
stock Interiors_DressBuilding(index) {
    if (index < 0 || index >= Property_Count()) return 0;

    // Bongkar salinan lama dulu (idempoten).
    for (new obj = 0; obj < INT_OBJ_MAX; obj++) {
        if (gIntObjectId[index][obj] != INVALID_OBJECT_ID) {
            DestroyObject(gIntObjectId[index][obj]);
            gIntObjectId[index][obj] = INVALID_OBJECT_ID;
        }
    }
    if (gIntExitPickup[index] != 0) {
        DestroyPickup(gIntExitPickup[index]);
        gIntExitPickup[index] = 0;
    }
    if (gIntExitLabel[index] != Text3D:INVALID_3DTEXT_ID) {
        Delete3DTextLabel(gIntExitLabel[index]);
        gIntExitLabel[index] = Text3D:INVALID_3DTEXT_ID;
    }

    new blueprint = Property_InteriorOf(index);
    if (blueprint < 1 || blueprint > INT_BLUEPRINT_MAX) return 0;
    new bp = blueprint - 1;

    new Float:originX, Float:originY, Float:originZ;
    Interiors_OriginOf(index, originX, originY, originZ);
    for (new obj = 0; obj < gBpCount[bp]; obj++) {
        gIntObjectId[index][obj] = CreateObject(gBpModel[bp][obj],
            originX + gBpX[bp][obj], originY + gBpY[bp][obj],
            originZ + gBpZ[bp][obj], gBpRx[bp][obj], 0.0,
            gBpRz[bp][obj]);
    }

    new Float:exitX = originX + gBpExitX[bp];
    new Float:exitY = originY + gBpExitY[bp];
    new Float:exitZ = originZ + 0.5;
    gIntExitPickup[index] = CreatePickup(INT_EXIT_PICKUP, 1,
        exitX, exitY, exitZ, 0);
    new buildingName[LOC_NAME_LEN];
    Property_NameOf(index, buildingName, sizeof (buildingName));
    new labelText[LOC_NAME_LEN + 16];
    format(labelText, sizeof (labelText), "%s\n[KELUAR]", buildingName);
    gIntExitLabel[index] = Create3DTextLabel(labelText, 0xFFFFFFFF,
        exitX, exitY, exitZ + 0.9, 25.0, 0);
    return 1;
}

stock Interiors_NameOf(blueprint, dest[], maxlength = sizeof (dest)) {
    if (blueprint == 1) return format(dest, maxlength, "Warung Kelontong");
    if (blueprint == 2) return format(dest, maxlength, "Minimarket");
    return format(dest, maxlength, "Tanpa Interior");
}

// Masuk ke dalam gedung (dipanggil Property_OpenAt). uiMode: UI yang dibuka
// otomatis setelah sampai (INT_UI_SHOP / INT_UI_MANAGE).
stock bool:Interiors_Enter(playerid, propIndex, uiMode) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (propIndex < 0 || propIndex >= Property_Count()) return false;
    new blueprint = Property_InteriorOf(propIndex);
    if (blueprint < 1 || blueprint > INT_BLUEPRINT_MAX) return false;
    new bp = blueprint - 1;

    // Simpan posisi keluar.
    GetPlayerPos(playerid, gIntRetX[playerid], gIntRetY[playerid],
        gIntRetZ[playerid]);
    GetPlayerFacingAngle(playerid, gIntRetA[playerid]);
    gIntRetInterior[playerid] = GetPlayerInterior(playerid);
    gIntRetWorld[playerid] = GetPlayerVirtualWorld(playerid);

    new Float:originX, Float:originY, Float:originZ;
    Interiors_OriginOf(propIndex, originX, originY, originZ);
    SetPlayerInterior(playerid, 0);
    SetPlayerVirtualWorld(playerid, 0);
    SetPlayerPos(playerid, originX + gBpSpawnX[bp],
        originY + gBpSpawnY[bp], originZ + 0.5);
    SetPlayerFacingAngle(playerid, gBpSpawnA[bp]);
    SetCameraBehindPlayer(playerid);

    gIntInside[playerid] = propIndex;
    gIntPendingUi[playerid] = uiMode;
    gIntPendingExit[playerid] = 0;

    new buildingName[LOC_NAME_LEN], toast[LOC_NAME_LEN + 12];
    Property_NameOf(propIndex, buildingName, sizeof (buildingName));
    format(toast, sizeof (toast), "Masuk %s", buildingName);
    Toast_Show(playerid, "GEDUNG", toast, THEME_ACCENT);
    return true;
}

stock bool:Interiors_IsInside(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gIntInside[playerid] >= 0;
}

// Keluar: kembalikan pemain ke posisi sebelum masuk.
stock bool:Interiors_Exit(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (gIntInside[playerid] < 0) return false;

    SetPlayerInterior(playerid, gIntRetInterior[playerid]);
    SetPlayerVirtualWorld(playerid, gIntRetWorld[playerid]);
    SetPlayerPos(playerid, gIntRetX[playerid], gIntRetY[playerid],
        gIntRetZ[playerid]);
    SetPlayerFacingAngle(playerid, gIntRetA[playerid]);
    SetCameraBehindPlayer(playerid);
    gIntInside[playerid] = -1;
    gIntPendingUi[playerid] = INT_UI_NONE;
    gIntPendingExit[playerid] = 0;
    return true;
}

// Tanggapi pickup keluar: tandai, eksekusi di tick berikutnya.
stock bool:Interiors_OnPickup(playerid, pickupid) {
    for (new index = 0; index < Property_Count(); index++) {
        if (gIntExitPickup[index] != pickupid) continue;
        if (playerid < 0 || playerid >= MAX_PLAYERS) return true;
        if (gIntInside[playerid] != index) return true;
        gIntPendingExit[playerid] = 1;
        return true;
    }
    return false;
}

// Tick 500ms: buka UI tertunda / eksekusi keluar tertunda.
stock Interiors_PendingTick(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gIntPendingExit[playerid]) {
        gIntPendingExit[playerid] = 0;
        Interiors_Exit(playerid);
        return 1;
    }
    new pendingUi = gIntPendingUi[playerid];
    if (pendingUi == INT_UI_NONE) return 0;
    gIntPendingUi[playerid] = INT_UI_NONE;

    new propIndex = gIntInside[playerid];
    if (propIndex < 0) return 0;
    if (pendingUi == INT_UI_MANAGE) {
        Property_ManageOpen(playerid, propIndex);
        return 1;
    }
    if (pendingUi == INT_UI_SHOP) {
        new warung = Property_WarungOf(propIndex);
        if (warung >= 0) WarungUI_Open(playerid, warung);
        return 1;
    }
    return 0;
}

stock Interiors_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gIntInside[playerid] = -1;
    gIntPendingUi[playerid] = INT_UI_NONE;
    gIntPendingExit[playerid] = 0;
    return 1;
}

// Admin pasang/ganti/hapus blueprint gedung terdekat. Tulis DB lalu bangun
// ulang salinan interior gedung itu.
stock bool:Interiors_SetForBuilding(propIndex, blueprint) {
    if (propIndex < 0 || propIndex >= Property_Count()) return false;
    if (blueprint < 0 || blueprint > INT_BLUEPRINT_MAX) return false;

    new query[128];
    format(query, sizeof (query),
        "UPDATE buildings SET interior_id = %d WHERE building_id = %d",
        blueprint, Property_IdOf(propIndex));
    if (!DB_Exec(query)) return false;

    Property_Reload();
    Interiors_DressBuilding(propIndex);
    return true;
}
