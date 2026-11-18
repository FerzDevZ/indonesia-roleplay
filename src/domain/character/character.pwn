// ---------------------------------------------------------------------------
// module      : domain/character
// entry       : Character_Boot()
// depends     : core/db, shared/money, shared/player_phase, shared/messages
// owns tables : characters
// public api  : Character_Boot(), Character_ShowSelector(),
//               Character_OnDialogResponse(), Character_Load(),
//               Character_Save(), Character_GetId(), Character_GetFullName()
// ---------------------------------------------------------------------------
#if defined _INC_CHARACTER
    #endinput
#endif
#define _INC_CHARACTER

#define DEFAULT_SKIN_MALE   (250)
#define DEFAULT_SKIN_FEMALE (233)
// Spawn pemain: halaman Stasiun Kereta Unity (dekat pusat kota, jalur
// layanan onboarding docs/11) - bukan koordinat kosong.
#define SPAWN_POS_X         (1766.4)
#define SPAWN_POS_Y         (-1899.4)
#define SPAWN_POS_Z         (13.5)
#define SPAWN_POS_ANGLE     (180.0)

static gCharacterId[MAX_PLAYERS] = { -1, ... };
static gSkinModel[MAX_PLAYERS] = { DEFAULT_SKIN_MALE, ... };
static gFullName[MAX_PLAYERS][48];
new gPendingFirst[MAX_PLAYERS][MAX_USERNAME_LENGTH + 1];
new gPendingLast[MAX_PLAYERS][MAX_USERNAME_LENGTH + 1];

stock Character_Boot() {
    Log_Info("character", "siap");
    return 1;
}

stock Character_GetId(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    return gCharacterId[playerid];
}

stock Character_GetFullName(playerid, dest[], maxlength = sizeof (dest)) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return format(dest, maxlength, "%s", gFullName[playerid]);
}

stock Character_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gCharacterId[playerid] = -1;
    gFullName[playerid][0] = '\0';
    gSkinModel[playerid] = DEFAULT_SKIN_MALE;
    gPendingFirst[playerid][0] = '\0';
    gPendingLast[playerid][0] = '\0';
    Money_Reset(playerid);
    return 1;
}

// --- pemilihan karakter -----------------------------------------------------
stock Character_ShowSelector(playerid) {
    if (!Auth_IsLoggedIn(playerid)) return 0;

    new accountId = Auth_AccountId(playerid);
    new slotCount = Character_CountSlots(accountId);

    if (slotCount == 0) {
        Welcome_SetHint(playerid, "LENGKAPI DATA KARAKTER");
        UIModal_Open(playerid, UI_CHARCREATE);
        CharCreate_Open(playerid);
        return 1;
    }

    new names[MAX_CHAR_SLOTS][MAX_USERNAME_LENGTH + 1];
    new hours[MAX_CHAR_SLOTS][16];
    new bool:slotAlive[MAX_CHAR_SLOTS];

    for (new slot = 0; slot < MAX_CHAR_SLOTS; slot++) {
        slotAlive[slot] = Character_SlotExists(accountId, slot);
        if (slotAlive[slot]) {
            Character_SlotName(accountId, slot, names[slot], sizeof (names[]));
            Character_SlotHours(accountId, slot, hours[slot], sizeof (hours[]));
        }
    }

    CharSelect_Show(playerid, names, hours, slotAlive, slotCount < MAX_CHAR_SLOTS);
    UIModal_Open(playerid, UI_CHARSELECT);
    Welcome_SetHint(playerid, "PILIH KARAKTER KAMU");
    return 1;
}

// Handler klik kursor textdraw (dipanggil dari callbacks.pwn).
stock bool:Character_OnClickTextDraw(playerid, PlayerText:clicked) {
    if (!CharSelect_IsOpen(playerid)) return false;

    new slot = CharSelect_RowSlot(playerid, clicked);
    if (slot >= 0) {
        new accountId = Auth_AccountId(playerid);
        if (!Character_SlotExists(accountId, slot)) {
            Messages_SendError(playerid, MSG_INTERNAL_ERROR);
            return true;
        }
        new query[192];
        format(query, sizeof (query),
            "SELECT character_id FROM characters WHERE account_id = %d AND slot_index = %d",
            accountId, slot);
        new characterId = DB_Int(query, -1);
        if (characterId < 1) {
            Messages_SendError(playerid, MSG_INTERNAL_ERROR);
            return true;
        }
        UIModal_Close(playerid);
        Character_Load(playerid, characterId);
        return true;
    }

    if (CharSelect_IsCreate(playerid, clicked)) {
        if (Character_CountSlots(Auth_AccountId(playerid)) >= MAX_CHAR_SLOTS) {
            new body[128];
            format(body, sizeof (body), MSG_CHAR_LIMIT, MAX_CHAR_SLOTS, MAX_CHAR_SLOTS);
            Messages_SendError(playerid, body);
            CharSelect_Hide(playerid);
            Character_ShowSelector(playerid);
            return true;
        }
        UIModal_Open(playerid, UI_CHARCREATE);
        Welcome_SetHint(playerid, "LENGKAPI DATA KARAKTER");
        CharCreate_Open(playerid);
        return true;
    }
    return false;
}

