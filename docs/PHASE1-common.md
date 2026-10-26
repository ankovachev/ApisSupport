# Фаза 1 — общи патчове (`patches/common/`)

**Дата:** 2026-10-25
**Резултат:** ✅ Завършена — 14 общи патча (17 файла) за двата продукта, прилагат се чисто върху RustDesk 1.5.0 и компилират без нови предупреждения. Приложението говори **само с нашия сървър** (проверено по DNS, по сокети и по лога).

Канон за изискванията: [`REQUIREMENTS.md`](../REQUIREMENTS.md). Карта изискване→патч: [`ARCHITECTURE.md`](ARCHITECTURE.md) §6.1.

---

## 1. Инструменти (`scripts/`)

| Скрипт | Какво прави |
|---|---|
| `Common.ps1` | Общи пътища и pin-ът на source-а (единственото място с SHA-тата). Dot-source от другите скриптове. |
| `Reset-Vanilla.ps1 [-Force]` | Без `-Force`: само показва какво би върнал. С `-Force`: `reset --hard` + `clean -fd` (без `-x` → `target/` и build кешовете остават), submodule-ът `hbb_common` обратно на pin-а. Ако HEAD не е на pin-а — грешка, не го мести. |
| `Apply-Patches.ps1 -Product quicksupport\|agent` | Изисква vanilla source. Подготвя **всички** патчове (замества `{{TOKEN}}` в копия под `builds/patches/<product>/`, отказва непознат token) и чак тогава прилага `common/` → `<product>/` по име, всеки с `git apply --check`. `*.hbb_common.patch` се прилагат в `libs/hbb_common`. Накрая копира `patches/new-files/`. |
| `Build-Baseline.ps1` | Build на каквото има в `rustdesk-source/` (vanilla или патчнато). `Build-Product.ps1` още липсва. |

### Token-и (от `configs/<product>.json` + `configs/secrets.json`)

| Token | Източник | Ползван в |
|---|---|---|
| `{{SERVER}}`, `{{PUBLIC_KEY}}`, `{{API_SERVER}}` | `secrets.json` (gitignored) | 001 |
| `{{APP_NAME}}` | `branding.app_name` (само букви, цифри, тире) | `quicksupport/001`, `agent/001` |
| `{{DISPLAY_NAME}}`, `{{WINDOW_TITLE}}` | `branding.display_name`, `branding.window_title` | 020 |
| `{{LOG_LEVEL}}`, `{{LOG_RETENTION_DAYS}}` | `logging.level`, `logging.max_local_retention_days` | 038 |

Стойностите отиват директно в низове в Rust/Dart код → скриптът отказва кавички, `\` и нов ред; `LOG_LEVEL` ∈ error/warn/info/debug/trace; retention 1–999. Ако `secrets.json` още съдържа стойностите от шаблона — отказ.

### Как се прави патч (установен процес)

1. Картографиране в `rustdesk-source/` (само четене) — намира се **общата точка** (choke point), през която минават всички пътища до функцията.
2. Копия на засегнатите файлове от pin-а (`git show HEAD:<file>`) в scratch git repo; върху тях се прилагат **предишните патчове, които пипат същите файлове** (контекстът трябва да съвпада).
3. Редакция с малък perl скрипт (повторяема), `git diff` → `patches/common/NNN-*.patch`.
4. `Reset-Vanilla -Force` → `Apply-Patches` за **двата** продукта → `cargo check --lib --features flutter,hwcodec` (броят предупреждения трябва да остане 14 — всички от upstream).
5. Build + проверка (мрежа/лог/визуално), ако патчът има наблюдаемо поведение на една машина.
6. `Reset-Vanilla -Force`, обновяване на docs, commit; secret scan на разликата преди push.

Конвенции в патчовете: всеки добавен ред носи коментар `// Apis (<изискване>): …`; предпочитат се **само добавени редове** — ранно `return` в началото на функцията + `#[allow(unreachable_code[, unused_variables])]`, без триене на upstream код (малки hunks → лесен rebase при upgrade).

---

## 2. Патчове

