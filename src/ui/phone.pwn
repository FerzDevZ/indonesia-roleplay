// ---------------------------------------------------------------------------
// module      : ui/phone
// entry       : PhoneUI_Open()
// depends     : ui/theme, ui/trxtdraw, ui/uimodal, ui/toast, ui/phone_draw,
//               shared/money, core/db, domain/character (Character_GetId)
// public api  : PhoneUI_Open(), PhoneUI_Destroy(), PhoneUI_IsOpen(),
//               PhoneUI_OnClick(), PhoneUI_Tick(), PhoneUI_GetStyle(),
//               PhoneUI_StyleName(), PhoneUI_ToastName(),
//               PhoneUI_TrackHandle(), PhoneUI_SetValHandle()
// Isi         : smartphone dua skin (iPhone obsidian / Samsung One UI) dengan
//               aplikasi BANK, KTP, PENGATURAN, KERJA. Layar Pengaturan:
//               ganti skin (tersimpan di DB characters.phone_style) dan
//               notifikasi toast (characters.toast_on).
// Anti-glitch : SEMUA layar dibuat SEKALI saat open; pindah layar hanya
//               Show/Hide (tidak ada destroy di dalam callback klik). Rebuild
//               penuh (ganti skin) ditunda ke PhoneUI_Tick via flag pending.
// ---------------------------------------------------------------------------
#if defined _INC_UI_PHONE
    #endinput
#endif
#define _INC_UI_PHONE

#include "theme.pwn"
#include "uimodal.pwn"

#define PHONEUI_ID_BANK        (270)
#define PHONEUI_ID_KTP         (271)
#define PHONEUI_ID_CLOSE       (272)
#define PHONEUI_ID_SETTINGS    (273)
#define PHONEUI_ID_KERJA       (274)
#define PHONEUI_ID_BACK        (275)
#define PHONEUI_ID_SET_SKIN    (276)
#define PHONEUI_ID_SET_TOAST   (277)

#define PHONE_SCREEN_HOME      (0)
#define PHONE_SCREEN_SETTINGS  (1)

#define PHONE_SKIN_IPHONE      (0)
#define PHONE_SKIN_SAMSUNG     (1)

#define PHONE_HOME_MAX_TD   (128)
#define PHONE_SET_MAX_TD    (72)

static bool:gPhoneOpen[MAX_PLAYERS];
static gPhoneScreen[MAX_PLAYERS];
static bool:gPhonePendingHome[MAX_PLAYERS];     // rebuild home ditunda ke tick
static gPhoneStyle[MAX_PLAYERS];                // PHONE_SKIN_*
static bool:gPhoneToastOn[MAX_PLAYERS];
static gPhoneDrawList[MAX_PLAYERS];             // layar yang sedang digambar

// Daftar kill per layar: pindah layar = Hide list lama, Show list baru.
static PlayerText:gPhoneHomeTd[MAX_PLAYERS][PHONE_HOME_MAX_TD];
static gPhoneHomeCount[MAX_PLAYERS];
static PlayerText:gPhoneSetTd[MAX_PLAYERS][PHONE_SET_MAX_TD];
static gPhoneSetCount[MAX_PLAYERS];

// Nilai baris Pengaturan yang berubah lewat SetString (update in-place).
static PlayerText:gPhoneValSkin[MAX_PLAYERS];
static PlayerText:gPhoneValToast[MAX_PLAYERS];

stock bool:PhoneUI_IsOpen(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gPhoneOpen[playerid];
}

stock PhoneUI_GetStyle(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return PHONE_SKIN_IPHONE;
    return gPhoneStyle[playerid];
}

stock PhoneUI_StyleName(playerid, dest[], maxlength) {
    if (PhoneUI_GetStyle(playerid) == PHONE_SKIN_SAMSUNG) {
        return format(dest, maxlength, "Samsung");
    }
    return format(dest, maxlength, "iPhone");
}

stock PhoneUI_ToastName(playerid, dest[], maxlength) {
    if (gPhoneToastOn[playerid]) return format(dest, maxlength, "AKTIF");
    return format(dest, maxlength, "MATI");
}

// Catat handle ke daftar kill layar yang sedang digambar (dipanggil phone_draw
// lewat PhoneTrack; PhoneUI_BeginDraw menentukan daftar tujuan).
stock PhoneUI_BeginDraw(playerid, listId) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gPhoneDrawList[playerid] = listId;
    return 1;
}

