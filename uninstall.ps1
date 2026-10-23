# Claude Code Windows toast notifications - uninstaller
#
# Removes the SessionStart / Notification / Stop hooks added by install.ps1,
# and deletes the two hook scripts + SnoreToast.exe + the branded Start Menu shortcut.

$ErrorActionPreference = "Stop"

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$settingsPath = Join-Path $claudeDir 'settings.json'

# Remove any hook in $EventName whose command points at our scripts.
function Remove-HookFromEvent($Settings, [string]$EventName) {
    if (-not $Settings -or -not ($Settings.PSObject.Properties.Name -contains 'hooks') -or $null -eq $Settings.hooks) { return }
    $hooks = $Settings.hooks
    if (-not ($hooks.PSObject.Properties.Name -contains $EventName) -or $null -eq $hooks.$EventName) { return }

    $kept = @()
    foreach ($g in @($hooks.$EventName)) {
        if ($g -and $g.hooks) {
            $keptHooks = @($g.hooks) | Where-Object { $_.command -and ($_.command -notmatch 'session-register\.ps1|toast\.ps1') }
            if ($keptHooks.Count -gt 0) {
                $g.hooks = @($keptHooks)
                $kept += $g
            }
        }
    }
    if ($kept.Count -eq 0) {
        $hooks.PSObject.Properties.Remove($EventName)
    } else {
        $hooks.$EventName = $kept
    }
}

if (Test-Path $settingsPath) {
    $raw = [System.IO.File]::ReadAllText($settingsPath)
    $Settings = $null
    if ($raw -and $raw.Trim()) { $Settings = $raw | ConvertFrom-Json }

    if ($null -ne $Settings) {
        Remove-HookFromEvent $Settings 'SessionStart'
        Remove-HookFromEvent $Settings 'Notification'
        Remove-HookFromEvent $Settings 'Stop'

        $outJson = $Settings | ConvertTo-Json -Depth 30
        [System.IO.File]::WriteAllText($settingsPath, $outJson, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "Removed our hooks from settings.json" -ForegroundColor Green
    }
} else {
    Write-Host "settings.json not found, nothing to clean." -ForegroundColor Yellow
}

foreach ($f in @('session-register.ps1', 'toast.ps1', 'SnoreToast.exe')) {
    $p = Join-Path $claudeDir $f
    if (Test-Path $p) {
        Remove-Item $p -Force
        Write-Host "Removed $p"
    }
}

# Remove the branded Start Menu shortcut registered by toast.ps1 (app identity).
$shortcut = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Claude Code\Claude Code.lnk'
if (Test-Path $shortcut) {
    Remove-Item $shortcut -Force
    Write-Host "Removed $shortcut"
}

Write-Host "Done. (You may also delete ~/.claude/session-map to clear cached session names.)" -ForegroundColor Cyan
