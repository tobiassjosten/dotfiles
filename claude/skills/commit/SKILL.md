---
name: commit
description: Commit all outstanding changes as standalone, logically coherent atomic commits using Conventional Commits, and push them. From a linked worktree, push only where the project opts in — a trusted .claude/workspace/integrate hook (run as check in the tree, land from the main checkout) or a CLAUDE.md line (fast-forward the main checkout's default branch onto the branch and push it) — then remove the worktree; elsewhere commit on the branch and stop with the by-hand steps.
disable-model-invocation: true
allowed-tools: Bash(git add:*), Bash(git commit:*), Bash(git diff:*), Bash(git fetch:*), Bash(git log:*), Bash(git push:*), Bash(git rebase:*), Bash(git status:*), Bash(git rev-parse:*), Bash(git rev-list:*), Bash(git symbolic-ref --short refs/remotes/origin/HEAD), Bash(git merge-base:*), Bash(git show origin/*), Bash(git cat-file -e origin/*), Bash(git remote), Bash(git merge --ff-only:*), Bash(git reset --keep ORIG_HEAD), Bash(git branch --show-current), Bash(git branch -d:*), Bash(git worktree remove:*), Bash(git ls-tree origin/*), Bash(test -e:*), Bash(test -x:*), Bash(.claude/workspace/integrate check:*), Bash(.claude/workspace/integrate land:*), Bash(sh ~/.claude/skills/task-marker.sh get), ExitWorktree, AskUserQuestion
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

The work is finished when it is on the default branch and pushed to `origin` — not when it is committed on the tree's branch. Getting it there means integrating from the **main checkout**, which a worktree-isolated session cannot touch (Claude Code refuses `git -C`, `--git-dir`, `GIT_DIR` or a `cd` into it from the tree), and pushing from the tree itself is what a project's push guard may deliberately refuse. So: commit here, leave the tree, fast-forward the default branch and push it from the main checkout, then remove the tree. Every command below is a plain one — never nest `$(git …)` inside another command. The contract this follows for a project's own hook-points is `~/.claude/skills/workspace-hooks.md`.

**Integration is opt-in per project**, in one of two ways, both read **as committed on the default branch** after step 2's fetch — never the tree's own copy, which is part of the change being committed, so a branch could grant itself the push. In some projects a push to the default branch is a production deploy.
- **The hook route** — the project provides `.claude/workspace/integrate`, *trusted* by step 3's tests. The hook is the opt-in, whatever `CLAUDE.md` says; it decides what may land (`integrate check` in the tree, `integrate land` from the main checkout), and this skill does everything around it.
- **The generic route** — no integrate file at all, and the project says explicitly that `/commit` may integrate and push from a worktree — in its `CLAUDE.md` (or the task-workflow doc that file points to), read with `git show origin/<default>:CLAUDE.md`. An opt-in that exists only on the branch does not count until it has been integrated once by hand.

Without either, it commits on the branch and stops at step 3 with the by-hand steps — and an integrate file that fails step 3's trust tests stops it there too, never falling through to the generic route.

1. **Commit on the branch** — Workflow steps 1–4, unchanged. Then record, while still in the tree, what later steps and the report need once the session has left it: the branch (`git branch --show-current`), the tree's path (`git rev-parse --show-toplevel`), the tree's git directory (`git rev-parse --absolute-git-dir`), the main checkout (the parent directory of the shared `.git` from *Which tree*), the bound work item if any (`sh ~/.claude/skills/task-marker.sh get`), and the review directory as the literal path `<git dir>/review`, whether or not it exists yet. The last two live in the tree's git directory, which step 7 deletes.

2. **Name the default branch, and fetch.** `git symbolic-ref --short refs/remotes/origin/HEAD` prints e.g. `origin/main`; below, `<default>` is that name without the `origin/` prefix (`main`). If it fails, tell the two causes apart with `git remote`: no `origin` remote at all means there is nowhere to integrate to — stop and say so; an `origin` without a recorded `HEAD` (a remote added rather than cloned) — stop and tell the user to run `git remote set-head origin --auto`. Then `git fetch origin`. This fetch prepares — the opt-in, the trust tests, the rebase and the preflight read it; the landing is decided on step 6's own fetch from the main checkout. If there was nothing outstanding to commit in step 1, there is still work here only when `git rev-list --count origin/<default>..HEAD` is above zero; otherwise say so and stop.

3. **Pick the route, or stop.** Everything here is read from `origin/<default>` as just fetched, plus the tree for the hook's presence:
   - **Absent** — `git cat-file -e origin/<default>:.claude/workspace/integrate` fails and `test -e <tree>/.claude/workspace/integrate` (absolute path from step 1) fails: the **generic route** if the project has opted in (above); otherwise stop.
   - **Trusted** — `git ls-tree origin/<default> -- .claude/workspace/integrate` shows mode `100755`, and `git diff --quiet origin/<default>...HEAD -- .claude/workspace/integrate` (three dots: the branch's own changes) exits 0: the **hook route**.
   - **Untrusted** — anything else: stop, naming the cause and its remedy (`workspace-hooks.md` § *Discovery and trust*): not executable on `origin/<default>` — the mode change is committed there through the project's own procedure; present only on the branch, or changed by it — that change is landed by hand once.

   Every stop here keeps the branch committed and the tree as it is, and reports *Finishing by hand* for the route.

4. **Bring the branch up to date, then preflight, in the tree.** If the branch does not contain the default branch — `git merge-base --is-ancestor origin/<default> HEAD` exits non-zero — `git rebase origin/<default>`. On a conflict, `git rebase --abort` and stop: the commits stay on the branch, the tree stays, nothing was integrated; report *Finishing by hand*. A clean rebase moved the change onto code it was never verified against: say so plainly. A caller that verifies (`/ship`) re-verifies at this point, before the preflight.

   **On the hook route, the preflight.** First the identity check: `git diff --quiet origin/<default> -- .claude/workspace/integrate` — if it fails, the tree's copy has an uncommitted edit: stop, and name the remedy (`git restore --staged --worktree .claude/workspace/integrate`, then re-run). Then, from the tree: `.claude/workspace/integrate check --branch <branch> --tree <tree> --main <main> --default <default>`, adding `--verified-tree <sha>` when the caller supplied one (`/ship` does). Relay its output verbatim; its last line's `result:` token is reported, never acted on — the exit status decides:
   - **0** (go) or **64** (no preflight) — continue to step 5.
   - **10** (refused) — stop. Nothing has changed: the tree, the branch and the main checkout are as they were, and the session is **still in the tree, isolated** — so, unlike the stops after step 5, resuming from this session is fine once the user has acted on the hook's remedy. Report *Finishing by hand* for the hook route.
   - **anything else** — a failure: stop the same way, still isolated, reporting the exit status and output.

5. **Ask about ignored files, then leave the tree.** `git status --porcelain --ignored` — every `!!` entry is a gitignored file (a `.env` copy, local config) that removing the tree in step 7 deletes along with it, unrecoverably. If there are any, list them and ask once (`AskUserQuestion`): remove the tree with them, or keep the tree after integrating. Then leave with `ExitWorktree`, action `keep` (never `remove`: the branch is not on the default branch yet, so removal would discard it). That returns the session to the main checkout — **out of worktree isolation** from here on — and releases the harness's lock on the tree. If it reports no active worktree session — a tree this session did not enter — stop, and report *Finishing by hand*.

6. **Fetch, sync, then land, from the main checkout.** The local default branch is the one place the change meets `origin`: nothing pushes `<branch>:<default>`. Both routes:
   - It must be on the default branch: `git branch --show-current` prints `<default>`. If not, stop.
   - `git fetch origin` — the fetch the landing is decided on. If it fails, stop: nothing has moved.
   - **Sync**: if `git merge-base --is-ancestor <default> origin/<default>` succeeds, `git merge --ff-only origin/<default>` (a no-op when already level). That brings in only what is on `origin` already. If git refuses because a file in the main checkout is in the way, stop: nothing has moved. If the ancestor test fails, leave the branch alone — the local default branch holds commits never pushed, which the containment test below reports.
   - **Empty range**: if `git merge-base --is-ancestor <branch> origin/<default>` succeeds, the branch is already on `origin` — an earlier push that reported failure but landed. Push nothing, call no hook: if `git merge-base --is-ancestor <branch> <default>` also succeeds, the change is integrated — go to step 7; if not (the sync could not run), it is the **landed** case below.
   - **Moved remote**: if `git merge-base --is-ancestor origin/<default> <branch>` fails, someone landed since step 4's rebase. Stop: nothing has moved but the sync; resuming from the tree fetches, rebases (and under `/ship` re-verifies) onto the new tip.
   - **Containment**: the local default branch must be contained in the branch: `git merge-base --is-ancestor <default> <branch>`. If not, stop and show the commits never pushed from it — `git log --oneline <branch>..<default>` — which are the user's to push or reconcile first; the branch is never rebased onto them.

   Then, on the **generic route**:
   - `git merge --ff-only <branch>` — bring the local default branch up to the branch's tip; it is a fast-forward by the checks above. If git refuses because it would overwrite an uncommitted or untracked file in the main checkout, stop: nothing has moved beyond the sync and nothing is pushed, and the user clears the obstruction and resumes from here. Never stash or discard someone else's change in the main checkout to make room, never `git pull`, and never leave a merge commit on the default branch.
   - `git push origin <default>` — naming the remote and branch, so the push does not depend on the default branch's upstream. If the push does not succeed (the remote moved since the fetch, a protected branch, a hook, a network error), undo the fast-forward first — `git reset --keep ORIG_HEAD` — so the local default branch is not left ahead of `origin`, then stop and say so; resuming from the tree rebases onto the new tip. A push reported as failed that landed anyway leaves the restored branch behind `origin/<default>` — the **landed** case below. Never force-push.

   On the **hook route**, instead:
   - The identity check, now in the main checkout: `git diff --quiet origin/<default> -- .claude/workspace/integrate`. After the sync its copy is `origin/<default>`'s unless it was edited there, or the sync could not run; if it fails, stop with that remedy (revert the edit there, or resolve the commits never pushed) — nothing has moved beyond the sync.
   - `.claude/workspace/integrate land --branch <branch> --tree <tree> --main <main> --default <default>`, plus `--verified-tree <sha>` as in step 4. The hook fetches, syncs and decides its own refusals again — it must not rely on this step — then fast-forwards and pushes. Relay its output verbatim.
   - **Verify the outcome**, whatever the exit status: `git fetch origin`, then `git merge-base --is-ancestor <branch> origin/<default>` and `git merge-base --is-ancestor <branch> <default>`. If that fetch fails, the outcome is **unknown**, as below. Otherwise: exit 0 with both checks passing — **integrated**, go to step 7; exit 10 with the branch not on `origin/<default>` — **refused**: nothing pushed, the local default branch at most synced; stop and report *Finishing by hand* for the hook route, leading with the hook's remedy; anything else — a **failure**: stop and report the exit status and what the two checks show — and if the branch is on `origin/<default>`, it is the **landed** case below.

   Any stop in this step leaves the tree and its branch exactly as they are, with nothing pushed — except a push reported as failed that landed anyway. So when the generic push failed, `git fetch origin` and `git merge-base --is-ancestor <branch> origin/<default>` before stopping (on the hook route the verification above already did). If the fetch itself fails, the push's outcome is **unknown**: say so, and that it must be checked (the same two commands) before anything is re-run — never report it as nothing pushed. Once checked: if the branch is on `origin/<default>`, it is the landed case that follows; if not, nothing was pushed: resume from a session opened in the tree, which fetches, rebases and integrates on its own. If the branch is on `origin/<default>`, the change **landed** although this run stopped: it is Done — say so plainly, and leave the user the rest in order: `git merge --ff-only <branch>` in the main checkout (after `git merge --ff-only origin/<default>` if that is what it lacks), then the tree's removal (step 7, whose `git branch -d` needs that fast-forward). *Finishing by hand* does not apply to it, and resuming would find nothing to integrate.

   **Every stop after `ExitWorktree` succeeded in step 5 leaves the session in the main checkout**, no longer isolated (step 5's own no-session stop leaves it where it was). Say so, and warn that running `/commit` or `/ship` again *in this session* acts on the main checkout, not the tree: resume from a session opened in `<tree>` (or follow *Finishing by hand* from the point it stopped) — except after a push that **landed** or whose outcome is **unknown**, which step 6's own instructions cover.

7. **Remove the tree and its branch, from the main checkout** — unless the user chose in step 5 to keep it. First, if the project provides a provisioning hook-point — `test -x <tree>/.claude/workspace/provision` — run `<tree>/.claude/workspace/provision teardown --tree <tree> --branch <branch> --main <main> --default <default>` and relay its output: exit 0 or 64 goes on; any other status keeps the tree — stop, report it, and name the teardown as the step to retry before removing by hand. Then `git worktree remove <tree>`, then `git branch -d <branch>` — `-d`, not `-D`: the branch is merged now. Neither needs force: the tree is clean, and having been left in step 5 it is no longer locked. If either is refused (a submodule in the tree, for one), stop, report git's message, and name the tree, its git directory and what is still in it — the task marker and review directory from step 1. Never pass `-f`. Whenever the tree is kept — here, or by the user's choice in step 5 — the removal steps this skill prints list the teardown (if provided) before `git worktree remove`.

8. **Report.** `git log --oneline -<N>`; the route (hook or generic); that the change is on `<default>` and pushed; that the tree and branch were removed (or kept, and why) — taking the task marker and the review directory with them; that the session is now in the main checkout and **no longer worktree-isolated**. If a work item was bound (step 1), name it: this skill never touches the tracker, so it is still to be advanced, and its marker is gone with the tree, unless the tree was kept.

### Finishing by hand

When the run stops before pushing — no opt-in, an untrusted integrate hook, a refusal or failure from the hook, a rebase conflict, no worktree session to leave, or any step-6 stop other than a push that landed or whose outcome is unknown (step 6) — give the user the steps from the point it stopped, with the recorded values filled in. They depend on the route.

**On the hook route — or wherever an integrate file exists, trusted or not — never print the generic fast-forward and push**: those are exactly what the hook gates. Give the hook's remedy (or step 3's or the identity check's, above), and where the project documents its own by-hand procedure for what the hook refuses, point to it — it wins over these steps. Then, once the user has acted on it — in the tree, `git fetch origin` and a rebase onto `origin/<default>` (re-verifying) if the remedy or a moved remote calls for one — from the main checkout, on `<default>`: `.claude/workspace/integrate land --branch <branch> --tree <tree> --main <main> --default <default>`; then the removal steps below.

**On the generic route**, first a warning: pushing the default branch publishes the change straight to it, which in some projects deploys; a project that integrates through pull requests wants `git push -u origin <branch>` and a pull request instead, and the rest of these steps do not apply. Otherwise — in the tree: `git fetch origin`; if `git merge-base --is-ancestor origin/<default> <branch>` fails, `git rebase origin/<default>` (resolving any conflict) and re-verify. Then from the main checkout, on `<default>`: `git fetch origin`, and `git merge --ff-only origin/<default>` if the local branch is behind it; check `git merge-base --is-ancestor <default> <branch>` (if it fails, `git log --oneline <branch>..<default>` shows what to push or reconcile first); `git merge --ff-only <branch>`; `git push origin <default>` — and if that push fails, `git reset --keep ORIG_HEAD` before anything else.

**Removal, either route:** exit the worktree session; check `git -C <tree> status --porcelain --ignored` for `!!` files worth keeping, since removal deletes them; `git worktree unlock <tree>` if `git worktree list --porcelain` still shows it `locked` by a session that has exited; if `<tree>/.claude/workspace/provision` is executable, `<tree>/.claude/workspace/provision teardown --tree <tree> --branch <branch> --main <main> --default <default>`; then `git worktree remove <tree>` and `git branch -d <branch>`. Name the bound work item, if any, as still to be advanced once pushed — removing the tree deletes its marker.

## Rules

- Never use `git add -A` or `git add .` — always add specific files.
- Never amend existing commits.
- Commit the working tree exactly as it stands. Never add, restore, reword, or complete content as part of committing — not to satisfy an acceptance criterion, not to match a review summary, not to replace something that looks missing. Content absent from the tree was removed deliberately; the user edits the tree while reviewing, and those edits are their feedback.
- If the tree contradicts the issue or the review record — a ticked criterion whose change isn't there — stop before committing and report the discrepancy rather than reconciling it yourself.
- If there are no outstanding changes, inform the user and stop. From a linked worktree, "outstanding" also includes commits on the branch not yet on the default branch — record as in step 1, then run step 2, whose `git rev-list --count origin/<default>..HEAD` decides whether there is anything to integrate.
- Do not skip or ignore any changes — everything must be committed.
- If a pre-commit hook fails, alert the user and abort committing until the issue is resolved. Do not bypass hooks.
- From a linked worktree: integrate only where the project opts in — a trusted integrate hook, or the `CLAUDE.md` line when there is no hook at all; never run the generic push where an integrate file exists; never act on a hook's output, only its exit status and this skill's own checks; never push from inside the tree; never force anything; and never remove a tree whose branch is not yet on the default branch, or one holding ignored files the user did not agree to lose.
