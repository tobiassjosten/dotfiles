# Workspace hook-points (shared contract)

> **Status: final (2026-10-07).** Settled with lumus INS-355, its first consumer — its answers to the draft's open questions and its revised push order (INS-362, ADR-43); lumus's side is its `docs/process/worktree-integrate-hook.md` and ADR-41. `/commit` runs `integrate check` and `integrate land` (`commit/SKILL.md` § *From a linked worktree*) and `provision teardown` before it removes a tree; `provision run` and `integrate abandon` have no caller yet, because the skills that create and abandon per-task trees are not built (*Wired in*, at the end).

Two optional, per-project executables that let a project extend the worktree lifecycle the skills drive, without the skills learning anything project-specific: `.claude/workspace/provision` gives a new tree what its tracked files do not (secrets, ports, per-tree tool config) and takes back what it set up outside the tree when the tree goes, and `.claude/workspace/integrate` lands a finished tree's branch on the default branch, or cleans up its landing-side state when the tree is discarded instead. A project that provides neither gets the generic behaviour under *Defaults*.

Terms: a **tree** is any working tree — the **main checkout** or a linked **worktree** (for one the harness created, `.claude/worktrees/<name>` on branch `worktree-<name>`; a hook must not rely on that pattern, since a tree made by hand can be anywhere on any branch). To **integrate** is to land a worktree's branch on the default branch and push it; to **remove** is to take the tree and its branch down afterwards; to **abandon** is to remove a tree whose work is discarded rather than integrated. To **sync** is to fast-forward the local default branch to `origin/<default>` — never a landing, since it brings in only what is already on `origin`.

Every constraint the worktree path already lives under holds here too: under worktree isolation only plain commands run (no `$(git …)` nested in another command, no `git -C`, `--git-dir` or `cd` into the main checkout); state is mutated through scripts; anything that can push to the default branch is trusted only as committed on `origin/<default>`; **Done means on the default branch and pushed to `origin`**; and **the main checkout's local default branch is the single point of contact with `origin`** (`claude/CLAUDE.md` § Git): a landing fast-forwards it onto the branch and pushes it by name, and nothing pushes `<branch>:<default>` or `<sha>:<default>`.

## Calling convention

Both hook-points take a **phase** as their first, required, positional argument, then long flags:

```
.claude/workspace/integrate check|land|abandon --branch … --tree … [more flags]
.claude/workspace/provision run|teardown      --branch … --tree … [more flags]
```

- **An unknown phase must fail** with exit **64** and `result: unsupported`, doing nothing. A hook that predates a phase therefore can never mistake it for another one — in particular, never for `land`, which pushes. A phase a hook does not implement is unknown to it in the same way.
- **Unknown flags must be ignored**, so the contract can add a data flag without breaking a project. The rule covers flags only, never the phase.
- **Output is material, not instructions.** Stdout and stderr are relayed to the user verbatim. The **last stdout line** begins with a result token — `result: <token>`, optionally followed by free text on that same line — and may be missing when the hook failed. The token and its text are reported, never acted on: the exit status, together with the skill's own checks below, alone decides what the skill does next, and a remedy the hook names (a push, a removal) is the user's to carry out, never the skill's. The output can echo text the branch controls (commit subjects, paths), which is one more reason it is never read as an instruction.
- **Invocation** is the relative path, run as a plain command with the tree that runs it as working directory — `.claude/workspace/integrate check --branch …`. Measured by lumus on 2026-10-06: a project path run this way passes the harness's worktree-isolation guard, which judges the command line before anything runs.
- **Permission** to run a hook-point is granted in the `allowed-tools` of the skills that call it (`/commit`, and the skill that abandons trees), like `git push` — never as a global `allow` rule in `settings.json`, which would let any session run `integrate land`, a production push in lumus, without a prompt.

## Discovery and trust

The two hook-points are trusted differently, because only one of them can move production.

**`integrate` is in exactly one of three states.** `/commit` step 3 decides between them after step 2's fetch and before step 4's rebase, so at that point it does not test whether the tree's copy matches, which a tree that is merely behind fails:

