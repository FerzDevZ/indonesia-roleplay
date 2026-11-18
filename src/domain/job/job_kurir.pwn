// ---------------------------------------------------------------------------
// module      : domain/job/job_kurir
// entry       : JobKurir_Boot()
// depends     : core/db, core/log, shared/money, shared/messages, ui/toast,
//               domain/world/locations
// owns tables : -
// public api  : JobKurir_Boot(), JobKurir_AtCenter(), JobKurir_IsCarrying(),
//               JobKurir_TargetIndex(), JobKurir_Deliver(), JobKurir_Cancel(),
//               JobKurir_Reset()
// Alur        : Job Center [Y] Ambil Paket -> tujuan acak dari tabel locations
//               -> checkpoint + prompt [Y] Serahkan Paket -> bayaran Rp 5.000
//               -> kembali ke Job Center untuk paket berikutnya.
// Aturan      : Tanpa paket di tangan = tanpa bayaran. Paket hilang saat
//               disconnect (state memori, bukan DB - kerja sementara).
// ---------------------------------------------------------------------------
#if defined _INC_JOB_KURIR
    #endinput
#endif
#define _INC_JOB_KURIR

#define KURIR_PAY             (5000)
#define KURIR_STATE_IDLE      (0)
#define KURIR_STATE_CARRYING  (1)

static gKurirState[MAX_PLAYERS];
static gKurirTarget[MAX_PLAYERS];       // indeks lokasi tujuan antaran

stock JobKurir_Boot() {
    Log_Info("job_kurir", "siap (bayaran Rp 5.000 per antaran)");
    return 1;
}

stock JobKurir_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gKurirState[playerid] = KURIR_STATE_IDLE;
    gKurirTarget[playerid] = -1;
    DisablePlayerCheckpoint(playerid);
    return 1;
}

stock bool:JobKurir_IsCarrying(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gKurirState[playerid] == KURIR_STATE_CARRYING;
}

stock JobKurir_TargetIndex(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    return gKurirTarget[playerid];
}

// Pemain memicu Job Center (prompt [Y] atau datang ke lokasinya).
stock bool:JobKurir_AtCenter(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (!Phase_CanAct(playerid)) return false;

    if (gKurirState[playerid] == KURIR_STATE_CARRYING) {
        Toast_Show(playerid, "JOB CENTER",
            "Antar dulu paketmu, jangan di bawa-bawa kemari.", THEME_DANGER);
        return true;
    }

    return JobKurir_Assign(playerid);
}

// Pilih tujuan acak dari tabel lokasi (bukan Job Center sendiri).
static bool:JobKurir_Assign(playerid) {
    new total = Locations_Count();
    if (total < 2) {
        Toast_Show(playerid, "JOB CENTER", "Belum ada tujuan antaran.", THEME_DANGER);
        return false;
    }

    new candidate = -1;
    for (new attempt = 0; attempt < 16 && candidate < 0; attempt++) {
        candidate = random(total);
        if (candidate == Locations_FindByCode("JOB_CENTER")) candidate = -1;
    }
    if (candidate < 0) candidate = 0;

    new Float:x, Float:y, Float:z;
    Locations_Pos(candidate, x, y, z);
    SetPlayerCheckpoint(playerid, x, y, z, 2.5);

    new name[40], detail[96];
    Locations_Name(candidate, name, sizeof (name));
    format(detail, sizeof (detail), "Antar paket ke %s.", name);
    Toast_Show(playerid, "KURIR", detail, THEME_ACCENT);

    gKurirState[playerid] = KURIR_STATE_CARRYING;
    gKurirTarget[playerid] = candidate;
    Onboarding_Event(playerid, ONBOARD_JOB);
    return true;
}

// Pemain sampai di checkpoint: prompt [Y] Serahkan Paket ditangani world.
stock bool:JobKurir_Deliver(playerid) {
    if (!JobKurir_IsCarrying(playerid)) return false;
    if (gKurirTarget[playerid] < 0) return false;

    // Validasi server-side: benar-benar dekat tujuan? (anti teleport cheat)
    new Float:x, Float:y, Float:z;
    Locations_Pos(gKurirTarget[playerid], x, y, z);
    if (GetPlayerDistanceFromPoint(playerid, x, y, z) > 6.0) {
        Toast_Show(playerid, "KURIR", "Kamu belum di titik antaran.", THEME_DANGER);
        return false;
    }

    if (!Money_Add(playerid, KURIR_PAY, MONEY_REASON_JOB)) {
        Toast_Show(playerid, "KURIR", "Bayaran gagal diproses.", THEME_DANGER);
        return false;
    }

    new money[24], detail[96];
    Messages_Money(KURIR_PAY, money, sizeof (money));
    format(detail, sizeof (detail), "Paket diterima. Upah Rp %s.", money);
    Toast_Show(playerid, "KURIR", detail, THEME_OK);

    gKurirState[playerid] = KURIR_STATE_IDLE;
    gKurirTarget[playerid] = -1;
    DisablePlayerCheckpoint(playerid);
    Onboarding_Event(playerid, ONBOARD_DELIVER);
    return true;
}

// /kerjabatal: paket hangus, tidak ada bayaran.
stock bool:JobKurir_Cancel(playerid) {
    if (!JobKurir_IsCarrying(playerid)) {
        Messages_SendError(playerid, "Kamu tidak sedang membawa paket.");
        return true;
    }
    gKurirState[playerid] = KURIR_STATE_IDLE;
    gKurirTarget[playerid] = -1;
    DisablePlayerCheckpoint(playerid);
    Toast_Show(playerid, "KURIR", "Paket dibatalkan. Tidak ada upah.", THEME_DANGER);
    return true;
}
