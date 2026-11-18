// ---------------------------------------------------------------------------
// module      : domain/identity_datadiri
// entry       : Identity_OpenDataDiri(), Identity_OnDialogResponse()
// depends     : domain/identity, core/db, shared/messages
// owns tables : - (menulis kolom data diri di tabel characters milik core/db)
// public api  : Identity_OpenDataDiri(), Identity_OnDialogResponse()
// Alur        : /datadiri -> dialog daftar field (agama, golongan darah,
//               status perkawinan, pekerjaan, alamat) -> dialog input teks
//               -> UPDATE characters. Nama, NIK, dan tanggal lahir tidak bisa
//               diubah lewat sini (data administrasi tetap).
// ---------------------------------------------------------------------------
#if defined _INC_IDENTITY_DATADIRI
    #endinput
#endif
#define _INC_IDENTITY_DATADIRI

#define IDENTITY_FIELD_COUNT    (7)

static gIdentityEditField[MAX_PLAYERS];

// Nama kolom tabel characters untuk tiap field data diri.
static const gIdentityColumns[IDENTITY_FIELD_COUNT][] = {
    "religion", "blood_type", "marital_status", "occupation", "address",
    "height_cm", "weight_kg"
};

// Label tampilan di dialog daftar.
static const gIdentityLabels[IDENTITY_FIELD_COUNT][] = {
    "Agama", "Golongan Darah", "Status Perkawinan", "Pekerjaan", "Alamat",
    "Tinggi (cm)", "Berat (kg)"
};

stock Identity_OpenDataDiri(playerid) {
    if (Character_GetId(playerid) < 1) {
        Messages_SendError(playerid, MSG_INTERNAL_ERROR);
        return 0;
    }

    new list[160] = "";
    for (new field = 0; field < IDENTITY_FIELD_COUNT; field++) {
        format(list, sizeof (list), "%s%s\n", list, gIdentityLabels[field]);
    }
    ShowPlayerDialog(playerid, DIALOG_IDENTITY_PICK, DIALOG_STYLE_LIST,
        "Data Diri KTP", list, "Pilih", "Tutup");
    return 1;
}

// Simpan satu field data diri (input sudah divalidasi dan di-escape).
// Field tinggi badan divalidasi angka 140-220; sisanya teks 2-60 karakter.
static bool:Identity_SaveField(playerid, field, const value[]) {
    if (field < 0 || field >= IDENTITY_FIELD_COUNT) return false;
    if (Character_GetId(playerid) < 1) return false;

    // Field tinggi & berat divalidasi angka; sisanya teks 2-60 karakter.
    if (field == 5 || field == 6) {
        new number = strval(value);
        new lo = (field == 5) ? 140 : 35;
        new hi = (field == 5) ? 220 : 200;
        if (number < lo || number > hi) {
            new body[96];
            format(body, sizeof (body), "Nilai harus %d-%d.", lo, hi);
            Messages_SendError(playerid, body);
            return false;
        }
        new query[128];
        format(query, sizeof (query),
            "UPDATE characters SET %s = %d WHERE character_id = %d",
            gIdentityColumns[field], number, Character_GetId(playerid));
        if (!DB_Exec(query)) {
            Messages_SendError(playerid, MSG_INTERNAL_ERROR);
            return false;
        }
        new body[64];
        format(body, sizeof (body), "%s diperbarui: %d", gIdentityLabels[field], number);
        Messages_SendSystem(playerid, body);
        return true;
    }

    new escaped[128];
    DB_Escape(escaped, sizeof (escaped), value);

    new query[192];
    format(query, sizeof (query), "UPDATE characters SET %s = '%s' WHERE character_id = %d",
        gIdentityColumns[field], escaped, Character_GetId(playerid));
    if (!DB_Exec(query)) {
        Messages_SendError(playerid, MSG_INTERNAL_ERROR);
        return false;
    }

    new body[96];
    format(body, sizeof (body), "Data diri diperbarui: %s = %s",
        gIdentityLabels[field], value);
    Messages_SendSystem(playerid, body);
    return true;
}

// Baca nilai sekarang untuk dijadikan isi awal dialog input.
static Identity_CurrentValue(playerid, field, dest[], maxlength = sizeof (dest)) {
    new query[192];
    format(query, sizeof (query),
        "SELECT %s FROM characters WHERE character_id = %d",
        gIdentityColumns[field], Character_GetId(playerid));
    if (!DB_String(query, dest, maxlength)) {
        dest[0] = EOS;
    }
    return 1;
}

stock bool:Identity_OnDialogResponse(playerid, dialogid, response, listitem,
    const inputtext[]) {
    if (dialogid == DIALOG_IDENTITY_PICK) {
        if (!response) return true;
        if (listitem < 0 || listitem >= IDENTITY_FIELD_COUNT) return true;

        gIdentityEditField[playerid] = listitem;
        new current[96];
        Identity_CurrentValue(playerid, listitem, current, sizeof (current));

        new title[40], info[128];
        format(title, sizeof (title), "Ubah %s", gIdentityLabels[listitem]);
        format(info, sizeof (info),
            "Nilai sekarang: %s\n\nMasukkan nilai baru (2-60 karakter):",
            current[0] == EOS ? "-" : current);
        ShowPlayerDialog(playerid, DIALOG_IDENTITY_INPUT, DIALOG_STYLE_INPUT,
            title, info, "Simpan", "Batal");
        return true;
    }
    if (dialogid == DIALOG_IDENTITY_INPUT) {
        if (!response) return true;
        Identity_SaveField(playerid, gIdentityEditField[playerid], inputtext);
        return true;
    }
    return false;
}
