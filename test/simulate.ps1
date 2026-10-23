# Simulate SessionStart + Notification + Stop events to verify the hooks work
# without a real Claude Code session. Run after install.ps1:
#   powershell -ExecutionPolicy Bypass -File .\test\simulate.ps1

param(
    [string]$SessionId = "demo-abc123",
    [string]$Title = "任务A",
    [string]$Cwd = "C:\Users\Public"
)

$claudeDir = Join-Path $env:USERPROFILE '.claude'
$register = Join-Path $claudeDir 'session-register.ps1'
$toast    = Join-Path $claudeDir 'toast.ps1'

if (-not (Test-Path $register) -or -not (Test-Path $toast)) {
    Write-Host "Hook scripts not found. Run install.ps1 first." -ForegroundColor Red
    exit 1
}

# Deliver JSON via redirected stdin. We write raw bytes and close the base
# stream (not the StreamWriter) to avoid a stray UTF-8 BOM from the parent.
function Invoke-Hook([string]$Script, [string]$Json) {
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo.FileName = "powershell.exe"
    $p.StartInfo.Arguments = "-NoProfile -File `"$Script`""
    $p.StartInfo.RedirectStandardInput = $true
    $p.StartInfo.UseShellExecute = $false
    $p.StartInfo.CreateNoWindow = $true
    $p.Start() | Out-Null
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.BaseStream.Flush()
    $p.StandardInput.BaseStream.Close()
    $p.WaitForExit()
}

# 1. SessionStart -> writes ~/.claude/session-map/<session_id>.json
$registerJson = @{
    session_id     = $SessionId
    cwd            = $Cwd
    hook_event_name = 'SessionStart'
    session_title  = $Title
} | ConvertTo-Json -Compress
Invoke-Hook $register $registerJson
Start-Sleep -Milliseconds 500

# 2. Two permission prompts
$notifJson = @{
    session_id        = $SessionId
    cwd               = $Cwd
    hook_event_name   = 'Notification'
    notification_type = 'permission_prompt'
    message           = 'needs permission to use Bash'
} | ConvertTo-Json -Compress
Invoke-Hook $toast $notifJson
Start-Sleep -Milliseconds 900
Invoke-Hook $toast $notifJson
Start-Sleep -Milliseconds 900

# 3. Stop
$stopJson = @{
    session_id       = $SessionId
    cwd              = $Cwd
    hook_event_name  = 'Stop'
    stop_hook_active = $true
} | ConvertTo-Json -Compress
Invoke-Hook $toast $stopJson

Write-Host "Simulation finished. Expected: 2 permission toasts + 1 completion toast, titled with `"$Title`"."
