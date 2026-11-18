// ---------------------------------------------------------------------------
// module      : ui/warungui_draw
// entry       : -
// depends     : ui/theme, ui/trxtdraw, ui/warungui (state + track),
//               domain/warung (akses baca menu), domain/inventory (katalog)
// owns tables : -
// public api  : WarungDraw_Shop()
// Isi         : Panel toko gaya e-commerce FiveM: TrxTd_Panel (bayangan +
//               garis rambut + kaca + judul + [X]), kartu item grid 2x4
//               (chip glyph warna + nama + harga), footer saldo tunai live
//               + petunjuk "KLIK BARANG = BELI 1".
// Aturan      : Hitbox kartu dulu, konten kemudian; tanpa warna literal.
// ---------------------------------------------------------------------------
#if defined _INC_UI_WARUNGUI_DRAW
    #endinput
#endif
#define _INC_UI_WARUNGUI_DRAW

#include "theme.pwn"

// Geometri panel toko.
#define SHOOP_X             (170.0)
#define SHOP_X              (170.0)
#define SHOP_Y              (90.0)
#define SHOP_W              (300.0)
#define SHOP_H              (340.0)

// Kartu item 2 kolom x 4 baris.
#define SHOPCARD_W          (140.0)
#define SHOPCARD_H          (58.0)
#define SHOPCARD_STEP_X     (146.0)
#define SHOPCARD_STEP_Y     (64.0)
#define SHOPCARD_X0         (SHOP_X + 8.0)
#define SHOPCARD_Y0         (SHOP_Y + 48.0)

// Satu kartu item: kotak hitbox + chip glyph + nama + harga.
static DrawCard(playerid, slot) {
    new Float:x = SHOPCARD_X0 + SHOPCARD_STEP_X * (slot % 2);
    new Float:y = SHOPCARD_Y0 + SHOPCARD_STEP_Y * (slot / 2);

    new PlayerText:card = TrxTd_Box(playerid, x, y, x + SHOPCARD_W,
        SHOPCARD_H, THEME_BG_SOFT);
    PlayerTextDrawSetSelectable(playerid, card, true);
    WarungUI_TrackHandle(playerid, card);
    TrxTd_BindClick(playerid, card, SHOPUI_ID_ROW0 + slot);

    new PlayerText:chip = TrxTd_Box(playerid, x + 6.0, y + 6.0, x + 24.0,
        18.0, THEME_ELEVATED);
    WarungUI_TrackHandle(playerid, chip);

    new PlayerText:chipLbl = TrxTd_Text(playerid, x + 15.0, y + 8.0, " ",
        THEME_FONT_LABEL, 0.16, 0.80, THEME_TEXT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    WarungUI_TrackHandle(playerid, chipLbl);

    new PlayerText:name = TrxTd_Text(playerid, x + 30.0, y + 8.0, "-",
        THEME_FONT_BODY, 0.15, 0.75, THEME_TEXT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    WarungUI_TrackHandle(playerid, name);

    new PlayerText:price = TrxTd_Text(playerid, x + 6.0, y + 36.0, "-",
        THEME_FONT_LABEL, 0.15, 0.80, THEME_ACCENT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    WarungUI_TrackHandle(playerid, price);

    WarungUI_SetCardHandles(playerid, slot, card, chipLbl, name, price);
    return 1;
}

// Panel toko lengkap: header (judul = nama warung), grid kartu, footer tunai.
stock WarungDraw_Shop(playerid, warung) {
    new PlayerText:panel[TRX_PANEL_MAX_TD];
    new PlayerText:closeBtn = PlayerText:0, PlayerText:closeLbl = PlayerText:0;
    new warungName[WAR_NAME_LEN];
    Warung_NameOf(warung, warungName);

    new count = TrxTd_Panel(playerid, panel, SHOP_X, SHOP_Y, SHOP_W, SHOP_H,
        warungName, SHOPUI_ID_CLOSE, closeBtn, closeLbl);
    for (new index = 0; index < count; index++) {
        WarungUI_TrackHandle(playerid, panel[index]);
    }

    new rows = Warung_ItemCountOf(warung);
    if (rows > SHOPUI_MAX_ROWS) rows = SHOPUI_MAX_ROWS;
    for (new slot = 0; slot < SHOPUI_MAX_ROWS; slot++) {
        DrawCard(playerid, slot);
        if (slot >= rows) continue;

        new itemCode[WAR_ITEM_CODE_LEN];
        Warung_ItemCodeOf(warung, slot, itemCode, sizeof (itemCode));
        new item = Inv_ItemFromCode(itemCode);
        if (item < 0) {
            WarungUI_SetCardText(playerid, slot, " ", THEME_MUTED, itemCode,
                "-");
            continue;
        }
        new glyph[2], itemName[20], priceText[24];
        Inv_ItemGlyph(item, glyph, sizeof (glyph));
        Inv_ItemName(item, itemName, sizeof (itemName));
        Messages_Money(Warung_ItemPriceOf(warung, slot), priceText,
            sizeof (priceText));
        WarungUI_SetCardText(playerid, slot, glyph, Inv_ItemColor(item),
            itemName, priceText);
    }

    // Footer: tunai kiri, petunjuk kanan.
    new PlayerText:cashTd = TrxTd_Text(playerid, SHOPCARD_X0, SHOP_Y + 312.0,
        "TUNAI -", THEME_FONT_LABEL, 0.14, 0.80, THEME_TEXT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    WarungUI_TrackHandle(playerid, cashTd);
    WarungUI_SetCashHandle(playerid, cashTd);

    new PlayerText:hint = TrxTd_Text(playerid, SHOP_X + SHOP_W - 8.0,
        SHOP_Y + 314.0, "KLIK BARANG = BELI 1", THEME_FONT_BODY, 0.11, 0.60,
        THEME_MUTED, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_RIGHT);
    WarungUI_TrackHandle(playerid, hint);
    return 1;
}
