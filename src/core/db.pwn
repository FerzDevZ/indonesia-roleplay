// ---------------------------------------------------------------------------
// module      : core/db
// entry       : DB_Boot()
// depends     : core/log, core/settings
// owns tables : skema dasar (accounts, characters, money_log, identity_docs,
//               plates, vehicles, admin_audit)
// public api  : DB_Boot(), DB_Exec(), DB_ExecFormat(), DB_Int(), DB_Float(),
//               DB_String(), DB_InsertId(), DB_LastError()
// Catatan     : backend = SQLite bawaan open.mp (komponen Databases).
//               DB_Open() dan fopen() hanya bisa menyentuh scriptfiles/, jadi
//               semua path di modul ini relatif terhadap folder itu.
//               Semua akses database WAJIB lewat modul ini.
// ---------------------------------------------------------------------------
#if defined _INC_DB
    #endinput
#endif
#define _INC_DB

static DB:gDatabase = DB:0;
static gDbReady = 0;
static gLastError[128] = "";

stock DB_Boot() {
    new path[64];
    Settings_DbPath(path, sizeof (path));

    gDatabase = DB_Open(path);
    if (gDatabase == DB:0) {
        Log_Error("db", "DB_Open gagal");
        return 0;
    }

    gDbReady = 1;
    if (!DB_ApplySchema()) {
        Log_Error("db", "skema gagal diterapkan");
        gDbReady = 0;
        return 0;
    }

    Log_Info("db", "sqlite siap");
    return 1;
}

stock bool:DB_IsReady() {
    return gDbReady != 0;
}

stock DB_Exec(const query[]) {
    if (!gDbReady) {
        format(gLastError, sizeof (gLastError), "database belum siap");
        return 0;
    }

    new DBResult:result = DB_ExecuteQuery(gDatabase, query);
    if (result == DBResult:0) {
        // Simpan dan tampilkan SQL yang gagal: tanpa teks query, diagnosa hanya menebak.
        format(gLastError, sizeof (gLastError), "%s", query);
        new detail[128];
        format(detail, sizeof (detail), "gagal: %.110s", query);
        Log_Error("db", detail);
        return 0;
    }
    DB_FreeResultSet(result);
    return 1;
}

// Escape string untuk SQLite: kutip tunggal digandakan. Dipakai bersama
// format() di pemanggil, bukan wrapper variadik (Pawn tidak mendukung forwarding
// argumen variadik tanpa YSI, dan kita tidak menambah dependensi untuk itu).
stock DB_Escape(dest[], maxlength, const source[]) {
    new written = 0;
    for (new index = 0; source[index] != '\0' && written < maxlength - 1; index++) {
        if (source[index] == '\'') {
            dest[written++] = '\'';
            if (written >= maxlength - 1) break;
        }
        dest[written++] = source[index];
    }
    dest[written] = '\0';
    return written;
}

stock DB_Int(const query[], fallback = 0) {
    if (!gDbReady) return fallback;

    new DBResult:result = DB_ExecuteQuery(gDatabase, query);
    if (result == DBResult:0) {
        new detail[128];
        format(detail, sizeof (detail), "gagal baca: %.110s", query);
        Log_Error("db", detail);
        return fallback;
    }

    // Setelah DB_ExecuteQuery, baris pertama SUDAH aktif (pola resmi:
    // do { baca } while (DB_SelectNextRow(...))). Memanggil SelectNextRow lebih dulu
    // membuat hasil satu baris selalu terbaca kosong.
    new value = DB_GetFieldInt(result, 0);
    DB_FreeResultSet(result);
    return value;
}

stock Float:DB_Float(const query[], Float:fallback = 0.0) {
    if (!gDbReady) return fallback;

    new DBResult:result = DB_ExecuteQuery(gDatabase, query);
    if (result == DBResult:0) {
        new detail[128];
        format(detail, sizeof (detail), "gagal baca: %.110s", query);
        Log_Error("db", detail);
        return fallback;
    }

    // Baris pertama sudah aktif; lihat catatan di DB_Int.
    new Float:value = DB_GetFieldFloat(result, 0);
    DB_FreeResultSet(result);
    return value;
}

stock bool:DB_String(const query[], dest[], maxlength = sizeof (dest)) {
    dest[0] = '\0';
    if (!gDbReady) return false;

    new DBResult:result = DB_ExecuteQuery(gDatabase, query);
    if (result == DBResult:0) return false;

    new bool:found = false;
    // Baris pertama sudah aktif; lihat catatan di DB_Int.
    DB_GetFieldString(result, 0, dest, maxlength);
    found = true;
    DB_FreeResultSet(result);
    return found;
}

// --- akses multi-baris (untuk daftar mutasi, lokasi, dsb.) ------------------

stock DB_Rows(const query[]) {
    if (!gDbReady) return 0;

    new DBResult:result = DB_ExecuteQuery(gDatabase, query);
    if (result == DBResult:0) return 0;

    new count = DB_GetRowCount(result);
    DB_FreeResultSet(result);
    return count;
}

