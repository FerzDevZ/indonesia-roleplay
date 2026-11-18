# 04 — Model data

> **Status implementasi (26-11-17):** server jalan dengan **SQLite bawaan open.mp**
> (`server/scriptfiles/rp.db`) lewat `core/db`, bukan MySQL. Skema di dokumen ini tetap
> berlaku apa adanya karena SQL-nya portabel; MySQL baru relevan kalau butuh panel web
> atau lebih dari satu server. Saat itu terjadi, hanya `src/core/db.pwn` yang berubah —
> domain tidak tahu backend apa yang dipakai.
>

MySQL 8.0, InnoDB, `utf8mb4_0900_ai_ci`. Semua tabel memakai `BIGINT UNSIGNED` untuk
id. Nama kolom `snake_case`, tanpa singkatan yang tidak bisa dibaca.

## 1. Akun dan karakter

```sql
CREATE TABLE accounts (
    account_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    username        VARCHAR(24)     NOT NULL,
    password_hash   CHAR(60)        NOT NULL,           -- bcrypt cost 11
    email           VARCHAR(120)    DEFAULT NULL,
    admin_level     TINYINT UNSIGNED NOT NULL DEFAULT 0,
    is_banned       TINYINT(1)      NOT NULL DEFAULT 0,
    ban_reason      VARCHAR(160)    DEFAULT NULL,
    last_ip         VARCHAR(45)     DEFAULT NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at   TIMESTAMP       NULL DEFAULT NULL,
    PRIMARY KEY (account_id),
    UNIQUE KEY uq_accounts_username (username)
) ENGINE=InnoDB;

CREATE TABLE characters (
    character_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    account_id      BIGINT UNSIGNED NOT NULL,
    slot_index      TINYINT UNSIGNED NOT NULL,          -- 0..2
    first_name      VARCHAR(24)     NOT NULL,
    last_name       VARCHAR(24)     NOT NULL,
    gender          ENUM('male','female') NOT NULL,
    birth_date      DATE            NOT NULL,
    skin_model      SMALLINT        NOT NULL DEFAULT 0,
    cash            BIGINT          NOT NULL DEFAULT 0, -- rupiah, bisa minus (utang)
    bank_balance    BIGINT          NOT NULL DEFAULT 0,
    job_id          SMALLINT UNSIGNED DEFAULT NULL,
    faction_id      SMALLINT UNSIGNED DEFAULT NULL,
    faction_rank    TINYINT UNSIGNED DEFAULT NULL,
    hours_played    INT UNSIGNED    NOT NULL DEFAULT 0,
    hunger          TINYINT UNSIGNED NOT NULL DEFAULT 100, -- kebutuhan tubuh
    thirst          TINYINT UNSIGNED NOT NULL DEFAULT 100,
    stamina         TINYINT UNSIGNED NOT NULL DEFAULT 100,
    last_login_at   TIMESTAMP       NULL DEFAULT NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at      TIMESTAMP       NULL DEFAULT NULL,
    PRIMARY KEY (character_id),
    UNIQUE KEY uq_characters_account_slot (account_id, slot_index),
    KEY idx_characters_account (account_id),
    CONSTRAINT fk_characters_account FOREIGN KEY (account_id)
        REFERENCES accounts (account_id) ON DELETE CASCADE
) ENGINE=InnoDB;
```

`cash` dan `bank_balance` **boleh** ditulis langsung hanya oleh `shared/money`.

## 2. Catatan uang (append-only)

```sql
CREATE TABLE money_log (
    money_log_id    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id    BIGINT UNSIGNED NOT NULL,
    delta           BIGINT          NOT NULL,           -- + masuk, - keluar
    balance_after   BIGINT          NOT NULL,
    wallet          ENUM('cash','bank') NOT NULL,
    reason          VARCHAR(48)     NOT NULL,           -- SALARY, JOB_TRUCKER, TAX, FINE
    ref_table       VARCHAR(32)     DEFAULT NULL,       -- 'vehicles', 'properties'
    ref_id          BIGINT UNSIGNED DEFAULT NULL,
    actor_character_id BIGINT UNSIGNED DEFAULT NULL,    -- admin/penilang
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (money_log_id),
    KEY idx_money_log_character (character_id, created_at),
    KEY idx_money_log_reason (reason, created_at)
) ENGINE=InnoDB;
```

