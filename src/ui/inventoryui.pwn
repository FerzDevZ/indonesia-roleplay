// ---------------------------------------------------------------------------
// module      : ui/inventoryui
// entry       : -
// depends     : ui/theme, ui/trxtdraw, ui/uimodal, ui/toast,
//               domain/inventory (Inv_*)
// owns tables : daftar kill textdraw tas, handle slot, status seleksi
// public api  : InventoryUI_Open(), InventoryUI_Destroy(), InventoryUI_IsOpen(),
//               InventoryUI_OnClick(), InventoryUI_TrackHandle(),
//               InventoryUI_SetSlotHandles(), InventoryUI_SetFooterHandles(),
//               InventoryUI_SetActionHandles(), InventoryUI_Refresh()
// Isi         : Modal TAS (UI_INVENTORY). Satu layar: grid 4x3 slot + footer
//               berat + bar aksi PAKAI/BUANG. Klik slot = seleksi via
//               update-in-place (SetColour/SetString + Show, TANPA redraw
//               penuh - aturan anti-glitch Android). PAKAI memakai barang,
//               BUANG menjatuhkan pickup fisik di dunia.
// Aturan      : Hitbox slot digambar SEBELUM konten; [X] wajib ada; kill list
//               di-track semua textdraw agar Destroy bersih.
// ---------------------------------------------------------------------------
#if defined _INC_UI_INVENTORYUI
    #endinput
#endif
#define _INC_UI_INVENTORYUI

#include "theme.pwn"
#include "trxtdraw.pwn"
#include "uimodal.pwn"

// Id aksi klik tas (slot 0-11 = 280-291).
#define INVUI_ID_SLOT0      (280)
#define INVUI_ID_USE        (292)
#define INVUI_ID_DROP       (293)
#define INVUI_ID_CLOSE      (294)

#define INVUI_MAX_TD        (96)

static bool:gInvUiOpen[MAX_PLAYERS];
static gInvUiSelected[MAX_PLAYERS] = { -1, ... };

static PlayerText:gInvTd[MAX_PLAYERS][INVUI_MAX_TD];
static gInvTdCount[MAX_PLAYERS];

// Handle slot untuk update-in-place (box, glyph, qty).
static PlayerText:gInvSlotBox[MAX_PLAYERS][INV_MAX_SLOTS];
static PlayerText:gInvSlotGlyph[MAX_PLAYERS][INV_MAX_SLOTS];
static PlayerText:gInvSlotQty[MAX_PLAYERS][INV_MAX_SLOTS];

// Handle footer + bar aksi.
static PlayerText:gInvWeightTd[MAX_PLAYERS];
static PlayerText:gInvDetailTd[MAX_PLAYERS];
static PlayerText:gInvUseBtn[MAX_PLAYERS];
static PlayerText:gInvUseLabel[MAX_PLAYERS];
static PlayerText:gInvDropBtn[MAX_PLAYERS];
static PlayerText:gInvDropLabel[MAX_PLAYERS];

stock InventoryUI_TrackHandle(playerid, PlayerText:handle) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gInvTdCount[playerid] >= INVUI_MAX_TD) {
        Log_Warn("ui", "daftar tas penuh");
        return 0;
    }
    gInvTd[playerid][gInvTdCount[playerid]++] = handle;
    return 1;
}

stock InventoryUI_SetSlotHandles(playerid, slot, PlayerText:box,
    PlayerText:glyph, PlayerText:qty) {
    if (slot < 0 || slot >= INV_MAX_SLOTS) return 0;
    gInvSlotBox[playerid][slot] = box;
    gInvSlotGlyph[playerid][slot] = glyph;
    gInvSlotQty[playerid][slot] = qty;
    return 1;
}

stock InventoryUI_SetFooterHandles(playerid, PlayerText:weightTd,
    PlayerText:detailTd) {
    gInvWeightTd[playerid] = weightTd;
    gInvDetailTd[playerid] = detailTd;
    return 1;
}

stock InventoryUI_SetActionHandles(playerid, PlayerText:useBtn,
    PlayerText:useLabel, PlayerText:dropBtn, PlayerText:dropLabel) {
    gInvUseBtn[playerid] = useBtn;
    gInvUseLabel[playerid] = useLabel;
    gInvDropBtn[playerid] = dropBtn;
    gInvDropLabel[playerid] = dropLabel;
    return 1;
}

stock bool:InventoryUI_IsOpen(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gInvUiOpen[playerid];
}

