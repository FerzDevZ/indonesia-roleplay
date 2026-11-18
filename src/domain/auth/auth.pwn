// ---------------------------------------------------------------------------
// module      : domain/auth
// entry       : Auth_Boot()
// depends     : core/db, core/log, core/timer, shared/player_phase, shared/messages
// owns tables : accounts
// public api  : Auth_Boot(), Auth_OnConnect(), Auth_OnDialogResponse(),
//               Auth_OnDisconnect(), Auth_IsLoggedIn(), Auth_AccountId(),
//               Auth_AdminLevel(), Auth_Username()
// Catatan     : hash = SHA256(password + salt) dari native server, bukan di
//               client. Upgrade ke bcrypt dicatat di docs/07 fase 8.
// ---------------------------------------------------------------------------
#if defined _INC_AUTH
    #endinput
#endif
#define _INC_AUTH

static gUsername[MAX_PLAYERS][MAX_USERNAME_LENGTH + 1];
static gAccountId[MAX_PLAYERS] = { -1, ... };
static gAdminLevel[MAX_PLAYERS];
static gFailedAttempts[MAX_PLAYERS];
static gLockedUntil[MAX_PLAYERS];

stock Auth_Boot() {
    Log_Info("auth", "siap");
    return 1;
}

stock Auth_ResetState(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gAccountId[playerid] = -1;
    gAdminLevel[playerid] = 0;
    gFailedAttempts[playerid] = 0;
    gLockedUntil[playerid] = 0;
    gUsername[playerid][0] = '\0';
    return 1;
}

stock Auth_OnConnect(playerid) {
    Auth_ResetState(playerid);
    ClientTier_Reset(playerid);
    Phase_Set(playerid, PHASE_AUTHENTICATING);

    // Tahan pemain di mode spectate selama login/pilih karakter. Tanpa ini client
    // masuk ke layar pemilihan class dengan kamera default dan dialog bisa tidak
    // tampil rapi.
    TogglePlayerSpectating(playerid, true);
    Welcome_Show(playerid);

    GetPlayerName(playerid, gUsername[playerid], MAX_USERNAME_LENGTH + 1);

    // Client 0.3.7 tidak akan pernah mengirim OnPlayerFinishedDownloading.
    Timer_OnceForPlayer("Timer_OnClientTierProbe", playerid, TIER_DETECT_SECONDS * 1000);

    if (!Validate_Username(gUsername[playerid])) {
        // Nama client tidak bisa diubah dari server, jadi tidak ada jalan lain
        // selain mengeluarkan pemain dengan penjelasan.
        SendClientMessage(playerid, COLOR_ERROR,
            "Nama kamu tidak didukung. Pakai huruf/angka/garis bawah, 3-24 karakter.");
        Kick(playerid);
        return 0;
    }

    if (Auth_UsernameExists(gUsername[playerid])) {
        Auth_ShowLogin(playerid);
        return 1;
    }

    Auth_ShowRegister(playerid);
    return 1;
}

static bool:Auth_UsernameExists(const username[]) {
    new escaped[MAX_USERNAME_LENGTH * 2 + 1];
    DB_Escape(escaped, sizeof (escaped), username);

    new query[160];
    format(query, sizeof (query),
        "SELECT COUNT(*) FROM accounts WHERE username = '%s'", escaped);
    new found = DB_Int(query, -1);

    // -1 berarti query gagal (beda dengan 0 = akun memang tidak ada); itu kondisi
    // error yang wajib terlihat di log, bukan dibiarkan senyap.
    if (found == -1) {
        new detail[96];
        format(detail, sizeof (detail), "cek akun %s gagal (query error)", username);
        Log_Error("auth", detail);
    }
    return found > 0;
}

static Auth_ShowLogin(playerid) {
    new body[192];
    format(body, sizeof (body),
        "Masukkan password untuk akun %s.\r\n\r\nPercobaan gagal: %d dari %d.",
        gUsername[playerid], gFailedAttempts[playerid], MAX_LOGIN_ATTEMPTS);

    ShowPlayerDialog(playerid, DIALOG_LOGIN, DIALOG_STYLE_PASSWORD,
        "Login", body, "Masuk", "Keluar");
    return 1;
}

static Auth_ShowRegister(playerid) {
    new body[224];
    format(body, sizeof (body),
        "Akun %s belum terdaftar.\r\n\r\nBuat password (minimal %d karakter).\r\n\
Password tidak boleh sama dengan nama akun.",
        gUsername[playerid], MIN_PASSWORD_LENGTH);

    ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD,
        "Daftar", body, "Daftar", "Keluar");
    return 1;
}

stock bool:Auth_OnDialogResponse(playerid, dialogid, response, const inputtext[]) {
    if (dialogid == DIALOG_REGISTER) {
        return Auth_HandleRegister(playerid, response, inputtext);
    }
    if (dialogid == DIALOG_LOGIN) {
        return Auth_HandleLogin(playerid, response, inputtext);
    }
    return false;
}

