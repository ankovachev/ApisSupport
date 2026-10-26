# Фаза 2 — QuickSupport патчове (`patches/quicksupport/`)

**Започната:** 2026-10-26
**Състояние:** в ход — `001-app-name` ✅

Канон за изискванията: [`REQUIREMENTS.md`](../REQUIREMENTS.md). Карта изискване→патч: [`ARCHITECTURE.md`](ARCHITECTURE.md) §6.2. Работният цикъл е същият като във Фаза 1 ([`PHASE1-common.md`](PHASE1-common.md) §1, §5).

---

## 1. Патчове

| Патч | Изисквания | Какво прави | Проверка |
|---|---|---|---|
| `001-app-name` (hbb) | C1, C2 | `APP_NAME` по подразбиране = `{{APP_NAME}}` (`ApisQuickSupport`). Същият патч е и `agent/001-app-name` (там → `ApisAgent`) | Release build: config/log в `%APPDATA%\ApisQuickSupport\` (`ApisQuickSupport*.toml`), `%APPDATA%\RustDesk` непроменен (сравнение размер+време на всички файлове), IPC pipe `\\.\pipe\ApisQuickSupport\query`, нов ID ✅ |

Заедно с 001 е добавен общият `common/039-custom-client-hardening` (виж `PHASE1-common.md` §2), защото затваря пътищата, които сменят или използват APP_NAME.

## 2. Картографиране на APP_NAME (RustDesk 1.5.0)

- **Източник:** `hbb_common::config::APP_NAME` (lazy_static, `"RustDesk"`). Единственото друго място, което го пише, е `read_custom_client()` (`app-name` от подписан `custom.txt` до exe-то или подаден от Flutter при `initialize`) → изключено с 039.
- **Какво следва от него:** папката `%APPDATA%\<APP_NAME>\` (config + log), имената на config файловете, IPC pipe-овете (`\\.\pipe\<APP_NAME>\…`), заглавието/`FindWindow` на Windows runner-а (`get_rustdesk_app_name`; видимото заглавие после се сменя от Dart на `{{WINDOW_TITLE}}`, 020), URI схемата, имената на услуга/registry при инсталация (не се ползва — F1/F2), `portable_service` споделената памет.
- **Името на exe-то** не влиза в IPC проверките на Windows (само на macOS) → `rustdesk.exe` → `ApisQuickSupport.exe`, иконата и `Runner.rc` (ProductName/FileDescription) остават за branding/packaging (B1, Фаза 3–4).

### Странични ефекти на `is_custom_client()` (= `APP_NAME != "RustDesk"`)

| Къде | Ефект | Оценка |
|---|---|---|
| `check_software_update`, `checkUpdate` (Dart), карта за update | Не се проверява за обновления | Желано (P11, вече и от 036) |
| IPC `hide_cm` | Отговаря с `password_security::hide_cm()` (скриване на CM при постоянна парола + approve-mode password + `allow-hide-cm`) | **Риск за A8** → `hide_cm()` = `false` в 039. Dart логиката за `hideCm` е закоментирана upstream |
| `defaultOption*` (Dart) | „По подразбиране“ се записва като явна стойност (`Y`/`N`, `default`, `system`, `custom`, `password-click`) вместо `''` | Безвредно; езикът/темата са форсирани (010/011); `approve-mode`/`access-mode` ще се решат с 002–004 |
| `loadPowered` | Би показал „Powered by RustDesk“ | Вече махнат (020) |
| `lang.rs` | „RustDesk“ в непреведени низове → APP_NAME | Преводите вече са с `{{DISPLAY_NAME}}` (020) |
| `platform/windows.rs` (MSI, custom icon, update staging), `updater.rs` | Само при инсталация/обновление | Неприложимо (F1, P11) |
| `verify_login` | Закоментирана upstream | — |

## 3. Отворени точки

- Exe име/икона/версия ресурс — Фаза 3–4 (B1).
- Следващ патч: `002-disable-unattended` (A1).
