// ---------------------------------------------------------------------------
// module      : ui/charselect
// entry       : CharSelect_Show() / CharSelect_Hide() / CharSelect_Destroy()
// depends     : ui/theme, ui/trxtdraw, core/log
// owns tables : -
// public api  : CharSelect_Show(), CharSelect_Hide(), CharSelect_Destroy(),
//               CharSelect_RowSlot(), CharSelect_IsCreate(), CharSelect_IsOpen()
// Tampilan    : panel kiri bergaya FiveM: kartu rounded gelap + strip header
//               merah bata rounded, daftar slot sebagai tombol sprite penuh
//               lebar (hitbox akurat, label overlay di tengah, kursor aktif
//               lewat SelectTextDraw). Logika pemilihan tetap milik
//               domain/character; modul ini hanya menggambar dan meneruskan
//               id textdraw yang diklik.
// ---------------------------------------------------------------------------
#if defined _INC_UI_CHARSELECT
    #endinput
#endif
#define _INC_UI_CHARSELECT

#include "theme.pwn"
#include "trxtdraw.pwn"

#define CS_PANEL_X      (24.0)
#define CS_PANEL_Y      (118.0)
#define CS_PANEL_W      (280.0)
#define CS_PANEL_H      (200.0)
#define CS_ROW_X        (CS_PANEL_X + 12.0)
#define CS_ROW_W        (CS_PANEL_W - 24.0)
#define CS_ROW_H        (26.0)
#define CS_ROW_STEP     (34.0)
#define CS_ROW_Y        (CS_PANEL_Y + 46.0)
#define CS_CREATE_Y     (CS_ROW_Y + CS_ROW_STEP * MAX_CHAR_SLOTS + 6.0)

static PlayerText:gCsPanel[MAX_PLAYERS][TRX_PANEL_MAX_TD];
static gCsPanelCount[MAX_PLAYERS];
static PlayerText:gCsRow[MAX_PLAYERS][MAX_CHAR_SLOTS];
static PlayerText:gCsRowLabel[MAX_PLAYERS][MAX_CHAR_SLOTS];
static PlayerText:gCsCreate[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static PlayerText:gCsCreateLabel[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static bool:gCsOpen[MAX_PLAYERS];
static bool:gCsRowAlive[MAX_PLAYERS][MAX_CHAR_SLOTS];
static bool:gCsCreateAlive[MAX_PLAYERS];

stock bool:CharSelect_IsOpen(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gCsOpen[playerid];
}

// -1 = bukan baris slot; 0..MAX_CHAR_SLOTS-1 = nomor slot yang diklik.
stock CharSelect_RowSlot(playerid, PlayerText:clicked) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    for (new slot = 0; slot < MAX_CHAR_SLOTS; slot++) {
        if (gCsRowAlive[playerid][slot] && clicked == gCsRow[playerid][slot]) {
            return slot;
        }
    }
    return -1;
}

stock bool:CharSelect_IsCreate(playerid, PlayerText:clicked) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gCsCreateAlive[playerid] && clicked == gCsCreate[playerid];
}

static CharSelect_DrawFrame(playerid) {
    // Panel modal FiveM standar: bayangan + garis rambut + kaca + judul
    // uppercase + garis aksen merah bata. Tanpa [X] (layar pre-login).
    new PlayerText:closeBtn = PlayerText:0, PlayerText:closeLbl = PlayerText:0;
    gCsPanelCount[playerid] = TrxTd_Panel(playerid, gCsPanel[playerid],
        CS_PANEL_X, CS_PANEL_Y, CS_PANEL_W, CS_PANEL_H, "PILIH KARAKTER",
        -1, closeBtn, closeLbl);
    return 1;
}

// Data slot diambil pemanggil (domain/character) sebelum show.
stock CharSelect_Show(playerid, const names[][MAX_USERNAME_LENGTH + 1],
    const hours[][16], const bool:slotAlive[], bool:createEnabled) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gCsOpen[playerid]) CharSelect_Destroy(playerid);

    CharSelect_DrawFrame(playerid);

    new label[96];
    new Float:rowY = 0.0;
    for (new slot = 0; slot < MAX_CHAR_SLOTS; slot++) {
        rowY = CS_ROW_Y + CS_ROW_STEP * slot;
        if (slotAlive[slot]) {
            format(label, sizeof (label), "%d.  %s   -   %s jam", slot + 1,
                names[slot], hours[slot]);
            gCsRow[playerid][slot] = TrxTd_Button(playerid, gCsRowLabel[playerid][slot],
                CS_ROW_X, rowY, CS_ROW_W, CS_ROW_H, label,
                THEME_ELEVATED, THEME_TEXT, 0.20, 0.85,
                TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
        } else {
            format(label, sizeof (label), "%d.  ( slot kosong )", slot + 1);
            gCsRow[playerid][slot] = TrxTd_Button(playerid, gCsRowLabel[playerid][slot],
                CS_ROW_X, rowY, CS_ROW_W, CS_ROW_H, label,
                THEME_GLASS, THEME_MUTED, 0.20, 0.85,
                TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
        }
        gCsRowAlive[playerid][slot] = slotAlive[slot];
    }

    // Tombol buat karakter: latar kaca, label dengan aksen merah.
    format(label, sizeof (label), "+  BUAT KARAKTER BARU");
    gCsCreate[playerid] = TrxTd_Button(playerid, gCsCreateLabel[playerid],
        CS_ROW_X, CS_CREATE_Y, CS_ROW_W, CS_ROW_H, label,
        THEME_GLASS, THEME_TEXT, 0.20, 0.85,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gCsCreateAlive[playerid] = createEnabled;

    gCsOpen[playerid] = true;
    SelectTextDraw(playerid, THEME_ACCENT);
    return 1;
}

stock CharSelect_Hide(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gCsOpen[playerid]) return 0;

    CancelSelectTextDraw(playerid);
    CharSelect_Destroy(playerid);
    return 1;
}

stock CharSelect_Destroy(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gCsOpen[playerid]) return 0;

    for (new index = 0; index < gCsPanelCount[playerid]; index++) {
        TrxTd_Kill(playerid, gCsPanel[playerid][index]);
    }
    gCsPanelCount[playerid] = 0;
    for (new slot = 0; slot < MAX_CHAR_SLOTS; slot++) {
        TrxTd_Kill(playerid, gCsRowLabel[playerid][slot]);
        TrxTd_Kill(playerid, gCsRow[playerid][slot]);
        gCsRowAlive[playerid][slot] = false;
    }
    TrxTd_Kill(playerid, gCsCreateLabel[playerid]);
    TrxTd_Kill(playerid, gCsCreate[playerid]);
    gCsCreateAlive[playerid] = false;
    gCsOpen[playerid] = false;
    return 1;
}
