---
name: review
description: Review all outstanding changes — or, when the working tree is clean on a non-main branch, the branch's diff from the main branch. Reports Issues (anything that could cause user problems, security risk, or data inconsistency) and optional Notes for further improvement.
disable-model-invocation: true
context: fork
allowed-tools: Bash(cat:*), Bash(echo:*), Bash(sh ~/.claude/skills/review-diff.sh:*), Bash(git status:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(git show-ref:*), Bash(git branch:*), Bash(git merge-base:*), Bash(rtk proxy git diff:*)
---

# Code Review

Review the changes under review (outstanding changes, or the branch diff when the tree is clean — see below) against a fixed threshold. The aim is a bounded, useful review — not an open-ended hunt for things to flag.

## Shared principles

The threshold, categories, planned-work calibration, review method, output formats, and rules below govern this review:

!`cat ~/.claude/skills/review-core.md`

## Changes under review

Working tree status:

!`git status --untracked-files=all`

The diff below picks its base automatically; the `MODE:` line at its top says which case applies:

- **outstanding** — there are uncommitted changes: staged and unstaged together against `HEAD` (staging state is irrelevant).
- **branch** — the working tree is clean and the current branch is not the main branch: the branch's changes since it diverged from the main branch (`<main>...HEAD`, i.e. against the merge-base). The main branch is whatever `origin/HEAD` points at, falling back to a local `main`, `master`, or `trunk`; when both the local and `origin/` refs exist, the more up-to-date of the two is the base — a stale local main would otherwise blame others' already-merged commits on the branch.
- **initial** — a repo with no commits yet: the diff against the empty tree.

`rtk proxy` and `--no-ext-diff` keep this a plain unified diff — the rtk filter and external diff tools (difftastic) drop context lines and truncate long ones, which a review can't afford. The base-selection logic lives in `~/.claude/skills/review-diff.sh`, shared with the `code-reviewer` agent:

!`sh ~/.claude/skills/review-diff.sh`

## Workflow

1. **Complete the picture.** The status and diff are included above. Read every untracked file listed in the status in full — they are part of the change but absent from the diff (in branch mode the tree is clean, so there are none). If the diff appears truncated — a truncation marker, or it ends mid-hunk — re-run `rtk proxy git diff --no-ext-diff <base>` with Bash, using the base named on the `MODE:` line, to recover the full diff before reviewing.

2. **Understand the intent and planned work.** Before critiquing, understand what the changes are trying to accomplish. Read surrounding code and related files as needed to build context. Check the repo for planned-work notes (e.g., `TODO.md`, a `plans/` or `todo/` directory) and read what's relevant — see *Calibrating against planned work* in the shared principles.

3. **Review against each category.** Walk through the categories in the order listed in the shared principles. For each candidate finding, check it against the threshold before deciding whether it is an Issue or a Note.

4. **Check documentation alignment.** Per *Documentation alignment* in the shared principles.

5. **Present findings.** Use the sections and formats from *Presenting findings* in the shared principles.

6. **Ask which Issues to fix, then implement them.** If the review surfaced one or more Issues, end the review by asking the user which to proceed to fix. Do not modify any code yet — wait for the user's reply.

   Prompt them with a short line like: `Which to fix? (e.g. 1b, 2, 3a, 5 (with the database), 6, 8, D11)`. The full numbered findings list is already on screen above, so do not restate the Issues.

   Expect free-text input naming Issues by number, optionally with a fix-option letter and/or a parenthetical hint. Examples of valid input:
   - `2` — fix Issue 2 (apply the only fix, or option `a.` if there are several).
   - `3a` — fix Issue 3 using option `a.`.
   - `5 (with the database)` — fix Issue 5; the parenthetical is the user's steer on how — honor it, picking the option or approach that matches.
   - `1b, 2, 3a, 5 (with the database), 6, 8` — apply each in turn.
   - Ranges like `3–6` are also valid and mean every Issue in that range.

   For each named Issue:
   - Single fix (`→`): apply it.
   - Multiple fix options (`a.`, `b.`, `c.`) with no letter or hint from the user: apply option `a.` and mention which one you used in your implementation summary, so the user can redirect — e.g., "for #3 I applied option a; reply if you'd prefer b".
   - Parenthetical hint: pick the option or approach that matches the hint. If no listed option fits, follow the hint directly and note what you did.

   Notes are below the threshold and are never offered for selection — ignore any Note numbers the user names, and say so.

   Documentation suggestions can be applied alongside Issue fixes. The user names them with a `D` prefix (e.g., `D11`) or naturally in a parenthetical. Apply them as straightforward doc edits.

   If the user replies with nothing, "none", or similar, end without implementing anything.

## Rules

All rules from the shared principles apply. Additionally:

- Only implement Issues the user explicitly picks in step 6 — never before, never others.
