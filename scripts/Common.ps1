# Shared constants and helpers for the build scripts. Dot-source: . "$PSScriptRoot\Common.ps1"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $RepoRoot 'rustdesk-source'
$HbbCommon = Join-Path $Source 'libs\hbb_common'

# Source pin (RustDesk 1.5.0). Keep in sync with CLAUDE.md.
$PinCommit = 'fada664df7a294d1d1a9ca3e7cd3637069122f17'
$HbbCommonCommit = '229b904508364c8997aad0fb5af57effac859f60'

function Invoke-Git {
    param([string]$Repo, [Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)
    $out = & git -C $Repo @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "git -C $Repo $($GitArgs -join ' ') failed (exit $LASTEXITCODE)" }
    $out
}

function Assert-Pin {
    $head = Invoke-Git $Source rev-parse HEAD
    if ($head -ne $PinCommit) { throw "rustdesk-source HEAD is $head, expected pin $PinCommit" }
    $hbb = Invoke-Git $HbbCommon rev-parse HEAD
    if ($hbb -ne $HbbCommonCommit) { throw "hbb_common HEAD is $hbb, expected pin $HbbCommonCommit (run Reset-Vanilla.ps1 -Force)" }
}

# Returns `git status --porcelain` lines for the source and its hbb_common submodule.
function Get-SourceChanges {
    @(Invoke-Git $Source status --porcelain --ignore-submodules=all) +
    @(Invoke-Git $HbbCommon status --porcelain) | Where-Object { $_ }
}
