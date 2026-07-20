#!/bin/bash
# Claude Code notification hook.
# Modes: notify (Notification hook), stop (Stop hook), cleanup (SessionEnd hook)

command -v terminal-notifier &>/dev/null || exit 0
command -v jq               &>/dev/null || exit 0

mode="${1:-notify}"
payload=$(cat)
session_id=$(jq -r '.session_id // empty' <<<"$payload")
[ -z "$session_id" ] && exit 0

if [ "$mode" = "cleanup" ]; then
  terminal-notifier -remove "$session_id"
  exit 0
fi

if [ "$mode" = "stop" ]; then
  msg="Ready for your input"
else
  msg=$(jq -r '.message // "Needs attention"' <<<"$payload")
fi

args=(
  -title    "Claude Code"
  -message  "$msg"
  -group    "$session_id"
  -sender   "net.kovidgoyal.kitty"
  -activate "net.kovidgoyal.kitty"
)

if [ -n "$KITTY_LISTEN_ON" ] && command -v kitten &>/dev/null; then
  args+=(-execute "kitten @ --to $KITTY_LISTEN_ON focus-window")
fi

# -execute keeps terminal-notifier resident until the banner is clicked; drop any
# prior resident notifier for this session so they can't accumulate.
pkill -f "terminal-notifier.*-group $session_id" 2>/dev/null

terminal-notifier "${args[@]}" &
disown
