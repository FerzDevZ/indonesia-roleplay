// ---------------------------------------------------------------------------
// module      : shared/money
// entry       : Money_Load()
// depends     : core/db, core/log
// owns tables : characters.cash, characters.bank_balance, money_log
// public api  : Money_Load(), Money_Save(), Money_GetCash(), Money_GetBank(),
//               Money_Add(), Money_Take(), Money_Transfer(), Money_Debt()
// Aturan      : SATU-SATUNYA modul yang boleh menulis kolom saldo. Setiap
//               mutasi menghasilkan baris money_log dengan reason bertipe.
// ---------------------------------------------------------------------------
#if defined _INC_MONEY
    #endinput
#endif
#define _INC_MONEY

#define MONEY_REASON_START        "START_CASH"
#define MONEY_REASON_SALARY       "SALARY"
#define MONEY_REASON_SALARY_FACTION "SALARY_FACTION"
#define MONEY_REASON_JOB          "JOB_PAYOUT"
#define MONEY_REASON_FINE         "FINE"
#define MONEY_REASON_TAX          "TAX"
#define MONEY_REASON_ADMIN        "ADMIN_GIVE"
#define MONEY_REASON_TRANSFER     "TRANSFER"
#define MONEY_REASON_HOSPITAL     "HOSPITAL"
#define MONEY_REASON_FOOD         "FOOD"
#define MONEY_REASON_PROPERTY     "PROPERTY"
#define MONEY_REASON_DEPOSIT      "DEPOSIT"
#define MONEY_REASON_WITHDRAW     "WITHDRAW"
#define MONEY_REASON_RENTAL       "RENTAL"
#define MONEY_REASON_VEHICLE      "VEHICLE"
#define MONEY_REASON_BANK_XFER    "BANK_TRANSFER"
#define MONEY_REASON_BANK_FEE     "BANK_FEE"

#define WALLET_CASH "cash"
#define WALLET_BANK "bank"

// Biaya admin transfer antar rekening: 1%, minimal Rp 1.000.
#define BANK_FEE_PERCENT        (1)
#define BANK_FEE_MINIMUM        (1000)
#define BANK_AMOUNT_MINIMUM     (1000)
#define BANK_AMOUNT_MAXIMUM     (50000000)

static gCharacterId[MAX_PLAYERS] = { -1, ... };
static gCash[MAX_PLAYERS];
static gBank[MAX_PLAYERS];

stock Money_Reset(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    gCharacterId[playerid] = -1;
    gCash[playerid] = 0;
    gBank[playerid] = 0;
    return 1;
}

stock bool:Money_Load(playerid, characterId) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;

    new query[128];
    format(query, sizeof (query),
        "SELECT COUNT(*) FROM characters WHERE character_id = %d", characterId);
    if (DB_Int(query, 0) < 1) {
        Log_Error("money", "karakter tidak ditemukan saat load saldo");
        return false;
    }

    format(query, sizeof (query),
        "SELECT cash FROM characters WHERE character_id = %d", characterId);
    gCash[playerid] = DB_Int(query, 0);

    format(query, sizeof (query),
        "SELECT bank_balance FROM characters WHERE character_id = %d", characterId);
    gBank[playerid] = DB_Int(query, 0);

    gCharacterId[playerid] = characterId;
    return true;
}

stock Money_CharacterId(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return -1;
    return gCharacterId[playerid];
}

stock Money_GetCash(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return gCash[playerid];
}

stock Money_GetBank(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return 0;
    return gBank[playerid];
}

stock bool:Money_Add(playerid, amount, const reason[], actorCharacterId = -1) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (amount <= 0) return false;
    if (gCharacterId[playerid] < 1) return false;

    gCash[playerid] += amount;
    Money_Persist(playerid, WALLET_CASH);
    Money_Log(gCharacterId[playerid], amount, gCash[playerid], WALLET_CASH, reason, actorCharacterId);
    return true;
}