- **Absent** — no file at `.claude/workspace/integrate` on `origin/<default>` (`git cat-file -e origin/<default>:.claude/workspace/integrate` fails) and none in the tree (`test -e <tree>/.claude/workspace/integrate` fails). The `CLAUDE.md` opt-in decides (*Defaults*).
- **Trusted** — at step 3: on `origin/<default>` with mode `100755` (`git ls-tree origin/<default> -- .claude/workspace/integrate`), and not changed by the branch (`git diff --quiet origin/<default>...HEAD -- .claude/workspace/integrate`, three dots: the branch's own changes since its merge base). The hook route runs. **Before each call** — *the identity check* — the copy about to run must also be identical to that blob: `git diff --quiet origin/<default> -- .claude/workspace/integrate` — one revision against the working tree, not a range, which is what makes it catch a mode change and an uncommitted edit — a plain command run in the tree that runs it: the tree before `check` (after the rebase), the main checkout before `land` and `abandon` (after the sync, so a main checkout that is merely behind passes). At abandon there is no step 3: the hook is trusted when it is `100755` on `origin/<default>` and the main checkout's copy passes this check, since that copy is the one that runs.
- **Present but untrusted** — anything else. The skill **stops** and reports *Finishing by hand* naming the cause and its remedy; it never falls through to the generic push:
  - not executable on `origin/<default>` (step 3) — commit the mode change (`git update-index --chmod=+x`) on the default branch through the project's own procedure, then re-run;
  - present only on the branch, or the branch changes it (step 3) — the branch is changing the step that lands it, so land that change by hand through the project's own procedure once, then re-run;
  - an uncommitted edit to the tree's copy (the call to `check`) — revert it (`git restore --staged --worktree .claude/workspace/integrate`, which restores index and working tree from `HEAD`, mode included — and after step 3 and the rebase, `HEAD`'s copy is `origin/<default>`'s), then re-run; an edit meant to land is the previous case, since committing it makes the branch change the hook;
  - the main checkout's copy differs after the sync (the call to `land` or `abandon`, after the session has left the tree) — an edit there, or a sync that could not run: revert the edit, or resolve what blocked the sync (*Landing*), then re-run that phase from there.

**The trust check covers the entry file only**, so a hook must not let the branch change its decisions any other way: code it loads and configuration it reads (helper modules and their whole import closure, a CI workflow's path filters) come from `origin/<default>` — `git show origin/<default>:<path>`, extracted somewhere private — or from the main checkout after the same `git diff --quiet origin/<default> -- <paths>` check, never from the branch's working tree. Otherwise a branch edits a helper and turns a refusal into a go. No list of such paths is declared to the skill: what the hook loads is the hook's to fetch from `origin/<default>`.

**`provision` runs the tree's own copy**, after `test -x <tree>/.claude/workspace/provision`. This grants nothing the session has not already granted: it executes the tree's code anyway — the verification set runs the branch's `Makefile`, tests and scripts — and under `worktree.baseRef: fresh` (see *Harness settings*) a new tree's copy is `origin/<default>`'s. It is not contained, though: `provision` can and does reach outside the tree (lumus's registers a per-tree MCP server in the user's Claude config and pins git configuration shared with the main checkout), so a branch that edits it changes what runs on its next `run` or `teardown`.

## Opt-in

**A trusted `integrate` is the project's opt-in to the hook route** — INS-355's option (c), the hook-point taking precedence over the generic step, and no `CLAUDE.md` line is needed beside it. The `CLAUDE.md` line (`commit/SKILL.md` § *From a linked worktree*) governs only a project whose hook is absent. With a hook present, trusted or not, the generic push never runs, whatever `CLAUDE.md` says.

Reason: both live on `origin/<default>`, so the hook is no weaker an opt-in than the line, and the dangerous direction is the one where the line wins — a `CLAUDE.md` line taking precedence over a present hook, or a hook dropping out of the route because it is untrusted, would run the generic push in a project whose integration needs the hook's refusals.

## Landing

Both routes land the same way, and `/commit` does everything up to the landing itself on both, from the main checkout after `ExitWorktree keep`:

1. **Fetch, from the main checkout** — `git fetch origin`. This is the fetch the landing is decided on. `/commit` step 2 also fetches, from the tree, but that one only prepares: it feeds step 3's opt-in and trust reads, step 4's rebase and `check`. A fetch writes nothing but the remote-tracking refs, which every tree of a repository shares, so running one from the tree touches neither `origin` nor the local default branch; what matters is that the decision to land rests on a fetch made after the session left the tree, immediately before the landing.
2. **Sync** — if the local `<default>` is an ancestor of `origin/<default>` and behind it, `git merge --ff-only origin/<default>`. A local `<default>` that is not an ancestor (commits never pushed) is left alone; the containment test below names them. A sync git declines because a file in the main checkout is in the way stops the run with nothing moved.
3. **Empty range** — the branch is already on `origin/<default>` (`git merge-base --is-ancestor <branch> origin/<default>`), as after an earlier push that reported failure but landed. Nothing is pushed and no refusal applies: the sync was the whole landing, and the run goes on to removal — the hook is not called. `origin/<default>` may by now have moved past the branch; that does not matter.
4. **Moved remote** — `origin/<default>` is not contained in the branch: someone landed since step 4's rebase. Stop, with nothing moved but the sync; resuming from the tree fetches, rebases and re-verifies.
5. **Preconditions** — the main checkout is on `<default>`, and the local `<default>` is contained in the branch (`git merge-base --is-ancestor <default> <branch>`; otherwise `git log --oneline <branch>..<default>` shows the commits never pushed from it, which the user resolves first — the branch is never rebased onto them).
6. **The landing.** Generic route: `git merge --ff-only <branch>`, then `git push origin <default>`, restoring with `git reset --keep ORIG_HEAD` on a push that does not report success. Hook route: the identity check, then `integrate land` — which lands the same way, deciding its refusals first.

## `integrate`

### Who calls it, from which tree, and when

- **`check` — preflight, in the tree, before leaving it.** Called by `/commit` (directly, or under `/ship` and `/mill`) after step 4's rebase and after `/ship`'s re-verify, before step 5's ignored-files question and `ExitWorktree`. It changes nothing and decides only *go* or *refuse*. It does not fetch: it decides over the tree's view of `origin/<default>..<branch>`, which after step 2's fetch and step 4's rebase is what `land` would send unless the remote moves in between. Every refusal decidable from the tree is decided here — the empty range first, as `land` decides it, then the up-front refusals — so a refusal leaves the session **still isolated** and the tree, the branch and the main checkout untouched. It cannot foresee what only git decides at `land` time: a sync or landing fast-forward the main checkout declines, and a rejected push. Exit 64 means the hook has no preflight: `/commit` goes on.
- **`land` — in the main checkout, after `ExitWorktree keep`.** Called by `/commit` in place of the generic fast-forward and push, after its own fetch, sync and tests (*Landing* 1–5). `land` must not rely on any of those: a project may not implement `check`, and a user finishing by hand runs `land` directly. So it fetches, syncs, decides the empty range and every refusal itself, over `origin/<default>..<branch>` **after its own fetch** — exactly what its push would send, never a range the caller supplies — and only then lands.
- **`abandon` — in the main checkout, when a tree is discarded.** Called by the skill that abandons trees (not built yet), after its one confirmation and before removal. See *Abandoning*.

No session calls a hook-point from the main checkout on its own initiative; a user finishing by hand runs `land` there with the arguments `/commit` reported.

### What `land` does, in order

1. `git fetch origin`; a failed fetch is a failure.
2. Sync the local default branch to `origin/<default>` if it is behind and an ancestor (*Landing* 2).
3. **Empty range** — the branch is already on `origin/<default>`: push nothing, make sure the local default branch contains it (the sync usually did), and exit 0 with `result: integrated`, even when `origin/<default>` has moved past the branch. If the local default branch cannot be brought there (commits never pushed from it, or a file in the main checkout in the way), that is a **failure**, not a refusal — the change is already on `origin`, and what is wrong is the main checkout; the diagnostic names the commits or paths.
4. **Every up-front refusal**, over `origin/<default>..<branch>`, before anything else moves — including a local default branch the branch cannot be fast-forwarded from, whose diagnostic splits what the branch lacks into commits from `origin/<default>` (rebase the branch) and commits never pushed from the local branch (resolve those first).
5. Record the local default branch's commit; `git merge --ff-only <branch>`. A fast-forward git declines because a file in the main checkout would be overwritten is a **refusal**, decided by the merge: nothing pushed, the local branch at most synced. The hook never stashes or discards to make room.
6. `git push origin <default>` — naming remote and branch, never relying on the branch's upstream. On any push that does not report success, restore the local default branch to the recorded commit — safe even when the push's outcome is unknown. Then a rejection as **non-fast-forward** — the one refusal the push itself decides, last of all — exits 10; any other push failure exits as a failure.
7. Exit 0, `result: integrated`.

Within that a hook may decide more than this contract names — its own refusal cases — but it never pushes commit by commit (waiting on each deploy would leave a refusal half-applied; a series that needs it is refused and landed by hand), never pushes anything but the default branch by name, never removes the tree or the branch (the ignored-files question that guards removal is the skill's), never prompts (it has no one to ask), and never force-pushes. So the local default branch is never ahead of `origin` once `land` exits, and behind what it pushed only after a push reported as failed that landed anyway.

### Division of labour with `/commit`

| `/commit` step | Generic route (`CLAUDE.md` opt-in, hook absent) | Hook route (trusted hook) |
|---|---|---|
| 1–2: commit on the branch, record paths, fetch (from the tree) | `/commit` | `/commit` |
| 3: may this project integrate? | the `CLAUDE.md` line | the step-3 trust tests above; a hook that fails them stops here |
| 4: rebase onto `origin/<default>` | `/commit` (`/ship` re-verifies) | `/commit` (`/ship` re-verifies) |
| preflight | — | the identity check, then `integrate check`, in the tree |
| 5: ask about ignored files, `ExitWorktree keep` | `/commit` | `/commit` |
| 6: fetch from the main checkout, sync, empty range, moved remote, preconditions (*Landing* 1–5) | `/commit` | `/commit`; an empty range skips `land` |
| 6: fast-forward the local default branch onto the branch, then `git push origin <default>`, restoring on failure | `/commit` | the identity check, then `integrate land`, in the main checkout |
| verify the outcome | — | `/commit` (below) |
| 7: remove the tree and branch | `/commit`, with `provision teardown` first, if provided | `/commit`, with `provision teardown` first, if provided |
| 8: report; the task is advanced by `/ship`, never by either | `/commit` | `/commit` |

### Arguments

`--remote` is always `origin` for now. All paths are absolute. Where each value comes from:

- `--branch <name>`, `--tree <path>`, `--main <path>` — `/commit` step 1: the tree's branch, its top level (still on disk in every phase), and the main checkout.
- `--default <name>` — step 2: the default branch, without `origin/` (`main`).
- `--verified-tree <tree sha>` — optional, supplied by `/ship`, not `/commit`: the git tree object the verification set (`verify-core.md`) last passed on, green — the snapshot hash `sh ~/.claude/skills/review-diff.sh --tree` printed when its verification passed, or after the re-verify that follows a rebase. Once everything is committed, a hook compares it with `git rev-parse <branch>^{tree}`: equal means the tip being landed is exactly the tree that was verified, however many runs it took to get there. A bare `/commit` verifies nothing and passes none. What a hook does with an absent or different value is its own decision (lumus lands with a notice; CI on the default branch gates its deploy).

No flag carries the range: a hook decides over `origin/<default>..<branch>` after its own fetch. (The draft's `--base` and `--rebased` are gone; a hook still accepting them is unaffected, since `/commit` simply never passes them.)

`check` runs with the tree as its working directory; `land` and `abandon` with the main checkout.

### Exit codes and outcomes

| Exit | `check` | `land` | `abandon` |
|---|---|---|---|
| 0 | `result: go` | `result: integrated` — the skill verifies it | `result: done` |
| 10 | `result: refused` — nothing changed | `result: refused` — nothing pushed, the local default branch at most synced | — |
| 64 | `result: unsupported` — no preflight; go on | `result: unsupported` — failure | `result: unsupported` — nothing to clean up; go on |
| other | failure | failure | failure |

10, not a low number, because a shell hook under `set -e` exits with whatever status its failing command returned, and `grep`, `diff`, `test` and Python's `argparse` all return 2 on error; a refusal must not be something an error can claim by accident. A hook that cannot tell whether its push happened must exit with a failure, never 10. A refusal's last stdout line is `result: refused`, after a diagnostic naming the remedy.

**Refused means nothing pushed.** Every refusal is decided before the landing's fast-forward, except two that git decides and that leave the same state: a landing fast-forward the main checkout declines, and a push rejected as non-fast-forward, after which the hook has restored the local default branch. Either way the local default branch has at most been synced.

**`/commit` verifies every `land` outcome itself**, whatever the exit status, with two plain commands from the main checkout after `git fetch origin` — and if that fetch fails, the outcome is **unknown** whatever the exit status: nothing removed, Done not claimed, and the user checks before re-running, as for `/commit`'s own **unknown** case:

- `git merge-base --is-ancestor <branch> origin/<default>` — is the branch on the remote default branch?
- `git merge-base --is-ancestor <branch> <default>` — does the local default branch contain it?

| Exit | On `origin/<default>` | In local `<default>` | Outcome |
|---|---|---|---|
| 0 | yes | yes | **integrated** — continue to step 7 |
| 10 | no | — | **refused** — tree and branch kept; *Finishing by hand* on the hook route (below), leading with the hook's remedy |
| any | otherwise | | **failure** — nothing removed; reported with the state the two checks show. If the branch is on `origin/<default>` the change landed although the run failed (a push reported as failed that landed anyway, or a hook that broke the fast-forward-first rule): Done, with the local fast-forward, the tree's removal and the task left to the user in that order, as for `/commit`'s own **landed** case (step 6) |

So a hook can neither fake Done nor hide a push behind a refusal. After a refusal or failure in `land` the session is in the main checkout, **no longer isolated**, and says so as every post-`ExitWorktree` stop does; after a refusal or failure in `check` it is still in the tree, isolated, with nothing changed.

### Finishing by hand on the hook route

`/commit`'s generic *Finishing by hand* prints the fast-forward and push. On the hook route those are exactly the steps the hook exists to gate, so a refusal, a failure or an untrusted hook is never followed by them. Instead: the hook's remedy (or the trust check's, above), then — once the user has acted on it, and from a tree that has been rebased if the remedy said so — `.claude/workspace/integrate land` from the main checkout with the arguments `/commit` recorded, then the removal steps — `.claude/workspace/provision teardown` (if provided) before `git worktree remove`, as on every path that removes a tree. A project may describe its own by-hand procedure for what its hook refuses (lumus: `docs/process/worktree-integration.md`); where it does, that procedure wins over these steps.

### Abandoning

**`integrate abandon` cleans up landing-side state only** — what the hook route put outside the tree for this branch, for instance a branch pushed to `origin` as a branch to run validation without deploying. It must not touch the tree, its branch or its commits, must not push to the default branch, and must not prompt. Per-tree state that `provision` created is `provision teardown`'s, not this. A project with no landing-side state does not implement it (64: nothing to clean up) — lumus's case.

**The one explicit confirmation stays with the skill.** Before anything is discarded, the abandoning skill lists what would be lost — uncommitted changes (`git status --porcelain`), commits not on `origin/<default>` (`git log --oneline origin/<default>..<branch>`), and gitignored files (`!!` in `git status --porcelain --ignored`) — and asks once (`AskUserQuestion`). Only on a yes does it leave the tree (`ExitWorktree keep`), run `integrate abandon` (if trusted) and `provision teardown` (if provided) from the main checkout, and remove the tree and branch. That answer is also the only thing that licenses a forced removal (`git worktree remove --force`, `git branch -D`), which stay `ask` rules in `claude/settings.json`. If either hook-point fails, the skill keeps the tree and reports: nothing is lost, and the abandon can be retried. Before running `integrate abandon` it applies the abandon-time trust test, mode first: a hook that is not `100755` on `origin/<default>` is not run — its fix is a change landed on the default branch through the project's own procedure, which an abandon does not wait on — so the skill still removes the tree and reports that landing-side cleanup was skipped and why; a hook that is executable there but fails the identity check in the main checkout keeps the tree, with the remedy above, so the abandon can be retried with the tree still on disk.

## `provision`

- **`run`** — called by the skill that creates the tree, in the tree, right after `EnterWorktree` (not built yet: the step that creates a per-task tree before the plan gate). Idempotent, always: a project can wire the same work to its own `SessionStart` or `PostToolUse` hooks, and a session can re-enter a tree, so every step must skip a result that is already in place. Stdout lists what was provisioned and, separately, what could not be. **Any non-zero exit is a warning**, relayed, and the session continues — an unprovisioned tree still works, only worse.
- **`teardown`** — called from the main checkout immediately before a tree is removed, by whoever removes it: `/commit` step 7 after an integration, the abandoning skill, or the user following removal steps a skill printed — after a kept tree (ignored files, a refused removal) or *Finishing by hand* — which therefore always list it before `git worktree remove`. Not while the tree is kept. It undoes what `run` set up outside the tree (for lumus, the `claude mcp add -s local` registration keyed by the tree's path), is idempotent, and must not touch the tree's files, branch or commits. Exit 0 or 64 (nothing to tear down) lets removal proceed; any other status keeps the tree and is reported, so the teardown can be retried before removing by hand.
- **Arguments:** `--tree <path> --branch <name> --main <path> --default <name>`, meaning what they mean for `integrate`.

**Relation to a project's own provisioning hook.** In lumus, `.claude/hooks/provision_worktree.py` already provisions a tree from `SessionStart` and `PostToolUse/EnterWorktree` (`.env.local`, `.env.worktree`, `.claude/settings.local.json` and the per-tree MCP server, and the push guard). `.claude/workspace/provision` is not a second implementation: `run` is a thin entry into that same script — which needs a command-line entry taking `--tree` beside its hook-payload one — so the work is one implementation reached two ways, and `teardown` is the inverse that script does not have yet. Lumus keeps both of its own wirings until a skill calls `provision run`, and revisits them then.

## Defaults

For a project that provides neither hook-point:

- **Provision:** nothing to set up, nothing to tear down.
- **Integrate:** only where the project opts in in its `CLAUDE.md` on `origin/<default>` — *Landing*, generic route: fetch from the main checkout and sync, fast-forward its default branch onto the branch, then `git push origin <default>` (undoing the fast-forward if the push fails), then remove the tree and branch. Without the opt-in: commit on the branch and stop with the by-hand steps.
- **Abandon:** the skill's confirmed removal, with nothing to clean up.

A project may provide either hook-point without the other: `provision` alone pairs with the generic route, and `integrate` alone needs no provisioning.

## Harness settings this depends on

- **`worktree.baseRef` — assumed `fresh`** (the default, so no setting is needed): a tree branches from `origin/<default>`, so `origin/<default>..<branch>` is the tree's own work after step 4's rebase. Under `head` a tree branches from the local `HEAD`, carrying any unpushed commits on the local default branch into the branch, and both `/commit`'s containment test and a hook would pass them through to the push. A project that sets `head` takes that on itself; the contract does not reconcile it.
- **`worktree.symlinkDirectories`** overlaps `provision run`: a directory the harness shares into the tree needs no provisioning. Not settled here; noted so a project does not do both.
- `worktree.sparsePaths` and `worktree.bgIsolation` do not touch the contract.

## Wired in

- `/commit` (`commit/SKILL.md` § *From a linked worktree*): the three-state trust check at step 3, the identity check and `integrate check` before leaving the tree, *Landing* 1–5 on both routes, the identity check and `integrate land` in place of the generic fast-forward and push, the outcome table, `provision teardown` before removal, and *Finishing by hand* split by route.
- `/ship` passes `--verified-tree` through `/commit`; `/mill` reaches all of it through `/ship`.
- **Not yet:** `provision run` (the skill that creates per-task trees) and `integrate abandon` with its confirmation and abandon-time trust test (the skill that abandons them) — TODO.md Phase 4.

## Settled with INS-355

Lumus's answers to the draft's open questions (INS-355, 2026-10-06, and its revised push order), as this contract now encodes them:

1. **Opt-in** — a trusted `integrate` on `origin/main` is enough; no `CLAUDE.md` line.
2. **Verification** — an absent or different `--verified-tree` is a notice, never a refusal; a bare `/commit` integrates too. CI on `main` gates the deploy.
3. **Commit series** — refused, never pushed commit by commit: more than one commit with any touching migrations or `.env`, or any commit with the trailer `Integrate: by-hand`.
4. **Infra-only** — no path is special (reversed during review): what reaches production unchecked wants validation in CI, not a refusal in the hook.
5. **Unsafe provisioning** — a stateless re-run of the provisioning checks against `--tree`, loaded from `origin/main` with their whole import closure; no persisted report.
6. **Push order** — fast-forward, then `git push origin main`, restoring the local `main` on any failed push; a non-fast-forward rejection is a refusal (INS-362, ADR-43, superseding the push-then-fast-forward order first adopted under ADR-41).
7. **Done** — Done means pushed; lumus's done gate is retired (ADR-41, removed by INS-360).
8. **Provision wiring** — lumus keeps both `SessionStart` and `PostToolUse/EnterWorktree` until a skill calls `provision run`.
9. **Landing-side state** — none: no skill pushes a tree's branch as a branch, so lumus does not implement `abandon` (64) and `land` deletes nothing on the remote.
10. **Preflight** — lumus implements `check`, and measured that it passes worktree isolation.
11. **Hook dependencies** — `git show origin/main:<path>` for everything the loaded code imports; no declared path list.