// Handle jam ponsel untuk update hidup tiap tick (status bar + widget home).
static PlayerText:gPhoneClockTd[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static PlayerText:gPhoneWidgetClockTd[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };

stock PhoneUI_SetStatusClock(playerid, PlayerText:statusClock) {
    gPhoneClockTd[playerid] = statusClock;
    return 1;
}

stock PhoneUI_SetWidgetClock(playerid, PlayerText:widgetClock) {
    gPhoneWidgetClockTd[playerid] = widgetClock;
    return 1;
}

stock PhoneUI_TrackHandle(playerid, PlayerText:handle) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    // Pengaman: hanya modul ponsel yang boleh mengisi daftar kill ponsel.
    // Kalau modul lain memanggil helper Phone* saat ponsel tertutup,
    // textdrawnya bocor (tidak pernah dibunuh) dan daftar ini penuh.
    if (!gPhoneOpen[playerid]) {
        Log_Warn("ui", "PhoneTrack ditolak: ponsel tidak terbuka");
        return 0;
    }
    if (gPhoneDrawList[playerid] == PHONE_SCREEN_HOME) {
        if (gPhoneHomeCount[playerid] >= PHONE_HOME_MAX_TD) {
            Log_Warn("ui", "daftar home ponsel penuh");
            return 0;
        }
        gPhoneHomeTd[playerid][gPhoneHomeCount[playerid]++] = handle;
        return 1;
    }
    if (gPhoneSetCount[playerid] >= PHONE_SET_MAX_TD) {
        Log_Warn("ui", "daftar settings ponsel penuh");
        return 0;
    }
    gPhoneSetTd[playerid][gPhoneSetCount[playerid]++] = handle;
    return 1;
}

stock PhoneUI_SetValHandle(playerid, slot, PlayerText:handle) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (slot == PHONEUI_ID_SET_SKIN) gPhoneValSkin[playerid] = handle;
    if (slot == PHONEUI_ID_SET_TOAST) gPhoneValToast[playerid] = handle;
    return 1;
}

// Baca preferensi dari DB (dipanggil sekali saat ponsel dibuka).
static PhoneUI_LoadPrefs(playerid) {
    gPhoneStyle[playerid] = PHONE_SKIN_IPHONE;
    gPhoneToastOn[playerid] = true;
    new characterId = Character_GetId(playerid);
    if (characterId < 1) return 0;

    new query[128];
    format(query, sizeof (query),
        "SELECT phone_style FROM characters WHERE character_id = %d",
        characterId);
    gPhoneStyle[playerid] = DB_Int(query, PHONE_SKIN_IPHONE);

    format(query, sizeof (query),
        "SELECT toast_on FROM characters WHERE character_id = %d",
        characterId);
    gPhoneToastOn[playerid] = DB_Int(query, 1) != 0;
    Toast_SetEnabled(playerid, gPhoneToastOn[playerid]);
    return 1;
}

static PhoneUI_SavePrefs(playerid) {
    new characterId = Character_GetId(playerid);
    if (characterId < 1) return 0;
    new query[160];
    format(query, sizeof (query),
        "UPDATE characters SET phone_style = %d, toast_on = %d WHERE character_id = %d",
        gPhoneStyle[playerid], gPhoneToastOn[playerid] ? 1 : 0, characterId);
    return DB_Exec(query);
}

// Pindah layar = sembunyikan satu daftar, tampilkan daftar lain (murah,
// tanpa destroy -> aman dipanggil dari callback klik Android).
stock PhoneUI_ShowScreen(playerid, screen) {
    if (!gPhoneOpen[playerid]) return 0;
    gPhoneScreen[playerid] = screen;

    if (screen == PHONE_SCREEN_SETTINGS) {
        for (new index = 0; index < gPhoneHomeCount[playerid]; index++) {
            PlayerTextDrawHide(playerid, gPhoneHomeTd[playerid][index]);
        }
        for (new index = 0; index < gPhoneSetCount[playerid]; index++) {
            PlayerTextDrawShow(playerid, gPhoneSetTd[playerid][index]);
        }
        return 1;
    }
    for (new index = 0; index < gPhoneSetCount[playerid]; index++) {
        PlayerTextDrawHide(playerid, gPhoneSetTd[playerid][index]);
    }
    for (new index = 0; index < gPhoneHomeCount[playerid]; index++) {
        PlayerTextDrawShow(playerid, gPhoneHomeTd[playerid][index]);
    }
    return 1;
}

stock bool:PhoneUI_Open(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (!Phase_CanAct(playerid)) return false;
    if (gPhoneOpen[playerid]) PhoneUI_Destroy(playerid);
    if (!UIModal_Open(playerid, UI_PHONE)) return false;

    PhoneUI_LoadPrefs(playerid);
    gPhonePendingHome[playerid] = false;
    PhoneUI_BeginDraw(playerid, PHONE_SCREEN_HOME);
    PhoneDraw_Home(playerid);
    PhoneUI_BeginDraw(playerid, PHONE_SCREEN_SETTINGS);
    PhoneDraw_Settings(playerid);
    PhoneUI_ShowScreen(playerid, PHONE_SCREEN_HOME);

    gPhoneOpen[playerid] = true;
    SelectTextDraw(playerid, THEME_ACCENT);
    return true;
}

