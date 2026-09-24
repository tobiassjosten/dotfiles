#!/bin/sh
# Behavioural tests for review-diff.sh — the one piece of executable code the review
# skills (/review, /polish, /ship) and the code-reviewer agent all run. Each case builds a
# throwaway repo under $TMPDIR and asserts on what the script printed and wrote — bar the
# first, which only checks that the repo inherited none of the developer's git config.
# Nothing here touches the repo it lives in.
#
# Run it with `make check`, or directly: sh claude/skills/review-diff.test.sh
#
# The bugs this exists to catch are behavioural, not syntactic — an empty per-file diff
# for a non-ASCII path, a pathspec resolved against the wrong directory, an awk that goes
# silent on an empty input file. `sh -n` and shellcheck see none of them.
set -u

# Hermetic: the throwaway repos must not inherit the developer's git config or environment.
# `git rebase --exec`, `git bisect run` and hooks all set GIT_DIR and friends, and with
# GIT_DIR set a `git init` in a fresh directory silently re-initialises the outer repo, so
# the suite would write objects and run directories into the developer's real .git.
# GIT_CONFIG_PARAMETERS and GIT_CONFIG_COUNT inject config GIT_CONFIG_GLOBAL cannot override.
# This repo's own gitconfig ships commit.gpgsign with an ssh signing key, so on a machine
# where that key is absent every `git commit` here would fail and the suite would blame
# the script. All of this is inherited by the `sh "$script"` runs, so the script under
# test is hermetic too.
GIT_CONFIG_GLOBAL=/dev/null
GIT_CONFIG_SYSTEM=/dev/null
# GIT_CONFIG_SYSTEM does not cover $(prefix)/etc/gitattributes; this does.
GIT_ATTR_NOSYSTEM=1
# GIT_CONFIG_SYSTEM=/dev/null does NOT suppress the system config on macOS — Xcode's
# gitconfig still reaches the repo (verified: credential.helper and init.defaultbranch).
GIT_CONFIG_NOSYSTEM=1
# The suite's own grep/sed run over script output carrying arbitrary repo bytes; BSD grep
# silently fails to match an invalid byte under a UTF-8 locale, which would make absence
# assertions pass vacuously. The latin-1 case overrides this per invocation, as intended.
LC_ALL=C
export LC_ALL
export GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_ATTR_NOSYSTEM GIT_CONFIG_NOSYSTEM
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT GIT_ALTERNATE_OBJECT_DIRECTORIES \
	GIT_CEILING_DIRECTORIES GIT_TEMPLATE_DIR

script=$(cd "$(dirname "$0")" && pwd)/review-diff.sh
# A template, so BSD mktemp honours $TMPDIR (it ignores it when given none) and the
# directory is identifiable if a crash leaves one behind.
work=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/review-diff-test.XXXXXX")" && pwd -P)
trap 'rm -rf "$work"' EXIT
passed=0
failed=0
skipped=0

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

assert_file_nonempty() { # <path> <what>
	if [ -s "$1" ]; then ok; else fail "$2" "empty or missing: $1"; fi
}

assert_no_run_dir() { # <what>
	assert_eq "0" "$(ls -1d "$(git rev-parse --absolute-git-dir)"/review/*/ 2>/dev/null | wc -l | tr -d ' ')" "$1"
}

assert_dir() { # <path> <what>
	if [ -d "$1" ]; then ok; else fail "$2" "missing directory: $1"; fi
}

assert_file() { # <path> <what>
	if [ -f "$1" ]; then ok; else fail "$2" "missing file: $1"; fi
}

# A fresh repo with no commits at all, cd'd into. $1 names it; $2 optionally names the
# initial branch (default `main`).
empty_repo() { # <name> [initial-branch]
	repo=$work/$1
	mkdir -p "$repo"
	cd "$repo" || exit 1
	git init -q -b "${2:-main}" .
	git config user.email test@example.com
	git config user.name Test
	# GIT_CONFIG_GLOBAL=/dev/null leaves core.excludesFile and core.attributesFile unset, so
	# git falls back to ~/.config/git/{ignore,attributes} — which `git add -A` and the diff
	# honour and the suite never wrote. A `*.md -diff` there blanks most of these fixtures.
	git config core.excludesFile /dev/null
	git config core.attributesFile /dev/null
}

# A fresh repo with one commit, cd'd into. $1 names it; $2 optionally names the initial
# branch (default `main`).
new_repo() { # <name> [initial-branch]
	empty_repo "$@"
	echo base >base.md
	git add base.md
	git commit -qm base || { echo "FATAL: could not commit in a throwaway repo" >&2; exit 1; }
}

# $run_status carries the script's exit code: every caller invokes it through a shell
# where a non-zero status is a failure, and `MODE: none` is an expected outcome, not one.
# Sets $out and $run_status rather than printing, because it hands back two values: with
# `out=$(run)` the status is still available as $?, but the `run_status=` assignment made
# inside the substitution's subshell would be lost.
run_status=0
out=""
run() { out=$(sh "$script" "$@" 2>&1); run_status=$?; }

# For values fed back into the script: no 2>&1, so a stray warning cannot end up inside a
# tree hash and fail a later assertion in the wrong place.
tree_of() { sh "$script" --tree; }

# Runs with the two streams kept apart: $out_stdout, $out_stderr, $run_status.
run_split() {
	out_stdout=$(sh "$script" "$@" 2>"$work/stderr"); run_status=$?
	out_stderr=$(cat "$work/stderr")
}

meta() { # <field> <output> — pull "FIELD: value" out of a run's output
	printf '%s\n' "$2" | sed -n "s/^$1: //p"
}

# --- hermeticity: none of the developer's git config reaches a throwaway repo -------
case_name="hermetic git config"
new_repo hermetic
# Pin the origin, not two sample keys: key-specific checks only fail on a machine whose
# own config happens to set them, so they pass on CI and on a fresh machine.
assert_eq "" "$(git config --list --show-origin | grep -v '^file:\.git/config' || true)" \
	"the repo sees no config from outside its own .git/config"
