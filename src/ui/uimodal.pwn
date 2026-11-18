// ---------------------------------------------------------------------------
// module      : ui/uimodal
// entry       : -
// depends     : core/log (dan modul modal yang ada / yang akan datang)
// owns tables : -
// public api  : UIModal_Open(), UIModal_Close(), UIModal_Active(),
//               UIModal_IsOpen()
// Aturan      : SATU pemain = SATU modal. Buka modal baru otomatis menutup
//               modal lama (hancurkan semua PlayerTextDraw-nya + lepas
//               kursor). Modul modal baru WAJIB mendaftar di
//               UIModal_DestroyActive() supaya manajer bisa menutupnya.
// ---------------------------------------------------------------------------
#if defined _INC_UIMODAL
    #endinput
#endif
#define _INC_UIMODAL

// Id modal (konstanta #define, bukan enum anonim - pawncc menolaknya).
#define UI_NONE         (0)
#define UI_CHARSELECT   (1)
#define UI_CHARCREATE   (2)
#define UI_PHONE        (3)     // fase P2: smartphone
#define UI_BANK         (4)     // fase P2: ATM / m-banking
#define UI_INVENTORY    (5)     // fase P2: inventory grid
#define UI_DEALERSHIP   (6)     // fase P2: dealer kendaraan
#define UI_GARAGE       (7)     // fase P2: garasi
#define UI_HOUSE        (8)     // fase P4: menu rumah
#define UI_MDT          (9)     // fase P3: MDT polisi
#define UI_ADMIN        (10)    // fase P5: panel admin
#define UI_HELP         (11)    // fase P5: menu bantuan
#define UI_KTPCARD      (12)    // kartu e-KTP
#define UI_SIMCARD      (13)    // kartu SIM Nasional
#define UI_WARUNG       (14)    // toko warung (fase D)
#define UI_MODAL_LAST   (UI_WARUNG)

static gUIModalActive[MAX_PLAYERS];

stock UIModal_Active(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return UI_NONE;
    return gUIModalActive[playerid];
}

stock bool:UIModal_IsOpen(playerid, which) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gUIModalActive[playerid] == which;
}

// Tutup modal aktif apa pun itu. Aman dipanggil saat tidak ada modal.
stock UIModal_Close(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gUIModalActive[playerid] == UI_NONE) return 0;

    UIModal_DestroyActive(playerid);
    gUIModalActive[playerid] = UI_NONE;
    return 1;
}

// Buka modal: tutup yang lama dulu, lalu tandai modal baru. Pemanggil
// menggambar modalnya sendiri SETELAH fungsi ini sukses.
stock bool:UIModal_Open(playerid, which) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (which <= UI_NONE || which > UI_MODAL_LAST) {
        Log_Warn("ui", "modal id tidak dikenal ditolak");
        return false;
    }
    if (gUIModalActive[playerid] == which) return true; // sudah terbuka

    UIModal_Close(playerid);
    gUIModalActive[playerid] = which;
    return true;
}

// Dispatch penutup per modal. Tambahkan case baru di sini setiap kali ada
// modul modal baru - inilah satu-satunya tempat yang perlu diubah.
stock UIModal_DestroyActive(playerid) {
    switch (gUIModalActive[playerid]) {
        case UI_CHARSELECT: CharSelect_Hide(playerid);
        case UI_CHARCREATE: CharCreate_Destroy(playerid);
        case UI_PHONE:      PhoneUI_Destroy(playerid);
        case UI_BANK:       BankUI_Destroy(playerid);
        case UI_INVENTORY:  InventoryUI_Destroy(playerid);
        case UI_WARUNG:     WarungUI_Destroy(playerid);
        case UI_KTPCARD:    KtpCard_Destroy(playerid);
        case UI_SIMCARD:    SimCard_Destroy(playerid);
    }
    // Binding mati sudah dibersihkan otomatis oleh TrxTd_Kill (auto-unbind).
    // JANGAN TrxTd_ClearClicks di sini: itu menghapus binding UI yang MASIH
    // hidup (badge prompt) sehingga prompt tidak bisa ditutup/diklik lagi.
    return 1;
}
