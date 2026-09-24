#!/bin/sh
# Prepare the changes under review as files on disk and print a short summary.
# Shared by /review, /polish, /ship and the code-reviewer agent (via review-fanout.md)
# so base selection and diff preparation live in one place. /review-pr and /focused-review
# gather their own diffs and do not use this script.
#
# Usage:
#   review-diff.sh                 # auto: outstanding, branch, or initial (see below)
#   review-diff.sh --since <tree>  # delta: only what changed since an earlier snapshot
#   review-diff.sh --since=<tree>  # the same, = form
#   review-diff.sh --tree          # print the working-tree snapshot hash and exit
#   review-diff.sh -h, --help      # print the usage and exit
#
# Modes (auto):
#   - outstanding — uncommitted changes (staged, unstaged and untracked) against HEAD.
#   - branch      — clean tree on a non-main branch: merge-base(<main>, HEAD) → HEAD.
#                   main is whatever origin/HEAD names, then main/master/trunk — taking the
#                   first candidate that resolves as either a local branch or an origin/ ref,
#                   so a stale origin/HEAD falls through instead of stranding the run. When
#                   both the local and origin/ refs exist, the more up-to-date wins so a stale
#                   local main doesn't blame others' already-merged commits on the branch.
#   - initial     — a repo with no commits yet: the empty tree → the working tree.
#   - none        — nothing to review: a clean tree on the main branch (or no main branch
#                   found), or a base that turns out to equal the working tree. Printed on
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
# .git, so it is per-worktree and never committed. The 5 most recent runs are kept.
#   meta.txt           MODE, FROM, TREE, DIR, totals, and NO-CONTENT listing any changed
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
	usage: review-diff.sh [--since <tree> | --since=<tree> | --tree | -h | --help]
	  (no arguments)      prepare the outstanding, branch or initial diff
	  --since <tree>      prepare only what changed since an earlier snapshot
	  --since=<tree>      the same, = form
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

# Argument dispatch. Anything unrecognised is an error: silently falling through to auto
# mode would turn a mistyped --since into a full re-review that still looks successful.
since=""
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
elif ! git rev-parse -q --verify HEAD >/dev/null 2>&1; then
	mode="initial"
	from=$empty_tree
# "Is the tree dirty?" is asked of the snapshot, not of `git status`: the snapshot is what
# every mode then diffs, and the two disagree under ordinary config. `git status` honours
# status.showUntrackedFiles=no (so a new file would read as a clean tree while `git add -A`
# captures it in full) and reports a dirty submodule the snapshot cannot see.
elif head_tree=$(git rev-parse 'HEAD^{tree}') && [ "$tree" != "$head_tree" ]; then
	mode="outstanding"
	from=$head_tree
else
	# Candidates in order: whatever origin/HEAD points at, then the conventional names.
	# Walk until one actually *resolves*. Testing only whether origin/HEAD produced a name
	# would strand the review on a stale pointer — an upstream default-branch rename plus a
	# prune leaves origin/HEAD naming a ref that is gone, and the run would then report
	# "nothing to review" while sitting on a branch full of commits.
	head_name=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)
	base=""; main=""
	for b in "${head_name#origin/}" main master trunk; do
		[ -n "$b" ] || continue
		loc=""; rem=""
		git show-ref -q --verify "refs/heads/$b" && loc=$b
		git show-ref -q --verify "refs/remotes/origin/$b" && rem=origin/$b
		[ -n "$loc" ] || [ -n "$rem" ] || continue
		main=$b
		if [ -n "$loc" ] && [ -n "$rem" ]; then
			if git merge-base --is-ancestor "$loc" "$rem" 2>/dev/null; then base=$rem; else base=$loc; fi
		else
			base=${loc:-$rem}
		fi
		break
	done
	cur=$(git branch --show-current)
	if [ -z "$base" ] || [ "$cur" = "$main" ]; then
		if [ -z "$base" ]; then
			printf '%s\n' "MODE: none — no main branch found (looked for origin/HEAD, then main, master, trunk); nothing to review"
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
# ("refer" inside "reference") would be undercounted. -F since the terms are literal
# [a-z0-9]+ by construction; --no-color because a repo may set color.ui=always, which
# colours a pipe too and would break the "<tree>:" anchor below (the same reason gd()
# passes it); -I to match how still-in is described. Skipped when there are no candidates:
# given an empty pattern file git falls back to reading the pattern from the positional
# arguments, so $tree would become the search term and the tree grep a working-tree one.
cut -d' ' -f2 <"$dir/.candidates" >"$dir/.terms"
: >"$dir/.hits"
if [ -s "$dir/.terms" ]; then
	# git grep exits 1 for "no matches" and 2+ for an error. Swallowing everything would
	# make a sweep that never ran read as a sweep that found nothing — and the claims
	# lens's coverage is checked against this file's line count, so an empty file reads
	# as complete coverage.
	{ git grep -z -i -I -F --no-color -f "$dir/.terms" "$tree" -- || gs=$?; [ "${gs:-0}" -le 1 ] ||
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
