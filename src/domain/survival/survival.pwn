// ---------------------------------------------------------------------------
// module      : domain/survival
// entry       : Survival_HandleCommand()
// depends     : core/db, core/log, shared/money, domain/inventory, ui/toast,
//               ui/theme (sudah di-include gamemode.pwn), shared/player_phase
// owns tables : kolom hunger/thirst/stamina pada tabel `characters`
//               (ditambah di Survival_Boot, bukan db.pwn)
// public api  : Survival_Boot(), Survival_OnSpawn(), Survival_Save(),
//               Survival_Reset(), Survival_Tick(), Survival_HandleCommand(),
//               Survival_AddHunger(), Survival_AddThirst(), Survival_AddStamina(),
//               Survival_TakeStamina(), Survival_Hunger(), Survival_Thirst(),
//               Survival_Stamina()
// Fungsi      : kebutuhan tubuh (lapar, haus, energi). Turun bertahap per waktu
//               nyata, dipulihkan dengan makan/minum dari warung. Lapar atau
//               haus habis -> darah turun perlahan (bukan langsung mati).
// Aturan      : HUD survival hanya memperbarui textdraw kalau nilainya berubah
//               (anti kedip / hemat render Android). Nilai disimpan ke DB saat
//               keluar supaya tidak reset tiap reconnect.
// ---------------------------------------------------------------------------
#if defined _INC_DOMAIN_SURVIVAL
    #endinput
#endif
#define _INC_DOMAIN_SURVIVAL


#define SURV_MAX            (100)
#define SURV_START          (100)
#define SURV_HUNGER_SECONDS (90)    // 1 poin lapar per 90 detik
#define SURV_THIRST_SECONDS (60)    // 1 poin haus per 60 detik
#define SURV_STAMINA_SECONDS (5)    // 1 poin energi pulih per 5 detik
#define SURV_HUNGER_EAT     (45)    // +45 lapar per porsi makanan
#define SURV_THIRST_DRINK   (55)    // +55 haus per porsi minuman
#define SURV_DRAIN_SECONDS  (10)    // interval darah turun saat kebutuhan habis
#define SURV_DRAIN_HP       (2.0)   // darah turun per interval
#define SURV_WARN_VALUE     (25)
#define SURV_SLEEP_COOLDOWN (60)    // jeda antar /tidur dalam detik    // di bawah ini bar berwarna bahaya

static gSurvHunger[MAX_PLAYERS];
static gSurvThirst[MAX_PLAYERS];
static gSurvStamina[MAX_PLAYERS];
static gSurvLastHungerAt[MAX_PLAYERS];
static gSurvLastThirstAt[MAX_PLAYERS];
static gSurvLastStaminaAt[MAX_PLAYERS];
static gSurvLastDrainAt[MAX_PLAYERS];
static gSurvLastSleepAt[MAX_PLAYERS];
static bool:gSurvHudShown[MAX_PLAYERS];
static PlayerText:gSurvText[MAX_PLAYERS][3];
static gSurvShownValue[MAX_PLAYERS][3];  // cache: nilai terakhir di textdraw

stock Survival_Boot() {
    // Kolom disimpan di tabel characters milik domain/character.
    new columns[3][10] = { "hunger", "thirst", "stamina" };
    for (new slot = 0; slot < 3; slot++) {
        new query[128];
        format(query, sizeof (query),
            "SELECT COUNT(*) FROM pragma_table_info('characters') \
             WHERE name = '%s'", columns[slot]);
        if (DB_Int(query, 0) > 0) continue;
        format(query, sizeof (query),
            "ALTER TABLE characters ADD COLUMN %s INTEGER NOT NULL DEFAULT %d",
            columns[slot], SURV_START);
        DB_Exec(query);
    }
    return 1;
}

stock Survival_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gSurvHunger[playerid] = SURV_START;
    gSurvThirst[playerid] = SURV_START;
    gSurvStamina[playerid] = SURV_START;
    gSurvLastHungerAt[playerid] = 0;
    gSurvLastThirstAt[playerid] = 0;
    gSurvLastStaminaAt[playerid] = 0;
    gSurvLastDrainAt[playerid] = 0;
    gSurvLastSleepAt[playerid] = 0;
    gSurvShownValue[playerid][0] = -1;
    gSurvShownValue[playerid][1] = -1;
    gSurvShownValue[playerid][2] = -1;
    return 1;
}

