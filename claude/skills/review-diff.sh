#!/bin/sh
# Prepare the changes under review as files on disk and print a short summary.
# Shared by /review, /polish, /ship and the code-reviewer agent (via review-fanout.md)
# so base selection and diff preparation live in one place. /review-pr and /focused-review
# gather their own diffs and do not use this script.
#
# Usage:
#   review-diff.sh                 # auto: unpublished, outstanding, branch, or initial
#   review-diff.sh --since <tree>  # delta: only what changed since an earlier snapshot
#   review-diff.sh --since=<tree>  # the same, = form
#   review-diff.sh --base <commit> # full: everything since merge-base(<commit>, HEAD)
#   review-diff.sh --base=<commit> # the same, = form
#   review-diff.sh --target        # print the publish target auto mode uses, and exit
#   review-diff.sh --transient <commit>  # print paths an unpublished commit (one no origin/ ref
#                                  # holds) since merge-base(<commit>, HEAD) touched that the
#                                  # net diff does not show, and exit
#   review-diff.sh --tree          # print the working-tree snapshot hash and exit
#   review-diff.sh -h, --help      # print the usage and exit
#
# Modes (auto). The change under review is everything not yet published: /commit never
# pushes, so commits can sit unpublished under the working tree, and a review that read
# only the uncommitted part would let them out unread. So auto mode first names the
# **publish target** — origin/<branch> when that ref exists and HEAD contains it (a branch
# already pushed and not rewritten since), otherwise the default branch's origin/ ref
# (whatever origin/HEAD names, then origin/main, master, trunk, taking the first that
# resolves, so a stale origin/HEAD falls through) — and diffs from where HEAD meets it.
#   - unpublished — HEAD holds commits the target lacks: merge-base(<target>, HEAD) → the
#                   working tree, committed and uncommitted alike. FROM is the merge base's
#                   tree, as in base mode. No merge base: the empty tree.
#   - outstanding — nothing unpublished is committed (HEAD is contained in the target, or
#                   there is no target): uncommitted changes (staged, unstaged and
#                   untracked) against HEAD. FROM is HEAD^{tree} — the same value an
#                   unpublished run prints once those changes are committed on a HEAD level
#                   with the target, so a ledger entry outlives the commit until the push.
#   - branch      — only with no origin/ ref to publish to: a clean tree on a non-main
#                   branch, merge-base(<main>, HEAD) → HEAD, main being the first of main,
#                   master, trunk that exists locally.
#   - initial     — a repo with no commits yet: the empty tree → the working tree.
#   - base        — with --base: merge-base(<commit>, HEAD) → the working tree, committed and
#                   uncommitted alike. /ship uses it to review exactly what it is about to
#                   publish (origin/<default> or the branch's own origin/ ref). FROM is the
#                   merge base's *tree*, not the commit, so it compares directly with the
#                   HEAD^{tree} an outstanding run printed — the base= a ledger entry carries.
#                   No merge base (unrelated histories, an unborn HEAD): the empty tree.
#   - none        — nothing to review: a clean tree whose HEAD the target already holds, a
#                   clean tree on the main branch with no target (or no main branch found),
#                   or a base that turns out to equal the working tree. Printed on
#                   its own, with no run directory; callers stop on it.
#
# The working tree is snapshotted as a tree object (a temporary index + `git add -A`, so
# untracked non-ignored files are included and the real index is untouched). Every mode
# then diffs two trees, which makes untracked files ordinary diff entries — no separate
# "read the untracked files" step — and makes a snapshot usable later as a --since base.
# The snapshot writes untracked non-ignored files into the object database and their
# contents into full.diff, so anything secret must be gitignored, not merely untracked.
#
# Output goes to $(git rev-parse --absolute-git-dir)/review/<timestamp>-<pid>/ — inside
# .git, so it is per-worktree and never committed. The 5 most recent runs are kept. In a
# linked worktree that is under the main checkout, so a worktree-isolated session writes it
# only through scripts like this one — see review-state.sh.
#   meta.txt           MODE, FROM, TREE, DIR, totals, TRANSIENT (unpublished and base mode:
#                      paths an unpublished commit under review touched that the net diff
#                      does not show,
#                      see transient_paths), and NO-CONTENT listing any changed
#                      file whose diff carries no content — a real binary, or one carrying a
#                      `-diff` attribute — see the NO-CONTENT block further down for the
#                      attribute sources and why numstat reports "-" for them.
#   stat.txt           per-file added/removed lines (numstat)
#   full.diff          the whole diff, never truncated by this script — but see NO-CONTENT
#   files/<path>.diff  one diff per changed file
#   removed-terms.txt  words the change stopped using that still occur in the tree —
#                      candidate stale vocabulary for the claims lens (heuristic, noisy;
#                      only the 80 most-removed candidates are checked)
#
# Exit status: 0 on success, including `MODE: none` (nothing to review is not a failure)
# and -h/--help; 1 for a missing work tree, a refused path (an unsafe `..` or absolute
# component, or an embedded newline), or an interrupted run;
# 2 for a bad argument. Any other git failure aborts the run under `set -e` with git's own
# status, typically 128.
#
# --no-ext-diff because an external diff tool (difftastic) drops context lines, which a
# review can't afford; --no-color because a repo may set color.ui=always, which colours a
# pipe too and would put ANSI escapes in every diff file (this repo's gitconfig does).
# --literal-pathspecs so the per-file `-- <path>` below is a path and not a glob: without
# it, `-- 'a[1].md'` also matches `a1.md` and that file's diff absorbs its neighbour.
# Renames are off, and the file lists are read NUL-delimited (-z) rather than relying on
# core.quotePath, which only suppresses quoting for non-ASCII bytes and still C-quotes a
# path containing ", \, or a control character such as a tab. core.quotePath=false is still
# set, for the path names inside the diff text itself (the `diff --git a/… b/…` headers),
# which are not -z-delimited.
# So every path in stat.txt names a real file under files/. A path containing a literal
# newline is the one case -z cannot survive here, and is unsupported.
#
# Everything runs under LC_ALL=C. This script slices diff text into words and lines, and
# a diff carries whatever bytes the repo's files do: under a UTF-8 locale, BSD `sed` exits
# with "RE error: illegal byte sequence", BSD `tr` with "Illegal byte sequence" and BSD
# `awk` with "towc: multibyte conversion failure" on the first latin-1 byte. The `sed` and
# `tr` calls inside words() sit mid-pipeline, so a failure there truncates the term list
# silently; `difflines` is a plain command, so `set -e` turns its awk failure into an
# aborted run instead. Neither outcome is acceptable for a stale-vocabulary sweep. Nothing
# here needs a locale — the terms extracted are ASCII by construction, git's plumbing
# output is not localised, and the timestamps are numeric.
set -eu
export LC_ALL=C
# Owner-only for everything this script writes: the run directory holds full.diff, which
# carries the contents of every changed and untracked non-ignored file. Set here, not in
# snapshot_tree — that runs in a command substitution, so a umask set there dies with the
# subshell and never reaches the run directory.
umask 077

