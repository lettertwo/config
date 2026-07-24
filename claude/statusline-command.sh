#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Soft spend budgets for API-billed accounts (bars fill toward these).
# Set to the p90 of observed spend on the API-billed machine (2026-07-24:
# 29 days, daily p50 $35 / p90 $152 / max $902; 23 rolling weeks, p50 $502 /
# p90 $1356 / max $1487), so roughly one day and one week in ten crosses the
# line. The previous $50/$250 dated from June and were 3-10x too low: both the
# fill and its pace marker capped at 100%, so the bars sat solid-thick nearly
# every day and reported nothing. Recalibrate by re-running the percentile
# pass over ~/.cache/claude-statusline-spend.json.
: "${DAY_BUDGET_USD:=150}"
: "${WK_BUDGET_USD:=1350}"

# Context zones in ABSOLUTE tokens, not percent of window. Effective context is
# a property of the model, not a fraction of its advertised window: a 1M window
# does not push degradation 5x later than a 200K one (RULER, NoLiMa, Chroma's
# context-rot report, and Anthropic's own "attention budget" framing all agree).
# Percent thresholds silently became meaningless when the 1M model arrived —
# 60% of 1M is 600K tokens, deep into degradation by any published account.
#
# These values are calibrated to THIS machine's observed usage rather than to
# the 32K-100K onset range in the literature, which would read red two-thirds
# of the time here and so tell us nothing. Measured over 6188 deduped requests
# across the 91 most recent transcripts (2026-07-24): p50 142K, p90 327K.
#   CTX_TYPICAL — median session; also where the bar switches scale
#   CTX_HEAVY   — p90; this session is unusual for us, act
# Recalibrate by re-running the percentile pass over ~/.claude/projects/*.jsonl.
: "${CTX_TYPICAL_TOK:=142000}"
: "${CTX_HEAVY_TOK:=327000}"

