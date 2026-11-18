// ---------------------------------------------------------------------------
// module      : ui/simcard
// entry       : SimCard_Show()
// depends     : ui/theme, ui/trxtdraw, ui/uimodal
// owns tables : -
// public api  : SimCard_Show(), SimCard_Destroy(), SimCard_IsOpen(),
//               SimCard_OnClick()
// Tampilan    : replika SIM Nasional Indonesia: kartu biru muda, band header
//               biru tua "SIM NASIONAL INDONESIA" dengan teks putih, keterangan
//               "REPUBLIC OF INDONESIA - DRIVING LICENSE" di kanan band, foto
//               pas kiri berbingkai putih, kolom isian label-nilai, baris kaki
//               golongan darah / tinggi / masa berlaku, dan golongan SIM.
// Aturan      : modal lewat UIModal_Open(UI_SIMCARD); isi kartu disusun
//               domain/identity; klik tombol tutup ditangani di sini.
// ---------------------------------------------------------------------------
#if defined _INC_UI_SIMCARD
    #endinput
#endif
#define _INC_UI_SIMCARD

#include "theme.pwn"

#define SIMC_X          (105.0)
#define SIMC_Y          (112.0)
#define SIMC_W          (430.0)
#define SIMC_H          (266.0)
#define SIMC_BAND_H     (34.0)
#define SIMC_TITLE_Y    (SIMC_Y + 9.0)
#define SIMC_EN_Y1      (SIMC_Y + 6.0)
#define SIMC_EN_Y2      (SIMC_Y + 18.0)
#define SIMC_PROV_Y     (SIMC_Y + SIMC_BAND_H + 6.0)
#define SIMC_PHOTO_X    (SIMC_X + 14.0)
#define SIMC_PHOTO_Y    (SIMC_Y + 52.0)
#define SIMC_PHOTO_W    (78.0)
#define SIMC_PHOTO_H    (96.0)
#define SIMC_ROW_X      (SIMC_X + 104.0)
#define SIMC_ROW_Y      (SIMC_Y + 54.0)
#define SIMC_ROW_STEP   (17.0)
#define SIMC_FOOT_Y     (SIMC_Y + 162.0)
#define SIMC_GOL_Y      (SIMC_Y + 184.0)
#define SIMC_ROWS       (5)

#define SIMC_ID_CLOSE   (240)

static bool:gSimOpen[MAX_PLAYERS];
static PlayerText:gSimCard[MAX_PLAYERS][6];
static PlayerText:gSimBand[MAX_PLAYERS];
static PlayerText:gSimTitle[MAX_PLAYERS];
static PlayerText:gSimEn1[MAX_PLAYERS];
static PlayerText:gSimEn2[MAX_PLAYERS];
static PlayerText:gSimProv[MAX_PLAYERS];
static PlayerText:gSimPhotoFrame[MAX_PLAYERS];
static PlayerText:gSimPhoto[MAX_PLAYERS];
static PlayerText:gSimLabel[MAX_PLAYERS][SIMC_ROWS];
static PlayerText:gSimValue[MAX_PLAYERS][SIMC_ROWS];
static PlayerText:gSimFootA[MAX_PLAYERS];
static PlayerText:gSimFootB[MAX_PLAYERS];
static PlayerText:gSimFootC[MAX_PLAYERS];
static PlayerText:gSimGol[MAX_PLAYERS];
static PlayerText:gSimBtnClose[MAX_PLAYERS];
static PlayerText:gSimLblClose[MAX_PLAYERS];

stock bool:SimCard_IsOpen(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gSimOpen[playerid];
}

