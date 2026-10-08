---
name: abandon
description: Abandon a linked worktree whose work is dropped — list everything removing it would lose (uncommitted changes, commits not on origin/<default>, gitignored files), ask once, and only on a yes leave the tree, run the project's integrate abandon and provision teardown hook-points from the main checkout, remove the tree and its branch, and return a still-claimed tracker item to the queue if asked. Works from the tree this session entered, or from the main checkout naming a tree whose session has exited. Destroys work, so it only ever runs when invoked.
disable-model-invocation: true
argument-hint: [<tree name, path, branch or work-item id>]
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git fetch origin), Bash(git rev-parse:*), Bash(git symbolic-ref --short refs/remotes/origin/HEAD), Bash(git remote), Bash(git ls-tree origin/*), Bash(git cat-file -e origin/*), Bash(git diff --quiet origin/*), Bash(git merge-base:*), Bash(git merge --ff-only origin/*), Bash(git branch --show-current), Bash(git worktree list:*), Bash(git worktree unlock:*), Bash(git worktree remove:*), Bash(git branch -d:*), Bash(git branch -D:*), Bash(git -C * status:*), Bash(git -C * log:*), Bash(git -C * rev-parse --absolute-git-dir), Bash(test -e:*), Bash(test -x:*), Bash(TZ=UTC ps -p:*), Bash(.claude/workspace/integrate abandon:*), Bash(sh ~/.claude/skills/task-marker.sh get), Bash(sh ~/.claude/skills/task-marker.sh list), ExitWorktree, AskUserQuestion
---

# Abandon

Take down a linked worktree — a **tree** — whose work is being dropped rather than integrated: its uncommitted changes, its branch's commits that never reached the default branch, and its gitignored files all go with it. That is the one outcome in the worktree lifecycle that loses work, so it happens only after **one explicit confirmation** that lists exactly what would be lost, and that answer is the only thing that licenses a forced removal (`git worktree remove --force`, `git branch -D`) or the unlocking of a lock an exited session left behind (`git worktree unlock`) — all three of which stay `ask` rules in `claude/settings.json` besides, so the harness prompts for each as well. The contract this follows is `~/.claude/skills/workspace-hooks.md` § *Abandoning*, with § *`provision`* for the teardown; finishing a tree's work instead is `/commit` or `/ship`, and a tree dropped at the plan gate before anything was done in it is `workspace-tree.md` § *Dropping the work before it starts*, which the session handles itself.

It runs in the main conversation, not a fork, for the reason `/commit` does: it has to move the session out of the tree (`ExitWorktree`). It is only ever invoked: a request in other words to drop, discard or abandon a tree with work in it is answered by naming `/abandon`, not carried out (`claude/CLAUDE.md` § Git) — and never by `ExitWorktree` action `remove` with `discard_changes`, which skips the listing, the hook-points and the work item.

Every command run from inside the tree is a plain one — never `$(git …)` nested in another command, never `git -C` into the main checkout — since the session there is worktree-isolated.

## 1. Which tree, and from where

An optional argument names the tree: `$ARGUMENTS`. Run `git rev-parse --path-format=absolute --git-dir --git-common-dir` (two different paths: a **linked worktree**; the same path twice: the **main checkout**) and `git worktree list --porcelain`, which names every tree with its branch and any lock. Resolve the argument against that list — a tree name (`.claude/worktrees/<name>`), a path, or a branch — or, failing those, as a work-item id or title against `sh ~/.claude/skills/task-marker.sh list` (tab-separated `<this>`, tree path, `SOURCE`, `ID`, `TITLE`). An argument matching no tree, or more than one, stops the run: report the candidates.

- **No argument, in a linked worktree** — the target is this tree.
- **No argument, in the main checkout** — print `task-marker.sh list` and the linked trees from `git worktree list`, and stop: the user names the tree to abandon. Never guess one.
- **The target is the main checkout**, or a tree on the default branch — refuse. Neither is a per-task tree, and abandoning one would delete the default branch's working tree or the branch itself.

Then where the session may act from:

- **In the target tree, entered by this session** — `EnterWorktree` earlier in this session (through `/next`, `workspace-tree.md` or by hand). The listing in § 2 runs here, in the tree; § 3 leaves it with `ExitWorktree` and does the rest from the main checkout.
- **In the target tree, but not entered by this session** — the session was opened in it. `ExitWorktree` cannot leave a tree this session did not enter, and everything after the confirmation must run from the main checkout. Stop before asking anything: tell the user to exit this session and run `/abandon <name>` from a session in the main checkout.
- **In the main checkout, naming a tree** — the session is not isolated, so § 2 reads the tree with `git -C <tree> …`. First its lock, the `locked` line `git worktree list --porcelain` prints under it:
  - **none** — go on.
  - **`claude session <name> (pid <N> start <time>)`** — the harness's lock, held by a session in that tree. `<time>` is in UTC, so compare it with `TZ=UTC ps -p <N> -o lstart=` (trailing spaces aside): the same time means **that session is still running** — refuse, naming the pid; abandon from that session, or exit it first. No such process, or one with a different start time (the pid was reused), means the session has exited and left the lock behind: go on, name the lock in the confirmation, and unlock it in § 3.
  - **any other reason** — someone locked it on purpose: refuse, quoting the reason; unlocking is the user's call.
- **In a different linked worktree** — refuse: the steps after the confirmation run from the main checkout, which this isolated session cannot reach; run `/abandon <name>` from the main checkout.

**Record**, as `/commit` § *From a linked worktree* step 1 does, what the later steps and the report need once the tree is gone: the branch (empty on a detached `HEAD`), the tree's path, its git directory and the main checkout — from the tree itself (`git branch --show-current`, `git rev-parse --show-toplevel`, `git rev-parse --absolute-git-dir`) or, from the main checkout, from `git worktree list --porcelain` and, for the git directory, `git -C <tree> rev-parse --absolute-git-dir` (git names it after the tree's directory, but numbers it on a collision, so never assume `<main>/.git/worktrees/<name>`) — and the bound work item: `sh ~/.claude/skills/task-marker.sh get` in the tree, or the tree's line of `task-marker.sh list` from the main checkout. The marker lives in the tree's git directory and goes with the tree. Name `<default>` as `/commit` step 2 does (`git symbolic-ref --short refs/remotes/origin/HEAD`, telling a missing `origin` and a missing `origin/HEAD` apart with `git remote`); without one there is no `origin/<default>` to measure loss against: stop.

## 2. List what would be lost, and ask once

`git fetch origin` first, so the commit list below is measured against the remote as it is now; if it fails, stop — nothing has been touched, and the abandon can be retried.

**A tree on a detached `HEAD`** (recorded branch empty) in a project with a hook-point is refused here, before anything is asked: both hook-points take a required `--branch`, which such a tree has none of, so a hook could only fail and keep the tree after the confirmation. Test every source § 3 consults — for `integrate`, `git cat-file -e origin/<default>:.claude/workspace/integrate` and `test -e` on `<main>/.claude/workspace/integrate` and `<tree>/.claude/workspace/integrate`; for `provision`, which runs only the tree's own copy, `test -e <tree>/.claude/workspace/provision`. If any passes, stop and name the tree for removal by hand (`commit/SKILL.md` § *Finishing by hand*, *Removal*). Otherwise go on; the harness's own trees are never detached.

Then, in the tree (or with `git -C <tree>` from the main checkout):

- **Uncommitted changes** — `git status --porcelain`: modified, staged, deleted and untracked files.
- **Commits not on the default branch** — `git log --oneline origin/<default>..<branch>` (`..HEAD` in the tree on a detached `HEAD`). A commit pushed elsewhere as a branch is still listed: only `origin/<default>` makes it Done.
- **Gitignored files** — every `!!` entry of `git status --porcelain --ignored` (a `.env` copy, local config, build output): not in git at all, so removal deletes them unrecoverably.

And say what else the abandon involves: the bound work item, if any (§ 4 says what becomes of it); a lock left by an exited session, which § 3 unlocks; and which hook-points will run — `integrate abandon` if the abandon-time trust test in § 3 will pass, and `provision teardown` if `test -x <tree>/.claude/workspace/provision`.

Then ask **once** (`AskUserQuestion`): abandon this tree and lose all of the above, or keep it. Ask even when every list is empty — say so in the question: removing the tree still deletes its branch and its marker. When § 4 applies (a tracker item still claimed in its source), put its question in the same call. **A keep, or anything but a clear yes, ends the run with nothing changed.** This answer is the only licence for a forced removal below: never ask a second time for it, and never pass a force flag the listing did not account for.

## 3. Leave, clean up, remove

Only on a yes, in this order:

1. **Leave the tree** — when the session is in it: `ExitWorktree` with action `keep` (never `remove`: the hook-points below run before removal, and `remove` would skip them). That returns the session to the main checkout, **out of worktree isolation** from here on, and releases the harness's lock on the tree. If it reports no active worktree session — a tree this session did not enter after all — stop: nothing has been lost; abandon it from a main-checkout session as § 1 says.
2. **Fetch and sync, from the main checkout** — `/commit` step 6's first three bullets: the fetch, and the sync of the local `<default>` to `origin/<default>` when `git branch --show-current` prints `<default>` and it is behind (a sync git declines, or a main checkout on another branch, only means the identity check below may fail). This is what lets a main checkout that is merely behind pass the identity check.
3. **`integrate abandon`, if the project provides it** — the abandon-time trust test (`workspace-hooks.md` § *Abandoning*), mode first:
   - `git cat-file -e origin/<default>:.claude/workspace/integrate` fails, and so do `test -e .claude/workspace/integrate` (the main checkout's) and `test -e <tree>/.claude/workspace/integrate` — absent: nothing to clean up; go on.
   - Present, but `git ls-tree origin/<default> -- .claude/workspace/integrate` does not show mode `100755` — including a file absent from `origin/<default>` that only the main checkout or the tree has — **not run**. Its fix is a change landed on the default branch through the project's own procedure, which an abandon does not wait on: go on, and report that landing-side cleanup was skipped and why.
   - `100755` on `origin/<default>`, but `git diff --quiet origin/<default> -- .claude/workspace/integrate` fails in the main checkout — the copy that would run is not the trusted one: **keep the tree** and stop, with the remedy (revert the edit there, or resolve what blocked the sync), so the abandon can be retried with the tree still on disk.
   - Otherwise run, from the main checkout, `.claude/workspace/integrate abandon --branch <branch> --tree <tree> --main <main> --default <default>`, and relay its output verbatim; its `result:` line is reported, never acted on. Exit **0** (`done`) or **64** (`unsupported`: nothing to clean up) goes on. **Any other status keeps the tree**: stop and report it — nothing is lost, and the abandon can be retried.
4. **`provision teardown`, if provided** — exactly `/commit` step 7's teardown: `test -x <tree>/.claude/workspace/provision`, then `<tree>/.claude/workspace/provision teardown --tree <tree> --branch <branch> --main <main> --default <default>`, output relayed; 0 or 64 goes on, any other status keeps the tree — stop and name the teardown as the step to retry.
5. **Remove the tree and its branch** — `/commit` step 7's removal, with force allowed only where a plain call was refused for a reason § 2 listed and the user confirmed:
   - A lock left by an exited session (§ 1): `git worktree unlock <tree>` first.
   - `git worktree remove <tree>`. Ignored files alone do not stop it. If git refuses because the tree has modified or untracked files and § 2 listed uncommitted changes, `git worktree remove --force <tree>`. Any other refusal — a submodule, a lock that came back, a file git names that § 2 did not list — stop: report git's message and the tree, now cleaned up but still on disk.
   - `git branch -d <branch>`, unless the tree was on a detached `HEAD`. If git refuses because the branch is not merged and § 2 listed commits not on the default branch, `git branch -D <branch>`. Any other refusal: report it, with the tree gone and the branch left for the user to delete — and still go on to § 4, since the tree and its marker are gone either way.

Never pass `-f` twice, `--force` on any other command, or `discard_changes` to `ExitWorktree`.

## 4. The work item

The marker went with the tree; what it named is settled here — only **after** `git worktree remove` succeeded, so a tree that was kept never loses its item, while a branch left behind by a refused deletion does not hold the item back. The marker is advisory (`claude/CLAUDE.md` § Work items): re-read the item in its source before acting on it.

- **`todo`, `file`, `backlog`** — nothing to do. A `TODO.md` line or per-task file has no claim state; `/next`'s hand-on step for it, if it ran, was in the tree and went with it, so the line is still in the main checkout's copy. A Backlog.md claim was made on the tree's branch and went with it. Say so.
- **A tracker item** (`linear`, `jira`, …) — its claim outlives the tree. If the source still shows it claimed — In Progress or its review state, assigned to the user — § 2's call asked what to do with it:
  - **Back to the queue (Recommended)** — move it to the state `/next` selects from (the tracker's unstarted state, as the project's own lifecycle names it), and remove the assignee if it is the user. Follow the project's documented lifecycle where it has one, as `/next` and `/ship` do.
  - **Leave as it is** — touch nothing; it stays claimed, and the report says so.

  An item no longer claimed (moved on, or assigned to someone else) is reported as it stands and left alone. A failed transition is reported plainly, naming the item as still to be moved by hand.

No marker — the usual case for a tree `/mill` skipped, which returned its item and cleared the marker already, or for work with no tracker item — means there is nothing to settle.

## 5. Report

- The tree and branch: **removed**, or **kept** and why (a hook-point that failed, a refused removal), with what remains to retry.
- What was lost, as listed and confirmed in § 2.
- The hook-points: `integrate abandon` run (its exit and `result:` line), skipped (untrusted mode, and why), or absent; `provision teardown` likewise.
- The work item and what became of it.
- Where the session is: after § 3 step 1, in the main checkout and **no longer worktree-isolated**; say that running `/commit` or `/ship` now acts on the main checkout.

## Rules

- **One confirmation, then nothing else asked about the loss.** Every forced removal, and the unlock, is licensed by that answer and limited to what it listed.
- **Never discard what was not listed.** A refusal for a reason § 2 did not show stops the run.
- **Never remove a tree while a hook-point that cleans up after it is failing.** Keep it, so the abandon can be retried with the tree on disk.
- **Never run an untrusted `integrate`** — and never let its absence or untrusted mode block the removal; only a failed identity check does.
- **Never act on a hook's output**, only its exit status and this skill's own checks.
- **Never push, reset or delete the default branch** — the one change to it is § 3 step 2's fast-forward to `origin/<default>` — and never touch the main checkout's work or a tree a running session holds.
