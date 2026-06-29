# tmux-claude-session-manager

> **Fork notice.** This is a fork of
> [craftzdog/tmux-claude-session-manager](https://github.com/craftzdog/tmux-claude-session-manager)
> with extra features. Enhancements added in this fork:
>
> - 🔢 **Number-key selection** in the picker — press `1`–`4` to jump to the
>   1st–4th listed session.
> - 📊 **Status-bar summary** (`scripts/status.sh`) — live `waiting`/`idle`/
>   `working` tallies for your tmux status line.
> - 🔔 **Native macOS notifications** on `waiting`/`idle` transitions; clicking a
>   banner raises your terminal and jumps to that session.
> - 🪟 **Split-view launch** (`prefix` + `o`) — Claude on the left (2/3), a shell
>   on the right (1/3).

[![screenshot](./docs/screenshot.jpg)](https://youtu.be/NnTV6r4l5D0)

Run many [Claude Code](https://claude.com/claude-code) sessions across your
projects, each in its own tmux session — then **list them, see which are done
vs. still working, and jump to one** from a single popup.

If you launch Claude per-directory (one nested session per project), you quickly
end up with a dozen of them and no way to tell which are finished without opening
each one. This plugin gives you:

- 🔢 **A central picker** (`prefix` + `u`) listing every running Claude session.
- 🟢 **Live status** per session — `working` / `waiting` / `idle` — driven by
  Claude Code hooks, so you instantly see which need you.
- 👁️ **A live preview** of each session's screen right in the picker.
- 🎯 **Smart jump** — selecting a session switches your client to the window it
  was launched from, then resumes it in a popup over it.
- 🚀 **A launcher** (`prefix` + `y`) that opens/attaches a Claude session for the
  current directory.
- ❌ **Quick kill** (`ctrl-x`) of finished sessions from the picker.

Status is optional: without the hooks the picker still lists, previews, jumps,
and kills — sessions just show `?` instead of a color.

## Prerequisites

- **tmux ≥ 3.2** (for `display-popup`)
- **[fzf](https://github.com/junegunn/fzf)** — the picker UI
- **[Claude Code](https://claude.com/claude-code)** CLI (the `claude` command)
- bash; macOS or Linux

## Install (tpm)

Add to `~/.tmux.conf` (or `~/.config/tmux/tmux.conf`):

```tmux
set -g @plugin 'craftzdog/tmux-claude-session-manager'
```

Then hit `prefix` + <kbd>I</kbd> to install.

> **Keybinding note:** by default the plugin binds `prefix` + `y` (launch) and
> `prefix` + `u` (list). If your config binds those elsewhere, either change the
> options below, or make sure the plugin loads **after** your own bindings (put
> `run '~/.tmux/plugins/tpm/tpm'` _after_ them) so the one you want wins.

### Manual install

```sh
git clone https://github.com/craftzdog/tmux-claude-session-manager ~/clone/path
```

Add to `~/.tmux.conf`, then reload (`prefix` + <kbd>r</kbd> or `tmux source ~/.tmux.conf`):

```tmux
run-shell ~/clone/path/claude_session_manager.tmux
```

## Usage

| Key            | Action                                                                          |
| -------------- | ------------------------------------------------------------------------------- |
| `prefix` + `y` | Launch (or re-attach to) a Claude session for the current directory, in a popup |
| `prefix` + `o` | Same, but split the popup — Claude on the left (2/3), a shell on the right (1/3) |
| `prefix` + `u` | Open the session picker                                                         |

Inside the picker:

| Key                       | Action                                                                    |
| ------------------------- | ------------------------------------------------------------------------- |
| `enter`                   | Jump to the session (switches to its origin window, resumes in the popup) |
| `1`–`4`                   | Jump to the 1st–4th listed session (positional — `1` is the top row)      |
| `ctrl-x`                  | Kill the highlighted session                                              |
| `↑` / `↓`, type to filter | fzf navigation (`5`–`0` still type into the filter)                       |

> The row numbers are **positional**: they reflect the current order, so after you
> filter the list, `1` always picks the new top row (the printed digits don't
> renumber as you type).

Sessions needing your attention (`waiting`, `idle`) sort to the top.

## Status setup (optional, recommended)

Status comes from [Claude Code hooks](https://code.claude.com/docs/en/hooks)
that stamp each session's state onto its tmux session. Add the following to your
Claude Code settings (`~/.claude/settings.json`), merging into any existing
`hooks` block. Adjust the path if your plugins live elsewhere (e.g.
`~/.tmux/plugins/...`):

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh working"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh waiting"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh waiting"
          }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "$HOME/.config/tmux/plugins/tmux-claude-session-manager/scripts/state.sh idle"
          }
        ]
      }
    ]
  }
}
```

The state machine:

| Event                            | State        | Meaning                   |
| -------------------------------- | ------------ | ------------------------- |
| `UserPromptSubmit`               | 🔴 `working` | Busy — leave it           |
| `Notification` (permission)      | 🟡 `waiting` | Needs permission          |
| `PreToolUse` (`AskUserQuestion`) | 🟡 `waiting` | Asking you a question     |
| `Stop`                           | 🟢 `idle`    | Turn finished — your move |

> Claude Code reloads `hooks` dynamically — no restart needed. Sessions that are
> already running start reporting status on their next event once the hooks are
> added.

## Native notifications (macOS, optional)

Once the status hooks are wired (above), `state.sh` also fires a native macOS
notification when a session changes to `waiting` (needs input) or `idle` (turn
finished) — once per transition, so you hear about a session that needs you even
when its popup is closed. It prefers
[`terminal-notifier`](https://github.com/julienXX/terminal-notifier) (clicking the
banner focuses iTerm) and falls back to `osascript` (built in).

Clicking the banner raises your terminal and resumes that session in a popup over
the window it was launched from (the same jump as the picker). Set the terminal
app to raise with `@claude_notify_app` (defaults to `Ghostty`).

On by default. Disable it with:

```tmux
set -g @claude_notify off          # turn notifications off
set -g @claude_notify_app 'iTerm'  # terminal app to raise on click (default: Ghostty)
```

## Status bar summary (optional)

Show a live tally of running Claude sessions — `waiting` / `idle` / `working` —
in your tmux status bar. `scripts/status.sh` counts prefixed sessions by state
and prints colored dots (yellow waiting, green idle, red working); it prints
nothing when no Claude sessions exist.

Add it to `status-right` (redrawn every `status-interval` seconds):

```tmux
set -ag status-right '#(~/.tmux/plugins/tmux-claude-session-manager/scripts/status.sh)'
```

Using [oh-my-tmux](https://github.com/gpakosz/.tmux)? Set it inside
`tmux_conf_theme_status_right` in `~/.tmux.conf.local` instead, e.g. insert
`#(~/.tmux/plugins/tmux-claude-session-manager/scripts/status.sh)` as its own
` , `-separated segment. The counts require the status hooks above to be wired.