Tanpa `UPDATE` dan `DELETE` di tabel ini. Kalau butuh koreksi, tulis baris baru dengan
`reason = 'CORRECTION'` dan `ref_id` menunjuk baris yang dikoreksi.

## 3. Identitas: KTP, SIM, STNK, plat

```sql
CREATE TABLE identity_docs (
    doc_id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id    BIGINT UNSIGNED NOT NULL,
    doc_type        ENUM('ktp','sim_a','sim_b1','sim_b2','sim_c','izin_usaha') NOT NULL,
    doc_number      VARCHAR(32)     NOT NULL,
    issued_at       DATE            NOT NULL,
    expires_at      DATE            DEFAULT NULL,       -- NULL = seumur hidup
    issued_by       BIGINT UNSIGNED DEFAULT NULL,       -- character_id petugas
    revoked_at      TIMESTAMP       NULL DEFAULT NULL,
    revoke_reason   VARCHAR(120)    DEFAULT NULL,
    PRIMARY KEY (doc_id),
    UNIQUE KEY uq_docs_number (doc_type, doc_number),
    KEY idx_docs_character (character_id, doc_type)
) ENGINE=InnoDB;

CREATE TABLE plates (
    plate_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    plate_code      VARCHAR(10)     NOT NULL,           -- 'B 1234 XYZ'
    vehicle_id      BIGINT UNSIGNED DEFAULT NULL,
    registered_to   BIGINT UNSIGNED DEFAULT NULL,       -- character_id
    region_code     VARCHAR(4)      NOT NULL,           -- B, D, F, L, N ...
    stnk_expires_at DATE            NOT NULL,
    is_stolen       TINYINT(1)      NOT NULL DEFAULT 0,
    PRIMARY KEY (plate_id),
    UNIQUE KEY uq_plates_code (plate_code),
    KEY idx_plates_vehicle (vehicle_id)
) ENGINE=InnoDB;
```

Plat nomor adalah entitas mandiri — bisa dicabut, dicuri, dipindahtangan, dan dicari
polisi tanpa harus memuat seluruh data kendaraan.

## 4. Kendaraan

```sql
CREATE TABLE vehicles (
    vehicle_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    model_id        SMALLINT        NOT NULL,
    plate_id        BIGINT UNSIGNED DEFAULT NULL,
    owner_character BIGINT UNSIGNED DEFAULT NULL,
    owner_faction   SMALLINT UNSIGNED DEFAULT NULL,
    color_1         SMALLINT        NOT NULL DEFAULT 1,
    color_2         SMALLINT        NOT NULL DEFAULT 1,
    health          FLOAT           NOT NULL DEFAULT 1000,
    fuel            FLOAT           NOT NULL DEFAULT 100,
    odometer_km     FLOAT           NOT NULL DEFAULT 0,
    spawn_x         FLOAT           NOT NULL,
    spawn_y         FLOAT           NOT NULL,
    spawn_z         FLOAT           NOT NULL,
    spawn_angle     FLOAT           NOT NULL DEFAULT 0,
    is_impounded    TINYINT(1)      NOT NULL DEFAULT 0,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (vehicle_id),
    KEY idx_vehicles_owner (owner_character),
    KEY idx_vehicles_faction (owner_faction)
) ENGINE=InnoDB;
```

## 5. Properti dan bisnis

```sql
CREATE TABLE properties (
    property_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    kind            ENUM('house','apartment','garage','warehouse') NOT NULL,
    interior_id     SMALLINT        NOT NULL,
    entrance_x      FLOAT           NOT NULL,
    entrance_y      FLOAT           NOT NULL,
    entrance_z      FLOAT           NOT NULL,
    exit_x          FLOAT           NOT NULL,
    exit_y          FLOAT           NOT NULL,
    exit_z          FLOAT           NOT NULL,
    price           BIGINT          NOT NULL,
    owner_character BIGINT UNSIGNED DEFAULT NULL,
    rent_per_day    BIGINT          NOT NULL DEFAULT 0,
    tax_due_at      DATE            DEFAULT NULL,
    PRIMARY KEY (property_id),
    KEY idx_properties_owner (owner_character)
) ENGINE=InnoDB;

CREATE TABLE businesses (
    business_id     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    kind            ENUM('warung','resto','bengkel','toko','pompa','laundry') NOT NULL,
    name            VARCHAR(48)     NOT NULL,
    property_id     BIGINT UNSIGNED DEFAULT NULL,
    owner_character BIGINT UNSIGNED DEFAULT NULL,
    balance         BIGINT          NOT NULL DEFAULT 0,
    stock_units     INT             NOT NULL DEFAULT 0,
    supplier_price  BIGINT          NOT NULL DEFAULT 1000,
    sell_margin     SMALLINT        NOT NULL DEFAULT 25,  -- persen
    PRIMARY KEY (business_id),
    KEY idx_business_owner (owner_character)
) ENGINE=InnoDB;
```

