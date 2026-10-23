# ntfy-push - Remote Push Hook (optional)
# 把"需要确认/已完成"推送到 ntfy.sh（手机 App 接收）。
# 配置 ~/.claude/ntfy.json: {"server":"https://ntfy.sh","topic":"","token":""}
# topic 为空则静默退出（即关闭此通道）；推送失败不报错、不影响本地 toast。
# stdin 同 toast.ps1: {"session_id":"...","cwd":"...","hook_event_name":"Notification|Stop"}

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

# 读配置；topic 为空则关闭本通道
$server = "https://ntfy.sh"
$topic  = ""
$token  = ""
try {
    $cfgFile = Join-Path $env:USERPROFILE '.claude\ntfy.json'
    if (Test-Path $cfgFile) {
        $cfg = [System.IO.File]::ReadAllText($cfgFile) | ConvertFrom-Json
        if ($cfg.server) { $server = $cfg.server }
        if ($cfg.topic)  { $topic  = $cfg.topic }
        if ($cfg.token)  { $token  = $cfg.token }
    }
} catch { }

if (-not $topic) { exit 0 }

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
    $title = "已完成 · $label"
    $msg   = "任务跑完了  (session $shortId)"
    $prio  = "default"
} else {
    $title = "需要确认 · $label"
    $msg   = "请回终端选择 yes/no  (session $shortId)"
    $prio  = "high"
}

try {
    $body = $title + "`n" + $msg
    $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $headers = @{ 'Title' = 'Claude Code'; 'Priority' = $prio }
    if ($token) { $headers["Authorization"] = "Bearer $token" }
    $uri = $server.TrimEnd('/') + '/' + [uri]::EscapeDataString($topic)
    Invoke-RestMethod -Uri $uri -Method Post -Body $bodyBytes -ContentType 'text/plain; charset=utf-8' -Headers $headers -TimeoutSec 10 *> $null
} catch { }