## Options

Set any of these before the plugin loads (defaults shown):

```tmux
set -g @claude_launch_key     'y'        # prefix key: launch/open for current dir
set -g @claude_split_key      'o'        # prefix key: launch with a split shell pane
set -g @claude_split_percent  '33'       # right-pane width (%) in split mode
set -g @claude_list_key       'u'        # prefix key: open the picker
set -g @claude_command        'claude'   # command run in new sessions
set -g @claude_session_prefix 'claude-'  # tmux session name prefix
set -g @claude_popup_width     '90%'     # popup width
set -g @claude_popup_height    '90%'     # popup height
```

## How it works

- The **launcher** creates a detached `claude-<hash-of-dir>` tmux session running
  `claude`, records the window it came from in `@claude_origin`, and attaches to
  it in a popup.
- The **hooks** set `@claude_state` / `@claude_state_at` on each session as Claude
  works.
- The **picker** lists sessions matching the prefix, reads their state and a live
  `capture-pane` preview, and on selection moves your client to the session's
  origin window before resuming it in the popup.
- Pressing `prefix` + `u` **from inside a session popup** detaches that popup
  first (closing it), then reopens the picker full-size on the outer host client —
  so you never end up with a cramped popup-in-popup.

## License

[MIT](LICENSE) © Takuya Matsuyama
