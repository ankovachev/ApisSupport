<#
.SYNOPSIS
    Applies the Apis patch set for one product on top of a vanilla rustdesk-source/.

.DESCRIPTION
    1. Requires a vanilla source at the pin (run Reset-Vanilla.ps1 -Force first).
    2. Substitutes {{TOKEN}} placeholders from configs/<product>.json + configs/secrets.json
       into copies under builds/patches/<product>/ (secrets never land in patches/).
    3. Applies patches/common/*.patch, then patches/<product>/*.patch, in name order.
       *.hbb_common.patch files are applied inside libs/hbb_common (separate git repo).
    4. Copies patches/new-files/ over the source tree.

    Each patch is checked with `git apply --check` right before it is applied; the first
    failure stops the run. Reset-Vanilla.ps1 -Force undoes a partial apply.

.PARAMETER Product
    quicksupport or agent.
#>
param(
    [Parameter(Mandatory)][ValidateSet('quicksupport', 'agent')][string]$Product
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Common.ps1"

function Read-Json([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Missing $Path" }
    Get-Content $Path -Raw -Encoding utf8 | ConvertFrom-Json
}

Assert-Pin
$changes = Get-SourceChanges
if ($changes) { throw "rustdesk-source is not vanilla (run Reset-Vanilla.ps1 -Force):`n$($changes -join "`n")" }

$config = Read-Json (Join-Path $RepoRoot "configs\$Product.json")
$secrets = Read-Json (Join-Path $RepoRoot 'configs\secrets.json')
if ($secrets.server.rendezvous -match 'example\.com' -or $secrets.server.public_key -eq 'BASE64_PUBLIC_KEY_HERE') {
    throw 'configs/secrets.json still holds template values from secrets.example.json'
}

$tokens = [ordered]@{
    APP_NAME   = $config.branding.app_name
    SERVER     = $secrets.server.rendezvous
    API_SERVER = $secrets.server.api
    PUBLIC_KEY = $secrets.server.public_key
}
foreach ($t in $tokens.GetEnumerator()) {
    if ([string]::IsNullOrWhiteSpace($t.Value)) { throw "Token {{$($t.Key)}} has no value in the configs" }
}

$patches = @('common', $Product) | ForEach-Object {
    Get-ChildItem (Join-Path $RepoRoot "patches\$_") -Filter *.patch -File | Sort-Object Name
}

$staging = Join-Path $RepoRoot "builds\patches\$Product"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory $staging | Out-Null

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
foreach ($p in $patches) {
    $text = [IO.File]::ReadAllText($p.FullName)
    foreach ($t in $tokens.GetEnumerator()) { $text = $text.Replace("{{$($t.Key)}}", $t.Value) }
    $unresolved = [regex]::Matches($text, '\{\{[A-Z0-9_]+\}\}') | ForEach-Object Value | Sort-Object -Unique
    if ($unresolved) { throw "$($p.Directory.Name)/$($p.Name): unknown token(s) $($unresolved -join ', ')" }

    $target = if ($p.Name -like '*.hbb_common.patch') { $HbbCommon } else { $Source }
    $out = Join-Path $staging "$($p.Directory.Name)-$($p.Name)"
    [IO.File]::WriteAllText($out, $text, $utf8NoBom)

    Write-Host "=== $($p.Directory.Name)/$($p.Name)" -ForegroundColor Cyan
    Invoke-Git $target apply --check $out | Out-Null
    Invoke-Git $target apply $out | Out-Null
}

$newFiles = Join-Path $RepoRoot 'patches\new-files'
$overlay = Get-ChildItem $newFiles -Recurse -File | Where-Object Name -ne '.gitkeep'
foreach ($f in $overlay) {
    $rel = $f.FullName.Substring($newFiles.Length + 1)
    $dest = Join-Path $Source $rel
    New-Item -ItemType Directory (Split-Path $dest) -Force | Out-Null
    Copy-Item $f.FullName $dest -Force
    Write-Host "=== new-files/$rel" -ForegroundColor Cyan
}

Write-Host "=== Applied $(@($patches).Count) patch(es), $(@($overlay).Count) new file(s) for $Product" -ForegroundColor Green
