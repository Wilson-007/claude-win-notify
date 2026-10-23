# claude-win-notify

Windows toast notifications for [Claude Code](https://claude.com/claude-code), so you can work in other windows and still get alerted when:

1. **Claude needs a permission confirmation** (the yes/no prompt)
2. **Claude finishes a task**

It also distinguishes between multiple concurrent sessions/windows (task A/B/C) by showing a friendly name and a short session code on each toast.

Uses the built-in [BurntToast](https://github.com/Windos/BurntToast) PowerShell module — no admin rights, no background service.

## Features

- **Two triggers** — `Notification` (permission prompt) and `Stop` (task done).
- **Multi-session aware** — each session registers its own name via `SessionStart`; toasts show that name plus a short session id.
- **Friendly names** — launch with `claude --name MyTask` and toasts show `MyTask`; otherwise falls back to the directory name.
- **Non-destructive install** — merges hooks into `~/.claude/settings.json` without touching your other settings.
- **Idempotent** — safe to run the installer multiple times.

## Requirements

- Windows 10/11
- PowerShell 5.1+ (preinstalled on Windows)
- Claude Code CLI

## Install

### Option A — one-liner (no clone)

```powershell
irm https://raw.githubusercontent.com/Wilson-007/claude-win-notify/main/install.ps1 | iex
```

### Option B — clone and run

```powershell
git clone https://github.com/Wilson-007/claude-win-notify.git
cd claude-win-notify
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The installer:

1. Installs the BurntToast module (current-user scope) if missing.
2. Copies `session-register.ps1` and `toast.ps1` into `~/.claude/` (as UTF-8 with BOM — required for Chinese text on PowerShell 5.1).
3. Registers three hooks in `~/.claude/settings.json`:
   - `SessionStart` → `session-register.ps1`
   - `Notification` (matcher `permission_prompt`) → `toast.ps1`
   - `Stop` → `toast.ps1`

After installing, **restart Claude Code** (or open `/hooks` once) to load the new hooks.

## Usage

To get friendly toast titles, launch sessions with a name:

```powershell
claude --name MyTask
```

Without `--name`, toasts fall back to the working directory name.

## Test it

Verify the hooks work without a real session:

```powershell
powershell -ExecutionPolicy Bypass -File .\test\simulate.ps1
```

You should see two "needs confirmation" toasts and one "done" toast.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Removes the three hooks from `settings.json` and deletes the two scripts. (Your `~/.claude/session-map/` cache is left in place; delete it manually if you like.)

## How it works

| Hook event | Script | Effect |
|-----------|--------|--------|
| `SessionStart` | `session-register.ps1` | Writes `{title, cwd}` to `~/.claude/session-map/<session_id>.json` |
| `Notification` (`permission_prompt`) | `toast.ps1` | Fires a "needs confirmation" toast |
| `Stop` | `toast.ps1` | Fires a "done" toast |

`toast.ps1` looks up the friendly name from `session-map` by session id, falls back to the directory name, and appends a 6-char session code so you can tell concurrent windows apart.

## Troubleshooting

- **Chinese shows as `????` / mojibake** — the hook scripts must be UTF-8 *with BOM* on PowerShell 5.1. The installer already writes them correctly; only relevant if you edit them by hand.
- **Hooks don't fire after install** — restart Claude Code or open `/hooks` once. Hooks added to `settings.json` mid-session aren't picked up until reload.
- **BurntToast install fails (PSGallery missing)** — run `Register-PSRepository -Default` then retry, or `Install-Module BurntToast -Scope CurrentUser -Force`.

## Project layout

```
claude-win-notify/
├── README.md
├── LICENSE
├── install.ps1          # one-click installer
├── uninstall.ps1        # removes hooks + scripts
├── src/
│   ├── session-register.ps1
│   └── toast.ps1
└── test/
    └── simulate.ps1     # manual verification without a real session
```

## License

MIT — see [LICENSE](LICENSE).
