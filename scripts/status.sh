#!/usr/bin/env bash
# Emit a one-line summary of Claude session states for the tmux status bar.
#
# Counts prefixed sessions by @claude_state and prints colored tallies, e.g.
#   ●2 ●1 ●3   (red working, yellow waiting, green idle)
# Prints nothing when no Claude sessions exist, so it stays out of the way.
#
# Wire it into status-right (runs every `status-interval` seconds):
#   set -ag status-right '#(/path/to/scripts/status.sh)'
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
. "$DIR/helpers.sh"

prefix="$(get_tmux_option @claude_session_prefix 'claude-')"

working=0 waiting=0 idle=0 unknown=0
while IFS= read -r s; do
  [ -z "$s" ] && continue
  case "$(tmux show-options -qv -t "$s" @claude_state 2>/dev/null)" in
  working) working=$((working + 1)) ;;
  waiting) waiting=$((waiting + 1)) ;;
  idle) idle=$((idle + 1)) ;;
  *) unknown=$((unknown + 1)) ;;
  esac
done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^${prefix}")

# Nothing running — emit nothing so the status bar isn't cluttered.
[ $((working + waiting + idle + unknown)) -eq 0 ] && exit 0

# Show waiting/idle first (need attention), then working, then unknown if any.
# tmux #[fg=...] color codes; #[default] restores the surrounding style.
out=''
[ "$waiting" -gt 0 ] && out="$out#[fg=yellow]●${waiting} "
[ "$idle" -gt 0 ] && out="$out#[fg=green]●${idle} "
[ "$working" -gt 0 ] && out="$out#[fg=red]●${working} "
[ "$unknown" -gt 0 ] && out="$out#[fg=colour244]●${unknown} "
printf '%s#[default]' "${out% }"