| Патч | Изисквания | Какво прави | Проверка |
|---|---|---|---|
| `001-server-config` (+hbb) | N1 | Вграден rendezvous сървър, публичен ключ и API адрес (`{{SERVER}}`/`{{PUBLIC_KEY}}`/`{{API_SERVER}}`) | Smoke: mediator → нашия сървър ✅ |
| `002-block-server-override` (+hbb) | N3 | Сървърът е само вграденият: игнорирани exe-name „license“, `--config`, опциите `custom-rendezvous-server`/`rendezvous-servers`/`relay-server`/`api-server`/`key` (не се четат и не се записват), записаният `rendezvous_server`, синтаксисът `id@server`. `using_public_server()` → `false` (иначе приложението се мислеше за публичния сървър на RustDesk) | exe, преименуван на `rustdesk-host=evil.example.com,...` → пак само нашия ✅; линкът „направете свой сървър“ изчезна ✅ |
| `003-relay-policy` (+hbb) | N1, N2, N4 | Без proxy (SOCKS/HTTP); `allow-insecure-tls-fallback` винаги изключено; WebRTC изключен структурно (`WebRTCStream::new` → грешка — клиентът иначе отговаря на WebRTC оферти и ползва публични STUN); без IPv6 STUN проба. P2P = TCP hole punching през нашия сървър, relay само през нашия | STUN заявките изчезнаха; няма TCP към чужди адреси ✅ |
| `010-force-bulgarian` | B2 | `resolve_lang` → винаги `bg`; `locale: Locale('bg')` в двата `GetMaterialApp`; махната карта „Language“ | Визуално на en-US Windows ✅ |
| `011-light-theme-forced` | B6 | `getThemeModePreference()` → light; `changeDarkMode()` форсира light; махната карта „Theme“ | Визуално със записано `theme='dark'` ✅ |
| `020-strip-rustdesk-strings` | B4, B1, B7 | „RustDesk“ във всички преводи → `{{DISPLAY_NAME}}`; заглавие на прозореца и таба → `{{WINDOW_TITLE}}`; „Powered by RustDesk“ махнат | Визуално ✅ (UAC банерът казва „АПИС Дистанционна Поддръжка“; title „АПИС Европа АД“) |
| `030-remove-lan-discovery` | P9, C3 | Без UDP 21119 listener (отговаряше с ID/hostname/user/MAC), без broadcast търсене, без Wake-on-LAN; табът „Открити“ скрит | Няма UDP 21119 и TCP listener-и; табът липсва ✅ |
| `031-remove-direct-ip-tunneling` | P10, C3 | Клиентът отказва ID-та тип IP / `домейн:порт`; без direct-access listener (TCP 21118); `permission()` отказва tunnel (TCP tunneling и RDP); без локален forwarding listener | `127.0.0.1` и `127.0.0.1:21118` → „Direct IP access is disabled“ ✅; tunneling → Фаза 4 |
| ~~`032-remove-plugin-system`~~ | P8 | **Не е нужен** — plugin системата липсва в 1.5.0; зареждат се само фиксирани DLL-и от папката на приложението и системни | Проверено в source-а |
| `033-remove-camera` | P5 | `permission()` отказва camera; `libs/scrap`: камерите не се изброяват и не се отварят | `cargo check` ✅; runtime → Фаза 4 |
| `034-remove-block-input` | P6 | `permission()` отказва block-input; `platform::block_input(true)` винаги грешка (клиентът може да включи правото от CM по време на сесия) | `cargo check` ✅; runtime → Фаза 4 |
| `035-remove-privacy-mode` | P7 | `permission()` отказва privacy-mode; `is_privacy_mode_supported()` → false; `turn_on_privacy()` → грешка | `cargo check` ✅; runtime → Фаза 4 |
| `036-disable-auto-update-telemetry` | P11 | `do_check_software_update()` → без заявка (единствената връзка към `api.rustdesk.com`; покрива ръчна проверка и auto-update) | За 40 s в DNS кеша **само нашия сървър** ✅ |
| `037-security-defaults` | P1–P4, P12, P14, P15 | `permission()` отказва audio, recording, terminal, remote printer, remote restart; clipboard и file transfer изключени при свързване. CM не може да включи audio/recording/restart/block_input/privacy_mode | `cargo check` ✅; runtime → Фаза 4 |
| `038-logging-hardening` (hbb) | P13, L2 | Ниво `{{LOG_LEVEL}}` (warn), `RUST_LOG` не може да го вдигне; retention `{{LOG_RETENTION_DAYS}}` (7) вместо 90; IP адресите → `<ip>` | Release build с `RUST_LOG=trace`: 4 реда WARN/ERROR, 0 IP ✅ |
| `039-custom-client-hardening` (+hbb) | C1, L2, N3, A8 | *Добавен 2026-10-26, заедно с `001-app-name` от Фаза 2.* `read_custom_client()` → нищо (подписан `custom.txt` до exe-то иначе сменя APP_NAME и налага настройки); `hide_cm()` → `false` (става достъпен по IPC, щом `is_custom_client()` е true) | `cargo check` ✅ |
| `040-random-device-id` (hbb) | F5, C1 | *Добавен 2026-10-26.* `get_auto_id()` → случайно 10-цифрено ID (както upstream на Android/iOS) вместо производното от MAC адреса. Без виртуализация ID-то се пази в конфига; с празна конфигурация (Enigma) — ново при всяко стартиране | Release build, празни конфигурации: QS и агентът на една машина → различни 10-цифрени ID (преди: и двата `501 818 368`) ✅ |

Общите точки, които по-късните патчове ползват: `Connection::permission()` в `src/server/connection.rs` (всички права на контролираната страна) и `SwitchPermission` handler-ът (превключватели от CM по време на сесия).

---

## 3. Решения, взети по време на фазата

