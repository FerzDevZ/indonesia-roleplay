// ---------------------------------------------------------------------------
// module      : domain/character (alur buat karakter)
// depends     : domain/character, ui/charcreate, core/db, shared/*
// public api  : Character_OnCreateUIAction()
// Isi         : dialog nama (keyboard), validasi, INSERT karakter lengkap
//               (gender, tanggal lahir, skin), dan slot kosong. State form
//               dibaca dari ui/charcreate; pemilik data tetap tabel characters.
// ---------------------------------------------------------------------------
#if defined _INC_CHARACTER_CREATE
    #endinput
#endif
#define _INC_CHARACTER_CREATE

// Aksi dari UI buat karakter (dikirim lewat callbacks.pwn).
stock Character_OnCreateUIAction(playerid, action) {
    switch (action) {
        case CC_ACT_ASK_FIRST: {
            Character_AskFirstName(playerid);
            return 1;
        }
        case CC_ACT_ASK_LAST: {
            Character_AskLastName(playerid);
            return 1;
        }
        case CC_ACT_CONFIRM: {
            new first[MAX_USERNAME_LENGTH + 1], last[MAX_USERNAME_LENGTH + 1];
            CharCreate_GetFirstName(playerid, first, sizeof (first));
            CharCreate_GetLastName(playerid, last, sizeof (last));
            if (!Validate_NamePart(first) || !Validate_NamePart(last)) {
                Messages_SendError(playerid,
                    "Lengkapi nama depan & belakang (huruf, 2-24 karakter). Klik baris NAMA di panel kiri.");
                CharCreate_Show(playerid);
                return 1;
            }
            Character_Create(playerid);
            return 1;
        }
        case CC_ACT_CANCEL: {
            UIModal_Close(playerid);
            if (Character_CountSlots(Auth_AccountId(playerid)) == 0) {
                Kick(playerid);
                return 1;
            }
            Character_ShowSelector(playerid);
            return 1;
        }
    }
    return 0;
}

stock Character_AskFirstName(playerid) {
    Welcome_SetHint(playerid, "LENGKAPI DATA KARAKTER");
    new body[192];
    format(body, sizeof (body),
        "Nama depan (huruf, 2-%d karakter).\r\n\
Contoh: Budi, Siti, Rahmat.", MAX_USERNAME_LENGTH);
    ShowPlayerDialog(playerid, DIALOG_CHAR_CREATE_FIRST, DIALOG_STYLE_INPUT,
        "Nama Depan", body, "Simpan", "Kembali");
    return 1;
}

stock Character_AskLastName(playerid) {
    new body[224];
    format(body, sizeof (body),
        "Nama depan: %s\r\n\r\nNama belakang (tanpa spasi).\r\n\
Contoh: Santoso, Wulandari, Pratama.", gPendingFirst[playerid]);
    ShowPlayerDialog(playerid, DIALOG_CHAR_CREATE_LAST, DIALOG_STYLE_INPUT,
        "Nama Belakang", body, "Simpan", "Kembali");
    return 1;
}

stock Character_Create(playerid) {
    new accountId = Auth_AccountId(playerid);
    if (accountId < 1) return 0;

    new slot = Character_FirstFreeSlot(accountId);
    if (slot < 0) {
        new body[128];
        format(body, sizeof (body), MSG_CHAR_LIMIT, MAX_CHAR_SLOTS, MAX_CHAR_SLOTS);
        Messages_SendError(playerid, body);
        return 0;
    }

    new first[MAX_USERNAME_LENGTH + 1], last[MAX_USERNAME_LENGTH + 1];
    CharCreate_GetFirstName(playerid, first, sizeof (first));
    CharCreate_GetLastName(playerid, last, sizeof (last));

    new escapedFirst[MAX_USERNAME_LENGTH * 2 + 1];
    new escapedLast[MAX_USERNAME_LENGTH * 2 + 1];
    DB_Escape(escapedFirst, sizeof (escapedFirst), first);
    DB_Escape(escapedLast, sizeof (escapedLast), last);

    new religion[12], blood[4];
    CharCreate_GetReligion(playerid, religion, sizeof (religion));
    CharCreate_GetBlood(playerid, blood, sizeof (blood));

    new query[640];
    format(query, sizeof (query),
        "INSERT INTO characters (account_id, slot_index, first_name, last_name, gender, \
         birth_day, birth_month, birth_year, skin_model, cash, religion, blood_type, \
         height_cm, weight_kg) \
         VALUES (%d, %d, '%s', '%s', '%s', %d, %d, %d, %d, %d, '%s', '%s', %d, %d)",
        accountId, slot, escapedFirst, escapedLast,
        CharCreate_IsMale(playerid) ? "male" : "female",
        CharCreate_GetBirthDay(playerid), CharCreate_GetBirthMonth(playerid),
        CharCreate_GetBirthYear(playerid), CharCreate_GetSkin(playerid), STARTING_CASH,
        religion, blood, CharCreate_GetHeight(playerid), CharCreate_GetWeight(playerid));

    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_DB_ERROR);
        return 0;
    }

    new createdId = DB_InsertId();
    if (createdId > 0) {
        Money_Load(playerid, createdId);
        Money_LogInitial(playerid, STARTING_CASH);
        Identity_IssueKTP(createdId);
    }

    new message[160];
    format(message, sizeof (message), MSG_CHAR_CREATED, first, last);
    Messages_SendSystem(playerid, message);

    UIModal_Close(playerid);
    Character_ShowSelector(playerid);
    return 1;
}

stock Character_FirstFreeSlot(accountId) {
    for (new slot = 0; slot < MAX_CHAR_SLOTS; slot++) {
        if (!Character_SlotExists(accountId, slot)) {
            return slot;
        }
    }
    return -1;
}
