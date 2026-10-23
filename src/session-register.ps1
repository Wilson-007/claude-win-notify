# Session Register - SessionStart Hook
# 把会话 title + cwd 写入 ~/.claude/session-map/<session_id>.json，供 toast.ps1 显示友好名字
# Hook stdin: {"session_id":"...","cwd":"...","session_title":"..."}

param(
    [string]$session_id = $env:CLAUDE_SESSION_ID,
    [string]$cwd = $env:CLAUDE_CWD
)

if (-not $cwd) { $cwd = (Get-Location).Path }

$title = ""

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
            if ($stdinInput.session_title) { $title = $stdinInput.session_title }
        }
    }
} catch { }

if (-not $session_id) { exit 0 }

$mapDir = Join-Path $env:USERPROFILE '.claude\session-map'
if (-not (Test-Path $mapDir)) {
    New-Item -ItemType Directory -Force -Path $mapDir | Out-Null
}

$entry = @{
    title = $title
    cwd   = $cwd
}

$mapFile = Join-Path $mapDir ($session_id + '.json')
try {
    $json = $entry | ConvertTo-Json -Compress
    [System.IO.File]::WriteAllText($mapFile, $json, (New-Object System.Text.UTF8Encoding($false)))
} catch { }
