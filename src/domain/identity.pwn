// ---------------------------------------------------------------------------
// module      : domain/identity
// entry       : Identity_Boot()
// depends     : core/db, core/log, shared/messages, shared/money,
//               shared/player_phase, ui/doccard, ui/toast, domain/character
// owns tables : identity_docs (tabel), characters.sim_points (kolom)
// public api  : Identity_Boot(), Identity_IssueKTP(), Identity_HasDoc(),
//               Identity_GetDocNumber(), Identity_Age(), Identity_ShowKTPTo(),
//               Identity_ShowOwnKTP(), Identity_ShowOwnSIM(),
//               Identity_TakeSimTest(), Identity_FindByName(),
//               Identity_HandleCommand()
// Aturan      : penerbitan & penarikan dokumen hanya lewat modul ini. Nomor
//               dokumen dibentuk dari doc_id (unik oleh constraint tabel).
//               Akses DB hanya lewat API core/db.
// ---------------------------------------------------------------------------
#if defined _INC_IDENTITY
    #endinput
#endif
#define _INC_IDENTITY

#define DOC_TYPE_KTP        "KTP"
#define DOC_TYPE_SIM        "SIM_B"
// Fase C: biaya terjangkau pemain baru (tangga progresi docs/11) dan gerbang
// lokasi dinamis - ujian hanya di lokasi beraksi LOKET_PD dari tabel locations.
#define SIM_FEE             (100000)
#define SIM_MIN_AGE         (17)
#define SIM_POINTS_REVOKE   (3)
#define SIM_VALID_YEARS     (5)

stock Identity_Boot() {
    Log_Info("identity", "siap");
    return 1;
}

// KTP diterbitkan otomatis saat karakter dibuat (dipanggil character_create).
stock Identity_IssueKTP(characterId) {
    if (characterId < 1) return 0;

    new stamp = GetTickCount();
    new query[192];
    format(query, sizeof (query),
        "INSERT INTO identity_docs (character_id, doc_type, doc_number, issued_at) \
         VALUES (%d, '%s', 'TMP-%d-%d', datetime('now'))",
        characterId, DOC_TYPE_KTP, stamp, characterId);
    if (!DB_Exec(query)) {
        Log_Error("identity", "gagal terbitkan KTP");
        return 0;
    }

    new docId = DB_InsertId();
    format(query, sizeof (query),
        "UPDATE identity_docs SET doc_number = 'KTP-%08d' WHERE doc_id = %d",
        docId, docId);
    DB_Exec(query);
    return docId;
}

stock bool:Identity_HasDoc(characterId, const docType[]) {
    new query[224];
    format(query, sizeof (query),
        "SELECT COUNT(*) FROM identity_docs WHERE character_id = %d AND doc_type = '%s' \
         AND revoked_at IS NULL", characterId, docType);
    return DB_Int(query, 0) > 0;
}

stock bool:Identity_GetDocNumber(characterId, const docType[], dest[], maxlength = sizeof (dest)) {
    new query[224];
    format(query, sizeof (query),
        "SELECT doc_number FROM identity_docs WHERE character_id = %d AND doc_type = '%s' \
         AND revoked_at IS NULL ORDER BY doc_id DESC LIMIT 1", characterId, docType);
    return DB_String(query, dest, maxlength);
}

// NIK tampilan 16 digit: baris baru sudah format NIK; baris lama (KTP-xxxx)
// diturunkan dari tanggal lahir + doc_id supaya stabil.
stock bool:Identity_GetNik(characterId, dest[], maxlength = sizeof (dest)) {
    new query[192];
    format(query, sizeof (query),
        "SELECT doc_id FROM identity_docs WHERE character_id = %d AND doc_type = '%s' \
         AND revoked_at IS NULL ORDER BY doc_id DESC LIMIT 1", characterId, DOC_TYPE_KTP);
    new docId = DB_Int(query, 0);
    if (docId < 1) return false;

    new docNumber[32] = "";
    Identity_GetDocNumber(characterId, DOC_TYPE_KTP, docNumber, sizeof (docNumber));

    // Nomor sudah format NIK (16 digit angka) -> pakai langsung.
    if (strlen(docNumber) == 16 && '0' <= docNumber[0] <= '9') {
        format(dest, maxlength, "%s", docNumber);
        return true;
    }

    // Nomor lama: turunkan NIK dari data karakter.
    format(query, sizeof (query),
        "SELECT birth_day FROM characters WHERE character_id = %d", characterId);
    new birthDay = DB_Int(query, 1);
    format(query, sizeof (query),
        "SELECT birth_month FROM characters WHERE character_id = %d", characterId);
    new birthMonth = DB_Int(query, 1);
    format(query, sizeof (query),
        "SELECT birth_year FROM characters WHERE character_id = %d", characterId);
    new birthYear = DB_Int(query, 2000);

    format(dest, maxlength, "3175%02d%02d%02d%06d",
        birthDay, birthMonth, birthYear % 100, docId % 1000000);
    return true;
}

