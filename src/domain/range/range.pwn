// ---------------------------------------------------------------------------
// module      : domain/range/range
// entry       : public Timer_OnRangeTick()
// depends     : domain/range/range_data, domain/world/locations, shared/money,
//               shared/messages, shared/player_phase, ui/toast, ui/theme
// owns tables : - (rekor milik range_data)
// public api  : Range_Boot(), Range_Open(), Range_Reset(), Range_OnWeaponShot(),
//               Range_Tick(), Range_HandleCommand(), Range_OnDialogResponse()
// Isi         : arena latihan tembak + siklus sesi (mulai, hitung, akhiri). Arena dibangun dari objek (lantai + dinding
//               + sasaran) pada ketinggian kosong dan VirtualWorld sendiri, jadi
//               tidak bergantung pada terrain dan tidak bisa ditembus pemain luar.
// Aturan      : senjata HANYA diberikan saat sesi aktif dan selalu dicabut saat
//               sesi berakhir, pemain keluar arena, tewas, atau putus koneksi.
//               Skor dihitung server-side dari posisi peluru (OnPlayerWeaponShot),
//               bukan dari klien.
// ---------------------------------------------------------------------------
#if defined _INC_RANGE
    #endinput
#endif
#define _INC_RANGE

// Arena: di atas peta (z = 300) supaya tidak ada terrain liar, dan VirtualWorld
// khusus supaya pemain di dunia normal tidak melihat/mengganggu sesi.
#define RANGE_ORIGIN_X      (2600.0)
#define RANGE_ORIGIN_Y      (500.0)
#define RANGE_ORIGIN_Z      (300.0)
#define RANGE_VW            (900)

// Geometri mengikuti panel yang sama dengan interior (docs/13): slab 9.64 x 10.5,
// dinding 9.64 x 2.6 yang dinaikkan agar hanya 2.6 m bagian atas yang tampak.
#define RANGE_SLAB_Z        (Float:-0.089388)
#define RANGE_WALL_Z        (Float:-2.65073)
#define RANGE_HALF_W        (Float:4.82)
#define RANGE_HALF_D        (Float:10.5)
#define RANGE_SLAB_D        (Float:5.25)

#define RANGE_MODE_MAX      (3)
#define RANGE_TARGET_MAX    (3)
#define RANGE_SHOT_RADIUS   (Float:1.7)
#define RANGE_SHOT_HEIGHT   (Float:1.6)
#define RANGE_SECONDS       (90)
#define RANGE_EXIT_RANGE    (Float:25.0)

static const gRangeModeName[RANGE_MODE_MAX][20] = {
    "Pistol 9mm", "Shotgun", "Rifle"
};
static const WEAPON:gRangeModeWeapon[RANGE_MODE_MAX] = {
    WEAPON_COLT45, WEAPON_SHOTGUN, WEAPON_RIFLE
};
static const gRangeModeAmmo[RANGE_MODE_MAX] = { 48, 24, 20 };
static const gRangeModePrice[RANGE_MODE_MAX] = { 2500, 4000, 6000 };
static const gRangeModePoints[RANGE_MODE_MAX] = { 1, 2, 3 };

// Pusat sasaran relatif terhadap origin: dekat / sedang / jauh.
static const Float:gTargetY[RANGE_TARGET_MAX] = { 2.0, 6.0, 9.5 };
static const gTargetPoints[RANGE_TARGET_MAX] = { 10, 20, 30 };

static gRangeObjects[24];
static gRangeObjectCount = 0;
static Text3D:gRangeLabel[RANGE_TARGET_MAX + 1];

static gRangeActive[MAX_PLAYERS];
static gRangeMode[MAX_PLAYERS];
static gRangeEnd[MAX_PLAYERS];
static gRangeShots[MAX_PLAYERS];
static gRangeHits[MAX_PLAYERS];
static gRangePoints[MAX_PLAYERS];
static Float:gRangeBackX[MAX_PLAYERS], Float:gRangeBackY[MAX_PLAYERS],
    Float:gRangeBackZ[MAX_PLAYERS], Float:gRangeBackA[MAX_PLAYERS];
