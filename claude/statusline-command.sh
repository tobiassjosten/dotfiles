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

# Longest instruction shown on line 3 before it is ellipsised.
PROMPT_MAX=100

# Longest work-item title shown on line 1 before it is ellipsised. Shorter than
# PROMPT_MAX: the title shares its line with the directory and git state, and
# the id next to it is the part that identifies the item.
TASK_TITLE_MAX=40

# How many lines from the end of the transcript to search before giving up and
# rereading the whole file. `tail -r` has to buffer all of its input, and a
# transcript grows without bound during a long session, so the window keeps the
# common case flat (measured: 53MB -> 7MB peak RSS on a 46MB transcript).
#
# Size this against the depth of the instruction the search *accepts*, not the
# newest "user" record — the machine-generated turns filtered out below sit
# between them, so the accepted one is much deeper. Measured over the 255
# transcripts here that have one: median 21, p90 103, max 928 lines from the
# end. 2000 therefore leaves roughly 2x headroom, and none needed the fallback.
PROMPT_SCAN_LINES=2000

# Line 3 answers "what stage are we at, and why is Claude busy?", so it ignores
# turns that don't drive the work and keeps walking back to the one that does.
#
# Skipped commands: read-only inspection (/tasks, /cost, /context), session
# plumbing (/resume, /login, /doctor) and asides (/btw — "a quick side question
# without interrupting the main conversation"). Everything absent from this
# list shows, so a new personal skill needs no change here.
PROMPT_SKIP_COMMANDS='add-dir|agents|alias|artifacts|btw|bug|chrome|compact|config|context|cost|doctor|effort|exit|export|fast|feedback|help|hooks|ide|install-github-app|keybindings|login|logout|mcp|memory|model|output-style|permissions|plugin|privacy-settings|quit|release-notes|remote-control|resume|rewind|sandbox|status|statusline|tasks|terminal-setup|todo|todos|upgrade|usage|vim|worktree'

