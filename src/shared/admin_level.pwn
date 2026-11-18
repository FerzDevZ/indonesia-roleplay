// ---------------------------------------------------------------------------
// module      : shared/admin_level
// Isi         : tangga pangkat admin. Dipakai modul yang butuh tahu level
//               admin (chat /lapor, /help admin) sebelum domain/admin
//               di-include, jadi definisi dipisah ke header bersama.
// ---------------------------------------------------------------------------
#if defined _INC_SHARED_ADMIN_LEVEL
    #endinput
#endif
#define _INC_SHARED_ADMIN_LEVEL

#define ADMIN_HELPER     (1)
#define ADMIN_MODERATOR  (2)
#define ADMIN_ADMIN      (3)
#define ADMIN_DEVELOPER  (4)
#define ADMIN_OWNER      (5)