static gRangeBackVW[MAX_PLAYERS], gRangeBackInt[MAX_PLAYERS];
static PlayerText:gRangeHud[MAX_PLAYERS];
static gRangeHudShown[MAX_PLAYERS];

static Range_SpawnObject(model, Float:x, Float:y, Float:z, Float:rx, Float:rz) {
    if (gRangeObjectCount >= sizeof (gRangeObjects)) return 0;
    gRangeObjects[gRangeObjectCount] = CreateObject(model, x, y, z, rx, 0.0, rz);
    if (gRangeObjects[gRangeObjectCount] == INVALID_OBJECT_ID) {
        Log_Warn("range", "objek arena gagal dibuat");
        return 0;
    }
    gRangeObjectCount++;
    return 1;
}

// Sasaran dibuat dari peti (model yang sudah dipakai warung) bertumpuk dua,
// jadi terlihat jelas sebagai target dan tetap solid saat ditembak.
static Range_BuildTarget(index) {
    new Float:y = RANGE_ORIGIN_Y + gTargetY[index];
    Range_SpawnObject(1224, RANGE_ORIGIN_X, y, RANGE_ORIGIN_Z + 0.4, 0.0, 0.0);
    Range_SpawnObject(1224, RANGE_ORIGIN_X, y, RANGE_ORIGIN_Z + 1.2, 0.0, 25.0);
    new text[32];
    format(text, sizeof (text), "SASARAN %d POIN", gTargetPoints[index]);
    gRangeLabel[index + 1] = Create3DTextLabel(text, 0xF59E0BFF,
        RANGE_ORIGIN_X, y, RANGE_ORIGIN_Z + 2.1, 12.0, RANGE_VW);
    return 1;
}

static Range_BuildArena() {
    // Lantai dua panel (9.64 x 10.5) menutup kedalaman 21 m.
    Range_SpawnObject(19379, RANGE_ORIGIN_X, RANGE_ORIGIN_Y - RANGE_SLAB_D,
        RANGE_ORIGIN_Z + RANGE_SLAB_Z, 90.0, 0.0);
    Range_SpawnObject(19379, RANGE_ORIGIN_X, RANGE_ORIGIN_Y + RANGE_SLAB_D,
        RANGE_ORIGIN_Z + RANGE_SLAB_Z, 90.0, 0.0);

    // Dinding ujung (belakang penembak & belakang sasaran).
    Range_SpawnObject(19377, RANGE_ORIGIN_X, RANGE_ORIGIN_Y - RANGE_HALF_D,
        RANGE_ORIGIN_Z + RANGE_WALL_Z, 0.0, 0.0);
    Range_SpawnObject(19377, RANGE_ORIGIN_X, RANGE_ORIGIN_Y + RANGE_HALF_D,
        RANGE_ORIGIN_Z + RANGE_WALL_Z, 0.0, 0.0);

    // Dinding samping dua segmen per sisi.
    for (new side = -1; side <= 1; side += 2) {
        new Float:x = RANGE_ORIGIN_X + RANGE_HALF_W * float(side);
        Range_SpawnObject(19377, x, RANGE_ORIGIN_Y - RANGE_SLAB_D,
            RANGE_ORIGIN_Z + RANGE_WALL_Z, 0.0, 90.0);
        Range_SpawnObject(19377, x, RANGE_ORIGIN_Y + RANGE_SLAB_D,
            RANGE_ORIGIN_Z + RANGE_WALL_Z, 0.0, 90.0);
    }

    // Meja penembak + sekat jalur, penanda garis tembak.
    Range_SpawnObject(2164, RANGE_ORIGIN_X, RANGE_ORIGIN_Y - 8.0,
        RANGE_ORIGIN_Z + 0.45, 0.0, 0.0);

    for (new index = 0; index < RANGE_TARGET_MAX; index++) {
        Range_BuildTarget(index);
    }

    gRangeLabel[0] = Create3DTextLabel("LATIHAN TEMBAK\n[Y] mulai", 0x38BDF8FF,
        RANGE_ORIGIN_X, RANGE_ORIGIN_Y - 8.6, RANGE_ORIGIN_Z + 1.2, 15.0, RANGE_VW);
    return 1;
}

