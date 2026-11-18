// ---------------------------------------------------------------------------
// module      : ui/bankui
// entry       : BankUI_OpenAtm() / BankUI_OpenPhone()
// depends     : ui/theme, ui/trxtdraw, ui/uimodal, ui/toast, shared/money,
//               shared/messages, core/db
// owns tables : -
// public api  : BankUI_OpenAtm(), BankUI_OpenPhone(), BankUI_Destroy(),
//               BankUI_IsOpen(), BankUI_OnClick(), BankUI_OnDialogResponse()
// Sumber      : ATM (semua tombol aktif) atau HP (setor/tarik terkunci -
//               tunai fisik hanya di ATM, sesuai alur docs/11).
// Aturan      : Update teks lewat SetString, tanpa redraw penuh di callback.
// ---------------------------------------------------------------------------
#if defined _INC_UI_BANKUI
    #endinput
#endif
#define _INC_UI_BANKUI

#include "theme.pwn"
#include "uimodal.pwn"

#define BANK_SRC_ATM        (0)
#define BANK_SRC_PHONE      (1)

#define BANKC_X             (210.0)
#define BANKC_Y             (90.0)
#define BANKC_W             (220.0)
#define BANKC_H             (300.0)
#define BANKC_BTN_X         (BANKC_X + 20.0)
#define BANKC_BTN_W         (180.0)
#define BANKC_BTN_H         (26.0)
#define BANKC_ROW_STEP      (34.0)

#define BANKUI_ID_SETOR     (260)
#define BANKUI_ID_TARIK     (261)
#define BANKUI_ID_TRANSFER  (262)
#define BANKUI_ID_MUTASI    (263)
#define BANKUI_ID_CLOSE     (264)

#define BANK_OP_NONE        (0)
#define BANK_OP_DEPOSIT     (1)
#define BANK_OP_WITHDRAW    (2)
#define BANK_OP_TRANSFER    (3)

static bool:gBankOpen[MAX_PLAYERS];
static gBankSource[MAX_PLAYERS];
static gBankOp[MAX_PLAYERS];            // operasi yang menunggu input jumlah
static gBankTargetId[MAX_PLAYERS];      // karakter tujuan transfer (hasil cari nama)

static PlayerText:gBankPanel[MAX_PLAYERS][TRX_PANEL_MAX_TD];
static gBankPanelCount[MAX_PLAYERS];
static PlayerText:gBankSaldoLbl[MAX_PLAYERS];
static PlayerText:gBankSaldoVal[MAX_PLAYERS];
static PlayerText:gBankTunaiLbl[MAX_PLAYERS];
static PlayerText:gBankTunaiVal[MAX_PLAYERS];
static PlayerText:gBankBtnSetor[MAX_PLAYERS];
static PlayerText:gBankLblSetor[MAX_PLAYERS];
static PlayerText:gBankBtnTarik[MAX_PLAYERS];
static PlayerText:gBankLblTarik[MAX_PLAYERS];
static PlayerText:gBankBtnTransfer[MAX_PLAYERS];
static PlayerText:gBankLblTransfer[MAX_PLAYERS];
static PlayerText:gBankBtnMutasi[MAX_PLAYERS];
static PlayerText:gBankLblMutasi[MAX_PLAYERS];
static PlayerText:gBankBtnClose[MAX_PLAYERS];
static PlayerText:gBankLblClose[MAX_PLAYERS];

stock bool:BankUI_IsOpen(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gBankOpen[playerid];
}

stock bool:BankUI_OpenAtm(playerid) {
    return BankUI_Open(playerid, BANK_SRC_ATM);
}

stock bool:BankUI_OpenPhone(playerid) {
    return BankUI_Open(playerid, BANK_SRC_PHONE);
}

