// ---------------------------------------------------------------------------
// module      : ui/phone_draw
// entry       : -
// depends     : ui/theme, ui/trxtdraw, ui/phone (state via PhoneUI_*)
// owns tables : -
// public api  : PhoneDraw_Home(), PhoneDraw_StatusBar(), PhoneShadow(),
//               PhoneDraw_CloseButton(), helper stock (PhoneCard dkk.)
// Isi         : Bahasa desain komunitas SA-MP terbaik: FLAT BERSIH.
//               - Frame gelap + garis rambut + bayangan (depth).
//               - Widget jam dalam kartu (terpusat iPhone / kiri Samsung).
//               - Daftar aplikasi 4 baris: chip warna + huruf besar (Font 2)
//                 + nama + chevron - pola yang dipuji komunitas karena
//                 sederhana dan rapi (bukan grid kotak warna).
//               - Pembeda skin: iPhone = Dynamic Island + chip squircle;
//                 Samsung = punch-hole + chip sudut landai + nav bar.
//               Tidak memakai sprite TXD (rawan gagal di client Android);
//               semua ikon berupa glyph teks - pasti tampil di semua client.
// Aturan      : Tanpa karakter non-ASCII; SetOutline(0)/SetShadow(0) via TrxTd.
// ---------------------------------------------------------------------------
#if defined _INC_UI_PHONE_DRAW
    #endinput
#endif
#define _INC_UI_PHONE_DRAW

#include "theme.pwn"

// Geometri ponsel (kanan layar, aman dari jempol Android kiri-bawah).
#define PHONEC_X            (476.0)
#define PHONEC_Y            (100.0)
#define PHONEC_W            (146.0)
#define PHONEC_H            (296.0)
#define PHONEC_CX           (PHONEC_X + PHONEC_W / 2.0)

// Chip ikon aplikasi: persegi dikoreksi aspek 16:9.
#define PHONE_CHIP_W        (24.0)
#define PHONE_CHIP_H        (32.0)
#define PHONE_CHIP_R_IPH    (7.0)
#define PHONE_CHIP_R_SAM    (4.0)

// Daftar aplikasi: 4 baris flat di bawah widget jam.
#define PHONE_APP_X         (PHONEC_X + 10.0)
#define PHONE_APP_W         (PHONEC_W - 20.0)
#define PHONE_APP_H         (36.0)
#define PHONE_APP_STEP      (44.0)
#define PHONE_APP_Y1        (PHONEC_Y + 92.0)

// Nama bulan Indonesia untuk tanggal di bawah jam widget.
static const gPhoneMonths[12][10] = {
    "Januari", "Februari", "Maret", "April", "Mei", "Juni",
    "Juli", "Agustus", "September", "Oktober", "November", "Desember"
};

stock PhoneTrack(playerid, PlayerText:handle) {
    return PhoneUI_TrackHandle(playerid, handle);
}

// Latar kartu rounded + pencatatan otomatis ke daftar kill.
stock PhoneCard(playerid, Float:x, Float:y, Float:w, Float:h,
    Float:radius, color) {
    new PlayerText:cards[6];
    TrxTd_RoundedCard(playerid, cards, x, y, w, h, radius, color);
    for (new index = 0; index < 6; index++) {
        PhoneTrack(playerid, cards[index]);
    }
    return 1;
}

// Kartu FiveM: garis rambut 11% putih di belakang permukaan.
stock PhoneCardBordered(playerid, Float:x, Float:y, Float:w, Float:h,
    Float:radius, color) {
    PhoneCard(playerid, x - 1.5, y - 1.5, w + 3.0, h + 3.0, radius + 1.5,
        THEME_BORDER);
    PhoneCard(playerid, x, y, w, h, radius, color);
    return 1;
}

stock PlayerText:PhoneSprite(playerid, Float:x, Float:y, Float:w, Float:h,
    color, bool:selectable = false) {
    new PlayerText:handle = TrxTd_Sprite(playerid, x, y, THEME_SPRITE_WHITE,
        w, h, color, selectable);
    PhoneTrack(playerid, handle);
    return handle;
}

