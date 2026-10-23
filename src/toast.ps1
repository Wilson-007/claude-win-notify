# Toast - Notification / Stop Hook
# 弹系统 toast：标签优先用友好名字(~/.claude/session-map/<session_id>.json 的 title)，否则用目录名，并带 session 短码，用于区分多窗口
# Notification stdin: {"session_id":"...","cwd":"...","hook_event_name":"Notification",...}
# Stop stdin:        {"session_id":"...","cwd":"...","hook_event_name":"Stop",...}

param(
    [string]$session_id = $env:CLAUDE_SESSION_ID,
    [string]$cwd = $env:CLAUDE_CWD
)

if (-not $cwd) { $cwd = (Get-Location).Path }

$event = ""

try {
    if ([Console]::IsInputRedirected) {
        $in = [Console]::OpenStandardInput()
        $ms = New-Object System.IO.MemoryStream
        $in.CopyTo($ms)
        $stdinRaw = ([System.Text.Encoding]::UTF8.GetString($ms.ToArray())).TrimStart([char]0xFEFF)
        if ($stdinRaw) {
            $stdinInput = $stdinRaw | ConvertFrom-Json
            if ($stdinInput.session_id) { $session_id = $stdinInput.session_id }
            if ($stdinInput.cwd) { $cwd = $stdinInput.cwd }
            if ($stdinInput.hook_event_name) { $event = $stdinInput.hook_event_name }
        }
    }
} catch { }

if (-not $session_id) { exit 0 }

if ($session_id.Length -ge 6) { $shortId = $session_id.Substring(0, 6) } else { $shortId = $session_id }

$label = ""
try {
    $mapDir = Join-Path $env:USERPROFILE '.claude\session-map'
    $mapFile = Join-Path $mapDir ($session_id + '.json')
    if (Test-Path $mapFile) {
        $m = [System.IO.File]::ReadAllText($mapFile) | ConvertFrom-Json
        if ($m.title) { $label = $m.title }
    }
} catch { }

if (-not $label) {
    $label = Split-Path $cwd -Leaf
    if (-not $label) { $label = $cwd }
}

if ($event -eq "Stop") {
    $title = "$label · 已完成"
    $body  = "任务跑完了  (session $shortId)"
} else {
    $title = "$label · 需要确认"
    $body  = "请回终端选择 yes/no  (session $shortId)"
}

Import-Module BurntToast -ErrorAction SilentlyContinue
try {
    New-BurntToastNotification -Text $title, $body -ErrorAction Stop
} catch { }