// Satu baris "Label : Nilai" gaya SIM Nasional.
static SimCard_Row(playerid, row, const label[], const value[]) {
    new Float:y = SIMC_ROW_Y + row * SIMC_ROW_STEP;
    gSimLabel[playerid][row] = TrxTd_Text(playerid, SIMC_ROW_X, y, label,
        THEME_FONT_BODY, 0.16, 0.70, SIM_LABEL, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gSimValue[playerid][row] = TrxTd_Text(playerid, SIMC_ROW_X + 84.0, y, value,
        THEME_FONT_BODY, 0.16, 0.70, SIM_VALUE, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    return 1;
}

stock bool:SimCard_Show(playerid, skinModel, const name[], const ttl[],
    const gender[], const address[], const occupation[], const blood[],
    const heightLabel[], const golongan[], const validUntil[]) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (gSimOpen[playerid]) SimCard_Destroy(playerid);
    if (!UIModal_Open(playerid, UI_SIMCARD)) return false;

    // Badan kartu biru muda + band header biru tua.
    TrxTd_RoundedCard(playerid, gSimCard[playerid], SIMC_X, SIMC_Y,
        SIMC_W, SIMC_H, 8.0, SIM_CARD);
    gSimBand[playerid] = TrxTd_Sprite(playerid, SIMC_X + 1.0, SIMC_Y + 1.0,
        THEME_SPRITE_WHITE, SIMC_W - 2.0, SIMC_BAND_H, SIM_BAND);

    // Judul band putih kiri + keterangan Inggris kanan (khas SIM Nasional).
    gSimTitle[playerid] = TrxTd_Text(playerid, SIMC_X + 14.0, SIMC_TITLE_Y,
        "SIM NASIONAL INDONESIA", THEME_FONT_LABEL, 0.20, 0.90, THEME_WHITE,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gSimEn1[playerid] = TrxTd_Text(playerid, SIMC_X + SIMC_W - 14.0, SIMC_EN_Y1,
        "REPUBLIC OF INDONESIA", THEME_FONT_BODY, 0.12, 0.70, THEME_WHITE,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_RIGHT);
    gSimEn2[playerid] = TrxTd_Text(playerid, SIMC_X + SIMC_W - 14.0, SIMC_EN_Y2,
        "DRIVING LICENSE", THEME_FONT_BODY, 0.12, 0.70, THEME_WHITE,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_RIGHT);

    gSimProv[playerid] = TrxTd_Text(playerid, SIMC_X + 14.0, SIMC_PROV_Y,
        "PROV. DKI JAKARTA", THEME_FONT_BODY, 0.14, 0.70, SIM_SUB,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);

    // Pas foto kiri berbingkai putih.
    gSimPhotoFrame[playerid] = TrxTd_Sprite(playerid, SIMC_PHOTO_X - 2.0,
        SIMC_PHOTO_Y - 2.0, THEME_SPRITE_WHITE, SIMC_PHOTO_W + 4.0,
        SIMC_PHOTO_H + 4.0, THEME_WHITE);
    gSimPhoto[playerid] = TrxTd_PreviewModel(playerid, SIMC_PHOTO_X,
        SIMC_PHOTO_Y, SIMC_PHOTO_W, SIMC_PHOTO_H, skinModel);

    // Kolom isian di kanan foto.
    SimCard_Row(playerid, 0, "Nama", name);
    SimCard_Row(playerid, 1, "Tempat/Tgl Lahir", ttl);
    SimCard_Row(playerid, 2, "Jenis Kelamin", gender);
    SimCard_Row(playerid, 3, "Alamat", address);
    SimCard_Row(playerid, 4, "Pekerjaan", occupation);

    // Baris kaki: data fisik dan masa berlaku.
    gSimFootA[playerid] = TrxTd_Text(playerid, SIMC_ROW_X, SIMC_FOOT_Y,
        blood, THEME_FONT_BODY, 0.16, 0.70, SIM_VALUE,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gSimFootB[playerid] = TrxTd_Text(playerid, SIMC_ROW_X + 120.0, SIMC_FOOT_Y,
        heightLabel, THEME_FONT_BODY, 0.16, 0.70, SIM_VALUE,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gSimFootC[playerid] = TrxTd_Text(playerid, SIMC_ROW_X + 210.0, SIMC_FOOT_Y,
        validUntil, THEME_FONT_BODY, 0.16, 0.70, SIM_VALUE,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gSimGol[playerid] = TrxTd_Text(playerid, SIMC_ROW_X, SIMC_GOL_Y,
        golongan, THEME_FONT_LABEL, 0.16, 0.80, SIM_BAND,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);

    gSimBtnClose[playerid] = TrxTd_Button(playerid, gSimLblClose[playerid],
        SIMC_X + SIMC_W - 36.0, SIMC_Y + 6.0, 28.0, 22.0, "X",
        THEME_ELEVATED, THEME_TEXT);
    TrxTd_BindClick(playerid, gSimBtnClose[playerid], SIMC_ID_CLOSE);

    gSimOpen[playerid] = true;
    // Aktifkan mode klik kursor: tombol X hanya bisa diklik saat mode ini on.
    SelectTextDraw(playerid, THEME_ACCENT);
    return true;
}

stock SimCard_Destroy(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gSimOpen[playerid]) return 0;

    CancelSelectTextDraw(playerid);
    TrxTd_Kill(playerid, gSimLblClose[playerid]);
    TrxTd_Kill(playerid, gSimBtnClose[playerid]);
    TrxTd_Kill(playerid, gSimGol[playerid]);
    TrxTd_Kill(playerid, gSimFootC[playerid]);
    TrxTd_Kill(playerid, gSimFootB[playerid]);
    TrxTd_Kill(playerid, gSimFootA[playerid]);
    for (new row = 0; row < SIMC_ROWS; row++) {
        TrxTd_Kill(playerid, gSimValue[playerid][row]);
        TrxTd_Kill(playerid, gSimLabel[playerid][row]);
    }
    TrxTd_Kill(playerid, gSimPhoto[playerid]);
    TrxTd_Kill(playerid, gSimPhotoFrame[playerid]);
    TrxTd_Kill(playerid, gSimProv[playerid]);
    TrxTd_Kill(playerid, gSimEn2[playerid]);
    TrxTd_Kill(playerid, gSimEn1[playerid]);
    TrxTd_Kill(playerid, gSimTitle[playerid]);
    TrxTd_Kill(playerid, gSimBand[playerid]);
    TrxTd_KillCard(playerid, gSimCard[playerid]);
    gSimOpen[playerid] = false;
    return 1;
}

// Return: true kalau klik ditangani di sini (tombol tutup), false selainnya.
stock bool:SimCard_OnClick(playerid, PlayerText:clicked) {
    if (!gSimOpen[playerid]) return false;
    if (TrxTd_ResolveClick(playerid, clicked) != SIMC_ID_CLOSE) return false;

    UIModal_Close(playerid);
    return true;
}
