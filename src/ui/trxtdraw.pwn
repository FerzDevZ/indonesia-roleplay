// ---------------------------------------------------------------------------
// module      : ui/trxtdraw
// entry       : -
// depends     : ui/theme
// owns tables : -
// public api  : primitif textdraw modern bergaya FiveM/NoPixel:
//               TrxTd_Text(), TrxTd_Sprite(), TrxTd_Box(), TrxTd_RoundedCard(),
//               TrxTd_KillCard(), TrxTd_Button(), TrxTd_BindClick(),
//               TrxTd_ResolveClick(), TrxTd_Kill(), TrxTd_Reset(),
//               TrxTd_PoolUsed(), Progress_Show/Set/Hide()
// Aturan      : SEMUA pembuatan PlayerTextDraw modul UI lewat engine ini supaya
//               budget pool 256 terukur dan gaya (tanpa outline tebal, proporsional)
//               konsisten. Bentuk persegi memakai koreksi aspek 16:9 (0.75).
// ---------------------------------------------------------------------------
#if defined _INC_UI_TRXTDRAW
    #endinput
#endif
#define _INC_UI_TRXTDRAW

#include "theme.pwn"

// Ambang aman pool: open.mp memotong keras di 256 PlayerTextDraw per pemain.
#define TRX_POOL_LIMIT      (256)
#define TRX_POOL_WARN       (200)
#define TRX_MAX_CLICKS      (48)

// Target sentuh minimum untuk client Android (jari, bukan kursor 1px).
#define TRX_TOUCH_MIN_W     (28.0)
#define TRX_TOUCH_MIN_H     (22.0)

static gTrxPoolUsed[MAX_PLAYERS];
static gTrxClickCount[MAX_PLAYERS];
static PlayerText:gTrxClickHandle[MAX_PLAYERS][TRX_MAX_CLICKS];
static gTrxClickId[MAX_PLAYERS][TRX_MAX_CLICKS];

// Progress bar tunggal per pemain (dipakai pekerjaan/aksi berdurasi).
static PlayerText:gTrxProgTrack[MAX_PLAYERS];
static PlayerText:gTrxProgFill[MAX_PLAYERS];
static Float:gTrxProgX[MAX_PLAYERS];
static Float:gTrxProgW[MAX_PLAYERS];
static bool:gTrxProgActive[MAX_PLAYERS];

stock TrxTd_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gTrxPoolUsed[playerid] = 0;
    gTrxClickCount[playerid] = 0;
    gTrxProgTrack[playerid] = PlayerText:INVALID_TEXT_DRAW;
    gTrxProgFill[playerid] = PlayerText:INVALID_TEXT_DRAW;
    gTrxProgActive[playerid] = false;
    return 1;
}

stock TrxTd_PoolUsed(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return gTrxPoolUsed[playerid];
}

static TrxTd_CountCreate(playerid) {
    gTrxPoolUsed[playerid]++;
    if (gTrxPoolUsed[playerid] == TRX_POOL_WARN) {
        Log_Warn("ui", "pool PlayerTextDraw mendekati batas 256");
    }
    return 1;
}

// Teks modern: tanpa outline tebal, proporsional, tidak bisa diklik.
stock PlayerText:TrxTd_Text(playerid, Float:x, Float:y, const text[],
    TEXT_DRAW_FONT:font, Float:lsX, Float:lsY, color,
    TEXT_DRAW_ALIGN:align = TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT,
    bool:outline = false) {
    new PlayerText:handle = CreatePlayerTextDraw(playerid, x, y, text);
    PlayerTextDrawAlignment(playerid, handle, align);
    PlayerTextDrawFont(playerid, handle, font);
    PlayerTextDrawLetterSize(playerid, handle, lsX, lsY);
    PlayerTextDrawColour(playerid, handle, color);
    PlayerTextDrawSetOutline(playerid, handle, outline ? 1 : 0);
    PlayerTextDrawSetShadow(playerid, handle, 0);
    PlayerTextDrawSetProportional(playerid, handle, true);
    PlayerTextDrawSetSelectable(playerid, handle, false);
    PlayerTextDrawShow(playerid, handle);
    TrxTd_CountCreate(playerid);
    return handle;
}