stock PlayerText:PhoneText(playerid, Float:x, Float:y, const text[],
    TEXT_DRAW_FONT:font, Float:lsX, Float:lsY, color,
    TEXT_DRAW_ALIGN:align = TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT) {
    new PlayerText:handle = TrxTd_Text(playerid, x, y, text, font, lsX, lsY,
        color, align);
    PhoneTrack(playerid, handle);
    return handle;
}

stock PlayerText:PhoneButton(playerid, &PlayerText:labelOut, Float:x, Float:y,
    Float:w, Float:h, const label[], bgColor, textColor,
    Float:lsX = 0.20, Float:lsY = 0.90) {
    new PlayerText:handle = TrxTd_Button(playerid, labelOut, x, y, w, h,
        label, bgColor, textColor, lsX, lsY);
    PhoneTrack(playerid, handle);
    PhoneTrack(playerid, labelOut);
    return handle;
}

// Lingkaran glow besar ala dekor mesh FiveM (di belakang konten).
stock PhoneGlow(playerid, Float:x, Float:y, Float:diam) {
    PhoneSprite(playerid, x, y, diam * THEME_TD_ASPECT, diam, PHONE_GLOW);
    return 1;
}

// Bayangan panel: kartu rounded hitam transparan digeser +3px di belakang
// frame - lapisan depth wajib di UI server premium.
stock PhoneShadow(playerid, Float:x, Float:y, Float:w, Float:h,
    Float:radius) {
    PhoneCard(playerid, x + 3.0, y + 3.0, w, h, radius, PHONE_SHADOW);
    return 1;
}