| Решение | Къде е записано |
|---|---|
| Proxy (SOCKS/HTTP) — **блокиран** (чужда инфраструктура, сменим през config) | 003 |
| WebRTC — **изключен** структурно (публични STUN/TURN) | 003 |
| **P14** Remote terminal — забранен (shell, вкл. администраторски, без видимост за клиента) | REQUIREMENTS |
| **P15** Remote restart — забранен | REQUIREMENTS |
| P1/P2: clipboard (текст) и file transfer — **изключени при свързване, клиентът може да ги включи за сесията от CM**; отделният прозорец „Прехвърляне на файлове“ остава отказан | REQUIREMENTS, 037 |
| P3/P4: audio и recording — забранени структурно (и от CM) | REQUIREMENTS, 037 |
| P12 IPv6 — без отделен код (покрит от 031 и 003) | REQUIREMENTS |
| `sysinfo`/heartbeat към **нашия** API сървър — оставени (N1) | 036 |

---

## 4. Промени на сървъра (извън repo-то)

| Проблем | Поправка | Копие |
|---|---|---|
| nginx подаваше само крайния сертификат → rustls: `InvalidCertificate(UnknownIssuer)` | `/etc/nginx/ssl/apis.crt` = краен + Sectigo Public Server Authentication CA DV R36 | `/etc/nginx/ssl/apis.crt.bak-2026-10-25` |
| `apis.key` беше четим за всички (`644`) | `chmod 600` | — |
| Дублирани server блокове за сайта в `sites-available/default` и `sites-available/<сайт>` (`conflicting server name`); активното копие в `default` имаше `location /api/` → `127.0.0.1:8001`, което липсваше в другото | Всичко за сайта — в `sites-available/<сайт>` (вкл. `/api/`); `default` = само catch-all | `/root/nginx-backup-2026-10-25/` |

След поправките: отвън `Verify return code: 0 (ok)`; `nginx -t` без предупреждения; `/api/` пак стига до бекенда (`404 application/json` от uvicorn за `/api/`).

---

## 5. Рецепти за проверка

- **Цикъл:** `Reset-Vanilla.ps1 -Force` → `Apply-Patches.ps1 -Product agent` → `Reset-Vanilla.ps1 -Force` → `Apply-Patches.ps1 -Product quicksupport` → проверка → `Reset-Vanilla.ps1 -Force`.
- **Компилация:** `cargo check --lib --features flutter,hwcodec` в `rustdesk-source/` (env: `VCPKG_ROOT`, `VCPKG_DEFAULT_HOST_TRIPLET=x64-windows-static`, `LIBCLANG_PATH`). Код под `#[cfg(not(debug_assertions))]` (напр. 038) се проверява само с release build.
- **Build:** `powershell -NoProfile -File scripts\Build-Baseline.ps1 > log 2>&1` (пренасочване **отвън**; с `*>` в PowerShell 5.1 пада). ~5–7 мин. Изход: `rustdesk-source\flutter\build\windows\x64\runner\Release\rustdesk.exe`.
- **`%APPDATA%\RustDesk`:** докато няма `quicksupport/001-app-name`, build-ът ползва папката на стандартния RustDesk → **преди тест копие, след теста възстановяване**. (Копието от 2026-10-25 беше в scratchpad на сесията и не се пази.)
- **Мрежа:** `Clear-DnsClientCache` → старт за ~40 s → `Get-DnsClientCache` (очаква се само нашият сървър); `Get-NetTCPConnection -State Listen` / `Get-NetUDPEndpoint` за процеса.
- **Лог:** `%APPDATA%\RustDesk\log\rustdesk_rCURRENT.log` (при warn ниво — почти празен).
- **Визуално:** снимка от shell-а излиза празна (Flutter рисува през GPU) → визуалната проверка я прави потребителят; приложението се стартира и се оставя да работи.
- **Тайни:** преди всеки push — проверка, че адресът/хостът/API/ключът от `secrets.json` не са в `git diff origin/main..HEAD`; в отговори и docs адресът се маскира.

---

## 6. Отворени точки

**E2E с две машини (Фаза 4)** — отказите, видими само при реална входяща връзка:
- TCP tunneling / RDP (031), View camera (033), block-input от контролиращия и от CM (034), privacy mode (035), audio/recording/terminal/remote printer/remote restart и CM превключвателите (037), clipboard/file per-session (037).

**UI почистване:**
- QuickSupport: UAC/„Инсталирай“ банер, панел „Отдалечено управление“, история на сесиите, еднократна парола (Фаза 2).
- Агент: менюта „TCP tunneling“, „RDP“, „Terminal“, „View camera“ още се виждат (при избор → грешка).
- Новите съобщения за грешка („Direct IP access is disabled“ и др.) са на английски — нужен е превод.
- Шум в лога: „Failed to load lan peers“ (ERROR) — UI-ът още чете LAN списъка.
- Линкове към rustdesk.com в about/privacy (скрити с 007), install page (QS), иконата (B1, branding).

**При upgrade на RustDesk:** да се провери отново, че plugin системата липсва (032) и че `toggle_blank_screen` няма извиквания (035).
