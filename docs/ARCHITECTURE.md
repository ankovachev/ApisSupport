# Архитектурен план — Apis Remote Support

**Версия:** 0.2 (чернова за преглед)
**Дата:** 2026-10-25
**Основа:** REQUIREMENTS.md v1.1 (заключен)
**Статус:** За преглед — НЕ пишем код, докато не бъде одобрен

**Заключени решения (този прочит):**
- Име на repo: **ApisSupport** (ново, самостоятелно; без връзка със стари repos)
- Source версия: **най-новата стабилна RustDesk** (точен tag + SHA се фиксират при setup)
- Асиметрия на агента: **потвърдена** — агентът само инициира връзки, не приема (не е контролиран)

---

## 1. Водещ архитектурен принцип

**Patch-overlay върху чист source.** Оригиналният RustDesk source остава **бит-идентичен** с upstream. Всички Apis промени се изразяват като:
- `.patch` файлове (прилагани с `git apply`),
- нови файлове (копирани върху source-а),
- JSON конфиг (единствен източник на истина за стойности).

**Защо точно така:**
- Rebuild от нова версия на RustDesk за <30 мин — просто re-pin + re-apply.
- Чистотата на source-а прави промените прозрачни и одитируеми (важно и за легитимността).
- Един source → два продукта (QuickSupport + Agent) чрез различни набори патчове.

Това е утвърден подход за поддръжка на дълготрайни форкове.

---

## 2. Структура на repo-то

```
ApisSupport/                      # ново, самостоятелно repo
├── CLAUDE.md                     # Контекст за AI асистенти (без препратки към стари repos)
├── README.md
├── REQUIREMENTS.md               # Заключените изисквания (v1.1)
├── docs/
│   ├── ARCHITECTURE.md           # Този документ
│   ├── PHASES.md                 # Фазов план
│   ├── SECURITY.md               # Спецификация на hardening-а
│   ├── PACKAGING.md              # Enigma виртуализация + code signing
│   └── assets/                   # Reference screenshots
├── configs/
│   ├── quicksupport.json         # Brand + security конфиг (клиент)
│   └── agent.json                # Brand + security конфиг (агент)
├── patches/
│   ├── common/                   # Прилагат се и за двата продукта
│   ├── quicksupport/             # Само за клиента
│   ├── agent/                    # Само за агента
│   └── new-files/                # Копирани файлове (икони, shim-ове)
├── assets/                       # Изходни лого/икони
├── scripts/
│   ├── Reset-Vanilla.ps1         # Връщане на source към чист pinned state
│   ├── Apply-Patches.ps1         # Прилага патчове + JSON substitution
│   ├── Build-Product.ps1         # Build per продукт
│   ├── Pack-Portable.ps1         # Enigma Virtual Box → еднофайлов exe
│   └── Sign-Binary.ps1           # Code signing
├── builds/                       # Изход (gitignored)
└── rustdesk-source/              # Чист RustDesk (gitignored, ~5GB)
    └── libs/hbb_common/          # Git submodule
```

Какво влиза в git: всичко освен `builds/` и `rustdesk-source/`. Source-ът е голям и се възстановява от pin — не се пази в нашето repo.

---

## 3. Стратегия за source-а

| Аспект | Решение |
|---|---|
| Версия | **Най-новата стабилна RustDesk** към момента на setup; фиксира се точен release tag + commit SHA. |
| hbb_common | Git submodule. **НЕ форкваме.** Патчваме checked-out копието след `submodule update` (промените са малки, ~50-100 реда). |
| Чистота | `Reset-Vanilla.ps1` връща source-а към точния pin + `submodule update --force`. След него `Apply-Patches.ps1` дава напълно патчнато състояние. |
| Upgrade | Нова версия = нов pin + re-test на всички патчове с `git apply --check`. |

---

## 4. Config-driven модел (JSON = единствен източник на истина)

`configs/<product>.json` държи всички стойности, които се различават между продукти или могат да се променят: APP_NAME, server, key, feature flags, security defaults, лимити.

`Apply-Patches.ps1` чете JSON и **замества placeholder токени** (`{{APP_NAME}}`, `{{SERVER}}`, `{{PUBLIC_KEY}}` …) в патчовете, преди да ги приложи. Така една и съща патч-логика ражда два различни продукта без дублиране.

