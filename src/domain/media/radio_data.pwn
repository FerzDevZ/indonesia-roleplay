// ---------------------------------------------------------------------------
// module      : domain/media/radio_data
// entry       : Radio_Boot()
// depends     : core/db, core/log
// owns tables : radio_stations
// public api  : Radio_Boot(), Radio_Reload(), Radio_Count(), Radio_Id(),
//               Radio_Name(), Radio_Genre(), Radio_Url(), Radio_Add(),
//               Radio_Remove()
// Aturan      : daftar stasiun TIDAK boleh hardcode di kode UI. URL stream
//               disimpan di DB supaya admin bisa menukar sumber (AzuraCast
//               sendiri, radio komunitas, atau stasiun berlisensi) tanpa
//               compile ulang. Pakai http:// untuk kompatibilitas klien 0.3.7;
//               https:// didukung klien modern tapi belum tentu di mobile.
// ---------------------------------------------------------------------------
#if defined _INC_RADIO_DATA
    #endinput
#endif
#define _INC_RADIO_DATA

#define RADIO_MAX           (8)
#define RADIO_NAME_LEN      (24)
#define RADIO_GENRE_LEN     (18)
#define RADIO_URL_LEN       (128)

static gRadioCount = 0;
static gRadioId[RADIO_MAX];
static gRadioBitrate[RADIO_MAX];
static gRadioName[RADIO_MAX][RADIO_NAME_LEN];
static gRadioGenre[RADIO_MAX][RADIO_GENRE_LEN];
static gRadioUrl[RADIO_MAX][RADIO_URL_LEN];

stock Radio_Boot() {
    if (!DB_Exec("CREATE TABLE IF NOT EXISTS radio_stations (\
            station_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            name TEXT NOT NULL,\
            genre TEXT NOT NULL DEFAULT '',\
            stream_url TEXT NOT NULL,\
            bitrate INTEGER NOT NULL DEFAULT 128,\
            enabled INTEGER NOT NULL DEFAULT 1,\
            created_at TEXT DEFAULT (datetime('now')))")) {
        Log_Error("radio", "gagal membuat tabel radio_stations");
        return 0;
    }

    // Seed hanya saat tabel kosong: stasiun yang sudah diubah admin tidak
    // pernah ditimpa saat restart. Sumber bawaan = SomaFM (gratis, boleh
    // didengarkan; untuk produksi sebaiknya host sendiri lewat AzuraCast).
    if (DB_Int("SELECT COUNT(*) FROM radio_stations", 0) == 0) {
        DB_Exec("INSERT INTO radio_stations (name, genre, stream_url, bitrate) \
                 VALUES ('Groove Salad', 'Chillout', \
                 'http://ice1.somafm.com/groovesalad-128-mp3', 128)");
        DB_Exec("INSERT INTO radio_stations (name, genre, stream_url, bitrate) \
                 VALUES ('Lush', 'Vokal', \
                 'http://ice1.somafm.com/lush-128-mp3', 128)");
        DB_Exec("INSERT INTO radio_stations (name, genre, stream_url, bitrate) \
                 VALUES ('Secret Agent', 'Lounge', \
                 'http://ice1.somafm.com/secretagent-128-mp3', 128)");
        DB_Exec("INSERT INTO radio_stations (name, genre, stream_url, bitrate) \
                 VALUES ('Deep Space One', 'Ambient', \
                 'http://ice1.somafm.com/deepspaceone-128-mp3', 128)");
    }

    Radio_Reload();
    return 1;
}

stock Radio_Reload() {
    new total = DB_Int("SELECT COUNT(*) FROM radio_stations WHERE enabled = 1", 0);
    if (total > RADIO_MAX) total = RADIO_MAX;

    gRadioCount = 0;
    for (new row = 0; row < total; row++) {
        new query[256];
        format(query, sizeof (query),
            "SELECT station_id, name, genre, stream_url, bitrate FROM radio_stations \
             WHERE enabled = 1 ORDER BY station_id LIMIT 1 OFFSET %d", row);
        new stationId = DB_IntAt(query, 0, 0, 0);
        if (stationId <= 0) continue;

        gRadioId[gRadioCount] = stationId;
        DB_StrAt(query, 0, 1, gRadioName[gRadioCount], RADIO_NAME_LEN);
        DB_StrAt(query, 0, 2, gRadioGenre[gRadioCount], RADIO_GENRE_LEN);
        DB_StrAt(query, 0, 3, gRadioUrl[gRadioCount], RADIO_URL_LEN);
        gRadioBitrate[gRadioCount] = DB_IntAt(query, 0, 4, 128);
        if (gRadioUrl[gRadioCount][0] == EOS) continue;
        gRadioCount++;
    }

    new report[64];
    format(report, sizeof (report), "stasiun radio dimuat: %d", gRadioCount);
    Log_Info("radio", report);
    return gRadioCount;
}

stock Radio_Count() {
    return gRadioCount;
}

stock Radio_Id(index) {
    if (index < 0 || index >= gRadioCount) return 0;
    return gRadioId[index];
}

stock Radio_Name(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gRadioCount) return format(dest, maxlength, "-");
    return format(dest, maxlength, "%s", gRadioName[index]);
}

stock Radio_Genre(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gRadioCount) return format(dest, maxlength, "-");
    return format(dest, maxlength, "%s", gRadioGenre[index]);
}

stock Radio_Url(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gRadioCount) return format(dest, maxlength, "");
    return format(dest, maxlength, "%s", gRadioUrl[index]);
}

stock Radio_Bitrate(index) {
    if (index < 0 || index >= gRadioCount) return 0;
    return gRadioBitrate[index];
}

stock bool:Radio_Add(const name[], const genre[], const url[], bitrate) {
    if (name[0] == EOS || url[0] == EOS) return false;
    if (bitrate < 32 || bitrate > 320) return false;
    if (strfind(url, "http", true) != 0) return false;
    if (gRadioCount >= RADIO_MAX) return false;

    new escapedName[RADIO_NAME_LEN * 2 + 1];
    new escapedGenre[RADIO_GENRE_LEN * 2 + 1];
    new escapedUrl[RADIO_URL_LEN * 2 + 1];
    DB_Escape(escapedName, sizeof (escapedName), name);
    DB_Escape(escapedGenre, sizeof (escapedGenre), genre);
    DB_Escape(escapedUrl, sizeof (escapedUrl), url);

    new query[512];
    format(query, sizeof (query),
        "INSERT INTO radio_stations (name, genre, stream_url, bitrate) \
         VALUES ('%s', '%s', '%s', %d)",
        escapedName, escapedGenre, escapedUrl, bitrate);
    if (!DB_Exec(query)) return false;

    Radio_Reload();
    return true;
}

// Nonaktifkan stasiun (baris tetap ada supaya riwayat tidak hilang).
stock bool:Radio_Remove(index) {
    new stationId = Radio_Id(index);
    if (stationId <= 0) return false;

    new query[128];
    format(query, sizeof (query),
        "UPDATE radio_stations SET enabled = 0 WHERE station_id = %d", stationId);
    if (!DB_Exec(query)) return false;

    Radio_Reload();
    return true;
}
