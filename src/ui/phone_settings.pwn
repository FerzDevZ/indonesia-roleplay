// ---------------------------------------------------------------------------
// module      : ui/phone_settings
// entry       : -
// depends     : ui/theme, ui/trxtdraw, ui/phone, ui/phone_draw (helper stock)
// owns tables : -
// public api  : PhoneDraw_Settings()
// Isi         : Layar PENGATURAN ponsel, dua gaya: iOS = grup kartu inset
//               ber-border berisi baris chip glyph + nilai + chevron; One UI
//               = baris datar menyatu latar. Nilai baris aktif di-update
//               lewat SetString (update in-place) via PhoneUI_SetValHandle.
// Aturan      : Tanpa karakter non-ASCII; hitbox digambar sebelum konten.
// ---------------------------------------------------------------------------
#if defined _INC_UI_PHONE_SETTINGS
    #endinput
#endif
#define _INC_UI_PHONE_SETTINGS

#include "theme.pwn"

// Baris settings flat (One UI).
#define PHONE_ROW_X         (PHONEC_X + 10.0)
#define PHONE_ROW_W         (PHONEC_W - 20.0)
#define PHONE_ROW_H         (32.0)

// Baris setting: chip glyph + label + nilai berwarna + chevron.
static PhoneDraw_SettingRow(playerid, Float:y, const label[], const value[],
    valueColor, clickId, valSlot, chipColor, const glyph[], Float:chipR) {
    new PlayerText:hit = PhoneSprite(playerid, PHONE_ROW_X, y, PHONE_ROW_W,
        PHONE_ROW_H, THEME_SURFACE, clickId > 0);
    if (clickId > 0) TrxTd_BindClick(playerid, hit, clickId);
    PhoneChip(playerid, PHONE_ROW_X + 5.0, y + 3.0, 20.0, 26.0, chipR,
        chipColor, glyph);
    PhoneText(playerid, PHONE_ROW_X + 32.0, y + 9.0, label, THEME_FONT_BODY,
        0.16, 0.75, THEME_TEXT);
    new PlayerText:valText = PhoneText(playerid,
        PHONE_ROW_X + PHONE_ROW_W - 22.0, y + 9.0, value, THEME_FONT_BODY,
        0.16, 0.75, valueColor, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_RIGHT);
    PhoneText(playerid, PHONE_ROW_X + PHONE_ROW_W - 14.0, y + 9.0, ">",
        THEME_FONT_BODY, 0.17, 0.78, THEME_MUTED);
    PhoneSprite(playerid, PHONE_ROW_X, y + PHONE_ROW_H, PHONE_ROW_W, 1.0,
        THEME_LINE);
    if (valSlot > 0) PhoneUI_SetValHandle(playerid, valSlot, valText);
    return 1;
}

// Baris setting iOS: di dalam kartu grup inset ber-border.
static PhoneDraw_SettingRowInset(playerid, Float:y, const label[],
    const value[], valueColor, clickId, valSlot, chipColor, const glyph[],
    Float:chipR) {
    new Float:rowX = PHONEC_X + 8.0;
    new Float:rowW = PHONEC_W - 16.0;
    new PlayerText:hit = PhoneSprite(playerid, rowX, y, rowW, 32.0,
        THEME_SURFACE, clickId > 0);
    if (clickId > 0) TrxTd_BindClick(playerid, hit, clickId);
    PhoneChip(playerid, rowX + 6.0, y + 3.0, 20.0, 26.0, chipR, chipColor,
        glyph);
    PhoneText(playerid, rowX + 34.0, y + 9.0, label, THEME_FONT_BODY,
        0.16, 0.75, THEME_TEXT);
    new PlayerText:valText = PhoneText(playerid, rowX + rowW - 26.0, y + 9.0,
        value, THEME_FONT_BODY, 0.16, 0.75, valueColor,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_RIGHT);
    PhoneText(playerid, rowX + rowW - 16.0, y + 9.0, ">",
        THEME_FONT_BODY, 0.17, 0.78, THEME_MUTED);
    PhoneSprite(playerid, rowX + 12.0, y + 32.0, rowW - 12.0, 1.0,
        THEME_LINE);
    if (valSlot > 0) PhoneUI_SetValHandle(playerid, valSlot, valText);
    return 1;
}

