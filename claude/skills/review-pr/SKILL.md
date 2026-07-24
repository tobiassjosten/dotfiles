---
name: review-pr
description: Review a GitHub pull request against the shared review principles. Accepts "123" (current repo), "repo#123" (current repo's owner), "owner/repo#123", or a URL. Reports Issues and Notes locally, then optionally posts them to the PR as a review.
disable-model-invocation: true
context: fork
argument-hint: [123 | repo#123 | owner/repo#123 | url]
allowed-tools: Bash(cat:*), Bash(~/.claude/skills/review-pr/gh-pr.sh:*), Bash(gh issue view:*), Bash(git fetch:*), Bash(git show:*)
---

# Pull Request Review

Review the given pull request against a fixed threshold. The aim is a bounded, useful review — not an open-ended hunt for things to flag.

The PR reference was resolved by `gh-pr.sh` (bundled with this skill), which accepts a bare number (current repo), `repo#123` (current repo's owner), `owner/repo#123`, a URL, or nothing (the current branch's PR). Anything in the arguments beyond the reference itself is ignored by the resolver — treat it as the user's guidance on what to focus the review on. Only the first argument token (`$1`, not `$ARGUMENTS`) is substituted into the embedded commands: the substitution is textual, so free-text guidance containing quotes or other shell metacharacters would otherwise break the command line before any script could defend against it.

## Shared principles

The threshold, categories, planned-work calibration, output formats, and rules below govern this review:

!`cat ~/.claude/skills/review-core.md`

## Pull request under review

Overview:

!`~/.claude/skills/review-pr/gh-pr.sh view "$1" --json number,url,title,body,author,state,isDraft,baseRefName,headRefName,additions,deletions,changedFiles`

Diff:

!`~/.claude/skills/review-pr/gh-pr.sh diff "$1"`

Discussion so far:

!`~/.claude/skills/review-pr/gh-pr.sh view "$1" --comments`

## Workflow

1. **Understand the intent.** The PR title, description, and discussion are included above. Follow linked issues if the description references them (`gh issue view <n>`). If reviewers have already left inline comments, fetch them so you don't repeat feedback: `gh api repos/<owner>/<repo>/pulls/<number>/comments` (owner, repo, and number are in the overview above). Where a candidate finding overlaps with existing feedback, either drop it or explicitly build on it — never re-raise it as if new.

2. **Build context beyond the diff.** If the diff above appears truncated — a truncation marker, or it ends mid-hunk — re-run `~/.claude/skills/review-pr/gh-pr.sh diff <ref>` to recover the full diff before reviewing. Read surrounding code as needed. If the PR belongs to the repo you are in, prefer `git fetch origin <headRefName>` and `git show FETCH_HEAD:<path>` — do not check out the branch or otherwise touch the working tree. For a PR in another repo, fetch files with `gh api repos/<owner>/<repo>/contents/<path>?ref=<headRefName>`.

3. **Check planned work.** Look for planned-work notes (`TODO.md`, `plans/`, `todo/`) in the PR's **base** repo using the same file-access methods, and calibrate per *Calibrating against planned work* in the shared principles.

4. **Review against each category.** Walk through the categories in the order listed in the shared principles. For each candidate finding, check it against the threshold before deciding whether it is an Issue or a Note.

5. **Check documentation alignment.** Per *Documentation alignment* in the shared principles, reading the docs at the PR's head ref.

6. **Present findings locally.** Use the sections and formats from *Presenting findings* in the shared principles. Present everything in the conversation first — nothing goes to GitHub yet.

7. **Ask what to post, then post it.** End by asking, e.g.: `Post to the PR? (all / e.g. 1, 3, D5 / none)`. Do not post anything before the user replies.

   - `all` or a bare confirmation → post every finding.
   - Numbers (ranges like `3–6` are valid) → post only those findings. Notes and Documentation entries are selectable here too — the Issue/Note distinction governs severity framing, not postability.
   - `none`, nothing, or similar → end without posting.

   Post the selection as a **single review** with event `COMMENT`, via `gh api repos/<owner>/<repo>/pulls/<number>/reviews`:
   - Issues that map to a line in the diff become inline comments (`path`, `line`, `side: RIGHT`), keeping their category tag and `→`/`a.`/`b.` fix format.
   - Notes, Documentation suggestions, and any finding that cannot be anchored to the diff go in the review `body`.
   - Open the review body with a one-line summary of the overall verdict.

## Rules

All rules from the shared principles apply. Additionally:

- Never modify any code — this skill reviews someone's PR; it does not fix it.
- Never post anything to GitHub before the user's explicit selection in step 7, and never post more than they selected.
- Only ever post `COMMENT` reviews. Never approve or request changes — that judgment belongs to the human.
- Phrase posted comments as coming from a reviewer: constructive, specific, no filler. The threshold framing ("Issue" vs "Note") carries over so the author knows what is blocking versus advisory.
