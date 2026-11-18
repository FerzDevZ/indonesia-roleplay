// ---------------------------------------------------------------------------
// module      : world/locations_label
// entry       : Locations_SetLabel()
// depends     : domain/world/locations (nama, posisi, handle label)
// public api  : Locations_SetLabel()
// Fungsi      : mengganti teks label 3D lokasi (status DIJUAL / TUTUP / kosong)
//               tanpa meninggalkan handle label basi. Dipisah dari
//               locations.pwn supaya file inti lokasi tetap di bawah 400 baris.
// ---------------------------------------------------------------------------
#if defined _INC_WORLD_LOCATIONS_LABEL
    #endinput
#endif
#define _INC_WORLD_LOCATIONS_LABEL

// Ganti teks label lokasi. `suffix` kosong = hanya nama + petunjuk [Y].
stock Locations_SetLabel(index, const suffix[]) {
    if (index < 0 || index >= Locations_Count()) return 0;

    new locationName[LOC_NAME_LEN];
    Locations_Name(index, locationName, sizeof (locationName));

    new labelText[LOC_NAME_LEN + 56];
    if (suffix[0] == '\0') {
        format(labelText, sizeof (labelText), "%s\n[Y] Interaksi", locationName);
    } else {
        format(labelText, sizeof (labelText), "%s\n%s\n[Y] Interaksi",
            locationName, suffix);
    }

    new Float:posX, Float:posY, Float:posZ;
    Locations_Pos(index, posX, posY, posZ);
    new Text3D:label = Create3DTextLabel(labelText, 0xFFFFFFFF,
        posX, posY, posZ + 0.9, 25.0, 0);
    Locations_SetLabelHandle(index, label);
    return 1;
}