// ESC saat kursor aktif: tampilkan ulang menu, jangan tendang pemain.
stock bool:Character_OnCancelSelect(playerid) {
    if (!CharSelect_IsOpen(playerid)) return false;
    Character_ShowSelector(playerid);
    return true;
}

stock Character_CountSlots(accountId) {
    new query[160];
    format(query, sizeof (query),
        "SELECT COUNT(*) FROM characters WHERE account_id = %d AND deleted_at IS NULL", accountId);
    return DB_Int(query, 0);
}

stock bool:Character_SlotExists(accountId, slot) {
    new query[192];
    format(query, sizeof (query),
        "SELECT COUNT(*) FROM characters WHERE account_id = %d AND slot_index = %d AND deleted_at IS NULL",
        accountId, slot);
    return DB_Int(query, 0) > 0;
}

static Character_SlotName(accountId, slot, dest[], maxlength) {
    new query[224];
    format(query, sizeof (query),
        "SELECT first_name || ' ' || last_name FROM characters WHERE account_id = %d AND slot_index = %d",
        accountId, slot);
    if (!DB_String(query, dest, maxlength)) {
        format(dest, maxlength, "(kosong)");
    }
    return 1;
}

static Character_SlotHours(accountId, slot, dest[], maxlength) {
    new query[224];
    format(query, sizeof (query),
        "SELECT hours_played FROM characters WHERE account_id = %d AND slot_index = %d",
        accountId, slot);
    new hours = DB_Int(query, 0);
    return format(dest, maxlength, "%d", hours);
}

// --- pembuatan karakter -----------------------------------------------------
stock bool:Character_OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    #pragma unused listitem
    #pragma unused response
    switch (dialogid) {
        case DIALOG_CHAR_CREATE_FIRST: {
            if (!response) {
                CharCreate_Show(playerid);
                return true;
            }
            if (!Validate_NamePart(inputtext)) {
                Messages_SendError(playerid, "Nama depan tidak valid (huruf, 2-24 karakter).");
                Character_AskFirstName(playerid);
                return true;
            }
            format(gPendingFirst[playerid], MAX_USERNAME_LENGTH + 1, "%s", inputtext);
            CharCreate_SetFirstName(playerid, inputtext);
            CharCreate_Show(playerid);
            return true;
        }

        case DIALOG_CHAR_CREATE_LAST: {
            if (!response) {
                CharCreate_Show(playerid);
                return true;
            }
            if (!Validate_NamePart(inputtext)) {
                Messages_SendError(playerid, "Nama belakang tidak valid (huruf, 2-24 karakter).");
                Character_AskLastName(playerid);
                return true;
            }
            format(gPendingLast[playerid], MAX_USERNAME_LENGTH + 1, "%s", inputtext);
            CharCreate_SetLastName(playerid, inputtext);
            CharCreate_Show(playerid);
            return true;
        }
    }
    return false;
}

// --- load & spawn -----------------------------------------------------------
stock bool:Character_Load(playerid, characterId) {
    Phase_Set(playerid, PHASE_LOADING);

    new query[192];
    format(query, sizeof (query),
        "SELECT first_name || ' ' || last_name FROM characters WHERE character_id = %d", characterId);
    if (!DB_String(query, gFullName[playerid], sizeof (gFullName[]))) {
        Messages_SendError(playerid, MSG_INTERNAL_ERROR);
        Phase_Set(playerid, PHASE_CHAR_SELECT);
        Character_ShowSelector(playerid);
        return false;
    }

    if (!Money_Load(playerid, characterId)) {
        Messages_SendError(playerid, MSG_INTERNAL_ERROR);
        Phase_Set(playerid, PHASE_CHAR_SELECT);
        Character_ShowSelector(playerid);
        return false;
    }

    format(query, sizeof (query),
        "SELECT skin_model FROM characters WHERE character_id = %d", characterId);
    new skin = DB_Int(query, -1);
    gSkinModel[playerid] = (skin >= 0 && skin <= 311) ? skin : DEFAULT_SKIN_MALE;

    gCharacterId[playerid] = characterId;
    new message[160];
    format(message, sizeof (message), "Kamu bermain sebagai %s.", gFullName[playerid]);
    Messages_SendSystem(playerid, message);

    Character_Spawn(playerid);
    return true;
}

stock Character_Spawn(playerid) {
    Phase_Set(playerid, PHASE_SPAWNING);

    // Keluar dari mode spectate yang dipasang saat connect, kalau tidak
    // SpawnPlayer tidak akan menampilkan karakter.
    TogglePlayerSpectating(playerid, false);

    SetSpawnInfo(playerid, NO_TEAM, gSkinModel[playerid], SPAWN_POS_X, SPAWN_POS_Y,
        SPAWN_POS_Z, SPAWN_POS_ANGLE, WEAPON_FIST, 0, WEAPON_FIST, 0, WEAPON_FIST, 0);
    SpawnPlayer(playerid);
    SetPlayerInterior(playerid, 0);
    return 1;
}

stock bool:Character_Save(playerid) {
    if (Character_GetId(playerid) < 1) return false;

    if (!Money_Save(playerid)) {
        Log_Error("character", "gagal simpan saldo saat keluar");
        return false;
    }

    new query[128];
    format(query, sizeof (query),
        "UPDATE characters SET hours_played = hours_played + 1 WHERE character_id = %d",
        Character_GetId(playerid));
    DB_Exec(query);
    return true;
}