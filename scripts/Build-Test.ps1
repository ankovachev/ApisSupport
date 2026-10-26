<#
.SYNOPSIS
    Builds test copies of the products into builds\test\<name>\.

.DESCRIPTION
    For each product: Reset-Vanilla -Force -> Apply-Patches -> Build-Baseline -> copy the
    Release folder to builds\test\<product><Suffix>\ (so a second build does not overwrite the
    first). Ends with Reset-Vanilla -Force.

    -TestLimits and -LogLevel change configs/quicksupport.json only for Apply-Patches and
    restore it in a finally block, so test values never stay in configs/. If a run is
    interrupted anyway, check `git status` for configs/ before committing.

    Run with the output redirected from outside (PowerShell 5.1 `*>` fails):
        powershell -NoProfile -File scripts\Build-Test.ps1 > build.log 2>&1

.PARAMETER Product
    One or both of quicksupport, agent.
.PARAMETER TestLimits
    QuickSupport with idle 1 min and 1 connection (quicksupport/005).
.PARAMETER LogLevel
    Override logging.level for QuickSupport (e.g. info for a diagnostic build).
.PARAMETER Suffix
    Appended to the output folder name, e.g. -diag.
#>
param(
    [ValidateSet('quicksupport', 'agent')][string[]]$Product = @('quicksupport', 'agent'),
    [switch]$TestLimits,
    [ValidateSet('error', 'warn', 'info', 'debug', 'trace')][string]$LogLevel,
    [string]$Suffix = ''
)

$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\Common.ps1"

$release = Join-Path $Source 'flutter\build\windows\x64\runner\Release'
$cfg = Join-Path $RepoRoot 'configs\quicksupport.json'
$utf8 = New-Object System.Text.UTF8Encoding $false

foreach ($p in $Product) {
    Write-Output "##### $p"
    & "$PSScriptRoot\Reset-Vanilla.ps1" -Force | Out-Null
    $override = $p -eq 'quicksupport' -and ($TestLimits -or $LogLevel)
    if ($override) {
        $orig = [IO.File]::ReadAllText($cfg)
        $test = $orig
        if ($TestLimits) {
            $test = $test.Replace('"idle_disconnect_minutes": 30,', '"idle_disconnect_minutes": 1,').Replace('"max_simultaneous_connections": 2,', '"max_simultaneous_connections": 1,')
        }
        if ($LogLevel) { $test = [regex]::Replace($test, '"level": "[a-z]+"', "`"level`": `"$LogLevel`"") }
        if ($test -eq $orig) { Write-Output 'CONFIG OVERRIDE NOT APPLIED'; exit 1 }
        [IO.File]::WriteAllText($cfg, $test, $utf8)
        try { & "$PSScriptRoot\Apply-Patches.ps1" -Product $p | Select-Object -Last 1 }
        finally { [IO.File]::WriteAllText($cfg, $orig, $utf8) }
        Write-Output "config override (TestLimits=$TestLimits LogLevel=$LogLevel) applied and restored"
    } else {
        & "$PSScriptRoot\Apply-Patches.ps1" -Product $p | Select-Object -Last 1
    }
    & powershell -NoProfile -File "$PSScriptRoot\Build-Baseline.ps1"
    if ($LASTEXITCODE) { Write-Output "BUILD FAILED: $p"; exit 1 }
    $dst = Join-Path $RepoRoot "builds\test\$p$Suffix"
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Copy-Item $release $dst -Recurse
    Write-Output "copied to $dst"
}
& "$PSScriptRoot\Reset-Vanilla.ps1" -Force | Select-Object -Last 1
