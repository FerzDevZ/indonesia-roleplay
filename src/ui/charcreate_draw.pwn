// ---------------------------------------------------------------------------
// module      : ui/charcreate (draw)
// depends     : ui/charcreate, ui/theme, ui/trxtdraw
// public api  : CharCreate_Open(), CharCreate_Show(), CharCreate_Hide(),
//               CharCreate_Destroy(), CharCreate_DestroyInner()
// Tugas       : menggambar & membongkar layar buat karakter (panel form kiri,
//               preview skin kanan). State form & getter tetap di ui/charcreate;
//               klik ditangani ui/charcreate_input; alur domain di domain/character.
// ---------------------------------------------------------------------------
#if defined _INC_UI_CHARCREATE_DRAW
    #endinput
#endif
#define _INC_UI_CHARCREATE_DRAW

// --- gambar ulang -----------------------------------------------------------
static CharCreate_DestroyInner(playerid) {
    TrxTd_Kill(playerid, gCcSkinLabel[playerid]);
    TrxTd_Kill(playerid, gCcSkinNext[playerid]);
    TrxTd_Kill(playerid, gCcSkinPrev[playerid]);
    TrxTd_Kill(playerid, gCcPreview[playerid]);
    TrxTd_Kill(playerid, gCcLblCancel[playerid]);
    TrxTd_Kill(playerid, gCcBtnCancel[playerid]);
    TrxTd_Kill(playerid, gCcLblCreate[playerid]);
    TrxTd_Kill(playerid, gCcBtnCreate[playerid]);
    for (new row = 0; row < CC_OPT_COUNT; row++) {
        TrxTd_Kill(playerid, gCcOptValue[row][playerid]);
        TrxTd_Kill(playerid, gCcOptNext[row][playerid]);
        TrxTd_Kill(playerid, gCcOptPrev[row][playerid]);
        TrxTd_Kill(playerid, gCcOptLabel[row][playerid]);
    }
    for (new row = 0; row < 3; row++) {
        TrxTd_Kill(playerid, gCcDobValue[row][playerid]);
        TrxTd_Kill(playerid, gCcDobNext[row][playerid]);
        TrxTd_Kill(playerid, gCcDobPrev[row][playerid]);
        TrxTd_Kill(playerid, gCcDobLabel[row][playerid]);
    }
    TrxTd_Kill(playerid, gCcLblGenderF[playerid]);
    TrxTd_Kill(playerid, gCcGenderF[playerid]);
    TrxTd_Kill(playerid, gCcLblGenderM[playerid]);
    TrxTd_Kill(playerid, gCcGenderM[playerid]);
    TrxTd_Kill(playerid, gCcLblLast[playerid]);
    TrxTd_Kill(playerid, gCcBtnLast[playerid]);
    TrxTd_Kill(playerid, gCcLblFirst[playerid]);
    TrxTd_Kill(playerid, gCcBtnFirst[playerid]);
    TrxTd_Kill(playerid, gCcTitle[playerid]);
    TrxTd_KillCard(playerid, gCcView[playerid]);
    TrxTd_KillCard(playerid, gCcForm[playerid]);
    gCcOpen[playerid] = false;
    return 1;
}

stock CharCreate_Destroy(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gCcOpen[playerid]) return 0;
    CancelSelectTextDraw(playerid);
    CharCreate_DestroyInner(playerid);
    return 1;
}

stock CharCreate_Hide(playerid) {
    return CharCreate_Destroy(playerid);
}

