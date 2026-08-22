#!/bin/sh
# Print the changes under review as a plain unified diff, prefixed with a MODE: line
# naming which case applied. Shared by the /review skill and the code-reviewer agent so
# the base-selection logic lives in one place.
#
#   - outstanding — uncommitted changes: staged and unstaged together against HEAD.
#   - branch      — clean tree on a non-main branch: <main>...HEAD (against the merge-base).
#                   main is origin/HEAD, falling back to local main/master/trunk; when both
#                   the local and origin/ refs exist, the more up-to-date wins so a stale
#                   local main doesn't blame others' already-merged commits on the branch.
#   - initial     — a repo with no commits yet: diff against the empty tree.
#
# rtk proxy + --no-ext-diff keep this a plain unified diff — the rtk filter and external
# diff tools (difftastic) drop context lines and truncate long ones, which a review can't afford.
if ! git rev-parse -q --verify HEAD >/dev/null 2>&1; then
	echo "MODE: initial (diff against the empty tree)"
	rtk proxy git diff --no-ext-diff 4b825dc642cb6eb9a060e54bf8d69288fbee4904
elif [ -n "$(git status --porcelain)" ]; then
	echo "MODE: outstanding (diff against HEAD)"
	rtk proxy git diff --no-ext-diff HEAD
else
	main=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); main=${main#origin/}
	if [ -z "$main" ]; then
		for b in main master trunk; do
			if git show-ref -q --verify refs/heads/$b; then main=$b; break; fi
		done
	fi
	base=""
	if [ -n "$main" ]; then
		loc=""; rem=""
		git show-ref -q --verify refs/heads/$main && loc=$main
		git show-ref -q --verify refs/remotes/origin/$main && rem=origin/$main
		if [ -n "$loc" ] && [ -n "$rem" ]; then
			if git merge-base --is-ancestor "$loc" "$rem" 2>/dev/null; then base=$rem; else base=$loc; fi
		else
			base=${loc:-$rem}
		fi
	fi
	cur=$(git branch --show-current)
	if [ -n "$base" ] && [ "$cur" != "$main" ]; then
		echo "MODE: branch ($base...HEAD)"
		rtk proxy git diff --no-ext-diff "$base...HEAD"
	else
		echo "MODE: clean working tree on the main branch (or no main branch found) — no diff to review"
	fi
fi
