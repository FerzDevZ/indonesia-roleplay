// ---------------------------------------------------------------------------
// module      : ui/charcreate
// entry       : -
// depends     : ui/theme, ui/trxtdraw, ui/toast, core/log
// owns tables : -
// public api  : CharCreate_Open(), CharCreate_Show(), CharCreate_Hide(),
//               CharCreate_Destroy(), CharCreate_IsOpen(), CharCreate_OnClick(),
//               CharCreate_SetFirstName(), CharCreate_SetLastName(),
//               CharCreate_GetFirstName(), CharCreate_GetLastName(),
//               CharCreate_IsMale(), CharCreate_GetBirthDay/Month/Year(),
//               CharCreate_GetSkin(), CharCreate_GetReligion(),
//               CharCreate_GetBlood(), CharCreate_GetHeight(),
//               CharCreate_GetWeight()
// Tampilan    : layar buat karakter ala FiveM dua panel: kiri form (nama via
//               dialog keyboard, toggle jenis kelamin, tanggal lahir dengan
//               stepper, agama & golongan darah dengan pemilih siklus, tinggi
//               & berat badan dengan stepper), kanan preview skin 3D (font
//               model preview) dengan panah pilih skin. State form milik
//               modul ini; alur domain (dialog nama, INSERT, spawn) tetap
//               milik domain/character.
// ---------------------------------------------------------------------------
#if defined _INC_UI_CHARCREATE
    #endinput
#endif
#define _INC_UI_CHARCREATE

#include "theme.pwn"
#include "trxtdraw.pwn"
#include "toast.pwn"

// Aksi yang diteruskan ke domain/character (dikembalikan CharCreate_OnClick).
#define CC_ACT_NONE         (0)
#define CC_ACT_HANDLED      (1)
#define CC_ACT_ASK_FIRST    (2)
#define CC_ACT_ASK_LAST     (3)
#define CC_ACT_CONFIRM      (4)
#define CC_ACT_CANCEL       (5)

// Id klik internal (registry TrxTd_BindClick).
#define CC_ID_FIRST         (101)
#define CC_ID_LAST          (102)
#define CC_ID_GENDER_M      (103)
#define CC_ID_GENDER_F      (104)
#define CC_ID_DAY_PREV      (105)
#define CC_ID_DAY_NEXT      (106)
#define CC_ID_MON_PREV      (107)
#define CC_ID_MON_NEXT      (108)
#define CC_ID_YEAR_PREV     (109)
#define CC_ID_YEAR_NEXT     (110)
#define CC_ID_SKIN_PREV     (111)
#define CC_ID_SKIN_NEXT     (112)
#define CC_ID_CONFIRM       (113)
#define CC_ID_CANCEL        (114)
#define CC_ID_REL_PREV      (115)
#define CC_ID_REL_NEXT      (116)
#define CC_ID_BLOOD_PREV    (117)
#define CC_ID_BLOOD_NEXT    (118)
#define CC_ID_HEIGHT_PREV   (119)
#define CC_ID_HEIGHT_NEXT   (120)
#define CC_ID_WEIGHT_PREV   (121)
#define CC_ID_WEIGHT_NEXT   (122)

#define CC_MIN_YEAR         (1965)
#define CC_MAX_YEAR         (2007)   // menjamin usia >= 18 tahun

#define CC_HEIGHT_MIN       (140)
#define CC_HEIGHT_MAX       (220)
#define CC_WEIGHT_MIN       (35)
#define CC_WEIGHT_MAX       (150)

#define CC_FORM_X           (36.0)
#define CC_FORM_W           (280.0)
#define CC_VIEW_X           (336.0)
#define CC_VIEW_W           (268.0)
#define CC_CARD_Y           (70.0)
#define CC_CARD_H           (350.0)
#define CC_INNER_X          (CC_FORM_X + 12.0)
#define CC_INNER_W          (CC_FORM_W - 24.0)
#define CC_ROW_H            (26.0)
#define CC_DOB_BASE_Y       (120.0)
#define CC_OPT_BASE_Y       (198.0)
#define CC_STEP             (24.0)
#define CC_BTN_Y            (308.0)

