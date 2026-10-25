---
name: rustdesk-build
description: Build RustDesk from rustdesk-source/ on Windows (vanilla baseline or patched product) — toolchain check, project-local vcpkg, flutter pub get, flutter_rust_bridge codegen, build.py, smoke test. Use whenever building, rebuilding, or debugging a failed build of ApisSupport / RustDesk, or when vcpkg, codegen, build_runner or pubspec.lock problems come up.
---

# RustDesk build (ApisSupport)

Canonical reference: `docs/PHASE0-baseline.md` (versions, timings, pitfalls). Automated: `scripts/Build-Baseline.ps1`.
Everything lives under `C:\src\ApisSupport`. Never use folders outside it (old experiments in `C:\src\rustdesk` etc.).

## 1. Toolchain (verify before building)

| Tool | Expected |
|---|---|
| Flutter / Dart | 3.24.5 / 3.5.4 |
| Rust | stable msvc (1.93.1 works; CI pins 1.75 only for sciter) |
| flutter_rust_bridge_codegen | **1.80.1** (`cargo install ... --version 1.80.1 --features uuid --locked`) |
| cargo-expand | installed |
| Python | 3.12 in `%LOCALAPPDATA%\Programs\Python\Python312` (the WindowsApps `python.exe` is a Store stub) |
| CMake | from VS 2022 BuildTools (not on PATH — fine) |
| LLVM | `LIBCLANG_PATH=C:\Program Files\LLVM\bin` |
| vcpkg | `C:\src\ApisSupport\vcpkg` at `9e593bb` (= upstream CI baseline) |

## 2. Environment (every shell — PowerShell state does not persist between tool calls)

```powershell
$env:VCPKG_ROOT = 'C:\src\ApisSupport\vcpkg'
$env:VCPKG_DEFAULT_HOST_TRIPLET = 'x64-windows-static'
$env:LIBCLANG_PATH = 'C:\Program Files\LLVM\bin'
$env:Path = "$env:LOCALAPPDATA\Programs\Python\Python312;$env:Path"
```

## 3. Steps (order matters)

1. **vcpkg deps** (one-time, ~40 min, run in background): from `rustdesk-source/`
   `& "$env:VCPKG_ROOT\vcpkg.exe" install --triplet x64-windows-static --x-install-root="$env:VCPKG_ROOT\installed"`
   Verify `installed\x64-windows-static\lib` has `avcodec.lib`, `vpx.lib`, `yuv.lib`, `opus.lib`, `aom.lib`.
2. `flutter pub get` in `rustdesk-source/flutter` — **before** codegen.
3. Codegen from `rustdesk-source/`, **no `--class-name`**:
   `flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h`
4. Build: `python build.py --portable --flutter --skip-portable-pack --hwcodec` (~12.5 min cold; run in background, log to scratchpad).
5. Output: `rustdesk-source/flutter/build/windows/x64/runner/Release/rustdesk.exe` + `librustdesk.dll`.

Or simply: `powershell -File scripts/Build-Baseline.ps1` (add `-InstallDeps` for step 1).

## 4. Known pitfalls

- **ffmpeg missing / hwcodec link errors** → `VCPKG_DEFAULT_HOST_TRIPLET` was not set during `vcpkg install`. Re-run step 1 with it (already-built ports are reused).
- **`Null check operator used on a null value` in `PackageGraph`** (build_runner or FRB codegen) → `package_config.json` is incomplete (seen: `screen_retriever` missing). Restore `flutter/pubspec.lock` to upstream and re-run `flutter pub get`. Restoring the lock is a destructive git op on `rustdesk-source/` → ask the user first (a hook enforces this).
- **`flutter/pubspec.lock` shows as modified** after pub get → expected (Flutter 3.24.5 downgrades ~16 SDK-pinned packages; upstream CI does the same). Reset must restore it.
- Generated bridge files are gitignored upstream — they never dirty the source.
- Benign build output: ~14 Rust warnings (snake_case `mod pt_PT`, unused imports).

## 5. Smoke test

- An unpatched (vanilla) build uses APP_NAME `RustDesk` → shares `%APPDATA%\RustDesk` with any other RustDesk on the machine and rewrites `rendezvous_server` / `local-ip-addr`. **Back up `%APPDATA%\RustDesk\config` before launching and restore after.**
- Launch, wait ~15 s, check: process responding, window title, log `%APPDATA%\RustDesk\log\rustdesk_rCURRENT.log`.
- Benign log errors: printer service init, IPv6 STUN (no IPv6), "server not started" (no service installed).
- Close the app (CloseMainWindow, then Stop-Process if it lingers in tray). Screenshots show ID + one-time password — keep them out of git (`builds/` is gitignored).

## 6. Rules

- Never edit `rustdesk-source/` directly — only via patches (hook-enforced).
- Never `cargo clean` without explicit approval — `target/` is a ~10 min cache (hook asks).
- After a successful build step: record results in docs and commit (restore points).
