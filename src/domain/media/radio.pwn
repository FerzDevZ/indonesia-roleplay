// ---------------------------------------------------------------------------
// module      : domain/media/radio
// entry       : -
// depends     : domain/media/radio_data, domain/admin (Admin_Require/Audit),
//               shared/messages, shared/player_phase, shared/validate,
//               ui/toast, ui/uimodal
// owns tables : - (daftar stasiun milik radio_data)
// public api  : Radio_Open(), Radio_Load(), Radio_Stop(), Radio_Reset(),
//               Radio_CurrentName(), Radio_IsListening(),
//               Radio_OnDialogResponse(), Radio_HandleCommand()
// Isi         : Radio in-game (audio nyata lewat PlayAudioStreamForPlayer),
//               perintah /radio /musik /radiostop, dan admin /radiostation.
// Aturan      : klien hanya boleh memutar SATU stream per pemain. Semua
//               pemutaran lewat Radio_Play supaya stream lama selalu dihentikan
//               lebih dulu (tidak ada dua lagu menumpuk). Audio tidak memakai
//               posisi 3D di tahap ini: sumber bergerak (mobil) membuat stream
//               restart setiap kali posisi dipanggil ulang.
// ---------------------------------------------------------------------------
#if defined _INC_RADIO
    #endinput
#endif
#define _INC_RADIO

#define RADIO_SOURCE_NONE   (0)
#define RADIO_SOURCE_PHONE  (1)
#define RADIO_SOURCE_CAR    (2)

static gRadioSource[MAX_PLAYERS];
static gRadioStation[MAX_PLAYERS];
static gRadioMuted[MAX_PLAYERS];

stock Radio_Load(playerid) {
    gRadioSource[playerid] = RADIO_SOURCE_NONE;
    gRadioStation[playerid] = -1;
    gRadioMuted[playerid] = 0;
    return 1;
}

stock Radio_IsListening(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return gRadioSource[playerid] != RADIO_SOURCE_NONE;
}

stock Radio_CurrentName(playerid, dest[], maxlength = sizeof (dest)) {
    if (!Radio_IsListening(playerid)) return format(dest, maxlength, "");
    return Radio_Name(gRadioStation[playerid], dest, maxlength);
}

stock Radio_Stop(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gRadioSource[playerid] == RADIO_SOURCE_NONE) return 0;
    StopAudioStreamForPlayer(playerid);
    gRadioSource[playerid] = RADIO_SOURCE_NONE;
    gRadioStation[playerid] = -1;
    return 1;
}

stock Radio_Reset(playerid) {
    Radio_Stop(playerid);
    Radio_Load(playerid);
    return 1;
}

// Satu pintu masuk untuk memutar stasiun. Stream lama dihentikan lebih dulu.
static bool:Radio_Play(playerid, stationIndex) {
    if (stationIndex < 0 || stationIndex >= Radio_Count()) {
        Messages_SendError(playerid, "Stasiun tidak tersedia.");
        return false;
    }

    new url[RADIO_URL_LEN];
    Radio_Url(stationIndex, url, sizeof (url));
    if (url[0] == EOS) {
        Messages_SendError(playerid, "URL stasiun kosong. Hubungi admin.");
        return false;
    }

    Radio_Stop(playerid);
    if (!PlayAudioStreamForPlayer(playerid, url)) {
        Messages_SendError(playerid,
            "Audio gagal diputar di klienmu. Coba /musik off lalu /radio lagi.");
        return false;
    }

    new inVehicle = IsPlayerInAnyVehicle(playerid);
    gRadioSource[playerid] = inVehicle ? RADIO_SOURCE_CAR : RADIO_SOURCE_PHONE;
    gRadioStation[playerid] = stationIndex;
    gRadioMuted[playerid] = 0;

    new name[RADIO_NAME_LEN], genre[RADIO_GENRE_LEN], message[128];
    Radio_Name(stationIndex, name, sizeof (name));
    Radio_Genre(stationIndex, genre, sizeof (genre));
    format(message, sizeof (message), "%s (%s) - %s", name, genre,
        inVehicle ? "radio mobil" : "radio pribadi");
    Toast_Show(playerid, "MUSIK", message, THEME_OK);
    Messages_SendSystem(playerid, message);
    Messages_SendSystem(playerid,
        "Matikan: /radiostop | Senyapkan: /musik off | Ganti: /radio");
    return true;
}

