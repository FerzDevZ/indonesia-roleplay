// ---------------------------------------------------------------------------
// module      : domain/world/world
// entry       : World_Boot()
// depends     : ui/prompt, ui/toast, domain/world/locations, domain/job/job_kurir,
//               domain/identity, shared/player_phase, ui/uimodal
// public api  : World_Boot(), World_PromptTick(), World_DispatchPrompt(),
//               World_Reset()
// Tugas       : SATU-SATUNYA jembatan prompt [Y] ke domain. Scan tiap 500 ms:
//               interaksi pemain menang atas lokasi; paket kurir siap serah
//               menang atas semuanya. Dispatch pakai kind + ref dari prompt.
// ---------------------------------------------------------------------------
#if defined _INC_WORLD
    #endinput
#endif
#define _INC_WORLD

#define WORLD_TEXT_PLAYER    "[Y] Tunjukkan KTP"

stock World_Boot() {
    Log_Info("world", "siap");
    return 1;
}

// Status kerja: dipakai /kerja dan aplikasi KERJA di ponsel.
stock World_ShowJobStatus(playerid) {
    if (JobKurir_IsCarrying(playerid)) {
        new name[40], detail[96];
        Locations_Name(JobKurir_TargetIndex(playerid), name, sizeof (name));
        format(detail, sizeof (detail), "Antar paket ke %s (lihat checkpoint merah).", name);
        Toast_Show(playerid, "KURIR", detail, THEME_ACCENT);
    } else {
        Toast_Show(playerid, "KURIR",
            "Ambil paket di Job Center dekat stasiun.", THEME_ACCENT);
    }
    return 1;
}

// Perintah dunia: /hp (smartphone), /kerja (status), /kerjabatal.
stock bool:World_HandleCommand(playerid, const command[], const params[]) {
    #pragma unused params

    if (!strcmp(command, "hp", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        PhoneUI_Open(playerid);
        return true;
    }
    if (!strcmp(command, "kerja", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        World_ShowJobStatus(playerid);
        return true;
    }
    if (!strcmp(command, "kerjabatal", true)) {
        if (!Phase_CanAct(playerid)) {
            Messages_SendError(playerid, MSG_NOT_ALIVE);
            return true;
        }
        JobKurir_Cancel(playerid);
        return true;
    }
    return false;
}

stock World_Reset(playerid) {
    JobKurir_Reset(playerid);
    return 1;
}

// Tick 500 ms (Timer_OnPromptTick): tentukan pil yang tampil per pemain.
stock World_PromptTick() {
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) {
            continue;
        }
        if (!Phase_CanAct(playerid) || UIModal_Active(playerid) != UI_NONE) {
            Prompt_Hide(playerid);
            continue;
        }

        // Prioritas 1: paket kurir siap diserahkan di titik tujuan.
        if (JobKurir_IsCarrying(playerid)) {
            new target = JobKurir_TargetIndex(playerid);
            new locIdx = Locations_Near(playerid);
            if (locIdx == target && target >= 0) {
                Prompt_Present(playerid, "[Y] Serahkan Paket",
                    PROMPT_KIND_LOCATION, target);
                continue;
            }
        }

        // Prioritas 2: pemain lain terdekat (interaksi sosial).
        new neighbor = Prompt_ScanNeighbor(playerid);
        if (neighbor >= 0) {
            Prompt_Present(playerid, WORLD_TEXT_PLAYER,
                PROMPT_KIND_PLAYER, neighbor);
            continue;
        }

        // Prioritas 3: lokasi layanan (ATM, loket, warung, gedung, dsb.).
        // Hysteresis: pil yang sedang tampil bertahan sampai pemain benar-
        // benar menjauh (radius + 1.5 m) supaya tidak kedip di batas radius.
        new Float:margin = 0.0;
        if (Prompt_ActiveKind(playerid) == PROMPT_KIND_LOCATION
            && Prompt_ActiveRef(playerid) >= 0) {
            margin = 1.5;
        }
        new location = Locations_NearWithin(playerid, margin);
        if (location >= 0) {
            new name[40], action[24], text[48];
            Locations_Name(location, name, sizeof (name));
            Locations_Action(location, action, sizeof (action));
            World_LocationLabel(playerid, location, action, name,
                text, sizeof (text));
            Prompt_Present(playerid, text, PROMPT_KIND_LOCATION, location);
            continue;
        }

        Prompt_Hide(playerid);
    }
    return 1;
}

// Label pil per jenis lokasi - teks aksi yang manusiawi, bukan kode mentah.
static World_LocationLabel(playerid, locIndex, const action[], const name[],
    dest[], maxlength) {
    if (strcmp(action, LOC_ACT_ATM, false) == 0) {
        return format(dest, maxlength, "[Y] Akses ATM");
    }
    if (strcmp(action, LOC_ACT_LOKET_PD, false) == 0) {
        return format(dest, maxlength, "[Y] Daftar Ujian SIM");
    }
    if (strcmp(action, LOC_ACT_JOB_CENTER, false) == 0) {
        return format(dest, maxlength, "[Y] Ambil Paket");
    }
    if (strcmp(action, LOC_ACT_WARUNG, false) == 0) {
        return format(dest, maxlength, "[Y] Belanja Warung");
    }
    if (strcmp(action, LOC_ACT_GEDUNG, false) == 0) {
        // Label dinamis mengikuti status gedung: dijual / milik sendiri /
        // milik orang lain.
        new code[LOC_CODE_LEN];
        Locations_Code(locIndex, code, sizeof (code));
        new propIndex = Property_FindByLocation(code);
        if (propIndex < 0) {
            return format(dest, maxlength, "[Y] %s", name);
        }
        new owner = Property_OwnerOf(propIndex);
        if (owner == 0) {
            return format(dest, maxlength, "[Y] Beli Gedung (Rp %d)",
                Property_PriceOf(propIndex));
        }
        if (owner == Character_GetId(playerid)) {
            return format(dest, maxlength, "[Y] Kelola Toko");
        }
        if (!Property_IsOpenOf(propIndex)) {
            return format(dest, maxlength, "[Y] Toko Tutup");
        }
        return format(dest, maxlength, "[Y] Masuk Toko");
    }
    if (strcmp(action, LOC_ACT_RS, false) == 0) {
        return format(dest, maxlength, "[Y] Periksa (Rp 10.000)");
    }
    return format(dest, maxlength, "[Y] %s", name);
}

// Dispatch hasil konsumsi prompt (tombol Y atau klik badge).
stock bool:World_DispatchPrompt(playerid, kind, refId) {
    if (kind == PROMPT_KIND_PLAYER) {
        if (refId < 0 || refId >= MAX_PLAYERS || !IsPlayerConnected(refId)) {
            return false;
        }
        Identity_ShowKTPTo(playerid, Character_GetId(refId));
        return true;
    }
    if (kind == PROMPT_KIND_LOCATION) {
        return Locations_Activate(playerid, refId);
    }
    return false;
}
