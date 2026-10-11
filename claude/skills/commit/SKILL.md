---
name: commit
description: Commit all outstanding changes as standalone, logically coherent atomic commits using Conventional Commits. Never pushes — publishing (pushing a branch, pushing the default branch, integrating a worktree) is /ship's. In a project that works with feature branches, refuses to commit on the default branch and offers to create a branch instead.
disable-model-invocation: true
allowed-tools: Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git symbolic-ref --short refs/remotes/origin/HEAD), Bash(git remote), Bash(git show origin/*), Bash(git cat-file -e origin/*), Bash(test -e:*), Bash(git branch --show-current), Bash(git switch -c:*), Bash(sh ~/.claude/skills/task-marker.sh get), Bash(sh ~/.claude/skills/task-marker.sh set:*), AskUserQuestion
---

Commit all outstanding changes. Group related changes into standalone, logically coherent atomic commits. Each commit must be independently meaningful — do not lump unrelated changes together.

**This skill never pushes.** Publishing the commits — pushing a feature branch to its namesake on `origin`, pushing the default branch, or integrating a linked worktree's branch onto the default branch — is `/ship`'s (`~/.claude/skills/publish.md`). From a linked worktree it commits on the tree's branch and the session stays in the tree.

## Which branch

Before committing, find out whether there is anything to commit and whether this branch takes it:

0. If there are no outstanding changes (`git status --porcelain --untracked-files=all` prints nothing — the flag overrides a repo's `status.showUntrackedFiles=no`, which would hide a change made only of new files), inform the user and stop — before any branch question, so a clean tree is never offered a branch it has nothing to put on.
1. Name `<default>` as `publish.md` § *Names used below* does. With no `origin` remote at all, go to *Workflow*: there is no default branch to protect. With an `origin` that has no recorded `HEAD`, stop and tell the user to run `git remote set-head origin --auto` — there is a default branch, and committing before it is known could put a feature-branch project's work on it.
2. Compare it with `git branch --show-current`. On any other branch, go to *Workflow*. This holds in a linked worktree too: a tree is normally on a branch of its own, but git lets one check out the default branch while the main checkout is on another.
3. On `<default>`, decide the project's branch model per `publish.md` § *Branch model*. If the project **says** it works with feature branches (step 1 of that section — the fallback on the current branch never refuses), do not commit here. Ask once (`AskUserQuestion`):
   - **Create a branch** — offer a name that follows the project's own branch-naming rule where it states one (e.g. the issue key), else a short kebab-case description of the change; the bound task's `ID` (`sh ~/.claude/skills/task-marker.sh get`) is a good source for either. On the user's choice, `git switch -c <name>`, which carries the uncommitted changes along — and any commits the local `<default>` holds that `origin` lacks (`git log --oneline origin/<default>..HEAD` lists any): say that those go onto the branch and also stay on the local `<default>` until the user resets it to `origin/<default>`. If a task marker is bound, refresh it so its `BRANCH` follows: `sh ~/.claude/skills/task-marker.sh set --source <SOURCE> --id <ID>`, plus `--title <TITLE>` and `--base <BASE>` when the marker has them, every field carried over from `get` (`set` rewrites the whole marker). Then go to *Workflow*.
   - **Stop** — commit nothing.

## Workflow

1. Run `git status --untracked-files=all` and `git diff` (both staged and unstaged) to understand all outstanding changes — the same set step 0 found, new files included.

2. Run `git log --oneline -25` to see recent commit style for reference.

3. Analyze the changes and group them into logical units. Each group should represent one coherent change (e.g., a single feature, a single bug fix, a refactor of one concern). Consider file relationships and semantic coupling when grouping.

4. For each logical group, in a sensible order (e.g., foundational changes first):
   a. Stage only the files belonging to that group using `git add <specific files>`.
   b. Commit with a simple one-liner: `git commit -m "<type>: <description>"`
      - Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `style`, `perf`, `ci`, `build`
      - Description: imperative mood, lowercase, no period, max 50 characters total
      - Examples: `git commit -m "feat: add company search endpoint"`
      - Always use a plain string — no `$()`, heredocs, or multi-line messages

5. Run `git log --oneline -<N>` (where N = number of new commits) to show the user what was committed, and say that nothing was pushed: `/ship` publishes it — its verification and review gates run on the committed work too.

## Rules

- **Never push**, in any form — not `git push`, not an integration, not on request phrased as part of committing. Name `/ship` instead.
- Never use `git add -A` or `git add .` — always add specific files.
- Never amend existing commits.
- Commit the working tree exactly as it stands. Never add, restore, reword, or complete content as part of committing — not to satisfy an acceptance criterion, not to match a review summary, not to replace something that looks missing. Content absent from the tree was removed deliberately; the user edits the tree while reviewing, and those edits are their feedback.
- If the tree contradicts the issue or the review record — a ticked criterion whose change isn't there — stop before committing and report the discrepancy rather than reconciling it yourself.
- If there are no outstanding changes, inform the user and stop (*Which branch* step 0).
- Do not skip or ignore any changes — everything must be committed.
- If a pre-commit hook fails, alert the user and abort committing until the issue is resolved. Do not bypass hooks.