stock bool:Money_Take(playerid, amount, const reason[], actorCharacterId = -1) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (amount <= 0) return false;
    if (gCharacterId[playerid] < 1) return false;
    if (gCash[playerid] < amount) return false;

    gCash[playerid] -= amount;
    Money_Persist(playerid, WALLET_CASH);
    Money_Log(gCharacterId[playerid], -amount, gCash[playerid], WALLET_CASH, reason, actorCharacterId);
    return true;
}

// Saldo boleh minus (utang). Dipakai untuk denda yang tidak bisa dihindari.
stock bool:Money_Debt(playerid, amount, const reason[], actorCharacterId = -1) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (amount <= 0) return false;
    if (gCharacterId[playerid] < 1) return false;

    gCash[playerid] -= amount;
    Money_Persist(playerid, WALLET_CASH);
    Money_Log(gCharacterId[playerid], -amount, gCash[playerid], WALLET_CASH, reason, actorCharacterId);
    return true;
}

stock bool:Money_Transfer(senderId, targetId, amount) {
    if (!Validate_PlayerId(senderId) || !Validate_PlayerId(targetId)) return false;
    if (senderId == targetId) return false;
    if (amount <= 0) return false;

    if (!Money_Take(senderId, amount, MONEY_REASON_TRANSFER)) return false;
    Money_Add(targetId, amount, MONEY_REASON_TRANSFER);
    return true;
}

// --- rekening bank ---------------------------------------------------------

stock Money_BankFee(amount) {
    new fee = (amount * BANK_FEE_PERCENT) / 100;
    if (fee < BANK_FEE_MINIMUM) fee = BANK_FEE_MINIMUM;
    return fee;
}

// Tunai -> rekening. Dua baris log (keluar tunai, masuk bank).
stock bool:Money_Deposit(playerid, amount) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (amount < BANK_AMOUNT_MINIMUM || amount > BANK_AMOUNT_MAXIMUM) return false;
    if (gCharacterId[playerid] < 1) return false;
    if (gCash[playerid] < amount) return false;

    gCash[playerid] -= amount;
    Money_Persist(playerid, WALLET_CASH);
    Money_Log(gCharacterId[playerid], -amount, gCash[playerid], WALLET_CASH,
        MONEY_REASON_DEPOSIT, -1);

    gBank[playerid] += amount;
    Money_Persist(playerid, WALLET_BANK);
    Money_Log(gCharacterId[playerid], amount, gBank[playerid], WALLET_BANK,
        MONEY_REASON_DEPOSIT, -1);
    return true;
}

// Rekening -> tunai.
stock bool:Money_Withdraw(playerid, amount) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (amount < BANK_AMOUNT_MINIMUM || amount > BANK_AMOUNT_MAXIMUM) return false;
    if (gCharacterId[playerid] < 1) return false;
    if (gBank[playerid] < amount) return false;

    gBank[playerid] -= amount;
    Money_Persist(playerid, WALLET_BANK);
    Money_Log(gCharacterId[playerid], -amount, gBank[playerid], WALLET_BANK,
        MONEY_REASON_WITHDRAW, -1);

    gCash[playerid] += amount;
    Money_Persist(playerid, WALLET_CASH);
    Money_Log(gCharacterId[playerid], amount, gCash[playerid], WALLET_CASH,
        MONEY_REASON_WITHDRAW, -1);
    return true;
}

// Transfer antar rekening (biaya admin). Penerima boleh offline: saldonya
// dikredit langsung ke DB lewat Money_BankCreditCharacter.
stock bool:Money_BankTransfer(playerid, targetCharacterId, amount) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (targetCharacterId < 1 || targetCharacterId == gCharacterId[playerid]) return false;
    if (amount < BANK_AMOUNT_MINIMUM || amount > BANK_AMOUNT_MAXIMUM) return false;
    if (gCharacterId[playerid] < 1) return false;

    new fee = Money_BankFee(amount);
    if (gBank[playerid] < amount + fee) return false;

    gBank[playerid] -= amount + fee;
    Money_Persist(playerid, WALLET_BANK);
    Money_Log(gCharacterId[playerid], -(amount + fee), gBank[playerid],
        WALLET_BANK, MONEY_REASON_BANK_XFER, -1);
    // Biaya admin = luberan (hilang dari ekonomi), tetap tercatat.
    Money_Log(gCharacterId[playerid], -fee, gBank[playerid], WALLET_BANK,
        MONEY_REASON_BANK_FEE, -1);

    return Money_BankCreditCharacter(targetCharacterId, amount);
}

