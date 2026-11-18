// ---------------------------------------------------------------------------
// module      : ui/charcreate (input)
// depends     : ui/charcreate, ui/trxtdraw
// public api  : CharCreate_OnClick() - dispatch klik layar buat karakter.
//               Perubahan state internal ditangani di sini; aksi yang butuh
//               domain (dialog nama, konfirmasi, batal) dikembalikan sebagai
//               kode CC_ACT_* untuk domain/character.
// ---------------------------------------------------------------------------
#if defined _INC_UI_CHARCREATE_INPUT
    #endinput
#endif
#define _INC_UI_CHARCREATE_INPUT

// Return: CC_ACT_NONE (bukan milik kita), CC_ACT_HANDLED (internal),
// atau aksi domain (CC_ACT_ASK_FIRST/LAST/CONFIRM/CANCEL).
stock CharCreate_OnClick(playerid, PlayerText:clicked) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return CC_ACT_NONE;
    if (!gCcOpen[playerid]) return CC_ACT_NONE;

    new action = TrxTd_ResolveClick(playerid, clicked);
    if (action == -1) return CC_ACT_NONE;

    // Baris opsi (agama, gol darah, tinggi, berat): update TEKS saja, tanpa
    // redraw penuh - menghancurkan textdraw di tengah callback klik membuat
    // klien glitch (flicker/teks kacau) saat diklik cepat.
    for (new row = 0; row < CC_OPT_COUNT; row++) {
        if (action == gOptPrevIds[row] || action == gOptNextIds[row]) {
            new dir = (action == gOptPrevIds[row]) ? -1 : 1;
            if (row < 2) CharCreate_CycleOption(playerid, row, dir);
            else CharCreate_StepOption(playerid, row, dir);
            new value[16];
            CharCreate_OptValue(playerid, row, value, sizeof (value));
            PlayerTextDrawSetString(playerid, gCcOptValue[row][playerid], value);
            PlayerTextDrawShow(playerid, gCcOptValue[row][playerid]);
            return CC_ACT_HANDLED;
        }
    }

    switch (action) {
        case CC_ID_FIRST: return CC_ACT_ASK_FIRST;
        case CC_ID_LAST:  return CC_ACT_ASK_LAST;
        case CC_ID_CONFIRM: return CC_ACT_CONFIRM;
        case CC_ID_CANCEL:  return CC_ACT_CANCEL;

        case CC_ID_GENDER_M, CC_ID_GENDER_F: {
            gCcMale[playerid] = (action == CC_ID_GENDER_M);
            CharCreate_UpdateGender(playerid);
            return CC_ACT_HANDLED;
        }
        case CC_ID_DAY_PREV: {
            gCcDay[playerid]--;
            Character_ClampDay(playerid);
            CharCreate_UpdateDobValue(playerid, 0);
            return CC_ACT_HANDLED;
        }
        case CC_ID_DAY_NEXT: {
            gCcDay[playerid]++;
            Character_ClampDay(playerid);
            CharCreate_UpdateDobValue(playerid, 0);
            return CC_ACT_HANDLED;
        }
        case CC_ID_MON_PREV: {
            gCcMonth[playerid] = (gCcMonth[playerid] == 1) ? 12 : gCcMonth[playerid] - 1;
            Character_ClampDay(playerid);
            CharCreate_UpdateDobValue(playerid, 1);
            return CC_ACT_HANDLED;
        }
        case CC_ID_MON_NEXT: {
            gCcMonth[playerid] = (gCcMonth[playerid] == 12) ? 1 : gCcMonth[playerid] + 1;
            Character_ClampDay(playerid);
            CharCreate_UpdateDobValue(playerid, 1);
            return CC_ACT_HANDLED;
        }
        case CC_ID_YEAR_PREV: {
            if (gCcYear[playerid] > CC_MIN_YEAR) gCcYear[playerid]--;
            CharCreate_UpdateDobValue(playerid, 2);
            return CC_ACT_HANDLED;
        }
        case CC_ID_YEAR_NEXT: {
            if (gCcYear[playerid] < CC_MAX_YEAR) gCcYear[playerid]++;
            CharCreate_UpdateDobValue(playerid, 2);
            return CC_ACT_HANDLED;
        }
        case CC_ID_SKIN_PREV: {
            gCcSkinIdx[playerid]--;
            if (gCcSkinIdx[playerid] < 0) gCcSkinIdx[playerid] = CharCreate_SkinCount(playerid) - 1;
            PlayerTextDrawSetPreviewModel(playerid, gCcPreview[playerid], CharCreate_GetSkin(playerid));
            PlayerTextDrawShow(playerid, gCcPreview[playerid]);
            new label[32];
            format(label, sizeof (label), "SKIN  %d/%d", gCcSkinIdx[playerid] + 1,
                CharCreate_SkinCount(playerid));
            PlayerTextDrawSetString(playerid, gCcSkinLabel[playerid], label);
            return CC_ACT_HANDLED;
        }
        case CC_ID_SKIN_NEXT: {
            gCcSkinIdx[playerid]++;
            if (gCcSkinIdx[playerid] >= CharCreate_SkinCount(playerid)) gCcSkinIdx[playerid] = 0;
            PlayerTextDrawSetPreviewModel(playerid, gCcPreview[playerid], CharCreate_GetSkin(playerid));
            PlayerTextDrawShow(playerid, gCcPreview[playerid]);
            new label[32];
            format(label, sizeof (label), "SKIN  %d/%d", gCcSkinIdx[playerid] + 1,
                CharCreate_SkinCount(playerid));
            PlayerTextDrawSetString(playerid, gCcSkinLabel[playerid], label);
            return CC_ACT_HANDLED;
        }
    }
    return CC_ACT_NONE;
}
