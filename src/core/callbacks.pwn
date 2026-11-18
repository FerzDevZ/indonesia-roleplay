// ---------------------------------------------------------------------------
// module      : core/callbacks
// entry       : -
// depends     : semua modul
// owns tables : -
// public api  : callback publik open.mp + timer publik
// Aturan      : hanya file ini yang mendefinisikan callback. Domain tidak boleh
//               punya `public OnPlayer...` sendiri, supaya urutan jelas.
// ---------------------------------------------------------------------------
#if defined _INC_CALLBACKS
    #endinput
#endif
#define _INC_CALLBACKS

public OnGameModeInit() {
    SetGameModeText("Roleplay Indonesia " SERVER_VERSION);
    ShowPlayerMarkers(PLAYER_MARKERS_MODE_GLOBAL);
    ShowNameTags(true);
    SetWorldTime(10);

    Log_Info("gamemode", "callback OnGameModeInit selesai");
    return 1;
}

public OnGameModeExit() {
    new players[MAX_PLAYERS];
    new count = GetPlayers(players, sizeof (players));
    for (new index = 0; index < count; index++) {
        Character_Save(players[index]);
    }
    Log_Info("gamemode", "server berhenti, semua karakter disimpan");
    return 1;
}

public OnPlayerConnect(playerid) {
    Phase_Set(playerid, PHASE_CONNECTING);

    // Log koneksi masuk: satu-satunya cara membedakan "paket tidak sampai" dari
    // "paket sampai tapi client putus di tengah handshake".
    new name[32], address[46], entry[128];
    GetPlayerName(playerid, name, sizeof (name));
    GetPlayerIp(playerid, address, sizeof (address));
    format(entry, sizeof (entry), "%s (%s) masuk", name, address);
    Log_Module("player", entry);

    TrxTd_Reset(playerid);
    Locations_ShowIcons(playerid);
    Auth_OnConnect(playerid);
    return 1;
}

public OnPlayerDisconnect(playerid, reason) {
    Vehicle_DespawnOf(playerid);
    VehicleOwned_Save(playerid);
    Fuel_SaveOwned(playerid);
    VehicleOwned_Reset(playerid);
    Radio_Reset(playerid);
    Onboarding_Reset(playerid);
    Range_Reset(playerid);
    Survival_Save(playerid);
    Character_Save(playerid);

    new message[128], name[32];
    GetPlayerName(playerid, name, sizeof (name));
    format(message, sizeof (message), "%s keluar dari server.", name);
    Log_Module("player", message);

    Character_Reset(playerid);
    Auth_ResetState(playerid);
    World_Reset(playerid);
    Inv_Reset(playerid);
    CharSelect_Destroy(playerid);
    CharCreate_Destroy(playerid);
    PhoneUI_Destroy(playerid);
    InventoryUI_Destroy(playerid);
    WarungUI_Destroy(playerid);
    Property_Reset(playerid);
    Interiors_Reset(playerid);
    BankUI_Destroy(playerid);
    KtpCard_Destroy(playerid);
    SimCard_Destroy(playerid);
    Prompt_Destroy(playerid);
    HUD_Destroy(playerid);
    Toast_Reset(playerid);
    TrxTd_Reset(playerid);
    UIModal_Close(playerid);
    ClientTier_Reset(playerid);
    Phase_Reset(playerid);
    return 1;
}

public OnPlayerSpawn(playerid) {
    if (Character_GetId(playerid) > 0) {
        Phase_Set(playerid, PHASE_ALIVE);
        Welcome_Hide(playerid);
        // Jaring pengaman: pastikan TIDAK ada textdraw layar menu yang nyisa
        // saat pemain sudah masuk dunia (bug klien Android render basi).
        UIModal_Close(playerid);
        CharSelect_Destroy(playerid);
        CharCreate_Destroy(playerid);
        Prompt_Destroy(playerid);
        HUD_Show(playerid);
        Inv_Load(playerid);
        VehicleOwned_Load(playerid, Character_GetId(playerid));
        Radio_Load(playerid);
        Fuel_LoadOwned(playerid, Character_GetId(playerid));
        Onboarding_Load(playerid, Character_GetId(playerid));
        Survival_OnSpawn(playerid);
        Interiors_Reset(playerid);
        Toast_Show(playerid, "SELAMAT DATANG", "Jalani roleplay dengan baik.", THEME_ACCENT);
    }
    return 1;
}

// Latihan tembak: posisi peluru diverifikasi server-side, bukan dari klien.
public OnPlayerWeaponShot(playerid, WEAPON:weaponid, BULLET_HIT_TYPE:hittype,
    hitid, Float:fX, Float:fY, Float:fZ) {
    Range_OnWeaponShot(playerid, weaponid, hittype, hitid, fX, fY, fZ);
    return 1;
}

public OnPlayerDeath(playerid, killerid, WEAPON:reason) {
    #pragma unused killerid, reason
    // Kendaraan hilang saat pemain tewas: mencegah kendaraan telantar.
    Vehicle_DespawnOf(playerid);
    VehicleOwned_Save(playerid);
    VehicleOwned_Destroy(playerid);
    Radio_Stop(playerid);
    return 1;
}