# The destructive hazard the header describes: with GIT_DIR inherited, `git init` here
# would re-initialise the outer repo and the suite would commit into it.
assert_contains "$(git rev-parse --absolute-git-dir)" "$work" \
	"the git dir is under the suite's own work directory, not the developer's repo"

# --- initial: a repo with no commits at all -----------------------------------------
case_name="initial mode"
empty_repo initial
echo hello >new.md
run
assert_contains "$out" "MODE: initial" "reports initial mode"
assert_contains "$out" "new.md" "lists the untracked file"

# --- outstanding: uncommitted changes, staged, unstaged and untracked ---------------
case_name="outstanding mode"
new_repo outstanding
echo changed >>base.md
echo staged >staged.md && git add staged.md
echo untracked >untracked.md
before=$(git status --porcelain)
run
assert_eq "0" "$run_status" "a successful run exits 0"
dir=$(meta DIR "$out")
assert_contains "$out" "MODE: outstanding" "reports outstanding mode"
assert_eq "$before" "$(git status --porcelain)" "leaves the real index untouched"
for f in base.md staged.md untracked.md; do
	assert_contains "$(cat "$dir/stat.txt")" "$f" "stat.txt lists $f"
	assert_file_nonempty "$dir/files/$f.diff" "per-file diff for $f"
done

# --- branch: clean tree on a non-main branch ----------------------------------------
case_name="branch mode"
new_repo branch
git checkout -qb feature
echo more >>base.md
git commit -qam more
run
assert_contains "$out" "MODE: branch (main...HEAD)" "reports branch mode against main"
assert_contains "$out" "base.md" "diffs the branch's commit"

# --- none: clean tree on the main branch --------------------------------------------
case_name="none mode (clean on main)"
new_repo none-main
run
assert_contains "$out" "MODE: none — clean working tree on the main branch main" "reports none on a clean main, naming it"
assert_eq "0" "$run_status" "MODE: none is a normal outcome, not an error"
assert_no_run_dir "creates no run directory"

# --- none: a --since base identical to the working tree -----------------------------
case_name="none mode (empty delta)"
new_repo none-delta
echo work >>base.md
t=$(tree_of)
run --since "$t"
assert_contains "$out" "MODE: none — the working tree is identical to the base $t (delta); nothing to review" \
	"reports none, naming the base and the mode, when nothing changed since it"
assert_eq "0" "$run_status" "an empty delta is a normal outcome, not an error"
assert_no_run_dir "creates no run directory"

# --- --tree: stable, and a usable --since base --------------------------------------
case_name="--tree"
new_repo tree
echo work >>base.md
before=$(git status --porcelain)
t1=$(tree_of)
t2=$(tree_of)
assert_eq "$t1" "$t2" "the same tree hashes twice"
assert_eq "$before" "$(git status --porcelain)" "leaves the real index untouched"
# /polish records meta.txt's TREE as `converged: tree=<hash>` and /ship compares it against
# `review-diff.sh --tree`. If the two ever named different things the review-skip would
# silently stop working, with nothing red.
run
assert_eq "$(tree_of)" "$(meta TREE "$out")" "--tree equals the TREE recorded in meta.txt"
echo later >>base.md
run --since "$t1"
assert_eq "0" "$run_status" "a delta run exits 0"
assert_contains "$out" "MODE: delta" "reports delta mode"
assert_contains "$(cat "$(meta DIR "$out")/full.diff")" "later" "the delta holds only the later change"
assert_eq "" "$(sed -n '/^+work$/p' "$(meta DIR "$out")/full.diff")" "the delta excludes the base change"

# --- paths git would C-quote, and paths with glob characters ------------------------
case_name="awkward paths"
new_repo paths
printf 'accent\n' >"café.md"
printf 'bracket\n' >"a[1].md"
printf 'plain\n' >"a1.md"
printf 'spaced\n' >"with space.md"
# git C-quotes these whatever core.quotePath says — only -z gets them out raw.
printf 'quoted\n' >'quo"te.md'
printf 'slashed\n' >'back\slash.md'
printf 'tabbed\n' >"$(printf 'ta\tb.md')"
# A leading "-" is an option to `dirname`, and a "-dir/" prefix aborted the whole run.
printf 'dashed\n' >-dash.md
mkdir -p -- -dir && printf 'nested\n' >-dir/file.md
run
dir=$(meta DIR "$out")
assert_eq "0" "$run_status" "the run survives every awkward path"
assert_eq "9" "$(printf '%s\n' "$out" | sed -n 's/^[0-9-]*	[0-9-]*	//p' | wc -l | tr -d ' ')" \
	"stat.txt lists all 9 awkward paths"
# Every path in stat.txt must name a real, non-empty per-file diff. Counted above first:
# with no paths extracted the loop below would pass on nothing.
printf '%s\n' "$out" | sed -n 's/^[0-9-]*	[0-9-]*	//p' | while IFS= read -r p; do
	[ -s "$dir/files/$p.diff" ] || echo "MISSING $p"
done >"$work/missing"
assert_eq "" "$(cat "$work/missing")" "every stat.txt path has a non-empty per-file diff"
assert_eq "1" "$(grep -c '^+bracket$' "$dir/files/a[1].md.diff")" "a glob-looking path diffs only itself"
assert_eq "0" "$(grep -c '^+plain$' "$dir/files/a[1].md.diff")" "a glob-looking path does not absorb its neighbour"

# --- a repo path containing a backslash --------------------------------------------
# /bin/sh's echo expands \t, \n and \\ in its operand (macOS bash 3.2 with XPG echo, and
# dash), so a path carrying a backslash came out mangled in the DIR: line the fan-out
# pastes into every reviewer's prompt.
case_name="backslash in the repo path"
new_repo 'ta\tb'
echo work >>base.md
run
assert_eq "0" "$run_status" "the run completes"
assert_dir "$(meta DIR "$out")" "the printed DIR names a directory that exists"

