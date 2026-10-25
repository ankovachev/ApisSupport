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

**Още няма:** написани scripts, нито един патч.

## 3. Следваща стъпка (започни оттук)

**Фаза 1: `common/` патчове** (виж картата в `ARCHITECTURE.md` §6.1): server-config (от `secrets.json`), block-server-override, relay policy, force-bulgarian, light-theme, strip-rustdesk-strings, security hardening.

Заедно с първите патчове — scripts `Reset-Vanilla` / `Apply-Patches` / `Build-Product`, автоматизиращи стъпките от `PHASE0-baseline.md` (вкл. връщане на `flutter/pubspec.lock`). Отправна точка: `scripts/Build-Baseline.ps1` (vanilla build, както CI).

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
