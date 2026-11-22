#!/bin/sh
# Find the GitHub Actions runs a push started, and watch one of them to its
# end, so /ship can report every run's result after it publishes
# (ship/SKILL.md § 4). It is agnostic to what the workflows do: every run
# GitHub registers against the pushed commit on the pushed branch counts, a
# deploy or a lint alike. The branch keeps out the runs an earlier push of the
# same commit started elsewhere, such as the feature branch it came from.
#
# Usage: push-runs.sh <sha> <branch> [seconds]
#        push-runs.sh --watch <run-id> [seconds]
#
# Both forms ask gh about the repository `origin` points at, where /ship
# pushes, rather than the one gh picks itself, which in a fork's clone may be
# its upstream.
#
# The first form polls `gh run list --commit <sha> --branch <branch>` every
# PUSH_RUNS_INTERVAL seconds (default 5) for up to <seconds> (default 30). Runs
# do not register the instant a push lands, and several workflows triggered by
# one push register a few seconds apart, so once the first appears it polls once
# more before answering. It prints one tab-separated line per run — id, workflow
# name, event, URL — and nothing when no run registered within the window; a run
# that registers later is not seen. A run with no workflow name (one a ruleset
# workflow started) is named `run <id>`, here and below.
#
# The second form polls `gh run view <run-id>` every PUSH_RUNS_WATCH_INTERVAL
# seconds (default 30) for up to <seconds> (default 1800) and prints one line
# naming the workflow, branch and commit, so a result arriving long after the
# ship still says which push it belongs to:
#   <workflow> on <branch> @ <sha7>: <conclusion> — <url>
# or, for a run still going when the time is up (one waiting on an approval,
# say), the status it was last seen in:
#   <workflow> on <branch> @ <sha7>: still <status> after <n> min — <url>
# (<n> s when the time given is not whole minutes).
# A gh failure while watching is retried on the next poll. When the last poll
# failed, the status last read may be stale, so the line says so instead:
#   <workflow> on <branch> @ <sha7>: last seen <status>, then gh failed — <url>
#
# Exit status: 0 with the runs, none, or the run's line; 1 on a usage error,
# an unknown commit or no `origin` remote; 2 when gh failed — on a lookup's
# poll before any run was found, or on a watch's last poll, after the
# last-seen line if any poll read the run — with its message on stderr. A
# failure here never stops a ship: the caller reports the runs as not watched
# and goes on.
set -u

usage() {
	echo "usage: push-runs.sh <sha> <branch> [seconds]" >&2
	echo "       push-runs.sh --watch <run-id> [seconds]" >&2
	exit 1
}

number() {
	case $1 in '' | *[!0-9]*) usage ;; esac
}

# The workflow name, or `run <id>` for a run that has none.
label='(if (.workflowName // "") == "" then "run \(.databaseId)"
	else .workflowName end)'

list() {
	gh run list --repo "$repo" --commit "$sha" --branch "$branch" --limit 100 \
		--json databaseId,workflowName,event,url \
		--jq ".[] | [.databaseId, $label, .event, .url] | @tsv"
}

view() {
	gh run view "$run" --repo "$repo" \
		--json databaseId,status,conclusion,workflowName,headBranch,headSha,url \
		--jq "[.status, .conclusion, $label, .headBranch,
			.headSha[0:7], .url] | map(tostring) | join(\"\\u001f\")"
}

lookup() {
	if ! git cat-file -e "$sha^{commit}" 2>/dev/null; then
		echo "push-runs.sh: no such commit: $sha" >&2
		exit 1
	fi
	deadline=$(($(date +%s) + window))
	while :; do
		runs=$(list) || exit 2
		if [ -n "$runs" ]; then
			# A failure here keeps what the first poll found.
			sleep "$interval"
			more=$(list) && [ -n "$more" ] && runs=$more
			printf '%s\n' "$runs"
			exit 0
		fi
		[ "$(date +%s)" -lt "$deadline" ] || exit 0
		sleep "$interval"
	done
}

watch() {
	# Not a tab: IFS collapses runs of whitespace, which would shift every
	# field after an empty conclusion.
	sep=$(printf '\037')
	deadline=$(($(date +%s) + window))
	seen=
	while :; do
		fresh=
		if line=$(view 2>"$err"); then
			seen=$line fresh=1
			IFS=$sep read -r status conclusion name branch head url <<EOF
$line
EOF
			if [ "$status" = completed ]; then
				echo "$name on $branch @ $head: $conclusion — $url"
				exit 0
			fi
		fi
		[ "$(date +%s)" -lt "$deadline" ] || break
		sleep "$interval"
	done
	if [ -z "$seen" ]; then
		echo "push-runs.sh: run $run could not be read:" >&2
		cat "$err" >&2
		exit 2
	fi
	if [ -z "$fresh" ]; then
		echo "$name on $branch @ $head: last seen $status, then gh failed — $url"
		cat "$err" >&2
		exit 2
	fi
	if [ $((window % 60)) -eq 0 ]; then
		after="$((window / 60)) min"
	else
		after="${window} s"
	fi
	echo "$name on $branch @ $head: still $status after $after — $url"
	exit 0
}

origin() {
	if ! repo=$(git remote get-url origin 2>/dev/null); then
		echo "push-runs.sh: no origin remote" >&2
		exit 1
	fi
}

[ $# -ge 1 ] || usage
if [ "$1" = --watch ]; then
	[ $# -ge 2 ] && [ $# -le 3 ] || usage
	run=$2
	window=${3:-1800}
	interval=${PUSH_RUNS_WATCH_INTERVAL:-30}
	number "$run"
	number "$window"
	number "$interval"
	origin
	err=$(mktemp "${TMPDIR:-/tmp}/push-runs.XXXXXX")
	trap 'rm -f "$err"' EXIT
	watch
fi
[ $# -ge 2 ] && [ $# -le 3 ] || usage
sha=$1
branch=$2
window=${3:-30}
interval=${PUSH_RUNS_INTERVAL:-5}
[ -n "$branch" ] || usage
number "$window"
number "$interval"
origin
lookup
