<#
.SYNOPSIS
    Returns rustdesk-source/ (and its hbb_common submodule) to the clean pinned state.

.DESCRIPTION
    Without -Force: dry run, only lists what would be reverted or removed.
    With -Force: reverts tracked files (incl. flutter/pubspec.lock), restores the submodule
    to its pinned commit and removes untracked files.

    Ignored files are kept (`git clean` without -x), so target/ and other build caches survive.
    The source HEAD itself is never moved; a HEAD off the pin is an error to resolve by hand.

.PARAMETER Force
    Actually perform the reset (destructive for local edits in rustdesk-source/).
#>
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

$head = Invoke-Git $Source rev-parse HEAD
if ($head -ne $PinCommit) { throw "rustdesk-source HEAD is $head, expected pin $PinCommit; fix manually" }

$hbbHead = Invoke-Git $HbbCommon rev-parse HEAD
$changes = Get-SourceChanges
$untracked = @(Invoke-Git $Source clean -nd) + @(Invoke-Git $HbbCommon clean -nd) | Where-Object { $_ }

if (-not $Force) {
    Write-Host "Dry run (use -Force to apply)." -ForegroundColor Yellow
    if ($hbbHead -ne $HbbCommonCommit) { Write-Host "hbb_common at $hbbHead -> would reset to $HbbCommonCommit" }
    if ($changes) { Write-Host "Would revert:"; $changes | ForEach-Object { Write-Host "  $_" } }
    if ($untracked) { Write-Host "Untracked:"; $untracked | ForEach-Object { Write-Host "  $_" } }
    if ($hbbHead -eq $HbbCommonCommit -and -not $changes -and -not $untracked) { Write-Host "Already vanilla." -ForegroundColor Green }
    return
}

Write-Host "=== Resetting rustdesk-source to $PinCommit" -ForegroundColor Cyan
Invoke-Git $Source reset --hard --quiet HEAD | Out-Null
Invoke-Git $Source clean -fd --quiet | Out-Null
# --force discards local edits inside the submodule as well.
Invoke-Git $Source submodule update --init --force --quiet libs/hbb_common | Out-Null
Invoke-Git $HbbCommon clean -fd --quiet | Out-Null

Assert-Pin
$left = Get-SourceChanges
if ($left) { throw "Source still not clean after reset:`n$($left -join "`n")" }
Write-Host "=== rustdesk-source is vanilla" -ForegroundColor Green