// Geser kursor hasil query ke baris ke-`row` (0-based). Baris 0 sudah aktif
// setelah DB_ExecuteQuery (pola resmi open.mp), jadi cukup SelectNextRow sebanyak
// `row` kali.
static bool:DB_SeekRow(DBResult:result, row) {
    for (new step = 0; step < row; step++) {
        if (!DB_SelectNextRow(result)) return false;
    }
    return true;
}

// Baca satu sel INT dari baris ke-`row` (0-based) kolom ke-`col`.
stock DB_IntAt(const query[], row, col, fallback = 0) {
    if (!gDbReady || row < 0) return fallback;

    new DBResult:result = DB_ExecuteQuery(gDatabase, query);
    if (result == DBResult:0) return fallback;
    if (row >= DB_GetRowCount(result) || !DB_SeekRow(result, row)) {
        DB_FreeResultSet(result);
        return fallback;
    }

    new value = DB_GetFieldInt(result, col);
    DB_FreeResultSet(result);
    return value;
}

// Baca satu sel STRING dari baris ke-`row` (0-based) kolom ke-`col`.
stock bool:DB_StrAt(const query[], row, col, dest[], maxlength = sizeof (dest)) {
    if (!gDbReady || row < 0) return false;

    new DBResult:result = DB_ExecuteQuery(gDatabase, query);
    if (result == DBResult:0) return false;
    if (row >= DB_GetRowCount(result) || !DB_SeekRow(result, row)) {
        DB_FreeResultSet(result);
        return false;
    }

    DB_GetFieldString(result, col, dest, maxlength);
    DB_FreeResultSet(result);
    return true;
}

// Baca satu sel FLOAT dari baris ke-`row` (0-based) kolom ke-`col`.
stock Float:DB_FloatAt(const query[], row, col, Float:fallback = 0.0) {
    if (!gDbReady || row < 0) return fallback;

    new DBResult:result = DB_ExecuteQuery(gDatabase, query);
    if (result == DBResult:0) return fallback;
    if (row >= DB_GetRowCount(result) || !DB_SeekRow(result, row)) {
        DB_FreeResultSet(result);
        return fallback;
    }

    new Float:value = DB_GetFieldFloat(result, col);
    DB_FreeResultSet(result);
    return value;
}

stock DB_InsertId() {
    return DB_Int("SELECT last_insert_rowid()");
}

stock DB_LastError(dest[], maxlength = sizeof (dest)) {
    return format(dest, maxlength, "%s", gLastError);
}

