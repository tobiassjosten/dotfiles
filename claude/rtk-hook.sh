#!/bin/sh
# PreToolUse hook for Bash: let rtk rewrite the command for token savings, except where the
# rewrite would get the command refused.
#
# In a linked worktree, a Claude Code session is usually worktree-isolated, and isolation
# refuses any command whose git it cannot verify stays in the tree. `rtk git status` is one:
# git is an operand of rtk, so the harness cannot read where it runs ("runs rtk with a git
# command among its operands"), and the check cannot be configured off. So in a linked
# worktree a rewrite that introduces `rtk git` is dropped and the command runs as written;
# every other rewrite, there and everywhere else, passes through.
#
# No rtk means no rewrite, like the inline hook this replaced; the settings.json entry
# also skips quietly while this file is not yet linked into ~/.claude. Without jq the
# worktree test cannot run, so a rewrite introducing `rtk git` is dropped wherever the
# session is — failing safe — while every other rewrite still passes through.
command -v rtk >/dev/null 2>&1 || exit 0

input=$(cat)
out=$(printf '%s' "$input" | rtk hook claude) || exit 0

case $out in
*'rtk git'*)
	command -v jq >/dev/null 2>&1 || exit 0
	cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
	[ -n "$cwd" ] || cwd=$PWD
	gitdir=$(git -C "$cwd" rev-parse --absolute-git-dir 2>/dev/null) || gitdir=
	common=$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || common=
	# A linked worktree's git dir is .git/worktrees/<name>, not the common .git.
	[ -n "$gitdir" ] && [ "$gitdir" != "$common" ] && exit 0
	;;
esac

printf '%s' "$out"
