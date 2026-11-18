// ---------------------------------------------------------------------------
// module      : domain/admin
// entry       : Admin_Boot()
// depends     : core/db, core/log, shared/money, shared/messages
// owns tables : admin_audit
// public api  : Admin_Boot(), Admin_HandleCommand(), Admin_OnDialogResponse()
// Aturan      : setiap tindakan admin menulis admin_audit. Tidak ada pengecualian.
// ---------------------------------------------------------------------------
#if defined _INC_ADMIN
    #endinput
#endif
#define _INC_ADMIN

stock Admin_Boot() {
    Log_Info("admin", "siap");
    return 1;
}

stock bool:Admin_HandleCommand(playerid, const command[], const params[]) {
    if (!strcmp(command, "admin", true))      return Admin_ShowMenu(playerid);
    if (!strcmp(command, "asay", true))       return Admin_Broadcast(playerid, params);
    if (!strcmp(command, "ainfo", true))      return Admin_PlayerInfo(playerid, params);
    if (!strcmp(command, "agive", true))      return Admin_GiveMoney(playerid, params);
    if (!strcmp(command, "beriitem", true))   return Admin_GiveItem(playerid, params);
    if (!strcmp(command, "superadmin", true)) return Admin_SuperLogin(playerid, params);
    if (!strcmp(command, "buatatm", true))    return Admin_CreateAtm(playerid, params);
    return false;
}

// /buatatm [nama] - pasang ATM fisik (mesin + pickup + ikon radar + label)
// di posisi admin. Lokasi & wujud dunia dibuat runtime oleh Locations_Add.
static bool:Admin_CreateAtm(playerid, const params[]) {
    if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;

    new name[LOC_NAME_LEN];
    if (params[0] == '\0') {
        format(name, sizeof (name), "ATM");
    } else {
        format(name, sizeof (name), "ATM %s", params);
    }

    new code[LOC_CODE_LEN];
    format(code, sizeof (code), "ATM_%d", gettime() % 100000);
    new Float:posX, Float:posY, Float:posZ;
    GetPlayerPos(playerid, posX, posY, posZ);
    new locIndex = Locations_Add(code, name, LOC_ACT_ATM,
        posX, posY, posZ, 3.0);
    if (locIndex < 0) {
        Messages_SendError(playerid, "ATM gagal dipasang (daftar penuh).");
        return true;
    }

    new message[96];
    format(message, sizeof (message), "ATM '%s' dipasang di posisimu.", name);
    Messages_SendSystem(playerid, message);
    Admin_Audit(playerid, "ATM_CREATE", -1, code);
    return true;
}

// Pemulihan owner: /superadmin <kunci> (kunci dari settings.ini). Tiga kali
// salah per sesi = dikunci sampai reconnect. Berhasil = akun naik level 5.
#define SUPERADMIN_MAX_ATTEMPTS (3)
static gSuperAttempts[MAX_PLAYERS];

static bool:Admin_SuperLogin(playerid, const params[]) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return true;
    if (!Auth_IsLoggedIn(playerid)) {
        Messages_SendError(playerid, MSG_NOT_LOGGED_IN);
        return true;
    }

    new key[33];
    if (!Settings_SuperAdminKey(key, sizeof (key))) {
        Messages_SendError(playerid, "Perintah ini tidak aktif di server ini.");
        return true;
    }
    if (params[0] == '\0') {
        Messages_SendError(playerid, "Pakai: /superadmin <kunci>");
        return true;
    }
    if (gSuperAttempts[playerid] >= SUPERADMIN_MAX_ATTEMPTS) {
        Messages_SendError(playerid, "Terlalu banyak percobaan. Sambung ulang dulu.");
        Admin_Audit(playerid, "SUPERADMIN_LOCKED", -1, "");
        return true;
    }

    if (strcmp(params, key, false) != 0) {
        gSuperAttempts[playerid]++;
        new body[96];
        format(body, sizeof (body), "Kunci salah. Sisa percobaan: %d.",
            SUPERADMIN_MAX_ATTEMPTS - gSuperAttempts[playerid]);
        Messages_SendError(playerid, body);
        Admin_Audit(playerid, "SUPERADMIN_FAIL", -1, "");
        return true;
    }

    new query[128];
    format(query, sizeof (query),
        "UPDATE accounts SET admin_level = %d WHERE account_id = %d",
        ADMIN_OWNER, Auth_AccountId(playerid));
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return true;
    }
    Auth_ReloadAdmin(playerid);

    gSuperAttempts[playerid] = 0;
    Messages_SendSystem(playerid, "Kunci diterima. Kamu sekarang OWNER (level 5).");
    Admin_Audit(playerid, "SUPERADMIN_LOGIN", -1, "naik ke level 5");
    return true;
}

