#!/usr/bin/env bash
# Record a Claude Code session's state on its tmux session, for the picker.
# Wire this into Claude Code hooks (see README):  state.sh <working|waiting|idle>
#
# Claude Code hooks inherit the Claude process environment, so $TMUX_PANE is set
# whenever Claude runs inside tmux. Outside tmux this is a no-op.
[ -z "$TMUX_PANE" ] && exit 0

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

session=$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null) || exit 0
[ -z "$session" ] && exit 0

new="${1:-idle}"
prev=$(tmux show-options -qv -t "$session" @claude_state 2>/dev/null)

tmux set-option -t "$session" @claude_state "$new"
tmux set-option -t "$session" @claude_state_at "$(date +%s)"

# Native macOS notification on actionable transitions (waiting/idle), fired once
# per change. Prefers terminal-notifier (clicking focuses iTerm), falls back to
# osascript. Disable with:  set -g @claude_notify off
notify="$(get_tmux_option @claude_notify 'on')"
if [ "$notify" != 'off' ] && [ "$new" != "$prev" ]; then
  case "$new" in
  waiting | idle)
    path=$(tmux display-message -p -t "$session" '#{pane_current_path}' 2>/dev/null)
    title="Claude · $new"
    msg="${path/#$HOME/~}"
    if command -v terminal-notifier >/dev/null 2>&1; then
      # Click the banner -> raise the terminal and jump to this session.
      terminal-notifier -title "$title" -message "$msg" \
        -execute "$DIR/notify-open.sh $session" >/dev/null 2>&1
    elif command -v osascript >/dev/null 2>&1; then
      osascript -e "display notification \"${msg//\"/}\" with title \"${title//\"/}\"" >/dev/null 2>&1
    fi
    ;;
  esac
fi
exit 0