# --- run from a subdirectory --------------------------------------------------------
case_name="run from a subdirectory"
new_repo subdir
mkdir -p nested/deep
echo content >nested/deep/file.md
cd nested/deep || exit 1
run
dir=$(meta DIR "$out")
case $dir in
	/*) ok ;;
	*) fail "DIR is absolute" "actual: $dir" ;;
esac
assert_file_nonempty "$dir/files/nested/deep/file.md.diff" "per-file diff written under the repo-root-relative path"

# --- renames stay consistent across stat.txt and files/ -----------------------------
case_name="renames"
new_repo renames
git mv base.md moved.md
run
dir=$(meta DIR "$out")
assert_eq "2" "$(wc -l <"$dir/stat.txt" | tr -d ' ')" "a rename is two stat.txt entries, not one pair"
assert_eq "2" "$(grep -c '^[0-9-]*	[0-9-]*	.' "$dir/stat.txt")" "both entries are well-formed numstat lines"
assert_file_nonempty "$dir/files/moved.md.diff" "per-file diff for the new path"
assert_file_nonempty "$dir/files/base.md.diff" "per-file diff for the old path"

# --- removed-terms: deletion-only change (the awk empty-first-file trap) ------------
case_name="removed-terms on a deletion-only change"
new_repo removed-deletion
echo "the legacywidget option" >>base.md
echo "legacywidget is documented here" >doc.md
git add . && git commit -qm setup
# Delete the mention from base.md only; doc.md still carries the term.
grep -v legacywidget base.md >base.tmp && mv base.tmp base.md
run
terms=$(cat "$(meta DIR "$out")/removed-terms.txt")
assert_contains "$terms" "legacywidget" "a pure deletion still yields its removed terms"

# The two filters that make the heuristic a signal rather than a word list: a term must
# be absent from the added lines, and it must still occur somewhere in the tree. Without
# these negatives, deleting either filter leaves the suite green and the claims lens is
# handed every 4+ character word in the diff.
case_name="removed-terms filters"
new_repo removed-filters
cat >base.md <<'FIXTURE'
the legacywidget option
the retainedword option
the vanishedword option
the xyz option
FIXTURE
echo "legacywidget is documented here" >doc.md
echo "retainedword is documented here" >>doc.md
echo "xyz is documented here too" >>doc.md
git add . && git commit -qm setup
cat >base.md <<'FIXTURE'
the retainedword option again
FIXTURE
run
terms=$(cat "$(meta DIR "$out")/removed-terms.txt")
assert_contains "$terms" "legacywidget" "a removed term still present in the tree is reported"
assert_eq "" "$(printf '%s\n' "$terms" | grep -w retainedword || true)" \
	"a term that also appears on an added line is filtered out"
assert_eq "" "$(printf '%s\n' "$terms" | grep -w vanishedword || true)" \
	"a term that occurs nowhere else in the tree is filtered out"
assert_eq "" "$(printf '%s\n' "$terms" | grep -w xyz || true)" \
	"a term under the 4-character floor is filtered out, though it is still in the tree"

# --- removed-terms: content lines that look like diff file headers ------------------
case_name="removed-terms on a line starting with --"
new_repo removed-header
echo "-- legacywidget option" >>base.md
echo "legacywidget is documented here" >doc.md
git add . && git commit -qm setup
grep -v legacywidget base.md >base.tmp && mv base.tmp base.md
run
assert_contains "$(cat "$(meta DIR "$out")/removed-terms.txt")" "legacywidget" \
	"a removed line starting with -- is not read as a file header"

# --- removed-terms: a latin-1 byte in the diff (the awk locale abort) ---------------
# Outside LC_ALL=C the `awk` in difflines() dies on an invalid byte ("towc: multibyte
# conversion failure"), and because `difflines` is a plain command `set -e` aborts the run
# (verified: exit 2, no MODE: line) rather than truncating quietly — the `sed` and `tr`
# calls inside words() are the ones that fail silently, being mid-pipeline. The fixture is
# named to sort ahead of base.md so the removed term is still downstream of the failure,
# which keeps the case honest against those quiet mid-pipeline failures too. Both legs pass
# today, because the script exports LC_ALL=C: the UTF-8 leg is the one that would hit the
# abort if that export were ever dropped, and the C leg is a control that the pipeline
# handles a high byte at all. Any *.UTF-8 locale will do, so take whatever this machine
# has rather than insisting on en_US.
case_name="removed-terms with a latin-1 byte"
new_repo removed-latin1
printf 'caf\351 sidebar\n' >a-latin1.md
echo "the legacywidget option" >>base.md
echo "legacywidget is documented here" >doc.md
git add . && git commit -qm setup
grep -v legacywidget base.md >base.tmp && mv base.tmp base.md
printf 'caf\351 sidebar changed\n' >a-latin1.md
locales="C"
utf8=$(locale -a 2>/dev/null | grep -i 'utf-*8$' | head -n 1 || true)
if [ -n "$utf8" ]; then
	locales="$locales $utf8"
else
	skipped=$((skipped + 1))
	echo "SKIP: no UTF-8 locale available — the latin-1 abort case was not exercised" >&2
fi
for loc in $locales; do
	out=$(LC_ALL=$loc sh "$script" 2>&1)
	assert_contains "$(cat "$(meta DIR "$out")/removed-terms.txt" 2>/dev/null)" "legacywidget" \
		"a latin-1 byte earlier in the diff does not truncate removed-terms (LC_ALL=$loc)"
done

# --- removed-terms: diff file headers are never read as content ---------------------
# difflines() decides what is content by position — reset at `diff --git`, enter at `@@` —
# so that a changed line beginning "--" or "++" is not mistaken for a "--- a/x" header.
# The converse matters just as much: the real header lines must not be read as content, or
# a deleted file's own path words enter the stale-vocabulary list as false leads.
case_name="diff headers are not content"
new_repo diff-headers
echo "placeholder" >legacywidget.md
printf 'legacywidget is documented here\ncontrolterm is documented too\n' >doc.md
printf 'first\nmovedword second\ncontrolterm goes away\n' >base.md
git add . && git commit -qm setup
rm legacywidget.md
printf 'first\n++ movedword still here\n' >base.md
run
assert_eq "0" "$run_status" "the run completes"
terms=$(cat "$(meta DIR "$out")/removed-terms.txt")
assert_contains "$terms" "controlterm" "a control term is reported, so the absences below are read against a real file"
assert_eq "" "$(printf '%s\n' "$terms" | grep -w legacywidget || true)" \
	"a deleted file's path does not enter removed-terms through its --- header"
# movedword left the "second" line and came back on a line starting with "++". If that
# line were mistaken for a +++ file header it would miss the added-list and be reported
# as retired vocabulary.
assert_eq "" "$(printf '%s\n' "$terms" | grep -w movedword || true)" \
	"a line starting with ++ is added content, not a +++ header"

# --- removed-terms: camelCase splitting and lowercasing -----------------------------
case_name="removed-terms word normalisation"
new_repo removed-case
printf 'keep\nthe legacyWidget option\n' >base.md
echo "LegacyWidget is documented here" >doc.md
git add . && git commit -qm setup
printf 'keep\n' >base.md
run
terms=$(cat "$(meta DIR "$out")/removed-terms.txt")
assert_eq "1" "$(printf '%s\n' "$terms" | grep -c '^legacy  removed=' || true)" \
	"camelCase is split, so 'legacy' is its own term"
assert_eq "1" "$(printf '%s\n' "$terms" | grep -c '^widget  removed=' || true)" \
	"and so is 'widget', lowercased"

# --- removed-terms: a NUL inside a file git still treats as text --------------------
# `git grep -I` skips a file only when a NUL falls in its first 8000 bytes. A later NUL
# leaves the file text, and its matching line then arrives from `git grep -z` carrying an
# embedded NUL — which `tr` turns into an extra line. A decoder that paired lines by
# parity would invert paths and content for the whole rest of the stream, silently
# deflating every still-in count after it.
case_name="removed-terms with a NUL in a text file"
new_repo removed-nul
# The NUL must sit on a line that *matches*, or grep never emits it and nothing desyncs.
{ head -c 9000 /dev/zero | tr '\0' 'x'; printf '\nlegacywidget tail\0with nul\n'; } >a-padded.md
echo "legacywidget is documented here" >b-doc.md
printf 'keep this line\nthe legacywidget option\n' >base.md
git add . && git commit -qm setup
printf 'keep this line\n' >base.md
run
assert_contains "$(cat "$(meta DIR "$out")/removed-terms.txt")" "legacywidget  removed=1  still-in=2 file(s)" \
	"the count survives an embedded NUL earlier in the stream"

# --- removed-terms: still-in counts files, case-insensitively, skipping binaries ----
# `review-lenses/claims.md` tells reviewers to reproduce this number with
# `git grep -n -i -I -F --no-color -e <term> <TREE> --`, so the flags are a contract.
case_name="still-in tally"
new_repo still-in
# color.ui=always (this repo sets it) makes git colour a pipe, so without --no-color the
# grep's output arrives wrapped in ANSI escapes, the decoder's "<tree>:" anchor never
# matches and removed-terms.txt comes out empty — which reads as full coverage downstream.
# The hostile-config case cannot pin this: its change is addition-only, so no grep runs.
git config color.ui always
printf 'legacywidget here\nlegacywidget again\n' >many-matches.md   # two lines, one file
echo "LegacyWidget in another case" >other-case.md                   # -i must match it
# -I keeps this file out of the grep entirely, so it must not reach the tally. The two
# binary guards (-I and the awk's "Binary file …" skip) and the `path == ""` belt are
# deliberately redundant: removing any one of them changes nothing observable here, so
# none of the three is individually pinned. This fixture pins the tally's outcome, not the
# guards — keeping all three is the point, since the count must not rest on any one.
printf 'legacywidget\0binary\n' >legacywidget-binary.md
printf 'keep\nthe legacywidget option\n' >base.md
git add . && git commit -qm setup
printf 'keep\n' >base.md
run
assert_contains "$(cat "$(meta DIR "$out")/removed-terms.txt")" "legacywidget  removed=1  still-in=2 file(s)" \
	"two matching text files, counted once each, with the binary skipped"

# --- the snapshot sees an edit made in the index's own second -----------------------
# git marks an index entry "racily clean" — and re-checks it by content — when its cached
# mtime is not older than the index file's. snapshot_tree copies the index, so the copy
# must carry the original's mtime; with a fresh one the re-check is retired and a same-size
# edit made in that second stays invisible to `git add -A`. The snapshot would then be a
# tree that does not match the working tree — which is what /polish records as `converged:`
# and /ship compares against. Pinning all three timestamps makes it deterministic.
case_name="racily-clean index entry"
new_repo racy
stamp=202001010000
printf 'bbbb\n' >f.md
git add f.md
touch -t "$stamp" f.md
git add f.md
touch -t "$stamp" "$(git rev-parse --git-path index)"
printf 'cccc\n' >f.md
touch -t "$stamp" f.md
assert_eq "cccc" "$(git cat-file -p "$(tree_of):f.md" | tr -d '\n')" \
	"the snapshot carries the edit, not the stale blob"

# --- the temporary index is cleaned up ----------------------------------------------
# snapshot_tree creates a private `mktemp -d` directory — 0700, since the index it holds
# is the repo's full path listing — and relies on an EXIT trap to remove it, including on
# the --tree path that /polish and /ship call on every run. A shim intercepts the script's
# one-argument `mktemp -d` and redirects it into a directory we own; TMPDIR would not work,
# because BSD mktemp ignores it when given no template and the assertion would pass
# vacuously.
case_name="temporary index cleanup"
new_repo tmpidx
echo work >>base.md
shimdir=$work/shim
mktdir=$work/mktemp-out
mkdir -p "$shimdir" "$mktdir"
realmktemp=$(command -v mktemp)
cat >"$shimdir/mktemp" <<SHIM
#!/bin/sh
[ "\$1" = -d ] && [ \$# -eq 1 ] && { echo called >>"$work/mktemp-calls"; exec "$realmktemp" -d "$mktdir/idx.XXXXXX"; }
exec "$realmktemp" "\$@"
SHIM
chmod +x "$shimdir/mktemp"
# Two guards, both learned the hard way: the shim records that it ran (or the assertions
# also pass on a script that stopped calling mktemp this way), and each run's status is
# checked (or they also pass on a run that died before reaching the path at all — the
# EXIT trap fires either way, so an abort is otherwise indistinguishable from success).
PATH="$shimdir:$PATH" sh "$script" >/dev/null 2>&1
assert_eq "0" "$?" "the normal run completed"
assert_file_nonempty "$work/mktemp-calls" "and took the shimmed mktemp -d path"
assert_eq "" "$(ls -A "$mktdir")" "leaving no temporary index directory behind"
: >"$work/mktemp-calls"
treeout=$(PATH="$shimdir:$PATH" sh "$script" --tree 2>/dev/null); status=$?
assert_eq "0" "$status" "the --tree run completed"
assert_eq "1" "$(printf '%s' "$treeout" | grep -c '^[0-9a-f]\{40\}$')" "and printed a tree hash"
assert_file_nonempty "$work/mktemp-calls" "--tree takes the same path"
assert_eq "" "$(ls -A "$mktdir")" "and leaves nothing behind either"

# --- content-suppressed files are named in meta.txt ---------------------------------
# A tracked .gitattributes `-diff` mark makes git print "Binary files … differ" with no
# content and numstat report "-", so the file is both unreadable and weightless in the
# totals. meta.txt has to name it, or its reviewer trusts an empty diff.
case_name="NO-CONTENT files"
new_repo nocontent
echo "*.bin -diff" >.gitattributes
printf 'one\n' >opaque.bin
echo plain >plain.md
git add . && git commit -qm setup
printf 'two two two\n' >opaque.bin
echo changed >>plain.md
run
assert_contains "$out" "NO-CONTENT" "a content-suppressed file is announced in meta.txt"
assert_contains "$out" "  opaque.bin" "and named on its own line"
assert_contains "$(cat "$(meta DIR "$out")/meta.txt")" "  opaque.bin" "and meta.txt carries it on disk"
# One path per line, and everything after the second tab: a path holding a tab or a space
# must come back verbatim, which a space-joined list on field 3 could not manage.
printf 'x\n' >"$(printf 'ta\tb.bin')"
printf 'x\n' >"with space.bin"
git add -A && git commit -qm awkward
printf 'yy\n' >"$(printf 'ta\tb.bin')"
printf 'yy\n' >"with space.bin"
run
assert_contains "$out" "$(printf '  ta\tb.bin')" "a path containing a tab survives whole"
assert_contains "$out" "  with space.bin" "and so does one containing a space"
# A change with nothing suppressed must not carry the line at all.
new_repo nocontent-absent
echo work >>base.md
run
assert_eq "0" "$(grep -c 'NO-CONTENT' "$(meta DIR "$out")/meta.txt" || true)" \
	"and the line is absent when every file has content"

# --- a textconv driver cannot blank out the diff ------------------------------------
# `diff.<driver>.textconv` plus a `diff=<driver>` attribute renders a file before diffing;
# a normalising filter would make a changed file's diff empty. The review wants the stored
# bytes, so gd() passes --no-textconv.
case_name="textconv does not suppress content"
new_repo textconv
git config diff.flatten.textconv "sed s/./x/g"
echo "*.tc diff=flatten" >.gitattributes
printf 'alpha\n' >file.tc
git add . && git commit -qm setup
printf 'bravo\n' >file.tc
run
assert_contains "$(cat "$(meta DIR "$out")/full.diff")" "bravo" "the stored bytes are diffed, not the rendered view"

# --- dirtiness is decided by the snapshot, not by git status -------------------------
# `git status` honours status.showUntrackedFiles=no; `git add -A` does not. If mode
# selection asked git status, a new file would read as a clean tree while the snapshot
# captured it in full — and the whole change would report as nothing to review.
case_name="dirtiness follows the snapshot"
new_repo dirty-snapshot
git config status.showUntrackedFiles no
echo "brand new" >untracked.md
run
assert_contains "$out" "MODE: outstanding" "an untracked file is a dirty tree even when git status hides it"
assert_contains "$out" "untracked.md" "and it is in the diff"

# --- argument handling --------------------------------------------------------------
# The exit codes and messages of the dispatch live in "argument dispatch exits" below;
# what is unique here is the happy path of the = form and the no-run-directory guarantee.
case_name="argument handling"
new_repo args
echo work >>base.md
run --nope
assert_no_run_dir "a rejected invocation creates no run directory"
t=$(tree_of)
echo again >>base.md
run --since="$t"
assert_eq "0" "$run_status" "the --since=<tree> form exits 0"
assert_contains "$out" "MODE: delta" "and prepares the delta"

# --- retention: 5 most recent runs, and the ledger survives -------------------------
case_name="run retention"
new_repo retention
echo work >>base.md
reviewroot=$(git rev-parse --absolute-git-dir)/review
mkdir -p "$reviewroot"
echo "- settled: keep me" >"$reviewroot/ledger.md"
i=0
while [ $i -lt 7 ]; do
	echo "run $i" >>base.md
	run
	i=$((i + 1))
done
assert_eq "5" "$(ls -1d "$reviewroot"/*/ | wc -l | tr -d ' ')" "keeps exactly the 5 most recent runs"
# The real-world same-second path; the deterministic version is the case below.
assert_dir "$(meta DIR "$out")" "the newest run survives its own prune"
assert_eq "- settled: keep me" "$(cat "$reviewroot/ledger.md")" "leaves the ledger alone"

