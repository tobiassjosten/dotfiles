---
name: commit
description: Commit all outstanding changes as standalone, logically coherent atomic commits using Conventional Commits, and push them. From a linked worktree, push only where the project opts in — by pushing the branch to the default branch, integrating it in the main checkout and removing the worktree; elsewhere commit on the branch and stop with the by-hand steps.
disable-model-invocation: true
allowed-tools: Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git fetch:*), Bash(git log:*), Bash(git push:*), Bash(git rebase:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git symbolic-ref --short refs/remotes/origin/HEAD), Bash(git merge-base:*), Bash(git show origin/*), Bash(git cat-file -e origin/*), Bash(git remote), Bash(git merge --ff-only:*), Bash(git branch --show-current), Bash(git branch -d:*), Bash(git worktree remove:*), Bash(test -e:*), Bash(sh ~/.claude/skills/task-marker.sh get), ExitWorktree, AskUserQuestion
---

Commit all outstanding changes. Group related changes into standalone, logically coherent atomic commits. Each commit must be independently meaningful — do not lump unrelated changes together.

This runs in the main conversation, not a fork: from a linked worktree it has to move the session out of the tree (`ExitWorktree`), and a forked agent's move would only move the fork. A skill that runs it from a fork must not do so from a linked worktree.

## Which tree

Run `git rev-parse --path-format=absolute --git-dir --git-common-dir` — `--path-format=absolute`, because without it git prints the same directory as an absolute path and a relative one from a subdirectory. The same path twice means the **main checkout** — follow *Workflow* below. Two different paths (`<main>/.git/worktrees/<name>` and `<main>/.git`) mean a **linked worktree** — follow *From a linked worktree* instead, which reuses the Workflow's grouping and committing.

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
   - If the push succeeds, continue. This is the common case — don't fetch or rebase preemptively.
   - If the push is rejected because the remote has advanced (non-fast-forward), run `git fetch` then `git rebase` onto the updated upstream, and push again.
     - If the rebase completes cleanly, push and continue.
     - If the rebase hits conflicts, run `git rebase --abort`, leave the commits in place unpushed, and tell the user the remote diverged and needs manual resolution. Do not force-push.

6. Run `git log --oneline -<N>` (where N = number of new commits) to show the user what was committed.

## From a linked worktree

The work is finished when it is on the default branch and pushed to `origin` — not when it is committed on the tree's branch. Getting it there means integrating from the **main checkout**, which a worktree-isolated session cannot touch (Claude Code refuses `git -C`, `--git-dir`, `GIT_DIR` or a `cd` into it from the tree), and pushing from the tree itself is what a project's push guard may deliberately refuse. So: commit here, leave the tree, push and integrate from the main checkout, then remove the tree. Every command below is a plain one — never nest `$(git …)` inside another command.

**Integration is opt-in per project.** In some projects a push to the default branch is a production deploy, so this skill integrates and pushes from a worktree only where the project says explicitly that `/commit` may integrate and push from a worktree — in its `CLAUDE.md` (or the task-workflow doc that file points to) **as committed on the default branch**, read with `git show origin/<default>:CLAUDE.md` after step 2's fetch. Never the tree's own copy: that is part of the change being committed, so a branch could grant itself the push. An opt-in that exists only on the branch therefore does not count until it has been integrated once by hand. Without the opt-in, it commits on the branch and stops at step 3 with the by-hand steps.

1. **Commit on the branch** — Workflow steps 1–4, unchanged. Then record, while still in the tree, what later steps and the report need once the session has left it: the branch (`git branch --show-current`), the tree's path (`git rev-parse --show-toplevel`), the tree's git directory (`git rev-parse --absolute-git-dir`), the main checkout (the parent directory of the shared `.git` from *Which tree*), the bound work item if any (`sh ~/.claude/skills/task-marker.sh get`), and the review directory as the literal path `<git dir>/review`, whether or not it exists yet. The last two live in the tree's git directory, which step 7 deletes.

2. **Name the default branch, and fetch.** `git symbolic-ref --short refs/remotes/origin/HEAD` prints e.g. `origin/main`; below, `<default>` is that name without the `origin/` prefix (`main`). If it fails, tell the two causes apart with `git remote`: no `origin` remote at all means there is nowhere to integrate to — stop and say so; an `origin` without a recorded `HEAD` (a remote added rather than cloned) — stop and tell the user to run `git remote set-head origin --auto`. Then `git fetch origin`. If there was nothing outstanding to commit in step 1, there is still work here only when `git rev-list --count origin/<default>..HEAD` is above zero; otherwise say so and stop.

3. **Stop here unless integration is the default here.** The opt-in is read only from the default branch as just fetched — never the tree or the main checkout's working copy, which may be part of the change or stale; the hook-point counts if it exists there or in the tree. Stop, with the branch committed and the tree kept, if either holds, and report *Finishing by hand*:
   - the project provides an integrate hook-point — `git cat-file -e origin/<default>:.claude/workspace/integrate` succeeds, or `test -e <tree>/.claude/workspace/integrate` (absolute path from step 1) does. Its contract is not settled yet, so this skill never runs it; this is where it will slot in;
   - the project has not opted in (above).

4. **Bring the branch up to date, in the tree.** If the branch does not contain the default branch — `git merge-base --is-ancestor origin/<default> HEAD` exits non-zero — `git rebase origin/<default>`. On a conflict, `git rebase --abort` and stop: the commits stay on the branch, the tree stays, nothing was integrated; report *Finishing by hand*. A clean rebase moved the change onto code it was never verified against: say so plainly. A caller that verifies (`/ship`) re-verifies at this point, before step 5.

5. **Ask about ignored files, then leave the tree.** `git status --porcelain --ignored` — every `!!` entry is a gitignored file (a `.env` copy, local config) that removing the tree in step 7 deletes along with it, unrecoverably. If there are any, list them and ask once (`AskUserQuestion`): remove the tree with them, or keep the tree after integrating. Then leave with `ExitWorktree`, action `keep` (never `remove`: the branch is not on the default branch yet, so removal would discard it). That returns the session to the main checkout — **out of worktree isolation** from here on — and releases the harness's lock on the tree. If it reports no active worktree session — a tree this session did not enter — stop, and report *Finishing by hand*.

6. **Push, then integrate, from the main checkout.**
   - It must be on the default branch: `git branch --show-current` prints `<default>`. If not, stop.
   - The local default branch must be contained in the branch: `git merge-base --is-ancestor <default> <branch>`. If not, stop and show what the branch lacks — `git log --oneline <branch>..<default>`. Two causes: commits on the local default branch that are not on `origin` (the user's to push or reconcile first), or a pull or merge into it since step 2, in which case resuming from the tree fetches and rebases onto it.
   - `git push origin <branch>:<default>` — the branch's tip becomes the remote default branch. Pushing first means a rejection changes nothing locally: if it is rejected (the remote moved since step 2, a protected branch, a hook), stop and say so; resuming from the tree rebases onto the new tip. Never force-push.
   - `git merge --ff-only <branch>` — bring the local default branch up to the pushed tip; it is a fast-forward by the check above. Never `git pull`, and never leave a merge commit on the default branch.

   Any stop **before the push** leaves the tree and its branch exactly as they are. A refusal of the **fast-forward after the push** — git declining to overwrite an uncommitted or untracked file in the main checkout — is a different outcome: the change *is* on `origin/<default>`, so the work is done, but the local default branch is behind. Stop there, keep the tree and branch, and report it as **pushed, local fast-forward pending**: the user clears the obstruction and runs `git merge --ff-only <branch>` in the main checkout, then removes the tree and branch as in step 7. Never stash or discard someone else's change in the main checkout to make room.

   **Every stop after `ExitWorktree` succeeded in step 5 leaves the session in the main checkout**, no longer isolated (step 5's own no-session stop leaves it where it was). Say so, and warn that running `/commit` or `/ship` again *in this session* acts on the main checkout, not the tree: resume from a session opened in `<tree>` (or follow *Finishing by hand* from the point it stopped).

7. **Remove the tree and its branch, from the main checkout** — unless the user chose in step 5 to keep it: `git worktree remove <tree>`, then `git branch -d <branch>` — `-d`, not `-D`: the branch is merged now. Neither needs force: the tree is clean, and having been left in step 5 it is no longer locked. If either is refused (a submodule in the tree, for one), stop, report git's message, and name the tree, its git directory and what is still in it — the task marker and review directory from step 1. Never pass `-f`.

8. **Report.** `git log --oneline -<N>`; that the change is on `<default>` and pushed (and, if step 6 stopped after the push, that the local fast-forward is pending); that the tree and branch were removed (or kept, and why) — taking the task marker and the review directory with them; that the session is now in the main checkout and **no longer worktree-isolated**. If a work item was bound (step 1), name it: this skill never touches the tracker, so it is still to be advanced, and its marker is gone with the tree, unless the tree was kept.

### Finishing by hand

When the run stops before pushing — no opt-in, an integrate hook-point, a rebase conflict, no worktree session to leave, or any step-6 stop before the push — give the user the steps from the point it stopped, with the recorded values filled in. **First a warning:** `git push origin <branch>:<default>` publishes straight to the default branch, which in some projects deploys; a project that integrates through pull requests wants `git push -u origin <branch>` and a pull request instead, and the rest of these steps do not apply. Otherwise — in the tree: `git fetch origin`; if `git merge-base --is-ancestor origin/<default> <branch>` fails, `git rebase origin/<default>` (resolving any conflict) and re-verify. Then from the main checkout, on `<default>`: check `git merge-base --is-ancestor <default> <branch>` (if it fails, `git log --oneline <branch>..<default>` shows what to push or reconcile first); `git push origin <branch>:<default>`; `git merge --ff-only <branch>`. Then exit the worktree session; check `git -C <tree> status --porcelain --ignored` for `!!` files worth keeping, since removal deletes them; `git worktree unlock <tree>` if `git worktree list --porcelain` still shows it `locked` by a session that has exited; `git worktree remove <tree>` and `git branch -d <branch>`. Name the bound work item, if any, as still to be advanced once pushed — removing the tree deletes its marker.

## Rules

- Never use `git add -A` or `git add .` — always add specific files.
- Never amend existing commits.
- Commit the working tree exactly as it stands. Never add, restore, reword, or complete content as part of committing — not to satisfy an acceptance criterion, not to match a review summary, not to replace something that looks missing. Content absent from the tree was removed deliberately; the user edits the tree while reviewing, and those edits are their feedback.
- If the tree contradicts the issue or the review record — a ticked criterion whose change isn't there — stop before committing and report the discrepancy rather than reconciling it yourself.
- If there are no outstanding changes, inform the user and stop. From a linked worktree, "outstanding" also includes commits on the branch not yet on the default branch — record as in step 1, then run step 2, whose `git rev-list --count origin/<default>..HEAD` decides whether there is anything to integrate.
- Do not skip or ignore any changes — everything must be committed.
- If a pre-commit hook fails, alert the user and abort committing until the issue is resolved. Do not bypass hooks.
- From a linked worktree: integrate only where the project opts in; never push from inside the tree; never force anything; and never remove a tree whose branch is not yet on the default branch, or one holding ignored files the user did not agree to lose.