// Segarkan seluruh isi grid + footer + bar aksi secara update-in-place.
stock InventoryUI_Refresh(playerid) {
    if (!gInvUiOpen[playerid]) return 0;

    for (new slot = 0; slot < INV_MAX_SLOTS; slot++) {
        new item = Inv_SlotItem(playerid, slot);
        new qty = Inv_SlotQty(playerid, slot);

        new boxColor = (slot == gInvUiSelected[playerid])
            ? THEME_HOVER : THEME_BG_SOFT;
        PlayerTextDrawBoxColour(playerid, gInvSlotBox[playerid][slot], boxColor);
        PlayerTextDrawShow(playerid, gInvSlotBox[playerid][slot]);

        new glyph[2];
        if (item >= 0) {
            Inv_ItemGlyph(item, glyph, sizeof (glyph));
            PlayerTextDrawSetString(playerid, gInvSlotGlyph[playerid][slot],
                glyph);
            PlayerTextDrawColour(playerid, gInvSlotGlyph[playerid][slot],
                Inv_ItemColor(item));
        } else {
            PlayerTextDrawSetString(playerid, gInvSlotGlyph[playerid][slot], " ");
        }
        PlayerTextDrawShow(playerid, gInvSlotGlyph[playerid][slot]);

        new qtyText[8];
        if (qty > 1) format(qtyText, sizeof (qtyText), "x%d", qty);
        else qtyText[0] = '\0';
        PlayerTextDrawSetString(playerid, gInvSlotQty[playerid][slot], qtyText);
        PlayerTextDrawShow(playerid, gInvSlotQty[playerid][slot]);
    }

    // Footer: berat total + nama barang terpilih.
    new weightText[40];
    format(weightText, sizeof (weightText), "BERAT %.1f/%.1f KG",
        Inv_TotalWeight(playerid), Inv_MaxWeight());
    PlayerTextDrawSetString(playerid, gInvWeightTd[playerid], weightText);
    PlayerTextDrawShow(playerid, gInvWeightTd[playerid]);

    new detail[48];
    if (gInvUiSelected[playerid] >= 0) {
        new item = Inv_SlotItem(playerid, gInvUiSelected[playerid]);
        if (item >= 0) {
            new itemName[20];
            Inv_ItemName(item, itemName, sizeof (itemName));
            format(detail, sizeof (detail), "%s - %.1f KG", itemName,
                Inv_ItemWeight(item));
        } else {
            format(detail, sizeof (detail), "PILIH BARANG");
        }
    } else {
        format(detail, sizeof (detail), "PILIH BARANG");
    }
    PlayerTextDrawSetString(playerid, gInvDetailTd[playerid], detail);
    PlayerTextDrawShow(playerid, gInvDetailTd[playerid]);

    // Bar aksi hanya tampil saat ada seleksi.
    if (gInvUiSelected[playerid] >= 0) {
        PlayerTextDrawShow(playerid, gInvUseBtn[playerid]);
        PlayerTextDrawShow(playerid, gInvUseLabel[playerid]);
        PlayerTextDrawShow(playerid, gInvDropBtn[playerid]);
        PlayerTextDrawShow(playerid, gInvDropLabel[playerid]);
    } else {
        PlayerTextDrawHide(playerid, gInvUseBtn[playerid]);
        PlayerTextDrawHide(playerid, gInvUseLabel[playerid]);
        PlayerTextDrawHide(playerid, gInvDropBtn[playerid]);
        PlayerTextDrawHide(playerid, gInvDropLabel[playerid]);
    }
    return 1;
}

stock InventoryUI_Open(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (Character_GetId(playerid) < 1) return 0;
    if (gInvUiOpen[playerid]) return 1;

    if (!UIModal_Open(playerid, UI_INVENTORY)) return 0;
    gInvUiOpen[playerid] = true;
    gInvUiSelected[playerid] = -1;

    InventoryDraw_Grid(playerid);
    InventoryUI_Refresh(playerid);
    SelectTextDraw(playerid, THEME_ACCENT);
    return 1;
}

stock InventoryUI_Destroy(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gInvUiOpen[playerid] && gInvTdCount[playerid] == 0) return 0;

    for (new index = 0; index < gInvTdCount[playerid]; index++) {
        TrxTd_Kill(playerid, gInvTd[playerid][index]);
    }
    gInvTdCount[playerid] = 0;
    gInvUiOpen[playerid] = false;
    gInvUiSelected[playerid] = -1;
    CancelSelectTextDraw(playerid);
    return 1;
}

stock bool:InventoryUI_OnClick(playerid, PlayerText:clicked) {
    if (!gInvUiOpen[playerid]) return false;

    new action = TrxTd_ResolveClick(playerid, clicked);
    if (action >= INVUI_ID_SLOT0 && action < INVUI_ID_SLOT0 + INV_MAX_SLOTS) {
        new slot = action - INVUI_ID_SLOT0;
        if (Inv_SlotItem(playerid, slot) < 0) return true; // slot kosong
        gInvUiSelected[playerid] = (gInvUiSelected[playerid] == slot) ? -1 : slot;
        InventoryUI_Refresh(playerid);
        return true;
    }
    switch (action) {
        case INVUI_ID_USE: {
            if (gInvUiSelected[playerid] < 0) return true;
            Inv_UseSlot(playerid, gInvUiSelected[playerid]);
            gInvUiSelected[playerid] = -1;
            InventoryUI_Refresh(playerid);
            return true;
        }
        case INVUI_ID_DROP: {
            if (gInvUiSelected[playerid] < 0) return true;
            Inv_DropSlot(playerid, gInvUiSelected[playerid]);
            gInvUiSelected[playerid] = -1;
            InventoryUI_Refresh(playerid);
            return true;
        }
        case INVUI_ID_CLOSE: {
            UIModal_Close(playerid);
            return true;
        }
    }
    return false;
}
