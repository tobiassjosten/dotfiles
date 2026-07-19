---
name: commit
description: Commit all outstanding changes as standalone, logically coherent atomic commits using Conventional Commits.
disable-model-invocation: true
allowed-tools: Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git push:*), Bash(git status:*)
---

Commit all outstanding changes. Group related changes into standalone, logically coherent atomic commits. Each commit must be independently meaningful — do not lump unrelated changes together.

## Workflow

1. Run `git status` and `git diff` (both staged and unstaged) to understand all outstanding changes.

2. Run `git log --oneline -25` to see recent commit style for reference.

3. Analyze the changes and group them into logical units. Each group should represent one coherent change (e.g., a single feature, a single bug fix, a refactor of one concern). Consider file relationships and semantic coupling when grouping.

4. For each logical group, in a sensible order (e.g., foundational changes first):
   a. Stage only the files belonging to that group using `git add <specific files>`.
   b. Commit with a simple one-liner: `git commit -m "<type>: <description>"`
      - Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`, `perf`, `ci`, `build`
      - Description: imperative mood, lowercase, no period, max 50 characters total
      - Examples: `git commit -m "feat: add company search endpoint"`
      - Always use a plain string — no `$()`, heredocs, or multi-line messages

5. After all commits, run `git push` to push everything to GitHub.

6. Run `git log --oneline -<N>` (where N = number of new commits) to show the user what was committed.

## Rules

- Never use `git add -A` or `git add .` — always add specific files.
- Never amend existing commits.
- If there are no outstanding changes, inform the user and stop.
- Do not skip or ignore any changes — everything must be committed.
- If a pre-commit hook fails, alert the user and abort committing until the issue is resolved. Do not bypass hooks.
