#!/usr/bin/env bash
# Stop-hook notification: ring the tmux pane's bell when the main session is
# genuinely idle and waiting for input.
#
# Claude Code stops the main session at points where work is still in flight —
# a backgrounded subagent, a workflow, a `run_in_background` shell task, or a
# scheduled wakeup all park the turn, let it stop, and wake it again later.
# Ringing on every Stop therefore notifies several times per piece of work. The
# Stop payload carries the two fields needed to tell those apart:
#
#   background_tasks  In-flight background work, already filtered by the harness
#                     to status running/pending and backgrounded; absent or empty
#                     when nothing is in flight. Each entry carries a `type`.
#   session_crons     Scheduled work that will wake this session later
#                     (CronCreate, ScheduleWakeup, /loop). `recurring: false`
#                     marks a one-shot wakeup: the session resumes on its own.
#
# Fails open: an unparseable payload or a missing jq rings, degrading to the
# unconditional bell this replaced rather than going silent. Exits 0 on every
# path and writes nothing to stdout — a Stop hook's stdout lands in the
# transcript.

# Background-task types that do NOT count as unfinished work. These are ambient
# watchers that can stay in flight for the rest of the session; letting them
# suppress the bell would mute notifications entirely. Everything else —
# subagent, workflow, shell, teammate, MCP task, cloud session, auto-mode scan —
# is bounded work and does suppress.
AMBIENT_TYPES='["monitor", "dream"]'

payload="$(cat)"

if command -v jq >/dev/null 2>&1; then
	jq -e --argjson ambient "$AMBIENT_TYPES" '
		(.hook_event_name == "Stop")
		and ([(.background_tasks // [])[] | select(.type as $t | $ambient | index($t) | not)] | length == 0)
		and ([(.session_crons // [])[] | select(.recurring == false)] | length == 0)
	' >/dev/null 2>&1 <<<"$payload"
	# 0 = idle, ring. 1 = still working, stay quiet. Anything else is jq failing
	# on the payload, which falls through to the bell.
	[ $? -eq 1 ] && exit 0
fi

[ -n "$TMUX_PANE" ] && printf '\a' > "$(tmux display-message -t "$TMUX_PANE" -p '#{pane_tty}')"
exit 0