static bool:BankUI_Open(playerid, source) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (!Phase_CanAct(playerid)) return false;
    if (gBankOpen[playerid]) BankUI_Destroy(playerid);
    if (!UIModal_Open(playerid, UI_BANK)) return false;

    gBankSource[playerid] = source;
    gBankOp[playerid] = BANK_OP_NONE;
    gBankTargetId[playerid] = -1;

    // Panel modal FiveM: bayangan + garis rambut + kaca + header + [X].
    gBankPanelCount[playerid] = TrxTd_Panel(playerid, gBankPanel[playerid],
        BANKC_X, BANKC_Y, BANKC_W, BANKC_H, "BANK NUSANTARA",
        BANKUI_ID_CLOSE, gBankBtnClose[playerid], gBankLblClose[playerid]);

    gBankSaldoLbl[playerid] = TrxTd_Text(playerid, BANKC_X + 20.0, BANKC_Y + 46.0,
        "SALDO REKENING", THEME_FONT_BODY, 0.16, 0.70, THEME_MUTED,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gBankSaldoVal[playerid] = TrxTd_Text(playerid, BANKC_X + 20.0, BANKC_Y + 62.0,
        "-", THEME_FONT_LABEL, 0.26, 1.00, THEME_OK,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gBankTunaiLbl[playerid] = TrxTd_Text(playerid, BANKC_X + 20.0, BANKC_Y + 88.0,
        "TUNAI", THEME_FONT_BODY, 0.16, 0.70, THEME_MUTED,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gBankTunaiVal[playerid] = TrxTd_Text(playerid, BANKC_X + 20.0, BANKC_Y + 104.0,
        "-", THEME_FONT_LABEL, 0.26, 1.00, THEME_TEXT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);

    // Empat tombol vertikal. Setor/tarik hanya aktif di ATM (tunai fisik).
    gBankBtnSetor[playerid] = TrxTd_Button(playerid, gBankLblSetor[playerid],
        BANKC_BTN_X, BANKC_Y + 140.0, BANKC_BTN_W, BANKC_BTN_H, "SETOR TUNAI",
        THEME_ELEVATED, THEME_TEXT, 0.20, 0.85,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    TrxTd_BindClick(playerid, gBankBtnSetor[playerid], BANKUI_ID_SETOR);

    gBankBtnTarik[playerid] = TrxTd_Button(playerid, gBankLblTarik[playerid],
        BANKC_BTN_X, BANKC_Y + 140.0 + BANKC_ROW_STEP, BANKC_BTN_W, BANKC_BTN_H,
        "TARIK TUNAI", THEME_ELEVATED, THEME_TEXT, 0.20, 0.85,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    TrxTd_BindClick(playerid, gBankBtnTarik[playerid], BANKUI_ID_TARIK);

    // Dari HP: setor/tarik terkunci (tunai fisik hanya di mesin ATM) -
    // tampil redup gaya FiveM, bukan tombol terang yang menolak saat diklik.
    if (source == BANK_SRC_PHONE) {
        PlayerTextDrawColour(playerid, gBankBtnSetor[playerid], THEME_MUTED);
        PlayerTextDrawColour(playerid, gBankLblSetor[playerid], THEME_MUTED);
        PlayerTextDrawColour(playerid, gBankBtnTarik[playerid], THEME_MUTED);
        PlayerTextDrawColour(playerid, gBankLblTarik[playerid], THEME_MUTED);
    }

    gBankBtnTransfer[playerid] = TrxTd_Button(playerid, gBankLblTransfer[playerid],
        BANKC_BTN_X, BANKC_Y + 140.0 + BANKC_ROW_STEP * 2, BANKC_BTN_W, BANKC_BTN_H,
        "TRANSFER", THEME_ELEVATED, THEME_TEXT, 0.20, 0.85,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    TrxTd_BindClick(playerid, gBankBtnTransfer[playerid], BANKUI_ID_TRANSFER);

    gBankBtnMutasi[playerid] = TrxTd_Button(playerid, gBankLblMutasi[playerid],
        BANKC_BTN_X, BANKC_Y + 140.0 + BANKC_ROW_STEP * 3, BANKC_BTN_W, BANKC_BTN_H,
        "MUTASI 10", THEME_ELEVATED, THEME_TEXT, 0.20, 0.85,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    TrxTd_BindClick(playerid, gBankBtnMutasi[playerid], BANKUI_ID_MUTASI);

    gBankBtnClose[playerid] = PlayerText:INVALID_TEXT_DRAW;
    gBankLblClose[playerid] = PlayerText:INVALID_TEXT_DRAW;

    gBankOpen[playerid] = true;
    BankUI_Refresh(playerid);
    SelectTextDraw(playerid, THEME_ACCENT);
    return true;
}

// Update dua angka saldo di tempat - tanpa redraw penuh.
stock BankUI_Refresh(playerid) {
    if (!gBankOpen[playerid]) return 0;

    new saldo[24], tunai[24], line[40];
    Messages_Money(Money_GetBank(playerid), saldo, sizeof (saldo));
    Messages_Money(Money_GetCash(playerid), tunai, sizeof (tunai));
    format(line, sizeof (line), "Rp %s", saldo);
    PlayerTextDrawSetString(playerid, gBankSaldoVal[playerid], line);
    format(line, sizeof (line), "Rp %s", tunai);
    PlayerTextDrawSetString(playerid, gBankTunaiVal[playerid], line);
    return 1;
}

stock BankUI_Destroy(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gBankOpen[playerid]) return 0;

    CancelSelectTextDraw(playerid);
    TrxTd_Kill(playerid, gBankLblClose[playerid]);
    TrxTd_Kill(playerid, gBankBtnClose[playerid]);
    TrxTd_Kill(playerid, gBankBtnMutasi[playerid]);
    TrxTd_Kill(playerid, gBankLblTransfer[playerid]);
    TrxTd_Kill(playerid, gBankBtnTransfer[playerid]);
    TrxTd_Kill(playerid, gBankLblTarik[playerid]);
    TrxTd_Kill(playerid, gBankBtnTarik[playerid]);
    TrxTd_Kill(playerid, gBankLblSetor[playerid]);
    TrxTd_Kill(playerid, gBankBtnSetor[playerid]);
    TrxTd_Kill(playerid, gBankTunaiVal[playerid]);
    TrxTd_Kill(playerid, gBankTunaiLbl[playerid]);
    TrxTd_Kill(playerid, gBankSaldoVal[playerid]);
    TrxTd_Kill(playerid, gBankSaldoLbl[playerid]);
    for (new index = 0; index < gBankPanelCount[playerid]; index++) {
        TrxTd_Kill(playerid, gBankPanel[playerid][index]);
    }
    gBankPanelCount[playerid] = 0;
    gBankOpen[playerid] = false;
    gBankOp[playerid] = BANK_OP_NONE;
    gBankTargetId[playerid] = -1;
    return 1;
}

stock bool:BankUI_OnClick(playerid, PlayerText:clicked) {
    if (!gBankOpen[playerid]) return false;

    new action = TrxTd_ResolveClick(playerid, clicked);
    switch (action) {
        case BANKUI_ID_CLOSE: {
            UIModal_Close(playerid);
            return true;
        }
        case BANKUI_ID_SETOR: {
            if (gBankSource[playerid] != BANK_SRC_ATM) {
                Toast_Show(playerid, "M-BANKING",
                    "Setor tunai hanya di ATM.", THEME_DANGER);
                return true;
            }
            gBankOp[playerid] = BANK_OP_DEPOSIT;
            BankUI_AskAmount(playerid, "SETOR TUNAI");
            return true;
        }
        case BANKUI_ID_TARIK: {
            if (gBankSource[playerid] != BANK_SRC_ATM) {
                Toast_Show(playerid, "M-BANKING",
                    "Tarik tunai hanya di ATM.", THEME_DANGER);
                return true;
            }
            gBankOp[playerid] = BANK_OP_WITHDRAW;
            BankUI_AskAmount(playerid, "TARIK TUNAI");
            return true;
        }
        case BANKUI_ID_TRANSFER: {
            gBankOp[playerid] = BANK_OP_TRANSFER;
            gBankTargetId[playerid] = -1;
            ShowPlayerDialog(playerid, _:DIALOG_BANK_TARGET, DIALOG_STYLE_INPUT,
                "Transfer Rekening",
                "Masukkan nama lengkap penerima\n(contoh: Budi Santoso):",
                "Lanjut", "Batal");
            return true;
        }
        case BANKUI_ID_MUTASI: {
            BankUI_ShowMutasi(playerid);
            return true;
        }
    }
    return false;
}

static BankUI_AskAmount(playerid, const title[]) {
    ShowPlayerDialog(playerid, _:DIALOG_BANK_AMOUNT, DIALOG_STYLE_INPUT,
        title, "Masukkan jumlah (Rp 1.000 - 50.000.000):", "Proses", "Batal");
}

// Daftar 10 mutasi terakhir dari money_log (semua wallet).
static BankUI_ShowMutasi(playerid) {
    new query[192];
    format(query, sizeof (query),
        "SELECT delta, reason, wallet FROM money_log WHERE character_id = %d \
         ORDER BY rowid DESC LIMIT 10", Money_CharacterId(playerid));
    new total = DB_Rows(query);
    if (total < 1) {
        ShowPlayerDialog(playerid, _:DIALOG_BANK_MUTASI, DIALOG_STYLE_MSGBOX,
            "Mutasi Rekening", "Belum ada transaksi.", "Tutup", "");
        return 1;
    }

    new body[1024], line[96], reason[32], wallet[8], money[24];
    for (new row = 0; row < total; row++) {
        format(query, sizeof (query),
            "SELECT delta, reason, wallet FROM money_log WHERE character_id = %d \
             ORDER BY rowid DESC LIMIT 10", Money_CharacterId(playerid));
        new delta = DB_IntAt(query, row, 0);
        DB_StrAt(query, row, 1, reason, sizeof (reason));
        DB_StrAt(query, row, 2, wallet, sizeof (wallet));

        Messages_Money(delta < 0 ? -delta : delta, money, sizeof (money));
        format(line, sizeof (line), "%s Rp %s  -  %s (%s)\n",
            delta < 0 ? "-" : "+", money, reason,
            strcmp(wallet, WALLET_BANK, false) == 0 ? "bank" : "tunai");
        strcat(body, line);
    }
    ShowPlayerDialog(playerid, _:DIALOG_BANK_MUTASI, DIALOG_STYLE_MSGBOX,
        "Mutasi Rekening", body, "Tutup", "");
    return 1;
}

// Return true kalau dialog ini milik bankui.
stock bool:BankUI_OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    #pragma unused listitem

    if (dialogid == DIALOG_BANK_MUTASI) return true; // hanya informasi

    if (dialogid == DIALOG_BANK_TARGET) {
        if (!response) return true;
        if (!gBankOpen[playerid]) return true;
        // Salin dulu ke lokal: parameter publik tidak boleh diteruskan langsung
        // ke parameter const (pawncc warning 214).
        new inputCopy[64];
        format(inputCopy, sizeof (inputCopy), "%s", inputtext);
        BankUI_FindTarget(playerid, inputCopy);
        return true;
    }
    if (dialogid == DIALOG_BANK_AMOUNT) {
        if (!response) {
            gBankOp[playerid] = BANK_OP_NONE;
            return true;
        }
        if (!gBankOpen[playerid]) return true;
        new amountCopy[16];
        format(amountCopy, sizeof (amountCopy), "%s", inputtext);
        BankUI_ProcessAmount(playerid, amountCopy);
        return true;
    }
    return false;
}

// Cari karakter penerima berdasar nama lengkap (first + space + last).
static bool:BankUI_FindTarget(playerid, const input[]) {
    new safe[64];
    DB_Escape(safe, sizeof (safe), input);

    new query[256];
    format(query, sizeof (query),
        "SELECT character_id, first_name || ' ' || last_name AS full_name \
         FROM characters WHERE deleted_at IS NULL \
         AND REPLACE(first_name || ' ' || last_name, '_', ' ') LIKE '%%%s%%' \
         COLLATE NOCASE LIMIT 1", safe);

    new targetId = DB_Int(query, -1);
    if (targetId < 1) {
        Toast_Show(playerid, "TRANSFER", "Penerima tidak ditemukan.", THEME_DANGER);
        gBankOp[playerid] = BANK_OP_NONE;
        return false;
    }

    gBankTargetId[playerid] = targetId;
    BankUI_AskAmount(playerid, "TRANSFER");
    return true;
}

static bool:BankUI_ProcessAmount(playerid, const input[]) {
    new amount = strval(input);
    if (amount < BANK_AMOUNT_MINIMUM || amount > BANK_AMOUNT_MAXIMUM) {
        Toast_Show(playerid, "M-BANKING",
            "Jumlah harus Rp 1.000 - 50.000.000.", THEME_DANGER);
        return false;
    }

    new op = gBankOp[playerid];
    gBankOp[playerid] = BANK_OP_NONE;

    if (op == BANK_OP_DEPOSIT) {
        if (!Money_Deposit(playerid, amount)) {
            Toast_Show(playerid, "SETOR", "Tunai tidak cukup.", THEME_DANGER);
            return false;
        }
        Toast_Show(playerid, "SETOR", "Setoran masuk rekening.", THEME_OK);
    } else if (op == BANK_OP_WITHDRAW) {
        if (!Money_Withdraw(playerid, amount)) {
            Toast_Show(playerid, "TARIK", "Saldo rekening tidak cukup.", THEME_DANGER);
            return false;
        }
        Toast_Show(playerid, "TARIK", "Uang tunai keluar.", THEME_OK);
    } else if (op == BANK_OP_TRANSFER) {
        new targetId = gBankTargetId[playerid];
        gBankTargetId[playerid] = -1;
        if (targetId < 1) return false;

        new fee = Money_BankFee(amount);
        if (Money_GetBank(playerid) < amount + fee) {
            Toast_Show(playerid, "TRANSFER",
                "Saldo tidak cukup (termasuk biaya admin).", THEME_DANGER);
            return false;
        }
        if (!Money_BankTransfer(playerid, targetId, amount)) {
            Toast_Show(playerid, "TRANSFER", "Transfer gagal.", THEME_DANGER);
            return false;
        }
        new detail[96], money[24];
        Messages_Money(fee, money, sizeof (money));
        format(detail, sizeof (detail), "Terkirim. Biaya admin Rp %s.", money);
        Toast_Show(playerid, "TRANSFER", detail, THEME_OK);
    }
    BankUI_Refresh(playerid);
    return true;
}
