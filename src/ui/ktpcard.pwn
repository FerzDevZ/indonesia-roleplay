// ---------------------------------------------------------------------------
// module      : ui/ktpcard
// entry       : KtpCard_Show()
// depends     : ui/theme, ui/trxtdraw, ui/uimodal
// owns tables : -
// public api  : KtpCard_Show(), KtpCard_Destroy(), KtpCard_IsOpen(),
//               KtpCard_OnClick()
// Tampilan    : replika e-KTP Indonesia: kartu terang, header "PROVINSI DKI
//               JAKARTA" navy, foto pas di kiri dengan NIK 16 digit di bawah,
//               dua kolom isian label-nilai (biru dinas : gelap), blok alamat,
//               baris Kewarganegaraan WNI + Berlaku Hingga SEUMUR HIDUP.
// Aturan      : modal lewat UIModal_Open(UI_KTPCARD); isi kartu disusun
//               domain/identity; klik tombol tutup ditangani di sini.
// ---------------------------------------------------------------------------
#if defined _INC_UI_KTPCARD
    #endinput
#endif
#define _INC_UI_KTPCARD

#include "theme.pwn"

#define KTPC_X          (105.0)
#define KTPC_Y          (112.0)
#define KTPC_W          (430.0)
#define KTPC_H          (266.0)
#define KTPC_TITLE_Y    (KTPC_Y + 8.0)
#define KTPC_SUB_Y      (KTPC_TITLE_Y + 14.0)
#define KTPC_PHOTO_X    (KTPC_X + 14.0)
#define KTPC_PHOTO_Y    (KTPC_Y + 46.0)
#define KTPC_PHOTO_W    (78.0)
#define KTPC_PHOTO_H    (96.0)
#define KTPC_NIK_Y      (KTPC_PHOTO_Y + KTPC_PHOTO_H + 6.0)
#define KTPC_COL_A_X    (KTPC_X + 104.0)
#define KTPC_COL_B_X    (KTPC_X + 252.0)
#define KTPC_ROW_Y      (KTPC_Y + 48.0)
#define KTPC_ROW_STEP   (17.0)
#define KTPC_ADDR_Y     (KTPC_Y + 160.0)
#define KTPC_FOOT_Y     (KTPC_Y + 196.0)
#define KTPC_ROWS       (5)

#define KTPC_ID_CLOSE   (230)

static bool:gKtpOpen[MAX_PLAYERS];
static PlayerText:gKtpCard[MAX_PLAYERS][6];
static PlayerText:gKtpTitle[MAX_PLAYERS];
static PlayerText:gKtpSub[MAX_PLAYERS];
static PlayerText:gKtpPhotoFrame[MAX_PLAYERS];
static PlayerText:gKtpPhoto[MAX_PLAYERS];
static PlayerText:gKtpNik[MAX_PLAYERS];
static PlayerText:gKtpLabel[MAX_PLAYERS][KTPC_ROWS * 2];
static PlayerText:gKtpValue[MAX_PLAYERS][KTPC_ROWS * 2];
static PlayerText:gKtpAddrLabel[MAX_PLAYERS];
static PlayerText:gKtpAddrValue[MAX_PLAYERS];
static PlayerText:gKtpFootA[MAX_PLAYERS];
static PlayerText:gKtpFootB[MAX_PLAYERS];
static PlayerText:gKtpBtnClose[MAX_PLAYERS];
static PlayerText:gKtpLblClose[MAX_PLAYERS];

stock bool:KtpCard_IsOpen(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gKtpOpen[playerid];
}

