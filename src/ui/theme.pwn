// ---------------------------------------------------------------------------
// module      : ui/theme
// entry       : -
// depends     : -
// owns tables : -
// public api  : konstanta warna & ukuran UI. Satu-satunya sumber token visual;
//               modul UI lain dilarang menulis warna literal sendiri.
// Palet       : netral gelap dengan aksen merah bata (identitas merah-putih).
//               Kontras teks utama di atas panel gelap >= 12:1, teks sekunder
//               >= 5:1, sesuai aturan WCAG pada docs/08.
// ---------------------------------------------------------------------------
#if defined _INC_UI_THEME
    #endinput
#endif
#define _INC_UI_THEME

#define THEME_BG            (0x0F1216FF)    // panel gelap solid
#define THEME_BG_SOFT       (0x161B21FF)    // panel sekunder
#define THEME_OVERLAY       (0x0B0E13D9)    // lapisan gelap di atas artwork
#define THEME_ACCENT        (0xD64545FF)    // merah bata
#define THEME_TEXT          (0xF2F3F5FF)    // teks utama
#define THEME_WHITE         (0xFFFFFFFF)    // putih murni (sprite/artwork)
#define THEME_MUTED         (0xA7AFB8FF)    // teks sekunder
#define THEME_LINE          (0x2A313AFF)    // garis pemisah

// Font memakai enum bertaga open.mp (TEXT_DRAW_FONT:), bukan angka telanjang.
// 1 = standard, 2 = Spaceage/BankGothic (label uppercase), 3 = Pricedown (GTA), 4 = sprite.
#define THEME_FONT_TITLE    (TEXT_DRAW_FONT:TEXT_DRAW_FONT_HEADING)     // Pricedown, judul besar
#define THEME_FONT_LABEL    (TEXT_DRAW_FONT:TEXT_DRAW_FONT_SPACEAGE)    // label uppercase
#define THEME_FONT_BODY     (TEXT_DRAW_FONT:TEXT_DRAW_FONT_STANDARD)   // normal, isi
#define THEME_FONT_SPRITE   (TEXT_DRAW_FONT:TEXT_DRAW_FONT_SPRITE_DRAW)

// Layout dasar layar 640x480 (aspect 4:3, semua client).
#define THEME_SCREEN_W      (640)
#define THEME_SCREEN_H      (480)

// Konvensi: satu unit LetterSize-Y textdraw box = 10 piksel tinggi.
stock Float:Theme_BoxHeight(Float:heightPx) {
    return heightPx / 10.0;
}

// Artwork loading screen GTA SA (txd loadscs, tekstur loadsc1-loadsc14).
#define THEME_BG_SPRITE     ("loadscs:loadsc14")

// ---------------------------------------------------------------------------
// Token gaya FiveM 2026: permukaan kaca (glassmorphism), garis rambut, dan
// aksen semantik. Semua modul UI wajib memakai token di sini - dilarang
// menulis warna literal sendiri.
// ---------------------------------------------------------------------------
#define THEME_GLASS         (0x0B0F19E6)    // kaca gelap 90% (kartu utama)
#define THEME_SURFACE       (0x111827F0)    // permukaan kartu 94%
#define THEME_ELEVATED      (0x1E293BF2)    // slot/tombol terangkat 95%
#define THEME_HOVER         (0x273549F5)    // sorotan slot aktif
#define THEME_BORDER        (0xFFFFFF1C)    // garis rambut putih 11%
#define THEME_SHADOW        (0x00000073)    // bayangan panel di belakang kartu (45%)

// Aksen semantik (emas/hiijau/biru/kuning/merah) di samping identitas merah bata.
#define THEME_OK            (0x10B981FF)    // sukses / saldo masuk
#define THEME_INFO          (0x38BDF8FF)    // informasi / polisi
#define THEME_WARN          (0xF59E0BFF)    // peringatan / bahan bakar
#define THEME_DANGER        (0xEF4444FF)    // bahaya / saldo kurang

// Koreksi aspek 16:9: kanvas 640x480 direntang ke layar lebar, jadi bentuk
// persegi/lingkaran harus dikali 0.75 pada sumbu-X agar tampak proporsional.
#define THEME_TD_ASPECT     (Float:0.75)

// Sprite bawaan GTA SA untuk menggambar permukaan & sudut bulat.
#define THEME_SPRITE_WHITE  ("LD_SPAC:white")
#define THEME_SPRITE_CIRCLE ("LD_BEAT:chit")

// ---------------------------------------------------------------------------
// Palet kartu e-KTP (dokumen resmi): kartu terang, header navy, label biru
// dinas, nilai gelap. Hanya dipakai ui/ktpcard.
// ---------------------------------------------------------------------------
#define KTP_CARD            (0xE9EEF6FF)    // badan kartu putih kebiruan
#define KTP_CARD_LINE       (0xC9D6E8FF)    // garis pemisah kolom
#define KTP_HEADER          (0x1F3B73FF)    // teks provinsi (navy)
#define KTP_SUB             (0x51617AFF)    // subjudul & keterangan redup
#define KTP_LABEL           (0x3D5A98FF)    // label isian biru dinas
#define KTP_VALUE           (0x232B36FF)    // nilai isian gelap
#define KTP_NIK             (0x14264DFF)    // NIK di bawah foto

// ---------------------------------------------------------------------------
// Palet SIM Nasional Indonesia: kartu biru muda, band header biru tua dengan
// teks putih. Hanya dipakai ui/simcard.
// ---------------------------------------------------------------------------
#define SIM_CARD            (0xD9E6F5FF)    // badan kartu biru muda
#define SIM_BAND            (0x0B3D91FF)    // band header biru tua
#define SIM_LABEL           (0x27488FFF)    // label isian biru tua
#define SIM_VALUE           (0x1C2430FF)    // nilai isian gelap
#define SIM_SUB             (0x3A5A9FFF)    // keterangan provinsi

// ---------------------------------------------------------------------------
// Palet ponsel: dua skin perangkat (dipilih pemain di aplikasi Pengaturan).
// iPhone = kaca hampir hitam, sudut besar; Samsung One UI = slate datar,
// header band, daftar baris. Token lain (tile aplikasi) memakai aksen
// semantik di atas (THEME_OK/INFO/WARN/ACCENT).
// ---------------------------------------------------------------------------
#define PHONE_IPHONE_BG     (0x05070AF2)    // layar iPhone: obsidian 95%
#define PHONE_SAMSUNG_BG    (0x0E1620F2)    // layar Samsung: slate 95%
#define PHONE_HOME_IND      (0xFFFFFF96)    // home indicator iPhone (putih 59%)
#define PHONE_GLOW          (0xD6454526)    // lingkaran glow aksen 15% (dekor mesh FiveM)
#define PHONE_SHEEN         (0xFFFFFF12)    // kilau gradasi atas tile (7% putih)
#define PHONE_SHADOW        (0x00000073)    // bayangan panel di belakang frame (45%)