// Sprite (LD_SPAC:white / LD_BEAT:chit / ikon txd): TextSize = ukuran visual.
// PENTING: SetSelectable WAJIB dipanggil sebelum Show - kalau setelah Show,
// properti tidak aktif dan tombol tidak bisa diklik.
stock PlayerText:TrxTd_Sprite(playerid, Float:x, Float:y, const sprite[],
    Float:w, Float:h, color, bool:selectable = false) {
    new PlayerText:handle = CreatePlayerTextDraw(playerid, x, y, sprite);
    PlayerTextDrawFont(playerid, handle, THEME_FONT_SPRITE);
    PlayerTextDrawTextSize(playerid, handle, w, h);
    PlayerTextDrawColour(playerid, handle, color);
    PlayerTextDrawSetSelectable(playerid, handle, selectable);
    PlayerTextDrawShow(playerid, handle);
    TrxTd_CountCreate(playerid);
    return handle;
}

// Kotak polos gaya lama (box "_") untuk lapisan/latar lebar penuh.
stock PlayerText:TrxTd_Box(playerid, Float:x, Float:y, Float:endX,
    Float:heightPx, boxColor) {
    new PlayerText:handle = CreatePlayerTextDraw(playerid, x, y, "_");
    PlayerTextDrawUseBox(playerid, handle, true);
    PlayerTextDrawBoxColour(playerid, handle, boxColor);
    PlayerTextDrawLetterSize(playerid, handle, 0.0, Theme_BoxHeight(heightPx));
    PlayerTextDrawTextSize(playerid, handle, endX, 0.0);
    PlayerTextDrawSetSelectable(playerid, handle, false);
    PlayerTextDrawShow(playerid, handle);
    TrxTd_CountCreate(playerid);
    return handle;
}

// ---------------------------------------------------------------------------
// TrxTd_Panel: komponen modal FiveM standar (satu sumber gaya seluruh server).
// Struktur (mengikuti bahasa desain NoPixel 4.0 / Nimbus np_menu):
//   1. bayangan hitam +3px (depth)
//   2. garis rambut border (hairline)
//   3. kaca gelap (frosted glass)
//   4. judul uppercase + garis aksen brand di bawahnya
//   5. tombol [X] kanan atas (otomatis di-bind ke closeId)
// Caller wajib meloop out[] dan meng-track semuanya ke kill list modalnya.
// ---------------------------------------------------------------------------
#define TRX_PANEL_MAX_TD       (22)

stock TrxTd_Panel(playerid, PlayerText:out[], Float:x, Float:y,
    Float:w, Float:h, const title[], closeId,
    &PlayerText:closeBtnOut, &PlayerText:closeLblOut) {
    new count = 0;

    // 1. Bayangan (hitam +3px offset).
    TrxTd_RoundedCard(playerid, out[count], x + 3.0, y + 3.0, w, h, 10.0,
        THEME_SHADOW);
    count += 6;

    // 2. Garis rambut lalu 3. kaca gelap.
    TrxTd_RoundedCard(playerid, out[count], x - 1.5, y - 1.5, w + 3.0,
        h + 3.0, 11.5, THEME_BORDER);
    count += 6;
    TrxTd_RoundedCard(playerid, out[count], x, y, w, h, 10.0, THEME_GLASS);
    count += 6;

    // 4. Judul + garis aksen.
    out[count++] = TrxTd_Text(playerid, x + 12.0, y + 10.0, title,
        THEME_FONT_LABEL, 0.15, 0.72, THEME_TEXT);
    out[count++] = TrxTd_Sprite(playerid, x + 12.0, y + 26.0,
        THEME_SPRITE_WHITE, w - 24.0, 2.0, THEME_ACCENT);

    // 5. Tombol [X] kanan atas (hitbox = sprite, akurat di Android).
    // closeId < 0 = panel tanpa tombol tutup (layar pre-login).
    if (closeId >= 0) {
        closeBtnOut = TrxTd_Button(playerid, closeLblOut, x + w - 30.0, y - 12.0,
            28.0, 24.0, "X", THEME_DANGER, THEME_WHITE, 0.24, 0.90);
        TrxTd_BindClick(playerid, closeBtnOut, closeId);
        out[count++] = closeBtnOut;
        out[count++] = closeLblOut;
    } else {
        closeBtnOut = PlayerText:INVALID_TEXT_DRAW;
        closeLblOut = PlayerText:INVALID_TEXT_DRAW;
    }
    return count;
}