usage() {
	cat <<-'EOF'
	usage: review-diff.sh [--since <tree> | --since=<tree> | --base <commit> | --base=<commit> | --target | --tree | -h | --help]
	  (no arguments)      prepare everything unpublished (or the outstanding, branch or initial diff)
	  --since <tree>      prepare only what changed since an earlier snapshot
	  --since=<tree>      the same, = form
	  --base <commit>     prepare everything since the merge base of <commit> and HEAD
	  --base=<commit>     the same, = form
	  --target            print the publish target auto mode diffs from, and exit
	  --transient <commit>
	                      print paths an unpublished commit since merge-base(<commit>, HEAD)
	                      touched that the net diff to HEAD does not show, and exit
	  --tree              print the working-tree snapshot hash and exit
	  -h, --help          print this usage and exit
	EOF
}

# --show-toplevel, not --git-dir: the latter succeeds in a bare repo, where everything
# below would instead fail with raw git diagnostics from some later command. (With GIT_DIR
# pointing at a non-bare repo, git adopts the cwd as the work tree and --show-toplevel
# succeeds; this follows git's own semantics there rather than second-guessing them.)
top=$(git rev-parse --show-toplevel 2>/dev/null) ||
	{ printf '%s\n' "review-diff.sh: not a git repository with a work tree" >&2; exit 1; }

