// ---------------------------------------------------------------------------
// module      : domain/survival_cmd
// entry       : Survival_HandleCommand()
// depends     : domain/survival (nilai + efek), domain/inventory, ui/toast,
//               domain/world/interiors
// public api  : Survival_HandleCommand()
// Fungsi      : perintah /makan, /minum, /tidur, /tubuh. Efek angka tetap di
//               survival.pwn supaya satu implementasi untuk UI tas juga.
// ---------------------------------------------------------------------------
#if defined _INC_DOMAIN_SURVIVAL_CMD
    #endinput
#endif
#define _INC_DOMAIN_SURVIVAL_CMD

#define SURV_SLEEP_COOLDOWN (60)    // jeda antar /tidur dalam detik

static gSurvLastSleepAt[MAX_PLAYERS];

// Tidur hanya di dalam interior gedung: memulihkan energi & sebagian darah.
// Ditunda dengan cooldown supaya tidak jadi tombol heal gratis di tengah baku
// tembak (hanya berlaku di ruangan, bukan di jalan).
static Survival_Sleep(playerid) {
    if (!Interiors_IsInside(playerid)) {
        Toast_Show(playerid, "TIDUR",
            "Kamu hanya bisa tidur di dalam gedung.", THEME_DANGER);
        return 0;
    }
    if (gSurvLastSleepAt[playerid] > 0
            && gettime() - gSurvLastSleepAt[playerid] < SURV_SLEEP_COOLDOWN) {
        new left = SURV_SLEEP_COOLDOWN - (gettime() - gSurvLastSleepAt[playerid]);
        new message[64];
        format(message, sizeof (message), "Tunggu %d detik lagi.", left);
        Toast_Show(playerid, "TIDUR", message, THEME_DANGER);
        return 0;
    }
    gSurvLastSleepAt[playerid] = gettime();
    Survival_AddStamina(playerid, SURV_MAX);

    new Float:health;
    GetPlayerHealth(playerid, health);
    health += 25.0;
    if (health > 100.0) health = 100.0;
    SetPlayerHealth(playerid, health);

    Survival_RefreshHud(playerid);
    Toast_Show(playerid, "TIDUR", "Energi pulih, badan terasa segar.", THEME_OK);
    return 1;
}

stock bool:Survival_HandleCommand(playerid, const command[], params[]) {
    #pragma unused params

    if (!strcmp(command, "makan", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        Survival_Eat(playerid);
        return true;
    }
    if (!strcmp(command, "minum", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        Survival_Drink(playerid);
        return true;
    }
    if (!strcmp(command, "tidur", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        Survival_Sleep(playerid);
        return true;
    }
    if (!strcmp(command, "tubuh", true) || !strcmp(command, "kondisi", true)) {
        new message[96];
        format(message, sizeof (message),
            "Lapar %d | Haus %d | Energi %d",
            Survival_Hunger(playerid), Survival_Thirst(playerid),
            Survival_Stamina(playerid));
        Toast_Show(playerid, "KONDISI TUBUH", message, THEME_ACCENT);
        return true;
    }
    return false;
}

static Survival_Eat(playerid) {
    if (Inv_CountOf(playerid, INV_ITEM_MAKANAN) < 1) {
        Toast_Show(playerid, "MAKAN",
            "Tidak ada makanan. Beli di warung atau gedung.", THEME_DANGER);
        return 0;
    }
    if (!Inv_Take(playerid, INV_ITEM_MAKANAN, 1)) return 0;
    Survival_ConsumeFood(playerid);
    Toast_Show(playerid, "MAKAN", "Kamu makan. Lapar berkurang.", THEME_OK);
    return 1;
}

static Survival_Drink(playerid) {
    if (Inv_CountOf(playerid, INV_ITEM_MINUMAN) < 1) {
        Toast_Show(playerid, "MINUM",
            "Tidak ada minuman. Beli di warung atau gedung.", THEME_DANGER);
        return 0;
    }
    if (!Inv_Take(playerid, INV_ITEM_MINUMAN, 1)) return 0;
    Survival_ConsumeDrink(playerid);
    Toast_Show(playerid, "MINUM", "Kamu minum. Haus berkurang.", THEME_OK);
    return 1;
}

