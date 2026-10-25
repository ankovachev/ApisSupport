# Фаза 0 — Baseline build на vanilla RustDesk 1.5.0

**Дата:** 2026-10-25
**Резултат:** ✅ Успешен — vanilla source компилира чисто, приложението стартира и UI-то се рендерира.

## Source

- RustDesk `fada664df7a294d1d1a9ca3e7cd3637069122f17` (tag 1.5.0), hbb_common `229b904508364c8997aad0fb5af57effac859f60`.
- Без нито един патч. Единствената tracked промяна след build е `flutter/pubspec.lock` (виж „Капани" №3).

## Toolchain (проверен)

| Инструмент | Версия | Upstream CI pin | Бележка |
|---|---|---|---|
| Rust | 1.93.1 stable-msvc | 1.75 | 1.75 в CI е заради sciter; Flutter build-ът минава и с текущия stable |
| Flutter / Dart | 3.24.5 / 3.5.4 | 3.24.5 | ✅ |
| flutter_rust_bridge_codegen | 1.80.1 (`--features uuid`) | 1.80.1 | беше 1.80.0 — преинсталиран |
| cargo-expand | 1.0.127 | 1.0.95 | нужен на FRB v1 |
| Python | 3.12.10 (winget, user scope) | — | преди беше само Store stub-ът |
| CMake | от VS 2022 BuildTools | — | не е нужен в PATH — Flutter го намира през VS |
| LLVM / clang | 21.1.8 | 15.0.6 | `LIBCLANG_PATH=C:\Program Files\LLVM\bin` |
| vcpkg | `9e593bb` (= CI baseline) | `9e593bb` | **проектен**: `C:\src\ApisSupport\vcpkg` (gitignored) |

Всичко проектно е под `C:\src\ApisSupport`. Старите папки в `C:\src` (стари проби) не се ползват.

## Стъпки (повторяеми)

Автоматизирани в `scripts/Build-Baseline.ps1` (`-InstallDeps` за първоначален `vcpkg install`). Ръчно:

```powershell
$env:VCPKG_ROOT = 'C:\src\ApisSupport\vcpkg'
$env:VCPKG_DEFAULT_HOST_TRIPLET = 'x64-windows-static'
$env:LIBCLANG_PATH = 'C:\Program Files\LLVM\bin'

# 1. vcpkg (еднократно, ~40 мин): от rustdesk-source/, manifest mode
& "$env:VCPKG_ROOT\vcpkg.exe" install --triplet x64-windows-static --x-install-root="$env:VCPKG_ROOT\installed"

# 2. pub get -> bridge codegen (без --class-name)
cd rustdesk-source\flutter; flutter pub get; cd ..
flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h

# 3. build (както Windows CI)
python build.py --portable --flutter --skip-portable-pack --hwcodec
```

**Време:** cargo 7.5 мин + flutter 2.75 мин ≈ 12.5 мин (студен `target/`). 14 warnings (snake_case, unused imports), без грешки.

**Изход:** `rustdesk-source/flutter/build/windows/x64/runner/Release/` — `rustdesk.exe` + `librustdesk.dll` (~39 MB) + плъгини.

## Капани (открити при baseline-а)

1. **`VCPKG_DEFAULT_HOST_TRIPLET=x64-windows-static` е задължителен.** ffmpeg е `host: true` с условие `static` в `vcpkg.json`; без него vcpkg тихо пропуска ffmpeg (avcodec/avformat/avutil) и `hwcodec` няма да линкне.
2. **pub `PackageGraph` null check.** Първият `flutter pub get` даде непълен `package_config.json` (липсваше `screen_retriever`, зависимост на git пакета `window_manager`), заради което `build_runner` (и FRB codegen) падаха с `Null check operator used on a null value`. Решение: връщане на `pubspec.lock` към upstream и повторен `flutter pub get` — след това графът е пълен и codegen минава.
3. **`pubspec.lock` се променя неизбежно.** Upstream lock-ът е генериран с по-нов Flutter; 3.24.5 downgrade-ва 16 SDK-pinned пакета (async, matcher, test_api…). CI-то на upstream прави същото. `Reset-Vanilla.ps1` трябва да връща този файл (`git checkout -- flutter/pubspec.lock`).
4. Генерираните bridge файлове (`src/bridge_generated*.rs`, `flutter/lib/generated_bridge*.dart`, `bridge_generated.h`) са gitignored от upstream — source-ът остава чист.

## Smoke тест

- Стартиране на `rustdesk.exe` → процес отговаря, прозорец „RustDesk", ~125 MB RAM.
- UI: vanilla начален екран (ID, временна парола, „Control Remote Desktop", UAC/Install банер) — без branding, както се очаква.
- Лог: само безобидни за baseline грешки — printer service init, IPv6 STUN (няма IPv6 мрежа), „server not started" (няма инсталиран service).
- Странична бележка: vanilla build-ът ползва `%APPDATA%\RustDesk` (същото APP_NAME като стандартния RustDesk) и презаписва runtime кеша (`rendezvous_server`, `local-ip-addr`). Конфигурацията беше архивирана преди теста и възстановена след него. Потвърждава нуждата от `001-app-name` (C1).

## Следваща стъпка

Фаза 1 — `common/` патчове (виж `ARCHITECTURE.md` §6.1) + scripts (`Reset-Vanilla`, `Apply-Patches`, `Build-Product`), които автоматизират стъпките по-горе.