# --- the prune never evicts the run that is doing the pruning -----------------------
# Directory names are <timestamp>-<pid> and the prune ranks them with `sort -r`, i.e. as
# strings. Two runs in the same second therefore sort by PID digits ("9952" above
# "10018"), so the newest run can rank last among its siblings. Five siblings that sort
# unambiguously above the current run reproduce that ordering without depending on timing.
case_name="prune excludes the current run"
new_repo prune-self
echo work >>base.md
reviewroot=$(git rev-parse --absolute-git-dir)/review
mkdir -p "$reviewroot"
for n in 1 2 3 4 5; do mkdir -p "$reviewroot/29991231-235959-$n"; done
run
assert_dir "$(meta DIR "$out")" "the current run survives even when five siblings outrank it"
assert_eq "5" "$(ls -1d "$reviewroot"/*/ | wc -l | tr -d ' ')" "and the total is still 5"

# --- gd()'s flags survive a hostile repo-local git config ---------------------------
# --no-ext-diff, --no-color and core.quotePath=false exist only to defend against the
# user's own config — and the suite nulls out the global config, so nothing else here
# would notice if they were dropped. Repo-local config is still read under
# GIT_CONFIG_GLOBAL=/dev/null, so setting it here keeps the suite hermetic while pinning
# all three. This repo's own gitconfig ships diff.external=difft and color.ui=always.
case_name="hostile git config"
new_repo hostile-config
git config diff.external /usr/bin/true
git config color.ui always
git config core.quotePath true
printf 'accent\n' >"café.md"
run
dir=$(meta DIR "$out")
assert_eq "0" "$(grep -c "$(printf '\033')" "$dir/full.diff")" "color.ui=always does not colour full.diff"
assert_eq "1" "$(grep -c '^diff --git' "$dir/full.diff")" "diff.external does not empty full.diff"
assert_contains "$(cat "$dir/stat.txt")" "café.md" "core.quotePath=true does not escape the path"
assert_file_nonempty "$dir/files/café.md.diff" "and the per-file diff still lands"
# -z covers the file lists; core.quotePath=false covers the path inside the diff text.
assert_contains "$(cat "$dir/full.diff")" "diff --git a/café.md" "nor the path in the diff header"

