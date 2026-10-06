#!/bin/sh
# Behavioural tests for task-marker.sh — the binding between a workspace and the work
# item it is on, which /next writes, /ship resolves its Finish gate from and clears, the
# status line reads on every render and the SessionStart hook reads once per session.
# Each case builds a throwaway repo under $TMPDIR and asserts on what the script printed,
# wrote and exited with. Nothing here touches the repo it lives in.
#
# Run it with `make check`, or directly: sh claude/skills/task-marker.test.sh
#
# The exit codes are the contract: /ship branches on check's 1 (no marker, fall back)
# and 3 (mismatch, stop); /next and the claude/CLAUDE.md rule stop when get shows a
# different item bound, and /next falls back on set's 2 if one appears after that check.
# So every case checks the exit status.
set -u

# Hermetic, for the same reasons as review-diff.test.sh: no GIT_DIR leaking in from a
# rebase --exec, no developer config (commit signing would fail every commit here), and a
# C locale so grep and sed match bytes predictably.
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

script=$(cd "$(dirname "$0")" && pwd)/task-marker.sh
# Two steps, each checked, for the reason given in review-diff.test.sh.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/task-marker-test.XXXXXX") || exit 1
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

assert_file() { # <path> <what>
	if [ -f "$1" ]; then ok; else fail "$2" "missing file: $1"; fi
}

assert_absent() { # <path> <what>
	if [ -e "$1" ]; then fail "$2" "should not exist: $1"; else ok; fi
}

# A fresh repo with no commits at all, cd'd into.
empty_repo() { # <name> [initial-branch]
	repo=$work/$1
	mkdir -p "$repo"
	cd "$repo" || exit 1
	git init -q -b "${2:-main}" .
	git config user.email test@example.com
	git config user.name Test
}

# A fresh repo with one commit, cd'd into.
new_repo() { # <name> [initial-branch]
	empty_repo "$@"
	echo base >base.md
	git add base.md
	git commit -qm base || { echo "FATAL: could not commit in a throwaway repo" >&2; exit 1; }
}

marker_path() { printf '%s/task.txt' "$(git rev-parse --absolute-git-dir)"; }

# Sets $out and $run_status; see review-diff.test.sh for why this is not `out=$(run)`.
run_status=0
out=""
run() { out=$(sh "$script" "$@" 2>&1); run_status=$?; }

# --- usage ---------------------------------------------------------------------------
case_name="usage"
new_repo usage
run --help
assert_eq "0" "$run_status" "--help exits 0"
assert_contains "$out" "usage: task-marker.sh" "--help prints the usage"
run -h
assert_eq "0" "$run_status" "-h exits 0"
run
assert_eq "2" "$run_status" "no command exits 2"
run frobnicate
assert_eq "2" "$run_status" "an unknown command exits 2"
assert_contains "$out" "unknown command" "and names the problem"

cd "$work" || exit 1
run --help
assert_eq "0" "$run_status" "--help exits 0 outside a git repository too"
run get
assert_eq "1" "$run_status" "outside a git repository it exits 1"
assert_contains "$out" "not a git repository" "and says so"
git init -q --bare "$work/bare.git"
cd "$work/bare.git" || exit 1
run get
assert_eq "1" "$run_status" "in a bare repo it exits 1"
assert_contains "$out" "with a work tree" "and names the work tree as what is missing"

# --- set: writes every field, at the git dir ----------------------------------------
case_name="set"
new_repo set
head=$(git rev-parse HEAD)
# Dated either side of the run, so a run straddling midnight still matches one of them.
day_before=$(date +%Y-%m-%d)
run set --source linear --id INS-1 --title "Bind the workspace"
day_after=$(date +%Y-%m-%d)
claimed=$(grep '^CLAIMED: ' "$(marker_path)")
case $claimed in
	"CLAIMED: $day_before" | "CLAIMED: $day_after") ok ;;
	*) fail "CLAIMED is the day the marker was written" "actual: $claimed" ;;
esac
assert_eq "0" "$run_status" "set exits 0"
assert_file "$repo/.git/task.txt" "the marker is written into the git dir"
expected="SOURCE: linear
ID: INS-1
TITLE: Bind the workspace
BRANCH: main
BASE: $head
$claimed"
assert_eq "$expected" "$(cat "$(marker_path)")" "the marker carries every field"
assert_eq "$expected" "$out" "set prints the marker it wrote"
assert_eq "-rw-------" "$(ls -l "$(marker_path)" | cut -c1-10)" "the marker is owner-only"
assert_eq "" "$(ls "$(git rev-parse --absolute-git-dir)" | grep '^task\.txt\.')" "no temp file is left behind"

run set --source linear --id INS-1 --base abc123
assert_eq "0" "$run_status" "--base is accepted"
assert_eq "BASE: abc123" "$(grep '^BASE: ' "$(marker_path)")" "--base overrides HEAD"
assert_eq "" "$(grep '^TITLE: ' "$(marker_path)")" "TITLE is omitted when not given"

run set --source=backlog --id=TASK-7 --title=Equals --force
assert_eq "0" "$run_status" "the --opt=value form is accepted"
assert_eq "TASK-7" "$(sh "$script" get id)" "and sets the id"
assert_eq "Equals" "$(sh "$script" get title)" "and the title"

empty_repo set-unborn
run set --source todo --id first
assert_eq "0" "$run_status" "set works in a repo with no commits"
assert_eq "" "$(grep '^BASE: ' "$(marker_path)")" "BASE is omitted with no HEAD"

