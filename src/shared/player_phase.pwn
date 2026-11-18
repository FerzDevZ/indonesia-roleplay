// ---------------------------------------------------------------------------
// module      : shared/player_phase
// entry       : Phase_Reset()
// depends     : -
// owns tables : -
// public api  : Phase_Reset(), Phase_Set(), Phase_Get(), Phase_CanAct(),
//               Phase_CanChat(), Phase_IsInWorld(), Phase_Name()
// ---------------------------------------------------------------------------
#if defined _INC_PLAYER_PHASE
    #endinput
#endif
#define _INC_PLAYER_PHASE

enum E_PLAYER_PHASE {
    PHASE_NONE = 0,
    PHASE_CONNECTING,
    PHASE_AUTHENTICATING,
    PHASE_CHAR_SELECT,
    PHASE_LOADING,
    PHASE_SPAWNING,
    PHASE_ALIVE,
    PHASE_INJURED,
    PHASE_ADMIN_SPECTATE
}

static E_PLAYER_PHASE:gPhase[MAX_PLAYERS] = { PHASE_NONE, ... };

stock Phase_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gPhase[playerid] = PHASE_NONE;
    return 1;
}

stock Phase_Set(playerid, E_PLAYER_PHASE:phase) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gPhase[playerid] = phase;
    return 1;
}

stock E_PLAYER_PHASE:Phase_Get(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return PHASE_NONE;
    return gPhase[playerid];
}

stock bool:Phase_IsInWorld(playerid) {
    switch (Phase_Get(playerid)) {
        case PHASE_ALIVE, PHASE_INJURED, PHASE_ADMIN_SPECTATE: return true;
    }
    return false;
}

stock bool:Phase_CanAct(playerid) {
    return Phase_Get(playerid) == PHASE_ALIVE;
}

stock bool:Phase_CanChat(playerid) {
    return Phase_IsInWorld(playerid);
}

stock bool:Phase_CanAuthenticate(playerid) {
    return Phase_Get(playerid) == PHASE_AUTHENTICATING;
}

stock Phase_Name(playerid, dest[], maxlength = sizeof (dest)) {
    switch (Phase_Get(playerid)) {
        case PHASE_NONE:           return format(dest, maxlength, "NONE");
        case PHASE_CONNECTING:     return format(dest, maxlength, "CONNECTING");
        case PHASE_AUTHENTICATING: return format(dest, maxlength, "AUTHENTICATING");
        case PHASE_CHAR_SELECT:    return format(dest, maxlength, "CHAR_SELECT");
        case PHASE_LOADING:        return format(dest, maxlength, "LOADING");
        case PHASE_SPAWNING:       return format(dest, maxlength, "SPAWNING");
        case PHASE_ALIVE:          return format(dest, maxlength, "ALIVE");
        case PHASE_INJURED:        return format(dest, maxlength, "INJURED");
        case PHASE_ADMIN_SPECTATE: return format(dest, maxlength, "ADMIN_SPECTATE");
    }
    return format(dest, maxlength, "UNKNOWN");
}
