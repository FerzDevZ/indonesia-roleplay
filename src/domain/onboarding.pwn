// ---------------------------------------------------------------------------
// module      : domain/onboarding
// entry       : public Timer_OnOnboardingTick()
// depends     : core/db, core/timer, core/log, shared/messages, shared/player_phase,
//               ui/toast, ui/theme
// owns tables : kolom characters.onboard_step (migrasi ringan di Onboarding_Boot)
// public api  : Onboarding_Boot(), Onboarding_Load(), Onboarding_Reset(),
//               Onboarding_Event(), Onboarding_Objective(),
//               Onboarding_HandleCommand(), Onboarding_ShowHud(),
//               Onboarding_Tick()
// Isi         : 5 objektif pertama pemain baru. Tanpa ini pemain spawn tanpa
//               tujuan dan keluar di menit kelima (docs/11 bagian 3).
// Aturan      : objektif HANYA maju berurutan. Event yang datang lebih awal
//               (mis. pemain lama beli makan sebelum ambil paket) tidak boleh
//               melompati langkah, supaya teks HUD tidak pernah menyesatkan.
//               Progres disimpan di DB, jadi relog tidak mengulang dari nol.
// ---------------------------------------------------------------------------
#if defined _INC_ONBOARDING
    #endinput
#endif
#define _INC_ONBOARDING

#define ONBOARD_STEPS       (5)

// Nomor event = nomor langkah yang diselesaikan (1..5).
#define ONBOARD_PHONE       (1)
#define ONBOARD_JOB         (2)
#define ONBOARD_DELIVER     (3)
#define ONBOARD_FOOD        (4)
#define ONBOARD_ATM         (5)

static gOnboardStep[MAX_PLAYERS];
static PlayerText:gOnboardText[MAX_PLAYERS];
static gOnboardShown[MAX_PLAYERS];
static gOnboardTextValue[MAX_PLAYERS];

stock Onboarding_Boot() {
    if (DB_Int("SELECT COUNT(*) FROM pragma_table_info('characters') \
            WHERE name = 'onboard_step'", 0) == 0) {
        if (!DB_Exec("ALTER TABLE characters ADD COLUMN onboard_step \
                INTEGER NOT NULL DEFAULT 0")) {
            Log_Error("onboarding", "migrasi kolom characters.onboard_step gagal");
            return 0;
        }
    }
    if (!Timer_Add("Timer_OnOnboardingTick", 1_000, true)) {
        Log_Error("onboarding", "timer objektif gagal didaftarkan");
        return 0;
    }
    Log_Info("onboarding", "objektif pemain baru siap");
    return 1;
}

stock Onboarding_Load(playerid, characterId) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gOnboardStep[playerid] = 0;
    gOnboardTextValue[playerid] = -1;
    if (characterId <= 0) return 0;

    new query[128];
    format(query, sizeof (query),
        "SELECT onboard_step FROM characters WHERE character_id = %d", characterId);
    new step = DB_Int(query, 0);
    if (step < 0) step = 0;
    if (step > ONBOARD_STEPS) step = ONBOARD_STEPS;
    gOnboardStep[playerid] = step;
    return step;
}

static Onboarding_Save(playerid) {
    new characterId = Character_GetId(playerid);
    if (characterId <= 0) return 0;

    new query[128];
    format(query, sizeof (query),
        "UPDATE characters SET onboard_step = %d WHERE character_id = %d",
        gOnboardStep[playerid], characterId);
    return DB_Exec(query);
}

stock Onboarding_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    Onboarding_ShowHud(playerid, false);
    gOnboardStep[playerid] = 0;
    gOnboardTextValue[playerid] = -1;
    return 1;
}

// Teks pendek per langkah (dipakai HUD 640x480, jadi harus singkat).
static Onboarding_ShortObjective(step, dest[], maxlength = sizeof (dest)) {
    switch (step) {
        case ONBOARD_PHONE:   return format(dest, maxlength, "buka ponsel (/hp)");
        case ONBOARD_JOB:     return format(dest, maxlength, "ambil paket di Job Center");
        case ONBOARD_DELIVER: return format(dest, maxlength, "antar paket, tekan [Y]");
        case ONBOARD_FOOD:    return format(dest, maxlength, "beli makan di warung");
        case ONBOARD_ATM:     return format(dest, maxlength, "cek saldo di ATM");
    }
    return format(dest, maxlength, "selesai");
}

stock Onboarding_Objective(playerid, dest[], maxlength = sizeof (dest)) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    new step = gOnboardStep[playerid];
    if (step >= ONBOARD_STEPS) {
        return format(dest, maxlength,
            "Objektif awal selesai. Jalankan /help untuk daftar perintah.");
    }
    new label[64];
    Onboarding_ShortObjective(step + 1, label, sizeof (label));
    return format(dest, maxlength, "Objektif %d/%d: %s.", step + 1, ONBOARD_STEPS,
        label);
}

