// ---------------------------------------------------------------------------
// module      : shared/client_tier
// entry       : -
// depends     : -
// owns tables : -
// public api  : ClientTier_Set(), ClientTier_Get(), ClientTier_HasCustomArt(),
//               ClientTier_DetectTimeout()
// Aturan      : tidak ada mekanik inti yang boleh bergantung pada model kustom.
//               ClientTier_HasCustomArt() hanya untuk kosmetik.
// ---------------------------------------------------------------------------
#if defined _INC_CLIENT_TIER
    #endinput
#endif
#define _INC_CLIENT_TIER

#define TIER_DETECT_SECONDS (10)

enum E_CLIENT_TIER {
    TIER_UNKNOWN = 0,
    TIER_037,
    TIER_DL
}

static E_CLIENT_TIER:gTier[MAX_PLAYERS] = { TIER_UNKNOWN, ... };

stock ClientTier_Set(playerid, E_CLIENT_TIER:tier) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gTier[playerid] = tier;
    return 1;
}

stock E_CLIENT_TIER:ClientTier_Get(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return TIER_UNKNOWN;
    return gTier[playerid];
}

stock bool:ClientTier_HasCustomArt(playerid) {
    return ClientTier_Get(playerid) == TIER_DL;
}

stock ClientTier_Reset(playerid) {
    return ClientTier_Set(playerid, TIER_UNKNOWN);
}

// Client 0.3.7 tidak pernah mengirim OnPlayerFinishedDownloading
stock ClientTier_DetectTimeout(playerid) {
    if (ClientTier_Get(playerid) != TIER_UNKNOWN) {
        return 0;
    }
    ClientTier_Set(playerid, TIER_037);
    return 1;
}

stock ClientTier_Name(playerid, dest[], maxlength = sizeof (dest)) {
    switch (ClientTier_Get(playerid)) {
        case TIER_UNKNOWN: return format(dest, maxlength, "unknown");
        case TIER_037: return format(dest, maxlength, "0.3.7");
        case TIER_DL:  return format(dest, maxlength, "0.3.DL");
    }
    return format(dest, maxlength, "?");
}