// Kartu rounded-corner FiveM: 6 sprite (2 persegi + 4 lingkaran sudut).
// Sudut dikoreksi aspek 16:9 agar lingkaran tetap bulat di layar lebar.
stock TrxTd_RoundedCard(playerid, PlayerText:out[], Float:x, Float:y,
    Float:w, Float:h, Float:radius, color) {
    new Float:rx = radius * THEME_TD_ASPECT;
    new Float:ry = radius;
    new Float:diamX = rx * 2.0;
    new Float:diamY = ry * 2.0;

    out[0] = TrxTd_Sprite(playerid, x, y + ry, THEME_SPRITE_WHITE, w, h - diamY, color);
    out[1] = TrxTd_Sprite(playerid, x + rx, y, THEME_SPRITE_WHITE, w - diamX, h, color);
    out[2] = TrxTd_Sprite(playerid, x, y, THEME_SPRITE_CIRCLE, diamX, diamY, color);
    out[3] = TrxTd_Sprite(playerid, x + w - diamX, y, THEME_SPRITE_CIRCLE, diamX, diamY, color);
    out[4] = TrxTd_Sprite(playerid, x, y + h - diamY, THEME_SPRITE_CIRCLE, diamX, diamY, color);
    out[5] = TrxTd_Sprite(playerid, x + w - diamX, y + h - diamY, THEME_SPRITE_CIRCLE, diamX, diamY, color);
    return 1;
}

stock TrxTd_KillCard(playerid, PlayerText:cards[], count = 6) {
    for (new index = 0; index < count; index++) {
        TrxTd_Kill(playerid, cards[index]);
    }
    return 1;
}

// Tombol pil FiveM: sprite jadi latar SEKALIGUS hitbox klik (akurat, tanpa
// quirk hitbox terpusat), label overlay di tengah tidak bisa diklik.
// Ukuran dipaksa memenuhi target sentuh minimum Android.
stock PlayerText:TrxTd_Button(playerid, &PlayerText:labelOut, Float:x, Float:y,
    Float:w, Float:h, const label[], bgColor, textColor,
    Float:lsX = 0.20, Float:lsY = 0.90,
    TEXT_DRAW_ALIGN:align = TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER) {
    if (w < TRX_TOUCH_MIN_W) w = TRX_TOUCH_MIN_W;
    if (h < TRX_TOUCH_MIN_H) h = TRX_TOUCH_MIN_H;

    new PlayerText:handle = TrxTd_Sprite(playerid, x, y, THEME_SPRITE_WHITE, w, h, bgColor, true);

    // Rata tengah = label di tengah tombol; rata kiri = label ber-indent 10px
    // (gaya list FiveM: nama item rata kiri, bukan tengah).
    new Float:labelX = x + w / 2.0;
    if (align == TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT) labelX = x + 10.0;
    new Float:labelY = y + (h - lsY * 10.0) / 2.0;
    labelOut = TrxTd_Text(playerid, labelX, labelY, label,
        THEME_FONT_BODY, lsX, lsY, textColor, align);
    return handle;
}

// Registry klik generik: handle tombol -> id aksi, supaya callback klik tinggal
// dispatch per id (tidak membandingkan handle di banyak modul).
stock bool:TrxTd_BindClick(playerid, PlayerText:handle, id) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (gTrxClickCount[playerid] >= TRX_MAX_CLICKS) {
        Log_Warn("ui", "registry klik penuh");
        return false;
    }
    gTrxClickHandle[playerid][gTrxClickCount[playerid]] = handle;
    gTrxClickId[playerid][gTrxClickCount[playerid]] = id;
    gTrxClickCount[playerid]++;
    return true;
}

stock TrxTd_ResolveClick(playerid, PlayerText:clicked) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    for (new index = 0; index < gTrxClickCount[playerid]; index++) {
        if (clicked == gTrxClickHandle[playerid][index]) {
            return gTrxClickId[playerid][index];
        }
    }
    return -1;
}

