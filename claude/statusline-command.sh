#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract current directory and context window percentage
read -r dir ctx_pct model_name <<< "$(echo "$input" | jq -r '[.workspace.current_dir, (.context_window.used_percentage // -1), (.model.display_name // "")] | @tsv')"

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
RESET='\033[0m'

# Unicode symbols
GIT_BRANCH_ICON="󰘬"
FOLDER_ICON="󰝰"
MODEL_ICON="󰚩"
BAR_FILLED="━"
BAR_THIN="─"
COL_WIDTH=10

# ── Left side: dir + git branch ──────────────────────────────────────────────

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

  # Format output with colors and icons
  if [ -n "$branch" ]; then
    left="${BLACK}${FOLDER_ICON} ${dir_display}${RESET} ${BRIGHT_BLACK}${GIT_BRANCH_ICON} ${branch}${RESET}"
  else
    left="${BLACK}${FOLDER_ICON} ${dir_display}${RESET}"
  fi
else
  # Not a git repo - just show directory
  left="${BLACK}${FOLDER_ICON} ${basename}${RESET}"
fi

# Prepend model name if available
if [ -n "$model_name" ]; then
  left="${CYAN}${MODEL_ICON} ${model_name}${RESET} ${left}"
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

# ── Cache API usage (session + weekly) ───────────────────────────────────────

CACHE_FILE="/tmp/claude-statusline-usage.json"
LOCK_DIR="/tmp/claude-statusline-usage.lock"
CACHE_TTL=60

# Check if cache is stale or missing
function cache_is_stale() {
  if [ ! -f "$CACHE_FILE" ]; then return 0; fi
  local mtime now age
  mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null) || return 0
  now=$(date +%s)
  age=$(( now - mtime ))
  [ "$age" -ge "$CACHE_TTL" ]
}

# Refresh cache in background (mkdir-based locking, no flock on macOS)
# Only one process will succeed in creating the lock dir and refreshing the cache;
# others will skip if they fail to acquire the lock.
function maybe_refresh_cache() {
  # Clean up stale lock (older than 2 minutes)
  if [ -d "$LOCK_DIR" ]; then
    local lock_age
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -gt 120 ]; then
      rmdir "$LOCK_DIR" 2>/dev/null
    fi
  fi

  if mkdir "$LOCK_DIR" 2>/dev/null; then
    (
      trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
      token=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null \
        | jq -r '.claudeAiOauth.accessToken' 2>/dev/null)
      if [ -n "$token" ] && [ "$token" != "null" ]; then
        response=$(curl -sf --max-time 10 \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/2.0.32" \
          "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ -n "$response" ]; then
          echo "$response" > "$CACHE_FILE"
        fi
      fi
    ) &
    disown 2>/dev/null || true
  fi
}

if cache_is_stale; then
  maybe_refresh_cache
fi

# ── Read cached session/weekly pcts ──────────────────────────────────────────

ses_pct=-1
wk_pct=-1
ses_resets_at=""
wk_resets_at=""

