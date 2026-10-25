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

**Още няма:** написани scripts, нито един патч, нито baseline build.

## 3. Следваща стъпка (започни оттук)

**Baseline build на vanilla RustDesk 1.5.0** — преди какъвто и да е патч, за да потвърдим, че средата компилира чисто.

1. Провери toolchain: Rust, Flutter, CMake, Python, `flutter_rust_bridge_codegen`, `VCPKG_ROOT`.
2. Build на `rustdesk-source/` без промени (спазвай 6-те build предпоставки от `CLAUDE.md`).
3. Smoke: стартира ли, UI се ли показва (vanilla, без branding — очаквано).
4. Запиши резултата в `docs/PHASE0-baseline.md` + commit.

След успешен baseline → **Фаза 1: `common/` патчове** (виж картата в `ARCHITECTURE.md` §6.1): server-config (от `secrets.json`), block-server-override, relay policy, force-bulgarian, light-theme, strip-rustdesk-strings, security hardening.

## 4. Важни напомняния

- `rustdesk-source/` се пипа САМО през патчове; `rustdesk-source/target/` е кеш — без `cargo clean` без одобрение.
- Тайните (сървър/ключ) не влизат в repo — винаги през `secrets.json`.
- Commit след всяка успешна стъпка (restore точки). UI текстове на български; код/commits на английски.
- Проектът е легитимен (виж `REQUIREMENTS.md` раздели 0 и 10): поддръжка със съгласие, без unattended. Формулирай работата конкретно и технически.

## 5. Среда (напомняне)

- `$env:VCPKG_ROOT` трябва да е зададен преди build.
- Windows / PowerShell. Build е тежък (минути) — пускай във фон при нужда.