# Extract dir, context pct, model, session id/cost, and subscription
# rate limits (rate_limits.* is only present for subscription accounts —
# its absence means API billing). resets_at is epoch seconds; tonumber?
# guards against schema drift breaking the whole line.
# NOTE: fields must never be empty strings — tab is IFS whitespace, so read
# collapses consecutive tabs and empty fields shift everything after them.
# Absent values use sentinels ("-" / -1) instead.
IFS=$'\t' read -r dir ctx_pct model_name session_id cost_usd ses_pct ses_resets wk_pct wk_resets effort lines_add lines_del cache_read cache_creation in_tok ctx_tok ctx_win <<< "$(echo "$input" | jq -r '[
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
  (.cost.total_lines_removed // 0),
  (.context_window.current_usage.cache_read_input_tokens // 0),
  (.context_window.current_usage.cache_creation_input_tokens // 0),
  (.context_window.current_usage.input_tokens // 0),
  (.context_window.total_input_tokens // 0),
  (.context_window.context_window_size // 0)
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

# What this request's input actually cost, as a multiple of paying full
# uncached price: cache reads bill at 0.1x, cache writes at 1.25x, uncached
# input at 1.0x. 0.10x is the floor (every token served from cache); 1.25x is
# a fully cold write.
#
# This replaces a plain cache-HIT ratio, which is degenerate here: measured
# over 6188 deduped requests (2026-07-24), p50 is 99.2% and 94% of requests
# land above 90%, so a 0-100 bar spent ~90% of its cells on 6% of the data
# and rendered the middle 80% of requests identically. The multiplier has a
# hard floor, a tight normal band, and a real blowout tail (p50 0.11x,
# p90 0.16x, p99 1.25x) — and it rises as things get worse, matching every
# other column on the line.
#
# Held in THOUSANDTHS so the whole path stays integer — the 0.1/1.25/1.0 weights
# scale to 100/1250/1000 exactly, so this needs no awk. Like fmt_tok, it runs on
# every render. Worst case is ~1e9, well inside bash's signed 64-bit range.
ch_mult=-1
ch_total=$(( ${cache_read:-0} + ${cache_creation:-0} + ${in_tok:-0} ))
if [ "$ch_total" -gt 0 ]; then
  ch_mult=$(( ( ${cache_read:-0} * 100 + ${cache_creation:-0} * 1250
                + ${in_tok:-0} * 1000 + ch_total / 2 ) / ch_total ))
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

  # Floor a nonzero percentage at one cell: integer division otherwise draws
  # an entirely empty bar below 100/cw percent (9% of 8 cells = 0), which reads
  # as "no data" rather than "barely started".
  local filled=$(( pct * cw / 100 ))
  if [ "$filled" -eq 0 ] && [ "$pct" -gt 0 ]; then filled=1; fi

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
# An empty name is allowed: the ctx column leads with its value, since a token
# count is self-identifying where "91%" or "$36.05" would not be.
function make_label() {
  local name="$1"
  local value="${2:-}"
  local color="${3:-}"
  local suffix="${4:-}"
  local cw="${5:-$COL_WIDTH}"
  local pad pad_len prefix=""

  if [ -n "$name" ]; then prefix="${name} "; fi

  if [ -n "$value" ]; then
    local text="${prefix}${value}"
    if [ -n "$suffix" ]; then
      local suffix_with_space=" ${suffix}"
      pad_len=$(( cw - ${#text} - ${#suffix_with_space} ))
      if [ "$pad_len" -lt 0 ]; then pad_len=0; fi
      pad=$(printf "%*s" "$pad_len" "")
      printf "${BLACK}%s${color}%s%s${BLACK}%s${RESET}" "$prefix" "$value" "$pad" "$suffix_with_space"
    else
      pad_len=$(( cw - ${#text} ))
      if [ "$pad_len" -lt 0 ]; then pad_len=0; fi
      pad=$(printf "%*s" "$pad_len" "")
      printf "${BLACK}%s${color}%s%s${RESET}" "$prefix" "$value" "$pad"
    fi
  else
    pad_len=$(( cw - ${#name} ))
    pad=$(printf "%*s" "$pad_len" "")
    printf "${BLACK}%s%s${RESET}" "$name" "$pad"
  fi
}

# label_width <name> [value] [suffix] — visible chars of the assembled label;
# each bar sizes to exactly its label's text, floored at 6 so empty/short
# columns keep a legible bar
function label_width() {
  local t="$1"
  if [ -n "${2:-}" ]; then t="$t $2"; fi
  if [ -n "${3:-}" ]; then t="$t $3"; fi
  local w=${#t}
  if [ "$w" -lt 6 ]; then w=6; fi
  printf "%s" "$w"
}

# dot_bar <width> — dim placeholder bar for columns with no data
function dot_bar() {
  printf "${BLACK}%s${RESET}" "$(printf "%*s" "$1" "" | tr ' ' '·')"
}

# fmt_tok <tokens> — compact magnitude: 850 / 452k / 1.2M. Integer math rather
# than awk: this runs on every render and needs no subprocess.
function fmt_tok() {
  local t="$1"
  if [ "$t" -ge 1000000 ]; then
    local tenths=$(( t / 100000 ))
    printf "%d.%dM" "$(( tenths / 10 ))" "$(( tenths % 10 ))"
  elif [ "$t" -ge 1000 ]; then
    printf "%dk" "$(( t / 1000 ))"
  else
    printf "%d" "$t"
  fi
}

# ch_zone_color <mult_x1000> — thresholds sit at the measured p90 (0.16x) and
# just past p95 (0.25x), so blue is "normal", yellow is "worse than nine runs
# in ten", and red is the ~4% of requests where caching genuinely failed.
function ch_zone_color() {
  local m="$1"
  if   [ "$m" -lt 160 ]; then printf "%s" "$BLUE"
  elif [ "$m" -lt 300 ]; then printf "%s" "$YELLOW"
  else                        printf "%s" "$RED"
  fi
}

# render_ch_bar <mult_x1000> <width> — log scale on the multiplier's EXCESS over
# the 0.10x floor, i.e. on what the cache failed to save. Driving the bar from
# the same number as the label keeps the two from ever disagreeing.
#
# The excess spans nearly five decades (p1 0.0001, p50 0.009, max 1.15), so the
# low anchor is the measured p25 rather than zero: below that there is nothing
# to report and the bar stays empty. Empty is unambiguous here because the
# no-data state draws dots, not dashes.
CH_BAR_FLOOR=0.004   # p25 of observed excess
CH_BAR_CEIL=1.15     # excess at 1.25x — a fully cold request
function render_ch_bar() {
  local m="$1" cw="$2" f out="" i
  f=$(awk -v m="$m" -v c="$cw" -v lo="$CH_BAR_FLOOR" -v hi="$CH_BAR_CEIL" 'BEGIN{
    e = m/1000 - 0.1
    if (e < lo) { print 0; exit }
    r = log(e/lo)/log(hi/lo); if (r>1) r=1
    v = int(r*c + 0.5); if (v==0) v=1; if (v>c) v=c; print v }')
  local zone
  zone=$(ch_zone_color "$m")
  for (( i=0; i<cw; i++ )); do
    if [ "$i" -lt "$f" ]; then out+="${zone}${BAR_FILLED}"
    else out+="${BLACK}${BAR_THIN}"; fi
  done
  printf "%b${RESET}" "$out"
}

# ctx_zone_color <tokens> — absolute-token zones (see CTX_* above), replacing
# the percent-of-window thresholds severity_color applies to the other columns.
function ctx_zone_color() {
  local t="$1"
  if   [ "$t" -lt "$CTX_TYPICAL_TOK" ]; then printf "%s" "$BLUE"
  elif [ "$t" -lt "$CTX_HEAVY_TOK" ];   then printf "%s" "$YELLOW"
  else                                       printf "%s" "$RED"
  fi
}

# render_ctx_bar <tokens> <window> <width> — two-scale bar. The head is linear
# 0→CTX_TYPICAL; past that the tail is LOG-scaled to the window, because a
# linear tail wastes its cells (100K-400K collapses into one) exactly where
# the compact/handoff call gets urgent. Cell budget follows observed usage:
# ~half of requests fall either side of the median, so the head and tail get
# comparable width. The scale change needs no divider glyph: the head draws
# thick and the log tail draws thin, reusing the same weight vocabulary the
# pace bars use for "past the marker".
function render_ctx_bar() {
  local tok="$1" win="$2" cw="$3"

  # Window at or below the scale change: no second scale to show, stay linear.
  if [ "$win" -le "$CTX_TYPICAL_TOK" ]; then
    render_bar $(( tok * 100 / win )) "" "" "$cw"
    return
  fi

  local seg1=$(( cw * 5 / 11 ))
  if [ "$seg1" -lt 2 ]; then seg1=2; fi
  if [ "$seg1" -gt $(( cw - 1 )) ]; then seg1=$(( cw - 1 )); fi
  local seg2=$(( cw - seg1 ))

  local f1 f2 i out=""
  if [ "$tok" -lt "$CTX_TYPICAL_TOK" ]; then
    f1=$(( tok * seg1 / CTX_TYPICAL_TOK ))
    if [ "$f1" -eq 0 ] && [ "$tok" -gt 0 ]; then f1=1; fi
    f2=0
  else
    f1=$seg1
    # ceil so any overage lights at least one tail cell
    f2=$(awk -v t="$tok" -v d="$CTX_TYPICAL_TOK" -v w="$win" -v c="$seg2" 'BEGIN{
      r = log(t/d)/log(w/d); if (r<0) r=0; if (r>1) r=1
      v = int(r*c + 0.999); if (v==0) v=1; if (v>c) v=c; print v }')
  fi

  # The whole bar carries the current zone colour — it reports state now, not
  # the history of how the context filled. Weight still separates the scales:
  # thick for the linear head, thin for the log tail.
  #
  # The head draws its FULL width thick, dim where unfilled, so the thick/thin
  # boundary sits at CTX_TYPICAL on every render rather than only once the head
  # fills. That restores the scale-change marker the divider glyph used to give
  # us, and reuses render_bar's existing "thick dim = budget remaining" idiom.
  local zone
  zone=$(ctx_zone_color "$tok")
  for (( i=0; i<seg1; i++ )); do
    if [ "$i" -lt "$f1" ]; then out+="${zone}${BAR_FILLED}"
    else out+="${BLACK}${BAR_FILLED}"; fi
  done
  for (( i=0; i<seg2; i++ )); do
    if [ "$i" -lt "$f2" ]; then out+="${zone}${BAR_THIN}"
    else out+="${BLACK}${BAR_THIN}"; fi
  done
  printf "%b${RESET}" "$out"
}

# Context window bar — leads with the absolute token count, ratio subordinate:
# the count is what drives clear/compact/handoff, and the pair pins the window
# size (1M vs 200k) without spending characters on a denominator.
if [ "${ctx_pct%.*}" != "-1" ] && [ -n "$ctx_pct" ] && [ "${ctx_tok:-0}" -gt 0 ]; then
  ctx_int="${ctx_pct%.*}"
  ctx_val=$(fmt_tok "$ctx_tok")
  ctx_w=$(label_width "ctx" "$ctx_val")
  ctx_label=$(make_label "ctx" "$ctx_val" "$(ctx_zone_color "$ctx_tok")" "" "$ctx_w")
  if [ "${ctx_win:-0}" -gt 0 ]; then
    ctx_bar=$(render_ctx_bar "$ctx_tok" "$ctx_win" "$ctx_w")
  else
    ctx_bar=$(render_bar "$ctx_int" "" "" "$ctx_w")
  fi
else
  ctx_w=$(label_width "ctx")
  ctx_label=$(make_label "ctx" "" "" "" "$ctx_w")
  ctx_bar=$(dot_bar "$ctx_w")
fi

# Cache bar: label is the input-cost multiplier, bar is how far above the
# 0.10x floor it sits. Both rise together, and with the rest of the line.
if [ "$ch_mult" -ge 0 ]; then
  # thousandths → hundredths, rounded; 109 → "0.11x", 1250 → "1.25x"
  ch_hun=$(( (ch_mult + 5) / 10 ))
  ch_val=$(printf "%d.%02dx" "$(( ch_hun / 100 ))" "$(( ch_hun % 100 ))")
  ch_w=$(label_width "ch" "$ch_val")
  ch_label=$(make_label "ch" "$ch_val" "$(ch_zone_color "$ch_mult")" "" "$ch_w")
  ch_bar=$(render_ch_bar "$ch_mult" "$ch_w")
else
  ch_w=$(label_width "ch")
  ch_label=$(make_label "ch" "" "" "" "$ch_w")
  ch_bar=$(dot_bar "$ch_w")
fi

# Columns 2 & 3: subscription rate limits when present, else API session cost + burn rate
if [ "$ses_pct" -ge 0 ]; then
  # Subscription: pace-aware session/weekly bars
  col2_w=$(label_width "ses" "${ses_pct}%" "$ses_countdown")
  col2_label=$(make_label "ses" "${ses_pct}%" "$(severity_color "$ses_pct" "$ses_diff")" "$ses_countdown" "$col2_w")
  col2_bar=$(render_bar "$ses_pct" "$ses_time_pct" "$ses_diff" "$col2_w")
  if [ "$wk_pct" -ge 0 ]; then
    col3_w=$(label_width "wk" "${wk_pct}%")
    col3_label=$(make_label "wk" "${wk_pct}%" "$(severity_color "$wk_pct" "$wk_diff")" "" "$col3_w")
    col3_bar=$(render_bar "$wk_pct" "$wk_time_pct" "$wk_diff" "$col3_w")
  else
    col3_w=$(label_width "wk")
    col3_label=$(make_label "wk" "" "" "" "$col3_w")
    col3_bar=$(dot_bar "$col3_w")
  fi
elif [ -f "$SPEND_FILE" ]; then
  # API billing: day/week spend against soft budgets, paced against the
  # rolling average (avg daily over trailing 14 days / previous 7-day window)
  # via the same ideal-marker bars the subscription mode uses for time-pace.
  # Thickness marks the rolling average, colour marks actual spend — the same
  # grammar the ctx bar's head uses for its threshold.
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
  col2_w=$(label_width "day" "$day_fmt")
  col2_label=$(make_label "day" "$day_fmt" "$(severity_color "$day_pct" "$day_diff")" "" "$col2_w")
  col2_bar=$(render_bar "$day_pct" "$day_ideal" "$day_diff" "$col2_w")

  IFS=$'\t' read -r wk_fmt wk_pct2 wk_ideal wk_diff2 <<< "$(spend_stats "$wk_spend" "$prev_wk" "$WK_BUDGET_USD")"
  col3_w=$(label_width "wk" "$wk_fmt")
  col3_label=$(make_label "wk" "$wk_fmt" "$(severity_color "$wk_pct2" "$wk_diff2")" "" "$col3_w")
  col3_bar=$(render_bar "$wk_pct2" "$wk_ideal" "$wk_diff2" "$col3_w")
else
  # No rate limits and no cost data: empty states
  col2_w=$(label_width "ses")
  col2_label=$(make_label "ses" "" "" "" "$col2_w")
  col2_bar=$(dot_bar "$col2_w")
  col3_w=$(label_width "wk")
  col3_label=$(make_label "wk" "" "" "" "$col3_w")
  col3_bar=$(dot_bar "$col3_w")
fi

# ── Output ────────────────────────────────────────────────────────────────────

printf "%b\n%b  %b  %b  %b\n%b  %b  %b  %b" \
  "$status" \
  "$ctx_label" "$ch_label" "$col2_label" "$col3_label" \
  "$ctx_bar" "$ch_bar" "$col2_bar" "$col3_bar"
