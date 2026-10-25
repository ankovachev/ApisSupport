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
- Открито: API заявката към нашия сървър пада в rustls с `InvalidCertificate(UnknownIssuer)` → проверка на сертификата/веригата на сървъра (N2).
- Капан: `Build-Baseline.ps1` с `*>` пренасочване в PowerShell 5.1 пада (stderr на cargo → грешка при `ErrorActionPreference=Stop`); пренасочвай отвън (`powershell -File ... > log 2>&1`).

## 3. Следваща стъпка (започни оттук)

**Фаза 1, продължение** (виж картата в `ARCHITECTURE.md` §6.1): `010-force-bulgarian`, после light-theme, strip-rustdesk-strings, security hardening.

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
