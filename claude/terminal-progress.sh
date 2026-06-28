#!/usr/bin/env bash
# terminal-progress.sh — drive an OSC 9;4 progress bar from Claude Code hooks in
# kitty/ghostty, working around Claude bugs (kitty isn't on the progressReporting
# allowlist and its native `9;4;3;` indeterminate form is malformed; ghostty native
# only tracks the thinking phase). Pairs with "terminalProgressBarEnabled": false.
#
#   start   (UserPromptSubmit/PreToolUse) -> show indeterminate bar
#   clear   (Stop/StopFailure/SessionEnd) -> hide bar
#
# PreToolUse also fires start because turns resumed without a typed prompt
# (background-command completions, wakeups) never fire UserPromptSubmit —
# the first tool call re-asserts the bar; re-sending 9;4;3 is idempotent.
#
# Writes OSC only to the terminal device, never stdout; always exits 0.
#
# Known limitation: a turn cancelled with Esc fires NO hook, so its bar persists until
# the next start/clear event. Dead ends investigated to date:
#   1. No cancel/abort hook exists; Stop explicitly skips interrupts. Open FR that would
#      fix this: anthropics/claude-code#9516 (UserInterrupt hook) — if it ships, wire
#      UserInterrupt -> clear and delete this caveat.
#   2. MessageDisplay doesn't fire for the "Interrupted" UI line (it's chrome, not a
#      message; the event covers assistant text blocks only).
#   3. Transcript interrupt records are prompt but only written when the turn already
#      produced output — Esc during silent thinking leaves no trace.
#   4. kitty keypress interception (CLAUDE_BUSY user var + var-gated Esc/Ctrl+C maps +
#      background-launch helper): the map fired, but window targeting from the
#      keybinding's background-launch context matched zero windows; dropped for simplicity.
#   5. CPU-idle watchdog: the TUI keeps re-rendering when idle, so CPU never hits ~0.

# Only act in terminals that render OSC 9;4 progress.
supported=0
[ -n "$KITTY_WINDOW_ID" ] && supported=1
[ -n "$GHOSTTY_RESOURCES_DIR" ] && supported=1
case "$TERM" in *kitty*|*ghostty*) supported=1 ;; esac
case "$TERM_PROGRAM" in ghostty) supported=1 ;; esac
[ "$supported" = 1 ] || exit 0

# /dev/<tty> of the first ancestor with a real controlling terminal (the hook and its
# shell wrappers have none: "??"). That ancestor is Claude / its login shell.
dev=""; pid=$PPID
for _ in 1 2 3 4 5 6 7 8; do
  { [ -n "$pid" ] && [ "$pid" != 1 ]; } || break
  t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -n "$t" ] && [ "$t" != "?" ] && [ "$t" != "??" ]; then dev="/dev/$t"; break; fi
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
[ -n "$dev" ] || exit 0

case "$1" in
  start) printf '\033]9;4;3\007' > "$dev" 2>/dev/null ;;  # indeterminate
  clear) printf '\033]9;4;0\007' > "$dev" 2>/dev/null ;;  # remove
esac
exit 0
