# Откъде започва нова сесия (SESSION-START)

> Този файл е входната точка за нова сесия/асистент по проекта. Прочети първо реда за четене по-долу, после „Къде сме" и „Следваща стъпка".

## 0. Какво е проектът (едно изречение)

Легитимен, безплатен инструмент за дистанционна IT поддръжка на собствени клиенти на „АПИС Европа" АД, с изрично съгласие и без unattended достъп — изграден като config-driven patch-overlay върху чист RustDesk.

## 1. Ред за четене (задължително, в този ред)

1. [`CLAUDE.md`](../CLAUDE.md) — контекст, pin, build предпоставки, „не пипай".
2. [`REQUIREMENTS.md`](../REQUIREMENTS.md) — заключени изисквания (v1.1). Канон.
3. [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — архитектура + карта изискване→патч, фази (v0.2). Канон.
4. Този файл — текущо състояние и следваща стъпка.

Каноничните docs надделяват над всяко устно допускане.

## 2. Къде сме (към 2026-10-25)

**Фаза 0 (setup) — завършена ✅**

- Самостоятелно git repo `C:\src\ApisSupport`, публично на https://github.com/ankovachev/ApisSupport (AGPL-3.0), `main` в синхрон с `origin/main`.
- Скелет: `docs/ configs/ patches/{common,quicksupport,agent,new-files}/ scripts/ assets/ builds/`.
- Конфиги: `configs/quicksupport.json`, `configs/agent.json` (попълнени по изискванията).
- Source pin: RustDesk **1.5.0** (`fada664`) + hbb_common `229b9045`, клониран в `rustdesk-source/` (gitignored).
- Тайни: адрес на сървъра + публичен ключ са САМО в `configs/secrets.json` (gitignored, локално) — НЕ в repo-то. Шаблон: `configs/secrets.example.json`.

**Baseline build — успешен ✅** (2026-10-25) — виж [`docs/PHASE0-baseline.md`](PHASE0-baseline.md): toolchain, точни стъпки, капани, smoke тест.

- Проектен vcpkg: `C:\src\ApisSupport\vcpkg` (gitignored, на CI baseline `9e593bb`).

**Фаза 1 — в ход** (2026-10-25)

- Scripts: `Reset-Vanilla.ps1` (dry run без `-Force`; пази `target/`), `Apply-Patches.ps1 -Product X` (изисква vanilla source; `{{TOKEN}}` от `configs/<product>.json` + `secrets.json` в копия под `builds/patches/`; `*.hbb_common.patch` се прилагат в submodule-а), общ `Common.ps1` (pin-ът е само там).
- Патчове: `common/001-server-config` (вграден сървър/ключ/API), `common/002-block-server-override` (N3: exe-name/`--config`/опции/записан сървър/`id@server` игнорирани).
- Smoke тест на patched build (001+002): rendezvous mediator → нашия сървър (UDP latency + NAT отговори на 21116/21115); exe, преименуван на `rustdesk-host=evil.example.com,...`, пак ползва само нашия сървър ✅.
- `common/003-relay-policy`: без proxy (`get/set_socks`, `get_network_type`), `allow-insecure-tls-fallback` винаги изключено (N2), WebRTC изключен структурно (`WebRTCStream::new` → грешка; клиентът иначе отговаря на WebRTC оферти независимо от `enable-webrtc` и ползва публични STUN), без IPv6 STUN проба. P2P = TCP hole punching + relay само през нашия сървър (relay идва от сървъра, override-ът е блокиран в 002). Smoke тест: STUN заявките изчезнаха, няма TCP към чужди адреси ✅.
- `common/010-force-bulgarian`: `resolve_lang` → винаги `bg` (записан `lang`, системен locale и езикът от другата страна се игнорират); `locale: Locale('bg')` в двата `GetMaterialApp`; махната карта „Language“ от общите настройки. Визуално потвърдено от потребителя на en-US Windows без записан език ✅. Забележка: снимка на прозореца от shell-а излиза празна (Flutter/GPU) — визуалните проверки ги прави потребителят.
- `common/011-light-theme-forced`: `MyTheme.getThemeModePreference()` → винаги light; `changeDarkMode()` форсира light (настройки, broadcast между прозорците, CM); махната карта „Theme“. Визуално потвърдено със записано `theme = 'dark'` ✅.
- Поправка в 002: `using_public_server()` → винаги `false`. Блокираната опция `custom-rendezvous-server` е винаги празна и приложението се мислеше за публичния сървър на RustDesk (линк „направете свой собствен сървър“, ограничено FPS/качество при relay, по-рядка проверка на онлайн статус, backoff при регистрация). Визуално потвърдено ✅.
- `common/020-strip-rustdesk-strings`: „RustDesk“ във всички преводи → `{{DISPLAY_NAME}}` (видимото име по продукт); заглавие на прозореца и текстът до логото в таба → `{{WINDOW_TITLE}}`; „Powered by RustDesk“ махнат. `Apply-Patches.ps1`: нови token-и `DISPLAY_NAME`/`WINDOW_TITLE` + отказ на стойности с кавички/`\`/нов ред (отиват в низове в кода). Визуално потвърдено ✅. Остават линкове към rustdesk.com в скрити/по-късни места (about/privacy в настройките → 007, install page → QS, update → 036); иконата → branding (B1).
- `common/030-remove-lan-discovery`: `lan::start_listening` (UDP 21119, отговаряше с ID/hostname/user/MAC), `ui_interface::discover` (broadcast) и `lan::send_wol` → ранен return; табът „Открити“ скрит. Проверено: няма UDP 21119 и TCP listener-и, табът липсва ✅.
- `common/031-remove-direct-ip-tunneling`: клиентът отказва ID във вид IP / `домейн:порт` („Direct IP access is disabled“); `direct_server` (TCP 21118) не тръгва; `Connection::permission()` винаги отказва `enable-tunnel` (TCP tunneling и RDP); `port_forward::listen` не отваря локален listener. Проверено: `127.0.0.1` → грешка, няма TCP listener-и ✅. Tunneling-ът е непроверен с 2 машини (Фаза 4). Отворено: менютата „TCP tunneling“/„RDP“ и „Terminal“ още се виждат в UI-а (агент) — за почистване на UI-а на агента; новите съобщения за грешка са на английски (превод → 020/bg). Remote terminal → забранен (P14, добавен в REQUIREMENTS), отива в `037-security-defaults`.
- `032-remove-plugin-system`: **не е нужен** — plugin системата липсва в 1.5.0; само фиксирани DLL-и от папката на приложението + системни. Remote printer (`printer_driver_adapter.dll`) → за 037 (канал за данни като P1).
- `common/033-remove-camera`: `Connection::permission()` винаги отказва `enable-camera` (login „View camera“ → „No permission of viewing camera“); в `libs/scrap` `primary_camera_exists()` → false, `Cameras::all_info()` → празно, `get_capturer()` → грешка (камерите не се изброяват и не се отварят). `cargo check` ✅; runtime непроверен (изисква 2 машини → Фаза 4).
- `common/034-remove-block-input`: `Connection::permission()` винаги отказва `enable-block-input`; `platform::windows::block_input(true)` винаги връща грешка (защото клиентът може да включи правото по време на сесия от CM; изключването минава). `cargo check` ✅; runtime → Фаза 4. Превключвателят в CM ще се скрие с consent UI-а (Фаза 2).
- Видяно, за Фаза 2: UAC/„Инсталирай“ банер (F1/F2), connect панел, еднократна парола (A3).
- Сървър (2026-10-25): nginx подаваше само крайния сертификат → rustls даваше `InvalidCertificate(UnknownIssuer)`. Поправено на сървъра: `/etc/nginx/ssl/apis.crt` = краен + Sectigo DV R36 (копие `apis.crt.bak-2026-10-25`); `apis.key` → `600`. Отвън `Verify return code: 0`, грешката изчезна от лога ✅. Дублираните server блокове за сайта (в `sites-available/default` и `<сайт>`) са обединени в `sites-available/<сайт>` (вкл. `location /api/` → `127.0.0.1:8001`, който липсваше там); `default` = само catch-all. Копие: `/root/nginx-backup-2026-10-25/`. `nginx -t` без предупреждения, `/api/` пак стига до бекенда ✅.
- Капан: `Build-Baseline.ps1` с `*>` пренасочване в PowerShell 5.1 пада (stderr на cargo → грешка при `ErrorActionPreference=Stop`); пренасочвай отвън (`powershell -File ... > log 2>&1`).

## 3. Следваща стъпка (започни оттук)

**Фаза 1, продължение** (виж картата в `ARCHITECTURE.md` §6.1): `035-remove-privacy-mode` (вкл. `toggle_blank_screen`) и останалия security hardening (036–038). После Фаза 2 (QuickSupport патчове).

Още липсва `Build-Product.ps1`; дотогава build върху патчнат source = `Apply-Patches.ps1` + `Build-Baseline.ps1`.

### Claude Code skills + hooks

**Направени (2026-10-25):** skill `rustdesk-build` (`.claude/skills/rustdesk-build/`) и guard hook (`.claude/settings.json` → `.claude/hooks/guard-rustdesk-source.ps1`): Edit/Write в `rustdesk-source/` → **deny**; `cargo clean` и деструктивни git команди към `rustdesk-source/` → **ask**. Важат само за сесии, отворени в `C:\src\ApisSupport` (не в `C:\src`). Ограничение: hook-ът не вижда запис във файл през shell (напр. `Set-Content`) и git команди вътре в скриптове — скриптовете са одобреният път.

Пълният план:

Собствени, малки, в git (`.claude/skills/`, `.claude/settings.json`) — без непрегледани чужди пакети (supply-chain / prompt-injection риск за инструмент за отдалечен достъп).

| Какво | Тип | Кога | Защо |
|---|---|---|---|
| `rustdesk-build` | skill | веднага (капаните са пресни) | Build стъпките + капаните от `PHASE0-baseline.md` — новите сесии да не ги преоткриват |
| Забрана за директни Edit/Write в `rustdesk-source/` | hook | веднага | Налага „само през патчове" (CLAUDE.md „Не пипай") вместо да разчита на памет |
| Блок на `cargo clean` и деструктивни git команди в `rustdesk-source/` | hook | веднага | Пази `target/` кеша и чистотата на source-а |
| `patch-workflow` | skill | с първия патч | Създаване/обновяване на патч, `git apply --check`, `{{PLACEHOLDER}}`-и, regression-surface проверка |
| `session-handoff` | skill | Фаза 1 | В края на сесия: обнови този файл + commit |
| `security-check` | skill | Фаза 1–2 | Чеклист срещу REQUIREMENTS (A1, N3, P1–P13) — патч да не отваря премахнат код-път |

Принцип: skill е насока (може да се пропусне); това, което **не бива** да се случи, се налага с hook. Skills се обновяват заедно с pin-а на source-а.

## 4. Важни напомняния

- `rustdesk-source/` се пипа САМО през патчове; `rustdesk-source/target/` е кеш — без `cargo clean` без одобрение.
- Тайните (сървър/ключ) не влизат в repo — винаги през `secrets.json`.
- Commit след всяка успешна стъпка (restore точки). UI текстове на български; код/commits на английски.
- Проектът е легитимен (виж `REQUIREMENTS.md` раздели 0 и 10): поддръжка със съгласие, без unattended. Формулирай работата конкретно и технически.

## 5. Среда (напомняне)

- `$env:VCPKG_ROOT = 'C:\src\ApisSupport\vcpkg'` и `$env:VCPKG_DEFAULT_HOST_TRIPLET = 'x64-windows-static'` преди build (user env `VCPKG_ROOT` вече сочи към проектния vcpkg; host triplet-ът се задава в build скрипта).
- Windows / PowerShell. Build е тежък (минути) — пускай във фон при нужда.