// /beriitem <kode> [jumlah] - beri barang tas ke diri sendiri (uji C2).
static bool:Admin_GiveItem(playerid, const params[]) {
    if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;

    new code[16], rest[64], qtyText[16], tail[32];
    if (!Command_NextToken(params, code, sizeof (code), rest, sizeof (rest))) {
        Messages_SendError(playerid, "Pakai: /beriitem <kode> [jumlah]");
        return true;
    }
    new qty = 1;
    if (Command_NextToken(rest, qtyText, sizeof (qtyText), tail, sizeof (tail))) {
        qty = strval(qtyText);
    }
    if (qty < 1 || qty > 99) {
        Messages_SendError(playerid, "Jumlah 1-99.");
        return true;
    }
    new item = Inv_ItemFromCode(code);
    if (item < 0) {
        Messages_SendError(playerid,
            "Kode tidak dikenal. Kode: PAKET, MAKANAN, MINUMAN, OBAT.");
        return true;
    }
    if (!Inv_Give(playerid, item, qty)) return true;

    new itemName[20], body[96];
    Inv_ItemName(item, itemName, sizeof (itemName));
    format(body, sizeof (body), "%s x%d masuk tas kamu.", itemName, qty);
    Messages_SendSystem(playerid, body);
    Admin_Audit(playerid, "BERIITEM", -1, code);
    return true;
}

static bool:Admin_ShowMenu(playerid) {
    if (!Admin_Require(playerid, ADMIN_HELPER)) return true;

    new uptime[128], body[320];
    Telemetry_Report(uptime, sizeof (uptime));
    format(body, sizeof (body),
        "Status server:\r\n%s\r\n\r\nLevel admin kamu: %d\r\n\r\nPerintah:\r\n\
/asay [teks]  - pengumuman admin\r\n\
/ainfo [id]   - detail pemain\r\n\
/agive [id] [jumlah] - tambah uang (level 3+)",
        uptime, Auth_AdminLevel(playerid));

    ShowPlayerDialog(playerid, _:DIALOG_ADMIN_MENU, DIALOG_STYLE_MSGBOX,
        "Admin", body, "Tutup", "");
    return true;
}

stock bool:Admin_OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    #pragma unused playerid
    #pragma unused response
    #pragma unused listitem
    #pragma unused inputtext

    if (dialogid != DIALOG_ADMIN_MENU) return false;
    // Menu ini hanya informasi; tidak ada aksi yang bisa dieksekusi dari dialog.
    return true;
}

static bool:Admin_Broadcast(playerid, const params[]) {
    if (!Admin_Require(playerid, ADMIN_HELPER)) return true;
    if (Text_IsEmpty(params)) {
        Messages_SendError(playerid, "Gunakan: /asay [teks]");
        return true;
    }

    new name[32], line[192];
    Admin_Name(playerid, name, sizeof (name));
    format(line, sizeof (line), "[ADMIN] %s: %s", name, params);
    Messages_SendAll(line);
    Admin_Audit(playerid, "BROADCAST", -1, params);
    return true;
}