stock Range_Boot() {
    RangeData_Boot();
    Range_BuildArena();

    if (!Timer_Add("Timer_OnRangeTick", 1_000, true)) {
        Log_Error("range", "timer latihan gagal didaftarkan");
        return 0;
    }

    new report[64];
    format(report, sizeof (report), "arena siap, %d objek", gRangeObjectCount);
    Log_Info("range", report);
    return 1;
}

// --- Sesi ------------------------------------------------------------------

static Range_DestroyHud(playerid) {
    if (!gRangeHudShown[playerid]) return 0;
    PlayerTextDrawHide(playerid, gRangeHud[playerid]);
    PlayerTextDrawDestroy(playerid, gRangeHud[playerid]);
    gRangeHud[playerid] = PlayerText:INVALID_TEXT_DRAW;
    gRangeHudShown[playerid] = 0;
    return 1;
}

static Range_CreateHud(playerid) {
    gRangeHud[playerid] = CreatePlayerTextDraw(playerid, 470.0, 424.0, " ");
    PlayerTextDrawFont(playerid, gRangeHud[playerid], THEME_FONT_BODY);
    PlayerTextDrawLetterSize(playerid, gRangeHud[playerid], 0.22, 1.05);
    PlayerTextDrawColour(playerid, gRangeHud[playerid], THEME_INFO);
    PlayerTextDrawSetOutline(playerid, gRangeHud[playerid], 1);
    PlayerTextDrawSetShadow(playerid, gRangeHud[playerid], 1);
    PlayerTextDrawShow(playerid, gRangeHud[playerid]);
    gRangeHudShown[playerid] = 1;
    return 1;
}

static Range_UpdateHud(playerid, secondsLeft) {
    if (!gRangeHudShown[playerid]) Range_CreateHud(playerid);

    new name[20], line[96];
    format(name, sizeof (name), "%s", gRangeModeName[gRangeMode[playerid]]);
    format(line, sizeof (line), "%s %02d:%02d | %d poin | %d hit",
        name, secondsLeft / 60, secondsLeft % 60, gRangePoints[playerid],
        gRangeHits[playerid]);
    PlayerTextDrawSetString(playerid, gRangeHud[playerid], line);
    return 1;
}

// Cabut senjata sesi. Hanya amunisi senjata sesi yang dinolkan, jadi pemain
// tidak kehilangan senjata lain yang mungkin ia bawa sah dari tempat lain.
static Range_StripWeapon(playerid) {
    new WEAPON:weapon = gRangeModeWeapon[gRangeMode[playerid]];
    if (_:weapon == 0) return 0;
    SetPlayerAmmo(playerid, weapon, 0);
    SetPlayerArmedWeapon(playerid, WEAPON_FIST);
    return 1;
}