// Chip ikon: kartu warna + huruf besar Font 2 di tengah (ikon aplikasi).
stock PhoneChip(playerid, Float:x, Float:y, Float:w, Float:h, Float:radius,
    color, const glyph[]) {
    PhoneCard(playerid, x, y, w, h, radius, color);
    PhoneText(playerid, x + w / 2.0, y + 4.0, glyph, THEME_FONT_LABEL,
        0.20, 1.05, THEME_WHITE, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    return 1;
}

// Header bar FiveM: judul uppercase kiri + garis aksen 2px di bawahnya.
stock PhoneDraw_Header(playerid, const title[]) {
    PhoneText(playerid, PHONEC_X + 12.0, PHONEC_Y + 10.0, title,
        THEME_FONT_LABEL, 0.15, 0.72, THEME_TEXT);
    PhoneSprite(playerid, PHONEC_X + 12.0, PHONEC_Y + 26.0, PHONEC_W - 24.0,
        2.0, THEME_ACCENT);
    return 1;
}

// Tanggal "18 November" gaya layar kunci.
static PhoneDateText(dest[], maxlength) {
    new year, month, day;
    getdate(year, month, day);
    return format(dest, maxlength, "%d %s", day, gPhoneMonths[month - 1]);
}

// Status bar: jam kiri, sinyal 4 batang + baterai realistis kanan.
stock PhoneDraw_StatusBar(playerid, Float:y) {
    new clockText[8];
    new hours, minutes;
    gettime(hours, minutes);
    format(clockText, sizeof (clockText), "%02d:%02d", hours, minutes);
    new PlayerText:statusClock = PhoneText(playerid, PHONEC_X + 14.0, y,
        clockText, THEME_FONT_BODY, 0.16, 0.70, THEME_TEXT);
    PhoneUI_SetStatusClock(playerid, statusClock);

    // Sinyal: 4 batang menaik (batang ke-4 redup = sinyal sedang).
    for (new bar = 0; bar < 4; bar++) {
        new Float:barH = 3.0 + bar * 2.0;
        new barColor = (bar < 3) ? THEME_TEXT : THEME_MUTED;
        PhoneSprite(playerid, PHONEC_X + 86.0 + bar * 5.0,
            y + 8.0 - barH, 3.0, barH, barColor);
    }
    // Baterai: badan + isi 70% + nub positif.
    PhoneSprite(playerid, PHONEC_X + 110.0, y + 1.0, 16.0, 8.0, THEME_MUTED);
    PhoneSprite(playerid, PHONEC_X + 111.5, y + 2.5, 10.0, 5.0, THEME_TEXT);
    PhoneSprite(playerid, PHONEC_X + 126.5, y + 3.0, 1.5, 4.0, THEME_MUTED);
    return 1;
}

// Widget jam dalam kartu surface (ala widget iOS/One UI di home screen).
static PhoneDraw_WidgetClock(playerid, bool:centered) {
    new clockText[8], dateText[24];
    new hours, minutes;
    gettime(hours, minutes);
    format(clockText, sizeof (clockText), "%02d:%02d", hours, minutes);
    PhoneDateText(dateText, sizeof (dateText));

    new TEXT_DRAW_ALIGN:align = TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER;
    if (!centered) align = TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT;
    new Float:cardX = PHONEC_X + 10.0;
    new Float:cardW = PHONEC_W - 20.0;
    new Float:clockX = centered ? PHONEC_CX : cardX + 10.0;
    new Float:dateX = centered ? PHONEC_CX : cardX + 11.0;

    PhoneCard(playerid, cardX, PHONEC_Y + 36.0, cardW, 46.0, 8.0,
        THEME_SURFACE);
    new PlayerText:widgetClock = PhoneText(playerid, clockX, PHONEC_Y + 41.0,
        clockText, THEME_FONT_LABEL, 0.34, 1.40, THEME_TEXT, align);
    PhoneUI_SetWidgetClock(playerid, widgetClock);
    PhoneText(playerid, dateX, PHONEC_Y + 70.0, dateText, THEME_FONT_BODY,
        0.14, 0.68, THEME_MUTED, align);
    return 1;
}

// Baris aplikasi: kartu flat + chip warna + glyph + nama + chevron.
// Hitbox digambar SEBELUM konten (aturan anti-tertutup, lihat MEMORY.md).
static PhoneDraw_AppRow(playerid, Float:y, const name[], color, clickId,
    const glyph[], Float:chipR) {
    PhoneCard(playerid, PHONE_APP_X, y, PHONE_APP_W, PHONE_APP_H, 6.0,
        THEME_SURFACE);
    new PlayerText:hit = PhoneSprite(playerid, PHONE_APP_X, y, PHONE_APP_W,
        PHONE_APP_H, THEME_SURFACE, true);
    TrxTd_BindClick(playerid, hit, clickId);
    PhoneChip(playerid, PHONE_APP_X + 5.0, y + 2.0, PHONE_CHIP_W,
        PHONE_CHIP_H, chipR, color, glyph);
    PhoneText(playerid, PHONE_APP_X + 38.0, y + 10.0, name, THEME_FONT_BODY,
        0.17, 0.80, THEME_TEXT);
    PhoneText(playerid, PHONE_APP_X + PHONE_APP_W - 16.0, y + 10.0, ">",
        THEME_FONT_BODY, 0.17, 0.80, THEME_MUTED);
    return 1;
}

// Empat aplikasi utama, dipakai kedua skin.
static PhoneDraw_AppList(playerid, Float:chipR) {
    PhoneDraw_AppRow(playerid, PHONE_APP_Y1, "BANK", THEME_OK,
        PHONEUI_ID_BANK, "B", chipR);
    PhoneDraw_AppRow(playerid, PHONE_APP_Y1 + PHONE_APP_STEP, "KTP",
        THEME_INFO, PHONEUI_ID_KTP, "K", chipR);
    PhoneDraw_AppRow(playerid, PHONE_APP_Y1 + PHONE_APP_STEP * 2.0,
        "SETING", THEME_ACCENT, PHONEUI_ID_SETTINGS, "S", chipR);
    PhoneDraw_AppRow(playerid, PHONE_APP_Y1 + PHONE_APP_STEP * 3.0,
        "KERJA", THEME_WARN, PHONEUI_ID_KERJA, "J", chipR);
    return 1;
}

// Tombol [X] menutup ponsel (wajib di semua modal, aturan Android).
stock PhoneDraw_CloseButton(playerid) {
    new PlayerText:closeLabel = PlayerText:0;
    new PlayerText:closeBtn = PhoneButton(playerid, closeLabel,
        PHONEC_X + PHONEC_W - 30.0, PHONEC_Y - 12.0, 28.0, 24.0, "X",
        THEME_DANGER, THEME_WHITE, 0.24, 0.90);
    TrxTd_BindClick(playerid, closeBtn, PHONEUI_ID_CLOSE);
    return 1;
}

// HOME SKIN IPHONE: island, widget jam terpusat, chip squircle.
static bool:PhoneDraw_HomeIphone(playerid) {
    PhoneGlow(playerid, PHONEC_X + 70.0, PHONEC_Y + 8.0, 64.0);
    PhoneShadow(playerid, PHONEC_X, PHONEC_Y, PHONEC_W, PHONEC_H, 12.0);
    PhoneCardBordered(playerid, PHONEC_X, PHONEC_Y, PHONEC_W, PHONEC_H,
        12.0, PHONE_IPHONE_BG);

    // Dynamic Island: pill hitam di atas garis status.
    PhoneSprite(playerid, PHONEC_CX - 22.0, PHONEC_Y + 7.0, 33.0, 12.0,
        THEME_BG);
    PhoneDraw_StatusBar(playerid, PHONEC_Y + 10.0);

    PhoneDraw_WidgetClock(playerid, true);
    PhoneDraw_AppList(playerid, PHONE_CHIP_R_IPH);

    PhoneSprite(playerid, PHONEC_CX - 18.0, PHONEC_Y + PHONEC_H - 7.0,
        36.0, 3.0, PHONE_HOME_IND);
    PhoneDraw_CloseButton(playerid);
    return true;
}

// HOME SKIN SAMSUNG (One UI): punch-hole, jam rata kiri, nav bar.
static bool:PhoneDraw_HomeSamsung(playerid) {
    PhoneGlow(playerid, PHONEC_X - 10.0, PHONEC_Y + 6.0, 56.0);
    PhoneShadow(playerid, PHONEC_X, PHONEC_Y, PHONEC_W, PHONEC_H, 9.0);
    PhoneCardBordered(playerid, PHONEC_X, PHONEC_Y, PHONEC_W, PHONEC_H,
        9.0, PHONE_SAMSUNG_BG);

    // Punch-hole kamera: titik kecil di tengah atas.
    PhoneSprite(playerid, PHONEC_CX - 3.0, PHONEC_Y + 9.0, 4.5, 6.0,
        THEME_BG);
    PhoneDraw_StatusBar(playerid, PHONEC_Y + 10.0);

    PhoneDraw_WidgetClock(playerid, false);
    PhoneDraw_AppList(playerid, PHONE_CHIP_R_SAM);

    // Garis pemisah + nav bar 3 tombol Samsung (hiasan).
    PhoneSprite(playerid, PHONEC_X + 10.0, PHONEC_Y + PHONEC_H - 24.0,
        PHONEC_W - 20.0, 1.0, THEME_LINE);
    PhoneText(playerid, PHONEC_X + 34.0, PHONEC_Y + PHONEC_H - 20.0, "<",
        THEME_FONT_BODY, 0.20, 0.80, THEME_MUTED);
    PhoneSprite(playerid, PHONEC_CX - 4.0, PHONEC_Y + PHONEC_H - 17.0,
        8.0, 8.0, THEME_MUTED);
    PhoneText(playerid, PHONEC_X + PHONEC_W - 42.0,
        PHONEC_Y + PHONEC_H - 20.0, "|||", THEME_FONT_BODY, 0.16, 0.80,
        THEME_MUTED);
    PhoneDraw_CloseButton(playerid);
    return true;
}

// HOME: dispatch per skin.
stock bool:PhoneDraw_Home(playerid) {
    if (PhoneUI_GetStyle(playerid) == PHONE_SKIN_SAMSUNG) {
        return PhoneDraw_HomeSamsung(playerid);
    }
    return PhoneDraw_HomeIphone(playerid);
}
