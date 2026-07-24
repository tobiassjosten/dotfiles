#!/bin/bash

# ANSI colors (will display dimmed in the status line)
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Foreground colors
FG_YELLOW='\033[33m'
FG_GREEN='\033[32m'
FG_RED='\033[31m'
FG_CYAN='\033[36m'
FG_BLUE='\033[34m'
FG_MAGENTA='\033[35m'
FG_WHITE='\033[97m'

input=$(cat)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Percentage of a rate-limit window already elapsed, given its reset epoch
# and total length in seconds. Clamped to 0-100.
window_time_pct() {
    local resets_at=$1
    local window_s=$2
    local now
    now=$(date +%s)
    local elapsed=$(( window_s - (resets_at - now) ))
    [ "$elapsed" -lt 0 ] && elapsed=0
    [ "$elapsed" -gt "$window_s" ] && elapsed=$window_s
    printf "%d" $(( elapsed * 100 / window_s ))
}

# Color for time-vs-usage pace: how far usage % runs ahead of elapsed time %.
# Green when on/behind pace, yellow/red when burning faster than the clock.
# Near the cap the absolute level predicts throttling regardless of pace,
# so high usage overrides: >=90% at least yellow, >=95% red.
pace_color() {
    local used=$1
    local time_pct=$2
    local used_int=${used%.*}
    local diff=$(( used_int - time_pct ))
    if [ "$used_int" -ge 95 ] || [ "$diff" -ge 20 ]; then
        printf '%s' "$FG_RED"
    elif [ "$used_int" -ge 90 ] || [ "$diff" -ge 10 ]; then
        printf '%s' "$FG_YELLOW"
    else
        printf '%s' "$FG_GREEN"
    fi
}

# Color a percentage value: green < 50, yellow < 80, red >= 80
pct_color() {
    local pct=$1
    local int=${pct%.*}
    if [ "$int" -ge 80 ]; then
        printf '%s' "$FG_RED"
    elif [ "$int" -ge 50 ]; then
        printf '%s' "$FG_YELLOW"
    else
        printf '%s' "$FG_GREEN"
    fi
}

# ---------------------------------------------------------------------------
# Line 1: directory + git info
# ---------------------------------------------------------------------------

cwd=$(echo "$input" | jq -r '.cwd')
dir=$(basename "$cwd")

line1="${BOLD}${FG_CYAN}${dir}${RESET}"

# Git info — use --no-optional-locks throughout to avoid contention
if git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks >/dev/null 2>&1; then
    branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
        || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)

    # Single porcelain call; reuse output for all marker checks
    status_output=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)

    markers=""

    # Conflicts (UU, AA, DD, AU, UA, UD, DU)
    if echo "$status_output" | grep -qE '^(DD|AU|UD|UA|DU|AA|UU)'; then
        markers="${markers}${FG_RED}!${RESET}"
    fi

    # Unstaged changes: second column is not space or ?
    has_unstaged=false
    if echo "$status_output" | grep -qE '^.[^ ?]'; then
        has_unstaged=true
        markers="${markers}${FG_YELLOW}*${RESET}"
    fi

    # Staged changes: first column is not space or ?
    # Show green star only when everything staged and nothing unstaged
    if echo "$status_output" | grep -qE '^[^ ?].'; then
        if ! $has_unstaged; then
            markers="${markers}${FG_GREEN}*${RESET}"
        fi
    fi

    # Untracked files
    if echo "$status_output" | grep -qE '^\?\?'; then
        markers="${markers}${DIM}?${RESET}"
    fi

    line1="${line1}  ${FG_BLUE}${branch}${RESET}"
    [ -n "$markers" ] && line1="${line1} ${markers}"
fi

# ---------------------------------------------------------------------------
# Line 2: Claude session info
# ---------------------------------------------------------------------------

# Parse all fields up front with a single jq call.
# Split on tabs only (model names contain spaces), and emit "null" for absent
# fields — an empty field would collapse its tab delimiters and shift the rest.
IFS=$'\t' read -r model \
        used_pct cost_usd \
        rl5h_pct rl5h_resets \
        rl7d_pct rl7d_resets \
    < <(echo "$input" | jq -r '
        def pct(v): if v == null then "null" else (v | round | tostring) end;
        [
            (.model.display_name // .model.id // "unknown"),
            pct(.context_window.used_percentage),
            (.cost.total_cost_usd // "null" | tostring),
            pct(.rate_limits.five_hour.used_percentage),
            (.rate_limits.five_hour.resets_at // "null" | tostring),
            pct(.rate_limits.seven_day.used_percentage),
            (.rate_limits.seven_day.resets_at // "null" | tostring)
        ] | @tsv
    ')

# --- model (dim) ---
line2="${DIM}${model}${RESET}"

# --- rate limits ---
rl_part=""

# Usage and time share one pace-based color so they always read as a pair;
# without a reset timestamp there is no pace, so fall back to absolute usage.
if [ "$rl5h_pct" != "null" ]; then
    time_str=""
    if [ "$rl5h_resets" != "null" ]; then
        time_pct=$(window_time_pct "$rl5h_resets" $(( 5 * 3600 )))
        color=$(pace_color "$rl5h_pct" "$time_pct")
        time_str=" ${color}t:${time_pct}%${RESET}"
    else
        color=$(pct_color "$rl5h_pct")
    fi
    rl_part="${rl_part}${color}5h:${rl5h_pct}%${RESET}${time_str}"
fi

if [ "$rl7d_pct" != "null" ]; then
    [ -n "$rl_part" ] && rl_part="${rl_part}  "
    time_str=""
    if [ "$rl7d_resets" != "null" ]; then
        time_pct=$(window_time_pct "$rl7d_resets" $(( 7 * 24 * 3600 )))
        color=$(pace_color "$rl7d_pct" "$time_pct")
        time_str=" ${color}t:${time_pct}%${RESET}"
    else
        color=$(pct_color "$rl7d_pct")
    fi
    rl_part="${rl_part}${color}7d:${rl7d_pct}%${RESET}${time_str}"
fi

[ -n "$rl_part" ] && line2="${line2}  ${rl_part}"

# --- context window usage ---
if [ "$used_pct" != "null" ]; then
    line2="${line2}  ${DIM}ctx:${used_pct}%${RESET}"
fi

# --- cost ---
if [ "$cost_usd" != "null" ] && [ "$cost_usd" != "0" ]; then
    cost_fmt=$(printf "\$%.2f" "$cost_usd")
    line2="${line2}  ${FG_MAGENTA}${cost_fmt}${RESET}"
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

# %b interprets the \033 escapes in the color variables; content stays out of
# the format string so literal % (rate limits, ctx) isn't parsed as a directive.
printf '%b\n%b\n' "$line1" "$line2"
