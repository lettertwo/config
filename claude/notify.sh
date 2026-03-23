#!/bin/bash
#
# Claude Code notification hook script.
# Usage:
#   notify.sh "message"   -- use provided message (e.g. Stop hook)
#   notify.sh             -- read message from JSON stdin (e.g. Notification hook)

# If a message was passed as an argument, use it; otherwise parse stdin JSON
if [ $# -ge 1 ]; then
  msg="$1"
else
  msg=$(cat | jq -r '.message // empty' 2>/dev/null)
  msg="${msg:-Needs attention}"
fi

# Prefer terminal-notifier: branded as Kitty, respects Kitty's Focus allowlist
if command -v terminal-notifier &>/dev/null; then
  args=(-title "Claude Code" -message "$msg" -sender "net.kovidgoyal.kitty" -activate "net.kovidgoyal.kitty")

  # If Kitty remote control is available, clicking the notification focuses the window
  if [ -n "$KITTY_LISTEN_ON" ] && command -v kitten &>/dev/null; then
    args+=(-execute "kitten @ --to $KITTY_LISTEN_ON focus-window")
  fi

  terminal-notifier "${args[@]}"

  # Fall back to osascript (generic, no Kitty branding)
elif command -v osascript &>/dev/null; then
  osascript -e "display notification \"$msg\" with title \"Claude Code\""

  # Fall back to notify-send (Linux/freedesktop)
elif command -v notify-send &>/dev/null; then
  notify-send "Claude Code" "$msg"
fi
