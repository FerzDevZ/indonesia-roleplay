// ---------------------------------------------------------------------------
// module      : domain/identity_simcard
// entry       : Identity_ShowSimCard()
// depends     : domain/identity, ui/simcard, core/db
// owns tables : - (membaca characters + identity_docs)
// public api  : Identity_ShowSimCard()
// Tugas       : menyusun isi kartu SIM Nasional dari data karakter dan dokumen
//               (nama, TTL, jenis kelamin, alamat, pekerjaan, golongan darah,
//               tinggi, masa berlaku) lalu menggambar lewat ui/simcard.
// ---------------------------------------------------------------------------
#if defined _INC_IDENTITY_SIMCARD
    #endinput
#endif
#define _INC_IDENTITY_SIMCARD

stock bool:Identity_ShowSimCard(playerid, characterId) {
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
    format(query, sizeof (query),
        "SELECT address FROM characters WHERE character_id = %d", characterId);
    new address[96];
    DB_String(query, address, sizeof (address));
    format(query, sizeof (query),
        "SELECT occupation FROM characters WHERE character_id = %d", characterId);
    new occupation[48];
    DB_String(query, occupation, sizeof (occupation));
    format(query, sizeof (query),
        "SELECT blood_type FROM characters WHERE character_id = %d", characterId);
    new blood[8];
    DB_String(query, blood, sizeof (blood));
    format(query, sizeof (query),
        "SELECT height_cm FROM characters WHERE character_id = %d", characterId);
    new height = DB_Int(query, 170);

    // Masa berlaku dokumen: simpan "YYYY-MM-DD HH:MM:SS", tampil DD-MM-YYYY.
    format(query, sizeof (query),
        "SELECT expires_at FROM identity_docs WHERE character_id = %d AND doc_type = '%s' \
         AND revoked_at IS NULL ORDER BY doc_id DESC LIMIT 1", characterId, DOC_TYPE_SIM);
    new expires[32];
    DB_String(query, expires, sizeof (expires));

    new const monthNames[12][4] = {
        "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
        "Jul", "Agu", "Sep", "Okt", "Nov", "Des"
    };
    new ttl[48], genderLabel[16], footBlood[24], footHeight[24], footValid[40];
    format(ttl, sizeof (ttl), "JAKARTA, %d %s %d",
        birthDay, monthNames[birthMonth - 1], birthYear);
    format(genderLabel, sizeof (genderLabel), "%s",
        !strcmp(gender, "female") ? "PEREMPUAN" : "LAKI-LAKI");
    format(footBlood, sizeof (footBlood), "Gol. Darah : %s", blood);
    format(footHeight, sizeof (footHeight), "Tinggi : %d cm", height);
    format(footValid, sizeof (footValid), "Berlaku s.d. : %.2s-%.2s-%.4s",
        expires[8], expires[5], expires[0]);

    return SimCard_Show(playerid, skin, name, ttl, genderLabel, address,
        occupation, footBlood, footHeight, "GOLONGAN : B (UMUM)", footValid);
}