// Dipanggil modul lain saat aksi berhasil. Hanya langkah berikutnya yang maju.
stock bool:Onboarding_Event(playerid, event) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (gOnboardStep[playerid] >= ONBOARD_STEPS) return false;
    if (event != gOnboardStep[playerid] + 1) return false;

    gOnboardStep[playerid]++;
    Onboarding_Save(playerid);
    Onboarding_RefreshHud(playerid);

    new label[64], message[128];
    Onboarding_ShortObjective(event, label, sizeof (label));
    format(message, sizeof (message), "Objektif %d/%d selesai: %s.",
        event, ONBOARD_STEPS, label);
    Toast_Show(playerid, "OBJEKTIF", message, THEME_OK);

    if (gOnboardStep[playerid] >= ONBOARD_STEPS) {
        Messages_SendSystem(playerid,
            "Semua objektif awal selesai. Sekarang caramu sendiri: kerja, dagang, atau jalan-jalan.");
    } else {
        new next[64];
        Onboarding_ShortObjective(gOnboardStep[playerid] + 1, next, sizeof (next));
        format(message, sizeof (message), "Berikutnya: %s.", next);
        Messages_SendSystem(playerid, message);
    }
    return true;
}

// --- HUD objektif (satu baris, bawah layar) --------------------------------

static Onboarding_CreateHud(playerid) {
    gOnboardText[playerid] = CreatePlayerTextDraw(playerid, 150.0, 424.0, " ");
    PlayerTextDrawFont(playerid, gOnboardText[playerid], THEME_FONT_BODY);
    PlayerTextDrawLetterSize(playerid, gOnboardText[playerid], 0.24, 1.10);
    PlayerTextDrawColour(playerid, gOnboardText[playerid], THEME_WARN);
    PlayerTextDrawSetOutline(playerid, gOnboardText[playerid], 1);
    PlayerTextDrawSetShadow(playerid, gOnboardText[playerid], 1);
    gOnboardTextValue[playerid] = -1;
    return 1;
}

stock Onboarding_RefreshHud(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gOnboardShown[playerid]) return 0;

    new step = gOnboardStep[playerid];
    if (gOnboardTextValue[playerid] == step) return 0;

    new label[64], line[96];
    Onboarding_ShortObjective(step + 1, label, sizeof (label));
    format(line, sizeof (line), "OBJEKTIF %d/%d - %s", step + 1, ONBOARD_STEPS,
        label);
    PlayerTextDrawSetString(playerid, gOnboardText[playerid], line);
    gOnboardTextValue[playerid] = step;
    return 1;
}

stock Onboarding_ShowHud(playerid, bool:toggle = true) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!toggle) {
        if (!gOnboardShown[playerid]) return 0;
        PlayerTextDrawHide(playerid, gOnboardText[playerid]);
        PlayerTextDrawDestroy(playerid, gOnboardText[playerid]);
        gOnboardText[playerid] = PlayerText:INVALID_TEXT_DRAW;
        gOnboardShown[playerid] = 0;
        gOnboardTextValue[playerid] = -1;
        return 1;
    }
    if (gOnboardShown[playerid]) {
        Onboarding_RefreshHud(playerid);
        return 1;
    }
    Onboarding_CreateHud(playerid);
    PlayerTextDrawShow(playerid, gOnboardText[playerid]);
    gOnboardShown[playerid] = 1;
    gOnboardTextValue[playerid] = -1;
    Onboarding_RefreshHud(playerid);
    return 1;
}

// Tampilkan hanya setelah pemain benar-benar bisa bergerak (pola deferred
// activation: jangan membuat textdraw di dalam callback spawn).
stock Onboarding_Tick() {
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;
        if (!Phase_CanAct(playerid)) continue;

        if (gOnboardStep[playerid] >= ONBOARD_STEPS) {
            if (gOnboardShown[playerid]) Onboarding_ShowHud(playerid, false);
            continue;
        }
        if (!gOnboardShown[playerid]) Onboarding_ShowHud(playerid);
        else Onboarding_RefreshHud(playerid);
    }
    return 1;
}

stock bool:Onboarding_HandleCommand(playerid, const command[], const params[]) {
    #pragma unused params
    if (strcmp(command, "tujuan", true) != 0) return false;

    new line[128], next[64];
    Onboarding_Objective(playerid, line, sizeof (line));
    Messages_SendSystem(playerid, line);

    if (gOnboardStep[playerid] < ONBOARD_STEPS) {
        Onboarding_ShortObjective(gOnboardStep[playerid] + 1, next, sizeof (next));
        format(line, sizeof (line), "Langkah berikutnya: %s", next);
        Messages_SendSystem(playerid, line);
    }
    return true;
}

public Timer_OnOnboardingTick() {
    Onboarding_Tick();
    return 1;
}
