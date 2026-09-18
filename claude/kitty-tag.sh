#!/bin/bash
# claude/kitty-tag.sh — SessionStart (all sources) / SessionEnd hook.
#
# Tags the kitty window Claude is running in with its cwd and session id, so
# nvim/lua/config/annotations/send.lua can find the right window to type
# feedback into with `kitty @ send-text`. This hook runs inside the Claude
# window itself, so `kitten @` needs no `--to` address; it also inherits
# `$KITTY_LISTEN_ON` from that window's environment.
#
# Usage: kitty-tag.sh <start|end>

set -u

mode="${1:-start}"
[ -n "${KITTY_WINDOW_ID:-}" ] || exit 0
command -v kitten >/dev/null 2>&1 || exit 0

if [ "$mode" = "end" ]; then
  # Removes the tags so this window is never picked as a send target once Claude has quit.
  kitten @ set-user-vars --match id:"$KITTY_WINDOW_ID" claude_cwd claude_session >/dev/null 2>&1
  exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0
payload=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$payload")
session_id=$(jq -r '.session_id // empty' <<<"$payload")
[ -n "$cwd" ] || exit 0

kitten @ set-user-vars --match id:"$KITTY_WINDOW_ID" claude_cwd="$cwd" claude_session="$session_id" >/dev/null 2>&1
exit 0