stock Range_End(playerid, bool:saveScore) {
    if (!gRangeActive[playerid]) return 0;
    gRangeActive[playerid] = 0;
    Range_StripWeapon(playerid);
    Range_DestroyHud(playerid);

    new score = gRangePoints[playerid];
    new hits = gRangeHits[playerid];
    new shots = gRangeShots[playerid];
    new characterId = Character_GetId(playerid);

    if (saveScore && characterId > 0) RangeData_Save(characterId, score, hits);

    // Kembali ke tempat asal, termasuk dunia & interior semula.
    SetPlayerVirtualWorld(playerid, gRangeBackVW[playerid]);
    SetPlayerInterior(playerid, gRangeBackInt[playerid]);
    SetPlayerPos(playerid, gRangeBackX[playerid], gRangeBackY[playerid],
        gRangeBackZ[playerid]);
    SetPlayerFacingAngle(playerid, gRangeBackA[playerid]);
    SetCameraBehindPlayer(playerid);
    SetPlayerHealth(playerid, 100.0);

    new accuracy = shots > 0 ? (hits * 100 / shots) : 0;
    new detail[128];
    format(detail, sizeof (detail),
        "Sesi selesai: %d poin, %d hit dari %d tembakan (%d%% akurasi).",
        score, hits, shots, accuracy);
    Toast_Show(playerid, "LATIHAN TEMBAK", detail, THEME_OK);
    Messages_SendSystem(playerid, detail);

    if (saveScore) {
        new best = RangeData_Best(characterId);
        if (score >= best && score > 0) {
            Messages_SendSystem(playerid, "Rekor pribadimu diperbarui.");
        } else if (best > 0) {
            new record[72];
            format(record, sizeof (record), "Rekor pribadimu: %d poin.", best);
            Messages_SendSystem(playerid, record);
        }
    }
    return 1;
}

stock Range_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gRangeActive[playerid]) {
        Range_End(playerid, false);
        return 1;
    }
    Range_DestroyHud(playerid);
    return 0;
}

stock bool:Range_Open(playerid) {
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return false;
    }
    if (gRangeActive[playerid]) {
        Messages_SendError(playerid, "Sesi masih berjalan. Akhiri: /latihanselesai");
        return true;
    }

    new body[256], line[96];
    body[0] = EOS;
    for (new index = 0; index < RANGE_MODE_MAX; index++) {
        new price[24];
        Text_FormatNumber(gRangeModePrice[index], price, sizeof (price));
        format(line, sizeof (line), "%s - Rp %s, %d peluru\n",
            gRangeModeName[index], price, gRangeModeAmmo[index]);
        strcat(body, line, sizeof (body));
    }

    ShowPlayerDialog(playerid, DIALOG_RANGE_MODES, DIALOG_STYLE_LIST,
        "Latihan Tembak (90 detik)", body, "Mulai", "Batal");
    return true;
}

stock bool:Range_Start(playerid, modeIndex) {
    if (modeIndex < 0 || modeIndex >= RANGE_MODE_MAX) return false;
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return false;
    }

    new price = gRangeModePrice[modeIndex];
    new priceText[24];
    Text_FormatNumber(price, priceText, sizeof (priceText));
    if (!Money_Take(playerid, price, MONEY_REASON_RANGE)) {
        new message[96];
        format(message, sizeof (message), "Uang tidak cukup. Biaya sesi Rp %s.", priceText);
        Messages_SendError(playerid, message);
        return false;
    }

    // Simpan posisi asal sebelum teleport, supaya sesi bisa mengembalikan pemain
    // tepat di tempat ia memulai.
    GetPlayerPos(playerid, gRangeBackX[playerid], gRangeBackY[playerid],
        gRangeBackZ[playerid]);
    GetPlayerFacingAngle(playerid, gRangeBackA[playerid]);
    gRangeBackVW[playerid] = GetPlayerVirtualWorld(playerid);
    gRangeBackInt[playerid] = GetPlayerInterior(playerid);

    gRangeMode[playerid] = modeIndex;
    gRangeShots[playerid] = 0;
    gRangeHits[playerid] = 0;
    gRangePoints[playerid] = 0;
    gRangeEnd[playerid] = gettime() + RANGE_SECONDS;
    gRangeActive[playerid] = 1;

    SetPlayerVirtualWorld(playerid, RANGE_VW);
    SetPlayerInterior(playerid, 0);
    SetPlayerPos(playerid, RANGE_ORIGIN_X, RANGE_ORIGIN_Y - 8.4,
        RANGE_ORIGIN_Z + 0.1);
    SetPlayerFacingAngle(playerid, 0.0);
    SetCameraBehindPlayer(playerid);
    SetPlayerHealth(playerid, 100.0);

    ResetPlayerWeapons(playerid);
    GivePlayerWeapon(playerid, gRangeModeWeapon[modeIndex], gRangeModeAmmo[modeIndex]);
    SetPlayerArmedWeapon(playerid, gRangeModeWeapon[modeIndex]);

    Range_CreateHud(playerid);
    Range_UpdateHud(playerid, RANGE_SECONDS);
    Toast_Show(playerid, "LATIHAN TEMBAK",
        "Tembak peti sasaran. Senjata dicabut otomatis saat selesai.", THEME_INFO);
    Messages_SendSystem(playerid,
        "Sasaran dekat 10 poin, sedang 20, jauh 30. Akhiri lebih awal: /latihanselesai");
    return true;
}