# --- the snapshot excludes gitignored files ------------------------------------------
# The header promises that anything secret must be gitignored, not merely untracked —
# i.e. .gitignore is the line between private and "written into .git/objects and a
# plain-text diff an agent then reads".
case_name="gitignored files stay out of the snapshot"
new_repo ignored
echo "secret.txt" >.gitignore
echo "TOKEN=hunter2" >secret.txt
echo "visible" >untracked.md
run
dir=$(meta DIR "$out")
assert_eq "0" "$(grep -c 'secret.txt' "$dir/stat.txt")" "an ignored file is not in stat.txt"
assert_eq "0" "$(grep -c 'hunter2' "$dir/full.diff")" "and its contents are not in full.diff"
assert_contains "$(cat "$dir/stat.txt")" "untracked.md" "but an untracked non-ignored file still is"
# The mirror image, and the reason snapshot_tree seeds its index from the real one: a file
# that is tracked *and* matches .gitignore must stay in the snapshot. `git add -A` into an
# empty index drops it, and the diff would then report a deletion the author never made.
echo "tracked" >tracked-ignored.txt
git add tracked-ignored.txt && git commit -qm "track it"
echo "tracked-ignored.txt" >>.gitignore
echo "edit" >>base.md
run
assert_eq "0" "$(grep -c 'tracked-ignored' "$(meta DIR "$out")/stat.txt")" \
	"a tracked file that later matches .gitignore is not reported as deleted"