if [ -f "$CACHE_FILE" ]; then
  read -r ses_pct wk_pct ses_resets_at wk_resets_at <<< "$(jq -r '[
    ((.five_hour.utilization // -1) | floor),
    ((.seven_day.utilization // -1) | floor),
    (.five_hour.resets_at // ""),
    (.seven_day.resets_at // "")
  ] | @tsv' "$CACHE_FILE" 2>/dev/null)"
fi

# Compute signed diffs: positive = burning faster than time elapsed
ses_diff=""
ses_time_pct=""
wk_diff=""
wk_time_pct=""
now_ts=$(date +%s)

ses_countdown=""
if [ "$ses_pct" -ge 0 ] && [ -n "$ses_resets_at" ] && [ "$ses_resets_at" != "null" ]; then
  reset_ts=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${ses_resets_at%%.*}" "+%s" 2>/dev/null)
  if [ -n "$reset_ts" ]; then
    elapsed=$(( now_ts - (reset_ts - 18000) ))
    if [ $elapsed -lt 0 ]; then elapsed=0; fi
    if [ $elapsed -gt 18000 ]; then elapsed=18000; fi
    ses_time_pct=$(( elapsed * 100 / 18000 ))
    ses_diff=$(( ses_pct - ses_time_pct ))
    remaining=$(( reset_ts - now_ts ))
    if [ "$remaining" -gt 0 ]; then
      hrs=$(( remaining / 3600 ))
      mins=$(( (remaining % 3600) / 60 ))
      ses_countdown="${hrs}h${mins}m"
    fi
  fi
fi

if [ "$wk_pct" -ge 0 ] && [ -n "$wk_resets_at" ] && [ "$wk_resets_at" != "null" ]; then
  reset_ts=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "${wk_resets_at%%.*}" "+%s" 2>/dev/null)
  if [ -n "$reset_ts" ]; then
    elapsed=$(( now_ts - (reset_ts - 604800) ))
    if [ $elapsed -lt 0 ]; then elapsed=0; fi
    if [ $elapsed -gt 604800 ]; then elapsed=604800; fi
    wk_time_pct=$(( elapsed * 100 / 604800 ))
    wk_diff=$(( wk_pct - wk_time_pct ))
  fi
fi

# ── Render bars ───────────────────────────────────────────────────────────────

# severity_color <pct> [diff] — unified color: pace-aware when diff given, else pct thresholds
function severity_color() {
  local pct="$1" diff="${2:-}"
  if [ -n "$diff" ]; then
    local adiff=$(( diff < 0 ? -diff : diff ))
    if   [ "$adiff" -gt 20 ]; then printf "%s" "$RED"
    elif [ "$adiff" -gt  5 ]; then printf "%s" "$YELLOW"
    else                           printf "%s" "$BLUE"
    fi
  else
    if   [ "$pct" -lt 75 ]; then printf "%s" "$BLUE"
    elif [ "$pct" -lt 90 ]; then printf "%s" "$YELLOW"
    else                         printf "%s" "$RED"
    fi
  fi
}

# make_label <name> [pct] [diff] [suffix] [col_width] — label padded to col_width visible chars
# name is BLACK; pct uses escalating color; suffix (e.g. countdown) rendered in BLACK
function make_label() {
  local name="$1"
  local pct="${2:-}"
  local diff="${3:-}"
  local suffix="${4:-}"
  local cw="${5:-$COL_WIDTH}"
  local color pad pad_len

  if [ -n "$pct" ]; then
    color=$(severity_color "$pct" "$diff")
    local text="${name} ${pct}%"
    if [ -n "$suffix" ]; then
      local suffix_with_space=" ${suffix}"
      pad_len=$(( cw - ${#text} - ${#suffix_with_space} ))
      if [ "$pad_len" -lt 0 ]; then pad_len=0; fi
      pad=$(printf "%*s" "$pad_len" "")
      printf "${BLACK}%s${color}%s%%%s${BLACK}%s${RESET}" "$name " "$pct" "$pad" "$suffix_with_space"
    else
      pad_len=$(( cw - ${#text} ))
      pad=$(printf "%*s" "$pad_len" "")
      printf "${BLACK}%s${color}%s%%%s${RESET}" "$name " "$pct" "$pad"
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
  ctx_label=$(make_label "ctx" "$ctx_int")
  ctx_bar=$(render_bar "$ctx_int")
else
  ctx_label=$(make_label "ctx")
  ctx_bar="${BLACK}$(printf "%${COL_WIDTH}s" "" | tr ' ' '·')${RESET}"
fi

# Session bar
if [ "$ses_pct" -ge 0 ]; then
  ses_label=$(make_label "ses" "$ses_pct" "$ses_diff" "$ses_countdown" 13)
  ses_bar=$(render_bar "$ses_pct" "$ses_time_pct" "$ses_diff" 13)
else
  ses_label=$(make_label "ses" "" "" "" 14)
  ses_bar="${BLACK}$(printf "%14s" "" | tr ' ' '·')${RESET}"
fi

# Weekly bar
if [ "$wk_pct" -ge 0 ]; then
  wk_label=$(make_label "wk" "$wk_pct" "$wk_diff")
  wk_bar=$(render_bar "$wk_pct" "$wk_time_pct" "$wk_diff")
else
  wk_label=$(make_label "wk")
  wk_bar="${BLACK}$(printf "%${COL_WIDTH}s" "" | tr ' ' '·')${RESET}"
fi

# ── Output ────────────────────────────────────────────────────────────────────

printf "%b\n%b  %b  %b\n%b  %b  %b" \
  "$left" \
  "$ctx_label" "$ses_label" "$wk_label" \
  "$ctx_bar" "$ses_bar" "$wk_bar"
