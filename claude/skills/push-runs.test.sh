#!/bin/sh
# Behavioural tests for push-runs.sh — the lookup /ship runs after a push to
# find the workflow runs it started, and the watch it runs in the background
# for each. The cases run in a throwaway repo under $TMPDIR with a fake `gh`
# first on PATH, so nothing here reaches GitHub or touches the repo it lives
# in. The fake needs jq, which the Brewfile installs.
#
# Run it with `make check`, or directly: sh claude/skills/push-runs.test.sh
set -u

GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_SYSTEM=/dev/null
LC_ALL=C
export GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM LC_ALL
unset GIT_DIR GIT_WORK_TREE

script=$(cd "$(dirname "$0")" && pwd)/push-runs.sh
tmp=$(mktemp -d "${TMPDIR:-/tmp}/push-runs-test.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fails=0

fail() {
	echo "FAIL: $1" >&2
	fails=$((fails + 1))
}

# The fake gh stands in for `gh run list` and `gh run view`. Its Nth call
# answers from $tmp/answers: N.fail makes that call fail and `fail` every
# call; otherwise N.json (or `default.json`, or an empty list) is the JSON
# GitHub would return. Like gh, it keeps only the fields --json names,
# refuses one gh does not have, and applies --jq to the rest, so the script's
# real field list and jq expression are what produce its output. Each call's
# arguments are appended to $tmp/args, one call per line.
mkdir "$tmp/bin"
cat >"$tmp/bin/gh" <<'EOF'
#!/bin/sh
n=$(($(cat "$FAKE_GH/calls" 2>/dev/null || echo 0) + 1))
echo "$n" >"$FAKE_GH/calls"
echo "$*" >>"$FAKE_GH/args"
a=$FAKE_GH/answers
if [ -e "$a/fail" ] || [ -e "$a/$n.fail" ]; then
	echo "gh: not logged in" >&2
	exit 4
fi
fields= filter=
while [ $# -gt 0 ]; do
	case $1 in
	--json) fields=$2; shift ;;
	--jq) filter=$2; shift ;;
	esac
	shift
done
known=databaseId,workflowName,event,url,status,conclusion,headBranch,headSha
for f in $(echo "$fields" | tr ',' ' '); do
	case ",$known," in *",$f,"*) ;; *)
		echo "Unknown JSON field: \"$f\"" >&2
		exit 1
	esac
done
if [ -e "$a/$n.json" ]; then json=$a/$n.json
elif [ -e "$a/default.json" ]; then json=$a/default.json
else json=/dev/null; fi
{ cat "$json"; [ -s "$json" ] || echo '[]'; } |
	jq --arg f "$fields" '
		($f | split(",")) as $keep
		| def pick: with_entries(select(.key as $k | $keep | index($k)));
		if type == "array" then map(pick) else pick end' |
	jq -r "$filter"
EOF
chmod +x "$tmp/bin/gh"
PATH=$tmp/bin:$PATH
FAKE_GH=$tmp
PUSH_RUNS_INTERVAL=0
PUSH_RUNS_WATCH_INTERVAL=0
export PATH FAKE_GH PUSH_RUNS_INTERVAL PUSH_RUNS_WATCH_INTERVAL

reset_gh() {
	rm -rf "$tmp/answers" "$tmp/calls" "$tmp/args"
	mkdir "$tmp/answers"
}

answer() {
	cat >"$tmp/answers/$1"
}

run() {
	out=$(sh "$script" "$@" 2>"$tmp/err")
	status=$?
}

# One variable set for one run: `VAR=x run` would leave VAR set afterwards,
# since sh keeps an assignment made in front of a function call.
run_env() {
	assignment=$1
	shift
	out=$(env "$assignment" sh "$script" "$@" 2>"$tmp/err")
	status=$?
}

calls() {
	cat "$tmp/calls" 2>/dev/null || echo 0
}

git init -q "$tmp/repo"
cd "$tmp/repo" || exit 1
echo x >x
git add -A
git -c user.name=t -c user.email=t@t commit -qm init
sha=$(git rev-parse HEAD)

ci='{"databaseId": 1, "workflowName": "CI", "event": "push",
	"url": "https://x/1", "status": "queued"}'
deploy='{"databaseId": 2, "workflowName": "Deploy", "event": "push",
	"url": "https://x/2"}'
tab=$(printf '\t')