**Предимство:** добавяне на трети продукт или смяна на тестов сървър = нов JSON, не нови патчове.

---

## 5. Асиметрия на двата продукта (важно за дизайна)

| | ApisQuickSupport (клиент) | ApisAgent (дилър) |
|---|---|---|
| Роля | **Контролиран** (приема връзки със съгласие) | **Контролиращ** (инициира връзки) |
| Основна тежест | Тежък security hardening + consent модел | Branding + OTP + локализация |
| Unattended | Забранен by design (A1) | N/A (не приема връзки) |
| UI | Само ID + статус + terms (без connect панел) | Connect панел (локализиран на BG) |

> **Потвърдено:** агентът само инициира връзки и не приема (не е контролиран).

---

## 6. Карта: изискване → механизъм

### 6.1 Общи патчове (`common/`) — за двата продукта

| Патч (планиран) | Изисквания | Какво прави |
|---|---|---|
| `001-server-config` | N1, N2 | Вгражда сървър + public key + API endpoint (от `configs/secrets.json`) в `hbb_common/config.rs` |
| `002-block-server-override` | N3 | Игнорира env/CLI/config override на сървъра |
| `003-relay-policy` | N4 | P2P по подразбиране + relay fallback само през own server |
| `010-force-bulgarian` | B2 | Език = bg, без picker, без switcher |
| `011-light-theme-forced` | B6 | Светла тема, заключена |
| `020-strip-rustdesk-strings` | B4 | Премахва „RustDesk" / „Powered by RustDesk" надписи |
| `030-remove-lan-discovery` | P9 | Маха UDP broadcast |
| `031-remove-direct-ip-tunneling` | P10 | Маха direct-IP + TCP tunneling код-пътища |
| `032-remove-plugin-system` | P8 | Маха зареждане на plugins |
| `033-remove-camera` | P5 | Маха camera access |
| `034-remove-block-input` | P6 | Маха block-input |
| `035-remove-privacy-mode` | P7 | Маха privacy mode |
| `036-disable-auto-update-telemetry` | P11 | Auto-update, telemetry, crash reports off |
| `037-security-defaults` | P1-P4, P12 | file transfer/clipboard/audio/recording/IPv6 off |
| `038-logging-hardening` | P13 | Ниско ниво, кратка retention, redaction |

### 6.2 QuickSupport патчове (`quicksupport/`)

| Патч (планиран) | Изисквания | Какво прави |
|---|---|---|
| `001-app-name` | C1 | APP_NAME = `ApisQuickSupport` (изолация) |
| `002-disable-unattended` | A1 | Премахва permanent password / unattended код-път изцяло |
| `003-consent-access-level` | A2, A9 | Popup за съгласие с избор „Само гледане" / „Пълен контрол" |
| `004-no-connection-password` | A3 | Без парола за връзка |
| `005-connection-limits` | A4, A5, A6, A7 | Prompt timeout 60s, idle 15min, max 2 връзки, rate-limit |
| `006-session-indicator` | A8 | Видима индикация за активна сесия + прекратяване |
| `007-hide-all-settings` | L1, L2, L3 | Скрива настройки; enforcement на ниво код |
| `008-close-equals-exit` | F3 | X = пълно спиране (override на minimize-to-tray) |
| `010-branding-home` | B1, B3, B5 | Header, центрирано лого, terms-of-use панел (текст от Приложение А) |

### 6.3 Agent патчове (`agent/`)

| Патч (планиран) | Изисквания | Какво прави |
|---|---|---|
| `001-app-name` | C1 | APP_NAME = `ApisAgent` (изолация) |
| `002-otp-auth` | S2, J2 | OTP автентикация за дилъра |
| `010-branding-agent` | B1 | Header „Интерфейс за дилъри", лого |
| `011-localize-connect-panel` | B2 | Connect панел на български |
| `012-close-equals-exit` | F3 | X = пълно спиране |

### 6.4 Нови файлове (`new-files/`)

- Икони/лого: `app_icon.ico`, `res/icon.png`, всички размери.
- `python3.bat` shim (нужен за packer-а).
- Евентуално exe metadata ресурс (version info, product name).