# Bare nudges and acknowledgements that carry no new instruction. Matched
# whole, case-insensitively, ignoring trailing punctuation — so "go" is
# skipped but "go with option B" still shows.
PROMPT_SKIP_PROSE='y|yes|yep|yeah|ok|okay|sure|go|go on|go ahead|proceed|continue|resume|carry on|keep going|do it|please continue|please do|thanks|thank you|ty|done|nice|good|great|perfect'

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
    # Two values from one call: the label to print, and the branch name on its
    # own. The task marker below records a branch and leaves it empty on a
    # detached HEAD, so comparing it against the SHA this falls back to would
    # report a mismatch where there is none.
    head_branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null) \
        || head_branch=""
    branch=${head_branch:-$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)}

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

    # --- the work item this workspace is bound to ---
    # /next writes a marker into the git dir naming the item it claimed and
    # /ship clears it once the push lands, so a marker present means "this
    # workspace is mid-item" and its id is the answer to "what are we on?".
    # It belongs on this line rather than the session line below: the binding
    # is per-worktree state living in .git, like everything else here.
    #
    # Read through task-marker.sh, which is where the marker's location and
    # validation are defined, instead of reaching into .git/task.txt — one
    # `get` costs ~30ms of a ~390ms render against ~15ms for a hand-rolled
    # read, which buys not having to track that path in a second place. Only
    # the "KEY: value" shape is re-read here, by the same anchored prefix the
    # script matches on, so a title containing ": " survives.
    task_marker=""
    # $0 is the deployed path, ~/.claude/statusline-command.sh, so the skills
    # directory is its sibling. Made absolute here because the `get` below runs
    # from $cwd, where a relative path would resolve against the wrong root.
    task_marker_sh=$(cd "$(dirname "$0")" 2>/dev/null \
        && printf '%s/skills/task-marker.sh' "$PWD")
    if [ -f "$task_marker_sh" ]; then
        # Exit 1 is the ordinary "no marker" answer, and anything on stderr
        # (not a repo, a malformed field) is for /next and /ship to report,
        # not for a status line to render.
        task_marker=$( (cd "$cwd" && sh "$task_marker_sh" get) 2>/dev/null )
    fi

    if [ -n "$task_marker" ]; then
        # TITLE comes from a tracker, so it is outside text on its way to
        # printf '%b', and the script's own validation only rejects newlines.
        # Clean and clip it the way line 3 cleans an instruction, and for the
        # same reasons: Cc for the control characters that would recolour or
        # rewrite the line, Cf for the bidi overrides that would reorder it,
        # and the clip in jq so a multi-byte character cannot be cut in half.
        # One field per line rather than the @tsv used for line 2's fields: two
        # of these three are optional, and tab is an IFS whitespace character,
        # so an empty field would collapse its delimiters and shift a branch
        # name into the title. A line each needs no sentinel to avoid that,
        # and clean() below has already taken the newlines out of the values.
        { read -r task_id; read -r task_branch; read -r task_title; } < <(
            printf '%s\n' "$task_marker" | jq -Rrn --argjson max "$TASK_TITLE_MAX" '
                def clean:
                    gsub("[\\p{Cc}\\p{Cf}]"; " ") | gsub("\\s+"; " ")
                    | gsub("^\\s+|\\s+$"; "");
                def clip:
                    if (length > $max) then .[0:$max - 1] + "\u2026" else . end;
                reduce inputs as $line ({};
                    if   $line | startswith("ID: ")     then .id     = $line[4:]
                    elif $line | startswith("TITLE: ")  then .title  = $line[7:]
                    elif $line | startswith("BRANCH: ") then .branch = $line[8:]
                    else . end)
                | (.id // "" | clean), (.branch // "" | clean),
                  (.title // "" | clean | clip)
            ' 2>/dev/null
        )
        task_id=${task_id//\\/\\\\}
        task_title=${task_title//\\/\\\\}
        task_branch=${task_branch//\\/\\\\}

        # The marker is advisory — the tracker is the authority on who claimed
        # what — and task-marker.sh deliberately makes a bad one loud rather
        # than silent, because /ship acting on a stale id closes the wrong
        # item. So the two states it can diagnose locally are shown in red: a
        # marker that names a branch other than the one checked out (with that
        # branch, so the mismatch is actionable), and one with no id at all,
        # which no longer names anything. Its remaining note — a BASE that has
        # left the repository — changes nothing about which item this is.
        if [ -z "$task_id" ]; then
            line1="${line1}  ${FG_RED}◆ ?${RESET}"
        elif [ "$task_branch" != "$head_branch" ]; then
            line1="${line1}  ${FG_RED}◆ ${task_id} @${task_branch:-(detached)}${RESET}"
        else
            line1="${line1}  ${BOLD}${FG_WHITE}◆ ${task_id}${RESET}"
            [ -n "$task_title" ] && line1="${line1} ${DIM}${task_title}${RESET}"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Parse the status payload (line 2's fields, plus the transcript for line 3)
# ---------------------------------------------------------------------------

# Parse all fields up front with a single jq call.
# Split on tabs only (model names contain spaces), and emit "null" for absent
# fields — an empty field would collapse its tab delimiters and shift the rest.
IFS=$'\t' read -r transcript_path model \
        used_pct cost_usd \
        rl5h_pct rl5h_resets \
        rl7d_pct rl7d_resets \
    < <(echo "$input" | jq -r '
        def pct(v): if v == null then "null" else (v | round | tostring) end;
        [
            (.transcript_path // "null"),
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

# --- branched conversation ---
# /branch (and `f` from a /btw aside) forks the session: Claude Code copies the
# transcript into a new file and stamps every copied record with the
# `forkedFrom` provenance of the conversation it came from. The copy is always a
# prefix of the new file, so line 1 carries the stamp whenever this session is a
# branch — one line read, nothing to scan in the common unbranched case. The
# trunk's short session id rides along in the marker because `claude -r <id>` is
# how you get back to it.
#
# Only this kind of branch is detectable: a /rewind continues in the same
# transcript, and `claude --resume --fork-session` records no provenance.
if [ "$transcript_path" != "null" ] && [ -f "$transcript_path" ]; then
    fork_parent=$(head -n 1 "$transcript_path" 2>/dev/null \
        | jq -Rr 'fromjson? | try (.forkedFrom.sessionId) catch empty
                  | select(type == "string")' 2>/dev/null)
    # The stamp reaches printf '%b' further down, so accept it only in the shape
    # it is meant to have: a UUID, of which the marker shows the first block.
    [[ $fork_parent =~ ^[0-9a-f]{8}-[0-9a-f-]+$ ]] || fork_parent=""
    [ -n "$fork_parent" ] \
        && line2="${line2}  ${FG_YELLOW}⑂ ${fork_parent:0:8}${RESET}"
fi

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
# Line 3: the instruction Claude is currently working on
# ---------------------------------------------------------------------------

# Walk the transcript backwards to the most recent thing the user actually
# typed, so the status line says *why* Claude is busy. Everything else that
# lands in a "user" turn is machine-generated and must be skipped: tool
# results, subagent traffic (isSidechain), injected context (isMeta),
# compaction summaries (isCompactSummary), task notifications, the stdout of
# `!` and local commands, and the synthetic
# "[Request interrupted by user]" records written when you press ESC.
#
# A slash command reaches the transcript either wrapped in <command-name>
# tags or as a bare "/name" string. Both forms occur for the same command
# (/review shows up 68 times bare and 19 times tagged here), and which one
# Claude Code writes is not something this script can predict, so both
# branches have to stay. Either way it is rendered differently from prose.
#
# Turns that don't explain the current work (see PROMPT_SKIP_* above) are
# stepped over, so an aside or a status check never displaces the `/forge`
# command or instruction actually driving the session.
read -r -d '' last_prompt_jq <<'JQ'
def body:
    if (.message.content | type) == "string" then .message.content
    else [.message.content[]? | select(.type == "text") | .text] | join("\n")
    end;

# Flatten to a single printable line. Cc catches the C0/C1 controls (ESC from
# pasted terminal output, BEL, ...) that would otherwise reach the terminal
# through printf '%b' and recolour or rewrite the status line; Cf catches the
# format controls, notably bidi overrides like U+202E, which reorder or hide
# text without being control characters.
def clean:
    gsub("[\\p{Cc}\\p{Cf}]"; " ") | gsub("\\s+"; " ") | gsub("^\\s+|\\s+$"; "");

# A slash command, once split into name and arguments. /clear ends the search
# rather than continuing past it: it wipes the conversation, so an instruction
# from before it is not what Claude is working on now.
def command_line($n; $a):
    ($n | ascii_downcase) as $lower
    | if $lower == "clear" then ["stop", ""]
      elif $lower | test("^(" + $skipcmd + ")$") then empty
      else ["cmd", "/" + $n + (if ($a | length) > 0 then " " + $a else "" end)]
      end;

def as_command:
    (capture("<command-name>(?<n>[^<]*)</command-name>").n | clean | ltrimstr("/")) as $n
    # Non-greedy rather than [^<]*, so arguments may themselves contain "<".
    | ([match("<command-args>(.*?)</command-args>"; "m").captures[0].string]
        | first // "" | clean) as $a
    | command_line($n; $a);

def as_prose:
    gsub("<system-reminder>.*?</system-reminder>"; ""; "m")
    | gsub("<pasted_content[^>]*>.*?</pasted_content[^>]*>"; "[pasted]"; "m")
    | clean
    | select(test("^<(task-notification|local-command-[a-z]+|bash-[a-z]+|command-message|agent-message|system-reminder)\\b") | not)
    # Pressing ESC writes a user turn carrying only this marker. It is the
    # moment line 3 matters most, so step over it to the real instruction.
    | select(test("^\\[Request interrupted by user") | not)
    | select(length > 0)
    # Only a bare "/name" with nothing trailing counts as a command. Anything
    # after it means prose that merely opens with a slash — "/tmp/foo.log has
    # the error", "/clear the build cache first" — which must not be split at
    # the next slash, dropped by the skip list, or, for /clear, mistaken for
    # the stop sentinel and blank the line. Costs nothing: no bare command
    # carries arguments in any of the 1910 transcripts here; the tagged form
    # is where arguments turn up.
    | if test("^/[A-Za-z0-9_:-]+$") then
        command_line(ltrimstr("/"); "")
      else
        select(ascii_downcase | gsub("[.!?,\\s]+$"; "")
               | test("^(" + $skipprose + ")$") | not)
        | ["text", .]
      end;

# Truncate here rather than in bash: jq slices by codepoint, so a multi-byte
# character can never be cut in half.
def clip:
    if (length > $max) then .[0:$max - 1] + "\u2026" else . end;

first(
    # Raw lines parsed individually: Claude Code appends to the transcript
    # while the status line renders, so a render can catch a half-written
    # line. fromjson? drops it instead of aborting the whole program, which
    # would blank line 3 outright.
    inputs
    | fromjson?
    # Per-record tolerance for unexpected shapes, so the jq call needs no
    # blanket 2>/dev/null: compile and --arg errors still reach stderr. A
    # *runtime* error in here is swallowed like any unexpected record, so a
    # bug below this point shows up as a silently missing line 3.
    | try (
        select(.type == "user" and (.isMeta | not) and (.isSidechain | not)
               and (.isCompactSummary | not))
        | body
        | select(type == "string" and length > 0)
        # Anchored: a command turn always opens with the tag block. An
        # unanchored match would route prose that merely mentions
        # <command-name> into as_command, where the capture fails and the
        # turn vanishes silently.
        | if test("^\\s*<command-(name|message)>") then as_command else as_prose end
        | .[0] + "\t" + (.[1] | clip)
      ) catch empty
) // ""
JQ

line3=""
if [ "$transcript_path" != "null" ] && [ -f "$transcript_path" ]; then
    # Runs "$@" to emit the transcript, newest line last. tail -r then feeds
    # jq newest-first so `first` stops at the newest match. The echo
    # guarantees a trailing newline: Claude Code appends while the status line
    # renders, and tail -r would otherwise splice a half-written final line
    # onto the record before it, destroying the newest *complete* entry along
    # with the fragment.
    scan_transcript() {
        # The redirect covers one race: the transcript being rotated or
        # deleted between the [ -f ] test above and this read.
        { "$@"; echo; } 2>/dev/null | tail -r \
            | jq -Rrn --argjson max "$PROMPT_MAX" \
                     --arg skipcmd "$PROMPT_SKIP_COMMANDS" \
                     --arg skipprose "$PROMPT_SKIP_PROSE" \
                     "$last_prompt_jq"
    }

    # The window answers in every realistic case; the whole-file pass is the
    # safety net, and only runs when the window found nothing at all.
    prompt_raw=$(scan_transcript tail -n "$PROMPT_SCAN_LINES" "$transcript_path")
    [ -n "$prompt_raw" ] || prompt_raw=$(scan_transcript cat "$transcript_path")
    IFS=$'\t' read -r prompt_kind prompt_text <<< "$prompt_raw"

    # "stop" is the /clear sentinel: search terminated, deliberately no line 3.
    if [ "$prompt_kind" != "stop" ] && [ -n "$prompt_text" ]; then
        # The instruction is arbitrary text but is printed with %b, which would
        # otherwise expand a literal backslash sequence the user typed.
        prompt_text=${prompt_text//\\/\\\\}
        # Commands get full weight; prose recedes like the other dim metadata.
        if [ "$prompt_kind" = "cmd" ]; then
            line3="${DIM}❯${RESET} ${BOLD}${FG_WHITE}${prompt_text}${RESET}"
        else
            line3="${DIM}❯ ${prompt_text}${RESET}"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------

# %b interprets the \033 escapes in the color variables; content stays out of
# the format string so literal % (rate limits, ctx) isn't parsed as a directive.
printf '%b\n%b\n' "$line1" "$line2"
if [ -n "$line3" ]; then
    printf '%b\n' "$line3"
fi