# --- the run directory holds everything the contract documents ----------------------
case_name="run directory contents"
new_repo contents
echo work >>base.md
run
dir=$(meta DIR "$out")
for f in meta.txt stat.txt full.diff removed-terms.txt; do
	assert_file "$dir/$f" "$f exists"
done
assert_dir "$dir/files" "files/ exists"
assert_eq "" "$(ls -A "$dir" | grep '^\.' || true)" "no scratch files left behind"
assert_eq "$(git rev-parse 'HEAD^{tree}')" "$(meta FROM "$out")" "FROM is HEAD's tree in outstanding mode"
assert_contains "$out" "FILES: 1 (+1 -0), full.diff 7 lines" "FILES carries both totals"
assert_contains "$out" "STAT (added removed path):" "the stat header is printed"

# --- branch mode picks its base from origin/HEAD and the local fallbacks ------------
# No network needed: a remote ref is just a ref. The loc-vs-rem rule exists so a stale
# local main does not blame others' already-merged commits on the branch.
case_name="branch mode against origin/HEAD"
new_repo branch-origin
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git checkout -qb feature
echo more >>base.md
git commit -qam more
run
assert_contains "$out" "MODE: branch (origin/main...HEAD)" "prefers origin/main when it is up to date"

case_name="branch mode when local main is ahead of origin"
new_repo branch-local-ahead
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
echo ahead >>base.md
git commit -qam "local main moves ahead"
git checkout -qb feature
echo more >>base.md
git commit -qam more
run
assert_contains "$out" "MODE: branch (main...HEAD)" "falls back to the more up-to-date local main"

case_name="branch mode falls back to master"
new_repo branch-master master
git checkout -qb feature
echo more >>base.md && git commit -qam more
run
assert_contains "$out" "MODE: branch (master...HEAD)" "finds master when there is no main"