// Hitung tembakan: akurasi dihitung dari semua peluru, poin hanya dari yang
// benar-benar jatuh di dalam kotak sasaran.
stock Range_OnWeaponShot(playerid, WEAPON:weaponid, hittype, hitid,
    Float:fX, Float:fY, Float:fZ) {
    #pragma unused hittype, hitid
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gRangeActive[playerid]) return 0;
    if (GetPlayerVirtualWorld(playerid) != RANGE_VW) return 0;
    if (weaponid != gRangeModeWeapon[gRangeMode[playerid]]) return 0;

    gRangeShots[playerid]++;

    new Float:deltaX = fX - RANGE_ORIGIN_X;
    new Float:deltaZ = fZ - RANGE_ORIGIN_Z;
    if (deltaX > RANGE_SHOT_RADIUS || deltaX < -RANGE_SHOT_RADIUS) return 1;
    if (deltaZ < 0.0 || deltaZ > RANGE_SHOT_HEIGHT) return 1;

    for (new index = 0; index < RANGE_TARGET_MAX; index++) {
        new Float:targetY = RANGE_ORIGIN_Y + gTargetY[index];
        if (fY > targetY + RANGE_SHOT_RADIUS || fY < targetY - RANGE_SHOT_RADIUS) {
            continue;
        }
        gRangeHits[playerid]++;
        gRangePoints[playerid] += gTargetPoints[index] * gRangeModePoints[gRangeMode[playerid]];
        break;
    }
    return 1;
}

stock bool:Range_IsActive(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gRangeActive[playerid] ? true : false;
}

stock Range_Tick() {
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;

        if (!gRangeActive[playerid]) {
            if (gRangeHudShown[playerid]) Range_DestroyHud(playerid);
            continue;
        }
        if (!Phase_CanAct(playerid)) {
            Range_End(playerid, false);
            continue;
        }

        // Keluar arena (teleport/kematian) mengakhiri sesi, senjata dicabut.
        new Float:posX, Float:posY, Float:posZ;
        GetPlayerPos(playerid, posX, posY, posZ);
        if (floatsqroot((posX - RANGE_ORIGIN_X) * (posX - RANGE_ORIGIN_X)
                + (posY - RANGE_ORIGIN_Y) * (posY - RANGE_ORIGIN_Y)) > RANGE_EXIT_RANGE
                || posZ < RANGE_ORIGIN_Z - 5.0 || posZ > RANGE_ORIGIN_Z + 10.0) {
            Range_End(playerid, true);
            continue;
        }

        new secondsLeft = gRangeEnd[playerid] - gettime();
        if (secondsLeft <= 0 || GetPlayerAmmo(playerid) <= 0) {
            Range_End(playerid, true);
            continue;
        }
        Range_UpdateHud(playerid, secondsLeft);
    }
    return 1;
}

public Timer_OnRangeTick() {
    Range_Tick();
    return 1;
}