// LAYAR PENGATURAN: header FiveM + grup inset (iOS) / baris datar (One UI).
stock bool:PhoneDraw_Settings(playerid) {
    new bool:samsung = (PhoneUI_GetStyle(playerid) == PHONE_SKIN_SAMSUNG);
    new bgColor = samsung ? PHONE_SAMSUNG_BG : PHONE_IPHONE_BG;
    new Float:chipR = samsung ? PHONE_CHIP_R_SAM : PHONE_CHIP_R_IPH;
    PhoneShadow(playerid, PHONEC_X, PHONEC_Y, PHONEC_W, PHONEC_H,
        samsung ? 9.0 : 12.0);
    PhoneCardBordered(playerid, PHONEC_X, PHONEC_Y, PHONEC_W, PHONEC_H,
        samsung ? 9.0 : 12.0, bgColor);
    PhoneDraw_StatusBar(playerid, PHONEC_Y + 10.0);
    if (!samsung) {
        PhoneSprite(playerid, PHONEC_CX - 22.0, PHONEC_Y + 7.0, 33.0, 12.0,
            THEME_BG);
    }
    PhoneDraw_Header(playerid, "PENGATURAN");

    // Tombol kembali.
    new PlayerText:backLabel = PlayerText:0;
    new PlayerText:backBtn = PhoneButton(playerid, backLabel,
        PHONEC_X + 10.0, PHONEC_Y + 38.0, 28.0, 22.0, "<", THEME_ELEVATED,
        THEME_TEXT, 0.22, 0.85);
    TrxTd_BindClick(playerid, backBtn, PHONEUI_ID_BACK);

    new styleName[16], toastName[8];
    PhoneUI_StyleName(playerid, styleName, sizeof (styleName));
    PhoneUI_ToastName(playerid, toastName, sizeof (toastName));

    if (samsung) {
        // One UI: baris datar dengan chip glyph di kiri.
        PhoneDraw_SettingRow(playerid, PHONEC_Y + 74.0, "Skin Ponsel",
            styleName, THEME_INFO, PHONEUI_ID_SET_SKIN, PHONEUI_ID_SET_SKIN,
            THEME_INFO, "S", chipR);
        PhoneDraw_SettingRow(playerid, PHONEC_Y + 118.0, "Notifikasi",
            toastName, THEME_OK, PHONEUI_ID_SET_TOAST, PHONEUI_ID_SET_TOAST,
            THEME_OK, "N", chipR);
        PhoneDraw_SettingRow(playerid, PHONEC_Y + 162.0, "Versi",
            "RP-ID 1.0", THEME_MUTED, -1, 0, THEME_MUTED, "V", chipR);
    } else {
        // iOS: satu kartu grup inset ber-border berisi 3 baris.
        PhoneCardBordered(playerid, PHONEC_X + 8.0, PHONEC_Y + 70.0,
            PHONEC_W - 16.0, 108.0, 8.0, THEME_SURFACE);
        PhoneDraw_SettingRowInset(playerid, PHONEC_Y + 78.0, "Skin Ponsel",
            styleName, THEME_INFO, PHONEUI_ID_SET_SKIN, PHONEUI_ID_SET_SKIN,
            THEME_INFO, "S", chipR);
        PhoneDraw_SettingRowInset(playerid, PHONEC_Y + 117.0, "Notifikasi",
            toastName, THEME_OK, PHONEUI_ID_SET_TOAST, PHONEUI_ID_SET_TOAST,
            THEME_OK, "N", chipR);
        PhoneDraw_SettingRowInset(playerid, PHONEC_Y + 156.0, "Versi",
            "RP-ID 1.0", THEME_MUTED, -1, 0, THEME_MUTED, "V", chipR);
    }

    PhoneText(playerid, PHONEC_X + PHONEC_W / 2, PHONEC_Y + 214.0,
        "KETUK BARIS UNTUK MENGUBAH", THEME_FONT_LABEL, 0.11, 0.58,
        THEME_MUTED, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    PhoneDraw_CloseButton(playerid);
    return true;
}