# --- set: validation -----------------------------------------------------------------
case_name="set validation"
new_repo validation
run set --source linear --id ""
assert_eq "2" "$run_status" "an empty --id exits 2"
run set --source linear --id INS-1 --title "two
lines"
assert_eq "2" "$run_status" "a newline in --title exits 2"
assert_contains "$out" "newline" "and names the newline"
run set --source Linear --id INS-1
assert_eq "2" "$run_status" "an uppercase --source exits 2"
run set --source "lin ear" --id INS-1
assert_eq "2" "$run_status" "a --source with a space exits 2"
run set --source linear --id
assert_eq "2" "$run_status" "a missing option value exits 2"
run set --source linear --id INS-1 --bogus
assert_eq "2" "$run_status" "an unknown option exits 2"
assert_absent "$(marker_path)" "no rejected set leaves a marker"

# --- set: rebinding ------------------------------------------------------------------
case_name="set rebinding"
new_repo rebind
sh "$script" set --source linear --id INS-1 --title Old >/dev/null
run set --source linear --id INS-1 --title New
assert_eq "0" "$run_status" "re-setting the same item needs no --force"
assert_eq "New" "$(sh "$script" get title)" "and refreshes the title"
before=$(cat "$(marker_path)")
run set --source linear --id INS-2
assert_eq "2" "$run_status" "binding a different item exits 2"
assert_contains "$out" "already bound to linear/INS-1" "and names the item already bound"
assert_eq "$before" "$(cat "$(marker_path)")" "and leaves the marker unchanged"
run set --source jira --id INS-1
assert_eq "2" "$run_status" "the same id in a different source is a different item"
run set --source linear --id INS-2 --force
assert_eq "0" "$run_status" "--force replaces the binding"
assert_eq "INS-2" "$(sh "$script" get id)" "with the new item"

# --- get -----------------------------------------------------------------------------
case_name="get"
new_repo get
run get
assert_eq "1" "$run_status" "get with no marker exits 1"
assert_contains "$out" "no task marker" "and says so"
sh "$script" set --source linear --id INS-3 --title "Fix: the colon: case" >/dev/null
run get
assert_eq "0" "$run_status" "get exits 0"
assert_eq "$(cat "$(marker_path)")" "$out" "get prints the whole marker"
run get ID
assert_eq "INS-3" "$out" "get <key> prints one value"
run get source
assert_eq "linear" "$out" "keys are case-insensitive"
run get title
assert_eq "Fix: the colon: case" "$out" "a title containing ': ' survives"
sh "$script" set --source linear --id INS-3 >/dev/null
run get title
assert_eq "1" "$run_status" "an absent optional key exits 1"
run get colour
assert_eq "2" "$run_status" "an unknown key exits 2"
run get id source
assert_eq "2" "$run_status" "more than one key exits 2"

# --- check ---------------------------------------------------------------------------
case_name="check"
new_repo check
run check
assert_eq "1" "$run_status" "check with no marker exits 1"
sh "$script" set --source linear --id INS-4 >/dev/null
run check
assert_eq "0" "$run_status" "check on the claimed branch exits 0"
assert_eq "ok: linear/INS-4 on main" "$out" "and reports ok"

git checkout -qb other
run check
assert_eq "3" "$run_status" "check on another branch exits 3"
assert_contains "$out" "mismatch: marker names branch main, workspace is on other" "and names both branches"
assert_contains "$out" "this check is local only" "and says the tracker is still authoritative"

git checkout -q --detach main
run check
assert_eq "3" "$run_status" "a detached HEAD against a recorded branch exits 3"
assert_contains "$out" "workspace is on (detached)" "and names the detached state"
git checkout -q main

printf 'SOURCE: linear\nBRANCH: main\n' >"$(marker_path)"
run check
assert_eq "3" "$run_status" "a marker without an ID exits 3"
assert_contains "$out" "malformed: no ID" "and says what is missing"

sh "$script" set --source linear --id INS-4 --force --base 0123456789abcdef0123456789abcdef01234567 >/dev/null
run check
assert_eq "0" "$run_status" "a base no longer in the repo still passes"
assert_contains "$out" "note: recorded base" "but is noted"

# --- clear ---------------------------------------------------------------------------
case_name="clear"
new_repo clear
sh "$script" set --source linear --id INS-5 >/dev/null
run clear
assert_eq "0" "$run_status" "clear exits 0"
assert_absent "$(marker_path)" "and removes the marker"
run clear
assert_eq "0" "$run_status" "clear with no marker still exits 0"
run clear now
assert_eq "2" "$run_status" "clear takes no arguments"

# --- linked worktrees: one marker per worktree --------------------------------------
case_name="worktree"
new_repo worktree
main_repo=$repo
git worktree add -q -b feature "$work/worktree-feature"
sh "$script" set --source linear --id MAIN-1 >/dev/null
cd "$work/worktree-feature" || exit 1
run get
assert_eq "1" "$run_status" "the main checkout's marker is not visible in a linked worktree"
run set --source linear --id TREE-1
assert_eq "0" "$run_status" "a linked worktree binds its own item without --force"
assert_file "$main_repo/.git/worktrees/worktree-feature/task.txt" "under .git/worktrees/<name>"
run check
assert_eq "ok: linear/TREE-1 on feature" "$out" "and checks against its own branch"
cd "$main_repo" || exit 1
assert_eq "MAIN-1" "$(sh "$script" get id)" "the main checkout keeps its own item"
cd "$work/worktree-feature" || exit 1
sh "$script" clear
cd "$main_repo" || exit 1
assert_eq "MAIN-1" "$(sh "$script" get id)" "clearing a worktree's marker leaves the main checkout's alone"

# --- report --------------------------------------------------------------------------
cd / || exit 1
echo "task-marker.test.sh: $passed passed, $failed failed"
[ "$failed" -eq 0 ]
