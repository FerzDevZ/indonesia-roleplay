// ---------------------------------------------------------------------------
// module      : core/settings
// entry       : Settings_Load()
// depends     : core/text
// owns tables : -
// public api  : Settings_Load(), Settings_LogLevel(), Settings_DebugEnabled(),
//               Settings_DbPath()
// ---------------------------------------------------------------------------
#if defined _INC_SETTINGS
    #endinput
#endif
#define _INC_SETTINGS

#define SERVER_VERSION      "0.1.0"
// Semua path di bawah ini relatif terhadap folder scriptfiles/, bukan root
// server: fopen() dan DB_Open() open.mp tidak bisa keluar dari scriptfiles/.
#define SETTINGS_FILE       "settings.ini"
#define SETTINGS_DB_DEFAULT "rp.db"

#define MAX_LOGIN_ATTEMPTS  (3)
#define LOGIN_LOCK_SECONDS  (60)
#define MAX_CHAR_SLOTS      (3)
#define STARTING_CASH       (25000)
#define AUTOSAVE_SECONDS    (120)

static gLogLevel = 2;
static gDebugMode = 0;
static gDbPath[64] = SETTINGS_DB_DEFAULT;
static gSuperAdminKey[33] = "";

stock Settings_Load() {
    new File:handle = fopen(SETTINGS_FILE, io_read);
    if (!handle) {
        print("[settings] settings.ini tidak ada, memakai nilai bawaan");
        return 1;
    }

    new line[160];
    new applied = 0;
    while (fread(handle, line)) {
        applied += Settings_ParseLine(line);
    }
    fclose(handle);

    new report[96];
    format(report, sizeof (report), "dimuat: %d kunci, log_level=%d, debug=%d",
        applied, gLogLevel, gDebugMode);
    Log_Info("settings", report);
    return 1;
}

static Settings_ParseLine(const line[]) {
    new trimmed[160];
    Text_Trim(trimmed, line, sizeof (trimmed));

    if (trimmed[0] == '\0' || trimmed[0] == '#' || trimmed[0] == ';' || trimmed[0] == '[') {
        return 0;
    }

    new key[32], value[96];
    if (!Text_SplitKeyValue(trimmed, key, sizeof (key), value, sizeof (value))) {
        return 0;
    }

    if (!strcmp(key, "log_level", true)) {
        gLogLevel = strval(value);
        return 1;
    }
    if (!strcmp(key, "debug", true)) {
        gDebugMode = strval(value);
        return 1;
    }
    if (!strcmp(key, "db_path", true)) {
        format(gDbPath, sizeof (gDbPath), "%s", value);
        return 1;
    }
    if (!strcmp(key, "super_admin_key", true)) {
        // Kunci pemulihan owner: dipakai /superadmin. Kosong = fitur mati.
        format(gSuperAdminKey, sizeof (gSuperAdminKey), "%s", value);
        return 1;
    }
    return 0;
}

stock Settings_LogLevel() {
    return gLogLevel;
}

stock bool:Settings_DebugEnabled() {
    return gDebugMode != 0;
}

stock Settings_DbPath(dest[], maxlength = sizeof (dest)) {
    return format(dest, maxlength, "%s", gDbPath);
}

// Kunci super admin dari settings.ini. Return false kalau tidak diset
// (fitur /superadmin mati - server tanpa kunci tidak bisa direbut orang).
stock bool:Settings_SuperAdminKey(dest[], maxlength = sizeof (dest)) {
    if (gSuperAdminKey[0] == '\0') return false;
    format(dest, maxlength, "%s", gSuperAdminKey);
    return true;
}
