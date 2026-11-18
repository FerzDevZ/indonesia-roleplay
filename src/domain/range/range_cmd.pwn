// ---------------------------------------------------------------------------
// module      : domain/range/range_cmd
// entry       : -
// depends     : domain/range/range, domain/range/range_data, shared/messages
// owns tables : -
// public api  : Range_HandleCommand(), Range_OnDialogResponse()
// Isi         : perintah & dialog latihan tembak: /latihan, /latihanselesai,
//               /rekor, dan /buatlatihan (admin).
// Aturan      : semua biaya diambil lewat Range_Start() di modul inti, jadi
//               pemotongan uang tetap satu pintu. Setiap perintah admin dicatat
//               lewat Admin_Audit.
// ---------------------------------------------------------------------------
#if defined _INC_RANGE_CMD
    #endinput
#endif
#define _INC_RANGE_CMD

// --- Perintah & dialog -----------------------------------------------------


stock bool:Range_OnDialogResponse(playerid, dialogid, response, listitem,
    const inputtext[]) {
    #pragma unused inputtext
    if (dialogid != DIALOG_RANGE_MODES) return false;

    if (!response) {
        Messages_SendSystem(playerid, "Latihan dibatalkan.");
        return true;
    }
    Range_Start(playerid, listitem);
    return true;
}

static Range_ShowRecords(playerid) {
    new body[512];
    RangeData_Top(body, sizeof (body));
    ShowPlayerDialog(playerid, DIALOG_RANGE_RECORDS, DIALOG_STYLE_MSGBOX,
        "Rekor Latihan Tembak", body, "Tutup", "");
    return 1;
}

stock bool:Range_HandleCommand(playerid, const command[], const params[]) {
    if (!strcmp(command, "latihan", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        if (Locations_NearCode(playerid, LOC_ACT_LATIHAN) < 0
                && !Range_IsActive(playerid)) {
            Messages_SendError(playerid,
                "Datang ke lokasi latihan tembak (ikon info di radar) lalu /latihan.");
            return true;
        }
        Range_Open(playerid);
        return true;
    }
    if (!strcmp(command, "latihanselesai", true)) {
        if (!Range_IsActive(playerid)) {
            Messages_SendError(playerid, "Kamu tidak sedang latihan.");
            return true;
        }
        Range_End(playerid, true);
        return true;
    }
    if (!strcmp(command, "rekor", true)) {
        Range_ShowRecords(playerid);
        return true;
    }
    if (!strcmp(command, "buatlatihan", true)) {
        if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;

        new name[LOC_NAME_LEN];
        if (params[0] == EOS) {
            format(name, sizeof (name), "Latihan Tembak");
        } else {
            format(name, sizeof (name), "Latihan Tembak %s", params);
        }
        new code[LOC_CODE_LEN];
        format(code, sizeof (code), "LATIHAN_%d", gettime() % 100000);

        new Float:posX, Float:posY, Float:posZ;
        GetPlayerPos(playerid, posX, posY, posZ);
        if (Locations_Add(code, name, LOC_ACT_LATIHAN, posX, posY, posZ, 3.0) < 0) {
            Messages_SendError(playerid, "Gagal dipasang: daftar lokasi penuh.");
            return true;
        }
        Messages_SendSystem(playerid, "Lokasi latihan tembak dipasang.");
        Admin_Audit(playerid, "RANGE_CREATE", -1, code);
        return true;
    }
    return false;
}
