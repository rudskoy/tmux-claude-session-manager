#!/usr/bin/env bash
# Launch (or re-attach to) a Claude session for a directory, shown in a popup.
# Args: <dir> [origin-window-id]   (both expanded by run-shell in the binding)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

path="${1:-$PWD}"
window="${2:-}"
mode="${3:-}"

prefix="$(get_tmux_option @claude_session_prefix 'claude-')"
cmd="$(get_tmux_option @claude_command 'claude')"
w="$(get_tmux_option @claude_popup_width '90%')"
h="$(get_tmux_option @claude_popup_height '90%')"

session="${prefix}$(session_hash "$path")"

if [[ "$(tmux display-message -p '#S')" == "$prefix"* ]]; then
  tmux display-message '🫪 Popup window already open'
  exit 0
fi

tmux has-session -t "$session" 2>/dev/null ||
  tmux new-session -d -s "$session" -c "$path" "$cmd"

# Record which window launched it, so the picker can jump back here later.
[ -n "$window" ] && tmux set-option -t "$session" @claude_origin "$window"

# Split mode: add a shell pane on the right (1/3) next to Claude (2/3). Only when
# the session has a single pane, so it's idempotent and also upgrades a session
# first opened single (via the launch key) to the split layout.
if [ "$mode" = 'split' ]; then
  panes=$(tmux display-message -p -t "$session" '#{window_panes}' 2>/dev/null)
  if [ "${panes:-1}" -eq 1 ]; then
    pct="$(get_tmux_option @claude_split_percent '33')"
    tmux split-window -h -l "${pct}%" -t "$session" -c "$path"
    tmux select-pane -t "$session" -L # focus the Claude (left) pane
  fi
fi

tmux display-popup -w "$w" -h "$h" -E "tmux attach-session -t $session"