# --- branch mode falls back to trunk ------------------------------------------------
case_name="branch mode falls back to trunk"
new_repo branch-trunk trunk
git checkout -qb feature
echo more >>base.md && git commit -qam more
run
assert_contains "$out" "MODE: branch (trunk...HEAD)" "finds trunk when there is no main or master"

case_name="branch mode with only origin/main"
new_repo branch-origin-only
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
git checkout -qb feature
echo more >>base.md
git commit -qam more
git branch -qD main
run
assert_contains "$out" "MODE: branch (origin/main...HEAD)" "falls back to origin when no local main exists"

case_name="branch mode with a stale origin/HEAD"
new_repo branch-stale-head
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
# origin/HEAD still names a ref that was pruned — an upstream rename plus `git remote prune`.
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
git checkout -qb feature
echo more >>base.md
git commit -qam more
run
assert_contains "$out" "MODE: branch (origin/main...HEAD)" \
	"a stale origin/HEAD falls through to a base that resolves"

case_name="no main branch at all"
new_repo no-main devel
run
assert_contains "$out" "MODE: none — no main branch found (looked for origin/HEAD, then main, master, trunk)" \
	"a clean tree with no main/master/trunk says so specifically"
assert_eq "0" "$run_status" "and exits 0"

case_name="branch with no merge base"
new_repo orphan
git checkout -q --orphan unrelated
git rm -q -rf .
echo fresh >fresh.md
git add fresh.md && git commit -qm fresh
run
assert_eq "0" "$run_status" "an orphan branch does not kill the run"
assert_contains "$out" "MODE: branch (unrelated has no merge base with main" "and names both the branch and the base"
assert_contains "$out" "fresh.md" "reviewing the whole branch instead"
git checkout -q --detach
run
assert_contains "$out" "MODE: branch (HEAD has no merge base" "a detached HEAD still names a subject"

# --- a tree carrying ".." path components is refused, not written outside ------------
# git's index rejects ".." as a component, but a tree object can hold one and `git diff`
# emits it; outstanding mode diffs HEAD's tree without ever checking it out, so a hostile
# clone could otherwise drive the per-file mkdir and redirect anywhere on the filesystem.
case_name="unsafe paths from a crafted tree"
new_repo traversal
blob=$(git hash-object -w base.md)
leaf=$(printf '100644 blob %s\tnotes.txt\n' "$blob" | git mktree)
# The guard has four constructible arms; the fixture below builds one of each shape.
#   "../*"      four levels of ".." above a file
#   ".."        a bare ".." entry
#   "*/.."      ".." nested under a directory
#   "*/../*"    a file reached through a directory's ".."
deep=$leaf
i=0
while [ $i -lt 4 ]; do deep=$(printf '040000 tree %s\t..\n' "$deep" | git mktree); i=$((i + 1)); done
dotdot=$(printf '100644 blob %s\t..\n' "$blob" | git mktree)
nested=$(printf '040000 tree %s\tdir\n' "$dotdot" | git mktree)
through=$(printf '040000 tree %s\tdir\n' "$(printf '040000 tree %s\t..\n' "$leaf" | git mktree)" | git mktree)
for t in "$deep" "$dotdot" "$nested" "$through"; do
	run --since "$t"
	assert_eq "1" "$run_status" "an unsafe path fails the run rather than writing outside it"
	assert_contains "$out" "refusing unsafe path" "and says why"
done
assert_eq "" "$(find "$work" -name 'notes.txt.diff' -not -path '*/review/*' 2>/dev/null)" \
	"nothing was created outside the review directory"

# --- a changed path containing a newline is refused ---------------------------------
# -z survives the newline, but `tr '\0' '\n'` splits the record in two; each half passes
# the ".." guard, gets its own mkdir and matches no pathspec, so a real changed file
# reaches its reviewer as two fabricated paths with empty diffs and nothing says so.
case_name="newline in a changed path"
new_repo newline-path
printf 'x\n' >"$(printf 'REA\nDME.md')"
run
assert_eq "1" "$run_status" "the run is refused rather than fabricating two paths"
assert_contains "$out" "refusing a changed path containing a newline" "and says why"

# --- diff.context cannot strip the context out of a prepared diff -------------------
case_name="diff.context is pinned"
new_repo context
git config diff.context 0
printf 'a\nb\nc\nd\ne\nf\ng\n' >ctx.md
git add . && git commit -qm setup
printf 'a\nb\nc\nCHANGED\ne\nf\ng\n' >ctx.md
run
assert_dir "$(meta DIR "$out")" "the run completes"
assert_eq "6" "$(grep -c '^ ' "$(meta DIR "$out")/files/ctx.md.diff" || true)" \
	"-U3 keeps three context lines either side of the per-file diff despite diff.context=0"
assert_eq "6" "$(grep -c '^ ' "$(meta DIR "$out")/full.diff" || true)" \
	"and of full.diff, which is the artifact read end to end"