#define CC_OPT_COUNT        (4)      // agama, gol darah, tinggi, berat

static const gMaleSkins[] = {2, 7, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24,
    25, 26, 27, 28, 29, 30, 32, 33, 34, 46, 250};
static const gFemaleSkins[] = {9, 10, 11, 12, 13, 40, 41, 55, 56, 63, 64, 65,
    76, 77, 88, 90, 93, 129, 130, 131, 132, 141, 148, 150};
new const gMonthNames[12][4] = {"JAN", "FEB", "MAR", "APR", "MEI", "JUN",
    "JUL", "AGU", "SEP", "OKT", "NOV", "DES"};
static const gMonthDays[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
new const gDobLabels[3][8] = {"TANGGAL", "BULAN", "TAHUN"};
static const gReligionNames[6][10] = {"ISLAM", "KRISTEN", "KATOLIK", "HINDU",
    "BUDDHA", "KONGHUCU"};
static const gBloodNames[4][3] = {"A", "B", "AB", "O"};
new const gOptLabels[CC_OPT_COUNT][12] = {"AGAMA", "GOL DARAH", "TINGGI",
    "BERAT"};
new const gOptPrevIds[CC_OPT_COUNT] = {CC_ID_REL_PREV, CC_ID_BLOOD_PREV,
    CC_ID_HEIGHT_PREV, CC_ID_WEIGHT_PREV};
new const gOptNextIds[CC_OPT_COUNT] = {CC_ID_REL_NEXT, CC_ID_BLOOD_NEXT,
    CC_ID_HEIGHT_NEXT, CC_ID_WEIGHT_NEXT};

new bool:gCcOpen[MAX_PLAYERS];
new gCcFirst[MAX_PLAYERS][MAX_USERNAME_LENGTH + 1];
new gCcLast[MAX_PLAYERS][MAX_USERNAME_LENGTH + 1];
new bool:gCcMale[MAX_PLAYERS];
new gCcDay[MAX_PLAYERS];
new gCcMonth[MAX_PLAYERS];
new gCcYear[MAX_PLAYERS];
new gCcSkinIdx[MAX_PLAYERS];
new gCcReligionIdx[MAX_PLAYERS];
new gCcBloodIdx[MAX_PLAYERS];
new gCcHeight[MAX_PLAYERS];
new gCcWeight[MAX_PLAYERS];

new PlayerText:gCcForm[MAX_PLAYERS][6];
new PlayerText:gCcView[MAX_PLAYERS][6];
new PlayerText:gCcTitle[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcBtnFirst[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcLblFirst[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcBtnLast[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcLblLast[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcGenderM[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcLblGenderM[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcGenderF[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcLblGenderF[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcDobLabel[3][MAX_PLAYERS];
new PlayerText:gCcDobPrev[3][MAX_PLAYERS];
new PlayerText:gCcDobNext[3][MAX_PLAYERS];
new PlayerText:gCcDobValue[3][MAX_PLAYERS];
new PlayerText:gCcOptLabel[CC_OPT_COUNT][MAX_PLAYERS];
new PlayerText:gCcOptPrev[CC_OPT_COUNT][MAX_PLAYERS];
new PlayerText:gCcOptNext[CC_OPT_COUNT][MAX_PLAYERS];
new PlayerText:gCcOptValue[CC_OPT_COUNT][MAX_PLAYERS];
new PlayerText:gCcBtnCreate[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcLblCreate[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcBtnCancel[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcLblCancel[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcPreview[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcSkinPrev[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcSkinNext[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };
new PlayerText:gCcSkinLabel[MAX_PLAYERS] = { PlayerText:INVALID_TEXT_DRAW, ... };

stock bool:CharCreate_IsOpen(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gCcOpen[playerid];
}

stock CharCreate_SkinCount(playerid) {
    return gCcMale[playerid] ? sizeof (gMaleSkins) : sizeof (gFemaleSkins);
}

stock Character_SkinAt(playerid, index) {
    new count = CharCreate_SkinCount(playerid);
    if (index < 0) index = count - 1;
    if (index >= count) index = 0;
    return gCcMale[playerid] ? gMaleSkins[index] : gFemaleSkins[index];
}

stock Character_DaysInMonth(playerid) {
    new days = gMonthDays[gCcMonth[playerid] - 1];
    if (gCcMonth[playerid] == 2) {
        new year = gCcYear[playerid];
        if ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) days = 29;
    }
    return days;
}

stock Character_ClampDay(playerid) {
    if (gCcDay[playerid] < 1) gCcDay[playerid] = Character_DaysInMonth(playerid);
    if (gCcDay[playerid] > Character_DaysInMonth(playerid)) gCcDay[playerid] = 1;
    return 1;
}

// --- getters untuk domain ---------------------------------------------------
stock CharCreate_GetFirstName(playerid, dest[], maxlength = sizeof (dest)) {
    return format(dest, maxlength, "%s", gCcFirst[playerid]);
}

stock CharCreate_GetLastName(playerid, dest[], maxlength = sizeof (dest)) {
    return format(dest, maxlength, "%s", gCcLast[playerid]);
}

stock CharCreate_SetFirstName(playerid, const value[]) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return format(gCcFirst[playerid], MAX_USERNAME_LENGTH + 1, "%s", value);
}

stock CharCreate_SetLastName(playerid, const value[]) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return format(gCcLast[playerid], MAX_USERNAME_LENGTH + 1, "%s", value);
}

stock bool:CharCreate_IsMale(playerid) {
    return gCcMale[playerid];
}

stock CharCreate_GetBirthDay(playerid) {
    return gCcDay[playerid];
}

stock CharCreate_GetBirthMonth(playerid) {
    return gCcMonth[playerid];
}

stock CharCreate_GetBirthYear(playerid) {
    return gCcYear[playerid];
}

stock CharCreate_GetSkin(playerid) {
    return Character_SkinAt(playerid, gCcSkinIdx[playerid]);
}

stock CharCreate_GetReligion(playerid, dest[], maxlength = sizeof (dest)) {
    return format(dest, maxlength, "%s", gReligionNames[gCcReligionIdx[playerid]]);
}

stock CharCreate_GetBlood(playerid, dest[], maxlength = sizeof (dest)) {
    return format(dest, maxlength, "%s", gBloodNames[gCcBloodIdx[playerid]]);
}

stock CharCreate_GetHeight(playerid) {
    return gCcHeight[playerid];
}

stock CharCreate_GetWeight(playerid) {
    return gCcWeight[playerid];
}

// Teks nilai untuk baris opsi (agama, gol darah, tinggi, berat).
stock CharCreate_OptValue(playerid, row, dest[], maxlength = sizeof (dest)) {
    switch (row) {
        case 0: return format(dest, maxlength, "%s", gReligionNames[gCcReligionIdx[playerid]]);
        case 1: return format(dest, maxlength, "%s", gBloodNames[gCcBloodIdx[playerid]]);
        case 2: return format(dest, maxlength, "%d CM", gCcHeight[playerid]);
        case 3: return format(dest, maxlength, "%d KG", gCcWeight[playerid]);
    }
    dest[0] = '\0';
    return 0;
}

// Siklus pilihan (agama / gol darah): dir -1 mundur, +1 maju.
stock CharCreate_CycleOption(playerid, row, dir) {
    if (row == 0) {
        gCcReligionIdx[playerid] += dir;
        if (gCcReligionIdx[playerid] < 0) gCcReligionIdx[playerid] = 5;
        if (gCcReligionIdx[playerid] > 5) gCcReligionIdx[playerid] = 0;
        return 1;
    }
    if (row == 1) {
        gCcBloodIdx[playerid] += dir;
        if (gCcBloodIdx[playerid] < 0) gCcBloodIdx[playerid] = 3;
        if (gCcBloodIdx[playerid] > 3) gCcBloodIdx[playerid] = 0;
        return 1;
    }
    return 0;
}

// Stepper angka (tinggi / berat): dir -1 turun, +1 naik, dijepit batas.
stock CharCreate_StepOption(playerid, row, dir) {
    if (row == 2) {
        gCcHeight[playerid] += dir;
        if (gCcHeight[playerid] < CC_HEIGHT_MIN) gCcHeight[playerid] = CC_HEIGHT_MIN;
        if (gCcHeight[playerid] > CC_HEIGHT_MAX) gCcHeight[playerid] = CC_HEIGHT_MAX;
        return 1;
    }
    if (row == 3) {
        gCcWeight[playerid] += dir;
        if (gCcWeight[playerid] < CC_WEIGHT_MIN) gCcWeight[playerid] = CC_WEIGHT_MIN;
        if (gCcWeight[playerid] > CC_WEIGHT_MAX) gCcWeight[playerid] = CC_WEIGHT_MAX;
        return 1;
    }
    return 0;
}

// Update satu nilai DOB di tempat - tanpa redraw penuh (anti-glitch klik cepat).
stock CharCreate_UpdateDobValue(playerid, row) {
    new value[8];
    if (row == 0) format(value, sizeof (value), "%d", gCcDay[playerid]);
    else if (row == 1) format(value, sizeof (value), "%s", gMonthNames[gCcMonth[playerid] - 1]);
    else format(value, sizeof (value), "%d", gCcYear[playerid]);
    PlayerTextDrawSetString(playerid, gCcDobValue[row][playerid], value);
    PlayerTextDrawShow(playerid, gCcDobValue[row][playerid]);
    return 1;
}

// Toggle kelamin tanpa redraw penuh: warna tombol + preview skin di-update
// di tempat, jadi tidak ada textdraw yang dihancurkan di tengah callback klik.
stock CharCreate_UpdateGender(playerid) {
    PlayerTextDrawColour(playerid, gCcGenderM[playerid],
        gCcMale[playerid] ? THEME_ACCENT : THEME_ELEVATED);
    PlayerTextDrawColour(playerid, gCcLblGenderM[playerid],
        gCcMale[playerid] ? THEME_TEXT : THEME_MUTED);
    PlayerTextDrawColour(playerid, gCcGenderF[playerid],
        !gCcMale[playerid] ? THEME_ACCENT : THEME_ELEVATED);
    PlayerTextDrawColour(playerid, gCcLblGenderF[playerid],
        !gCcMale[playerid] ? THEME_TEXT : THEME_MUTED);
    PlayerTextDrawShow(playerid, gCcGenderM[playerid]);
    PlayerTextDrawShow(playerid, gCcLblGenderM[playerid]);
    PlayerTextDrawShow(playerid, gCcGenderF[playerid]);
    PlayerTextDrawShow(playerid, gCcLblGenderF[playerid]);

    // Daftar skin berubah mengikuti kelamin: reset ke skin pertama.
    gCcSkinIdx[playerid] = 0;
    PlayerTextDrawSetPreviewModel(playerid, gCcPreview[playerid], CharCreate_GetSkin(playerid));
    PlayerTextDrawShow(playerid, gCcPreview[playerid]);
    new label[32];
    format(label, sizeof (label), "SKIN  %d/%d", gCcSkinIdx[playerid] + 1,
        CharCreate_SkinCount(playerid));
    PlayerTextDrawSetString(playerid, gCcSkinLabel[playerid], label);
    return 1;
}
