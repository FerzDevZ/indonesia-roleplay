// ---------------------------------------------------------------------------
// module      : core/timer
// entry       : Timer_Boot()
// depends     : core/log, core/settings
// owns tables : -
// public api  : Timer_Boot(), Timer_Add(), Timer_Count(), Timer_NameAt()
// Catatan     : tidak ada SetTimer liar di domain. Semua timer terdaftar di sini
//               supaya bisa diaudit dalam satu daftar.
// ---------------------------------------------------------------------------
#if defined _INC_TIMER
    #endinput
#endif
#define _INC_TIMER

// Forward untuk setiap timer berkala. Semua timer wajib terdaftar di sini
// supaya tidak ada SetTimer liar di domain.
forward Timer_OnClientTierProbe(playerid);
forward Timer_OnAutoSave();
forward Timer_OnEconomyTick();
forward Timer_OnTelemetryTick();
forward Timer_OnHudTick();
forward Timer_OnToastTick();
forward Timer_OnPromptTick();
forward Timer_OnFuelTick();
forward Timer_OnOnboardingTick();
forward Timer_OnRangeTick();

#define MAX_REGISTERED_TIMERS (16)

static gTimerNames[MAX_REGISTERED_TIMERS][40];
static gTimerCount = 0;

stock Timer_Boot() {
    Timer_Add("Timer_OnAutoSave", AUTOSAVE_SECONDS * 1000, true);
    Timer_Add("Timer_OnEconomyTick", 3_600_000, true);
    Timer_Add("Timer_OnTelemetryTick", 60_000, true);
    Timer_Add("Timer_OnHudTick", 1_000, true);
    Timer_Add("Timer_OnToastTick", 1_000, true);
    Timer_Add("Timer_OnPromptTick", 500, true);

    new report[64];
    format(report, sizeof (report), "%d timer terdaftar", gTimerCount);
    Log_Info("timer", report);
    return 1;
}

stock bool:Timer_Add(const functionName[], interval, bool:repeating) {
    if (gTimerCount >= MAX_REGISTERED_TIMERS) {
        Log_Error("timer", "registry penuh, timer ditolak");
        return false;
    }
    if (interval < 100) {
        Log_Error("timer", "interval di bawah 100ms ditolak");
        return false;
    }

    new timerId = SetTimer(functionName, interval, repeating);
    if (timerId == 0) {
        Log_Error("timer", "SetTimer gagal");
        return false;
    }

    format(gTimerNames[gTimerCount], 40, "%s", functionName);
    gTimerCount++;
    return true;
}

stock Timer_Count() {
    return gTimerCount;
}

stock Timer_NameAt(index, dest[], maxlength = sizeof (dest)) {
    if (index < 0 || index >= gTimerCount) {
        dest[0] = '\0';
        return 0;
    }
    return format(dest, maxlength, "%s", gTimerNames[index]);
}

// Timer sekali-jalan untuk satu pemain. Dipakai domain supaya tidak ada
// SetTimerEx liar di luar modul ini.
stock bool:Timer_OnceForPlayer(const functionName[], playerid, interval) {
    return SetTimerEx(functionName, interval, false, "i", playerid) != 0;
}

stock bool:Timer_Once(const functionName[], interval) {
    return SetTimer(functionName, interval, false) != 0;
}