public OnPlayerStateChange(playerid, PLAYER_STATE:newstate, PLAYER_STATE:oldstate) {
    #pragma unused oldstate
    if (newstate != PLAYER_STATE_DRIVER) return 1;

    // Kunci pintu hanya dipasang saat kendaraan muncul, jadi pemain yang baru
    // masuk setelahnya bisa mencoba membajak. Tolak di titik masuk kendaraan.
    new vehicleid = GetPlayerVehicleID(playerid);
    if (vehicleid == INVALID_VEHICLE_ID) return 1;

    new owner = Vehicle_OwnerOfVehicleId(vehicleid);
    if (owner != VEH_NONE && owner != playerid) {
        RemovePlayerFromVehicle(playerid);
        Messages_SendError(playerid, "Kendaraan ini milik orang lain.");
        return 1;
    }

    owner = VehicleOwned_OwnerOfVehicleId(vehicleid);
    if (owner >= 0 && owner != playerid) {
        RemovePlayerFromVehicle(playerid);
        Messages_SendError(playerid, "Kendaraan ini milik orang lain.");
        return 1;
    }
    return 1;
}

public OnPlayerFinishedDownloading(playerid, virtualworld) {
    // Hanya client 0.3.DL yang mengirim callback ini.
    ClientTier_Set(playerid, TIER_DL);
    Log_Debug("client", "tier DL terdeteksi");
    return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[]) {
    if (!Dialog_IsKnown(dialogid)) {
        Log_Warn("dialog", "dialog id tidak dikenal ditolak");
        return 0;
    }

    if (Auth_OnDialogResponse(playerid, dialogid, response, inputtext)) return 1;
    if (Character_OnDialogResponse(playerid, dialogid, response, listitem, inputtext)) return 1;
    if (Identity_OnDialogResponse(playerid, dialogid, response, listitem, inputtext)) return 1;
    if (BankUI_OnDialogResponse(playerid, dialogid, response, listitem, inputtext)) return 1;
    if (Property_OnDialogResponse(playerid, dialogid, response, listitem, inputtext)) return 1;
    if (VehicleRental_OnDialogResponse(playerid, dialogid, response, listitem, inputtext)) return 1;
    if (VehicleShop_OnDialogResponse(playerid, dialogid, response, listitem, inputtext)) return 1;
    if (Radio_OnDialogResponse(playerid, dialogid, response, listitem, inputtext)) return 1;
    if (Range_OnDialogResponse(playerid, dialogid, response, listitem, inputtext)) return 1;
    if (Admin_OnDialogResponse(playerid, dialogid, response, listitem, inputtext)) return 1;
    return 0;
}

forward OnPlayerCancelSelectTextDraw(playerid);

public OnPlayerClickPlayerTextDraw(playerid, PlayerText:playertextid) {
    new promptKind = -1, promptRef = -1;
    if (Prompt_OnClick(playerid, playertextid, promptKind, promptRef)) {
        World_DispatchPrompt(playerid, promptKind, promptRef);
        return 1;
    }
    if (BankUI_OnClick(playerid, playertextid)) return 1;
    if (InventoryUI_OnClick(playerid, playertextid)) return 1;
    if (WarungUI_OnClick(playerid, playertextid)) return 1;
    if (PhoneUI_OnClick(playerid, playertextid)) return 1;
    if (KtpCard_OnClick(playerid, playertextid)) return 1;
    if (SimCard_OnClick(playerid, playertextid)) return 1;

    new createAction = CharCreate_OnClick(playerid, playertextid);
    if (createAction == CC_ACT_HANDLED) return 1;
    if (createAction >= CC_ACT_ASK_FIRST) {
        Character_OnCreateUIAction(playerid, createAction);
        return 1;
    }
    if (Character_OnClickTextDraw(playerid, playertextid)) return 1;
    return 0;
}

public OnPlayerCancelSelectTextDraw(playerid) {
    if (CharCreate_IsOpen(playerid)) {
        CharCreate_Show(playerid);
        return 1;
    }
    if (Character_OnCancelSelect(playerid)) return 1;
    // Android: sentuhan layar saat berjalan (di luar tombol) memicu cancel
    // dan mematikan mode klik. Nyalakan lagi kalau ada UI yang butuh kursor,
    // supaya tombol X / badge [Y] tetap bisa diklik.
    if (KtpCard_IsOpen(playerid) || SimCard_IsOpen(playerid)
        || InventoryUI_IsOpen(playerid) || Prompt_IsActive(playerid)) {
        SelectTextDraw(playerid, THEME_ACCENT);
        return 1;
    }
    return 0;
}

forward OnPlayerPickUpPickup(playerid, pickupid);

public OnPlayerPickUpPickup(playerid, pickupid) {
    // Pickup lokasi = penanda visual saja (interaksi manual via prompt [Y]).
    // Pickup keluar interior tetap disentuh untuk keluar (pintu dalam).
    if (Interiors_OnPickup(playerid, pickupid)) return 1;
    Inv_OnPickup(playerid, pickupid);
    return 1;
}

