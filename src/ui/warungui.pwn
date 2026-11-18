// ---------------------------------------------------------------------------
// module      : ui/warungui
// entry       : -
// depends     : ui/theme, ui/trxtdraw, ui/uimodal, ui/toast,
//               domain/warung (Warung_Buy + akses baca), shared/money
// owns tables : daftar kill textdraw toko, handle kartu item
// public api  : WarungUI_Open(), WarungUI_Destroy(), WarungUI_IsOpen(),
//               WarungUI_OnClick(), WarungUI_TrackHandle(),
//               WarungUI_SetCardHandles(), WarungUI_Refresh()
// Isi         : Toko warung gaya e-commerce FiveM (ref: FiveM Market Shop
//               UI, AP5-Shops, Yuri Shops UI): panel gelap, kartu item
//               2 kolom (chip glyph + nama + harga), footer saldo tunai
//               live. Klik kartu = beli 1 (quick-buy), saldo footer ikut
//               bergerak via update-in-place.
// Aturan      : Hitbox kartu digambar SEBELUM konten; [X] wajib; semua
//               textdraw masuk kill list; tanpa warna literal.
// ---------------------------------------------------------------------------
#if defined _INC_UI_WARUNGUI
    #endinput
#endif
#define _INC_UI_WARUNGUI

#include "theme.pwn"
#include "trxtdraw.pwn"
#include "uimodal.pwn"

// Id klik toko (kartu item 0-7 = 301-308).
#define SHOPUI_ID_ROW0      (301)
#define SHOPUI_ID_CLOSE     (309)

#define SHOPUI_MAX_TD       (80)
#define SHOPUI_MAX_ROWS     (8)

static bool:gShopOpen[MAX_PLAYERS];
static gShopWarung[MAX_PLAYERS] = { -1, ... };

static PlayerText:gShopTd[MAX_PLAYERS][SHOPUI_MAX_TD];
static gShopTdCount[MAX_PLAYERS];

// Handle kartu item untuk refresh update-in-place (kartu, chip, nama, harga).
static PlayerText:gShopCard[MAX_PLAYERS][SHOPUI_MAX_ROWS];
static PlayerText:gShopChip[MAX_PLAYERS][SHOPUI_MAX_ROWS];
static PlayerText:gShopName[MAX_PLAYERS][SHOPUI_MAX_ROWS];
static PlayerText:gShopPrice[MAX_PLAYERS][SHOPUI_MAX_ROWS];

static PlayerText:gShopCashTd[MAX_PLAYERS];

stock WarungUI_TrackHandle(playerid, PlayerText:handle) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gShopTdCount[playerid] >= SHOPUI_MAX_TD) {
        Log_Warn("ui", "daftar toko penuh");
        return 0;
    }
    gShopTd[playerid][gShopTdCount[playerid]++] = handle;
    return 1;
}

stock WarungUI_SetCardHandles(playerid, slot, PlayerText:card,
    PlayerText:chip, PlayerText:name, PlayerText:price) {
    if (slot < 0 || slot >= SHOPUI_MAX_ROWS) return 0;
    gShopCard[playerid][slot] = card;
    gShopChip[playerid][slot] = chip;
    gShopName[playerid][slot] = name;
    gShopPrice[playerid][slot] = price;
    return 1;
}

stock WarungUI_SetCashHandle(playerid, PlayerText:cashTd) {
    gShopCashTd[playerid] = cashTd;
    return 1;
}

// Isi kartu slot (chip + nama + harga) dari luar file draw.
stock WarungUI_SetCardText(playerid, slot, const glyph[], glyphColor,
    const name[], const price[]) {
    if (slot < 0 || slot >= SHOPUI_MAX_ROWS) return 0;
    PlayerTextDrawSetString(playerid, gShopChip[playerid][slot], glyph);
    PlayerTextDrawColour(playerid, gShopChip[playerid][slot], glyphColor);
    PlayerTextDrawShow(playerid, gShopChip[playerid][slot]);
    PlayerTextDrawSetString(playerid, gShopName[playerid][slot], name);
    PlayerTextDrawShow(playerid, gShopName[playerid][slot]);
    PlayerTextDrawSetString(playerid, gShopPrice[playerid][slot], price);
    PlayerTextDrawShow(playerid, gShopPrice[playerid][slot]);
    return 1;
}

stock bool:WarungUI_IsOpen(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gShopOpen[playerid];
}

// Segarkan saldo tunai di footer (update-in-place, dipanggil setelah beli).
stock WarungUI_Refresh(playerid) {
    if (!gShopOpen[playerid]) return 0;

    new cashText[32];
    Messages_Money(Money_GetCash(playerid), cashText, sizeof (cashText));
    new footer[48];
    format(footer, sizeof (footer), "TUNAI %s", cashText);
    PlayerTextDrawSetString(playerid, gShopCashTd[playerid], footer);
    PlayerTextDrawShow(playerid, gShopCashTd[playerid]);
    return 1;
}

stock bool:WarungUI_Open(playerid, warung) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (Character_GetId(playerid) < 1) return false;
    if (warung < 0) return false;
    if (gShopOpen[playerid]) return true;

    if (!UIModal_Open(playerid, UI_WARUNG)) return false;
    gShopOpen[playerid] = true;
    gShopWarung[playerid] = warung;

    WarungDraw_Shop(playerid, warung);
    WarungUI_Refresh(playerid);
    SelectTextDraw(playerid, THEME_ACCENT);
    return true;
}

stock WarungUI_Destroy(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gShopOpen[playerid] && gShopTdCount[playerid] == 0) return 0;

    for (new index = 0; index < gShopTdCount[playerid]; index++) {
        TrxTd_Kill(playerid, gShopTd[playerid][index]);
    }
    gShopTdCount[playerid] = 0;
    gShopOpen[playerid] = false;
    gShopWarung[playerid] = -1;
    CancelSelectTextDraw(playerid);
    return 1;
}

stock bool:WarungUI_OnClick(playerid, PlayerText:clicked) {
    if (!gShopOpen[playerid]) return false;

    new action = TrxTd_ResolveClick(playerid, clicked);
    if (action >= SHOPUI_ID_ROW0 && action < SHOPUI_ID_ROW0 + SHOPUI_MAX_ROWS) {
        Warung_Buy(playerid, gShopWarung[playerid],
            action - SHOPUI_ID_ROW0);
        WarungUI_Refresh(playerid);
        return true;
    }
    if (action == SHOPUI_ID_CLOSE) {
        UIModal_Close(playerid);
        return true;
    }
    return false;
}
