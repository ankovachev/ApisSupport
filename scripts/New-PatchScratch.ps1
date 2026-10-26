<#
.SYNOPSIS
    Prepares scratch git repos for writing a new patch.

.DESCRIPTION
    Copies the given files from the pin (byte-exact, via `git show`) into <Dir>\main and
    <Dir>\hbb, commits them as "pin", applies the token-form patches of common/ (and of
    -Product) that touch those files, and commits that as "base". Edit the files there,
    then `git -C <Dir>\main diff > patches\...\NNN-name.patch` (cmd redirection: PowerShell
    5.1 `>` writes UTF-16).

    The patches are applied unsubstituted, so no secret from secrets.json can end up in the
    context lines of a new patch.

.PARAMETER Dir
    Scratch directory (recreated).
.PARAMETER MainFiles
    Paths relative to rustdesk-source/.
.PARAMETER HbbFiles
    Paths relative to rustdesk-source/libs/hbb_common.
.PARAMETER Product
    quicksupport, agent, or none (base = common patches only, for a new common patch).
#>
param(
    [Parameter(Mandatory)][string]$Dir,
    [string[]]$MainFiles = @(),
    [string[]]$HbbFiles = @(),
    [ValidateSet('quicksupport', 'agent', 'none')][string]$Product = 'quicksupport'
)

# Git writes CRLF warnings to stderr; exit codes are checked instead.
$ErrorActionPreference = 'Continue'
. "$PSScriptRoot\Common.ps1"

if (Test-Path $Dir) { Remove-Item $Dir -Recurse -Force }
$groups = @('common') + @(if ($Product -ne 'none') { $Product })
$patches = $groups | ForEach-Object { Get-ChildItem (Join-Path $RepoRoot "patches\$_") -Filter *.patch -File | Sort-Object Name }

$sets = @(
    @{ Name = 'main'; Src = $Source; Files = $MainFiles; Hbb = $false },
    @{ Name = 'hbb'; Src = $HbbCommon; Files = $HbbFiles; Hbb = $true }
)
foreach ($s in $sets) {
    if (-not $s.Files) { continue }
    $d = Join-Path $Dir $s.Name
    foreach ($f in $s.Files) {
        $out = Join-Path $d $f
        New-Item -ItemType Directory (Split-Path $out) -Force | Out-Null
        cmd /c "git -C `"$($s.Src)`" show HEAD:$f > `"$out`""
        if ($LASTEXITCODE) { throw "git show HEAD:$f failed" }
    }
    git -C $d init -q
    git -C $d config core.autocrlf false
    git -C $d add -A
    git -C $d -c user.name=scratch -c user.email=scratch@localhost commit -qm pin
    foreach ($p in $patches) {
        if (($p.Name -like '*.hbb_common.patch') -ne $s.Hbb) { continue }
        # A list, not an array literal: a single-element array would be splatted per character.
        $applyArgs = [System.Collections.Generic.List[string]]::new()
        $applyArgs.Add('apply')
        foreach ($f in $s.Files) {
            if (Select-String -Path $p.FullName -SimpleMatch "diff --git a/$f " -Quiet) { $applyArgs.Add("--include=$f") }
        }
        if ($applyArgs.Count -eq 1) { continue }
        $applyArgs.Add($p.FullName)
        & git -C $d @applyArgs
        if ($LASTEXITCODE) { throw "apply failed: $($p.Directory.Name)/$($p.Name)" }
        Write-Host "$($s.Name): $($p.Directory.Name)/$($p.Name)"
    }
    git -C $d add -A
    git -C $d -c user.name=scratch -c user.email=scratch@localhost commit -qm base --allow-empty
}
