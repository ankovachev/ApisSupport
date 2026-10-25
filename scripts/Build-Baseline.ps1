<#
.SYNOPSIS
    Builds vanilla (unpatched) RustDesk from rustdesk-source/, mirroring the upstream Windows CI.

.DESCRIPTION
    Steps: [vcpkg install] -> flutter pub get -> bridge codegen -> build.py.
    See docs/PHASE0-baseline.md for toolchain versions and known pitfalls.
    Leaves flutter/pubspec.lock modified (expected with Flutter 3.24.5).

.PARAMETER InstallDeps
    Run `vcpkg install` first (one-time, ~40 min on a cold vcpkg).
#>
param(
    [switch]$InstallDeps
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $RepoRoot 'rustdesk-source'

$env:VCPKG_ROOT = Join-Path $RepoRoot 'vcpkg'
# Without a static host triplet vcpkg silently skips ffmpeg (host:true + static in vcpkg.json).
$env:VCPKG_DEFAULT_HOST_TRIPLET = 'x64-windows-static'
$env:VCPKG_DISABLE_METRICS = '1'
$env:LIBCLANG_PATH = 'C:\Program Files\LLVM\bin'
$Python = Join-Path $env:LOCALAPPDATA 'Programs\Python\Python312'
$env:Path = "$Python;$Python\Scripts;$env:Path"

function Invoke-Step([string]$Name, [scriptblock]$Block) {
    Write-Host "=== $Name" -ForegroundColor Cyan
    & $Block
    if ($LASTEXITCODE -ne 0) { throw "$Name failed (exit $LASTEXITCODE)" }
}

if (-not (Test-Path "$env:VCPKG_ROOT\vcpkg.exe")) { throw "vcpkg not found at $env:VCPKG_ROOT" }

$sw = [Diagnostics.Stopwatch]::StartNew()
Push-Location $Source
try {
    if ($InstallDeps) {
        Invoke-Step 'vcpkg install' {
            & "$env:VCPKG_ROOT\vcpkg.exe" install --triplet x64-windows-static --x-install-root="$env:VCPKG_ROOT\installed"
        }
    }

    Invoke-Step 'flutter pub get' { Push-Location flutter; try { flutter pub get } finally { Pop-Location } }

    # No --class-name flag (build prerequisite #2).
    Invoke-Step 'bridge codegen' {
        flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs --dart-output ./flutter/lib/generated_bridge.dart --c-output ./flutter/macos/Runner/bridge_generated.h
    }

    Invoke-Step 'build.py' { python build.py --portable --flutter --skip-portable-pack --hwcodec }
}
finally {
    Pop-Location
}

Write-Host "=== Done in $($sw.Elapsed)" -ForegroundColor Green
Write-Host "Output: $Source\flutter\build\windows\x64\runner\Release\rustdesk.exe"