// --- kartu dokumen ----------------------------------------------------------
stock bool:Identity_ShowKTPTo(playerid, characterId) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (characterId < 1) {
        Messages_SendError(playerid, MSG_INTERNAL_ERROR);
        return false;
    }

    new query[256];
    format(query, sizeof (query),
        "SELECT first_name || ' ' || last_name FROM characters WHERE character_id = %d",
        characterId);
    new name[64];
    if (!DB_String(query, name, sizeof (name))) {
        Messages_SendError(playerid, MSG_INTERNAL_ERROR);
        return false;
    }

    // NIK 16 digit (nomor dokumen KTP).
    new nik[24] = "3175000000000000";
    if (!Identity_GetNik(characterId, nik, sizeof (nik))) {
        Messages_SendError(playerid, MSG_INTERNAL_ERROR);
        return false;
    }

    format(query, sizeof (query),
        "SELECT gender FROM characters WHERE character_id = %d", characterId);
    new gender[8];
    DB_String(query, gender, sizeof (gender));

    format(query, sizeof (query),
        "SELECT birth_day FROM characters WHERE character_id = %d", characterId);
    new birthDay = DB_Int(query, 1);
    format(query, sizeof (query),
        "SELECT birth_month FROM characters WHERE character_id = %d", characterId);
    new birthMonth = DB_Int(query, 1);
    format(query, sizeof (query),
        "SELECT birth_year FROM characters WHERE character_id = %d", characterId);
    new birthYear = DB_Int(query, 2000);
    format(query, sizeof (query),
        "SELECT skin_model FROM characters WHERE character_id = %d", characterId);
    new skin = DB_Int(query, DEFAULT_SKIN_MALE);

    // Data diri yang bisa diubah lewat /datadiri.
    format(query, sizeof (query),
        "SELECT address FROM characters WHERE character_id = %d", characterId);
    new address[96];
    DB_String(query, address, sizeof (address));
    format(query, sizeof (query),
        "SELECT blood_type FROM characters WHERE character_id = %d", characterId);
    new blood[8];
    DB_String(query, blood, sizeof (blood));
    format(query, sizeof (query),
        "SELECT religion FROM characters WHERE character_id = %d", characterId);
    new religion[24];
    DB_String(query, religion, sizeof (religion));
    format(query, sizeof (query),
        "SELECT marital_status FROM characters WHERE character_id = %d", characterId);
    new marital[32];
    DB_String(query, marital, sizeof (marital));
    format(query, sizeof (query),
        "SELECT occupation FROM characters WHERE character_id = %d", characterId);
    new occupation[48];
    DB_String(query, occupation, sizeof (occupation));

    new const monthNames[12][4] = {
        "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
        "Jul", "Agu", "Sep", "Okt", "Nov", "Des"
    };
    new ttl[48], genderLabel[16];
    format(ttl, sizeof (ttl), "JAKARTA, %d %s %d",
        birthDay, monthNames[birthMonth - 1], birthYear);
    format(genderLabel, sizeof (genderLabel), "%s",
        !strcmp(gender, "female") ? "PEREMPUAN" : "LAKI-LAKI");

    return KtpCard_Show(playerid, nik, skin,
        name, ttl, genderLabel, blood,
        address, "003/005", "Cempaka Putih", "Jakarta Pusat",
        religion, marital, occupation);
}

stock bool:Identity_ShowOwnKTP(playerid) {
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }
    return Identity_ShowKTPTo(playerid, Character_GetId(playerid));
}

stock bool:Identity_ShowOwnSIM(playerid) {
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }
    new characterId = Character_GetId(playerid);
    if (!Identity_HasDoc(characterId, DOC_TYPE_SIM)) {
        Messages_SendError(playerid,
            "Kamu belum punya SIM. Datangi Loket PD untuk ambil ujian (Rp 100.000).");
        return true;
    }
    return Identity_ShowSimCard(playerid, characterId);
}

