// ---------------------------------------------------------------------------
// module      : domain/chat
// entry       : Chat_Boot()
// depends     : shared/messages, shared/player_phase, shared/validate
// owns tables : -
// public api  : Chat_Boot(), Chat_HandleCommand()
// ---------------------------------------------------------------------------
#if defined _INC_CHAT
    #endinput
#endif
#define _INC_CHAT

#define CHAT_RADIUS_NORMAL  (8.0)
#define CHAT_RADIUS_SHOUT   (20.0)
#define CHAT_RADIUS_WHISPER (2.0)
#define CHAT_MAX_LENGTH     (100)
#define CHAT_ACTION_DELAY   (2000)

static gLastActionTick[MAX_PLAYERS];

stock Chat_Boot() {
    Log_Info("chat", "siap");
    return 1;
}

stock bool:Chat_HandleCommand(playerid, const command[], const params[]) {
    if (!strcmp(command, "b", true))      return Chat_Ooc(playerid, params);
    if (!strcmp(command, "s", true))      return Chat_Shout(playerid, params);
    if (!strcmp(command, "w", true))      return Chat_Whisper(playerid, params);
    if (!strcmp(command, "me", true))     return Chat_Action(playerid, params);
    if (!strcmp(command, "do", true))     return Chat_Environment(playerid, params);
    if (!strcmp(command, "saldo", true))  return Chat_Balance(playerid);
    if (!strcmp(command, "help", true))   return Chat_Help(playerid, params);
    if (!strcmp(command, "lapor", true))  return Chat_Report(playerid, params);
    return false;
}