static Radio_BuildList(dest[], maxlength) {
    dest[0] = EOS;
    for (new index = 0; index < Radio_Count(); index++) {
        new name[RADIO_NAME_LEN], genre[RADIO_GENRE_LEN], line[96];
        Radio_Name(index, name, sizeof (name));
        Radio_Genre(index, genre, sizeof (genre));
        format(line, sizeof (line), "%s - %s (%d kbps)\n", name, genre,
            Radio_Bitrate(index));
        strcat(dest, line, maxlength);
    }
    return 1;
}

stock bool:Radio_Open(playerid) {
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return false;
    }
    if (UIModal_Active(playerid) != UI_NONE) {
        Messages_SendError(playerid, "Tutup tampilan yang terbuka dulu.");
        return false;
    }
    if (Radio_Count() <= 0) {
        Messages_SendError(playerid, "Belum ada stasiun radio. Hubungi admin.");
        return false;
    }

    new body[384], current[RADIO_NAME_LEN];
    Radio_BuildList(body, sizeof (body));
    if (Radio_CurrentName(playerid, current, sizeof (current)) > 0) {
        new title[48];
        format(title, sizeof (title), "Radio (aktif: %s)", current);
        ShowPlayerDialog(playerid, DIALOG_RADIO_LIST, DIALOG_STYLE_LIST, title,
            body, "Putar", "Tutup");
        return true;
    }

    ShowPlayerDialog(playerid, DIALOG_RADIO_LIST, DIALOG_STYLE_LIST,
        "Radio", body, "Putar", "Tutup");
    return true;
}

stock bool:Radio_OnDialogResponse(playerid, dialogid, response, listitem,
    const inputtext[]) {
    #pragma unused inputtext
    if (dialogid != DIALOG_RADIO_LIST) return false;

    if (!response) {
        Messages_SendSystem(playerid, "Radio ditutup.");
        return true;
    }
    Radio_Play(playerid, listitem);
    return true;
}

// /musik [on|off] - senyapkan atau lanjutkan stasiun terakhir.
static bool:Radio_Mute(playerid, const params[]) {
    if (params[0] == EOS) {
        new status[64];
        format(status, sizeof (status), "Musik: %s",
            gRadioMuted[playerid] ? "mati (/musik on untuk nyalakan)"
                : "hidup (/musik off untuk matikan)");
        Messages_SendSystem(playerid, status);
        return true;
    }

    if (!strcmp(params, "off", true) || !strcmp(params, "mati", true)) {
        gRadioMuted[playerid] = 1;
        Radio_Stop(playerid);
        Messages_SendSystem(playerid, "Musik dimatikan. /musik on untuk menyalakan.");
        return true;
    }
    if (!strcmp(params, "on", true) || !strcmp(params, "nyala", true)) {
        gRadioMuted[playerid] = 0;
        Messages_SendSystem(playerid, "Musik dinyalakan. Pilih stasiun: /radio");
        return true;
    }

    Messages_SendError(playerid, "Pakai: /musik on  atau  /musik off");
    return true;
}

