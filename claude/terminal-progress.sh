#!/usr/bin/env bash
# Drive an OSC 9;4 progress bar from Claude Code hooks, for terminals where Claude's
# native emission is broken or weaker than a whole-turn bar:
#   - kitty: native never emits (not on Claude's progressReporting allowlist) AND
#     Claude's indeterminate form `9;4;3;` is malformed (kitty rejects the trailing
#     empty field). We emit the correct `9;4;3`.
#   - ghostty: native works but only tracks the thinking phase (drops during tool
#     runs). We hold an indeterminate bar for the whole turn instead.
# Pair with "terminalProgressBarEnabled": false so native emission never fights this.
# Arg: "start" (indeterminate) | "clear".
#
# Writes ONLY to the tty device, never stdout, and always exits 0 so it can never
# block or pollute a turn.

# Only act in terminals known to render OSC 9;4 progress.
supported=0
[ -n "$KITTY_WINDOW_ID" ] && supported=1
[ -n "$GHOSTTY_RESOURCES_DIR" ] && supported=1
case "$TERM" in *kitty*|*ghostty*) supported=1 ;; esac
case "$TERM_PROGRAM" in ghostty) supported=1 ;; esac
[ "$supported" = 1 ] || exit 0

# Resolve Claude's controlling pty: walk up the process tree to the first ancestor
# with a real controlling terminal (the hook and its shell wrappers have none: "??").
pid=$PPID
dev=""
for _ in 1 2 3 4 5 6 7 8; do
  { [ -n "$pid" ] && [ "$pid" != 1 ]; } || break
  t=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')
  if [ -n "$t" ] && [ "$t" != "?" ] && [ "$t" != "??" ]; then dev="/dev/$t"; break; fi
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
done
[ -n "$dev" ] && [ -w "$dev" ] || exit 0

case "$1" in
  start) printf '\033]9;4;3\007' > "$dev" 2>/dev/null ;;  # indeterminate (correct form)
  clear) printf '\033]9;4;0\007' > "$dev" 2>/dev/null ;;  # remove
esac
exit 0
