#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Soft spend budgets for API-billed accounts (bars fill toward these)
: "${DAY_BUDGET_USD:=50}"
: "${WK_BUDGET_USD:=250}"

# Extract dir, context pct, model, session id/cost, and subscription
# rate limits (rate_limits.* is only present for subscription accounts —
# its absence means API billing). resets_at is epoch seconds; tonumber?
# guards against schema drift breaking the whole line.
# NOTE: fields must never be empty strings — tab is IFS whitespace, so read
# collapses consecutive tabs and empty fields shift everything after them.
# Absent values use sentinels ("-" / -1) instead.
IFS=$'\t' read -r dir ctx_pct model_name session_id cost_usd ses_pct ses_resets wk_pct wk_resets effort lines_add lines_del <<< "$(echo "$input" | jq -r '[
  .workspace.current_dir,
  (.context_window.used_percentage // -1),
  (.model.display_name // ""),
  (.session_id // ""),
  (.cost.total_cost_usd // -1),
  ((.rate_limits.five_hour.used_percentage // -1) | floor),
  ((.rate_limits.five_hour.resets_at // -1) | tonumber? // -1 | floor),
  ((.rate_limits.seven_day.used_percentage // -1) | floor),
  ((.rate_limits.seven_day.resets_at // -1) | tonumber? // -1 | floor),
  (.effort.level // "-"),
  (.cost.total_lines_added // 0),
  (.cost.total_lines_removed // 0)
] | @tsv')"

if [ "$effort" = "-" ]; then effort=""; fi

# Showrunner marker: the SessionStart hook touches a per-session file when the
# policy was injected; absence here means the session is running vanilla.
sr=""
if [ -n "$session_id" ] && [ -f "${XDG_CACHE_HOME:-$HOME/.cache}/claude-showrunner/$session_id" ]; then
  sr="sr"
fi
lines_txt=""
if [ "${lines_add:-0}" -gt 0 ] || [ "${lines_del:-0}" -gt 0 ]; then
  lines_txt="+${lines_add} -${lines_del}"
fi

basename=$(basename "$dir")

# Change to directory
cd "$dir" 2>/dev/null || exit 1

# ANSI color codes
CYAN='\033[36m'
BLACK='\033[30m'
BRIGHT_BLACK='\033[90m'
BLUE='\033[34m'
YELLOW='\033[33m'
RED='\033[31m'
GREEN='\033[32m'
RESET='\033[0m'

# Unicode symbols
GIT_BRANCH_ICON="󰘬"
FOLDER_ICON="󰝰"
SHOWRUNNER_ON_ICON="󰎁"
SHOWRUNNER_OFF_ICON="󱛹"
# Effort gauge tracks the level: speedometer slow/medium/full, rocket beyond
case "$effort" in
  low)       EFFORT_ICON="󰾆" ;;
  medium)    EFFORT_ICON="󰾅" ;;
  xhigh|max) EFFORT_ICON="󱓞" ;;
  *)         EFFORT_ICON="󰓅" ;;
esac
BAR_FILLED="━"
BAR_THIN="─"
COL_WIDTH=10

# ── Status line: model + dir + git branch ──────────────────────────────────────────────

# Check if we're in a git repository
if git rev-parse --is-inside-work-tree &>/dev/null; then
  # Get current branch
  branch=$(git branch --show-current 2>/dev/null)

  # Check if this is a worktree
  if [ -f ".git" ]; then
    # This is a worktree - show parent/worktree
    parent=$(basename "$(dirname "$dir")")
    dir_display="$parent/$basename"
  else
    # Regular repo - show just basename
    dir_display="$basename"
  fi

  # Format output with colors and icons — always cap line 1 to keep lines 2&3 visible.
  term_cols=$(tput cols </dev/tty 2>/dev/null || stty size </dev/tty 2>/dev/null | awk '{print $2}')
  max_line1=$(( ${term_cols:-70} * 3 / 4 ))
  model_len=$([ -n "$model_name" ] && echo $(( ${#model_name} + 3 )) || echo 0)
  effort_len=$([ -n "$effort" ] && echo $(( ${#effort} + 3 )) || echo 0)
  lines_len=$([ -n "$lines_txt" ] && echo $(( ${#lines_txt} + 2 )) || echo 0)
  if [ -n "$branch" ] && [ "$branch" != "$dir_display" ]; then
    branch_budget=$(( max_line1 - model_len - effort_len - lines_len - ${#dir_display} - 8 ))
    if [ "$branch_budget" -lt 8 ]; then branch_budget=8; fi
    if [ "${#branch}" -gt "$branch_budget" ]; then
      branch="${branch:0:$(( branch_budget - 1 ))}…"
    fi
    status="${BLACK}${FOLDER_ICON} ${dir_display}${RESET} ${BRIGHT_BLACK}${GIT_BRANCH_ICON} ${branch}${RESET}"
  else
    status="${BLACK}${FOLDER_ICON} ${dir_display}${RESET}"
  fi
else
  # Not a git repo - just show directory
  status="${BLACK}${FOLDER_ICON} ${basename}${RESET}"
fi

# Prepend model name (with effort level when the model reports one)
if [ -n "$model_name" ]; then
  if [ -n "$sr" ]; then
    model_seg="${CYAN}${SHOWRUNNER_ON_ICON} ${model_name}${RESET}"
  else
    model_seg="${RED}${SHOWRUNNER_OFF_ICON}${RESET} ${CYAN}${model_name}${RESET}"
  fi
  if [ -n "$effort" ]; then
    model_seg="${model_seg} ${BRIGHT_BLACK}${EFFORT_ICON} ${effort}${RESET}"
  fi
  status="${model_seg} ${status}"
fi

# Append lines added/removed when the session has changed anything
if [ -n "$lines_txt" ]; then
  status="${status}  ${GREEN}+${lines_add}${RESET} ${RED}-${lines_del}${RESET}"
fi

# ── Progress bar helper ───────────────────────────────────────────────────────
# Usage: render_bar <pct_int> [ideal_pct_int] [diff] [col_width]
# Without ideal: thick filled + thin dim (ctx-style)
# With ideal: thick marks ideal pace zone, thin marks actual overage/unfilled
#   over-pace  (actual > ideal): thick colored up to ideal, thin colored overage, thin dim unfilled
#   behind     (actual < ideal): thick colored actual, thick dim budget remaining, thin dim unfilled
#   on-track   (actual ≈ ideal): thick colored filled, thin dim unfilled
function render_bar() {
  local pct="$1"
  local ideal_pct="${2:-}"
  local diff="${3:-}"
  local cw="${4:-$COL_WIDTH}"
  local bar_color
  bar_color=$(severity_color "$pct" "$diff")

  local filled=$(( pct * cw / 100 ))

  if [ -z "$ideal_pct" ]; then
    local unfilled=$(( cw - filled ))
    local bar=""
    local i
    for (( i=0; i<filled; i++ )); do bar+="${BAR_FILLED}"; done
    local gray_part=""
    for (( i=0; i<unfilled; i++ )); do gray_part+="${BAR_THIN}"; done
    printf "${bar_color}%s${BLACK}%s${RESET}" "$bar" "$gray_part"
  else
    local ideal=$(( ideal_pct * cw / 100 ))
    local result=""
    local i

    if [ "$filled" -ge "$ideal" ]; then
      # Over-pace: thick colored up to ideal, thin colored overage, thin dim unfilled
      for (( i=0; i<ideal; i++ )); do result+="${bar_color}${BAR_FILLED}"; done
      for (( i=ideal; i<filled; i++ )); do result+="${bar_color}${BAR_THIN}"; done
      for (( i=filled; i<cw; i++ )); do result+="${BLACK}${BAR_THIN}"; done
    else
      # Behind-pace: thick colored actual, thick dim budget remaining, thin dim unfilled
      for (( i=0; i<filled; i++ )); do result+="${bar_color}${BAR_FILLED}"; done
      for (( i=filled; i<ideal; i++ )); do result+="${BLACK}${BAR_FILLED}"; done
      for (( i=ideal; i<cw; i++ )); do result+="${BLACK}${BAR_THIN}"; done
    fi

    printf "%b${RESET}" "$result"
  fi
}

# ── Rate-limit pace (subscription accounts; fields absent under API billing) ──

# Compute signed diffs: positive = burning faster than time elapsed
ses_diff=""
ses_time_pct=""
wk_diff=""
wk_time_pct=""
now_ts=$(date +%s)

ses_countdown=""
if [ "$ses_pct" -ge 0 ] && [ "$ses_resets" -gt 0 ]; then
  elapsed=$(( now_ts - (ses_resets - 18000) ))
  if [ $elapsed -lt 0 ]; then elapsed=0; fi
  if [ $elapsed -gt 18000 ]; then elapsed=18000; fi
  ses_time_pct=$(( elapsed * 100 / 18000 ))
  ses_diff=$(( ses_pct - ses_time_pct ))
  remaining=$(( ses_resets - now_ts ))
  if [ "$remaining" -gt 0 ]; then
    hrs=$(( remaining / 3600 ))
    mins=$(( (remaining % 3600) / 60 ))
    ses_countdown="${hrs}h${mins}m"
  fi
fi

if [ "$wk_pct" -ge 0 ] && [ "$wk_resets" -gt 0 ]; then
  elapsed=$(( now_ts - (wk_resets - 604800) ))
  if [ $elapsed -lt 0 ]; then elapsed=0; fi
  if [ $elapsed -gt 604800 ]; then elapsed=604800; fi
  wk_time_pct=$(( elapsed * 100 / 604800 ))
  wk_diff=$(( wk_pct - wk_time_pct ))
fi

# ── Spend ledger (API billing) ────────────────────────────────────────────────
# Each render records this session's cost *increase* into a per-day bucket,
# using cost.total_cost_usd from stdin (Claude Code's own pricing math) — no
# pricing table needed. Day/week totals and rolling averages derive from it.
# Only counts sessions that render a statusline (headless `claude -p` won't).

SPEND_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline-spend.json"
SPEND_LOCK="${SPEND_FILE}.lock"
today=$(date +%F)

function update_spend_ledger() {
  # Clean up stale lock (older than 60s)
  if [ -d "$SPEND_LOCK" ]; then
    local lock_age
    lock_age=$(( $(date +%s) - $(stat -f %m "$SPEND_LOCK" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -gt 60 ]; then
      rmdir "$SPEND_LOCK" 2>/dev/null
    fi
  fi

  # Skip on contention: delta is computed against last *recorded* cost,
  # so a missed update is picked up whole on the next render.
  mkdir "$SPEND_LOCK" 2>/dev/null || return 0
  local state cutoff tmp
  state=$(jq -c . "$SPEND_FILE" 2>/dev/null || echo '{}')
  cutoff=$(date -v-35d +%F)
  tmp="${SPEND_FILE}.tmp.$$"
  if jq -n --argjson s "$state" --arg sid "$session_id" --arg today "$today" \
        --arg cutoff "$cutoff" --argjson cost "$cost_usd" '
      $s
      | .sessions //= {} | .days //= {}
      | (.sessions[$sid].c // 0) as $last
      # cost below last recorded means the session restarted its counter
      | (if $cost >= $last then $cost - $last else $cost end) as $delta
      | .days[$today] = ((.days[$today] // 0) + $delta)
      | .sessions[$sid] = {c: $cost, d: $today}
      | .days |= with_entries(select(.key >= $cutoff))
      | .sessions |= with_entries(select(.value.d >= $cutoff))
    ' > "$tmp" 2>/dev/null; then
    mv "$tmp" "$SPEND_FILE"
  else
    rm -f "$tmp"
  fi
  rmdir "$SPEND_LOCK" 2>/dev/null
}

day_spend=0
wk_spend=0
avg_day=0
prev_wk=0

if [ -n "$session_id" ] && [ "${cost_usd%.*}" != "-1" ]; then
  mkdir -p "$(dirname "$SPEND_FILE")" 2>/dev/null
  update_spend_ledger
fi

if [ -f "$SPEND_FILE" ]; then
  IFS=$'\t' read -r day_spend wk_spend avg_day prev_wk <<< "$(jq -r --arg today "$today" '
    (.days // {}) as $d
    | ($today | strptime("%Y-%m-%d") | mktime) as $t
    | [$d | to_entries[] | . + {age: ((($t - (.key | strptime("%Y-%m-%d") | mktime)) / 86400) | round)}] as $e
    | [
        ($d[$today] // 0),
        ([$e[] | select(.age >= 0 and .age <= 6) | .value] | add // 0),
        ([$e[] | select(.age >= 1 and .age <= 14 and .value > 0) | .value] | if length > 0 then add / length else 0 end),
        ([$e[] | select(.age >= 7 and .age <= 13) | .value] | add // 0)
      ] | @tsv
  ' "$SPEND_FILE" 2>/dev/null)"
  : "${day_spend:=0}" "${wk_spend:=0}" "${avg_day:=0}" "${prev_wk:=0}"
fi

# ── Render bars ───────────────────────────────────────────────────────────────

# severity_color <pct> [diff] — unified color: pace-aware when diff given, else pct thresholds
function severity_color() {
  local pct="$1" diff="${2:-}"
  if [ -n "$diff" ]; then
    if   [ "$diff" -gt 20 ]; then printf "%s" "$RED"
    elif [ "$diff" -gt  5 ]; then printf "%s" "$YELLOW"
    else                          printf "%s" "$BLUE"
    fi
  else
    if   [ "$pct" -lt 60 ]; then printf "%s" "$BLUE"
    elif [ "$pct" -lt 75 ]; then printf "%s" "$YELLOW"
    else                         printf "%s" "$RED"
    fi
  fi
}

# make_label <name> [value] [color] [suffix] [col_width] — label padded to col_width visible chars
# name is BLACK; value (pre-formatted, e.g. "42%" or "$4.52") uses the given color;
# suffix (e.g. countdown) rendered in BLACK
function make_label() {
  local name="$1"
  local value="${2:-}"
  local color="${3:-}"
  local suffix="${4:-}"
  local cw="${5:-$COL_WIDTH}"
  local pad pad_len

  if [ -n "$value" ]; then
    local text="${name} ${value}"
    if [ -n "$suffix" ]; then
      local suffix_with_space=" ${suffix}"
      pad_len=$(( cw - ${#text} - ${#suffix_with_space} ))
      if [ "$pad_len" -lt 0 ]; then pad_len=0; fi
      pad=$(printf "%*s" "$pad_len" "")
      printf "${BLACK}%s${color}%s%s${BLACK}%s${RESET}" "$name " "$value" "$pad" "$suffix_with_space"
    else
      pad_len=$(( cw - ${#text} ))
      if [ "$pad_len" -lt 0 ]; then pad_len=0; fi
      pad=$(printf "%*s" "$pad_len" "")
      printf "${BLACK}%s${color}%s%s${RESET}" "$name " "$value" "$pad"
    fi
  else
    pad_len=$(( cw - ${#name} ))
    pad=$(printf "%*s" "$pad_len" "")
    printf "${BLACK}%s%s${RESET}" "$name" "$pad"
  fi
}

# Context window bar
if [ "${ctx_pct%.*}" != "-1" ] && [ -n "$ctx_pct" ]; then
  ctx_int="${ctx_pct%.*}"
  ctx_label=$(make_label "ctx" "${ctx_int}%" "$(severity_color "$ctx_int")")
  ctx_bar=$(render_bar "$ctx_int")
else
  ctx_label=$(make_label "ctx")
  ctx_bar="${BLACK}$(printf "%${COL_WIDTH}s" "" | tr ' ' '·')${RESET}"
fi

# Columns 2 & 3: subscription rate limits when present, else API session cost + burn rate
if [ "$ses_pct" -ge 0 ]; then
  # Subscription: pace-aware session/weekly bars
  col2_label=$(make_label "ses" "${ses_pct}%" "$(severity_color "$ses_pct" "$ses_diff")" "$ses_countdown" 13)
  col2_bar=$(render_bar "$ses_pct" "$ses_time_pct" "$ses_diff" 13)
  if [ "$wk_pct" -ge 0 ]; then
    col3_label=$(make_label "wk" "${wk_pct}%" "$(severity_color "$wk_pct" "$wk_diff")")
    col3_bar=$(render_bar "$wk_pct" "$wk_time_pct" "$wk_diff")
  else
    col3_label=$(make_label "wk")
    col3_bar="${BLACK}$(printf "%${COL_WIDTH}s" "" | tr ' ' '·')${RESET}"
  fi
elif [ -f "$SPEND_FILE" ]; then
  # API billing: day/week spend against soft budgets, paced against the
  # rolling average (avg daily over trailing 14 days / previous 7-day window)
  # via the same ideal-marker bars the subscription mode uses for time-pace.
  # spend_stats <value> <baseline> <budget> → "fmt<TAB>pct<TAB>ideal_pct<TAB>diff"
  # pct/ideal capped at 100 for bar geometry; diff (color) kept uncapped.
  function spend_stats() {
    awk -v v="$1" -v a="$2" -v b="$3" 'BEGIN {
      fmt = (v >= 100) ? sprintf("$%.0f", v) : sprintf("$%.2f", v)
      p = int(v * 100 / b); ip = int(a * 100 / b)
      diff = p - ip
      if (p > 100) p = 100
      if (ip > 100) ip = 100
      if (a > 0) printf "%s\t%d\t%d\t%d", fmt, p, ip, diff
      else       printf "%s\t%d\t\t",     fmt, p
    }'
  }

  IFS=$'\t' read -r day_fmt day_pct day_ideal day_diff <<< "$(spend_stats "$day_spend" "$avg_day" "$DAY_BUDGET_USD")"
  col2_label=$(make_label "day" "$day_fmt" "$(severity_color "$day_pct" "$day_diff")" "" 13)
  col2_bar=$(render_bar "$day_pct" "$day_ideal" "$day_diff" 13)

  IFS=$'\t' read -r wk_fmt wk_pct2 wk_ideal wk_diff2 <<< "$(spend_stats "$wk_spend" "$prev_wk" "$WK_BUDGET_USD")"
  col3_label=$(make_label "wk" "$wk_fmt" "$(severity_color "$wk_pct2" "$wk_diff2")")
  col3_bar=$(render_bar "$wk_pct2" "$wk_ideal" "$wk_diff2")
else
  # No rate limits and no cost data: empty states
  col2_label=$(make_label "ses" "" "" "" 14)
  col2_bar="${BLACK}$(printf "%14s" "" | tr ' ' '·')${RESET}"
  col3_label=$(make_label "wk")
  col3_bar="${BLACK}$(printf "%${COL_WIDTH}s" "" | tr ' ' '·')${RESET}"
fi

# ── Output ────────────────────────────────────────────────────────────────────

printf "%b\n%b  %b  %b\n%b  %b  %b" \
  "$status" \
  "$ctx_label" "$col2_label" "$col3_label" \
  "$ctx_bar" "$col2_bar" "$col3_bar"
