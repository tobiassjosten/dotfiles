#!/bin/sh
# Bind one workspace to the one work item it is working on, and read that binding back.
# Shared by /next (writes), /ship (reads, then clears), /mill (clears on a skipped
# item), the /forge and /polish summaries (name it), the status line (shows ID and TITLE
# on every render), the SessionStart hook in settings.json (prints SOURCE, ID, BRANCH and
# `check` into each new session) and the work-item rules in claude/CLAUDE.md (set, check
# and clear for work started by hand), so the marker's path, format and validation live
# in one place.
#
# Usage:
#   task-marker.sh set --source <kind> --id <id> [--title <text>] [--base <commit>] [--force]
#   task-marker.sh get [<key>]     print the whole marker, or one key's value
#   task-marker.sh check           verify the marker against this workspace
#   task-marker.sh clear           remove the marker (silent when there is none)
#   task-marker.sh -h, --help      print the usage and exit
#
# The marker lives at $(git rev-parse --absolute-git-dir)/task.txt. That path resolves to
# .git in the main checkout and .git/worktrees/<name> in a linked worktree, so the binding
# is per-worktree on one machine and per-clone across machines without any extra plumbing —
# the same property that already scopes the review directory. It is inside .git, so it can
# never be committed, and `git worktree remove` takes it with the worktree it belongs to.
# In a linked worktree it is also under the main checkout, where a worktree-isolated
# session may not Edit, Write or `rm "$(git ...)/..."` — so every caller goes through this
# script, which the isolation checks let through (see review-state.sh for the details).
#
# It is a SIBLING of review/, not a child: /ship deletes the whole review directory as soon
# as its push succeeds, and only afterwards advances the task, so a marker stored under
# review/ would be gone before the step that needs the id.
# From a linked worktree, /commit removes the whole tree — this marker and review/ alike —
# after integrating, unless it keeps the tree, so /ship reads the marker before /commit
# runs, and never clears it there.
#
# KEY: value lines, one per line, matching the meta.txt written into each review run
# directory alongside it rather than the ledger's markdown. Keys:
#   SOURCE   the work-item source kind — backlog, todo, file, a tracker's name (linear,
#            jira), or whatever else a project documents. Lowercase token; not
#            validated against a fixed list, because /next's list of sources is
#            explicitly not exhaustive.
#   ID       the work item's id in that source. With SOURCE, this is what /ship acts on.
#   TITLE    a human label, for summaries and the statusline — and, for a todo item
#            whose ID is only a slug, what /next and /ship match the task line
#            against.
#            Optional. It is copied from the work-item source, so for a tracker it is
#            text anyone who can edit the item controls. The SessionStart hook leaves it
#            out, so it is not injected into every new session; a caller that reads the
#            marker (`get`) does see it.
#   BRANCH   the branch at claim time, or empty on a detached HEAD. `check` compares it
#            against the current branch — the one cross-check available locally.
#   BASE     the commit the work started from. Omitted in a repo with no commits yet.
#   CLAIMED  ISO date the marker was written.
#
# THE MARKER IS ADVISORY, AND THIS SCRIPT CANNOT MAKE IT AUTHORITATIVE. It records which
# item this workspace *believes* it owns; the tracker remains the only authority on who
# claimed what, and it is the only thing that can be seen from another machine. `check`
# therefore verifies what is checkable locally — the marker is present, well-formed, and
# names this branch — and callers must re-read the tracker before acting on the id. This
# is the deliberate difference from the review ledger, which is believed on sight: a stale
# ledger entry silently suppresses a finding, whereas a stale marker would point /ship at
# the wrong issue to close, so it is made loud instead of silent.
#
# Exit status: 0 success (including `clear` with nothing to remove, and -h/--help);
# 1 no marker, or `get <key>` for a key the marker does not carry; 2 bad usage, an invalid
# field value, or a `set` that would replace a different item's marker without --force;
# 3 `check` found a mismatch. A missing work tree is 1.
set -eu

# Owner-only, matching review-diff.sh: everything this script writes lands in the same
# per-worktree directory, and a marker carries a work item's title verbatim.
umask 077