// Muat nilai dari DB lalu tampilkan HUD. Dipanggil dari OnPlayerSpawn setelah
// karakter aktif (id karakter sudah terisi).
stock Survival_OnSpawn(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    Survival_Reset(playerid);

    new characterId = Character_GetId(playerid);
    if (characterId > 0) {
        new query[128];
        format(query, sizeof (query),
            "SELECT hunger, thirst, stamina FROM characters \
             WHERE character_id = %d", characterId);
        gSurvHunger[playerid] = DB_IntAt(query, 0, 0, SURV_START);
        gSurvThirst[playerid] = DB_IntAt(query, 0, 1, SURV_START);
        gSurvStamina[playerid] = DB_IntAt(query, 0, 2, SURV_START);
    }

    new stamp = gettime();
    gSurvLastHungerAt[playerid] = stamp;
    gSurvLastThirstAt[playerid] = stamp;
    gSurvLastStaminaAt[playerid] = stamp;
    gSurvLastDrainAt[playerid] = stamp;
    Survival_ShowHud(playerid);
    return 1;
}

stock Survival_Save(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    new characterId = Character_GetId(playerid);
    if (characterId < 1) return 0;

    new query[160];
    format(query, sizeof (query),
        "UPDATE characters SET hunger = %d, thirst = %d, stamina = %d \
         WHERE character_id = %d",
        gSurvHunger[playerid], gSurvThirst[playerid],
        gSurvStamina[playerid], characterId);
    if (!DB_Exec(query)) {
        Log_Warn("survival", "gagal simpan kebutuhan tubuh");
        return 0;
    }
    return 1;
}

stock Survival_Hunger(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return gSurvHunger[playerid];
}

stock Survival_Thirst(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return gSurvThirst[playerid];
}

stock Survival_Stamina(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return gSurvStamina[playerid];
}

static Survival_Clamp(value) {
    if (value < 0) return 0;
    if (value > SURV_MAX) return SURV_MAX;
    return value;
}

stock Survival_AddHunger(playerid, amount) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gSurvHunger[playerid] = Survival_Clamp(gSurvHunger[playerid] + amount);
    Survival_RefreshHud(playerid);
    return gSurvHunger[playerid];
}

stock Survival_AddThirst(playerid, amount) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gSurvThirst[playerid] = Survival_Clamp(gSurvThirst[playerid] + amount);
    Survival_RefreshHud(playerid);
    return gSurvThirst[playerid];
}

stock Survival_AddStamina(playerid, amount) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gSurvStamina[playerid] = Survival_Clamp(gSurvStamina[playerid] + amount);
    Survival_RefreshHud(playerid);
    return gSurvStamina[playerid];
}

// Dipakai pekerjaan berat (kurir, angkat barang). Return false kalau energi
// tidak cukup - pemanggil wajib membatalkan aksinya.
stock bool:Survival_TakeStamina(playerid, amount) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (gSurvStamina[playerid] < amount) return false;
    gSurvStamina[playerid] = Survival_Clamp(gSurvStamina[playerid] - amount);
    Survival_RefreshHud(playerid);
    return true;
}

// --- HUD -------------------------------------------------------------------

static Survival_CreateHud(playerid) {
    new const titles[3][8] = { "LAPAR", "HAUS", "ENERGI" };
    for (new slot = 0; slot < 3; slot++) {
        gSurvText[playerid][slot] = CreatePlayerTextDraw(playerid,
            14.0, 20.0 + slot * 14.0, titles[slot]);
        PlayerTextDrawFont(playerid, gSurvText[playerid][slot], THEME_FONT_BODY);
        PlayerTextDrawLetterSize(playerid, gSurvText[playerid][slot], 0.20, 1.05);
        PlayerTextDrawColour(playerid, gSurvText[playerid][slot], THEME_MUTED);
        PlayerTextDrawSetOutline(playerid, gSurvText[playerid][slot], 1);
        PlayerTextDrawSetShadow(playerid, gSurvText[playerid][slot], 1);
        gSurvShownValue[playerid][slot] = -1;
    }
    return 1;
}

stock Survival_ShowHud(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (gSurvHudShown[playerid]) {
        Survival_RefreshHud(playerid);
        return 1;
    }
    Survival_CreateHud(playerid);
    for (new slot = 0; slot < 3; slot++) {
        PlayerTextDrawShow(playerid, gSurvText[playerid][slot]);
    }
    gSurvHudShown[playerid] = true;
    Survival_RefreshHud(playerid);
    return 1;
}

stock Survival_DestroyHud(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gSurvHudShown[playerid]) return 0;
    for (new slot = 0; slot < 3; slot++) {
        PlayerTextDrawDestroy(playerid, gSurvText[playerid][slot]);
        gSurvText[playerid][slot] = PlayerText:INVALID_TEXT_DRAW;
        gSurvShownValue[playerid][slot] = -1;
    }
    gSurvHudShown[playerid] = false;
    return 1;
}

