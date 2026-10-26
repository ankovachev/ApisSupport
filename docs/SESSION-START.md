# Откъде започва нова сесия (SESSION-START)

> Този файл е входната точка за нова сесия/асистент по проекта. Прочети първо реда за четене по-долу, после „Къде сме" и „Следваща стъпка".

## 0. Какво е проектът (едно изречение)

Легитимен, безплатен инструмент за дистанционна IT поддръжка на собствени клиенти на „АПИС Европа" АД, с изрично съгласие и без unattended достъп — изграден като config-driven patch-overlay върху чист RustDesk.

## 1. Ред за четене (задължително, в този ред)

1. [`CLAUDE.md`](../CLAUDE.md) — контекст, pin, build предпоставки, „не пипай".
2. [`REQUIREMENTS.md`](../REQUIREMENTS.md) — заключени изисквания (v1.1 + P14/P15 и уточнения от 2026-10-25/26, вкл. A4/A5/A7). Канон.
3. [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — архитектура + карта изискване→патч, фази. Канон.
4. [`docs/PHASE1-common.md`](PHASE1-common.md) — общите патчове (вкл. 039–041 от 2026-10-26), token-и, процес, рецепти.
5. [`docs/PHASE2-quicksupport.md`](PHASE2-quicksupport.md) — QuickSupport патчове 001–009, картите (APP_NAME, пътища до авторизация, L2 одит), проверки, отворени точки.
6. Този файл — текущо състояние и следваща стъпка.

Каноничните docs надделяват над всяко устно допускане.

## 2. Къде сме (към 2026-10-26, вечер)

| Фаза | Състояние | Детайли |
|---|---|---|
| 0 — setup + vanilla baseline | ✅ | [`PHASE0-baseline.md`](PHASE0-baseline.md) |
| 1 — общи патчове (`patches/common/`) | ✅ (+ 039, 040, 041 от 2026-10-26) | [`PHASE1-common.md`](PHASE1-common.md) |
| 2 — QuickSupport патчове | ✅ 001–009, с една отворена точка (повишаване на права) | [`PHASE2-quicksupport.md`](PHASE2-quicksupport.md) |
| 3 — QuickSupport branding | ⏭ следваща | §3.3 по-долу |
| 4–7 | предстоят | `ARCHITECTURE.md` §8 |

- **Repo:** `main`; на `origin/main` е всичко до `b729373` (008). **Локално, непушнато:** 009 + документацията от вечерта — push след одобрение (§3.1).
- **Source:** `rustdesk-source/` чист, на pin-а (RustDesk 1.5.0 `fada664` + hbb_common `229b9045`). `target/` кешът е топъл (`cargo check` ~15 s, build ~5–7 мин).
- **QuickSupport днес (проверено на две машини):** собствен APP_NAME (`%APPDATA%\ApisQuickSupport`), случайно ID, без постоянна и без еднократна парола, достъп само с клик в прозореца за съгласие с избор „Само гледане“ / „Пълен контрол“ / „Откажи“, лимити (съгласие 120 s, неактивност 30 мин, max 2 сесии, 3 прозореца/мин), видим прозорец на сесията с време, ниво и „Прекъсни“, компактен прозорец без настройки и без панел за свързване, X = изход, без инсталация и услуга.
- **Агентът:** засега само общите патчове + `agent/001-app-name`; изглежда като upstream с наш сървър/език/тема. Фаза 5.
- **Тестови build-ове:** `builds\test\quicksupport\`, `builds\test\agent\` (последните), `builds\test\quicksupport-diag\` (лог `info`, само за диагностика). Чек лист за повишаването: `builds\test\CHECKLIST-009-povishavane.md`. Всичко в `builds\` е gitignored.

## 3. Следваща стъпка — план за следващата сесия

### 3.1 Старт (5 мин)

1. Отвори сесията в `C:\src\ApisSupport` (иначе guard hook-ът не е активен).
2. Прочети файловете от §1.
3. Провери състоянието:
   ```powershell
   git status -sb                     # очаквано: ahead на origin/main с commit-ите от 2026-10-26 вечерта
   git diff origin/main --stat -- configs   # конфигът не трябва да е с тестови стойности (level "warn", idle 30, max 2)
   .\scripts\Reset-Vanilla.ps1        # трябва да каже "Already vanilla."
   ```
4. Push на непушнатите commit-и — **след одобрение** (secret scan: виж `PHASE1-common.md` §5).

### 3.2 Отворено от Фаза 2 — повишаване на права (първо, ~30 мин)

Проблем: след „Повишаване“ + UAC „Да“ входът от агента работи, но картината при агента замръзва (две машини: клиент настолен Windows 10, агент лаптоп Windows 11). Анализ и логове: `PHASE2-quicksupport.md` §5.

1. **Сравнение с upstream** (решаващо): официалният преносим RustDesk от rustdesk.com на същите две машини (публичните сървъри на RustDesk, без инсталация) → сесия → „Повишаване“ при клиента → UAC „Да“ → замръзва ли картината?
   - **Да** → ограничение на upstream/средата. Решение с потребителя: да остане (работи там, където DXGI работи) или да се забрани изцяло (нов малък hunk в 009: `start_portable_service` → грешка и скрит бутон).
   - **Не** → проблемът е в нашия build: diff на поведението; логът на SYSTEM процеса (засега липсва — да се намери къде пише или да се добави временен лог във файл).
2. Видеокартата на клиента: Device Manager → Display adapters (при „Microsoft Basic Display Adapter“ DXGI заснемането обикновено не работи).

### 3.3 Фаза 3 — QuickSupport branding (`ARCHITECTURE.md` §6.2, `010-branding-home`)

- Header (двуреден, син, центриран): „АПИС Европа АД“ / „Система за дистанционна помощ“; лого „Силата на информацията“; terms-of-use панел с дословния текст и линковете от `REQUIREMENTS.md` Приложение А (B3, B5).
- Текстът над ID-то („Вашата работна среда не може да бъде достъпена …“) — неточен, да се смени.
- Икони (всички размери) и exe: `ApisQuickSupport.exe`, `Runner.rc` (ProductName / FileDescription / CompanyName — сега „RustDesk Remote Desktop“ / „Purslane Tech“ в Task Manager), иконата на прозореца и лентата (B1).
- Статус „Готово“ — вече на български (А.4).
- Нужни входни материали от потребителя: лого и икони (файлове), ако още не са в `assets/`.

### 3.4 Отворени точки (не са блокиращи)

- **Одит към API сървъра:** при всяка връзка `Audit post dropped … status 404` — endpoint на сървъра или спиране на изпращането (решение с потребителя).
- **F5 под Enigma (Фаза 4):** споделената памет при повишаване (`C:\ProgramData\ApisQuickSupport\portable_service_shmem\`), конфиг/лог на SYSTEM процеса.
- **Агент (Фаза 5):** `is_outgoing_only()` (не приема връзки — затваря и switch-sides откъм агента), менютата TCP tunneling/RDP/Terminal/View camera и „повишаване с име и парола“ в агента.
- Рамка около екрана по време на сесия (A8, по желание) — Фаза 3.
- `--install-idd`, `--install-remote-printer` (драйвери, изискват администратор) — да се преценят във Фаза 4.

### 3.5 Работен цикъл за всеки патч

Картографиране (само четене) → `scripts\New-PatchScratch.ps1 -Dir <scratch> -MainFiles … -HbbFiles … [-Product none]` → редакция в scratch → `git diff` с **cmd** пренасочване в `patches\…` → `Apply-Patches` за **двата** продукта → `cargo check --lib --features flutter,hwcodec` (14 предупреждения от upstream) → `scripts\Build-Test.ps1` (`builds\test\<product>\`) → тест (визуален/на две машини — от потребителя; при много стъпки — чек лист в `builds\test\`) → `Reset-Vanilla -Force` → docs + commit → secret scan → push след одобрение.

`Build-Test.ps1` е почистена версия на скрипта, ползван на 2026-10-26 — при първото пускане да се провери изходът.

## 4. Claude Code skills + hooks

**Направени (2026-10-25):** skill `rustdesk-build` (`.claude/skills/rustdesk-build/`) и guard hook (`.claude/settings.json` → `.claude/hooks/guard-rustdesk-source.ps1`): Edit/Write в `rustdesk-source/` → **deny**; `cargo clean` и деструктивни git команди към `rustdesk-source/` → **ask**. Важат само за сесии, отворени в `C:\src\ApisSupport`. Ограничение: hook-ът не вижда запис във файл през shell и git команди вътре в скриптове — скриптовете са одобреният път.

Собствени, малки, в git — без непрегледани чужди пакети (supply-chain / prompt-injection риск за инструмент за отдалечен достъп).

| Какво | Тип | Състояние | Защо |
|---|---|---|---|
| `rustdesk-build` | skill | ✅ | Build стъпките + капаните от `PHASE0-baseline.md` |
| Забрана за директни Edit/Write в `rustdesk-source/` | hook | ✅ | Налага „само през патчове" |
| Блок на `cargo clean` и деструктивни git команди в `rustdesk-source/` | hook | ✅ | Пази `target/` кеша и чистотата на source-а |
| `scripts/New-PatchScratch.ps1`, `scripts/Build-Test.ps1` | скриптове | ✅ 2026-10-26 | Основата за `patch-workflow` |
| `patch-workflow` | skill | предстои | Процесът от §3.5 |
| `session-handoff` | skill | предстои | В края на сесия: обнови този файл + commit |
| `security-check` | skill | предстои | Чеклист срещу REQUIREMENTS (A1, N3, P1–P15) — патч да не отваря премахнат код-път |

Принцип: skill е насока (може да се пропусне); това, което **не бива** да се случи, се налага с hook.

## 5. Важни напомняния

- `rustdesk-source/` се пипа САМО през патчове; `rustdesk-source/target/` е кеш — без `cargo clean` без одобрение.
- Тайните (сървър/ключ) не влизат в repo — винаги през `secrets.json`; в docs и отговори адресът се маскира. Нов патч се генерира от **token-формата** на предходните (`New-PatchScratch.ps1`), никога от приложения source.
- Commit след всяка успешна стъпка (restore точки); push — след одобрение. UI текстове на български; код/commits на английски. Общуването с потребителя — на български.
- **Тестови стойности в конфига** (`-TestLimits`, `-LogLevel`) се връщат във `finally`; ако команда бъде прекъсната, преди commit провери `git status -- configs` (на 2026-10-26 прекъсната команда остави `level: info` в конфига и той влезе в commit — коригирано преди push).
- Проектът е легитимен (виж `REQUIREMENTS.md` раздели 0 и 10): поддръжка със съгласие, без unattended. Формулирай работата конкретно и технически.

## 6. Среда (напомняне)

- `$env:VCPKG_ROOT = 'C:\src\ApisSupport\vcpkg'`, `$env:VCPKG_DEFAULT_HOST_TRIPLET = 'x64-windows-static'`, `$env:LIBCLANG_PATH = 'C:\Program Files\LLVM\bin'` (build скриптът ги задава сам).
- Windows / PowerShell 5.1. Build е тежък (минути) — пускай във фон, с пренасочване на изхода **отвън** (`powershell -File ... > log 2>&1`).
- Капани в PowerShell 5.1: `>` пише UTF-16 → за патчове `cmd /c "git diff > file"`; масив от един елемент се „разлива“ по символи при splat → `List[string]`; here-string към `git commit -F -` не стига до stdin → съобщение от файл (`-F file`); stderr предупреждения на git + `$ErrorActionPreference='Stop'` → грешка (проверявай `$LASTEXITCODE`).
- Тест на една машина: QS и агентът от `builds\test\` (различни APP_NAME и ID); огледалният образ е само визуален — кликът върху „Старт“ в отдалечения образ показва дали входът стига.
