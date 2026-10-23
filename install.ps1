# Claude Code Windows toast notifications - installer
#
# Installs SnoreToast.exe + two hook scripts, and registers SessionStart /
# Notification(permission_prompt) / Stop hooks in ~/.claude/settings.json
# without touching your other settings. Safe to run multiple times.
#
# Usage (clone + run):
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# Usage (one-liner, no clone):
#   irm https://raw.githubusercontent.com/Wilson-007/claude-win-notify/main/install.ps1 | iex

# --- CONFIG: point this at your fork (keep if you are the upstream repo) ---
$RepoRawBase = "https://raw.githubusercontent.com/Wilson-007/claude-win-notify/main"

$ErrorActionPreference = "Stop"

# Make sure we can reach github over TLS 1.2
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# 1. Platform checks
if ($env:OS -ne "Windows_NT") {
    Write-Host "ERROR: This tool only supports Windows." -ForegroundColor Red
    exit 1
}
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "ERROR: PowerShell 5.1 or newer is required." -ForegroundColor Red
    exit 1
}

$claudeDir = Join-Path $env:USERPROFILE '.claude'

# Resolve script source: local src/ when run from a clone, else remote raw.
# Downloads as bytes and decodes UTF-8 explicitly to avoid mojibake.
function Get-ScriptContent([string]$Name) {
    if ($PSScriptRoot) {
        $local = Join-Path $PSScriptRoot ("src\" + $Name)
        if (Test-Path $local) {
            return [System.IO.File]::ReadAllText($local)
        }
    }
    $url = "$RepoRawBase/src/$Name"
    $wc = New-Object System.Net.WebClient
    $bytes = $wc.DownloadData($url)
    return [System.Text.Encoding]::UTF8.GetString($bytes)
}

function Get-SnoreToastExe([string]$Dst) {
    if ($PSScriptRoot) {
        $local = Join-Path $PSScriptRoot "src\SnoreToast.exe"
        if (Test-Path $local) {
            [System.IO.File]::Copy($local, $Dst, $true)
            return
        }
    }
    $url = "$RepoRawBase/src/SnoreToast.exe"
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($url, $Dst)
}

# 2. Write SnoreToast.exe to ~/.claude (bundled toast binary, no PSGallery needed)
Write-Host "[1/4] Writing SnoreToast.exe..." -ForegroundColor Cyan
$snoreToastDst = Join-Path $claudeDir 'SnoreToast.exe'
if (Test-Path $snoreToastDst) {
    Write-Host "  SnoreToast.exe already present."
} else {
    Get-SnoreToastExe $snoreToastDst
    Write-Host "  -> $snoreToastDst"
}

# 3. Write hook scripts to ~/.claude (UTF-8 WITH BOM - required by PS 5.1 for Chinese text)
Write-Host "[2/4] Writing hook scripts..." -ForegroundColor Cyan
$registerDst = Join-Path $claudeDir 'session-register.ps1'
$toastDst    = Join-Path $claudeDir 'toast.ps1'
$ntfyDst     = Join-Path $claudeDir 'ntfy-push.ps1'
[System.IO.File]::WriteAllText($registerDst, (Get-ScriptContent 'session-register.ps1'), (New-Object System.Text.UTF8Encoding($true)))
[System.IO.File]::WriteAllText($toastDst,    (Get-ScriptContent 'toast.ps1'),             (New-Object System.Text.UTF8Encoding($true)))
[System.IO.File]::WriteAllText($ntfyDst,     (Get-ScriptContent 'ntfy-push.ps1'),         (New-Object System.Text.UTF8Encoding($true)))
Write-Host "  -> $registerDst"
Write-Host "  -> $toastDst"
Write-Host "  -> $ntfyDst"

# ntfy.json placeholder: topic empty = remote push disabled. Only write if missing
# so a reinstall never overwrites an existing topic/token.
$ntfyCfg = Join-Path $claudeDir 'ntfy.json'
if (-not (Test-Path $ntfyCfg)) {
    [System.IO.File]::WriteAllText($ntfyCfg, '{"server":"https://ntfy.sh","topic":"","token":""}', (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "  -> $ntfyCfg (set `"topic`" to enable phone push)"
}

# 4. Merge hooks into settings.json (non-destructive, idempotent)
Write-Host "[3/4] Registering hooks in settings.json..." -ForegroundColor Cyan

function Add-HookToEvent($Settings, [string]$EventName, [string]$Matcher, [string]$Command) {
    if (-not ($Settings.PSObject.Properties.Name -contains 'hooks') -or $null -eq $Settings.hooks) {
        $Settings | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{}) -Force
    }
    $hooks = $Settings.hooks
    if (-not ($hooks.PSObject.Properties.Name -contains $EventName) -or $null -eq $hooks.$EventName) {
        $hooks | Add-Member -MemberType NoteProperty -Name $EventName -Value @() -Force
    }
    # idempotent: skip if this exact command is already registered
    foreach ($g in @($hooks.$EventName)) {
        if ($g -and $g.hooks) {
            foreach ($h in @($g.hooks)) {
                if ($h -and $h.command -eq $Command) { return }
            }
        }
    }
    if ($Matcher) {
        $group = [pscustomobject]@{ matcher = $Matcher; hooks = @([pscustomobject]@{ type = 'command'; command = $Command }) }
    } else {
        $group = [pscustomobject]@{ hooks = @([pscustomobject]@{ type = 'command'; command = $Command }) }
    }
    $hooks.$EventName = @($hooks.$EventName) + @($group)
}

$settingsPath = Join-Path $claudeDir 'settings.json'
$Settings = [pscustomobject]@{}
if (Test-Path $settingsPath) {
    $raw = [System.IO.File]::ReadAllText($settingsPath)
    if ($raw -and $raw.Trim()) {
        $Settings = $raw | ConvertFrom-Json
        if ($null -eq $Settings) { $Settings = [pscustomobject]@{} }
    }
}

$registerCmd = 'powershell -NoProfile -File "' + $registerDst + '"'
$toastCmd    = 'powershell -NoProfile -File "' + $toastDst + '"'
$ntfyCmd     = 'powershell -NoProfile -File "' + $ntfyDst + '"'

Add-HookToEvent $Settings 'SessionStart' '' $registerCmd
Add-HookToEvent $Settings 'Notification' 'permission_prompt' $toastCmd
Add-HookToEvent $Settings 'Stop' '' $toastCmd
Add-HookToEvent $Settings 'Notification' 'permission_prompt' $ntfyCmd
Add-HookToEvent $Settings 'Stop' '' $ntfyCmd

$outJson = $Settings | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($settingsPath, $outJson, (New-Object System.Text.UTF8Encoding($false)))

# 5. Done
Write-Host "[4/4] Done!" -ForegroundColor Green
Write-Host ""
Write-Host "  Hooks registered. To apply them:"
Write-Host "    - restart Claude Code, or"
Write-Host "    - open /hooks once to reload config"
Write-Host ""
Write-Host "  Optional: launch sessions with --name for friendly toast titles:"
Write-Host "    claude --name MyTask"
Write-Host ""
Write-Host "  Optional: phone push via ntfy.sh:"
Write-Host "    edit ~/.claude/ntfy.json and set `"topic`" to your topic"
Write-Host ""
Write-Host "  To remove: run uninstall.ps1"
