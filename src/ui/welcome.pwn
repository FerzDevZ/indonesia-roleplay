// ---------------------------------------------------------------------------
// module      : ui/welcome
// entry       : UI_Boot() (latar global dibuat sekali)
// depends     : ui/theme, ui/trxtdraw, core/log
// owns tables : -
// public api  : UI_Boot(), Welcome_Show(), Welcome_SetHint(), Welcome_Hide()
// Tampilan    : layar masuk bergaya FiveM/GTA V - artwork loading screen GTA
//               sebagai latar, lapisan gelap, lalu KARTU KACA rounded di tengah
//               layar (border rambut putih 11%) berisi kicker Bank Gothic,
//               wordmark Pricedown dua baris (putih + merah bata), garis aksen,
//               tagline, dan hint fase di dasar kartu. Semua kartu digambar
//               lewat engine trxtdraw (koreksi aspek 16:9, tanpa outline tebal).
// ---------------------------------------------------------------------------
#if defined _INC_UI_WELCOME
    #endinput
#endif
#define _INC_UI_WELCOME

#include "theme.pwn"
#include "trxtdraw.pwn"

#define WCARD_W         (380.0)
#define WCARD_H         (230.0)
#define WCARD_X         ((640.0 - WCARD_W) / 2.0)
#define WCARD_Y         ((480.0 - WCARD_H) / 2.0)

static Text:gBgSprite = Text:INVALID_TEXT_DRAW;
static Text:gOverlay = Text:INVALID_TEXT_DRAW;
static Text:gFootLeft = Text:INVALID_TEXT_DRAW;

static PlayerText:gWShadow[MAX_PLAYERS][6];
static PlayerText:gWCardLine[MAX_PLAYERS][6];
static PlayerText:gWCard[MAX_PLAYERS][6];
static PlayerText:gWKicker[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static PlayerText:gWTitle1[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static PlayerText:gWAccent[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static PlayerText:gWTagline[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static PlayerText:gWHint[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static bool:gWelcomeShown[MAX_PLAYERS];

stock UI_Boot() {
    // Latar: artwork loading screen GTA SA. Dibuat paling awal supaya berada
    // di lapisan paling bawah (textdraw digambar berurutan sesuai pembuatan).
    gBgSprite = TextDrawCreate(0.0, 0.0, THEME_BG_SPRITE);
    TextDrawFont(gBgSprite, THEME_FONT_SPRITE);
    TextDrawTextSize(gBgSprite, THEME_SCREEN_W, THEME_SCREEN_H);
    TextDrawColour(gBgSprite, THEME_WHITE);

    // Lapisan gelap agar teks selalu terbaca di atas artwork.
    gOverlay = TextDrawCreate(0.0, 0.0, "_");
    TextDrawUseBox(gOverlay, true);
    TextDrawBoxColour(gOverlay, THEME_OVERLAY);
    TextDrawLetterSize(gOverlay, 0.0, Theme_BoxHeight(THEME_SCREEN_H));
    TextDrawTextSize(gOverlay, THEME_SCREEN_W, 0.0);

    gFootLeft = TextDrawCreate(320.0, 458.0,
        "OPEN.MP 1.6  -  0.3.7 / 0.3.DL  -  100.122.225.77:7777");
    TextDrawAlignment(gFootLeft, TEXT_DRAW_ALIGN_CENTER);
    TextDrawFont(gFootLeft, THEME_FONT_BODY);
    TextDrawLetterSize(gFootLeft, 0.2, 1.0);
    TextDrawColour(gFootLeft, THEME_MUTED);
    TextDrawSetOutline(gFootLeft, 1);

    Log_Info("ui", "layar masuk kartu kaca FiveM siap");
    return 1;
}

stock Welcome_Show(playerid, const hint[] = "MASUK UNTUK MELANJUTKAN") {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gWelcomeShown[playerid]) return 1;

    TextDrawShowForPlayer(playerid, gBgSprite);
    TextDrawShowForPlayer(playerid, gOverlay);
    TextDrawShowForPlayer(playerid, gFootLeft);

    // Bayangan + border rambut putih + kartu kaca (depth ala TrxTd_Panel).
    TrxTd_RoundedCard(playerid, gWShadow[playerid],
        WCARD_X + 3.0, WCARD_Y + 3.0, WCARD_W, WCARD_H, 10.0, THEME_SHADOW);
    TrxTd_RoundedCard(playerid, gWCardLine[playerid],
        WCARD_X - 2.0, WCARD_Y - 2.0, WCARD_W + 4.0, WCARD_H + 4.0, 12.0, THEME_BORDER);
    TrxTd_RoundedCard(playerid, gWCard[playerid],
        WCARD_X, WCARD_Y, WCARD_W, WCARD_H, 10.0, THEME_GLASS);

    // Isi kartu: hierarki tipografi ala layar muat GTA V - label kecil,
    // SATU kata dominan, garis aksen, tagline, hint di dasar kartu.
    gWKicker[playerid] = TrxTd_Text(playerid, 320.0, WCARD_Y + 20.0,
        "R O L E P L A Y", THEME_FONT_LABEL, 0.20, 0.90, THEME_ACCENT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    gWTitle1[playerid] = TrxTd_Text(playerid, 320.0, WCARD_Y + 40.0,
        "INDONESIA", THEME_FONT_TITLE, 0.62, 2.30, THEME_TEXT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    gWAccent[playerid] = TrxTd_Sprite(playerid, 320.0 - 40.0, WCARD_Y + 104.0,
        THEME_SPRITE_WHITE, 80.0, 3.0, THEME_ACCENT);
    gWTagline[playerid] = TrxTd_Text(playerid, 320.0, WCARD_Y + 116.0,
        "SERIUS  -  REALISTIS  -  BERBAHASA INDONESIA", THEME_FONT_LABEL,
        0.19, 0.85, THEME_MUTED, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    TrxTd_Sprite(playerid, 320.0 - 150.0, WCARD_Y + 152.0,
        THEME_SPRITE_WHITE, 300.0, 1.0, THEME_BORDER); // garis pemisah halus
    gWHint[playerid] = TrxTd_Text(playerid, 320.0, WCARD_Y + 168.0,
        hint, THEME_FONT_LABEL, 0.26, 1.00, THEME_TEXT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);

    gWelcomeShown[playerid] = true;
    return 1;
}

// Hint fase berubah: "MASUK UNTUK MELANJUTKAN" -> "PILIH KARAKTER KAMU", dst.
stock Welcome_SetHint(playerid, const hint[]) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gWelcomeShown[playerid]) return 0;
    PlayerTextDrawSetString(playerid, gWHint[playerid], hint);
    return 1;
}

stock Welcome_Hide(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gWelcomeShown[playerid]) return 0;

    TrxTd_Kill(playerid, gWHint[playerid]);
    TrxTd_Kill(playerid, gWTagline[playerid]);
    TrxTd_Kill(playerid, gWAccent[playerid]);
    TrxTd_Kill(playerid, gWTitle1[playerid]);
    TrxTd_Kill(playerid, gWKicker[playerid]);
    TrxTd_KillCard(playerid, gWCard[playerid]);
    TrxTd_KillCard(playerid, gWCardLine[playerid]);
    TrxTd_KillCard(playerid, gWShadow[playerid]);

    TextDrawHideForPlayer(playerid, gBgSprite);
    TextDrawHideForPlayer(playerid, gOverlay);
    TextDrawHideForPlayer(playerid, gFootLeft);

    gWelcomeShown[playerid] = false;
    return 1;
}
