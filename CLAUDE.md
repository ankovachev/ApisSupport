# CLAUDE.md — ApisSupport

> Контекст за AI асистенти, работещи по това repo. Прочети това първо.
> Това е самостоятелен проект. Няма препратки към други/външни repos.

## Обзор

ApisSupport произвежда два брандирани продукта от един чист RustDesk source чрез config-driven patch система:

- **ApisQuickSupport** — инструмент за клиента (контролиран, само със съгласие, без unattended).
- **ApisAgent** — инструмент за дилъра (контролиращ, с OTP).

Каноничните спецификации са [`REQUIREMENTS.md`](REQUIREMENTS.md) и [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — те надделяват над всяко устно допускане.

## Основен принцип

Чистият `rustdesk-source/` остава бит-идентичен с upstream. Всички промени са `.patch` файлове + JSON конфиг + нови файлове. Rebuild от нова версия — под 30 минути.

## Pin на source-а

- RustDesk: tag **1.5.0**, commit `fada664df7a294d1d1a9ca3e7cd3637069122f17`
- hbb_common submodule: `229b904508364c8997aad0fb5af57effac859f60`
- Клониран shallow (grafted) в `rustdesk-source/` (gitignored).

При upgrade: нов pin + re-test на всички патчове с `git apply --check`.

## Структура

```
ApisSupport/
├── REQUIREMENTS.md            # Заключени изисквания
├── CLAUDE.md                  # Този файл
├── README.md
├── docs/                      # ARCHITECTURE, PHASES, SECURITY, PACKAGING
├── configs/                   # quicksupport.json, agent.json (единствен източник на истина)
├── patches/                   # common/ quicksupport/ agent/ new-files/
├── assets/                    # лого, икони
├── scripts/                   # Reset-Vanilla, Apply-Patches, Build-Product, Pack-Portable, Sign-Binary
├── builds/                    # изход (gitignored)
└── rustdesk-source/           # чист RustDesk 1.5.0 (gitignored)
```

## Сървър (hardcode)

- Rendezvous адрес, API и публичен ключ: **не са в repo-то** — идват от `configs/secrets.json` (gitignored) при build. Шаблон: `configs/secrets.example.json`.
- Override на сървъра (env/CLI/config) е блокиран (anti-social-engineering).
- P2P по подразбиране + relay fallback само през own server.

## Критични build предпоставки (RustDesk Flutter)

1. `flutter_rust_bridge_codegen` ПРЕДИ `cargo build`.
2. Codegen **без** `--class-name` флаг.
3. `flutter pub get` ПРЕДИ codegen.
4. `python3.bat` shim (за portable packer).
5. Уникален APP_NAME за изолация (ApisQuickSupport / ApisAgent).
6. `VCPKG_ROOT` зададен преди build.

## Заключени ключови решения

- Unattended достъп — ЗАБРАНЕН by design (не е настройка).
- Клиентът избира ниво на достъп при съгласие (само гледане / пълен контрол).
- Max 2 едновременни връзки.
- Език: форсиран български; Тема: светла, forced.
- Отпечатък: пълна виртуализация (Enigma VB) — нищо не се пише на диск/registry; нов device ID всеки път.
- Съвместимост с инсталиран RustDesk: чрез APP_NAME изолация (не смяна на портове).
- Code signing на крайния exe.

## Не пипай

- `rustdesk-source/` файлове директно — само през патчове.
- `rustdesk-source/target/` build кеш — без `cargo clean` без изрично одобрение.
- Деструктивни git операции върху `rustdesk-source/` без потвърждение.

## Работен стил

1. Каноничните docs надделяват над допускания.
2. Commit след всяка успешна стъпка + проверка (restore точки).
3. Проверявай на кой branch си преди значими промени.
4. Питай преди деструктивни операции.
5. При несигурност — спри и питай, не гадай.
6. Код/коментари/commits на английски; UI текстове на български.