## 6. Faksi

```sql
CREATE TABLE factions (
    faction_id      SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
    code            VARCHAR(8)      NOT NULL,           -- 'PD','EMS','SAGOV','GANG_1'
    name            VARCHAR(48)     NOT NULL,
    kind            ENUM('legal','gang','neutral') NOT NULL,
    balance         BIGINT          NOT NULL DEFAULT 0,
    is_recruiting   TINYINT(1)      NOT NULL DEFAULT 1,
    PRIMARY KEY (faction_id),
    UNIQUE KEY uq_faction_code (code)
) ENGINE=InnoDB;

CREATE TABLE faction_ranks (
    faction_id      SMALLINT UNSIGNED NOT NULL,
    rank_index      TINYINT UNSIGNED NOT NULL,
    title           VARCHAR(40)     NOT NULL,
    salary          BIGINT          NOT NULL,
    permissions     INT UNSIGNED    NOT NULL DEFAULT 0, -- bitmask, lihat shared/pools
    PRIMARY KEY (faction_id, rank_index)
) ENGINE=InnoDB;
```

`permissions` adalah bitmask yang **hanya** dibaca lewat helper `Rank_Has(rank, PERM_MDC)`.
Bitmask mentah tidak boleh muncul di domain.

## 7. Medis, hukum, audit

```sql
CREATE TABLE injuries (
    injury_id       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id    BIGINT UNSIGNED NOT NULL,
    caused_by       BIGINT UNSIGNED DEFAULT NULL,
    cause           VARCHAR(48)     NOT NULL,           -- 'gunshot','crash','fall'
    severity        TINYINT UNSIGNED NOT NULL,          -- 1..5
    state           ENUM('bleeding','treated','dead') NOT NULL DEFAULT 'bleeding',
    bleeds_out_at   TIMESTAMP       NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (injury_id),
    KEY idx_injury_character (character_id, state)
) ENGINE=InnoDB;

CREATE TABLE warrants (
    warrant_id      BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id    BIGINT UNSIGNED NOT NULL,
    issued_by       BIGINT UNSIGNED NOT NULL,           -- character_id polisi
    reason          VARCHAR(160)    NOT NULL,
    expires_at      TIMESTAMP       NULL,
    cleared_at      TIMESTAMP       NULL,
    PRIMARY KEY (warrant_id),
    KEY idx_warrant_character (character_id, cleared_at)
) ENGINE=InnoDB;

CREATE TABLE admin_audit (
    audit_id        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    actor_account   BIGINT UNSIGNED NOT NULL,
    actor_name      VARCHAR(24)     NOT NULL,
    action          VARCHAR(48)     NOT NULL,           -- 'GIVE_MONEY','KICK','CK'
    target_character BIGINT UNSIGNED DEFAULT NULL,
    payload_json    JSON            DEFAULT NULL,
    created_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (audit_id),
    KEY idx_audit_actor (actor_account, created_at)
) ENGINE=InnoDB;
```

## 8. Aturan migrasi

1. Satu file migrasi = satu perubahan yang bisa di-rollback logis. Nomor urut wajib.
2. Tidak ada `DROP COLUMN` di migrasi produksi. Pakai expand-contract: tambah kolom
   baru → backfill → kode pakai yang baru → hapus di migrasi terpisah setelah rilis.
3. Semua `ALTER TABLE` pada tabel > 1 juta baris memakai `ALGORITHM=INPLACE, LOCK=NONE`
   dan dijalankan di luar jam sibuk.
4. Indeks baru untuk kolom yang sering difilter: `warrants.character_id`,
   `plates.plate_code`, `vehicles.owner_character` sudah ada di atas.
5. Backup sebelum migrasi wajib, dan migrasi diuji di dump produksi terakhir (anonymized).
