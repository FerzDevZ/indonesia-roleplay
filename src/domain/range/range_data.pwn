// ---------------------------------------------------------------------------
// module      : domain/range/range_data
// entry       : RangeData_Boot()
// depends     : core/db, core/log
// owns tables : range_scores
// public api  : RangeData_Boot(), RangeData_Best(), RangeData_Sessions(),
//               RangeData_Save(), RangeData_Top()
// Isi         : rekor latihan tembak per karakter. Skor disimpan server-side
//               dan hanya ditulis saat sesi berakhir, bukan per tembakan.
// Aturan      : satu baris per karakter (PRIMARY KEY character_id). Rekor baru
//               hanya menimpa bila lebih tinggi, sehingga tidak ada penurunan
//               skor gara-gara sesi buruk atau percobaan curang yang gagal.
// ---------------------------------------------------------------------------
#if defined _INC_RANGE_DATA
    #endinput
#endif
#define _INC_RANGE_DATA

#define RANGE_TOP_MAX       (5)

stock RangeData_Boot() {
    if (!DB_Exec("CREATE TABLE IF NOT EXISTS range_scores (\
            character_id INTEGER PRIMARY KEY,\
            best_score INTEGER NOT NULL DEFAULT 0,\
            best_hits INTEGER NOT NULL DEFAULT 0,\
            sessions INTEGER NOT NULL DEFAULT 0,\
            updated_at TEXT DEFAULT (datetime('now')))")) {
        Log_Error("range", "gagal membuat tabel range_scores");
        return 0;
    }
    Log_Info("range", "tabel rekor latihan siap");
    return 1;
}

stock RangeData_Best(characterId) {
    if (characterId <= 0) return 0;
    new query[128];
    format(query, sizeof (query),
        "SELECT best_score FROM range_scores WHERE character_id = %d", characterId);
    return DB_Int(query, 0);
}

stock RangeData_Sessions(characterId) {
    if (characterId <= 0) return 0;
    new query[128];
    format(query, sizeof (query),
        "SELECT sessions FROM range_scores WHERE character_id = %d", characterId);
    return DB_Int(query, 0);
}

// Simpan hasil sesi: rekor hanya naik, jumlah sesi selalu bertambah.
stock RangeData_Save(characterId, score, hits) {
    if (characterId <= 0) return 0;

    new query[320];
    format(query, sizeof (query),
        "INSERT INTO range_scores (character_id, best_score, best_hits, sessions) \
         VALUES (%d, %d, %d, 1) \
         ON CONFLICT(character_id) DO UPDATE SET \
             sessions = sessions + 1, \
             best_score = MAX(best_score, excluded.best_score), \
             best_hits = MAX(best_hits, excluded.best_hits), \
             updated_at = datetime('now')",
        characterId, score, hits);
    if (!DB_Exec(query)) return 0;
    return 1;
}

// Tulis daftar rekor teratas ke buffer dialog (satu baris per peringkat).
stock RangeData_Top(dest[], maxlength = sizeof (dest)) {
    dest[0] = EOS;
    new query[256];
    format(query, sizeof (query),
        "SELECT c.name, r.best_score, r.best_hits, r.sessions \
         FROM range_scores r JOIN characters c ON c.character_id = r.character_id \
         WHERE r.best_score > 0 ORDER BY r.best_score DESC LIMIT %d", RANGE_TOP_MAX);
    new rows = DB_Rows(query);
    if (rows <= 0) return format(dest, maxlength, "Belum ada yang mencetak skor.");

    for (new row = 0; row < rows; row++) {
        new name[MAX_PLAYER_NAME + 1], line[96];
        DB_StrAt(query, row, 0, name, sizeof (name));
        format(line, sizeof (line), "%d. %s - %d poin (%d hit, %d sesi)\n",
            row + 1, name, DB_IntAt(query, row, 1, 0), DB_IntAt(query, row, 2, 0),
            DB_IntAt(query, row, 3, 1));
        strcat(dest, line, maxlength);
    }
    return 1;
}
