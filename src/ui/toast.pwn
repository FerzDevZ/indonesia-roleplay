// ---------------------------------------------------------------------------
// module      : ui/toast
// entry       : -
// depends     : ui/theme, ui/trxtdraw, core/log
// owns tables : -
// public api  : Toast_Show(), Toast_Tick(), Toast_ClearAll()
// Tampilan    : notifikasi gaya ox_lib/FiveM di kanan-atas: kartu kaca gelap,
//               bilah aksen tipis di tepi kiri, judul Bank Gothic + isi normal.
//               Maksimal 3 slot per pemain; slot terlama diganti bila penuh.
//               Kadaluarsa dicek Timer_OnToastTick (1 detik) lalu dihancurkan.
// ---------------------------------------------------------------------------
#if defined _INC_UI_TOAST
    #endinput
#endif
#define _INC_UI_TOAST

#include "theme.pwn"
#include "trxtdraw.pwn"

#define TOAST_SLOTS     (3)
#define TOAST_W         (150.0)
#define TOAST_H         (30.0)
#define TOAST_X         (474.0)
#define TOAST_Y         (20.0)
#define TOAST_STEP      (36.0)
#define TOAST_LIFE      (4)         // detik tayang
#define TOAST_PAD_X     (10.0)

static PlayerText:gToastCard[MAX_PLAYERS][TOAST_SLOTS];
static PlayerText:gToastBar[MAX_PLAYERS][TOAST_SLOTS];
static PlayerText:gToastTitle[MAX_PLAYERS][TOAST_SLOTS];
static PlayerText:gToastBody[MAX_PLAYERS][TOAST_SLOTS];
static bool:gToastAlive[MAX_PLAYERS][TOAST_SLOTS];
static gToastExpire[MAX_PLAYERS][TOAST_SLOTS];
static gToastSlide[MAX_PLAYERS][TOAST_SLOTS];   // sisa langkah animasi masuk
static bool:gToastEnabled[MAX_PLAYERS] = { true, ... };

static Toast_DestroySlot(playerid, slot) {
    TrxTd_Kill(playerid, gToastBody[playerid][slot]);
    TrxTd_Kill(playerid, gToastTitle[playerid][slot]);
    TrxTd_Kill(playerid, gToastBar[playerid][slot]);
    TrxTd_Kill(playerid, gToastCard[playerid][slot]);
    gToastAlive[playerid][slot] = false;
    gToastSlide[playerid][slot] = 0;
    return 1;
}

stock Toast_ClearAll(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    for (new slot = 0; slot < TOAST_SLOTS; slot++) {
        if (gToastAlive[playerid][slot]) Toast_DestroySlot(playerid, slot);
    }
    return 1;
}

// Preferensi notifikasi (diatur lewat aplikasi Pengaturan ponsel).
// Reset hanya saat disconnect - jangan dipanggil saat spawn.
stock Toast_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gToastEnabled[playerid] = true;
    return Toast_ClearAll(playerid);
}

stock Toast_SetEnabled(playerid, bool:enabled) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gToastEnabled[playerid] = enabled;
    return 1;
}

stock bool:Toast_IsEnabled(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return true;
    return gToastEnabled[playerid];
}

// Tampilkan toast. Warna aksen menentukan makna: THEME_OK / THEME_INFO /
// THEME_WARN / THEME_DANGER / THEME_ACCENT.
stock Toast_Show(playerid, const title[], const body[], color = THEME_ACCENT) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!IsPlayerConnected(playerid)) return 0;
    if (!gToastEnabled[playerid]) return 0;

    // Cari slot kosong; kalau penuh, ganti slot yang paling cepat kadaluarsa.
    new slot = -1, oldestExpire = 0x7FFFFFFF, oldestSlot = 0;
    for (new index = 0; index < TOAST_SLOTS; index++) {
        if (!gToastAlive[playerid][index]) {
            slot = index;
            break;
        }
        if (gToastExpire[playerid][index] < oldestExpire) {
            oldestExpire = gToastExpire[playerid][index];
            oldestSlot = index;
        }
    }
    if (slot == -1) {
        slot = oldestSlot;
        Toast_DestroySlot(playerid, slot);
    }

    new Float:y = TOAST_Y + TOAST_STEP * slot;
    // Animasi masuk: kartu muncul dari kanan (+12px) lalu meluncur ke posisi
    // final lewat Toast_Animate (3 langkah @500ms, gaya notifikasi FiveM).
    new Float:startX = TOAST_X + 12.0;
    gToastCard[playerid][slot] = TrxTd_Sprite(playerid, startX, y,
        THEME_SPRITE_WHITE, TOAST_W, TOAST_H, THEME_GLASS);
    gToastBar[playerid][slot] = TrxTd_Sprite(playerid, startX, y,
        THEME_SPRITE_WHITE, 3.0, TOAST_H, color);
    gToastTitle[playerid][slot] = TrxTd_Text(playerid, startX + TOAST_PAD_X, y + 4.0,
        title, THEME_FONT_LABEL, 0.16, 0.75, THEME_TEXT);
    gToastBody[playerid][slot] = TrxTd_Text(playerid, startX + TOAST_PAD_X, y + 15.0,
        body, THEME_FONT_BODY, 0.15, 0.70, THEME_MUTED);

    gToastAlive[playerid][slot] = true;
    gToastExpire[playerid][slot] = gettime() + TOAST_LIFE;
    gToastSlide[playerid][slot] = 3;
    return 1;
}

// Animasi slide-in toast: dipanggil tiap 500ms dari Timer_OnPromptTick.
// Geser posisi ke kiri 4px per langkah sampai posisi final (slide = 0).
stock Toast_Animate() {
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;
        for (new slot = 0; slot < TOAST_SLOTS; slot++) {
            if (!gToastAlive[playerid][slot] || gToastSlide[playerid][slot] <= 0) {
                continue;
            }
            gToastSlide[playerid][slot]--;
            new Float:offset = 4.0 * float(gToastSlide[playerid][slot]);
            new Float:y = TOAST_Y + TOAST_STEP * slot;
            PlayerTextDrawSetPos(playerid, gToastCard[playerid][slot],
                TOAST_X + offset, y);
            PlayerTextDrawSetPos(playerid, gToastBar[playerid][slot],
                TOAST_X + offset, y);
            PlayerTextDrawSetPos(playerid, gToastTitle[playerid][slot],
                TOAST_X + offset + TOAST_PAD_X, y + 4.0);
            PlayerTextDrawSetPos(playerid, gToastBody[playerid][slot],
                TOAST_X + offset + TOAST_PAD_X, y + 15.0);
            PlayerTextDrawShow(playerid, gToastCard[playerid][slot]);
            PlayerTextDrawShow(playerid, gToastBar[playerid][slot]);
            PlayerTextDrawShow(playerid, gToastTitle[playerid][slot]);
            PlayerTextDrawShow(playerid, gToastBody[playerid][slot]);
        }
    }
    return 1;
}

// Dipanggil tiap detik lewat Timer_OnToastTick.
stock Toast_Tick() {
    new now = gettime();
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;
        for (new slot = 0; slot < TOAST_SLOTS; slot++) {
            if (gToastAlive[playerid][slot] && now >= gToastExpire[playerid][slot]) {
                Toast_DestroySlot(playerid, slot);
            }
        }
    }
    return 1;
}
