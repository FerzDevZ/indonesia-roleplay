// ---------------------------------------------------------------------------
// module      : domain/world/locations_seed
// entry       : dipanggil Locations_Boot()
// depends     : domain/world/locations
// owns tables : - (menulis baris awal tabel locations)
// public api  : Locations_SeedDefaults()
// Isi         : daftar lokasi bawaan. Dipisah dari locations.pwn supaya file
//               inti tetap di bawah batas 400 baris, dan supaya penambahan
//               lokasi baru tidak menyentuh logika cache/akses lokasi.
// Aturan      : Locations_Seed memakai INSERT OR IGNORE — posisi yang sudah
//               diubah admin di DB tidak pernah ditimpa saat restart.
// ---------------------------------------------------------------------------
#if defined _INC_LOCATIONS_SEED
    #endinput
#endif
#define _INC_LOCATIONS_SEED

stock Locations_SeedDefaults() {
    Locations_Seed("ATM_STASIUN", "ATM Stasiun Unity", LOC_ACT_ATM,
        1770.5, -1896.0, 13.5, 3.0);
    Locations_Seed("ATM_IDLEWOOD", "ATM Idlewood", LOC_ACT_ATM,
        1834.5, -1853.0, 13.5, 3.0);
    Locations_Seed("ATM_JEFFERSON", "ATM Jefferson", LOC_ACT_ATM,
        2087.0, -1394.0, 15.0, 3.0);
    Locations_Seed("LOKET_PD", "Loket PD", LOC_ACT_LOKET_PD,
        1552.51, -1675.73, 15.5, 30.0);
    Locations_Seed("JOB_CENTER", "Job Center", LOC_ACT_JOB_CENTER,
        1782.0, -1894.0, 13.5, 4.0);
    Locations_Seed("WARUNG_STASIUN", "Warung Bu Sari", LOC_ACT_WARUNG,
        1796.0, -1890.0, 13.5, 3.0);
    Locations_Seed("RS_ALL_SAINTS", "RS All Saints", LOC_ACT_RS,
        1173.0, -1323.5, 15.0, 4.0);
    Locations_Seed("RENTAL_STASIUN", "Rental Stasiun Unity", LOC_ACT_RENTAL,
        1766.4, -1906.0, 13.5, 3.0);
    Locations_Seed("BENSIN_STASIUN", "Pom Bensin Stasiun Unity", LOC_ACT_BENSIN,
        1730.0, -1902.0, 13.0, 4.0);
    Locations_Seed("BENGKEL_STASIUN", "Bengkel Stasiun Unity", LOC_ACT_BENGKEL,
        1740.0, -1918.0, 13.0, 4.0);
    Locations_Seed("DEALER_STASIUN", "Dealer Stasiun Unity", LOC_ACT_DEALER,
        1750.0, -1898.0, 13.5, 3.0);
    Locations_Seed("LATIHAN_STASIUN", "Latihan Tembak Stasiun Unity", LOC_ACT_LATIHAN,
        1712.0, -1890.0, 12.5, 3.0);
    return 1;
}
