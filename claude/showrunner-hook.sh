#!/bin/bash
#
# SessionStart hook: inject the showrunner policy (main-thread orchestration
# rules) into session context, and drop a per-session marker file that the
# statusline reads to confirm the policy actually loaded.
#
# Skip with CLAUDE_SHOWRUNNER=0 (bare-executor sessions, headless automation,
# A/B debugging of the setup itself).

[ "$CLAUDE_SHOWRUNNER" = "0" ] && exit 0

input=$(cat)
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

MARKER_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-showrunner"
if [ -n "$sid" ]; then
  mkdir -p "$MARKER_DIR"
  touch "$MARKER_DIR/$sid"
  find "$MARKER_DIR" -type f -mtime +7 -delete 2>/dev/null
fi

cat "$HOME/.claude/showrunner.md"