static bool:Auth_HandleRegister(playerid, response, const inputtext[]) {
    if (!response) {
        Kick(playerid);
        return true;
    }

    if (!Validate_Password(inputtext)) {
        new body[160];
        format(body, sizeof (body),
            "Password minimal %d karakter. Coba lagi.", MIN_PASSWORD_LENGTH);
        ShowPlayerDialog(playerid, DIALOG_REGISTER, DIALOG_STYLE_PASSWORD,
            "Daftar", body, "Daftar", "Keluar");
        return true;
    }

    if (!strcmp(inputtext, gUsername[playerid], true)) {
        Messages_SendError(playerid, "Password tidak boleh sama dengan username.");
        Auth_ShowRegister(playerid);
        return true;
    }

    new salt[24], hash[65];
    format(salt, sizeof (salt), "%d%d", random(900000) + 100000, random(900000) + 100000);
    SHA256_Hash(inputtext, salt, hash, sizeof (hash));

    new escapedUser[MAX_USERNAME_LENGTH * 2 + 1];
    DB_Escape(escapedUser, sizeof (escapedUser), gUsername[playerid]);

    new safeIp[64];
    Auth_FillSafeIp(playerid, safeIp, sizeof (safeIp));

    new query[320];
    format(query, sizeof (query),
        "INSERT INTO accounts (username, password_hash, salt, last_ip) VALUES ('%s', '%s', '%s', '%s')",
        escapedUser, hash, salt, safeIp);

    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return true;
    }

    Auth_LogAction("REGISTER", gUsername[playerid], 0);
    Messages_SendSystem(playerid, MSG_REGISTER_OK);
    Auth_ShowLogin(playerid);
    return true;
}

static bool:Auth_HandleLogin(playerid, response, const inputtext[]) {
    if (!response) {
        Kick(playerid);
        return true;
    }

    if (!Phase_CanAuthenticate(playerid)) {
        return true;
    }

    new now = GetTickCount();
    if (gLockedUntil[playerid] > now) {
        new body[160];
        format(body, sizeof (body), MSG_LOGIN_LOCKED, (gLockedUntil[playerid] - now) / 1000);
        Messages_SendError(playerid, body);
        Kick(playerid);
        return true;
    }

    new escapedUser[MAX_USERNAME_LENGTH * 2 + 1];
    DB_Escape(escapedUser, sizeof (escapedUser), gUsername[playerid]);

    new query[192];
    format(query, sizeof (query),
        "SELECT salt FROM accounts WHERE username = '%s'", escapedUser);
    new salt[24];
    if (!DB_String(query, salt, sizeof (salt))) {
        Messages_SendError(playerid, MSG_INTERNAL_ERROR);
        return true;
    }

    new hash[65];
    SHA256_Hash(inputtext, salt, hash, sizeof (hash));

    format(query, sizeof (query),
        "SELECT account_id FROM accounts WHERE username = '%s' AND password_hash = '%s' AND is_banned = 0",
        escapedUser, hash);

    new accountId = DB_Int(query, -1);
    if (accountId < 1) {
        gFailedAttempts[playerid]++;
        Auth_LogAction("LOGIN_FAIL", gUsername[playerid], gFailedAttempts[playerid]);

        if (gFailedAttempts[playerid] >= MAX_LOGIN_ATTEMPTS) {
            gLockedUntil[playerid] = GetTickCount() + (LOGIN_LOCK_SECONDS * 1000);
            new body[128];
            format(body, sizeof (body), MSG_LOGIN_LOCKED, LOGIN_LOCK_SECONDS);
            Messages_SendError(playerid, body);
            Kick(playerid);
            return true;
        }

        new body[128];
        format(body, sizeof (body), MSG_LOGIN_FAILED, gFailedAttempts[playerid], MAX_LOGIN_ATTEMPTS);
        Messages_SendError(playerid, body);
        Auth_ShowLogin(playerid);
        return true;
    }

    gAccountId[playerid] = accountId;
    gFailedAttempts[playerid] = 0;

    format(query, sizeof (query),
        "SELECT admin_level FROM accounts WHERE account_id = %d", accountId);
    gAdminLevel[playerid] = DB_Int(query, 0);

    new safeIp[64];
    Auth_FillSafeIp(playerid, safeIp, sizeof (safeIp));

    format(query, sizeof (query),
        "UPDATE accounts SET last_login_at = datetime('now'), last_ip = '%s' WHERE account_id = %d",
        safeIp, accountId);
    DB_Exec(query);

    Auth_LogAction("LOGIN_OK", gUsername[playerid], accountId);
    Messages_SendSystem(playerid, MSG_LOGIN_OK);

    Phase_Set(playerid, PHASE_CHAR_SELECT);
    Character_ShowSelector(playerid);
    return true;
}

// IP hanya berisi digit dan titik; tetap di-escape sebelum masuk query.
static Auth_FillSafeIp(playerid, dest[], maxlength) {
    new ip[32];
    GetPlayerIp(playerid, ip, sizeof (ip));
    return DB_Escape(dest, maxlength, ip);
}

static Auth_LogAction(const action[], const username[], value) {
    new detail[96];
    format(detail, sizeof (detail), "%s nilai=%d", username, value);
    Log_Module("auth", action);
    Log_Debug("auth", detail);
    return 1;
}

stock bool:Auth_IsLoggedIn(playerid) {
    return playerid >= 0 && playerid < MAX_PLAYERS && gAccountId[playerid] > 0;
}

stock Auth_AccountId(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    return gAccountId[playerid];
}

stock Auth_AdminLevel(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return gAdminLevel[playerid];
}

// Baca ulang level admin dari DB (dipakai setelah /superadmin atau promosi).
stock Auth_ReloadAdmin(playerid) {
    if (!Auth_IsLoggedIn(playerid)) return 0;

    new query[128];
    format(query, sizeof (query),
        "SELECT admin_level FROM accounts WHERE account_id = %d", gAccountId[playerid]);
    gAdminLevel[playerid] = DB_Int(query, 0);
    return gAdminLevel[playerid];
}

stock Auth_Username(playerid, dest[], maxlength = sizeof (dest)) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return format(dest, maxlength, "%s", gUsername[playerid]);
}