// Hancurkan semua textdraw kedua layar (Hide dulu, aturan Android).
stock PhoneUI_Destroy(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gPhoneOpen[playerid]) return 0;

    CancelSelectTextDraw(playerid);
    for (new index = 0; index < gPhoneHomeCount[playerid]; index++) {
        TrxTd_Kill(playerid, gPhoneHomeTd[playerid][index]);
    }
    for (new index = 0; index < gPhoneSetCount[playerid]; index++) {
        TrxTd_Kill(playerid, gPhoneSetTd[playerid][index]);
    }
    gPhoneHomeCount[playerid] = 0;
    gPhoneSetCount[playerid] = 0;
    gPhoneOpen[playerid] = false;
    gPhonePendingHome[playerid] = false;
    gPhoneClockTd[playerid] = PlayerText:INVALID_TEXT_DRAW;
    gPhoneWidgetClockTd[playerid] = PlayerText:INVALID_TEXT_DRAW;
    return 1;
}

// Tick 500 ms: terapkan rebuild home yang ditunda (ganti skin).
stock PhoneUI_Tick() {
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) {
            continue;
        }
        if (gPhoneOpen[playerid] && gPhonePendingHome[playerid]) {
            gPhonePendingHome[playerid] = false;
            for (new index = 0; index < gPhoneHomeCount[playerid]; index++) {
                TrxTd_Kill(playerid, gPhoneHomeTd[playerid][index]);
            }
            gPhoneHomeCount[playerid] = 0;
            PhoneUI_BeginDraw(playerid, PHONE_SCREEN_HOME);
            PhoneDraw_Home(playerid);
            PhoneUI_ShowScreen(playerid, PHONE_SCREEN_HOME);
        }

        // Jam ponsel hidup: perbarui status bar + widget tiap 500ms saat home
        // terbuka (SetString + Show, tanpa redraw penuh).
        if (gPhoneOpen[playerid] && gPhoneScreen[playerid] == PHONE_SCREEN_HOME
            && gPhoneWidgetClockTd[playerid] != PlayerText:INVALID_TEXT_DRAW) {
            new hours, minutes, clockText[8];
            gettime(hours, minutes);
            format(clockText, sizeof (clockText), "%02d:%02d", hours, minutes);
            PlayerTextDrawSetString(playerid, gPhoneWidgetClockTd[playerid],
                clockText);
            PlayerTextDrawShow(playerid, gPhoneWidgetClockTd[playerid]);
            if (gPhoneClockTd[playerid] != PlayerText:INVALID_TEXT_DRAW) {
                PlayerTextDrawSetString(playerid, gPhoneClockTd[playerid],
                    clockText);
                PlayerTextDrawShow(playerid, gPhoneClockTd[playerid]);
            }
        }
    }
    return 1;
}

stock bool:PhoneUI_OnClick(playerid, PlayerText:clicked) {
    if (!gPhoneOpen[playerid]) return false;

    new action = TrxTd_ResolveClick(playerid, clicked);
    switch (action) {
        case PHONEUI_ID_CLOSE: {
            UIModal_Close(playerid);
            return true;
        }
        case PHONEUI_ID_BANK: {
            // UIModal_Open di dalam BankUI otomatis menutup phone modal.
            return BankUI_OpenPhone(playerid);
        }
        case PHONEUI_ID_KTP: {
            UIModal_Close(playerid);
            Identity_ShowOwnKTP(playerid);
            return true;
        }
        case PHONEUI_ID_KERJA: {
            UIModal_Close(playerid);
            World_ShowJobStatus(playerid);
            return true;
        }
        case PHONEUI_ID_SETTINGS: {
            PhoneUI_ShowScreen(playerid, PHONE_SCREEN_SETTINGS);
            return true;
        }
        case PHONEUI_ID_BACK: {
            // Skin baru butuh rebuild home -> tunda ke tick (bukan di callback).
            if (gPhonePendingHome[playerid]) return true;
            PhoneUI_ShowScreen(playerid, PHONE_SCREEN_HOME);
            return true;
        }
        case PHONEUI_ID_SET_SKIN: {
            new newStyle = (gPhoneStyle[playerid] == PHONE_SKIN_IPHONE)
                ? PHONE_SKIN_SAMSUNG : PHONE_SKIN_IPHONE;
            gPhoneStyle[playerid] = newStyle;
            PhoneUI_SavePrefs(playerid);
            gPhonePendingHome[playerid] = true;
            if (gPhoneValSkin[playerid] != PlayerText:0) {
                new label[16];
                format(label, sizeof (label), "%s",
                    (newStyle == PHONE_SKIN_SAMSUNG) ? "Samsung" : "iPhone");
                PlayerTextDrawSetString(playerid, gPhoneValSkin[playerid], label);
                PlayerTextDrawShow(playerid, gPhoneValSkin[playerid]);
            }
            return true;
        }
        case PHONEUI_ID_SET_TOAST: {
            gPhoneToastOn[playerid] = !gPhoneToastOn[playerid];
            Toast_SetEnabled(playerid, gPhoneToastOn[playerid]);
            PhoneUI_SavePrefs(playerid);
            if (gPhoneValToast[playerid] != PlayerText:0) {
                PlayerTextDrawSetString(playerid, gPhoneValToast[playerid],
                    gPhoneToastOn[playerid] ? "AKTIF" : "MATI");
                PlayerTextDrawShow(playerid, gPhoneValToast[playerid]);
            }
            return true;
        }
    }
    return false;
}
