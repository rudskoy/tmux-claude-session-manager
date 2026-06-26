#!/usr/bin/env bash
# Click handler for the macOS notification fired by state.sh.
# Raises the terminal app, then resumes the given Claude session in a popup over
# the window it was launched from — same jump the picker does on <enter>.
# Args: <session-name>
set -uo pipefail
# terminal-notifier runs this via launchd, so its PATH is minimal — make sure the
# tmux / open binaries resolve.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

session="${1:-}"
[ -z "$session" ] && exit 0

app="$(get_tmux_option @claude_notify_app 'Ghostty')"
prefix="$(get_tmux_option @claude_session_prefix 'claude-')"
w="$(get_tmux_option @claude_popup_width '90%')"
h="$(get_tmux_option @claude_popup_height '90%')"

# Bring the terminal to the front so the popup is visible.
[ -n "$app" ] && open -a "$app" 2>/dev/null

tmux has-session -t "$session" 2>/dev/null || exit 0

# Outer client — one NOT attached to a prefixed (popup) session.
host=$(tmux list-clients -F '#{client_name} #{session_name}' 2>/dev/null |
  awk -v p="$prefix" 'index($2, p) != 1 { print $1; exit }')

# Move that client to the session's origin window, then resume the session in a
# popup over it (best-effort; falls back to a popup on the default client).
origin=$(tmux show-options -qv -t "$session" @claude_origin 2>/dev/null)
[ -n "$host" ] && [ -n "$origin" ] &&
  tmux switch-client -c "$host" -t "$origin" 2>/dev/null

if [ -n "$host" ]; then
  tmux display-popup -c "$host" -w "$w" -h "$h" -E "tmux attach-session -t $session"
else
  tmux display-popup -w "$w" -h "$h" -E "tmux attach-session -t $session"
fi