// Perbarui textdraw HANYA kalau nilainya berubah (invariant anti kedip).
stock Survival_RefreshHud(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    if (!gSurvHudShown[playerid]) return 0;

    new values[3];
    values[0] = gSurvHunger[playerid];
    values[1] = gSurvThirst[playerid];
    values[2] = gSurvStamina[playerid];
    new const titles[3][8] = { "LAPAR", "HAUS", "ENERGI" };

    for (new slot = 0; slot < 3; slot++) {
        if (gSurvShownValue[playerid][slot] == values[slot]) continue;
        gSurvShownValue[playerid][slot] = values[slot];

        new buffer[24];
        format(buffer, sizeof (buffer), "%s %d", titles[slot], values[slot]);
        PlayerTextDrawSetString(playerid, gSurvText[playerid][slot], buffer);
        PlayerTextDrawColour(playerid, gSurvText[playerid][slot],
            (values[slot] < SURV_WARN_VALUE) ? THEME_DANGER : THEME_MUTED);
        PlayerTextDrawShow(playerid, gSurvText[playerid][slot]);
    }
    return 1;
}

// --- Tick (500 ms) ---------------------------------------------------------

stock Survival_Tick() {
    new now = gettime();
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;
        if (Character_GetId(playerid) < 1) continue;
        if (!Phase_CanAct(playerid)) continue;

        new changed = 0;
        while (now - gSurvLastHungerAt[playerid] >= SURV_HUNGER_SECONDS) {
            gSurvLastHungerAt[playerid] += SURV_HUNGER_SECONDS;
            if (gSurvHunger[playerid] > 0) gSurvHunger[playerid]--;
            changed = 1;
        }
        while (now - gSurvLastThirstAt[playerid] >= SURV_THIRST_SECONDS) {
            gSurvLastThirstAt[playerid] += SURV_THIRST_SECONDS;
            if (gSurvThirst[playerid] > 0) gSurvThirst[playerid]--;
            changed = 1;
        }
        while (now - gSurvLastStaminaAt[playerid] >= SURV_STAMINA_SECONDS) {
            gSurvLastStaminaAt[playerid] += SURV_STAMINA_SECONDS;
            if (gSurvStamina[playerid] < SURV_MAX) {
                gSurvStamina[playerid]++;
                changed = 1;
            }
        }

        if (changed) Survival_RefreshHud(playerid);

        // Kebutuhan habis: darah turun perlahan, bukan mati mendadak.
        new emptyBars = 0;
        if (gSurvHunger[playerid] < 1) emptyBars++;
        if (gSurvThirst[playerid] < 1) emptyBars++;
        if (emptyBars < 1) continue;

        if (now - gSurvLastDrainAt[playerid] < SURV_DRAIN_SECONDS) continue;
        gSurvLastDrainAt[playerid] = now;

        new Float:health;
        GetPlayerHealth(playerid, health);
        health -= SURV_DRAIN_HP * emptyBars;
        if (health < 1.0) health = 1.0;
        SetPlayerHealth(playerid, health);

        if (emptyBars > 1) {
            Toast_Show(playerid, "TUBUH LEMAH",
                "Lapar dan haus. Segera makan dan minum.", THEME_DANGER);
        } else if (gSurvHunger[playerid] < 1) {
            Toast_Show(playerid, "LAPAR", "Kamu kelaparan. Cari makan.", THEME_DANGER);
        } else {
            Toast_Show(playerid, "HAUS", "Kamu kehausan. Cari minum.", THEME_DANGER);
        }
    }
    return 1;
}

// --- Perintah pemain -------------------------------------------------------

// Efek makan/minum TANPA mengambil item: pemanggil yang mengambil dari tas.
// Dipakai bersama oleh /makan, /minum dan tombol PAKAI di UI tas.
stock Survival_ConsumeFood(playerid) {
    Survival_AddHunger(playerid, SURV_HUNGER_EAT);
    new Float:health;
    GetPlayerHealth(playerid, health);
    health += 10.0;
    if (health > 100.0) health = 100.0;
    SetPlayerHealth(playerid, health);
    return 1;
}

stock Survival_ConsumeDrink(playerid) {
    Survival_AddThirst(playerid, SURV_THIRST_DRINK);
    new Float:health;
    GetPlayerHealth(playerid, health);
    health += 5.0;
    if (health > 100.0) health = 100.0;
    SetPlayerHealth(playerid, health);
    return 1;
}