### 6.5 Build / packaging стъпки (не патчове)

| Механизъм | Изисквания | Къде |
|---|---|---|
| Enigma Virtual Box виртуализация | F1, F2, F5, F6 | `Pack-Portable.ps1` — виртуализира `%APPDATA%`/registry → нищо не се пише; нов ID всеки път (няма persisted config) |
| Code signing | D3 | `Sign-Binary.ps1` — `signtool` с наличния сертификат |
| Еднофайлов exe | F4 | Изход на Enigma packer-а |

> **Важна бележка за F5 (нов ID):** при пълна виртуализация `%APPDATA%` е sandbox-нат и се изхвърля при изход, затова device ID не персистира → нов при всяко стартиране **по природа**, без да е нужен отделен патч. Ще се валидира, не се приема наум.

---

## 7. Build pipeline

```
Reset-Vanilla.ps1 -Force          # чист source на точния pin
   ↓
Apply-Patches.ps1 -Product X      # common/ + <product>/ патчове + JSON substitution + new-files overlay
   ↓
Build-Product.ps1 -Product X      # frb codegen → flutter pub get → cargo build → flutter build
   ↓
Pack-Portable.ps1 -Product X      # Enigma Virtual Box → еднофайлов, виртуализиран exe
   ↓
Sign-Binary.ps1 -Product X        # подпис с сертификата
   ↓
builds/<product>/ApisXxx.exe      # готов, подписан, преносим
```

**Критични build предпоставки (за RustDesk Flutter builds):**
1. `flutter_rust_bridge_codegen` ПРЕДИ `cargo build` (иначе не компилира).
2. Codegen **без** `--class-name` флаг.
3. `flutter pub get` ПРЕДИ codegen.
4. `python3.bat` shim за packer-а.
5. Уникален APP_NAME за изолация.
6. `VCPKG_ROOT` зададен преди build.

---

## 8. Фази на изпълнение (ред за намаляване на риска)

| Фаза | Съдържание | Изход |
|---|---|---|
| 0 | Setup: ново repo, скелет, scripts, pin на source, baseline build на vanilla | Чист компилируем vanilla |
| 1 | `common/` патчове (server, език, тема, hardening) + wire тест | Обща защитена основа |
| 2 | QuickSupport патчове (app-name, consent+access-level, limits, hide-settings, close=exit) | Функционален клиент |
| 3 | QuickSupport branding (header, лого, terms) по Приложение А | Брандиран клиент |
| 4 | Packaging: Enigma виртуализация + подпис + E2E тест на 2 машини | Production-ready QS |
| 5 | Agent: app-name, OTP, branding, локализация | Функционален агент |
| 6 | Agent packaging + подпис + E2E | Production-ready Agent |
| 7 | Финална валидация, coexistence тест, документация, ретроспектива | Завършен проект |

**Принцип:** всяка фаза завършва с проверим критерий и commit. Security патчовете се тестват с **реална връзка между две машини**, не само визуално.

---

## 9. Рискови зони (да ги следим)

1. **Unattended премахване (A1)** — трябва да е структурно (премахнат код-път), не само default. Най-важният security патч; изисква внимателен wire тест.
2. **Enigma виртуализация** — да се валидира, че наистина нищо не стига до `%APPDATA%`/registry (не просто „изглежда чисто").
3. **1.4.9 vs по-нова версия** — upstream може вече да е покрил част от anti-bruteforce/audit; да се свери, за да не дублираме или конфликтираме.
4. **Agent OTP** — реализация срещу connection кода на pinned версията; изисква внимателен дизайн и тест.
5. **frb codegen нюанси** — известни капани (виж предпоставки); нови 1.4.9 модули може да дадат безобидни warnings.

---

## 10. Какво следва след одобрение на този план

1. Създаване на новото (частно) repo.
2. Клониране на RustDesk на pinned версия в `rustdesk-source/`.
3. Setup на скелета (scripts, configs, CLAUDE.md) — Фаза 0.
4. Baseline build на vanilla (проверка, че компилира, преди каквито и да е патчове).

*Този документ е жив. След одобрение се пренася в новото repo като `docs/ARCHITECTURE.md`.*