# --- the run directory is owner-only ------------------------------------------------
# full.diff holds the contents of every changed and untracked non-ignored file, so it
# must not be more readable than the loose objects the same run writes.
case_name="run directory permissions"
new_repo perms
echo work >>base.md
( umask 022; sh "$script" >/dev/null 2>&1 )
d=$(ls -1dt "$(git rev-parse --absolute-git-dir)"/review/*/ | head -1)
assert_eq "drwx------" "$(ls -ld "$d" | cut -c1-10)" "the run directory is 0700 whatever the caller's umask"
assert_eq "-rw-------" "$(ls -l "$d/full.diff" | cut -c1-10)" "and full.diff is 0600"

# --- git grep failing is reported, not read as "found nothing" ----------------------
# lens:claims' coverage is checked against `wc -l < removed-terms.txt`, so an empty file
# from a grep that never ran would read as complete coverage.
case_name="git grep failure is announced"
new_repo grepfail
printf 'keep\nthe legacywidget option\n' >base.md
echo "legacywidget elsewhere" >doc.md
git add . && git commit -qm setup
printf 'keep\n' >base.md
gshim=$work/gitshim
mkdir -p "$gshim"
realgit=$(command -v git)
cat >"$gshim/git" <<SHIM
#!/bin/sh
for a in "\$@"; do [ "\$a" = grep ] && exit 2; done
exec "$realgit" "\$@"
SHIM
chmod +x "$gshim/git"
out=$(PATH="$gshim:$PATH" sh "$script" 2>&1); run_status=$?
assert_eq "0" "$run_status" "a failing git grep does not abort the run"
assert_contains "$out" "git grep failed (2); removed-terms.txt may be incomplete" "and is reported"
assert_file "$(meta DIR "$out")/removed-terms.txt" "an incomplete sweep still leaves the artifact"

# --- the candidate ranking and the 80-term cap --------------------------------------
# `sort -rn | head -n 80` decides which stale-vocabulary candidates reach the claims lens,
# and review-fanout.md checks that lens's coverage against `wc -l < removed-terms.txt`, so
# whatever survives the cap *is* the sweep. Nothing else in the suite produces more than a
# handful of candidates, so without this a reversed sort or a changed cap ships green.
case_name="candidate ranking and cap"
new_repo ranking
# One distinct 4+ character word per line and nothing else: any shared filler word would
# itself become a high-count candidate and take a slot in the cap.
{ i=0; while [ $i -lt 90 ]; do printf 'wordaaa%03d\n' "$i"; i=$((i + 1)); done; } >base.md
printf 'topterm\ntopterm\ntopterm\ntopterm\n' >>base.md
{ i=0; while [ $i -lt 90 ]; do printf 'wordaaa%03d\n' "$i"; i=$((i + 1)); done; } >doc.md
echo "topterm" >>doc.md
git add . && git commit -qm setup
: >base.md
run
terms="$(meta DIR "$out")/removed-terms.txt"
assert_eq "80" "$(wc -l <"$terms" | tr -d ' ')" "91 candidates are capped at 80"
assert_contains "$(head -1 "$terms")" "topterm  removed=4" "and the most-removed term ranks first"

# --- every remaining exit of the argument dispatch -----------------------------------
case_name="argument dispatch exits"
new_repo dispatch
echo work >>base.md
t=$(tree_of)
for bad in "--tree junk" "--since" "--since $t junk" "--since deadbeef" "--since=deadbeef" "--since=$t junk" "--help junk"; do
	# shellcheck disable=SC2086
	sh "$script" $bad >/dev/null 2>&1
	assert_eq "2" "$?" "\`$bad\` exits 2"
done
run_split -h
assert_eq "0" "$run_status" "-h exits 0"
assert_contains "$out_stdout" "usage: review-diff.sh" "-h prints the usage on stdout"
for form in "--since <tree>" "--since=<tree>" "--tree" "-h, --help"; do
	assert_contains "$out_stdout" "$form" "the usage lists $form"
done
assert_eq "" "$out_stderr" "and nothing on stderr"
run_split ""
assert_eq "2" "$run_status" "an empty argument exits 2"
assert_contains "$out_stderr" "unexpected argument: ''" "and is quoted so it is visible"
run_split -h junk
assert_eq "2" "$run_status" "-h with a surplus argument exits 2"
assert_contains "$out_stderr" "-h takes no arguments" "and echoes the spelling that was typed"
run_split --since deadbeef
assert_contains "$out_stderr" "--since: not a tree-ish: 'deadbeef'" \
	"an unresolvable --since quotes the value it rejected"
# The = branch builds its own diagnostic, so the message needs its own assertion (the
# loop above already pins this form's exit status).
run_split --since=deadbeef
assert_contains "$out_stderr" "--since: not a tree-ish: 'deadbeef'" "the = form quotes it the same way"
run --since "$(git rev-parse HEAD)"
assert_eq "0" "$run_status" "--since accepts a commit-ish"
assert_contains "$out" "FROM: $(git rev-parse 'HEAD^{tree}')" "and peels it to a tree"
run_split --since="$t" junk
assert_contains "$out_stderr" "--since= takes no further arguments" "the = form names its own arity error"
run_split --help junk
assert_contains "$out_stderr" "--help takes no arguments" "and the long spelling gets its own message"
run_split --tree junk
assert_contains "$out_stderr" "--tree takes no arguments" "--tree names its own arity error"
run_split --since
assert_contains "$out_stderr" "--since needs exactly one tree-ish" "--since names its own arity error"
run_split --nope
assert_eq "2" "$run_status" "an unknown argument exits 2"
assert_eq "" "$out_stdout" "with nothing on stdout"
assert_contains "$out_stderr" "unknown argument: '--nope'" "and the diagnosis on stderr, quoting the argument"
assert_contains "$out_stderr" "usage: review-diff.sh" "followed by the usage"
# --- outside a work tree -------------------------------------------------------------
case_name="outside a work tree"
cd "$work" || exit 1
run
assert_eq "1" "$run_status" "outside a git repository it exits 1"
assert_contains "$out" "not a git repository" "and says so"
# A bare repo is the case --git-dir accepted and every later command then failed on, so
# match the wording the work-tree guard added rather than the shared prefix.
git init -q --bare "$work/bare.git"
cd "$work/bare.git" || exit 1
run
assert_eq "1" "$run_status" "in a bare repo it exits 1"
assert_contains "$out" "with a work tree" "and names the work tree as what is missing"

# --- report --------------------------------------------------------------------------
cd / || exit 1
if [ "$skipped" -gt 0 ]; then
	echo "review-diff.test.sh: $passed passed, $failed failed, $skipped skipped"
else
	echo "review-diff.test.sh: $passed passed, $failed failed"
fi
[ "$failed" -eq 0 ]