# Pathspecs and relative paths resolve against the caller's cwd; anchor at the repo root
# so every path this script reads, writes and prints means the same thing wherever it ran.
cd "$top"

snapshot_tree() {
	# A private directory rather than a bare mktemp file: when the repo has no index yet
	# the file must not exist before `git add -A` creates it (a zero-byte GIT_INDEX_FILE is
	# fatal), and unlinking a mktemp'd name would leave that name unclaimed — a window in
	# which any process able to write the temp directory could plant a symlink git then
	# writes the index through. Inside a 0700 directory there is no window to win.
	tmpd=$(mktemp -d)
	idx=$tmpd/index
	# The signal traps must exit: a trap that only cleans up returns control to the script,
	# which would then run `git write-tree` against an index that is gone — that prints
	# the *empty tree* with status 0, and callers record it as the snapshot.
	trap 'rm -rf "$tmpd"' EXIT
	trap 'rm -rf "$tmpd"; exit 1' INT TERM HUP
	real=$(git rev-parse --git-path index)
	# The copy carries the real index's mtime: git decides an entry is "racily clean" —
	# and so re-checks it by content — by comparing the entry's cached mtime against the
	# index file's own. A fresh mtime would retire that check, letting a same-size edit
	# made in the same second as the last `git add` stay invisible to `git add -A`.
	if [ -f "$real" ]; then cp "$real" "$idx" && touch -r "$real" "$idx"; fi
	GIT_INDEX_FILE=$idx git add -A >/dev/null
	GIT_INDEX_FILE=$idx git write-tree
}

# The publish target (see the header): printed, or exit 1 when there is no origin/ ref to
# publish to. Needs a HEAD; the caller checks that.
publish_target() {
	cur=$(git branch --show-current)
	if [ -n "$cur" ] && git show-ref -q --verify "refs/remotes/origin/$cur" &&
		git merge-base --is-ancestor "origin/$cur" HEAD 2>/dev/null; then
		printf 'origin/%s\n' "$cur"
		return 0
	fi
	head_name=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)
	for b in "${head_name#origin/}" main master trunk; do
		[ -n "$b" ] || continue
		if git show-ref -q --verify "refs/remotes/origin/$b"; then
			printf 'origin/%s\n' "$b"
			return 0
		fi
	done
	return 1
}

# Paths a commit in <range> touched that the net diff <from> → <to> does not show: a file
# added in one unpublished commit and removed in a later one, or changed and changed back.
# A tree-to-tree review never sees them, yet a push publishes every commit, so their
# content reaches origin's history unread — a committed-then-deleted secret is the case
# that matters. Only commits no origin/ ref holds count — what a push would add: a branch
# that merged an updated default branch has others' published commits in its range, and
# their history is not this change's to rewrite. Printed one per line; nothing when none.
transient_paths() { # <log range> <from tree> <to tree>
	_td=$(mktemp -d)
	git log --no-show-signature --no-renames --format= --name-only -z "$1" --not --remotes=origin -- | tr '\0' '\n' | sed '/^$/d' | sort -u >"$_td/touched"
	git diff --no-renames --name-only -z "$2" "$3" -- | tr '\0' '\n' | sed '/^$/d' | sort -u >"$_td/net"
	comm -23 "$_td/touched" "$_td/net"
	rm -rf "$_td"
}

