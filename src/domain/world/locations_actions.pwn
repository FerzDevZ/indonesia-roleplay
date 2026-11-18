// ---------------------------------------------------------------------------
// module      : world/locations_actions
// entry       : Locations_ShowIcons()
// depends     : domain/world/locations (aksesor), domain/property (ikon gedung),
//               ui/bankui, domain/warung, ui/toast, shared/money
// public api  : Locations_ShowIcons(), Locations_Activate()
// Fungsi      : ikon radar + dispatch interaksi lokasi (prompt [Y]). Dipisah
//               dari locations.pwn supaya file inti tetap di bawah 400 baris;
//               semua akses data lewat aksesor publik, bukan variabel static.
// ---------------------------------------------------------------------------
#if defined _INC_WORLD_LOCATIONS_ACTIONS
    #endinput
#endif
#define _INC_WORLD_LOCATIONS_ACTIONS

// Ikon radar sesuai jenis layanan (data-driven: ikut kode aksi).
static Locations_MapIconOf(const action[]) {
    if (strcmp(action, LOC_ACT_ATM, false) == 0) return LOC_MAP_ICON_ATM;
    if (strcmp(action, LOC_ACT_WARUNG, false) == 0) return LOC_MAP_ICON_WARUNG;
    if (strcmp(action, LOC_ACT_RS, false) == 0) return LOC_MAP_ICON_RS;
    if (strcmp(action, LOC_ACT_JOB_CENTER, false) == 0) return LOC_MAP_ICON_JOB;
    if (strcmp(action, LOC_ACT_RENTAL, false) == 0) return LOC_MAP_ICON_RENTAL;
    if (strcmp(action, LOC_ACT_DEALER, false) == 0) return LOC_MAP_ICON_DEALER;
    return LOC_MAP_ICON_INFO;
}

// Pasang ulang ikon radar semua lokasi untuk satu pemain. Ikon gedung mengikuti
// status jual/milik (31 = dijual, 32 = sudah dimiliki).
stock Locations_ShowIcons(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;

    new total = Locations_Count();
    for (new index = 0; index < total; index++) {
        RemovePlayerMapIcon(playerid, index);
    }

    for (new index = 0; index < total; index++) {
        new action[LOC_ACTION_LEN], code[LOC_CODE_LEN];
        Locations_Action(index, action, sizeof (action));
        Locations_Code(index, code, sizeof (code));

        new icon = Locations_MapIconOf(action);
        if (strcmp(action, LOC_ACT_GEDUNG, false) == 0) {
            new propertyIndex = Property_FindByLocation(code);
            if (propertyIndex >= 0) {
                icon = (Property_OwnerOf(propertyIndex) == 0)
                    ? LOC_MAP_ICON_GEDUNG_SELL : LOC_MAP_ICON_GEDUNG_OWNED;
            }
        }

        new Float:posX, Float:posY, Float:posZ;
        Locations_Pos(index, posX, posY, posZ);
        SetPlayerMapIcon(playerid, index, posX, posY, posZ, icon, 0,
            MAPICON_GLOBAL);
    }
    return 1;
}

// Segarkan ikon radar semua pemain online (dipakai setelah lokasi ditambah
// atau jenisnya diubah) supaya tidak perlu reconnect.
stock Locations_RefreshIconsAll() {
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;
        Locations_ShowIcons(playerid);
    }
    return 1;
}

// Semua interaksi lokasi lewat sini (prompt [Y]). `index` = lokasi terdekat.
// Paket kurir ditangani lebih dulu: tujuannya lokasi mana pun.
stock bool:Locations_Activate(playerid, index) {
    if (index < 0 || index >= Locations_Count()) return false;
    if (JobKurir_IsCarrying(playerid)) return JobKurir_Deliver(playerid);

    new action[LOC_ACTION_LEN];
    Locations_Action(index, action, sizeof (action));

    if (strcmp(action, LOC_ACT_ATM, false) == 0) {
        return BankUI_OpenAtm(playerid);
    }
    if (strcmp(action, LOC_ACT_JOB_CENTER, false) == 0) {
        return JobKurir_AtCenter(playerid);
    }
    if (strcmp(action, LOC_ACT_WARUNG, false) == 0) {
        return Warung_OpenMenu(playerid, index);
    }
    if (strcmp(action, LOC_ACT_GEDUNG, false) == 0) {
        return Property_OpenAt(playerid, index);
    }
    if (strcmp(action, LOC_ACT_RENTAL, false) == 0) {
        return VehicleRental_Open(playerid);
    }
    if (strcmp(action, LOC_ACT_DEALER, false) == 0) {
        return VehicleShop_Open(playerid);
    }
    if (strcmp(action, LOC_ACT_RS, false) == 0) {
        new Float:health;
        GetPlayerHealth(playerid, health);
        if (health >= 100.0) {
            Messages_SendError(playerid, "Kesehatanmu sudah penuh.");
            return true;
        }
        if (!Money_Take(playerid, RS_PRICE, "BEROBAT")) {
            Messages_SendError(playerid, "Uang tidak cukup (Rp 10.000).");
            return true;
        }
        SetPlayerHealth(playerid, 100.0);
        Toast_Show(playerid, "RUMAH SAKIT", "Kamu sudah dirawat. HP penuh.", THEME_OK);
        return true;
    }
    if (strcmp(action, LOC_ACT_LOKET_PD, false) == 0) {
        Messages_SendSystem(playerid,
            "Loket PD: ketik /ujisim untuk ujian SIM atau /tilang untuk bayar denda.");
        return true;
    }
    return false;
}
