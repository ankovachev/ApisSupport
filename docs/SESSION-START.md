# Откъде започва нова сесия (SESSION-START)

> Този файл е входната точка за нова сесия/асистент по проекта. Прочети първо реда за четене по-долу, после „Къде сме" и „Следваща стъпка".

## 0. Какво е проектът (едно изречение)

Легитимен, безплатен инструмент за дистанционна IT поддръжка на собствени клиенти на „АПИС Европа" АД, с изрично съгласие и без unattended достъп — изграден като config-driven patch-overlay върху чист RustDesk.

## 1. Ред за четене (задължително, в този ред)

1. [`CLAUDE.md`](../CLAUDE.md) — контекст, pin, build предпоставки, „не пипай".
2. [`REQUIREMENTS.md`](../REQUIREMENTS.md) — заключени изисквания (v1.1 + P14/P15 и уточнения от 2026-10-25). Канон.
3. [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) — архитектура + карта изискване→патч, фази. Канон.
4. [`docs/PHASE1-common.md`](PHASE1-common.md) — какво е направено във Фаза 1: инструменти, патчове, решения, сървърни промени, рецепти за проверка, отворени точки.
5. Този файл — текущо състояние и следваща стъпка.

Каноничните docs надделяват над всяко устно допускане.

## 2. Къде сме (към 2026-10-26, сутрин)

| Фаза | Състояние | Детайли |
|---|---|---|
| 0 — setup + vanilla baseline | ✅ | [`PHASE0-baseline.md`](PHASE0-baseline.md) |
| 1 — общи патчове (`patches/common/`) | ✅ | [`PHASE1-common.md`](PHASE1-common.md) |
| 2 — QuickSupport патчове | ▶ в ход (`001`–`004` ✅) | [`PHASE2-quicksupport.md`](PHASE2-quicksupport.md), §3 по-долу |
| 3–7 | предстоят | `ARCHITECTURE.md` §8 |

