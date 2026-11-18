// ---------------------------------------------------------------------------
// module      : shared/messages
// entry       : -
// depends     : core/text
// owns tables : -
// public api  : Messages_Send(), Messages_SendAll(), Messages_SendNearby(),
//               Messages_Money(), Dialog_IsKnown(), serta enum E_DIALOG_ID
// Catatan     : ID dialog WAJIB dari enum di sini. Tidak ada literal angka.
// ---------------------------------------------------------------------------
#if defined _INC_MESSAGES
    #endinput
#endif
#define _INC_MESSAGES

#define COLOR_SERVER     (0x9ACD32FF)
#define COLOR_ERROR      (0xE74C3CFF)
#define COLOR_WARNING    (0xF1C40AFF)
#define COLOR_INFO       (0xECF0F1FF)
#define COLOR_ACTION     (0xC39BD3FF)
#define COLOR_OOC        (0x95A5A6FF)

// ID dialog memakai #define, bukan enum: `enum { ... }` tanpa nama tidak
// didukung compiler Pawn 3.10.11, dan enum bertag memicu tag mismatch karena
// dialogid dari open.mp tidak bertag.
#define DIALOG_NONE             (0)
#define DIALOG_LOGIN            (1)
#define DIALOG_REGISTER         (2)
#define DIALOG_CHAR_CREATE_FIRST  (4)
#define DIALOG_CHAR_CREATE_LAST   (5)
#define DIALOG_ADMIN_MENU       (7)
#define DIALOG_IDENTITY_PICK    (8)   // /datadiri: pilih field KTP
#define DIALOG_IDENTITY_INPUT   (9)   // /datadiri: isi nilai baru
#define DIALOG_BANK_TARGET      (10)  // m-banking: nama penerima transfer
#define DIALOG_BANK_AMOUNT      (11)  // m-banking: jumlah setor/tarik/transfer
#define DIALOG_BANK_MUTASI      (12)  // m-banking: daftar 10 mutasi terakhir
#define DIALOG_PROP_MENU        (13)  // kelola gedung: menu pemilik
#define DIALOG_PROP_PICKITEM    (14)  // kelola gedung: pilih item menu
#define DIALOG_PROP_PRICE       (15)  // kelola gedung: isi harga baru
#define DIALOG_PROP_ADDITEM     (16)  // kelola gedung: tambah menu (KODE harga)
#define DIALOG_PROP_SALE        (17)  // gedung dijual: konfirmasi beli
#define DIALOG_RENTAL_LIST      (18)  // rental kendaraan: pilih paket
#define DIALOG_DEALER_LIST      (19)  // dealer kendaraan: pilih unit
#define DIALOG_RADIO_LIST       (20)  // radio: pilih stasiun


#define MSG_WELCOME         "Selamat datang, %s. Silakan login."
#define MSG_REGISTER_HINT   "Akun belum terdaftar. Buat password untuk mendaftar."
#define MSG_LOGIN_FAILED    "Kombinasi username/password salah (%d/%d)."
#define MSG_LOGIN_LOCKED    "Terlalu banyak percobaan. Tunggu %d detik."
#define MSG_LOGIN_OK        "Login berhasil. Pilih karakter."
#define MSG_REGISTER_OK     "Akun dibuat. Silakan login."
#define MSG_CHAR_LIMIT      "Slot karakter penuh (%d/%d)."
#define MSG_CHAR_CREATED    "Karakter %s %s dibuat."
#define MSG_CHAR_SELECTED   "Kamu bermain sebagai %s %s."
#define MSG_NOT_ALIVE       "Kamu belum bisa melakukan itu sekarang."
#define MSG_NOT_LOGGED_IN   "Kamu belum masuk akun."
#define MSG_INTERNAL_ERROR  "Terjadi kesalahan internal. Hubungi admin."
#define MSG_DB_ERROR        "Data gagal disimpan. Coba lagi."
#define MSG_NO_PERMISSION   "Kamu tidak punya izin untuk perintah ini."

stock Messages_Send(playerid, const text[]) {
    SendClientMessage(playerid, COLOR_INFO, text);
    return 1;
}

stock Messages_SendError(playerid, const text[]) {
    SendClientMessage(playerid, COLOR_ERROR, text);
    return 1;
}

stock Messages_SendSystem(playerid, const text[]) {
    SendClientMessage(playerid, COLOR_SERVER, text);
    return 1;
}

stock Messages_SendAll(const text[]) {
    SendClientMessageToAll(COLOR_SERVER, text);
    return 1;
}

// Kirim ke pemain dalam radius tertentu (chat IC, bukan global).
stock Messages_SendNearby(playerid, const text[], Float:radius) {
    new Float:originX, Float:originY, Float:originZ;
    GetPlayerPos(playerid, originX, originY, originZ);

    new players[MAX_PLAYERS];
    new count = GetPlayers(players, sizeof (players));
    for (new index = 0; index < count; index++) {
        new targetid = players[index];
        new Float:targetX, Float:targetY, Float:targetZ;
        GetPlayerPos(targetid, targetX, targetY, targetZ);

        if (GetPlayerDistanceFromPoint(targetid, originX, originY, originZ) <= radius) {
            SendClientMessage(targetid, COLOR_INFO, text);
        }
    }
    return 1;
}

stock Messages_Money(value, dest[], maxlength = sizeof (dest)) {
    new digits[24];
    Text_FormatNumber(value, digits, sizeof (digits));
    return format(dest, maxlength, "Rp %s", digits);
}

stock bool:Dialog_IsKnown(dialogid) {
    switch (dialogid) {
        case DIALOG_LOGIN, DIALOG_REGISTER,
             DIALOG_CHAR_CREATE_FIRST, DIALOG_CHAR_CREATE_LAST,
             DIALOG_ADMIN_MENU, DIALOG_IDENTITY_PICK, DIALOG_IDENTITY_INPUT,
             DIALOG_BANK_TARGET, DIALOG_BANK_AMOUNT, DIALOG_BANK_MUTASI,
             DIALOG_PROP_MENU, DIALOG_PROP_PICKITEM, DIALOG_PROP_PRICE,
             DIALOG_PROP_ADDITEM, DIALOG_PROP_SALE,
             DIALOG_RENTAL_LIST, DIALOG_DEALER_LIST, DIALOG_RADIO_LIST: {
            return true;
        }
    }
    return false;
}