# Runs appear on the third poll; the extra poll after them is what is printed,
# picking up a workflow that registered later. The commit asked about is the
# one given, which a repo without .github/workflows is polled for all the
# same.
reset_gh
echo "[$ci]" | answer 3.json
echo "[$ci, $deploy]" | answer 4.json
run "$sha" 5
[ $status -eq 0 ] || fail "runs: exit $status"
expected="1${tab}CI${tab}push${tab}https://x/1
2${tab}Deploy${tab}push${tab}https://x/2"
[ "$out" = "$expected" ] || fail "runs: printed '$out'"
[ "$(calls)" -eq 4 ] || fail "runs: gh called $(calls) times, expected 4"
grep -q "^run list --commit $sha " "$tmp/args" ||
	fail "runs: gh not asked about $sha: $(head -1 "$tmp/args")"

# The follow-up poll failing keeps what the first one found.
reset_gh
echo "[$ci]" | answer 1.json
touch "$tmp/answers/2.fail"
run "$sha"
[ $status -eq 0 ] || fail "follow-up failure: exit $status"
[ "$out" = "1${tab}CI${tab}push${tab}https://x/1" ] ||
	fail "follow-up failure: printed '$out'"

# No run within the window: nothing printed, exit 0, and the window is what
# bounds the polling — a 1 s window at a 1 s interval polls at most twice.
reset_gh
run_env PUSH_RUNS_INTERVAL=1 "$sha" 1
[ $status -eq 0 ] || fail "timeout: exit $status"
[ -z "$out" ] || fail "timeout: printed '$out'"
[ "$(calls)" -ge 1 ] && [ "$(calls)" -le 3 ] ||
	fail "timeout: gh called $(calls) times, expected 1 to 3"

# gh failing on the first poll is exit 2, with its message passed through.
reset_gh
touch "$tmp/answers/fail"
run "$sha"
[ $status -eq 2 ] || fail "gh failure: exit $status"
[ -z "$out" ] || fail "gh failure: printed '$out'"
grep -q "not logged in" "$tmp/err" || fail "gh failure: message lost"

# Usage errors and unknown commits are exit 1, without asking gh.
reset_gh
for args in "" "$sha soon" "$sha 5 extra" "--watch" "--watch abc" \
	"--watch 7 soon" "--watch 7 5 extra" \
	0000000000000000000000000000000000000000; do
	# shellcheck disable=SC2086 # the cases are split on purpose
	run $args
	[ $status -eq 1 ] || fail "usage '$args': exit $status"
done
run_env PUSH_RUNS_INTERVAL=x "$sha"
[ $status -eq 1 ] || fail "bad interval: exit $status"
run_env PUSH_RUNS_WATCH_INTERVAL=x --watch 7
[ $status -eq 1 ] || fail "bad watch interval: exit $status"
[ "$(calls)" -eq 0 ] || fail "usage errors: gh called $(calls) times"

# A watched run is polled until it completes, then reported with its
# workflow, branch, short commit and conclusion — a failure as such.
run_json() {
	printf '{"status": "%s", "conclusion": "%s", "workflowName": "Deploy",
		"headBranch": "master", "headSha": "abcdef1234567890",
		"url": "https://x/7"}\n' "$1" "$2"
}
for conclusion in success failure; do
	reset_gh
	run_json in_progress "" | answer 1.json
	touch "$tmp/answers/2.fail"
	run_json completed "$conclusion" | answer 3.json
	run --watch 7
	[ $status -eq 0 ] || fail "watch $conclusion: exit $status"
	[ "$out" = "Deploy on master @ abcdef1: $conclusion — https://x/7" ] ||
		fail "watch $conclusion: printed '$out'"
	[ "$(calls)" -eq 3 ] || fail "watch $conclusion: $(calls) calls"
	grep -q "^run view 7 " "$tmp/args" ||
		fail "watch $conclusion: gh not asked about run 7"
done

# A run still going when the time is up is reported with its last status.
reset_gh
run_json waiting "" | answer default.json
run_env PUSH_RUNS_WATCH_INTERVAL=1 --watch 7 1
[ $status -eq 0 ] || fail "watch timeout: exit $status"
[ "$out" = "Deploy on master @ abcdef1: still waiting after 1 s — https://x/7" ] ||
	fail "watch timeout: printed '$out'"
[ "$(calls)" -le 3 ] || fail "watch timeout: $(calls) calls"

# A run never read is exit 2, with gh's message.
reset_gh
touch "$tmp/answers/fail"
run_env PUSH_RUNS_WATCH_INTERVAL=1 --watch 7 1
[ $status -eq 2 ] || fail "watch gh failure: exit $status"
[ -z "$out" ] || fail "watch gh failure: printed '$out'"
grep -q "not logged in" "$tmp/err" || fail "watch gh failure: message lost"

if [ $fails -gt 0 ]; then
	echo "push-runs.test.sh: $fails failed" >&2
	exit 1
fi
echo "push-runs.test.sh: all passed"
