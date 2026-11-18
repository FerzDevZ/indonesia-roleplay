// ---------------------------------------------------------------------------
// module      : core/telemetry
// entry       : Telemetry_Boot()
// depends     : core/log
// owns tables : -
// public api  : Telemetry_Boot(), Telemetry_Tick(), Telemetry_Players(),
//               Telemetry_Uptime(), Telemetry_Report()
// ---------------------------------------------------------------------------
#if defined _INC_TELEMETRY
    #endinput
#endif
#define _INC_TELEMETRY

static gBootTick = 0;
static gPeakPlayers = 0;

stock Telemetry_Boot() {
    gBootTick = GetTickCount();
    Log_Info("telemetry", "mulai");
    return 1;
}

stock Telemetry_Tick() {
    new players[MAX_PLAYERS];
    new count = GetPlayers(players, sizeof (players));

    if (count > gPeakPlayers) {
        gPeakPlayers = count;
    }

    if (!Settings_DebugEnabled()) {
        return 1;
    }

    new report[160];
    format(report, sizeof (report),
        "pemain=%d puncak=%d uptime=%d dt=%d",
        count, gPeakPlayers, Telemetry_Uptime(), GetTickCount() - gBootTick);
    Log_Debug("telemetry", report);
    return 1;
}

stock Telemetry_Players() {
    new players[MAX_PLAYERS];
    return GetPlayers(players, sizeof (players));
}

stock Telemetry_Peak() {
    return gPeakPlayers;
}

stock Telemetry_Uptime() {
    return (GetTickCount() - gBootTick) / 1000;
}

stock Telemetry_Report(dest[], maxlength = sizeof (dest)) {
    return format(dest, maxlength,
        "uptime %d detik, pemain %d, puncak %d, timer %d",
        Telemetry_Uptime(), Telemetry_Players(), gPeakPlayers, Timer_Count());
}
