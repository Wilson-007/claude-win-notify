# claude-win-notify

Windows toast notifications for [Claude Code](https://claude.com/claude-code), so you can work in other windows and still get alerted when:

1. **Claude needs a permission confirmation** (the yes/no prompt)
2. **Claude finishes a task**

It also distinguishes between multiple concurrent sessions/windows (task A/B/C) by showing a friendly name and a short session code on each toast.

Uses the bundled [SnoreToast](https://github.com/KDE/snoretoast) executable — no admin rights, no background service, no PowerShell module install.

## Features

- **Two triggers** — `Notification` (permission prompt) and `Stop` (task done).
- **Multi-session aware** — each session registers its own name via `SessionStart`; toasts show that name plus a short session id.
- **Friendly names** — launch with `claude --name MyTask` and toasts show `MyTask`; otherwise falls back to the directory name.
- **Optional phone push** — mirror each toast to your phone via [ntfy.sh](https://ntfy.sh) (open-source, self-hostable, no account needed).
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

1. Copies the bundled `SnoreToast.exe` toast binary into `~/.claude/` (no PSGallery / module install needed).
2. Copies `session-register.ps1`, `toast.ps1`, and `ntfy-push.ps1` into `~/.claude/` (as UTF-8 with BOM — required for Chinese text on PowerShell 5.1).
3. Writes a `~/.claude/ntfy.json` placeholder (topic empty = phone push off) if it doesn't already exist.
4. Registers hooks in `~/.claude/settings.json`:
   - `SessionStart` → `session-register.ps1`
   - `Notification` (matcher `permission_prompt`) → `toast.ps1` + `ntfy-push.ps1`
   - `Stop` → `toast.ps1` + `ntfy-push.ps1`

After installing, **restart Claude Code** (or open `/hooks` once) to load the new hooks.

### Option C — Claude Code plugin

Bundles `SnoreToast.exe` inside the plugin — no separate install needed. Then:

```powershell
claude plugin marketplace add Wilson-007/claude-win-notify
claude plugin install claude-win-notify@claude-win-notify
```

Or in one step (Claude Code v2.1.292+):

```powershell
claude plugin install claude-win-notify --marketplace Wilson-007/claude-win-notify
```

The plugin registers the same three hooks, but runs the scripts bundled inside the plugin (`${CLAUDE_PLUGIN_ROOT}/src/*.ps1`) instead of copying them to `~/.claude/`. The `SnoreToast.exe` binary ships alongside `toast.ps1` in the plugin's `src/` directory, so no BurntToast module is required.

Uninstall with `/plugin uninstall claude-win-notify`.

## Usage

To get friendly toast titles, launch sessions with a name:

```powershell
claude --name MyTask
```

Without `--name`, toasts fall back to the working directory name.

## Remote push (optional)

Mirror the local toasts to your phone via [ntfy.sh](https://ntfy.sh) — an open-source pub/sub service you can also self-host. No account, no WeChat, no third-party SDK.

1. Install the ntfy app on your phone ([Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) / [iOS](https://apps.apple.com/us/app/ntfy/id1625396347)) and subscribe to a topic of your choice, e.g. `my-claude-tasks`.
2. Edit `~/.claude/ntfy.json`:
   ```json
   {
     "server": "https://ntfy.sh",
     "topic": "my-claude-tasks",
     "token": ""
   }
   ```
   - `server` — `https://ntfy.sh` for the public server, or your own instance's URL.
   - `topic` — the topic your phone is subscribed to. Pick something hard to guess; anyone who knows it can read your notifications.
   - `token` — optional, for private topics / self-hosted servers that require auth.
3. On the phone, make sure notifications actually reach the system tray (not just inside the app):
   - In the ntfy app, open the topic's settings and enable **Instant delivery**. Without it the app only receives messages while it's open in the foreground.
   - Grant the app **notification permission**, and set its **battery** to *Unrestricted* (not "Optimized"). On some phones (Xiaomi/OPPO/Huawei) also enable **Auto-start**, otherwise the background connection gets killed.

Leave `topic` empty to disable the channel. The script exits silently when disabled, and a failed push never blocks or delays your local toast.

> **Note on priority:** "needs confirmation" toasts are sent with `priority=high`, so they pop a banner. "done" toasts use the default priority and only land quietly in the notification shade (no banner/sound). To make the done toast also pop a banner, change its priority to `high` in `ntfy-push.ps1`.

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

Removes the hooks from `settings.json` and deletes the scripts + `SnoreToast.exe`. (Your `~/.claude/session-map/` cache and `~/.claude/ntfy.json` are left in place; delete them manually if you like.)

## How it works

| Hook event | Script | Effect |
|-----------|--------|--------|
| `SessionStart` | `session-register.ps1` | Writes `{title, cwd}` to `~/.claude/session-map/<session_id>.json` |
| `Notification` (`permission_prompt`) | `toast.ps1` | Fires a "needs confirmation" toast |
| `Stop` | `toast.ps1` | Fires a "done" toast |
| `Notification` (`permission_prompt`) | `ntfy-push.ps1` | Mirrors the "needs confirmation" push to your phone (no-op unless a topic is set) |
| `Stop` | `ntfy-push.ps1` | Mirrors the "done" push to your phone (no-op unless a topic is set) |

`toast.ps1` looks up the friendly name from `session-map` by session id, falls back to the directory name, and appends a 6-char session code so you can tell concurrent windows apart.

## Troubleshooting

- **Chinese shows as `????` / mojibake** — the hook scripts must be UTF-8 *with BOM* on PowerShell 5.1. The installer already writes them correctly; only relevant if you edit them by hand.
- **Hooks don't fire after install** — restart Claude Code or open `/hooks` once. Hooks added to `settings.json` mid-session aren't picked up until reload.
- **No toast appears** — make sure `SnoreToast.exe` sits next to `toast.ps1` (both live in `~/.claude/` after `install.ps1`). Re-run `install.ps1` if the exe is missing.
- **First run creates a Start Menu shortcut** — on first use, SnoreToast registers a `Claude Code` app identity (so the toast header shows "Claude Code" instead of "SnoreToast") by adding a Start Menu shortcut. `uninstall.ps1` removes it; if uninstalling manually, delete `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Claude Code\` yourself.

## Project layout

```
claude-win-notify/
├── README.md
├── LICENSE
├── install.ps1          # one-click installer
├── uninstall.ps1        # removes hooks + scripts
├── src/
│   ├── session-register.ps1
│   ├── toast.ps1
│   ├── ntfy-push.ps1    # optional phone push (ntfy.sh)
│   └── SnoreToast.exe   # bundled toast binary (LGPL-3.0)
├── vendor/
│   └── SnoreToast/
│       └── LICENSE      # SnoreToast LGPL-3.0 license text
└── test/
    └── simulate.ps1     # manual verification without a real session
```

## License

MIT — see [LICENSE](LICENSE).

The bundled `SnoreToast.exe` is [SnoreToast](https://github.com/KDE/snoretoast) by Hannah von Reth (KDE), distributed unmodified under the [LGPL-3.0](vendor/SnoreToast/LICENSE). It is invoked as a separate process, so this project's own code remains MIT.
