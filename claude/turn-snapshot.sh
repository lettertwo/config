#!/bin/bash
# claude/turn-snapshot.sh — UserPromptSubmit ("prompt") / Stop ("stop") /
# SessionStart ("sweep") hook.
#
# Snapshots the worktree as a git tree object at every turn boundary, so
# `fish/functions/claude-turns.fish` can diff what one turn changed, whether
# the edits came from Claude's own Edit tool or from a subagent driving Bash.
# Claude's `file-history/` only tracks the former.
#
# Writes nothing to stdout: UserPromptSubmit output is injected into context
# and this hook has nothing useful to say there; it also has a 30s cap and is
# run async, so nothing here should block on network or a slow git status.
#
# Each snapshot is `git write-tree` against a throwaway copy of the worktree's
# index (`GIT_INDEX_FILE` pointed at the copy), so a same-turn `git add -A .`
# never touches the real index and stays cheap on a big repo: only the files
# that changed since the last snapshot get restatted.
#
# refs/claude/turns/<session_id>/<seq> pins each tree against `git gc` and
# will show up in `git log --all` / `git for-each-ref`; that's expected, not a
# leak. `seq` and the ledger row live under a mkdir-based lock
# (`<git-common-dir>/claude-turns/.lock`) since macOS has no `flock` binary
# and two hooks (e.g. two concurrent sessions) can race on the same repo.
# A lock held past 30s is treated as abandoned (a killed or timed-out hook —
# `-p` mode cancels async Stop hooks outright, and a hook that hits its own
# timeout is killed the same way) and broken rather than waited on forever.
#
# `Stop` never fires on user interrupt, so prompt/stop rows do not strictly
# alternate; the next `UserPromptSubmit` still closes the gap. Consecutive
# identical trees just mean the turn made no file changes.

set -u

kind="${1:-}"
LEDGER_DIR_NAME="claude-turns"
MAX_AGE_DAYS=30

payload=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$payload" 2>/dev/null)
session_id=$(jq -r '.session_id // empty' <<<"$payload" 2>/dev/null)
prompt_id=$(jq -r '.prompt_id // empty' <<<"$payload" 2>/dev/null)

[ -n "$cwd" ] || exit 0
top=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null) || exit 0
common=$(git -C "$top" rev-parse --git-common-dir 2>/dev/null) || exit 0
case "$common" in
  /*) : ;;
  *) common="$top/$common" ;;
esac

ledger_dir="$common/$LEDGER_DIR_NAME"
mkdir -p "$ledger_dir" 2>/dev/null || exit 0
lock="$ledger_dir/.lock"
STALE_LOCK_SECS=30

lock_held=0
tmp_index=""

acquire_lock() {
  local waited=0 mtime age
  while :; do
    if mkdir "$lock" 2>/dev/null; then
      lock_held=1
      return 0
    fi
    mtime=$(stat -f %m "$lock" 2>/dev/null || stat -c %Y "$lock" 2>/dev/null)
    if [ -n "$mtime" ]; then
      age=$(( $(date +%s) - mtime ))
      if [ "$age" -gt "$STALE_LOCK_SECS" ]; then
        rmdir "$lock" 2>/dev/null
        continue
      fi
    fi
    waited=$((waited + 1))
    [ "$waited" -ge 100 ] && return 1
    sleep 0.05
  done
}
release_lock() {
  if [ "$lock_held" = 1 ]; then
    rmdir "$lock" 2>/dev/null
    lock_held=0
  fi
}
cleanup() {
  release_lock
  [ -n "$tmp_index" ] && rm -f "$tmp_index"
}
trap cleanup EXIT

if [ "$kind" = "sweep" ]; then
  acquire_lock || exit 0
  now=$(date +%s)
  for ledger in "$ledger_dir"/*.jsonl; do
    [ -e "$ledger" ] || continue
    mtime=$(stat -f %m "$ledger" 2>/dev/null || stat -c %Y "$ledger" 2>/dev/null) || continue
    age_days=$(( (now - mtime) / 86400 ))
    if [ "$age_days" -gt "$MAX_AGE_DAYS" ]; then
      sid=$(basename "$ledger" .jsonl)
      git -C "$top" for-each-ref --format='%(refname)' "refs/claude/turns/$sid" |
        while read -r ref; do git -C "$top" update-ref -d "$ref"; done
      rm -f "$ledger"
    fi
  done
  exit 0
fi

[ -n "$session_id" ] || exit 0
[ "$kind" = "prompt" ] || [ "$kind" = "stop" ] || exit 0

index_path=$(git -C "$top" rev-parse --git-path index 2>/dev/null) || exit 0
case "$index_path" in
  /*) : ;;
  *) index_path="$top/$index_path" ;;
esac

tmp_index=$(mktemp -t claude-turn-index)
cp "$index_path" "$tmp_index" 2>/dev/null || cp /dev/null "$tmp_index"

GIT_INDEX_FILE="$tmp_index" git -C "$top" add -A . 2>/dev/null
tree=$(GIT_INDEX_FILE="$tmp_index" git -C "$top" write-tree 2>/dev/null) || exit 0

head=$(git -C "$top" rev-parse HEAD 2>/dev/null || echo "")
branch=$(git -C "$top" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ledger="$ledger_dir/$session_id.jsonl"

acquire_lock || exit 0

[ -f "$ledger" ] || touch "$ledger"
seq=$(( $(wc -l <"$ledger") + 1 ))
seq_padded=$(printf '%04d' "$seq")

git -C "$top" update-ref "refs/claude/turns/$session_id/$seq_padded" "$tree" 2>/dev/null

row=$(jq -cn \
  --arg seq "$seq_padded" \
  --arg kind "$kind" \
  --arg ts "$ts" \
  --arg session_id "$session_id" \
  --arg prompt_id "$prompt_id" \
  --arg tree "$tree" \
  --arg head "$head" \
  --arg branch "$branch" \
  --arg worktree "$top" \
  --arg prompt "$(jq -r '.prompt // empty' <<<"$payload" 2>/dev/null | cut -c1-200)" \
  --arg reply "$(jq -r '.last_assistant_message // empty' <<<"$payload" 2>/dev/null | cut -c1-200)" \
  '{seq: $seq, kind: $kind, ts: $ts, session_id: $session_id, prompt_id: $prompt_id, tree: $tree,
    head: $head, branch: $branch, worktree: $worktree} +
   (if $kind == "prompt" then {prompt: $prompt} else {reply: $reply} end)')

printf '%s\n' "$row" >>"$ledger"

exit 0
