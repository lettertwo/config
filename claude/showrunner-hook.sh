#!/bin/bash
#
# SessionStart hook: inject the showrunner policy (main-thread orchestration
# rules) and the voice rules into session context, and drop a per-session marker
# file that the statusline reads to confirm the policy actually loaded.
#
# Runs twice, once per part. A single hook's output is replaced by a ~2,000-char
# preview once it exceeds 10,000 chars (measured 2026-08-25 against 2.1.245:
# 10,000 lands whole, 10,001 gets persisted to a file the session never reads).
# The budget is per hook entry, so two entries carry both files intact.
#
# Skip with CLAUDE_SHOWRUNNER=0 (bare-executor sessions, headless automation,
# A/B debugging of the setup itself).

[ "$CLAUDE_SHOWRUNNER" = "0" ] && exit 0

part="${1:-showrunner}"
BUDGET=10000

input=$(cat)

if [ "$part" = "showrunner" ]; then
  sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)

  MARKER_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-showrunner"
  if [ -n "$sid" ]; then
    mkdir -p "$MARKER_DIR"
    touch "$MARKER_DIR/$sid"
    find "$MARKER_DIR" -type f -mtime +7 -delete 2>/dev/null
  fi

  payload=$(cat "$HOME/.claude/showrunner.md")
else
  payload=$(cat <<'HEADER'
# Writing

These rules govern prose artifacts around the work: PR titles and descriptions, commit messages,
issue and review comments, handoff docs, ADRs, RFCs, reports, long-form code comments, and the
names you give identifiers.

HEADER
  cat "$HOME/.claude/voice.md")
fi

if [ "${#payload}" -gt "$BUDGET" ]; then
  printf 'WARNING: the %s policy is %d chars, over the %d-char SessionStart hook budget. Everything past roughly 2,000 chars was dropped before it reached this context. Split it into another hook entry.\n\n' \
    "$part" "${#payload}" "$BUDGET"
fi

printf '%s\n' "$payload"
