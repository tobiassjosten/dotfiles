#!/bin/sh
# Run `gh pr <subcommand> ...` against a PR reference in one of these forms:
#
#   (empty)           the PR of the current branch
#   123               PR #123 in the current directory's repo
#   repo#123          PR #123 in that repo, under the current repo's owner
#   owner/repo#123    PR #123 in owner/repo
#
# URLs are passed through to gh with any #fragment stripped (browser URLs
# often carry one, e.g. .../pull/123#pullrequestreview-42). Only the first
# whitespace-separated token of the reference is used, and only if it matches
# one of the forms above — slash-command arguments often carry trailing
# free-text instructions meant for the reviewer, which gh must not see; a
# non-ref token means "current branch's PR". The repo/owner shorthands
# require the current directory to be a repo with a GitHub remote, since
# the missing pieces are resolved from it.
set -eu

sub="$1"
shift
ref="${1-}"
[ $# -gt 0 ] && shift

ref="${ref%%[[:space:]]*}"
case "$ref" in
''|*'://'*|*'#'*) ;;
*[!0-9]*) ref='' ;;
esac

case "$ref" in
"")
    exec gh pr "$sub" "$@"
    ;;
*'://'*)
    exec gh pr "$sub" "${ref%%\#*}" "$@"
    ;;
*'#'*)
    repo="${ref%\#*}"
    num="${ref##*\#}"
    case "$repo" in
    */*) ;;
    *)
        repo="$(gh repo view --json owner --jq .owner.login)/$repo"
        ;;
    esac
    exec gh pr "$sub" "$num" --repo "$repo" "$@"
    ;;
*)
    exec gh pr "$sub" "$ref" "$@"
    ;;
esac
