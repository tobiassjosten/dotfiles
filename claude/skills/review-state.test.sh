#!/bin/sh
# Behavioural tests for review-state.sh — the one way the review skills locate, append to
# and delete the review directory and its ledger. Each case builds a throwaway repo under
# $TMPDIR and asserts on what the script printed, wrote and exited with. Nothing here
# touches the repo it lives in.
#
# Run it with `make check`, or directly: sh claude/skills/review-state.test.sh
#
# The exit codes are the contract: callers treat dir's and ledger's 1 as "nothing there"
# (no ledger line in a reviewer prompt, nothing to name in a summary), and append's 2 as
# "nothing written". So every case checks the exit status.
set -u

# Hermetic, for the same reasons as review-diff.test.sh.
GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_SYSTEM=/dev/null
GIT_ATTR_NOSYSTEM=1
GIT_CONFIG_NOSYSTEM=1
LC_ALL=C
export LC_ALL
export GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_ATTR_NOSYSTEM GIT_CONFIG_NOSYSTEM
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_ALTERNATE_OBJECT_DIRECTORIES \
	GIT_CEILING_DIRECTORIES GIT_TEMPLATE_DIR

script=$(cd "$(dirname "$0")" && pwd)/review-state.sh
# Two steps, each checked, for the reason given in review-diff.test.sh.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/review-state-test.XXXXXX") || exit 1
work=$(cd "$tmp" && pwd -P) || exit 1
trap 'rm -rf "$work"' EXIT
passed=0
failed=0

fail() {
	failed=$((failed + 1))
	echo "FAIL: $case_name: $1" >&2
	[ $# -gt 1 ] && shift && printf '      %s\n' "$@" >&2
	return 0
}

ok() { passed=$((passed + 1)); }

assert_eq() { # <expected> <actual> <what>
	if [ "$1" = "$2" ]; then ok; else fail "$3" "expected: $1" "actual:   $2"; fi
}

assert_contains() { # <haystack> <needle> <what>
	case $1 in
		*"$2"*) ok ;;
		*) fail "$3" "expected to contain: $2" "actual: $1" ;;
	esac
}

assert_absent() { # <path> <what>
	if [ -e "$1" ]; then fail "$2" "should not exist: $1"; else ok; fi
}

# A fresh repo with one commit, cd'd into.
new_repo() { # <name>
	repo=$work/$1
	mkdir -p "$repo"
	cd "$repo" || exit 1
	git init -q -b main .
	git config user.email test@example.com
	git config user.name Test
	echo base >base.md
	git add base.md
	git commit -qm base || { echo "FATAL: could not commit in a throwaway repo" >&2; exit 1; }
}

# Sets $out and $run_status; see review-diff.test.sh for why this is not `out=$(run)`.
run_status=0
out=""
run() { out=$(sh "$script" "$@" 2>&1); run_status=$?; }
run_in() { out=$(printf '%s' "$1" | sh "$script" append 2>&1); run_status=$?; }

settled='- settled: base=abc123 a.sh:1 — gist. Left as-is: user call. (2026-10-06)'
converged='- converged: tree=def456 from=abc123 coverage=delta — /polish left nothing open; fan-out plus delta. (2026-10-06)'

# --- usage ---------------------------------------------------------------------------
case_name="usage"
new_repo usage
run --help
assert_eq "0" "$run_status" "--help exits 0"
assert_contains "$out" "usage: review-state.sh" "--help prints the usage"
run
assert_eq "2" "$run_status" "no command exits 2"
run frobnicate
assert_eq "2" "$run_status" "an unknown command exits 2"
run dir extra
assert_eq "2" "$run_status" "dir takes no arguments"
cd "$work" || exit 1
run --help
assert_eq "0" "$run_status" "--help exits 0 outside a git repository too"
run dir
assert_eq "1" "$run_status" "outside a git repository it exits 1"
git init -q --bare "$work/bare.git"
cd "$work/bare.git" || exit 1
run dir
assert_eq "1" "$run_status" "in a bare repo it exits 1"