stock TrxTd_ClearClicks(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gTrxClickCount[playerid] = 0;
    return 1;
}

// Preview model 3D (font 5): dipakai pemilih skin saat buat karakter.
stock PlayerText:TrxTd_PreviewModel(playerid, Float:x, Float:y, Float:w,
    Float:h, model) {
    new PlayerText:handle = CreatePlayerTextDraw(playerid, x, y, "_");
    PlayerTextDrawFont(playerid, handle, TEXT_DRAW_FONT:TEXT_DRAW_FONT_MODEL_PREVIEW);
    PlayerTextDrawUseBox(playerid, handle, true);
    PlayerTextDrawBoxColour(playerid, handle, THEME_SURFACE);
    PlayerTextDrawTextSize(playerid, handle, w, h);
    PlayerTextDrawSetPreviewModel(playerid, handle, model);
    PlayerTextDrawSetPreviewRot(playerid, handle, -10.0, 0.0, 0.0, 1.05);
    PlayerTextDrawSetSelectable(playerid, handle, false);
    PlayerTextDrawShow(playerid, handle);
    TrxTd_CountCreate(playerid);
    return handle;
}

stock TrxTd_Kill(playerid, &PlayerText:td) {
    if (td != PlayerText:INVALID_TEXT_DRAW) {
        // Hide sebelum destroy: klien Android kadang masih menampilkan
        // textdraw yang sudah dihancurkan (render basi) sampai di-hide.
        PlayerTextDrawHide(playerid, td);
        PlayerTextDrawDestroy(playerid, td);

        // Lepas SEMUA binding klik milik handle ini. Tanpa ini registry
        // menumpuk sampai penuh (tombol baru berhenti merespons) dan handle
        // daur ulang bisa memicu aksi hantu dari modal lama.
        for (new index = 0; index < gTrxClickCount[playerid]; index++) {
            if (gTrxClickHandle[playerid][index] == td) {
                for (new shift = index;
                    shift < gTrxClickCount[playerid] - 1; shift++) {
                    gTrxClickHandle[playerid][shift] =
                        gTrxClickHandle[playerid][shift + 1];
                    gTrxClickId[playerid][shift] =
                        gTrxClickId[playerid][shift + 1];
                }
                gTrxClickCount[playerid]--;
                index--; // slot yang bergeser ke sini juga harus dicek
            }
        }

        td = PlayerText:INVALID_TEXT_DRAW;
        if (gTrxPoolUsed[playerid] > 0) gTrxPoolUsed[playerid]--;
    }
    return 1;
}

// ---------------------------------------------------------------------------
// Progress bar (track + fill) untuk aksi berdurasi: isi lebar berubah halus.
// ---------------------------------------------------------------------------
stock bool:Progress_Show(playerid, Float:x, Float:y, Float:w, Float:h) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (gTrxProgActive[playerid]) Progress_Hide(playerid);

    gTrxProgTrack[playerid] = TrxTd_Sprite(playerid, x, y, THEME_SPRITE_WHITE, w, h, THEME_GLASS);
    gTrxProgFill[playerid] = TrxTd_Sprite(playerid, x + 2.0, y + 2.0, THEME_SPRITE_WHITE, 1.0, h - 4.0, THEME_OK);
    gTrxProgX[playerid] = x + 2.0;
    gTrxProgW[playerid] = w - 4.0;
    gTrxProgActive[playerid] = true;
    return true;
}

stock Progress_Set(playerid, percent) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gTrxProgActive[playerid]) return 0;
    if (percent < 0) percent = 0;
    if (percent > 100) percent = 100;

    new Float:fillW = gTrxProgW[playerid] * float(percent) / 100.0;
    PlayerTextDrawTextSize(playerid, gTrxProgFill[playerid], fillW, 0.0);
    PlayerTextDrawShow(playerid, gTrxProgFill[playerid]); // re-show menyegarkan ukuran
    return 1;
}

stock bool:Progress_Hide(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (!gTrxProgActive[playerid]) return false;

    TrxTd_Kill(playerid, gTrxProgFill[playerid]);
    TrxTd_Kill(playerid, gTrxProgTrack[playerid]);
    gTrxProgActive[playerid] = false;
    return true;
}