// Satu baris "Label : Nilai" gaya e-KTP (label biru dinas, nilai gelap).
static KtpCard_Row(playerid, Float:columnX, row, const label[], const value[]) {
    new Float:y = KTPC_ROW_Y + row * KTPC_ROW_STEP;
    new index = row + (columnX == KTPC_COL_B_X ? KTPC_ROWS : 0);

    gKtpLabel[playerid][index] = TrxTd_Text(playerid, columnX, y, label,
        THEME_FONT_BODY, 0.16, 0.70, KTP_LABEL, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gKtpValue[playerid][index] = TrxTd_Text(playerid, columnX + 78.0, y, value,
        THEME_FONT_BODY, 0.16, 0.70, KTP_VALUE, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    return 1;
}

stock bool:KtpCard_Show(playerid, const nik[], skinModel,
    const name[], const ttl[], const gender[], const blood[],
    const address[], const rtrw[], const kel[], const kec[],
    const religion[], const marital[], const occupation[]) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (gKtpOpen[playerid]) KtpCard_Destroy(playerid);
    if (!UIModal_Open(playerid, UI_KTPCARD)) return false;

    // Badan kartu terang + bingkai foto putih (pas foto e-KTP).
    TrxTd_RoundedCard(playerid, gKtpCard[playerid], KTPC_X, KTPC_Y,
        KTPC_W, KTPC_H, 8.0, KTP_CARD);
    gKtpPhotoFrame[playerid] = TrxTd_Sprite(playerid, KTPC_PHOTO_X - 2.0,
        KTPC_PHOTO_Y - 2.0, THEME_SPRITE_WHITE, KTPC_PHOTO_W + 4.0,
        KTPC_PHOTO_H + 4.0, THEME_WHITE);
    gKtpPhoto[playerid] = TrxTd_PreviewModel(playerid, KTPC_PHOTO_X,
        KTPC_PHOTO_Y, KTPC_PHOTO_W, KTPC_PHOTO_H, skinModel);

    // Header: provinsi + nama kartu, khas e-KTP.
    gKtpTitle[playerid] = TrxTd_Text(playerid, KTPC_X + KTPC_W / 2.0,
        KTPC_TITLE_Y, "PROVINSI DKI JAKARTA", THEME_FONT_LABEL, 0.26, 1.00,
        KTP_HEADER, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);
    gKtpSub[playerid] = TrxTd_Text(playerid, KTPC_X + KTPC_W / 2.0,
        KTPC_SUB_Y, "KARTU TANDA PENDUDUK", THEME_FONT_BODY, 0.16, 0.70,
        KTP_SUB, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_CENTER);

    // NIK 16 digit di bawah foto, tebal navy.
    gKtpNik[playerid] = TrxTd_Text(playerid, KTPC_X + 10.0, KTPC_NIK_Y, nik,
        THEME_FONT_LABEL, 0.15, 0.85, KTP_NIK, TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);

    // Kolom kiri: identitas inti.
    KtpCard_Row(playerid, KTPC_COL_A_X, 0, "Nama", name);
    KtpCard_Row(playerid, KTPC_COL_A_X, 1, "Tempat/Tgl Lahir", ttl);
    KtpCard_Row(playerid, KTPC_COL_A_X, 2, "Jenis Kelamin", gender);
    KtpCard_Row(playerid, KTPC_COL_A_X, 3, "Gol. Darah", blood);
    KtpCard_Row(playerid, KTPC_COL_A_X, 4, "Pekerjaan", occupation);

    // Kolom kanan: administrasi kependudukan.
    KtpCard_Row(playerid, KTPC_COL_B_X, 0, "Agama", religion);
    KtpCard_Row(playerid, KTPC_COL_B_X, 1, "Status Perkawinan", marital);
    KtpCard_Row(playerid, KTPC_COL_B_X, 2, "RT/RW", rtrw);
    KtpCard_Row(playerid, KTPC_COL_B_X, 3, "Kel/Desa", kel);
    KtpCard_Row(playerid, KTPC_COL_B_X, 4, "Kecamatan", kec);

    // Blok alamat melintang penuh di bawah kolom.
    gKtpAddrLabel[playerid] = TrxTd_Text(playerid, KTPC_COL_A_X, KTPC_ADDR_Y,
        "Alamat", THEME_FONT_BODY, 0.16, 0.70, KTP_LABEL,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gKtpAddrValue[playerid] = TrxTd_Text(playerid, KTPC_COL_A_X + 78.0,
        KTPC_ADDR_Y, address, THEME_FONT_BODY, 0.16, 0.70, KTP_VALUE,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);

    // Baris kaki: kewarganegaraan dan masa berlaku.
    gKtpFootA[playerid] = TrxTd_Text(playerid, KTPC_COL_A_X, KTPC_FOOT_Y,
        "Kewarganegaraan : WNI", THEME_FONT_BODY, 0.16, 0.70, KTP_VALUE,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);
    gKtpFootB[playerid] = TrxTd_Text(playerid, KTPC_COL_B_X, KTPC_FOOT_Y,
        "Berlaku Hingga : SEUMUR HIDUP", THEME_FONT_BODY, 0.16, 0.70, KTP_VALUE,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);

    gKtpBtnClose[playerid] = TrxTd_Button(playerid, gKtpLblClose[playerid],
        KTPC_X + KTPC_W - 36.0, KTPC_Y + 6.0, 28.0, 22.0, "X",
        THEME_ELEVATED, THEME_TEXT);
    TrxTd_BindClick(playerid, gKtpBtnClose[playerid], KTPC_ID_CLOSE);

    gKtpOpen[playerid] = true;
    // Aktifkan mode klik kursor: tombol X hanya bisa diklik saat mode ini on.
    SelectTextDraw(playerid, THEME_ACCENT);
    return true;
}

stock KtpCard_Destroy(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gKtpOpen[playerid]) return 0;

    CancelSelectTextDraw(playerid);
    TrxTd_Kill(playerid, gKtpLblClose[playerid]);
    TrxTd_Kill(playerid, gKtpBtnClose[playerid]);
    TrxTd_Kill(playerid, gKtpFootB[playerid]);
    TrxTd_Kill(playerid, gKtpFootA[playerid]);
    TrxTd_Kill(playerid, gKtpAddrValue[playerid]);
    TrxTd_Kill(playerid, gKtpAddrLabel[playerid]);
    for (new row = 0; row < KTPC_ROWS * 2; row++) {
        TrxTd_Kill(playerid, gKtpValue[playerid][row]);
        TrxTd_Kill(playerid, gKtpLabel[playerid][row]);
    }
    TrxTd_Kill(playerid, gKtpNik[playerid]);
    TrxTd_Kill(playerid, gKtpPhoto[playerid]);
    TrxTd_Kill(playerid, gKtpPhotoFrame[playerid]);
    TrxTd_Kill(playerid, gKtpSub[playerid]);
    TrxTd_Kill(playerid, gKtpTitle[playerid]);
    TrxTd_KillCard(playerid, gKtpCard[playerid]);
    gKtpOpen[playerid] = false;
    return 1;
}

// Return: true kalau klik ditangani di sini (tombol tutup), false selainnya.
stock bool:KtpCard_OnClick(playerid, PlayerText:clicked) {
    if (!gKtpOpen[playerid]) return false;
    if (TrxTd_ResolveClick(playerid, clicked) != KTPC_ID_CLOSE) return false;

    UIModal_Close(playerid);
    return true;
}