- **Repo:** `main` = `origin/main` (https://github.com/ankovachev/ApisSupport), локално има commit-и за `001-app-name` / `039` (push — след одобрение).
- **Source:** `rustdesk-source/` чист, на pin-а (RustDesk 1.5.0 `fada664` + hbb_common `229b9045`). `target/` кешът е топъл (incremental `cargo check` ~11 s, build ~5–7 мин).
- **Готово във Фаза 1:** scripts `Reset-Vanilla` / `Apply-Patches` / `Common`; 14 общи патча (001–003, 010, 011, 020, 030, 031, 033–038; 032 не е нужен) + `039` (добавен 2026-10-26). Приложението говори само с нашия сървър, на български, светла тема, без „RustDesk“ в текстовете, без LAN discovery / direct IP / tunneling / WebRTC / proxy / update check, с отказани опасни права и минимален лог.
- **Сървър:** поправени веригата на TLS сертификата, правата на частния ключ и дублираният nginx config (виж `PHASE1-common.md` §4).
- **Нови изисквания:** P14 (remote terminal — забранен), P15 (remote restart — забранен); уточнени P1–P4 и P12.

## 3. Следваща стъпка — план за следващата сесия

### 3.1 Старт (5 мин)

1. Отвори сесията в `C:\src\ApisSupport` (иначе guard hook-ът не е активен).
2. Прочети файловете от §1.
3. Провери състоянието:
   ```powershell
   git status -sb
   .\scripts\Reset-Vanilla.ps1        # трябва да каже "Already vanilla."
   ```
4. С `001-app-name` build-ът пише в `%APPDATA%\ApisQuickSupport` (агентът — `%APPDATA%\ApisAgent`), не в `%APPDATA%\RustDesk`; архив вече не е нужен. Копие от 2026-10-26 стои в `builds\appdata-backup\` (gitignored).

### 3.2 Фаза 2 — QuickSupport патчове (`patches/quicksupport/`)

Ред (карта: `ARCHITECTURE.md` §6.2):

| # | Патч | Изисквания | Бележки за старта |
|---|---|---|---|
| 1 | `001-app-name` | C1 | ✅ 2026-10-26 (+ `common/039-custom-client-hardening`). Карта и странични ефекти на `is_custom_client()`: `PHASE2-quicksupport.md` §2. |
| 2 | `002-disable-unattended` | A1 | ✅ 2026-10-26. Пътищата до авторизация: `PHASE2-quicksupport.md` §3. |
| 3 | `003-consent-access-level` | A2, A9 | ✅ 2026-10-26. „Само гледане“ / „Пълен контрол“ / „Откажи“ в CM; клавиатурата стартира изключена. |
| 4 | `004-no-connection-password` | A3 | ✅ 2026-10-26. Без еднократна парола; `approve-mode` винаги `click`; картата „Еднократна парола“ скрита. |
| 5 | `005-connection-limits` | A4–A7 | Timeout 60 s, idle 15 мин, max 2 връзки, rate limit (да се свери с upstream anti-bruteforce). |
| 6 | `006-session-indicator` | A8 | Видима индикация + прекратяване. |
| 7 | `007-hide-all-settings` | L1–L3, §5 | Вкл. превключвателите в CM за block-input/privacy и др.; about/privacy линковете към rustdesk.com; панел „Отдалечено управление“ и история/любими/адресна книга в QS. |
| 8 | `008-close-equals-exit` | F3 | Затваряне = край на процеса (без tray). |
| 9 | `009-no-install` | F1, F2 | Добавен 2026-10-26: банер „Инсталирай“, install/service пътища; „Повиши права“. |

`007` покрива и панела „Отдалечено управление“ + историята на сесиите в QS (QS е само контролиран). Общ `common/040-random-device-id` (F5) — 2026-10-26.

Отворените UI точки за QuickSupport от `PHASE1-common.md` §6 вече имат патч: банерът „Инсталирай“ → 009, панелът „Отдалечено управление“ и историята → 007.

### 3.3 Работен цикъл за всеки патч (както във Фаза 1)

Картографиране → генериране от копия на pin-а (с предходните патчове, които пипат същите файлове) → `Apply-Patches` за двата продукта → `cargo check` (14 предупреждения от upstream, без нови) → build + проверка (мрежа/лог; визуално — от потребителя) → `Reset-Vanilla -Force` → docs + commit → secret scan → push след одобрение. Подробно: `PHASE1-common.md` §1 и §5.

### 3.4 Може да се направи паралелно / по-късно

- `scripts/Build-Product.ps1` (Reset → Apply → Build, вкл. връщане на `pubspec.lock` и външно пренасочване на изхода).
- Skill `patch-workflow` (процесът от §3.3 е вече установен — може да се опише като skill).
- Превод на новите съобщения за грешка; скриване на менютата TCP tunneling/RDP/Terminal/View camera в агента (Фаза 5).

## 4. Claude Code skills + hooks

**Направени (2026-10-25):** skill `rustdesk-build` (`.claude/skills/rustdesk-build/`) и guard hook (`.claude/settings.json` → `.claude/hooks/guard-rustdesk-source.ps1`): Edit/Write в `rustdesk-source/` → **deny**; `cargo clean` и деструктивни git команди към `rustdesk-source/` → **ask**. Важат само за сесии, отворени в `C:\src\ApisSupport`. Ограничение: hook-ът не вижда запис във файл през shell и git команди вътре в скриптове — скриптовете са одобреният път.

Собствени, малки, в git — без непрегледани чужди пакети (supply-chain / prompt-injection риск за инструмент за отдалечен достъп).

| Какво | Тип | Състояние | Защо |
|---|---|---|---|
| `rustdesk-build` | skill | ✅ | Build стъпките + капаните от `PHASE0-baseline.md` |
| Забрана за директни Edit/Write в `rustdesk-source/` | hook | ✅ | Налага „само през патчове" |
| Блок на `cargo clean` и деструктивни git команди в `rustdesk-source/` | hook | ✅ | Пази `target/` кеша и чистотата на source-а |
| `patch-workflow` | skill | предстои | Процесът от §3.3 |
| `session-handoff` | skill | предстои | В края на сесия: обнови този файл + commit |
| `security-check` | skill | предстои | Чеклист срещу REQUIREMENTS (A1, N3, P1–P15) — патч да не отваря премахнат код-път |

Принцип: skill е насока (може да се пропусне); това, което **не бива** да се случи, се налага с hook.

## 5. Важни напомняния

- `rustdesk-source/` се пипа САМО през патчове; `rustdesk-source/target/` е кеш — без `cargo clean` без одобрение.
- Тайните (сървър/ключ) не влизат в repo — винаги през `secrets.json`; в docs и отговори адресът се маскира.
- Commit след всяка успешна стъпка (restore точки); push — след одобрение. UI текстове на български; код/commits на английски.
- Проектът е легитимен (виж `REQUIREMENTS.md` раздели 0 и 10): поддръжка със съгласие, без unattended. Формулирай работата конкретно и технически.

## 6. Среда (напомняне)

- `$env:VCPKG_ROOT = 'C:\src\ApisSupport\vcpkg'`, `$env:VCPKG_DEFAULT_HOST_TRIPLET = 'x64-windows-static'`, `$env:LIBCLANG_PATH = 'C:\Program Files\LLVM\bin'` (build скриптът ги задава сам).
- Windows / PowerShell 5.1. Build е тежък (минути) — пускай във фон, с пренасочване на изхода **отвън** (`powershell -File ... > log 2>&1`).