// --- ujian SIM --------------------------------------------------------------
stock bool:Identity_TakeSimTest(playerid) {
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }
    new characterId = Character_GetId(playerid);
    if (Identity_HasDoc(characterId, DOC_TYPE_SIM)) {
        Messages_SendError(playerid, "Kamu sudah punya SIM B yang berlaku.");
        return true;
    }

    // Gerbang lokasi dinamis (docs/11): ujian SIM hanya di Loket PD.
    if (Locations_NearCode(playerid, LOC_ACT_LOKET_PD) < 0) {
        Messages_SendError(playerid,
            "Ujian SIM hanya di Loket PD (Markas Polisi). Datangi loketnya dulu.");
        return true;
    }

    new query[192];
    format(query, sizeof (query),
        "SELECT birth_year FROM characters WHERE character_id = %d", characterId);
    new birthYear = DB_Int(query, 2000);
    format(query, sizeof (query),
        "SELECT birth_month FROM characters WHERE character_id = %d", characterId);
    new birthMonth = DB_Int(query, 1);
    format(query, sizeof (query),
        "SELECT birth_day FROM characters WHERE character_id = %d", characterId);
    new birthDay = DB_Int(query, 1);

    new thisYear, thisMonth, thisDay;
    getdate(thisYear, thisMonth, thisDay);
    new age = thisYear - birthYear;
    if (thisMonth < birthMonth || (thisMonth == birthMonth && thisDay < birthDay)) age--;

    if (age < SIM_MIN_AGE) {
        new body[96];
        format(body, sizeof (body), "Usia kamu %d tahun. SIM butuh usia minimal %d tahun.",
            age, SIM_MIN_AGE);
        Messages_SendError(playerid, body);
        return true;
    }
    if (Money_GetCash(playerid) < SIM_FEE) {
        new feeLabel[24], line[128];
        Messages_Money(SIM_FEE, feeLabel, sizeof (feeLabel));
        format(line, sizeof (line), "Biaya ujian SIM %s. Uang tunai kamu tidak cukup.",
            feeLabel);
        Messages_SendError(playerid, line);
        return true;
    }

    if (!Money_Take(playerid, SIM_FEE, MONEY_REASON_TAX)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return true;
    }

    new stamp = GetTickCount();
    format(query, sizeof (query),
        "INSERT INTO identity_docs (character_id, doc_type, doc_number, issued_at, expires_at) \
         VALUES (%d, '%s', 'TMP-%d-%d', datetime('now'), datetime('now', '+%d years'))",
        characterId, DOC_TYPE_SIM, stamp, characterId, SIM_VALID_YEARS);
    if (!DB_Exec(query)) {
        Log_Error("identity", "gagal terbitkan SIM");
        Messages_SendError(playerid, MSG_DB_ERROR);
        return true;
    }

    new docId = DB_InsertId();
    new docNumber[32];
    format(docNumber, sizeof (docNumber), "SIM-%08d", docId);
    format(query, sizeof (query),
        "UPDATE identity_docs SET doc_number = '%s' WHERE doc_id = %d", docNumber, docId);
    DB_Exec(query);

    format(query, sizeof (query),
        "SELECT first_name || ' ' || last_name FROM characters WHERE character_id = %d",
        characterId);
    new name[64];
    DB_String(query, name, sizeof (name));

    new feeLabel[24], message[128];
    Messages_Money(SIM_FEE, feeLabel, sizeof (feeLabel));
    format(message, sizeof (message), "SIM B diterbitkan. Biaya ujian %s.", feeLabel);
    Toast_Show(playerid, "SIM DITERBITKAN", message, THEME_OK);
    Messages_SendSystem(playerid, message);

    Identity_ShowSimCard(playerid, characterId);
    return true;
}

// --- pencarian & perintah ---------------------------------------------------
// Cari pemain online berdasarkan nama karakter lengkap (tidak peka huruf besar
// kecil). Return playerid, atau -1 kalau tidak ketemu.
stock Identity_FindByName(const name[]) {
    new players[MAX_PLAYERS];
    new count = GetPlayers(players, sizeof (players));

    for (new index = 0; index < count; index++) {
        new playerid = players[index];
        new fullName[64];
        Character_GetFullName(playerid, fullName, sizeof (fullName));
        if (!strcmp(fullName, name, true)) return playerid;
    }
    return -1;
}

stock bool:Identity_HandleCommand(playerid, const command[], const params[]) {
    if (!strcmp(command, "ktp", true)) {
        Identity_ShowOwnKTP(playerid);
        return true;
    }
    if (!strcmp(command, "sim", true)) {
        Identity_ShowOwnSIM(playerid);
        return true;
    }
    if (!strcmp(command, "ujisim", true)) {
        Identity_TakeSimTest(playerid);
        return true;
    }
    if (!strcmp(command, "datadiri", true)) {
        Identity_OpenDataDiri(playerid);
        return true;
    }
    #pragma unused params
    return false;
}
