# Фаза 2 — QuickSupport патчове (`patches/quicksupport/`)

**Започната:** 2026-10-26
**Състояние:** в ход — `001-app-name` ✅

Канон за изискванията: [`REQUIREMENTS.md`](../REQUIREMENTS.md). Карта изискване→патч: [`ARCHITECTURE.md`](ARCHITECTURE.md) §6.2. Работният цикъл е същият като във Фаза 1 ([`PHASE1-common.md`](PHASE1-common.md) §1, §5).

---

## 1. Патчове

| Патч | Изисквания | Какво прави | Проверка |
|---|---|---|---|
| `001-app-name` (hbb) | C1, C2 | `APP_NAME` по подразбиране = `{{APP_NAME}}` (`ApisQuickSupport`). Същият патч е и `agent/001-app-name` (там → `ApisAgent`) | Release build: config/log в `%APPDATA%\ApisQuickSupport\` (`ApisQuickSupport*.toml`), `%APPDATA%\RustDesk` непроменен (сравнение размер+време на всички файлове), IPC pipe `\\.\pipe\ApisQuickSupport\query`, нов ID ✅ |

| `002-disable-unattended` (+hbb) | A1 | Без постоянна/preset парола структурно: `verification_method()` → само еднократна (→ `permanent_enabled()` = false); `set_permanent_password()` и `set_permanent_password_storage_for_sync()` не записват нищо (UI, IPC, `--password`, sync от услугата); `validate_password()` не проверява постоянна/preset парола (вкл. fallback-а на logon екрана); `insert_switch_sides_uuid()` → нищо, т.е. switch-sides отговор никога не авторизира без клик | `cargo check` ✅ (14); release build: задаване на постоянна парола от UI → `ApisQuickSupport.toml` не е презаписан, `password = ''` ✅; вход/switch-sides → Фаза 4 |
| `003-consent-access-level` | A2, A9 | `permission()` → клавиатура/мишка изключени за всяка нова връзка (само гледане). Прозорецът за съгласие в CM (`buildUnAuthorized`) → „Само гледане“ / „Пълен контрол“ / „Откажи“ вместо „Приеми“ и „Приеми и повиши права“. „Пълен контрол“ праща `SwitchPermission(keyboard, true)` по същия канал преди `Authorize`, т.е. правото е налично от първия кадър. Превключвателят за клавиатура в CM остава — клиентът може да смени нивото по време на сесия | `cargo check` ✅ (14); release build ✅; агент → QS на една машина (след `040`): „Само гледане“ — кликовете не стигат до екрана ✅, „Пълен контрол“ — мишка/клавиатура работят ✅, „Откажи“ — връзката се затваря ✅ |
| `004-no-connection-password` (+hbb) | A3, A2 | `temporary_enabled()` → false (без еднократна парола); `approve_mode()` → винаги `Click`, т.е. връзката стига само до прозореца за съгласие, а контролиращият получава „изчакайте приемане“ вместо искане за парола; `is_recent_session(false)` → false (без повторна връзка със запомнена парола; 2FA повторното ползване остава); картата „Еднократна парола“ на началния екран — скрита | `cargo check` ✅ (14); агент → QS на една машина: картата я няма ✅, агентът не иска парола, а чака приемане ✅, съгласието работи ✅ |

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

## 3. Пътища до авторизация (контролирана страна, 1.5.0)

Единствената точка, която прави връзката авторизирана, е `Connection::send_logon_response_and_keep_alive()` (`src/server/connection.rs`). Извиква се от:

| Път | Условие | След 002 |
|---|---|---|
| `ipc::Data::Authorize` | Клиентът натиска „Приеми“ в CM | Остава — единственият желан път (A2) |
| `LoginRequest` + парола → `validate_password()` | approve-mode `password`/`both` | Затворен с 004: `approve_mode()` = `Click` (не се стига до паролата) и `temporary_enabled()` = false (дори да се стигне, няма валидна парола) |
| `LoginRequest` → `is_recent_session(false)` | Повторна връзка до `SESSION_TIMEOUT` с вече приета еднократна парола | Затворен с 004 |
| `Auth2fa` | Само след успешна парола | Недостижим без парола (004) |
| `SwitchSidesResponse` | uuid, записан при „смени страните“ от тази страна като контролираща | Затворен (002) |

`approve_mode()` (`click`/`password`/`both`) решава дали изобщо се гледа паролата; от 004 е винаги `Click`. Остава един теоретичен вход към паролния път — `allow-logon-screen-password` (builtin опция, само от custom client конфиг → затворен от 039), а и там няма валидна парола. След 002 + 004 единственият път до авторизация е кликът в CM. Preset паролата (`HARD_SETTINGS["password"]`) идва само от custom client конфиг → и без 002 е затворена от 039.

## 4. Проверка на една машина

- `--password <p>` работи само за инсталиран + администратор → неприложимо за преносимия exe.
- UI: опит за задаване на постоянна парола → полето `password` в `%APPDATA%\ApisQuickSupport\config\ApisQuickSupport.toml` трябва да остане празно.
- **Две машини (2026-10-26, от потребителя):** вход с постоянна парола → отказан ✅. Switch-sides, натиснат в **агента** → QS не успява да се свърже обратно, т.е. агентът не става контролиран ✅ — но причината не е установена (логът е на warn) и **не идва от 002**: 002 затваря само uuid-а, записан от QS като контролиращ. Откъм агента защита още няма → (а) QS да игнорира `SwitchSidesRequest` (QS е само контролиран), (б) агентът да не приема входящи връзки (Фаза 5).
- **Агент → QS на една машина** (от 003 нататък): двата build-а се копират в `builds\test\<product>\` (иначе вторият build презаписва първия) и се пускат оттам; QS се познава по банера „АПИС Дистанционна Поддръжка“. Огледалният образ е само визуален — кликът върху Start в отдалечения образ показва дали входът стига до екрана; при отказано право курсорът в агента е „забранен“. Скрипт: `Build-Both.ps1` (scratchpad на сесията — да стане `scripts/Build-Product.ps1`).

## 5. Отворени точки

- Exe име/икона/версия ресурс — Фаза 3–4 (B1).
- UI за постоянна парола (карта „Парола“, „Задай постоянна парола“, верификационен метод) още се вижда → 004/007.
- Инсталация/Windows услуга (F1/F2) — без патч в картата досега; да се реши къде (007 или отделен).
- Агентът: switch-sides и приемане на връзки изобщо → агентски патч във Фаза 5 (агентът не е контролиран).
- „Повиши права“ (Elevate) остава в CM след приемане — да се реши заедно с F1/F2 (UAC за преносимия exe).
- След приемане CM се минимизира (upstream) — видимата индикация е задача на 006 (A8).
- Текстът над ID-то („Вашата работна среда не може да бъде достъпена с този потребителски код и парола“) споменава парола и звучи обратно — за 010-branding-home.
- Следващ патч: `005-connection-limits` (A4–A7).