static CharCreate_Draw(playerid) {
    new PlayerText:unusedLabel = PlayerText:INVALID_TEXT_DRAW;
    TrxTd_ClearClicks(playerid);

    // Panel kiri: form. Panel kanan: preview skin.
    TrxTd_RoundedCard(playerid, gCcForm[playerid],
        CC_FORM_X, CC_CARD_Y, CC_FORM_W, CC_CARD_H, 8.0, THEME_SURFACE);
    TrxTd_RoundedCard(playerid, gCcView[playerid],
        CC_VIEW_X, CC_CARD_Y, CC_VIEW_W, CC_CARD_H, 8.0, THEME_SURFACE);

    gCcTitle[playerid] = TrxTd_Text(playerid, CC_INNER_X, CC_CARD_Y + 8.0,
        "BUAT KARAKTER", THEME_FONT_LABEL, 0.26, 1.00, THEME_ACCENT);

    // Baris nama: tombol penuh lebar, klik membuka dialog keyboard.
    new label[96];
    format(label, sizeof (label), "NAMA DEPAN:   %s",
        gCcFirst[playerid][0] ? gCcFirst[playerid] : "-");
    gCcBtnFirst[playerid] = TrxTd_Button(playerid, gCcLblFirst[playerid],
        CC_INNER_X, CC_CARD_Y + 30.0, CC_INNER_W, CC_ROW_H, label,
        THEME_ELEVATED, THEME_TEXT, 0.19, 0.85,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    TrxTd_BindClick(playerid, gCcBtnFirst[playerid], CC_ID_FIRST);

    format(label, sizeof (label), "NAMA BELAKANG:   %s",
        gCcLast[playerid][0] ? gCcLast[playerid] : "-");
    gCcBtnLast[playerid] = TrxTd_Button(playerid, gCcLblLast[playerid],
        CC_INNER_X, CC_CARD_Y + 62.0, CC_INNER_W, CC_ROW_H, label,
        THEME_ELEVATED, THEME_TEXT, 0.19, 0.85,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    TrxTd_BindClick(playerid, gCcBtnLast[playerid], CC_ID_LAST);

    // Toggle jenis kelamin: yang terpilih beraksen merah.
    TrxTd_Text(playerid, CC_INNER_X, CC_CARD_Y + 94.0, "KELAMIN:",
        THEME_FONT_BODY, 0.20, 0.90, THEME_MUTED);
    gCcGenderM[playerid] = TrxTd_Button(playerid, gCcLblGenderM[playerid],
        CC_INNER_X + 120.0, CC_CARD_Y + 88.0, 60.0, CC_ROW_H, "PRIA",
        gCcMale[playerid] ? THEME_ACCENT : THEME_ELEVATED,
        gCcMale[playerid] ? THEME_TEXT : THEME_MUTED, 0.16, 0.80);
    TrxTd_BindClick(playerid, gCcGenderM[playerid], CC_ID_GENDER_M);
    gCcGenderF[playerid] = TrxTd_Button(playerid, gCcLblGenderF[playerid],
        CC_INNER_X + 188.0, CC_CARD_Y + 88.0, 68.0, CC_ROW_H, "WANITA",
        !gCcMale[playerid] ? THEME_ACCENT : THEME_ELEVATED,
        !gCcMale[playerid] ? THEME_TEXT : THEME_MUTED, 0.16, 0.80);
    TrxTd_BindClick(playerid, gCcGenderF[playerid], CC_ID_GENDER_F);

    // Tanggal lahir: tiga baris stepper (hari, bulan, tahun).
    new dobValue[3][8];
    format(dobValue[0], 8, "%d", gCcDay[playerid]);
    format(dobValue[1], 8, "%s", gMonthNames[gCcMonth[playerid] - 1]);
    format(dobValue[2], 8, "%d", gCcYear[playerid]);
    for (new row = 0; row < 3; row++) {
        new Float:y = CC_CARD_Y + CC_DOB_BASE_Y + CC_STEP * row;
        gCcDobLabel[row][playerid] = TrxTd_Text(playerid, CC_INNER_X, y + 5.0,
            gDobLabels[row], THEME_FONT_BODY, 0.20, 0.90, THEME_MUTED);
        gCcDobPrev[row][playerid] = TrxTd_Button(playerid, unusedLabel,
            CC_INNER_X + 152.0, y, 28.0, 22.0, "<",
            THEME_ELEVATED, THEME_TEXT, 0.18, 0.80);
        gCcDobValue[row][playerid] = TrxTd_Text(playerid, CC_INNER_X + 196.0, y + 5.0,
            dobValue[row], THEME_FONT_BODY, 0.20, 0.90, THEME_TEXT,
            TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
        gCcDobNext[row][playerid] = TrxTd_Button(playerid, unusedLabel,
            CC_INNER_X + 228.0, y, 28.0, 22.0, ">",
            THEME_ELEVATED, THEME_TEXT, 0.18, 0.80);
        new clickId = (row == 0) ? CC_ID_DAY_PREV : ((row == 1) ? CC_ID_MON_PREV : CC_ID_YEAR_PREV);
        TrxTd_BindClick(playerid, gCcDobPrev[row][playerid], clickId);
        clickId = (row == 0) ? CC_ID_DAY_NEXT : ((row == 1) ? CC_ID_MON_NEXT : CC_ID_YEAR_NEXT);
        TrxTd_BindClick(playerid, gCcDobNext[row][playerid], clickId);
    }

    // Baris opsi: agama & gol darah (siklus), tinggi & berat (stepper).
    for (new row = 0; row < CC_OPT_COUNT; row++) {
        new Float:y = CC_CARD_Y + CC_OPT_BASE_Y + CC_STEP * row;
        new value[16];
        CharCreate_OptValue(playerid, row, value, sizeof (value));
        gCcOptLabel[row][playerid] = TrxTd_Text(playerid, CC_INNER_X, y + 5.0,
            gOptLabels[row], THEME_FONT_BODY, 0.20, 0.90, THEME_MUTED);
        gCcOptPrev[row][playerid] = TrxTd_Button(playerid, unusedLabel,
            CC_INNER_X + 152.0, y, 28.0, 22.0, "<",
            THEME_ELEVATED, THEME_TEXT, 0.18, 0.80);
        gCcOptValue[row][playerid] = TrxTd_Text(playerid, CC_INNER_X + 196.0,
            y + 5.0, value, THEME_FONT_BODY, 0.20, 0.90, THEME_TEXT,
            TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
        gCcOptNext[row][playerid] = TrxTd_Button(playerid, unusedLabel,
            CC_INNER_X + 228.0, y, 28.0, 22.0, ">",
            THEME_ELEVATED, THEME_TEXT, 0.18, 0.80);
        TrxTd_BindClick(playerid, gCcOptPrev[row][playerid], gOptPrevIds[row]);
        TrxTd_BindClick(playerid, gCcOptNext[row][playerid], gOptNextIds[row]);
    }

    // Tombol aksi: BUAT (aksen bila form lengkap) + BATAL.
    new bool:ready = gCcFirst[playerid][0] && gCcLast[playerid][0];
    gCcBtnCreate[playerid] = TrxTd_Button(playerid, gCcLblCreate[playerid],
        CC_INNER_X, CC_CARD_Y + CC_BTN_Y, 124.0, CC_ROW_H, "BUAT",
        ready ? THEME_ACCENT : THEME_ELEVATED,
        ready ? THEME_TEXT : THEME_MUTED, 0.18, 0.85);
    TrxTd_BindClick(playerid, gCcBtnCreate[playerid], CC_ID_CONFIRM);
    gCcBtnCancel[playerid] = TrxTd_Button(playerid, gCcLblCancel[playerid],
        CC_INNER_X + 132.0, CC_CARD_Y + CC_BTN_Y, 124.0, CC_ROW_H, "BATAL",
        THEME_GLASS, THEME_MUTED, 0.18, 0.85);
    TrxTd_BindClick(playerid, gCcBtnCancel[playerid], CC_ID_CANCEL);

    // Panel kanan: preview skin 3D + panah pilih.
    gCcPreview[playerid] = TrxTd_PreviewModel(playerid,
        CC_VIEW_X + 54.0, CC_CARD_Y + 34.0, 160.0, 180.0, CharCreate_GetSkin(playerid));
    format(label, sizeof (label), "SKIN  %d/%d", gCcSkinIdx[playerid] + 1,
        CharCreate_SkinCount(playerid));
    gCcSkinLabel[playerid] = TrxTd_Text(playerid, CC_VIEW_X + CC_VIEW_W / 2.0,
        CC_CARD_Y + 228.0, label, THEME_FONT_BODY, 0.20, 0.90, THEME_TEXT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    gCcSkinPrev[playerid] = TrxTd_Button(playerid, unusedLabel,
        CC_VIEW_X + 16.0, CC_CARD_Y + 224.0, 28.0, 22.0, "<",
        THEME_ELEVATED, THEME_TEXT, 0.18, 0.80);
    TrxTd_BindClick(playerid, gCcSkinPrev[playerid], CC_ID_SKIN_PREV);
    gCcSkinNext[playerid] = TrxTd_Button(playerid, unusedLabel,
        CC_VIEW_X + CC_VIEW_W - 44.0, CC_CARD_Y + 224.0, 28.0, 22.0, ">",
        THEME_ELEVATED, THEME_TEXT, 0.18, 0.80);
    TrxTd_BindClick(playerid, gCcSkinNext[playerid], CC_ID_SKIN_NEXT);

    gCcOpen[playerid] = true;
    SelectTextDraw(playerid, THEME_ACCENT);
    return 1;
}

// Buka baru: reset form ke nilai awal lalu gambar.
stock CharCreate_Open(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gCcOpen[playerid]) CharCreate_DestroyInner(playerid);

    gCcFirst[playerid][0] = '\0';
    gCcLast[playerid][0] = '\0';
    gCcMale[playerid] = true;
    gCcDay[playerid] = 1;
    gCcMonth[playerid] = 1;
    gCcYear[playerid] = 1998;
    gCcSkinIdx[playerid] = 0;
    gCcReligionIdx[playerid] = 0;
    gCcBloodIdx[playerid] = 3;
    gCcHeight[playerid] = 170;
    gCcWeight[playerid] = 60;
    CharCreate_Draw(playerid);
    return 1;
}

// Gambar ulang tanpa reset (dipakai setelah dialog nama ditutup / ESC).
stock CharCreate_Show(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gCcOpen[playerid]) CharCreate_DestroyInner(playerid);
    CharCreate_Draw(playerid);
    return 1;
}