static bool:Chat_Ooc(playerid, const params[]) {
    if (!Phase_CanChat(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }
    if (!Chat_ValidateText(playerid, params)) return true;

    new name[32], line[192];
    GetPlayerName(playerid, name, sizeof (name));
    format(line, sizeof (line), "(( %s: %s ))", name, params);

    SendClientMessageToAll(COLOR_OOC, line);
    return true;
}

static bool:Chat_Shout(playerid, const params[]) {
    if (!Phase_CanChat(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }
    if (!Chat_ValidateText(playerid, params)) return true;

    new name[32], line[192];
    GetPlayerName(playerid, name, sizeof (name));
    format(line, sizeof (line), "%s berteriak: %s!", name, params);
    Messages_SendNearby(playerid, line, CHAT_RADIUS_SHOUT);
    return true;
}

static bool:Chat_Whisper(playerid, const params[]) {
    if (!Phase_CanChat(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }
    if (!Chat_ValidateText(playerid, params)) return true;

    new name[32], line[192];
    GetPlayerName(playerid, name, sizeof (name));
    format(line, sizeof (line), "%s berbisik: %s", name, params);
    Messages_SendNearby(playerid, line, CHAT_RADIUS_WHISPER);
    return true;
}

static bool:Chat_Action(playerid, const params[]) {
    if (!Phase_CanChat(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }
    if (!Chat_ValidateAction(playerid, params)) return true;

    new name[32], line[192];
    GetPlayerName(playerid, name, sizeof (name));
    format(line, sizeof (line), "* %s %s", name, params);
    Messages_SendNearby(playerid, line, CHAT_RADIUS_NORMAL);
    return true;
}

static bool:Chat_Environment(playerid, const params[]) {
    if (!Phase_CanChat(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }
    if (!Chat_ValidateAction(playerid, params)) return true;

    new name[32], line[192];
    GetPlayerName(playerid, name, sizeof (name));
    format(line, sizeof (line), "* %s (( %s ))", params, name);
    Messages_SendNearby(playerid, line, CHAT_RADIUS_NORMAL);
    return true;
}

static bool:Chat_Balance(playerid) {
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }

    new summary[96];
    Money_Describe(playerid, summary, sizeof (summary));
    Messages_SendSystem(playerid, summary);
    return true;
}

static bool:Chat_HelpMain(playerid) {
    Messages_SendSystem(playerid, "=== BANTUAN PERINTAH ===");
    Messages_SendSystem(playerid,
        "Semua perintah diawali tanda / di chat. Contoh: /saldo");
    Messages_SendSystem(playerid,
        "IC: /me /do /s (teriak) /w (bisik) /saldo");
    Messages_SendSystem(playerid,
        "Dunia: /hp /kerja /kerjabatal | Tas: /tas");
    Messages_SendSystem(playerid,
        "Tubuh: /makan /minum /tubuh /tidur (tidur di dalam gedung)");
    Messages_SendSystem(playerid,
        "Kendaraan sewa: /rental /kendaraan /kembalikan (titik rental di radar)");
    Messages_SendSystem(playerid,
        "Kendaraan sendiri: /dealer /stnk /pakai <nomor> /parkir");
    Messages_SendSystem(playerid,
        "Musik: /radio (pilih stasiun) /musik on|off /radiostop");
    Messages_SendSystem(playerid,
        "Kendaraan: /isi penuh di pom bensin, /servis di bengkel");
    Messages_SendSystem(playerid, "Tujuan awal: /tujuan");
    Messages_SendSystem(playerid,
        "Dokumen: /ktp /sim /ujisim /datadiri | Lalu lintas: /tilang");
    Messages_SendSystem(playerid,
        "Bantuan lain: /help toko | /help admin | /lapor <masalah>");
    Messages_SendSystem(playerid, "OOC: /b");
    return true;
}

static bool:Chat_HelpToko(playerid) {
    Messages_SendSystem(playerid, "=== BANTUAN: TOKO & GEDUNG ===");
    Messages_SendSystem(playerid,
        "Dekati pintu gedung, lalu tekan Y (bukan tombol lain).");
    Messages_SendSystem(playerid,
        "Label pintu: DIJUAL = bisa dibeli, TUTUP = pemilik menutup toko.");
    Messages_SendSystem(playerid,
        "Beli barang: masuk toko, pilih kartu barang di panel.");
    Messages_SendSystem(playerid,
        "Makan/minum hasil beli: /makan atau /minum (atau PAKAI di /tas).");
    Messages_SendSystem(playerid,
        "Pemilik toko: tekan Y di pintu lalu pilih Kelola (harga, menu,");
    Messages_SendSystem(playerid,
        "buka/tutup, tarik kas). Hasil penjualan masuk kas gedung.");
    Messages_SendSystem(playerid,
        "Warung: /beli untuk melihat menu warung terdekat.");
    return true;
}

static bool:Chat_HelpAdmin(playerid) {
    new level = Auth_AdminLevel(playerid);
    if (level < ADMIN_HELPER) {
        Messages_SendError(playerid, "Bantuan admin hanya untuk admin.");
        return true;
    }
    Messages_SendSystem(playerid, "=== BANTUAN: ADMIN ===");
    Messages_SendSystem(playerid,
        "Login kunci: /superadmin <kunci> | Menu: /admin");
    Messages_SendSystem(playerid,
        "Dunia: /buatatm <nama> | /buatwarung <nama> | /tutupwarung");
    Messages_SendSystem(playerid,
        "Gedung: /buatgedung <nama> <interior> <harga>");
    Messages_SendSystem(playerid,
        "  contoh: /buatgedung Toko Sinar 1 500000");
    Messages_SendSystem(playerid,
        "  interior: 0 kosong, 1 Warung Kelontong, 2 Minimarket");
    Messages_SendSystem(playerid,
        "  minimal 6 meter dari gedung lain (mencegah label bertumpuk)");
    Messages_SendSystem(playerid,
        "Gedung lain: /setinterior <0-2> (berdiri dekat gedung)");
    Messages_SendSystem(playerid,
        "Menu warung: /tambahmenu /setharga /hapusmenu /bukawarung");
    Messages_SendSystem(playerid,
        "Rental: /buatrental <nama> | /rentalspawn (posisi mobil) | /hapusrental");
    Messages_SendSystem(playerid,
        "Paket rental: /rentalpkg | /rentalpkg tambah 462 5000 5 Motor Faggio");
    Messages_SendSystem(playerid,
        "  /rentalpkg hapus <nomor> | /rentalreload (setelah edit DB manual)");
    Messages_SendSystem(playerid,
        "Dealer: /dealerkatalog | tambah <model> <harga> <nama> | hapus <nomor>");
    Messages_SendSystem(playerid,
        "Radio: /radiostation | tambah <nama> <genre> <url> | hapus <nomor> | reload");
    Messages_SendSystem(playerid,
        "Lokasi: /buatbensin [nama] /buatbengkel [nama] (di posisimu)");
    Messages_SendSystem(playerid,
        "Pemain: /agive <id> <jumlah> | /beriitem <id> <item> <jumlah>");
    Messages_SendSystem(playerid,
        "Info: /ainfo <id> | /asay <teks> | Laporan pemain: /lapor");
    return true;
}

static bool:Chat_Help(playerid, const topic[]) {
    if (topic[0] == '\0') return Chat_HelpMain(playerid);
    if (!strcmp(topic, "toko", true) || !strcmp(topic, "gedung", true)) {
        return Chat_HelpToko(playerid);
    }
    if (!strcmp(topic, "admin", true)) return Chat_HelpAdmin(playerid);
    Messages_SendError(playerid, "Topik bantuan: toko, admin.");
    return true;
}

// Laporan pemain: masuk log server + diteruskan ke admin yang sedang online.
// Tanpa ini admin buta terhadap masalah in-game.
static bool:Chat_Report(playerid, const params[]) {
    if (!Phase_CanAct(playerid)) {
        Messages_SendError(playerid, MSG_NOT_ALIVE);
        return true;
    }
    if (strlen(params) < 5) {
        Messages_SendError(playerid, "Pakai: /lapor <masalah>");
        Messages_SendSystem(playerid,
            "Contoh: /lapor Ada pemain memakai cheat teleport di bank");
        return true;
    }

    new name[32], logLine[224];
    GetPlayerName(playerid, name, sizeof (name));
    format(logLine, sizeof (logLine), "%s: %s", name, params);
    Log_Module("lapor", logLine);

    new alert[192];
    format(alert, sizeof (alert), "[LAPORAN] %s: %s", name, params);
    new forwarded = 0;
    for (new other = 0; other < MAX_PLAYERS; other++) {
        if (!IsPlayerConnected(other)) continue;
        if (Auth_AdminLevel(other) < ADMIN_HELPER) continue;
        Messages_SendSystem(other, alert);
        forwarded++;
    }

    if (forwarded < 1) {
        Toast_Show(playerid, "LAPORAN",
            "Laporan tersimpan. Admin sedang tidak online.", THEME_INFO);
    } else {
        new message[64];
        format(message, sizeof (message), "Diteruskan ke %d admin online.", forwarded);
        Toast_Show(playerid, "LAPORAN", message, THEME_OK);
    }
    return true;
}

static bool:Chat_ValidateText(playerid, const params[]) {
    if (Text_IsEmpty(params)) {
        Messages_SendError(playerid, "Teks tidak boleh kosong.");
        return false;
    }
    if (strlen(params) > CHAT_MAX_LENGTH) {
        Messages_SendError(playerid, "Teks terlalu panjang (maksimal 100 karakter).");
        return false;
    }
    return true;
}

static bool:Chat_ValidateAction(playerid, const params[]) {
    if (!Chat_ValidateText(playerid, params)) return false;

    new now = GetTickCount();
    if (now - gLastActionTick[playerid] < CHAT_ACTION_DELAY) {
        Messages_SendError(playerid, "Terlalu cepat. Tunggu sebentar.");
        return false;
    }
    gLastActionTick[playerid] = now;
    return true;
}