// Perintah admin /radiostation: kelola daftar stasiun tanpa compile ulang.
static bool:Radio_Admin(playerid, const params[]) {
    if (params[0] == EOS) {
        new header[48];
        format(header, sizeof (header), "=== STASIUN RADIO (%d) ===", Radio_Count());
        Messages_SendSystem(playerid, header);
        for (new index = 0; index < Radio_Count(); index++) {
            new name[RADIO_NAME_LEN], genre[RADIO_GENRE_LEN], line[128];
            Radio_Name(index, name, sizeof (name));
            Radio_Genre(index, genre, sizeof (genre));
            format(line, sizeof (line), "%d. %s | %s | %d kbps", index + 1,
                name, genre, Radio_Bitrate(index));
            Messages_SendSystem(playerid, line);
        }
        Messages_SendSystem(playerid,
            "Tambah: /radiostation tambah <nama> <genre> <url> | Hapus: /radiostation hapus <nomor> | /radiostation reload");
        return true;
    }

    new action[12], rest[192];
    if (!Command_NextToken(params, action, sizeof (action), rest, sizeof (rest))) {
        Messages_SendError(playerid, "Pakai: /radiostation <tambah|hapus|reload>");
        return true;
    }

    if (!strcmp(action, "reload", true)) {
        new total = Radio_Reload();
        new message[64];
        format(message, sizeof (message), "%d stasiun radio dimuat ulang.", total);
        Messages_SendSystem(playerid, message);
        Admin_Audit(playerid, "RADIO_RELOAD", -1, message);
        return true;
    }

    if (!strcmp(action, "hapus", true)) {
        new index = strval(rest) - 1;
        if (index < 0 || index >= Radio_Count()) {
            Messages_SendError(playerid, "Nomor tidak ada. Lihat /radiostation.");
            return true;
        }
        new name[RADIO_NAME_LEN];
        Radio_Name(index, name, sizeof (name));
        if (!Radio_Remove(index)) {
            Messages_SendError(playerid, MSG_DB_ERROR);
            return true;
        }
        Messages_SendSystem(playerid, "Stasiun dinonaktifkan.");
        Admin_Audit(playerid, "RADIO_DEL", -1, name);
        return true;
    }

    if (strcmp(action, "tambah", true) == 0) {
        new name[RADIO_NAME_LEN], genre[RADIO_GENRE_LEN], url[RADIO_URL_LEN];
        new rest2[160];
        if (!Command_NextToken(rest, name, sizeof (name), rest2, sizeof (rest2))
            || !Command_NextToken(rest2, genre, sizeof (genre), url, sizeof (url))
            || url[0] == EOS) {
            Messages_SendError(playerid,
                "Pakai: /radiostation tambah Chillout Jazzy http://host:8000/stream");
            return true;
        }
        if (strfind(url, "http", true) != 0) {
            Messages_SendError(playerid, "URL wajib diawali http:// atau https://");
            return true;
        }
        if (!Radio_Add(name, genre, url, 128)) {
            Messages_SendError(playerid, "Stasiun gagal ditambah (penuh/URL invalid).");
            return true;
        }
        Messages_SendSystem(playerid, "Stasiun radio ditambahkan.");
        Admin_Audit(playerid, "RADIO_ADD", -1, name);
        return true;
    }

    Messages_SendError(playerid,
        "Pakai: /radiostation | tambah <nama> <genre> <url> | hapus <nomor> | reload");
    return true;
}

stock bool:Radio_HandleCommand(playerid, const command[], const params[]) {
    if (!strcmp(command, "radio", true)) {
        Radio_Open(playerid);
        return true;
    }
    if (!strcmp(command, "musik", true)) {
        return Radio_Mute(playerid, params);
    }
    if (!strcmp(command, "radiostop", true)) {
        if (Radio_Stop(playerid)) {
            Messages_SendSystem(playerid, "Radio dihentikan.");
        } else {
            Messages_SendError(playerid, "Radio tidak sedang menyala.");
        }
        return true;
    }
    if (!strcmp(command, "radiostation", true)) {
        if (!Admin_Require(playerid, ADMIN_MODERATOR)) return true;
        return Radio_Admin(playerid, params);
    }
    return false;
}