// Kredit rekening karakter (boleh offline). Saldo setelah mutasi dibaca dulu
// supaya baris money_log tetap akurat.
stock bool:Money_BankCreditCharacter(targetCharacterId, amount) {
    if (targetCharacterId < 1 || amount <= 0) return false;

    // Penerima online: lewat state pemain supaya tidak dobel dengan autosave.
    for (new playerid = 0; playerid < MAX_PLAYERS; playerid++) {
        if (!IsPlayerConnected(playerid)) continue;
        if (gCharacterId[playerid] != targetCharacterId) continue;

        gBank[playerid] += amount;
        Money_Persist(playerid, WALLET_BANK);
        Money_Log(targetCharacterId, amount, gBank[playerid], WALLET_BANK,
            MONEY_REASON_BANK_XFER, -1);
        return true;
    }

    // Penerima offline: baca saldo, tambah, tulis balik + log.
    new query[192];
    format(query, sizeof (query),
        "SELECT bank_balance FROM characters WHERE character_id = %d", targetCharacterId);
    new balance = DB_Int(query, -1);
    if (balance < 0) return false;

    balance += amount;
    format(query, sizeof (query),
        "UPDATE characters SET bank_balance = %d WHERE character_id = %d",
        balance, targetCharacterId);
    if (!DB_Exec(query)) return false;

    Money_Log(targetCharacterId, amount, balance, WALLET_BANK,
        MONEY_REASON_BANK_XFER, -1);
    return true;
}

stock bool:Money_Save(playerid) {
    if (playerid < 0 || playerid >= MAX_PLAYERS) return false;
    if (gCharacterId[playerid] < 1) return false;

    Money_Persist(playerid, WALLET_CASH);
    Money_Persist(playerid, WALLET_BANK);
    return true;
}

static Money_Persist(playerid, const wallet[]) {
    if (gCharacterId[playerid] < 1) return 0;

    new query[192];
    if (!strcmp(wallet, WALLET_BANK, true)) {
        format(query, sizeof (query),
            "UPDATE characters SET bank_balance = %d WHERE character_id = %d",
            gBank[playerid], gCharacterId[playerid]);
    } else {
        format(query, sizeof (query),
            "UPDATE characters SET cash = %d WHERE character_id = %d",
            gCash[playerid], gCharacterId[playerid]);
    }

    if (!DB_Exec(query)) {
        Log_Error("money", "gagal simpan saldo");
        return 0;
    }
    return 1;
}

// Uang awal karakter sudah dimasukkan lewat INSERT characters.cash, jadi baris
// log ditulis tanpa mengubah saldo lagi.
stock Money_LogInitial(characterId, amount) {
    if (characterId < 1) return 0;
    return Money_Log(characterId, amount, amount, WALLET_CASH, MONEY_REASON_START, -1);
}

static Money_Log(characterId, delta, balanceAfter, const wallet[], const reason[], actorCharacterId) {
    new query[256];
    format(query, sizeof (query),
        "INSERT INTO money_log (character_id, delta, balance_after, wallet, reason, actor_character_id) VALUES (%d, %d, %d, '%s', '%s', %d)",
        characterId, delta, balanceAfter, wallet, reason, actorCharacterId);

    if (!DB_Exec(query)) {
        Log_Error("money", "gagal tulis money_log");
        return 0;
    }
    return 1;
}

// Dipakai modul lain untuk menampilkan saldo tanpa menyentuh enum internal.
stock Money_Describe(playerid, dest[], maxlength = sizeof (dest)) {
    new cash[24], bank[24];
    Messages_Money(gCash[playerid], cash, sizeof (cash));
    Messages_Money(gBank[playerid], bank, sizeof (bank));
    return format(dest, maxlength, "Tunai %s | Bank %s", cash, bank);
}
