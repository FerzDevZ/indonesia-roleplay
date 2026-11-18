// ---------------------------------------------------------------------------
// module      : ui/prompt
// entry       : -
// depends     : ui/theme, ui/trxtdraw, ui/uimodal, shared/player_phase
// owns tables : -
// public api  : Prompt_Present(), Prompt_Hide(), Prompt_Destroy(),
//               Prompt_IsActive(), Prompt_ScanNeighbor(), Prompt_OnKey(),
//               Prompt_OnClick()
// Tampilan    : pil interaksi kontekstual ala FiveM di bawah-tengah: badge
//               tombol [Y] terang (bisa diklik - padanan sentuh Android)
//               + teks aksi pada pil kaca.
// Aturan      : Modul ini TIDAK tahu isi aksinya. Isi (kind + ref) dikonsumsi
//               lewat out-params dan didispatch oleh domain/world. kind:
//               PROMPT_KIND_PLAYER (ref = playerid) atau PROMPT_KIND_LOCATION
//               (ref = indeks lokasi).
// ---------------------------------------------------------------------------
#if defined _INC_UI_PROMPT
    #endinput
#endif
#define _INC_UI_PROMPT

#include "theme.pwn"
#include "uimodal.pwn"

#define PROMPT_RADIUS       (3.0)
#define PROMPT_X            (270.0)
#define PROMPT_Y            (426.0)
#define PROMPT_BADGE_W      (30.0)
#define PROMPT_BADGE_H      (24.0)
#define PROMPT_LABEL_X      (PROMPT_X + PROMPT_BADGE_W + 8.0)
#define PROMPT_TEXT_MAX     (40)

#define PROMPT_ID_ACT       (220)

#define PROMPT_KIND_PLAYER      (0)
#define PROMPT_KIND_LOCATION    (1)

static bool:gPromptActive[MAX_PLAYERS];
static gPromptKind[MAX_PLAYERS];
static gPromptRef[MAX_PLAYERS];
static gPromptLastText[MAX_PLAYERS][PROMPT_TEXT_MAX + 1];
static PlayerText:gPromptBadge[MAX_PLAYERS];
static PlayerText:gPromptPill[MAX_PLAYERS];
static PlayerText:gPromptLabel[MAX_PLAYERS];

stock bool:Prompt_IsActive(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    return gPromptActive[playerid];
}

// Tampilkan/perbarui pil. kind: PROMPT_KIND_*; refId sesuai kind.
// PENTING: modul ini TIDAK memanggil SelectTextDraw. SelectTextDraw memaksa
// client masuk mode kursor (pemain merasa "freeze" / tidak bisa jalan).
// Pil hanya informasi + tombol [Y]; mode klik hanya dipakai modal lain.
stock bool:Prompt_Present(playerid, const text[], kind, refId) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (!Phase_CanAct(playerid)) return false;

    new trimmed[PROMPT_TEXT_MAX + 1];
    format(trimmed, sizeof (trimmed), "%.40s", text);

    if (gPromptActive[playerid]) {
        // Sudah tampil: kalau isi & target tidak berubah, JANGAN sentuh
        // textdraw sama sekali (anti kedip di tick 500 ms).
        if (gPromptKind[playerid] == kind && gPromptRef[playerid] == refId
            && strcmp(gPromptLastText[playerid], trimmed, false) == 0) {
            return true;
        }
        PlayerTextDrawSetString(playerid, gPromptLabel[playerid], trimmed);
        PlayerTextDrawTextSize(playerid, gPromptPill[playerid],
            strlen(trimmed) * 5.0 + 18.0, PROMPT_BADGE_H);
        PlayerTextDrawShow(playerid, gPromptPill[playerid]);
        format(gPromptLastText[playerid], PROMPT_TEXT_MAX + 1, "%s", trimmed);
        gPromptKind[playerid] = kind;
        gPromptRef[playerid] = refId;
        return true;
    }

    // Badge [Y]: penanda tombol (bukan hitbox klik - biar tidak perlu kursor).
    gPromptBadge[playerid] = TrxTd_Sprite(playerid, PROMPT_X, PROMPT_Y,
        THEME_SPRITE_WHITE, PROMPT_BADGE_W, PROMPT_BADGE_H, THEME_ACCENT, false);

    // Pil kaca di belakang teks aksi; lebar mengikuti panjang teks.
    gPromptPill[playerid] = TrxTd_Sprite(playerid,
        PROMPT_X + PROMPT_BADGE_W - 2.0, PROMPT_Y, THEME_SPRITE_WHITE,
        strlen(trimmed) * 5.0 + 18.0, PROMPT_BADGE_H, THEME_GLASS);

    gPromptLabel[playerid] = TrxTd_Text(playerid, PROMPT_LABEL_X,
        PROMPT_Y + 4.0, trimmed, THEME_FONT_BODY, 0.18, 0.80, THEME_TEXT,
        TEXT_DRAW_ALIGN:TEXT_DRAW_ALIGN_LEFT);

    gPromptActive[playerid] = true;
    gPromptKind[playerid] = kind;
    gPromptRef[playerid] = refId;
    format(gPromptLastText[playerid], PROMPT_TEXT_MAX + 1, "%s", trimmed);
    return true;
}