usage() {
	cat <<-'EOF'
	usage: task-marker.sh <command> [options]
	  set --source <kind> --id <id> [--title <text>] [--base <commit>] [--force]
	                      bind this workspace to a work item
	  get [<key>]         print the whole marker, or one key's value
	                      (key names are case-insensitive: SOURCE ID TITLE BRANCH BASE CLAIMED)
	  check               verify the marker is present, well-formed and names this branch
	  clear               remove the marker
	  -h, --help          print this usage and exit
	EOF
}

die() { printf 'task-marker.sh: %s\n' "$1" >&2; exit "${2:-2}"; }

# Answered before the work-tree check, so the usage reads the same from anywhere.
case ${1:-} in
-h | --help)
	usage
	exit 0
	;;
"")
	usage >&2
	exit 2
	;;
esac

# --show-toplevel, not --absolute-git-dir: the latter succeeds in a bare repo, which has no
# workspace to bind and where every path below would mean something else. Same guard, and
# same reason, as review-diff.sh.
git rev-parse --show-toplevel >/dev/null 2>&1 ||
	die "not a git repository with a work tree" 1
marker=$(git rev-parse --absolute-git-dir)/task.txt

# Reject anything that would not survive the round trip through a KEY: value line. A value
# containing a newline would be read back as a truncated value plus a junk line — and for
# TITLE, which comes from a tracker and so from outside this repo, that junk line could be
# spelled to look like another field. Checked by comparing against the value with newlines
# stripped, because a `case` glob cannot match one.
validate() {
	_name=$1 _value=$2
	[ -n "$_value" ] || die "--${_name} must not be empty"
	[ "$_value" = "$(printf '%s' "$_value" | tr -d '\n\r')" ] ||
		die "--${_name} must not contain a newline"
}

# One key's value, or empty if the marker does not carry that key. Anchored on "KEY: " and
# splitting on the first occurrence only, so a TITLE containing a colon survives intact.
field() {
	sed -n "s/^$1: //p" "$marker" | head -1
}

cmd=${1:-}
[ $# -gt 0 ] && shift
case $cmd in
set)
	source= id= title= base= force=
	base_given=
	while [ $# -gt 0 ]; do
		case $1 in
		--source) [ $# -ge 2 ] || die "--source needs a value"; source=$2; shift 2 ;;
		--id) [ $# -ge 2 ] || die "--id needs a value"; id=$2; shift 2 ;;
		--title) [ $# -ge 2 ] || die "--title needs a value"; title=$2; shift 2 ;;
		--base) [ $# -ge 2 ] || die "--base needs a value"; base=$2; base_given=1; shift 2 ;;
		--force) force=1; shift ;;
		--source=* | --id=* | --title=* | --base=*)
			# The = form, so callers need not care which spelling this script prefers.
			_val=${1#*=}
			case $1 in
			--source=*) source=$_val ;;
			--id=*) id=$_val ;;
			--title=*) title=$_val ;;
			--base=*) base=$_val; base_given=1 ;;
			esac
			shift
			;;
		*) die "unknown option for set: $1" ;;
		esac
	done

	validate source "$source"
	validate id "$id"
	# A token, not free text: SOURCE routes /ship's Finish gate to a lifecycle, and a typo
	# there would send it down the wrong branch or none. Deliberately not checked against a
	# fixed list — /next calls its sources examples, not an exhaustive set.
	case $source in
	*[!a-z0-9-]* | -* | *- | "") die "--source must be a lowercase token (a-z, 0-9, -), got: $source" ;;
	esac
	[ -n "$title" ] && validate title "$title"

	if [ -n "$base_given" ]; then
		validate base "$base"
	else
		# Resolve rather than store "HEAD": the marker records where the work started, and
		# HEAD moves. Absent in a repo with no commits yet, which is not an error.
		base=$(git rev-parse HEAD 2>/dev/null) || base=
	fi

	# Refuse to silently retarget the workspace. Rewriting the same id is how /next refreshes
	# a marker after a rebase or a retitle, so that stays idempotent and needs no --force;
	# pointing it at a *different* item is the mistake this guard exists to catch, and in
	# phase 2 it is also where per-workspace WIP=1 bottoms out.
	if [ -e "$marker" ] && [ -z "$force" ]; then
		old_source=$(field SOURCE) old_id=$(field ID)
		if [ "$old_source" != "$source" ] || [ "$old_id" != "$id" ]; then
			printf 'task-marker.sh: this workspace is already bound to %s/%s\n' \
				"${old_source:-?}" "${old_id:-?}" >&2
			printf '  marker: %s\n' "$marker" >&2
			printf '  finish or clear it before binding %s/%s, or pass --force\n' \
				"$source" "$id" >&2
			exit 2
		fi
	fi

	# Empty on a detached HEAD, which `check` then holds the workspace to.
	branch=$(git branch --show-current)

	# Written whole and moved into place: a reader that catches a half-written marker would
	# see a plausible one missing its later fields, not an obvious failure. Same directory,
	# so the rename is atomic.
	tmp=$marker.$$
	trap 'rm -f "$tmp"' EXIT INT TERM HUP
	{
		printf 'SOURCE: %s\n' "$source"
		printf 'ID: %s\n' "$id"
		[ -n "$title" ] && printf 'TITLE: %s\n' "$title"
		printf 'BRANCH: %s\n' "$branch"
		[ -n "$base" ] && printf 'BASE: %s\n' "$base"
		printf 'CLAIMED: %s\n' "$(date +%Y-%m-%d)"
	} >"$tmp"
	mv -f "$tmp" "$marker"
	trap - EXIT INT TERM HUP
	cat "$marker"
	;;

