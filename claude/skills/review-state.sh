#!/bin/sh
# Locate, append to and delete the review directory and its ledger. Shared by /review,
# /polish, /ship, /forge, /mill and the review orchestration in review-fanout.md, so every
# write to that directory goes through one plain command.
#
# Usage:
#   review-state.sh dir            print the review directory, if it exists
#   review-state.sh ledger         print the ledger's path, if it exists
#   review-state.sh append         append ledger entries read from stdin, one per line
#   review-state.sh clear          delete the whole review directory, printing its path
#   review-state.sh -h, --help     print the usage and exit
#
# The directory is $(git rev-parse --absolute-git-dir)/review — the same root review-diff.sh
# writes its run directories under, computed the same way — with the ledger at
# review/ledger.md (format and lifecycle: review-fanout.md § The review ledger). In a
# linked worktree that resolves to <main>/.git/worktrees/<name>/review: inside the main
# checkout, so a worktree-isolated Claude Code session may not touch it with Edit or
# Write, nor with a shell command that nests `$(git ...)` inside another command — the
# harness's isolation checks refuse both and cannot be configured to allow them. A plain
# `sh review-state.sh <command>` passes those checks, which is why the skills mutate this
# directory only through here (and read it with a literal path this script printed), the
# same way task-marker.sh owns task.txt next to it.
#
# Exit status: 0 success (including `clear` with nothing to remove, and -h/--help);
# 1 the directory or ledger does not exist (dir, ledger), or no work tree; 2 bad usage,
# or an `append` entry that is not a well-formed ledger line — in which case nothing is
# appended.
set -eu

# Owner-only, matching review-diff.sh, which creates this directory in the first place: the
# ledger records the user's own review decisions.
umask 077

usage() {
	cat <<-'EOF'
	usage: review-state.sh <command>
	  dir                 print the review directory, if it exists
	  ledger              print the ledger's path, if it exists
	  append              append ledger entries from stdin (one "- <kind>: ..." line each)
	  clear               delete the whole review directory
	  -h, --help          print this usage and exit
	EOF
}

die() { printf 'review-state.sh: %s\n' "$1" >&2; exit "${2:-2}"; }

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

# --show-toplevel, not --absolute-git-dir, for the reason given in task-marker.sh.
git rev-parse --show-toplevel >/dev/null 2>&1 ||
	die "not a git repository with a work tree" 1
root=$(git rev-parse --absolute-git-dir)/review
ledger=$root/ledger.md

cmd=${1:-}
[ $# -gt 0 ] && shift
case $cmd in
dir)
	[ $# -eq 0 ] || die "dir takes no arguments"
	[ -d "$root" ] || die "no review directory ($root)" 1
	printf '%s\n' "$root"
	;;

ledger)
	[ $# -eq 0 ] || die "ledger takes no arguments"
	[ -f "$ledger" ] || die "no ledger ($ledger)" 1
	printf '%s\n' "$ledger"
	;;

append)
	[ $# -eq 0 ] || die "append takes no arguments; pass the entries on stdin"
	# Read whole, validated whole, then written: a batch with one malformed line appends
	# nothing, so a caller never has to work out which half of its batch landed.
	entries=$(cat)
	[ -n "$entries" ] || die "no entries on stdin"
	# Every line must open as one of the four entry kinds, keyed the way readers match them:
	# base= ties settled/rejected/decided to a change, and /ship matches converged on
	# tree= and from=. A line that opens any other way would be a ledger entry no reader
	# can expire, so it is refused rather than stored.
	# Numbered, so a blank line reports as "<n>:" — unnumbered, the substitution would strip
	# it to nothing and the batch would pass with it.
	bad=$(printf '%s\n' "$entries" | grep -Evn '^- ((settled|rejected|decided): base=[^ ]+ |converged: tree=[^ ]+ from=[^ ]+ coverage=(full|delta) )' | head -1)
	[ -z "$bad" ] || die "not a ledger entry (see review-fanout.md § The review ledger), line $bad"
	case $entries in
	*"$(printf '\r')"*) die "entries must not contain a carriage return" ;;
	esac
	mkdir -p "$root"
	printf '%s\n' "$entries" >>"$ledger"
	printf '%s\n' "$entries"
	;;

clear)
	[ $# -eq 0 ] || die "clear takes no arguments"
	# Idempotent, like task-marker.sh clear: /ship calls it after every successful push from
	# the main checkout (from a linked worktree, /commit removes this with the tree, unless
	# it keeps the tree), including for a change that was never reviewed and so never
	# created the directory.
	# Names the path either way, so a caller can report where it looked.
	if [ -e "$root" ]; then
		rm -rf "$root"
		printf 'removed %s\n' "$root"
	else
		printf 'nothing to remove at %s\n' "$root"
	fi
	;;

*)
	die "unknown command: $cmd (dir, ledger, append, clear)"
	;;
esac