stock bool:Prompt_Hide(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (!gPromptActive[playerid]) return false;

    TrxTd_Kill(playerid, gPromptLabel[playerid]);
    TrxTd_Kill(playerid, gPromptPill[playerid]);
    TrxTd_Kill(playerid, gPromptBadge[playerid]);
    gPromptActive[playerid] = false;
    gPromptKind[playerid] = PROMPT_KIND_PLAYER;
    gPromptRef[playerid] = -1;
    gPromptLastText[playerid][0] = 0;
    // JANGAN sentuh mode kursor di sini: modal lain mungkin masih memakainya.
    return true;
}

stock Prompt_Destroy(playerid) {
    return Prompt_Hide(playerid);
}

// Deteksi tetangga pemain terdekat (tanpa menggambar apa pun). Return -1 kalau
// tidak ada. Dipanggil dari tick world, bukan dari dalam modul ini.
stock Prompt_ScanNeighbor(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    if (!Phase_CanAct(playerid)) return -1;

    new nearest = -1;
    new Float:nearestDist = PROMPT_RADIUS;
    for (new other = 0; other < MAX_PLAYERS; other++) {
        if (other == playerid || !IsPlayerConnected(other)) continue;
        if (!Phase_CanAct(other)) continue;

        new Float:targetX, Float:targetY, Float:targetZ;
        GetPlayerPos(other, targetX, targetY, targetZ);
        new Float:dist = GetPlayerDistanceFromPoint(playerid, targetX, targetY, targetZ);
        if (dist < nearestDist) {
            nearestDist = dist;
            nearest = other;
        }
    }
    return nearest;
}

// Status prompt saat ini untuk modul pemanggil (hysteresis tick world).
// Return -1 kalau tidak ada prompt aktif, selain itu PROMPT_KIND_*.
stock Prompt_ActiveKind(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    if (!gPromptActive[playerid]) return -1;
    return gPromptKind[playerid];
}

stock Prompt_ActiveRef(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    if (!gPromptActive[playerid]) return -1;
    return gPromptRef[playerid];
}

// Konsumsi prompt: keluarkan kind + ref lewat out-params lalu sembunyikan.
// Return false kalau tidak ada prompt aktif / target tidak sah.
stock bool:Prompt_Consume(playerid, &kind, &refId) {
    if (!gPromptActive[playerid]) return false;
    if (gPromptRef[playerid] < 0) return false;

    kind = gPromptKind[playerid];
    refId = gPromptRef[playerid];
    Prompt_Hide(playerid);
    return true;
}

// Tombol Y ditekan: konsumsi prompt aktif.
stock bool:Prompt_OnKey(playerid, &kind, &refId) {
    return Prompt_Consume(playerid, kind, refId);
}

// Badge [Y] diklik (Android): konsumsi prompt aktif.
stock bool:Prompt_OnClick(playerid, PlayerText:clicked, &kind, &refId) {
    if (!gPromptActive[playerid]) return false;
    if (TrxTd_ResolveClick(playerid, clicked) != PROMPT_ID_ACT) return false;
    return Prompt_Consume(playerid, kind, refId);
}
