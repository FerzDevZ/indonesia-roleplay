// ---------------------------------------------------------------------------
// Roleplay Indonesia - open.mp 1.6.x
// Entry point: hanya include, urutan boot, dan main(). Tidak ada gameplay.
// ---------------------------------------------------------------------------
#include <open.mp>

#pragma dynamic 131072

// core
#include "src/core/text.pwn"
#include "src/core/settings.pwn"
#include "src/core/log.pwn"
#include "src/core/db.pwn"
#include "src/core/timer.pwn"
#include "src/core/telemetry.pwn"

// shared
#include "src/shared/messages.pwn"
#include "src/shared/player_phase.pwn"
#include "src/shared/client_tier.pwn"
#include "src/shared/validate.pwn"
#include "src/shared/money.pwn"

// ui (theme disertakan otomatis oleh modul ui)
#include "src/ui/trxtdraw.pwn"
#include "src/ui/toast.pwn"
#include "src/ui/uimodal.pwn"
#include "src/ui/welcome.pwn"
#include "src/ui/hud.pwn"
#include "src/ui/charselect.pwn"
#include "src/ui/charcreate.pwn"
#include "src/ui/charcreate_draw.pwn"
#include "src/ui/charcreate_input.pwn"
#include "src/ui/ktpcard.pwn"
#include "src/ui/simcard.pwn"
#include "src/ui/bankui.pwn"
#include "src/ui/phone.pwn"
#include "src/ui/phone_draw.pwn"
#include "src/ui/phone_settings.pwn"
#include "src/ui/prompt.pwn"

// header bersama (dipakai lintas domain, harus sebelum domain)
#include "src/shared/admin_level.pwn"

// domain
#include "src/domain/auth/auth.pwn"
#include "src/domain/character/character.pwn"
#include "src/domain/character/character_create.pwn"
#include "src/domain/chat/chat.pwn"
#include "src/domain/world/locations.pwn"
#include "src/domain/world/locations_label.pwn"
#include "src/domain/world/locations_actions.pwn"
#include "src/domain/identity.pwn"
#include "src/domain/identity_datadiri.pwn"
#include "src/domain/identity_simcard.pwn"
#include "src/domain/tilang.pwn"
#include "src/domain/job/job_kurir.pwn"
#include "src/domain/world/world.pwn"
#include "src/domain/inventory/inventory.pwn"
// survival setelah inventory: memakai Inv_CountOf/Inv_Take + makro INV_ITEM_*.
#include "src/domain/survival/survival.pwn"
#include "src/domain/survival/survival_cmd.pwn"
// admin setelah locations+inventory: /buatatm memakai makro LOC_* dan
// warung_admin di bawahnya memakai makro ADMIN_*.
#include "src/domain/admin/admin.pwn"
#include "src/domain/warung/warung.pwn"
#include "src/domain/property/property.pwn"
// kendaraan: inti pool + data rental (DB) + layanan sewa + perintah admin.
#include "src/domain/vehicle/vehicle.pwn"
#include "src/domain/vehicle/vehicle_rental_data.pwn"
#include "src/domain/vehicle/vehicle_rental.pwn"
#include "src/domain/vehicle/vehicle_rental_admin.pwn"
// interiors butuh API Property_*; property_manage butuh Interiors_*.
#include "src/domain/world/interiors.pwn"
#include "src/domain/warung/warung_admin.pwn"
#include "src/domain/property/property_manage.pwn"
#include "src/domain/property/property_admin.pwn"

// UI tas (butuh makro INV_* dari domain/inventory di atasnya)
#include "src/ui/inventoryui.pwn"
#include "src/ui/inventoryui_draw.pwn"

// UI toko warung (butuh Warung_* dari domain/warung di atasnya)
#include "src/ui/warungui.pwn"
#include "src/ui/warungui_draw.pwn"

// callbacks (satu-satunya tempat callback didefinisikan)
#include "src/core/callbacks.pwn"

main() {
    Settings_Load();

    if (!Log_Boot()) {
        print("[boot] GAGAL: logger tidak siap");
        return;
    }

    if (!DB_Boot()) {
        Log_Error("boot", "database gagal dibuka, server berhenti");
        return;
    }

    Timer_Boot();
    Telemetry_Boot();
    UI_Boot();

    Auth_Boot();
    Character_Boot();
    Chat_Boot();
    Locations_Boot();
    Identity_Boot();
    Tilang_Boot();
    JobKurir_Boot();
    World_Boot();
    Inv_Boot();
    Survival_Boot();
    Warung_Boot();
    Property_Boot();
    Interiors_Boot();
    Vehicle_Boot();
    VehicleRental_Boot();
    Admin_Boot();

    Log_Info("boot", "siap");
    Log_Info("boot", "backend database: sqlite, server siap menerima pemain");
}