# --- dir and ledger: printed only when they exist -----------------------------------
case_name="locate"
new_repo locate
run dir
assert_eq "1" "$run_status" "dir exits 1 before anything created the directory"
run ledger
assert_eq "1" "$run_status" "ledger exits 1 when there is no ledger"
mkdir -p .git/review/20260101-000000-1
run dir
assert_eq "0" "$run_status" "dir exits 0 once the directory exists"
assert_eq "$repo/.git/review" "$out" "and prints its absolute path"
run ledger
assert_eq "1" "$run_status" "a review directory with run dirs only still has no ledger"

# --- append --------------------------------------------------------------------------
case_name="append"
new_repo append
run_in "$settled
$converged"
assert_eq "0" "$run_status" "append exits 0 on well-formed entries"
assert_eq "$settled
$converged" "$(cat .git/review/ledger.md)" "and writes them, creating the directory"
run ledger
assert_eq "$repo/.git/review/ledger.md" "$out" "ledger then prints its path"
run_in "- rejected: base=abc123 b.sh:2 — gist. Wrong because docs. (2026-10-06)"
assert_eq "0" "$run_status" "a second append exits 0"
assert_eq "3" "$(wc -l <.git/review/ledger.md | tr -d ' ')" "a second append adds to the ledger"
before=$(cat .git/review/ledger.md)
run_in "$settled
not an entry"
assert_eq "2" "$run_status" "a batch with a malformed line exits 2"
assert_contains "$out" "not a ledger entry" "and names the problem"
assert_eq "$before" "$(cat .git/review/ledger.md)" "and appends none of the batch"
run_in "- settled: a.sh:1 — no base. (2026-10-06)"
assert_eq "2" "$run_status" "a settled entry without base= is refused"
run_in "$settled

$settled"
assert_eq "2" "$run_status" "a blank line inside a batch is refused"
assert_eq "$before" "$(cat .git/review/ledger.md)" "and appends none of the batch"
run_in "
$settled"
assert_eq "2" "$run_status" "a leading blank line is refused"
run_in "- converged: tree=def456 coverage=full — no from. (2026-10-06)"
assert_eq "2" "$run_status" "a converged entry without from= is refused"
run_in "- converged: tree=def456 from= coverage=full — empty from. (2026-10-06)"
assert_eq "2" "$run_status" "a converged entry with an empty from= is refused"
run_in "- converged: tree=def456 from=abc123 coverage=partial — bad grade. (2026-10-06)"
assert_eq "2" "$run_status" "a converged entry with an unknown coverage grade is refused"
run_in ""
assert_eq "2" "$run_status" "empty stdin exits 2"
run append extra
assert_eq "2" "$run_status" "append takes no arguments"

# --- clear ---------------------------------------------------------------------------
case_name="clear"
new_repo clear
run_in "$settled"
assert_eq "0" "$run_status" "the seeding append exits 0"
mkdir -p .git/review/20260101-000000-1
run clear
assert_eq "0" "$run_status" "clear exits 0"
assert_eq "removed $repo/.git/review" "$out" "and says what it removed"
assert_absent "$repo/.git/review" "the whole directory is gone, ledger and runs"
run clear
assert_eq "0" "$run_status" "clear with nothing there still exits 0"
assert_eq "nothing to remove at $repo/.git/review" "$out" "and names where it looked"

# --- linked worktrees: one review directory per worktree ----------------------------
case_name="worktree"
new_repo worktree
main_repo=$repo
git worktree add -q -b feature "$work/worktree-feature"
run_in "$settled"
assert_eq "0" "$run_status" "the main checkout appends to its own ledger"
cd "$work/worktree-feature" || exit 1
run ledger
assert_eq "1" "$run_status" "the main checkout's ledger is not visible in a linked worktree"
run_in "$converged"
assert_eq "0" "$run_status" "a linked worktree appends to its own ledger"
run ledger
assert_eq "$main_repo/.git/worktrees/worktree-feature/review/ledger.md" "$out" "under .git/worktrees/<name>"
run clear
assert_eq "0" "$run_status" "the worktree's clear exits 0"
cd "$main_repo" || exit 1
assert_eq "$settled" "$(cat .git/review/ledger.md)" "clearing a worktree's directory leaves the main checkout's alone"

# --- report --------------------------------------------------------------------------
cd / || exit 1
echo "review-state.test.sh: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
