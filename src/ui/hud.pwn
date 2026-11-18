// ---------------------------------------------------------------------------
// module      : ui/hud
// entry       : HUD_Show() / HUD_Tick() / HUD_Destroy()
// depends     : ui/theme, shared/money, core/log, core/timer
// owns tables : -
// public api  : HUD_Show(), HUD_Destroy(), HUD_Tick()
// Tampilan    : HUD kanan-atas bergaya modern: saldo rupiah (font tebal),
//               jam WIB di bawahnya, dan tanda server kecil di kiri-bawah.
//               Diperbarui tiap detik lewat Timer_OnHudTick.
// ---------------------------------------------------------------------------
#if defined _INC_UI_HUD
    #endinput
#endif
#define _INC_UI_HUD

#include "theme.pwn"

static PlayerText:gHudMoney[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static PlayerText:gHudClock[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static PlayerText:gHudTag[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
static bool:gHudActive[MAX_PLAYERS];

// Tween uang: angka HUD bergerak halus menuju nilai asli (25% per detik),
// hijau saat naik, merah saat turun, putih saat tenang. Terasa "hidup".
static gHudShownCash[MAX_PLAYERS];

static HUD_FormatClock(dest[], maxlength) {
    // WIB = UTC+7. gettime() mengembalikan unix epoch UTC.
    new stamp = gettime() + (7 * 3600);
    new hour = (stamp / 3600) % 24;
    new minute = (stamp / 60) % 60;
    return format(dest, maxlength, "~l~%02d:%02d ~w~WIB", hour, minute);
}

static HUD_CreateDraws(playerid) {
    gHudMoney[playerid] = CreatePlayerTextDraw(playerid, 628.0, 22.0, "Rp 0");
    PlayerTextDrawAlignment(playerid, gHudMoney[playerid], TEXT_DRAW_ALIGN_RIGHT); // kanan
    PlayerTextDrawFont(playerid, gHudMoney[playerid], THEME_FONT_TITLE);
    PlayerTextDrawLetterSize(playerid, gHudMoney[playerid], 0.36, 1.7);
    PlayerTextDrawColour(playerid, gHudMoney[playerid], THEME_TEXT);
    PlayerTextDrawSetOutline(playerid, gHudMoney[playerid], 1);
    PlayerTextDrawSetShadow(playerid, gHudMoney[playerid], 1);

    gHudClock[playerid] = CreatePlayerTextDraw(playerid, 628.0, 48.0, "~l~00:00 ~w~WIB");
    PlayerTextDrawAlignment(playerid, gHudClock[playerid], TEXT_DRAW_ALIGN_RIGHT);
    PlayerTextDrawFont(playerid, gHudClock[playerid], THEME_FONT_BODY);
    PlayerTextDrawLetterSize(playerid, gHudClock[playerid], 0.24, 1.2);
    PlayerTextDrawColour(playerid, gHudClock[playerid], THEME_MUTED);
    PlayerTextDrawSetOutline(playerid, gHudClock[playerid], 1);

    gHudTag[playerid] = CreatePlayerTextDraw(playerid, 12.0, 456.0,
        "~r~.~w~ ROLEPLAY INDONESIA");
    PlayerTextDrawFont(playerid, gHudTag[playerid], THEME_FONT_BODY);
    PlayerTextDrawLetterSize(playerid, gHudTag[playerid], 0.22, 1.1);
    PlayerTextDrawColour(playerid, gHudTag[playerid], THEME_MUTED);
    PlayerTextDrawSetOutline(playerid, gHudTag[playerid], 1);
    return 1;
}

stock HUD_Show(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gHudActive[playerid]) return 1;

    HUD_CreateDraws(playerid);
    gHudShownCash[playerid] = Money_GetCash(playerid);
    PlayerTextDrawShow(playerid, gHudMoney[playerid]);
    PlayerTextDrawShow(playerid, gHudClock[playerid]);
    PlayerTextDrawShow(playerid, gHudTag[playerid]);
    gHudActive[playerid] = true;
    HUD_Tick();
    return 1;
}

stock HUD_Destroy(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gHudActive[playerid]) return 0;

    PlayerTextDrawDestroy(playerid, gHudMoney[playerid]);
    PlayerTextDrawDestroy(playerid, gHudClock[playerid]);
    PlayerTextDrawDestroy(playerid, gHudTag[playerid]);
    gHudMoney[playerid] = PlayerText:INVALID_TEXT_DRAW;
    gHudClock[playerid] = PlayerText:INVALID_TEXT_DRAW;
    gHudTag[playerid] = PlayerText:INVALID_TEXT_DRAW;
    gHudActive[playerid] = false;
    gHudShownCash[playerid] = 0;
    return 1;
}

// Dipanggil tiap detik: tween saldo + jam berjalan terus.
stock HUD_Tick() {
    new moneyText[40], clockText[40];

    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!gHudActive[playerid] || !IsPlayerConnected(playerid)) continue;

        // Tween saldo: geser 25% selisih per detik (minimum 1 rupiah).
        new actual = Money_GetCash(playerid);
        new shown = gHudShownCash[playerid];
        new diff = actual - shown;
        new color = THEME_TEXT;
        if (diff != 0) {
            new step = diff / 4;
            if (step == 0) step = (diff > 0) ? 1 : -1;
            shown += step;
            gHudShownCash[playerid] = shown;
            color = (diff > 0) ? THEME_OK : THEME_DANGER;
        }
        new amount[24];
        Text_FormatNumber(shown, amount, sizeof (amount));
        format(moneyText, sizeof (moneyText), "~g~Rp %s", amount);
        PlayerTextDrawSetString(playerid, gHudMoney[playerid], moneyText);
        PlayerTextDrawColour(playerid, gHudMoney[playerid], color);
        PlayerTextDrawShow(playerid, gHudMoney[playerid]);

        HUD_FormatClock(clockText, sizeof (clockText));
        PlayerTextDrawSetString(playerid, gHudClock[playerid], clockText);
    }
    return 1;
}