static bool:Admin_PlayerInfo(playerid, const params[]) {
    if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;

    new token[16], rest[64];
    if (!Command_NextToken(params, token, sizeof (token), rest, sizeof (rest))) {
        Messages_SendError(playerid, "Gunakan: /ainfo [id]");
        return true;
    }

    new targetid = strval(token);
    if (!Validate_PlayerId(targetid)) {
        Messages_SendError(playerid, "Pemain tidak ditemukan.");
        return true;
    }

    new phaseName[24], tierName[16], balance[96], name[32], row[192];
    Phase_Name(targetid, phaseName, sizeof (phaseName));
    ClientTier_Name(targetid, tierName, sizeof (tierName));
    Money_Describe(targetid, balance, sizeof (balance));
    GetPlayerName(targetid, name, sizeof (name));

    format(row, sizeof (row), "%s id=%d fase=%s client=%s", name, targetid, phaseName, tierName);
    Messages_SendSystem(playerid, row);
    Messages_SendSystem(playerid, balance);
    Admin_Audit(playerid, "PLAYER_INFO", Character_GetId(targetid), "");
    return true;
}

static bool:Admin_GiveMoney(playerid, const params[]) {
    if (!Admin_Require(playerid, ADMIN_ADMIN)) return true;

    new token[16], rest[64], amountToken[16], tail[32];
    if (!Command_NextToken(params, token, sizeof (token), rest, sizeof (rest))) {
        Messages_SendError(playerid, "Gunakan: /agive [id] [jumlah]");
        return true;
    }
    if (!Command_NextToken(rest, amountToken, sizeof (amountToken), tail, sizeof (tail))) {
        Messages_SendError(playerid, "Gunakan: /agive [id] [jumlah]");
        return true;
    }

    new targetid = strval(token);
    new amount = strval(amountToken);

    if (!Validate_PlayerId(targetid)) {
        Messages_SendError(playerid, "Pemain tidak ditemukan.");
        return true;
    }
    if (amount < 1 || amount > 1000000) {
        Messages_SendError(playerid, "Jumlah harus 1 - 1.000.000.");
        return true;
    }

    new actorCharacter = Character_GetId(playerid);
    if (!Money_Add(targetid, amount, MONEY_REASON_ADMIN, actorCharacter)) {
        Messages_SendError(playerid, "Gagal menambah uang (karakter target belum siap).");
        return true;
    }

    new detail[96];
    format(detail, sizeof (detail), "jumlah=%d", amount);
    Admin_Audit(playerid, "GIVE_MONEY", Character_GetId(targetid), detail);

    new message[160], money[32];
    Messages_Money(amount, money, sizeof (money));
    format(message, sizeof (message), "Admin menambahkan %s ke tunai kamu.", money);
    Messages_SendSystem(targetid, message);
    return true;
}

stock bool:Admin_Require(playerid, requiredLevel) {
    if (Auth_AdminLevel(playerid) >= requiredLevel) {
        return true;
    }
    Messages_SendError(playerid, MSG_NO_PERMISSION);
    Admin_Audit(playerid, "DENIED", -1, "");
    return false;
}

static Admin_Name(playerid, dest[], maxlength) {
    new account[32];
    if (Auth_Username(playerid, account, sizeof (account)) && account[0] != '\0') {
        return format(dest, maxlength, "%s", account);
    }
    return GetPlayerName(playerid, dest, maxlength);
}

stock Admin_Audit(playerid, const action[], targetCharacter, const detail[]) {
    new account[32], detailSafe[128];
    Auth_Username(playerid, account, sizeof (account));
    DB_Escape(detailSafe, sizeof (detailSafe), detail);

    new query[320];
    format(query, sizeof (query),
        "INSERT INTO admin_audit (actor_account, actor_name, action, target_character, detail) \
         VALUES (%d, '%s', '%s', %d, '%s')",
        Auth_AccountId(playerid), account, action, targetCharacter, detailSafe);

    if (!DB_Exec(query)) {
        Log_Error("admin", "gagal tulis admin_audit");
        return 0;
    }
    return 1;
}