// --- skema -----------------------------------------------------------------
// Ditulis sebagai daftar pernyataan tunggal karena SQLite menjalankan satu
// pernyataan per pemanggilan. Versi MySQL ada di data/migrations/0001_init.sql
static DB_ApplySchema() {
    new const schema[][] = {
        "CREATE TABLE IF NOT EXISTS accounts (\
            account_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            username TEXT NOT NULL UNIQUE COLLATE NOCASE,\
            password_hash TEXT NOT NULL,\
            salt TEXT NOT NULL,\
            admin_level INTEGER NOT NULL DEFAULT 0,\
            is_banned INTEGER NOT NULL DEFAULT 0,\
            last_ip TEXT,\
            created_at TEXT NOT NULL DEFAULT (datetime('now')),\
            last_login_at TEXT)",

        "CREATE TABLE IF NOT EXISTS characters (\
            character_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            account_id INTEGER NOT NULL,\
            slot_index INTEGER NOT NULL,\
            first_name TEXT NOT NULL,\
            last_name TEXT NOT NULL,\
            gender TEXT NOT NULL DEFAULT 'male',\
            birth_year INTEGER NOT NULL DEFAULT 2000,\
            skin_model INTEGER NOT NULL DEFAULT 0,\
            cash INTEGER NOT NULL DEFAULT 0,\
            bank_balance INTEGER NOT NULL DEFAULT 0,\
            job_id INTEGER DEFAULT NULL,\
            faction_id INTEGER DEFAULT NULL,\
            faction_rank INTEGER DEFAULT NULL,\
            hours_played INTEGER NOT NULL DEFAULT 0,\
            deleted_at TEXT,\
            created_at TEXT NOT NULL DEFAULT (datetime('now')),\
            UNIQUE(account_id, slot_index))",

        "CREATE TABLE IF NOT EXISTS money_log (\
            money_log_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            character_id INTEGER NOT NULL,\
            delta INTEGER NOT NULL,\
            balance_after INTEGER NOT NULL,\
            wallet TEXT NOT NULL DEFAULT 'cash',\
            reason TEXT NOT NULL,\
            ref_table TEXT,\
            ref_id INTEGER,\
            actor_character_id INTEGER,\
            created_at TEXT NOT NULL DEFAULT (datetime('now')))",

        "CREATE INDEX IF NOT EXISTS idx_money_log_character ON money_log (character_id, created_at)",

        "CREATE TABLE IF NOT EXISTS identity_docs (\
            doc_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            character_id INTEGER NOT NULL,\
            doc_type TEXT NOT NULL,\
            doc_number TEXT NOT NULL,\
            issued_at TEXT NOT NULL,\
            expires_at TEXT,\
            issued_by INTEGER,\
            revoked_at TEXT,\
            revoke_reason TEXT,\
            UNIQUE(doc_type, doc_number))",

        "CREATE TABLE IF NOT EXISTS plates (\
            plate_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            plate_code TEXT NOT NULL UNIQUE,\
            vehicle_id INTEGER,\
            registered_to INTEGER,\
            region_code TEXT NOT NULL,\
            stnk_expires_at TEXT NOT NULL,\
            is_stolen INTEGER NOT NULL DEFAULT 0)",

        "CREATE TABLE IF NOT EXISTS admin_audit (\
            audit_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            actor_account INTEGER NOT NULL,\
            actor_name TEXT NOT NULL,\
            action TEXT NOT NULL,\
            target_character INTEGER,\
            detail TEXT,\
            created_at TEXT NOT NULL DEFAULT (datetime('now')))",

        // Lokasi layanan dinamis: ATM, loket, warung, dsb. Dipakai prompt [Y]
        // dan gerbang perintah - posisi layanan TIDAK boleh di-hardcode di kode.
        "CREATE TABLE IF NOT EXISTS locations (\
            location_id INTEGER PRIMARY KEY AUTOINCREMENT,\
            code TEXT NOT NULL UNIQUE,\
            name TEXT NOT NULL,\
            action TEXT NOT NULL,\
            pos_x REAL NOT NULL,\
            pos_y REAL NOT NULL,\
            pos_z REAL NOT NULL,\
            radius REAL NOT NULL DEFAULT 4.0)"
    };

    for (new index = 0; index < sizeof (schema); index++) {
        if (!DB_Exec(schema[index])) {
            new report[192];
            format(report, sizeof (report), "pernyataan skema #%d gagal", index);
            Log_Error("db", report);
            return 0;
        }
    }

    // Migrasi ringan: tanggal lahir lengkap (hari & bulan) untuk identitas RP.
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'birth_day'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN birth_day INTEGER NOT NULL DEFAULT 1")) {
            Log_Error("db", "migrasi birth_day gagal");
            return 0;
        }
    }
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'birth_month'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN birth_month INTEGER NOT NULL DEFAULT 1")) {
            Log_Error("db", "migrasi birth_month gagal");
            return 0;
        }
    }
    // Poin pelanggaran SIM (domain/tilang menulis, domain/identity membaca).
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'sim_points'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN sim_points INTEGER NOT NULL DEFAULT 0")) {
            Log_Error("db", "migrasi sim_points gagal");
            return 0;
        }
    }
    // Data diri KTP (domain/identity membaca & menulis lewat /datadiri).
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'address'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN address TEXT NOT NULL \
                      DEFAULT 'Jl. Cempaka No. 9, Jakarta Timur'")) {
            Log_Error("db", "migrasi address gagal");
            return 0;
        }
    }
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'blood_type'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN blood_type TEXT NOT NULL DEFAULT 'O'")) {
            Log_Error("db", "migrasi blood_type gagal");
            return 0;
        }
    }
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'religion'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN religion TEXT NOT NULL DEFAULT 'Islam'")) {
            Log_Error("db", "migrasi religion gagal");
            return 0;
        }
    }
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'marital_status'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN marital_status TEXT NOT NULL \
                      DEFAULT 'Belum Menikah'")) {
            Log_Error("db", "migrasi marital_status gagal");
            return 0;
        }
    }
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'occupation'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN occupation TEXT NOT NULL \
                      DEFAULT 'Belum bekerja'")) {
            Log_Error("db", "migrasi occupation gagal");
            return 0;
        }
    }
    // Tinggi badan untuk kartu SIM Nasional (diubah lewat /datadiri).
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'height_cm'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN height_cm INTEGER NOT NULL DEFAULT 170")) {
            Log_Error("db", "migrasi height_cm gagal");
            return 0;
        }
    }
    // Berat badan untuk data diri karakter (diisi saat buat karakter).
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'weight_kg'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN weight_kg INTEGER NOT NULL DEFAULT 60")) {
            Log_Error("db", "migrasi weight_kg gagal");
            return 0;
        }
    }
    // Preferensi ponsel: skin tampilan (0 = iPhone, 1 = Samsung One UI).
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'phone_style'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN phone_style INTEGER NOT NULL DEFAULT 0")) {
            Log_Error("db", "migrasi phone_style gagal");
            return 0;
        }
    }
    // Preferensi ponsel: notifikasi toast (1 = tampil, 0 = senyap).
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') WHERE name = 'toast_on'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN toast_on INTEGER NOT NULL DEFAULT 1")) {
            Log_Error("db", "migrasi toast_on gagal");
            return 0;
        }
    }
    return 1;
}