# Argument dispatch. Anything unrecognised is an error: silently falling through to auto
# mode would turn a mistyped --since into a full re-review that still looks successful.
since=""
pubbase=""
range=""   # the commits under review, in unpublished and base mode, for the TRANSIENT check
case ${1:-} in
	'')
		[ $# -eq 0 ] || { printf '%s\n' "review-diff.sh: unexpected argument: '$1'" >&2; usage >&2; exit 2; }
		;;
	--since)
		[ $# -eq 2 ] || { printf '%s\n' "review-diff.sh: --since needs exactly one tree-ish" >&2; usage >&2; exit 2; }
		since=$(git rev-parse -q --verify "$2^{tree}") ||
			{ printf '%s\n' "review-diff.sh: --since: not a tree-ish: '$2'" >&2; exit 2; }
		;;
	--since=*)
		[ $# -eq 1 ] || { printf '%s\n' "review-diff.sh: --since= takes no further arguments" >&2; usage >&2; exit 2; }
		since=$(git rev-parse -q --verify "${1#--since=}^{tree}") ||
			{ printf '%s\n' "review-diff.sh: --since: not a tree-ish: '${1#--since=}'" >&2; exit 2; }
		;;
	--base)
		[ $# -eq 2 ] || { printf '%s\n' "review-diff.sh: --base needs exactly one commit" >&2; usage >&2; exit 2; }
		pubbase=$(git rev-parse -q --verify "$2^{commit}") ||
			{ printf '%s\n' "review-diff.sh: --base: not a commit: '$2'" >&2; exit 2; }
		pubname=$2
		;;
	--base=*)
		[ $# -eq 1 ] || { printf '%s\n' "review-diff.sh: --base= takes no further arguments" >&2; usage >&2; exit 2; }
		pubbase=$(git rev-parse -q --verify "${1#--base=}^{commit}") ||
			{ printf '%s\n' "review-diff.sh: --base: not a commit: '${1#--base=}'" >&2; exit 2; }
		pubname=${1#--base=}
		;;
	--target)
		[ $# -eq 1 ] || { printf '%s\n' "review-diff.sh: --target takes no arguments" >&2; usage >&2; exit 2; }
		git rev-parse -q --verify HEAD >/dev/null 2>&1 ||
			{ printf '%s\n' "review-diff.sh: no commits yet, so nothing to publish" >&2; exit 1; }
		publish_target ||
			{ printf '%s\n' "review-diff.sh: no origin/ ref to publish to" >&2; exit 1; }
		exit 0
		;;
	--transient)
		[ $# -eq 2 ] || { printf '%s\n' "review-diff.sh: --transient needs exactly one commit" >&2; usage >&2; exit 2; }
		tbase=$(git rev-parse -q --verify "$2^{commit}") ||
			{ printf '%s\n' "review-diff.sh: --transient: not a commit: '$2'" >&2; exit 2; }
		git rev-parse -q --verify HEAD >/dev/null 2>&1 ||
			{ printf '%s\n' "review-diff.sh: no commits yet, so no history to check" >&2; exit 1; }
		if tmb=$(git merge-base "$tbase" HEAD 2>/dev/null); then
			transient_paths "$tmb..HEAD" "$tmb" HEAD
		else
			transient_paths HEAD "$(git hash-object -t tree /dev/null)" HEAD
		fi
		exit 0
		;;
	--tree)
		[ $# -eq 1 ] || { printf '%s\n' "review-diff.sh: --tree takes no arguments" >&2; usage >&2; exit 2; }
		snapshot_tree
		exit 0
		;;
	-h|--help)
		[ $# -eq 1 ] || { printf '%s\n' "review-diff.sh: $1 takes no arguments" >&2; usage >&2; exit 2; }
		usage
		exit 0
		;;
	*)
		printf '%s\n' "review-diff.sh: unknown argument: '$1'" >&2
		usage >&2
		exit 2
		;;
esac

empty_tree=$(git hash-object -t tree /dev/null)   # used by initial mode and the no-merge-base fallback
tree=$(snapshot_tree)

if [ -n "$since" ]; then
	mode="delta"
	from=$since
elif [ -n "$pubbase" ]; then
	if mb=$(git merge-base "$pubbase" HEAD 2>/dev/null); then
		mode="base ($pubname...HEAD)"
		from=$(git rev-parse "$mb^{tree}")
		range=$mb..HEAD
	else
		mode="base (no merge base with $pubname — reviewing everything)"
		from=$empty_tree
		git rev-parse -q --verify HEAD >/dev/null 2>&1 && range=HEAD
	fi
elif ! git rev-parse -q --verify HEAD >/dev/null 2>&1; then
	mode="initial"
	from=$empty_tree
elif target=$(publish_target); then
	if ! mb=$(git merge-base "$target" HEAD 2>/dev/null); then
		mode="unpublished (no merge base with $target — reviewing everything)"
		from=$empty_tree
		range=HEAD
	elif [ "$mb" != "$(git rev-parse HEAD)" ]; then
		mode="unpublished ($target...HEAD)"
		from=$(git rev-parse "$mb^{tree}")
		range=$mb..HEAD
	else
		# HEAD is contained in the target: nothing committed is unpublished, so the change is
		# whatever is uncommitted — the outstanding diff, or nothing at all.
		from=$(git rev-parse 'HEAD^{tree}')
		if [ "$tree" = "$from" ]; then
			printf '%s\n' "MODE: none — nothing unpublished: $target holds HEAD and the working tree is clean"
			exit 0
		fi
		mode="outstanding"
	fi
# "Is the tree dirty?" is asked of the snapshot, not of `git status`: the snapshot is what
# every mode then diffs, and the two disagree under ordinary config. `git status` honours
# status.showUntrackedFiles=no (so a new file would read as a clean tree while `git add -A`
# captures it in full) and reports a dirty submodule the snapshot cannot see.
elif head_tree=$(git rev-parse 'HEAD^{tree}') && [ "$tree" != "$head_tree" ]; then
	mode="outstanding"
	from=$head_tree
else
	# Reached only when no origin/ ref resolves (publish_target above found none), so the
	# main branch can only be a local one. Walk until one exists.
	base=""; main=""
	for b in main master trunk; do
		if git show-ref -q --verify "refs/heads/$b"; then
			base=$b; main=$b
			break
		fi
	done
	cur=$(git branch --show-current)
	if [ -z "$base" ] || [ "$cur" = "$main" ]; then
		if [ -z "$base" ]; then
			printf '%s\n' "MODE: none — no main branch found (no origin/ ref, and no local main, master or trunk); nothing to review"
		else
			printf '%s\n' "MODE: none — clean working tree on the main branch $main; nothing to review"
		fi
		exit 0
	fi
	if from=$(git merge-base "$base" HEAD 2>/dev/null); then
		mode="branch ($base...HEAD)"
	else
		# No common ancestor — an orphan branch, or grafted/unrelated histories. Everything
		# on the branch is the change under review, which is what `initial` mode does too.
		# Without this, `git merge-base` exits 1 printing nothing, `set -e` kills the run,
		# and the caller gets a non-zero status with no MODE: line to act on.
		mode="branch (${cur:-HEAD} has no merge base with $base — reviewing the whole branch)"
		from=$empty_tree
	fi
fi

gd() { git --literal-pathspecs -c core.quotePath=false diff --no-ext-diff --no-textconv --no-color --no-renames "$@"; }
# -U3 pins the context count against a repo- or user-set diff.context, which would
# otherwise strip the surrounding lines out of every prepared diff — the one property the
# artifact exists to provide. It goes on the patch calls only: -U implies --patch, so in
# gd() it would make the --numstat call append the whole patch after its records (verified
# on git 2.50.1; --name-only is unaffected).

# An empty diff is reported the same way as having no base at all, so callers need only
# the one check. A delta whose fixes were all rejected lands here.
if gd --quiet "$from" "$tree"; then
	printf '%s\n' "MODE: none — the working tree is identical to the base $from ($mode); nothing to review"
	exit 0
fi

# Same root review-state.sh computes — keep the two in step. That script is how the skills
# append to the ledger beside these run directories and delete the lot after a push.
root=$(git rev-parse --absolute-git-dir)/review
dir=$root/$(date +%Y%m%d-%H%M%S)-$$
mkdir -p "$dir/files"

gd -U3 "$from" "$tree" >"$dir/full.diff"
# git's output lands in a file before it is transformed: a pipeline's status is its last
# command's, so `gd | tr` would hide a git that died mid-stream and leave a short stat.txt
# — which the fan-out plans its areas from and checks two of its mechanical coverage
# rules against, so a truncated one yields a review that passes its own check having
# read less.
gd --numstat -z "$from" "$tree" >"$dir/.numstat"
tr '\0' '\n' <"$dir/.numstat" >"$dir/stat.txt"
gd --name-only -z "$from" "$tree" >"$dir/.names"
# A path containing a newline would survive -z but split in two here, and each half would
# pass the guard below, get its own mkdir, and match no pathspec — two fabricated paths
# with empty diffs, which is exactly the "reviewer trusts an empty diff" failure the
# NO-CONTENT list exists to prevent, with nothing announcing it. Refuse instead: the NUL
# record count and the line count after tr must agree.
nrec=$(tr -dc '\0' <"$dir/.names" | wc -c | tr -d ' ')
tr '\0' '\n' <"$dir/.names" >"$dir/.paths"
[ "$nrec" -eq "$(wc -l <"$dir/.paths" | tr -d ' ')" ] ||
	{ printf '%s\n' "review-diff.sh: refusing a changed path containing a newline" >&2; exit 1; }
while IFS= read -r path; do
	# The path becomes an output location, and it is repo-controlled text. git's index
	# rejects ".." as a component, but a *tree object* can hold one and `git diff` emits
	# it, so a hostile clone (fsck is off by default on fetch) could otherwise drive
	# mkdir and the redirect below to an arbitrary place on the filesystem — outstanding
	# mode diffs HEAD's tree without ever checking it out.
	case $path in
		/* | .. | ../* | */../* | */..)
			printf '%s\n' "review-diff.sh: refusing unsafe path from the diff: $path" >&2; exit 1 ;;
	esac
	# ${path%/*} rather than `dirname`, which parses a leading "-" as an option.
	case $path in */*) sub=${path%/*} ;; *) sub=. ;; esac
	mkdir -p "$dir/files/$sub"
	gd -U3 "$from" "$tree" -- "$path" >"$dir/files/$path.diff"
done <"$dir/.paths"

# Content lines of the diff, removed ("-") or added ("+"). The split is positional — from
# the first hunk header to the next file header — so a changed line that itself starts
# with "--" or "++" is not mistaken for one of the "--- a/x" / "+++ b/x" file headers.
difflines() {
	awk -v want="$1" '
		/^diff --git /			{ inhunk = 0; next }
		/^@@/				{ inhunk = 1; next }
		!inhunk				{ next }
		substr($0, 1, 1) == want	{ print substr($0, 2) }
	' "$dir/full.diff"
}

# Candidate stale vocabulary: words (split on camelCase, underscores and punctuation,
# lowercased, 4+ chars) that appear on removed lines, never on added lines, yet still
# occur somewhere in the tree. A reviewer judges which are real leftovers.
words() {
	sed -E 's/([a-z0-9])([A-Z])/\1 \2/g' | tr 'A-Z' 'a-z' |
		tr -cs 'a-z0-9' '\n' | awk 'length >= 4' | sort | uniq -c
}
# difflines is run as its own command rather than piped into words(), so `set -e` sees its
# awk fail instead of the status being masked by the pipeline's last stage. words()'s own
# internal stages stay unchecked: its sed and tr do see raw diff bytes, but the LC_ALL=C
# exported at the top is what keeps them from failing on one.
difflines - >"$dir/.rawremoved"
difflines + >"$dir/.rawadded"
words <"$dir/.rawremoved" >"$dir/.removed"
words <"$dir/.rawadded" >"$dir/.added"
# Keyed on FILENAME, not NR==FNR: a deletion-only change leaves .added empty, and NR==FNR
# would then stay true for every line of .removed and file the whole vocabulary as "added".
awk -v af="$dir/.added" 'FILENAME == af { added[$2] = 1; next } !($2 in added) { print $1, $2 }' \
	"$dir/.added" "$dir/.removed" |
	sort -rn | head -n 80 >"$dir/.candidates"
# One grep over the whole tree for all candidates at once, not one per term: grepping a
# tree object has to inflate every blob, and the per-term loop this replaces accounted for
# most of the script's runtime. `-z` emits "<tree>:<path>\0<line>\n", so `tr` turns each
# hit into a path line followed by one or more content lines, and awk attaches each
# content line to the last path line it saw — BSD awk cannot take NUL as a field
# separator, and `git grep -o` cannot do this tally at all,
# because its matches are non-overlapping, so a candidate that is a substring of another
# ("refer" inside "reference") would be undercounted.
# --no-color because a repo may set color.ui=always, which colours a pipe too and would
# break the "<tree>:" anchor below (the same reason gd() passes it); grep.lineNumber and
# grep.column are pinned off for the same reason — either one inserts a further
# NUL-delimited record per hit, which `tr` then turns into an extra line that the anchor
# reads as content and tallies terms against. -I to match how still-in is described.
# Skipped when there are no candidates: git would otherwise read the pattern from the
# positional arguments, so $tree would become the search term and the tree grep a
# working-tree one.
cut -d' ' -f2 <"$dir/.candidates" >"$dir/.terms"
: >"$dir/.hits"
if [ -s "$dir/.terms" ]; then
	# One alternation pattern rather than `-F -f <file>`: given many fixed patterns git
	# matches every line against each of them in turn, which costs superlinearly in their
	# number — on an 8000-file tree, 1 term took 0.2s, 10 took 3.9s and the full 80 took
	# 178s, which is nearly all of what made this script slow. A single pattern is one
	# automaton over the same bytes: 4.7s under -P, 14s under -E, and byte-identical
	# output in both cases. Alternation of literals matches exactly what -F did, substring
	# semantics included, because the terms cannot contain a metacharacter: words() builds
	# them through `tr -cs 'a-z0-9'`, so each is [a-z0-9]+. That invariant is now load
	# bearing — a term carrying anything else would be read as a regex and silently
	# change what gets counted — so it is checked rather than assumed.
	# One char minimum, not zero: an empty line would make `paste` emit an empty
	# alternative, which matches every line of the tree and would report every candidate
	# as still in use everywhere.
	if LC_ALL=C grep -qv '^[a-z0-9][a-z0-9]*$' "$dir/.terms"; then
		printf '%s\n' "review-diff.sh: refusing a candidate term outside [a-z0-9]" >&2; exit 1
	fi
	alt=$(paste -sd'|' "$dir/.terms")
	# -P where this git has PCRE2, -E otherwise (it is a build option, and -P on a git
	# built without it fails with status 128 and no output). Probed against the empty
	# tree: git compiles the patterns before walking anything, so the probe costs one
	# process and no blobs, and a working -P reports 1 for "no matches" rather than 0.
	gp=0; git grep -q -I -P -e x "$empty_tree" -- 2>/dev/null || gp=$?
	if [ "$gp" -le 1 ]; then re=-P; else re=-E; fi
	# git grep exits 1 for "no matches" and 2+ for an error. Swallowing everything would
	# make a sweep that never ran read as a sweep that found nothing — and the claims
	# lens's coverage is checked against this file's line count, so an empty file reads
	# as complete coverage.
	{ git -c grep.lineNumber=false -c grep.column=false grep -z -i -I "$re" --no-color \
		-e "$alt" "$tree" -- || gs=$?; [ "${gs:-0}" -le 1 ] ||
		printf '%s\n' "review-diff.sh: git grep failed ($gs); removed-terms.txt may be incomplete" >&2; } |
		tr '\0' '\n' |
		awk -v tf="$dir/.terms" -v tree="$tree" '
			FILENAME == tf { terms[$0] = 1; next }
			# Anchor on the "<tree>:" prefix rather than pairing lines by parity: -I only
			# skips files with a NUL in their first 8000 bytes, so a later NUL survives tr
			# as an extra line and parity would invert paths and content for the whole
			# rest of the stream. Here a stray line is just more content for the same file.
			# "Binary file <tree>:<path> matches" carries no content and no path record.
			# -I already keeps it away, so this and -I are belt-and-braces: with both in
			# place neither is individually observable, which is the intent — the tally
			# must not depend on a single flag surviving a future edit.
			index($0, "Binary file " tree ":") == 1 { next }
			index($0, tree ":") == 1 { path = substr($0, length(tree) + 2); next }
			# A third belt: content arriving before any path record is dropped rather than
			# tallied against an empty path. Unreachable while the two guards above hold.
			path == "" { next }
			{ line = tolower($0)
			  for (t in terms) if (index(line, t) && !seen[t SUBSEP path]++) files[t]++ }
			END { for (t in files) print t, files[t] }' "$dir/.terms" - >"$dir/.hits"
fi
awk -v hf="$dir/.hits" 'FILENAME == hf { files[$1] = $2; next }
	($2 in files) { print $2 "  removed=" $1 "  still-in=" files[$2] " file(s)" }' \
	"$dir/.hits" "$dir/.candidates" >"$dir/removed-terms.txt"
rm -f "$dir/.removed" "$dir/.added" "$dir/.rawremoved" "$dir/.rawadded" "$dir/.candidates" "$dir/.terms" "$dir/.hits" "$dir/.numstat" "$dir/.names" "$dir/.paths"

nfiles=$(wc -l <"$dir/stat.txt" | tr -d ' ')
adds=$(awk '$1 != "-" { s += $1 } END { print s + 0 }' "$dir/stat.txt")
dels=$(awk '$2 != "-" { s += $2 } END { print s + 0 }' "$dir/stat.txt")
lines=$(wc -l <"$dir/full.diff" | tr -d ' ')
# Paths whose diff carries no content: git reports "-" in numstat both for a genuinely
# binary file and for one carrying a `-diff` attribute — from a .gitattributes in the repo
# (tracked, or untracked and not gitignored — the snapshot adds untracked non-ignored
# files, so a changed one shows up in the diff), or from .git/info/attributes or the global
# or system attributes file, which never do. Either way the file is unreadable in the
# diff and weightless in the added/removed totals above. A reviewer handed such a path
# cannot trust an empty diff, so name them where meta.txt is read first — hedged, because
# dumping a real binary into a reviewing agent is what --text was rejected for.
# One path per line, and everything after the second tab — numstat -z leaves paths
# unquoted, so a tab or a space inside one must not be split on or joined over.
nocontent=$(awk -F'\t' '$1 == "-" { sub(/^[^\t]*\t[^\t]*\t/, ""); print }' "$dir/stat.txt")
transient=""
[ -n "$range" ] && transient=$(transient_paths "$range" "$from" "$tree")
{
	printf '%s\n' "MODE: $mode"
	printf '%s\n' "FROM: $from"
	printf '%s\n' "TREE: $tree"
	printf '%s\n' "DIR: $dir"
	printf '%s\n' "FILES: $nfiles (+$adds -$dels), full.diff $lines lines"
	if [ -n "$nocontent" ]; then
		printf '%s\n' "NO-CONTENT: no diff content (binary, or a -diff attribute from any source git honours); open these yourself if they are text:"
		printf '%s\n' "$nocontent" | sed 's/^/  /'
	fi
	if [ -n "$transient" ]; then
		printf '%s\n' "TRANSIENT: changed by an unpublished commit under review but not in the diff, so no reviewer sees them; a push still publishes that history ($range, less what origin holds):"
		printf '%s\n' "$transient" | sed 's/^/  /'
	fi
} >"$dir/meta.txt"

# Keep the 5 most recent runs (this one included). This run is excluded from the
# candidates rather than ranked among them: directory names are <timestamp>-<pid>, and
# `sort -r` compares them as strings, so two runs in the same second sort by PID digits
# ("9952" above "10018") and the newest could otherwise evict itself. Pruned only now
# that this run is complete, so a run that dies partway through cannot evict a finished one.
ls -1d "$root"/*/ 2>/dev/null | grep -vFx "$dir/" | sort -r | tail -n +5 |
	while IFS= read -r old; do rm -rf "$old"; done

cat "$dir/meta.txt"
printf '%s\n' "STAT (added removed path):"
cat "$dir/stat.txt"
