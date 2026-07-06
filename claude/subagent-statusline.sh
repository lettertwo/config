#!/bin/bash

# Custom agent-panel rows (settings.json "subagentStatusLine").
# Stdin: one JSON object per refresh tick — base hook fields plus `columns`
# and a `tasks` array ({id, status, description, startTime, tokenCount, ...}).
# Stdout: one {"id", "content"} JSON line per row we override.
#
# The payload has no agent type or model; both are joined from the session's
# on-disk agent files: <transcript-dir>/<session-id>/subagents/agent-<id>.*

input=$(cat)

transcript_path=$(jq -r '.transcript_path // ""' <<<"$input")
columns=$(jq -r '.columns // 80' <<<"$input")
subdir="${transcript_path%.jsonl}/subagents"
now_ms=$(date +%s)000

CYAN=$'\033[36m'
DIM=$'\033[90m'
GREEN=$'\033[32m'
RED=$'\033[31m'
RESET=$'\033[0m'
SEP=" · "

function short_model() {
  case "$1" in
    "") ;;
    claude-fable*)  printf "Fable" ;;
    claude-opus*)   printf "Opus" ;;
    claude-sonnet*) printf "Sonnet" ;;
    claude-haiku*)  printf "Haiku" ;;
    *) local m="${1#claude-}"; m="${m%%-*}"
       printf "%s%s" "$(printf "%s" "${m:0:1}" | tr '[:lower:]' '[:upper:]')" "${m:1}" ;;
  esac
}

function fmt_tokens() {
  if [ "$1" -ge 1000 ]; then printf "%dk" $(( $1 / 1000 )); else printf "%d" "$1"; fi
}

function fmt_elapsed() {
  local secs=$(( (now_ms - $1) / 1000 ))
  if [ "$secs" -lt 0 ]; then secs=0; fi
  if [ "$secs" -ge 3600 ]; then printf "%dh%02dm" $(( secs / 3600 )) $(( secs % 3600 / 60 ))
  elif [ "$secs" -ge 60 ]; then printf "%dm%02ds" $(( secs / 60 )) $(( secs % 60 ))
  else printf "%ds" "$secs"; fi
}

jq -c '.tasks[]' <<<"$input" | while read -r task; do
  IFS=$'\t' read -r id status desc start tok <<<"$(jq -r \
    '[.id, .status // "", .description // .label // "", .startTime // 0, .tokenCount // 0] | @tsv' <<<"$task")"

  agent_type=$(jq -r '.agentType // empty' "$subdir/agent-$id.meta.json" 2>/dev/null)
  # Model is constant per agent and appears in its first assistant line;
  # forward grep -m1 exits early instead of scanning the whole transcript.
  model=$(short_model "$(grep -m1 -o '"model":"[^"]*"' "$subdir/agent-$id.jsonl" 2>/dev/null | cut -d'"' -f4)")

  # No on-disk data to enrich with — keep the default rendering for this row.
  if [ -z "$agent_type" ] && [ -z "$model" ]; then continue; fi

  marker=""
  marker_len=0
  case "$status" in
    running) ;;
    completed) marker="${GREEN}✓${RESET} "; marker_len=2 ;;
    failed|error) marker="${RED}✗${RESET} "; marker_len=2 ;;
    *) if [ -n "$status" ]; then marker="${DIM}${status}${RESET} "; marker_len=$(( ${#status} + 1 )); fi ;;
  esac

  tail_txt="$(fmt_tokens "$tok")"
  [ "$start" -gt 0 ] && tail_txt+="${SEP}$(fmt_elapsed "$start")"

  # Truncate description so the visible row fits `columns`.
  head_len=$(( ${#agent_type} + marker_len ))
  [ -n "$model" ] && head_len=$(( head_len + ${#SEP} + ${#model} ))
  desc_budget=$(( columns - head_len - ${#SEP} - ${#tail_txt} - ${#SEP} ))
  if [ "$desc_budget" -lt 8 ]; then
    desc=""
  elif [ "${#desc}" -gt "$desc_budget" ]; then
    desc="${desc:0:$(( desc_budget - 1 ))}…"
  fi

  content="${marker}${agent_type:-agent}"
  [ -n "$model" ] && content+="${DIM}${SEP}${RESET}${CYAN}${model}${RESET}"
  [ -n "$desc" ] && content+="${DIM}${SEP}${desc}${RESET}"
  content+="${DIM}${SEP}${tail_txt}${RESET}"

  jq -cn --arg id "$id" --arg content "$content" '{id: $id, content: $content}'
done