public OnPlayerKeyStateChange(playerid, KEY:newkeys, KEY:oldkeys) {
    // Tombol Y: padanan keyboard untuk pil prompt (bisa juga diklik langsung).
    if ((newkeys & KEY_YES) && !(oldkeys & KEY_YES)) {
        new promptKind = -1, promptRef = -1;
        if (Prompt_OnKey(playerid, promptKind, promptRef)) {
            World_DispatchPrompt(playerid, promptKind, promptRef);
            return 1;
        }
    }
    return 0;
}

public OnPlayerCommandText(playerid, cmdtext[]) {
    new input[128], command[24], params[96];

    // open.mp mengirim teks tanpa '/', tapi client lama terkadang menyertakannya.
    if (cmdtext[0] == '/') {
        format(input, sizeof (input), "%s", cmdtext[1]);
    } else {
        format(input, sizeof (input), "%s", cmdtext);
    }

    if (!Command_Split(input, command, sizeof (command), params, sizeof (params))) {
        return 0;
    }

    // Log diagnostik: semua perintah tercatat di console.log.
    new cmdLog[128];
    format(cmdLog, sizeof (cmdLog), "perintah %d: /%s %s", playerid, command,
        params);
    Log_Info("cmd", cmdLog);

    if (Chat_HandleCommand(playerid, command, params)) return 1;
    if (World_HandleCommand(playerid, command, params)) return 1;
    if (Warung_HandleCommand(playerid, command, params)) return 1;
    if (Inv_HandleCommand(playerid, command, params)) return 1;
    if (Survival_HandleCommand(playerid, command, params)) return 1;
    if (VehicleRental_HandleCommand(playerid, command, params)) return 1;
    if (VehicleRentalAdmin_HandleCommand(playerid, command, params)) return 1;
    if (VehicleShop_HandleCommand(playerid, command, params)) return 1;
    if (Radio_HandleCommand(playerid, command, params)) return 1;
    if (Fuel_HandleCommand(playerid, command, params)) return 1;
    if (Onboarding_HandleCommand(playerid, command, params)) return 1;
    if (Range_HandleCommand(playerid, command, params)) return 1;
    if (VehicleShop_AdminCommand(playerid, command, params)) return 1;
    if (Identity_HandleCommand(playerid, command, params)) return 1;
    if (Tilang_HandleCommand(playerid, command, params)) return 1;
    if (WarungAdmin_HandleCommand(playerid, command, params)) return 1;
    if (PropertyAdmin_HandleCommand(playerid, command, params)) return 1;
    if (Admin_HandleCommand(playerid, command, params)) return 1;

    Messages_SendError(playerid, "Perintah tidak dikenal. Ketik /help.");
    return 1;
}

public Timer_OnClientTierProbe(playerid) {
    if (!IsPlayerConnected(playerid)) return 0;

    if (ClientTier_DetectTimeout(playerid)) {
        Log_Debug("client", "tier 0.3.7 (tidak ada sinyal download)");
    }
    return 1;
}

public Timer_OnAutoSave() {
    new players[MAX_PLAYERS];
    new count = GetPlayers(players, sizeof (players));

    for (new index = 0; index < count; index++) {
        if (Character_GetId(players[index]) > 0) {
            VehicleOwned_Save(players[index]);
            Fuel_SaveOwned(players[index]);
            Character_Save(players[index]);
        }
    }
    Log_Debug("autosave", "semua karakter disimpan");
    return 1;
}

public Timer_OnEconomyTick() {
    new query[192];
    format(query, sizeof (query),
        "SELECT COALESCE(SUM(delta), 0) FROM money_log WHERE delta > 0 \
         AND created_at >= datetime('now', '-1 hour')");
    new faucet = DB_Int(query, 0);

    format(query, sizeof (query),
        "SELECT COALESCE(SUM(-delta), 0) FROM money_log WHERE delta < 0 \
         AND created_at >= datetime('now', '-1 hour')");
    new sink = DB_Int(query, 0);

    new report[192];
    if (sink > 0) {
        format(report, sizeof (report), "faucet=%d sink=%d rasio=%d.%02d",
            faucet, sink, faucet / sink, ((faucet % sink) * 100) / sink);
    } else {
        format(report, sizeof (report), "faucet=%d sink=0 (belum ada sink)", faucet);
    }
    Log_Info("economy", report);
    return 1;
}

public Timer_OnHudTick() {
    HUD_Tick();
    return 1;
}

public Timer_OnToastTick() {
    Toast_Tick();
    return 1;
}

public Timer_OnPromptTick() {
    World_PromptTick();
    PhoneUI_Tick();
    Toast_Animate();
    Inv_Tick();
    Survival_Tick();
    Vehicle_Tick();
    // Buka layanan lokasi yang pickup-nya disentuh tick sebelumnya (di luar
    // callback pickup - aman untuk client, mencegah force close).
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;
        Interiors_PendingTick(playerid);
    }
    return 1;
}

public Timer_OnTelemetryTick() {
    Telemetry_Tick();
    return 1;
}