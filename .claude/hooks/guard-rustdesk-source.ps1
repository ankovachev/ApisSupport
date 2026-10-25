# PreToolUse guard for rustdesk-source/ (see CLAUDE.md "Do not touch").
#  - Edit/Write/NotebookEdit on a file under rustdesk-source/      -> deny (changes go through patches only)
#  - cargo clean                                                   -> ask (target/ is a ~10 min build cache)
#  - destructive git command aimed at rustdesk-source/             -> ask
# Reviewed scripts (scripts/*.ps1) are the approved path for resets; their inner git calls are not visible here.

$ErrorActionPreference = 'Stop'

$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
$payload = $raw | ConvertFrom-Json
$tool = $payload.tool_name
$toolInput = $payload.tool_input

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot 'rustdesk-source')).TrimEnd('\') + '\'

function Write-Decision([string]$decision, [string]$reason) {
    $out = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = $decision
            permissionDecisionReason = $reason
        }
    }
    $out | ConvertTo-Json -Compress -Depth 4
    exit 0
}

function Test-UnderSource([string]$path) {
    if (-not $path) { return $false }
    try { $full = [IO.Path]::GetFullPath(($path -replace '/', '\')) } catch { return $false }
    return ($full + '\').StartsWith($sourceRoot, [StringComparison]::OrdinalIgnoreCase)
}

if ($tool -in @('Edit', 'Write', 'NotebookEdit', 'MultiEdit')) {
    $path = $toolInput.file_path
    if (-not $path) { $path = $toolInput.notebook_path }
    if (Test-UnderSource $path) {
        Write-Decision 'deny' "rustdesk-source/ must stay bit-identical to upstream: express this change as a .patch under patches/ (CLAUDE.md 'Do not touch'). Blocked: $path"
    }
    exit 0
}

if ($tool -in @('Bash', 'PowerShell')) {
    $cmd = [string]$toolInput.command
    if (-not $cmd) { exit 0 }

    if ($cmd -match '(?i)\bcargo\s+(\+\S+\s+)?clean\b') {
        Write-Decision 'ask' 'cargo clean wipes rustdesk-source/target (a ~10 min build cache). CLAUDE.md requires explicit user approval.'
    }

    $targetsSource = ($cmd -match '(?i)rustdesk-source') -or (Test-UnderSource ([string]$payload.cwd))
    $destructiveGit = '(?i)\bgit\b[^;|&\r\n]*\s(' +
        'reset\s+--hard|clean\s+-\S*[fdx]|checkout\s+(--|\.|-f)|restore\b|stash\b|rebase\b|' +
        'push\s+[^;|&\r\n]*(--force|-f\b)|branch\s+-D|submodule\s+(deinit|update\s+[^;|&\r\n]*--force)|' +
        'rm\b|switch\s+[^;|&\r\n]*(--discard-changes|-f\b)|update-ref\s+-d|gc\s+--prune)'
    if ($targetsSource -and $cmd -match $destructiveGit) {
        Write-Decision 'ask' "Destructive git command on rustdesk-source/ ('$($Matches[1])'). CLAUDE.md requires user confirmation; prefer scripts/Reset-Vanilla.ps1 once it exists."
    }
}

exit 0
