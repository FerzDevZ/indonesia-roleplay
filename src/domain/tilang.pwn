// ---------------------------------------------------------------------------
// module      : domain/tilang
// entry       : Tilang_Boot()
// depends     : core/db, core/log, shared/messages, shared/money,
//               shared/player_phase, shared/validate, ui/toast,
//               domain/character, domain/identity
// owns tables : characters.sim_points (kolom, ditulis lewat modul ini),
//               identity_docs (penarikan SIM lewat Identity)
// public api  : Tilang_Boot(), Tilang_Issue(), Tilang_HandleCommand()
// Aturan      : denda adalah sink uang (Money_Take/Debt dengan reason FINE);
//               tidak ada uang yang berpindah ke pemain lain di sini. Tiga
//               poin pelanggaran menarik SIM aktif (kolom revoked_at).
// ---------------------------------------------------------------------------
#if defined _INC_TILANG
    #endinput
#endif
#define _INC_TILANG

#define TILANG_MAX_FINE     (5000000)
#define TILANG_MIN_FINE     (10000)

stock Tilang_Boot() {
    Log_Info("tilang", "siap");
    return 1;
}

// Terbitkan tilang ke pemain online. Issuer butuh otoritas (admin_level >= 1,
// peran polisi menyusul saat sistem faksi jadi).
stock bool:Tilang_Issue(playerid, targetPlayerid, fineAmount) {
    if (!Validate_PlayerId(playerid) || !Validate_PlayerId(targetPlayerid)) return false;
    if (targetPlayerid == playerid) {
        Messages_SendError(playerid, "Tidak bisa menilang diri sendiri.");
        return false;
    }
    if (fineAmount < TILANG_MIN_FINE || fineAmount > TILANG_MAX_FINE) {
        new body[96];
        format(body, sizeof (body),
            "Denda harus antara Rp 10.000 dan Rp 5.000.000 (diterima: %d).", fineAmount);
        Messages_SendError(playerid, body);
        return false;
    }
    if (!Phase_CanAct(targetPlayerid)) {
        Messages_SendError(playerid, "Target tilang tidak dalam dunia permainan.");
        return false;
    }

    new targetCharacterId = Character_GetId(targetPlayerid);
    if (targetCharacterId < 1) {
        Messages_SendError(playerid, MSG_INTERNAL_ERROR);
        return false;
    }

    // 1. Denda: potong tunai, boleh jadi utang bila tunai kurang (sink).
    new finePaid = false;
    if (Money_GetCash(targetPlayerid) >= fineAmount) {
        finePaid = Money_Take(targetPlayerid, fineAmount, MONEY_REASON_FINE,
            Character_GetId(playerid));
    } else {
        finePaid = Money_Debt(targetPlayerid, fineAmount, MONEY_REASON_FINE,
            Character_GetId(playerid));
    }
    if (!finePaid) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return false;
    }

    // 2. Poin pelanggaran SIM.
    new query[192];
    format(query, sizeof (query),
        "UPDATE characters SET sim_points = sim_points + 1 WHERE character_id = %d",
        targetCharacterId);
    if (!DB_Exec(query)) {
        Log_Error("tilang", "gagal tambah poin SIM");
    }
    format(query, sizeof (query),
        "SELECT sim_points FROM characters WHERE character_id = %d", targetCharacterId);
    new points = DB_Int(query, 0);

    // 3. Tiga poin: SIM ditarik.
    new bool:revoked = false;
    if (points >= SIM_POINTS_REVOKE && Identity_HasDoc(targetCharacterId, DOC_TYPE_SIM)) {
        format(query, sizeof (query),
            "UPDATE identity_docs SET revoked_at = datetime('now'), \
             revoke_reason = 'poin pelanggaran mencapai %d' \
             WHERE character_id = %d AND doc_type = '%s' AND revoked_at IS NULL",
            SIM_POINTS_REVOKE, targetCharacterId, DOC_TYPE_SIM);
        if (DB_Exec(query)) revoked = true;
    }

    // 4. Beritahu kedua pihak.
    new fineLabel[24];
    Messages_Money(fineAmount, fineLabel, sizeof (fineLabel));

    new targetBody[160];
    format(targetBody, sizeof (targetBody),
        "Kamu ditilang. Denda %s dibayar dari uang tunai. Poin SIM: %d/%d.",
        fineLabel, points, SIM_POINTS_REVOKE);
    Toast_Show(targetPlayerid, "TILANG", targetBody, THEME_DANGER);
    Messages_SendSystem(targetPlayerid, targetBody);

    if (revoked) {
        format(targetBody, sizeof (targetBody),
            "Poin pelanggaran mencapai %d. SIM kamu DITARIK.", SIM_POINTS_REVOKE);
        Toast_Show(targetPlayerid, "SIM DITARIK", targetBody, THEME_DANGER);
        Messages_SendSystem(targetPlayerid, targetBody);
    }

    new targetName[64];
    Character_GetFullName(targetPlayerid, targetName, sizeof (targetName));
    new issuerBody[128];
    format(issuerBody, sizeof (issuerBody),
        "Tilang diterbitkan ke %s. Denda %s, poin SIM target: %d/%d.",
        targetName, fineLabel, points, SIM_POINTS_REVOKE);
    Messages_SendSystem(playerid, issuerBody);

    Log_Module("tilang", issuerBody);
    return true;
}

stock Tilang_HandleCommand(playerid, const command[], const params[]) {
    if (strcmp(command, "tilang", true)) return false;

    new adminLevel = Auth_AdminLevel(playerid);
    if (adminLevel < 1) {
        Messages_SendError(playerid, MSG_NO_PERMISSION);
        return true;
    }

    new targetName[64], fineText[16], rest[96];
    if (!Command_NextToken(params, targetName, sizeof (targetName), rest, sizeof (rest))
        || !Command_NextToken(rest, fineText, sizeof (fineText), rest, sizeof (rest))) {
        Messages_SendError(playerid, "Pemakaian: /tilang <nama karakter> <denda>");
        return true;
    }

    new fineAmount = strval(fineText);
    new targetPlayerid = Identity_FindByName(targetName);
    if (targetPlayerid < 0) {
        Messages_SendError(playerid, "Pemain dengan nama karakter itu tidak online.");
        return true;
    }

    Tilang_Issue(playerid, targetPlayerid, fineAmount);
    return true;
}
