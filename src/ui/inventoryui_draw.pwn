// ---------------------------------------------------------------------------
// module      : ui/inventoryui_draw
// entry       : -
// depends     : ui/theme, ui/trxtdraw, ui/inventoryui (state + track),
//               domain/inventory (katalog barang)
// owns tables : -
// public api  : InventoryDraw_Grid()
// Isi         : Panel TAS gaya FiveM: bayangan + kaca gelap ber-garis rambut,
//               header judul uppercase + garis aksen, grid 4x3 slot flat
//               (kotak + glyph warna + jumlah), footer berat + nama barang,
//               bar aksi PAKAI/BUANG (tampil saat slot terpilih).
// Aturan      : Tanpa warna literal (token THEME_*); hitbox = kotak slot.
// ---------------------------------------------------------------------------
#if defined _INC_UI_INVENTORYUI_DRAW
    #endinput
#endif
#define _INC_UI_INVENTORYUI_DRAW

#include "theme.pwn"

// Geometri panel tas (tengah-kanan layar, tidak menabrak HUD kiri).
#define INVP_X              (190.0)
#define INVP_Y              (110.0)
#define INVP_W              (250.0)
#define INVP_H              (270.0)

// Grid slot 4x3.
#define INVSLOT_W           (54.0)
#define INVSLOT_H           (56.0)
#define INVSLOT_STEP_X      (60.0)
#define INVSLOT_STEP_Y      (62.0)
#define INVSLOT_X0          (INVP_X + 8.0)
#define INVSLOT_Y0          (INVP_Y + 40.0)

// Satu slot: kotak latar (hitbox) + glyph warna + jumlah.
static DrawSlot(playerid, slot) {
    new Float:x = INVSLOT_X0 + INVSLOT_STEP_X * (slot % 4);
    new Float:y = INVSLOT_Y0 + INVSLOT_STEP_Y * (slot / 4);

    new PlayerText:box = TrxTd_Box(playerid, x, y, x + INVSLOT_W,
        INVSLOT_H, THEME_BG_SOFT);
    PlayerTextDrawSetSelectable(playerid, box, true);
    InventoryUI_TrackHandle(playerid, box);
    TrxTd_BindClick(playerid, box, INVUI_ID_SLOT0 + slot);

    new PlayerText:glyph = TrxTd_Text(playerid, x + INVSLOT_W / 2.0, y + 12.0,
        " ", THEME_FONT_LABEL, 0.26, 1.20, THEME_TEXT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    InventoryUI_TrackHandle(playerid, glyph);

    new PlayerText:qty = TrxTd_Text(playerid, x + 4.0, y + 42.0, "",
        THEME_FONT_BODY, 0.13, 0.55, THEME_MUTED);
    InventoryUI_TrackHandle(playerid, qty);

    InventoryUI_SetSlotHandles(playerid, slot, box, glyph, qty);
    return 1;
}

// Panel utama tas: TrxTd_Panel (bayangan + garis rambut + kaca + header + [X])
// lalu grid 4x3 + footer berat + bar aksi PAKAI/BUANG.
stock InventoryDraw_Grid(playerid) {
    new PlayerText:panel[TRX_PANEL_MAX_TD];
    new PlayerText:closeBtn = PlayerText:0, PlayerText:closeLbl = PlayerText:0;
    new count = TrxTd_Panel(playerid, panel, INVP_X, INVP_Y, INVP_W, INVP_H,
        "TAS", INVUI_ID_CLOSE, closeBtn, closeLbl);
    for (new index = 0; index < count; index++) {
        InventoryUI_TrackHandle(playerid, panel[index]);
    }

    // Grid 4x3.
    for (new slot = 0; slot < INV_MAX_SLOTS; slot++) {
        DrawSlot(playerid, slot);
    }

    // Footer: berat kiri, nama barang terpilih kanan.
    new PlayerText:weightTd = TrxTd_Text(playerid, INVSLOT_X0, INVP_Y + 226.0,
        "BERAT 0.0/20.0 KG", THEME_FONT_LABEL, 0.12, 0.62, THEME_MUTED);
    InventoryUI_TrackHandle(playerid, weightTd);
    new PlayerText:detailTd = TrxTd_Text(playerid, INVP_X + INVP_W - 8.0,
        INVP_Y + 226.0, "PILIH BARANG", THEME_FONT_BODY, 0.15, 0.72,
        THEME_TEXT, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_RIGHT);
    InventoryUI_TrackHandle(playerid, detailTd);
    InventoryUI_SetFooterHandles(playerid, weightTd, detailTd);

    // Bar aksi: PAKAI + BUANG (disembunyikan sampai slot terpilih).
    new PlayerText:useLabel = PlayerText:0, PlayerText:dropLabel = PlayerText:0;
    new PlayerText:useBtn = TrxTd_Button(playerid, useLabel, INVSLOT_X0,
        INVP_Y + 242.0, 70.0, 24.0, "PAKAI", THEME_OK, THEME_WHITE, 0.18, 0.85);
    TrxTd_BindClick(playerid, useBtn, INVUI_ID_USE);
    new PlayerText:dropBtn = TrxTd_Button(playerid, dropLabel,
        INVSLOT_X0 + 78.0, INVP_Y + 242.0, 70.0, 24.0, "BUANG", THEME_DANGER,
        THEME_WHITE, 0.18, 0.85);
    TrxTd_BindClick(playerid, dropBtn, INVUI_ID_DROP);
    InventoryUI_TrackHandle(playerid, useBtn);
    InventoryUI_TrackHandle(playerid, useLabel);
    InventoryUI_TrackHandle(playerid, dropBtn);
    InventoryUI_TrackHandle(playerid, dropLabel);
    PlayerTextDrawHide(playerid, useBtn);
    PlayerTextDrawHide(playerid, useLabel);
    PlayerTextDrawHide(playerid, dropBtn);
    PlayerTextDrawHide(playerid, dropLabel);
    InventoryUI_SetActionHandles(playerid, useBtn, useLabel, dropBtn, dropLabel);
    return 1;
}