get)
	[ $# -le 1 ] || die "get takes at most one key"
	[ -e "$marker" ] || die "no task marker in this workspace ($marker)" 1
	if [ $# -eq 0 ]; then
		cat "$marker"
	else
		# Case-insensitive so callers may write the lowercase key names used in prose.
		key=$(printf '%s' "$1" | tr 'a-z' 'A-Z')
		case $key in
		SOURCE | ID | TITLE | BRANCH | BASE | CLAIMED) ;;
		*) die "unknown key: $1 (SOURCE ID TITLE BRANCH BASE CLAIMED)" ;;
		esac
		value=$(field "$key")
		# TITLE and BASE are optional, so "absent" is a real answer and not a malformed
		# marker. Distinguished by exit status rather than by printing something, so a
		# caller can use the value unquoted in a substitution.
		[ -n "$value" ] || die "marker has no $key" 1
		printf '%s\n' "$value"
	fi
	;;

check)
	[ $# -eq 0 ] || die "check takes no arguments"
	[ -e "$marker" ] || die "no task marker in this workspace ($marker)" 1

	source=$(field SOURCE) id=$(field ID) recorded=$(field BRANCH) base=$(field BASE)
	status=0

	# A marker missing either of these cannot be acted on at all, so it fails the check
	# rather than being reported as a mismatch of something.
	[ -n "$source" ] || { printf 'malformed: no SOURCE\n'; status=3; }
	[ -n "$id" ] || { printf 'malformed: no ID\n'; status=3; }

	current=$(git branch --show-current)
	if [ "$recorded" != "$current" ]; then
		printf 'mismatch: marker names branch %s, workspace is on %s\n' \
			"${recorded:-(detached)}" "${current:-(detached)}"
		status=3
	fi

	# A base that no longer resolves means the history was rewritten under the marker — a
	# rebase, an amend, a dropped commit. The binding to the work item still holds, so this
	# is a note and not a failure; it is worth printing because it is the usual reason a
	# /polish convergence record stops matching.
	if [ -n "$base" ] && ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
		printf 'note: recorded base %s is no longer in this repository\n' "$base"
	fi

	if [ "$status" -eq 0 ]; then
		printf 'ok: %s/%s on %s\n' "$source" "$id" "${current:-(detached)}"
	fi
	# The tracker half is not checkable from here — say so on every failure, so a caller
	# that passes this check never reads it as more than it is.
	[ "$status" -eq 0 ] ||
		printf 'this check is local only; the tracker is still authoritative for %s/%s\n' \
			"${source:-?}" "${id:-?}"
	exit "$status"
	;;

clear)
	[ $# -eq 0 ] || die "clear takes no arguments"
	# Idempotent: /ship clears after a push, and a task that never wrote a marker (a change
	# made by hand) must not turn that into a failure.
	rm -f "$marker"
	;;

*)
	die "unknown command: $cmd (set, get, check, clear)"
	;;
esac
