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

# Format token counts as e.g. "12k" or "1.2M"
format_tokens() {
    local n=$1
    if [ "$n" -ge 1000000 ]; then
        printf "%.1fM" "$(echo "scale=1; $n / 1000000" | bc)"
    elif [ "$n" -ge 1000 ]; then
        printf "%dk" "$(echo "scale=0; $n / 1000" | bc)"
    else
        printf "%d" "$n"
    fi
}

# Format a future Unix epoch as "Xh Ym" or "Ym Xs" relative to now
format_resets_in() {
    local epoch=$1
    local now
    now=$(date +%s)
    local diff=$(( epoch - now ))
    [ "$diff" -le 0 ] && { printf "now"; return; }
    local h=$(( diff / 3600 ))
    local m=$(( (diff % 3600) / 60 ))
    local s=$(( diff % 60 ))
    if [ "$h" -gt 0 ]; then
        printf "%dh %dm" "$h" "$m"
    elif [ "$m" -gt 0 ]; then
        printf "%dm %ds" "$m" "$s"
    else
        printf "%ds" "$s"
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
        total_input total_output used_pct \
        cost_usd duration_ms \
        rl5h_pct rl5h_resets \
        rl7d_pct rl7d_resets \
    < <(echo "$input" | jq -r '
        [
            (.model.display_name // .model.id // "unknown"),
            (.context_window.total_input_tokens // 0 | tostring),
            (.context_window.total_output_tokens // 0 | tostring),
            (.context_window.used_percentage // "null" | tostring),
            (.cost.total_cost_usd // "null" | tostring),
            (.cost.total_duration_ms // "null" | tostring),
            (.rate_limits.five_hour.used_percentage // "null" | tostring),
            (.rate_limits.five_hour.resets_at // "null" | tostring),
            (.rate_limits.seven_day.used_percentage // "null" | tostring),
            (.rate_limits.seven_day.resets_at // "null" | tostring)
        ] | @tsv
    ')

# --- model (dim) ---
line2="${DIM}${model}${RESET}"

# --- rate limits ---
rl_part=""

if [ "$rl5h_pct" != "null" ]; then
    color=$(pct_color "$rl5h_pct")
    reset_str=""
    [ "$rl5h_resets" != "null" ] && reset_str=" $(format_resets_in "$rl5h_resets")"
    rl_part="${rl_part}${color}5h:${rl5h_pct}%${reset_str}${RESET}"
fi

if [ "$rl7d_pct" != "null" ]; then
    [ -n "$rl_part" ] && rl_part="${rl_part}  "
    color=$(pct_color "$rl7d_pct")
    reset_str=""
    [ "$rl7d_resets" != "null" ] && reset_str=" $(format_resets_in "$rl7d_resets")"
    rl_part="${rl_part}${color}7d:${rl7d_pct}%${reset_str}${RESET}"
fi

[ -n "$rl_part" ] && line2="${line2}  ${rl_part}"

# --- context window usage ---
if [ "$used_pct" != "null" ]; then
    color=$(pct_color "$used_pct")
    in_fmt=$(format_tokens "$total_input")
    out_fmt=$(format_tokens "$total_output")
    line2="${line2}  ${color}ctx:${used_pct}%${RESET} ${DIM}${in_fmt}in ${out_fmt}out${RESET}"
else
    in_fmt=$(format_tokens "$total_input")
    out_fmt=$(format_tokens "$total_output")
    line2="${line2}  ${DIM}${in_fmt}in ${out_fmt}out${RESET}"
fi

# --- cost ---
if [ "$cost_usd" != "null" ] && [ "$cost_usd" != "0" ]; then
    cost_fmt=$(printf "\$%.2f" "$cost_usd")
    line2="${line2}  ${FG_MAGENTA}${cost_fmt}${RESET}"
fi

# --- session duration ---
if [ "$duration_ms" != "null" ] && [ "$duration_ms" != "0" ]; then
    total_s=$(( duration_ms / 1000 ))
    dur_m=$(( total_s / 60 ))
    dur_s=$(( total_s % 60 ))
    if [ "$dur_m" -gt 0 ]; then
        dur_fmt="${dur_m}m ${dur_s}s"
    else
        dur_fmt="${dur_s}s"
    fi
    line2="${line2}  ${DIM}${dur_fmt}${RESET}"
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

# %b interprets the \033 escapes in the color variables; content stays out of
# the format string so literal % (rate limits, ctx) isn't parsed as a directive.
printf '%b\n%b\n' "$line1" "$line2"
