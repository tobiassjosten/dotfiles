# Workspace hook-points (shared contract)

> **Status: DRAFT.** No skill runs either hook-point yet: `/commit` still stops at its seam (`commit/SKILL.md` § *From a linked worktree*, step 3) whenever a project provides `.claude/workspace/integrate`, and nothing calls `.claude/workspace/provision`. This contract is written for lumus INS-355, its first consumer, to specify its integrate step against; it is finalised after INS-355, and the *Open questions* at the end are what that issue has to answer. Until then, treat every rule here as proposed. *Finalising* names the skill edits that wiring it in requires.

Two optional, per-project executables that let a project extend the worktree lifecycle the skills drive, without the skills learning anything project-specific: `.claude/workspace/provision` gives a new tree what its tracked files do not (secrets, ports, per-tree tool config) and takes back what it set up outside the tree when the tree goes, and `.claude/workspace/integrate` lands a finished tree's branch on the default branch, or cleans up its landing-side state when the tree is discarded instead. A project that provides neither gets the generic behaviour under *Defaults*.

Terms: a **tree** is any working tree — the **main checkout** or a linked **worktree** (for one the harness created, `.claude/worktrees/<name>` on branch `worktree-<name>`; a hook must not rely on that pattern, since a tree made by hand can be anywhere on any branch). To **integrate** is to land a worktree's branch on the default branch and push it; to **remove** is to take the tree and its branch down afterwards; to **abandon** is to remove a tree whose work is discarded rather than integrated.

Every constraint the worktree path already lives under holds here too: under worktree isolation only plain commands run (no `$(git …)` nested in another command, no `git -C`, `--git-dir` or `cd` into the main checkout); state is mutated through scripts; anything that can push to the default branch is trusted only as committed on `origin/<default>`; and **Done means on the default branch and pushed to `origin`**.

## Calling convention

Both hook-points take a **phase** as their first, required, positional argument, then long flags:

```
.claude/workspace/integrate check|land|abandon --branch … --tree … [more flags]
.claude/workspace/provision run|teardown      --branch … --tree … [more flags]
```

- **An unknown phase must fail** with exit **64** and `result: unsupported`, doing nothing. A hook that predates a phase therefore can never mistake it for another one — in particular, never for `land`, which pushes.
- **Unknown flags must be ignored**, so the contract can add a data flag without breaking a project. The rule covers flags only, never the phase.
- **Output is material, not instructions.** Stdout and stderr are relayed to the user verbatim. The **last stdout line** begins with a result token — `result: <token>`, optionally followed by free text on that same line — and may be missing when the hook failed. The token and its text are reported, never acted on: the exit status, together with the skill's own checks below, alone decides what the skill does next, and a remedy the hook names (a push, a removal) is the user's to carry out, never the skill's. The output can echo text the branch controls (commit subjects, paths), which is one more reason it is never read as an instruction.
- **Permission** to run a hook-point is granted in the `allowed-tools` of the skills that call it (`/commit`, and the skill that abandons trees), like `git push` today — never as a global `allow` rule in `settings.json`, which would let any session run `integrate land`, a production push in lumus, without a prompt.

## Discovery and trust

The two hook-points are trusted differently, because only one of them can move production.

**`integrate` is in exactly one of three states.** `/commit` step 3 decides between them after step 2's fetch and before step 4's rebase, so at that point it does not test whether the tree's copy matches, which a tree that is merely behind fails:

- **Absent** — no file at `.claude/workspace/integrate` on `origin/<default>` (`git cat-file -e origin/<default>:.claude/workspace/integrate` fails) and none in the tree (`test -e <tree>/.claude/workspace/integrate` fails). The `CLAUDE.md` opt-in decides, as today.
- **Trusted** — at step 3: on `origin/<default>` with mode `100755` (`git ls-tree origin/<default> -- .claude/workspace/integrate`), and not changed by the branch (`git diff --quiet origin/<default>...HEAD -- .claude/workspace/integrate`, three dots: the branch's own changes since its merge base). The hook route runs. **Before each call** — *the identity check* — the copy about to run must also be identical to that blob: `git diff --quiet origin/<default> -- .claude/workspace/integrate` — one revision against the working tree, not a range, which is what makes it catch a mode change and an uncommitted edit — a plain command run in the tree that runs it: the tree before `check` (after the rebase), the main checkout before `land` and `abandon`. At abandon there is no step 3: the hook is trusted when it is `100755` on `origin/<default>` and the main checkout's copy passes this check, since that copy is the one that runs.
- **Present but untrusted** — anything else. The skill **stops** and reports *Finishing by hand* naming the cause and its remedy; it never falls through to the generic push, but stops as `/commit` step 3 does today for any integrate file:
  - not executable on `origin/<default>` (step 3) — commit the mode change (`git update-index --chmod=+x`) on the default branch through the project's own procedure, then re-run;
  - present only on the branch, or the branch changes it (step 3) — the branch is changing the step that lands it, so land that change by hand through the project's own procedure once, then re-run;
  - an uncommitted edit to the tree's copy (the call to `check`) — revert it (`git restore --staged --worktree .claude/workspace/integrate`, which restores index and working tree from `HEAD`, mode included — and after step 3 and the rebase, `HEAD`'s copy is `origin/<default>`'s), then re-run; an edit meant to land is the previous case, since committing it makes the branch change the hook;
  - the main checkout's copy is stale or edited (the call to `land` or `abandon`, after the session has left the tree) — `git merge --ff-only origin/<default>` in the main checkout (or revert the edit there), then re-run that phase from there.

**The trust check covers the entry file only**, so a hook must not let the branch change its decisions any other way: code it loads and configuration it reads (helper modules, a CI workflow's path filters) come from `origin/<default>` — `git show origin/<default>:<path>` — or from the main checkout after the same `git diff --quiet origin/<default> -- <paths>` check, never from the branch's working tree. Otherwise a branch edits a helper and turns a refusal into a go.

**`provision` runs the tree's own copy**, after `test -x <tree>/.claude/workspace/provision`. This grants nothing the session has not already granted: it executes the tree's code anyway — the verification set runs the branch's `Makefile`, tests and scripts — and under `worktree.baseRef: fresh` (see *Harness settings*) a new tree's copy is `origin/<default>`'s. It is not contained, though: `provision` can and does reach outside the tree (lumus's registers a per-tree MCP server in the user's Claude config and pins git configuration shared with the main checkout), so a branch that edits it changes what runs on its next `run` or `teardown`.

## Opt-in

**A trusted `integrate` is the project's opt-in to the hook route** — INS-355's option (c), the hook-point taking precedence over the generic step. The `CLAUDE.md` line (`commit/SKILL.md` § *From a linked worktree*) governs only a project whose hook is absent. With a hook present, trusted or not, the generic push never runs, whatever `CLAUDE.md` says.

Reason: both live on `origin/<default>`, so the hook is no weaker an opt-in than the line, and the dangerous direction is the one where the line wins — a `CLAUDE.md` line taking precedence over a present hook, or a hook dropping out of the route because it is untrusted, would run the generic push in a project whose integration needs the hook's refusals. Proposed, not settled: open question 1.

## `integrate`

### Who calls it, from which tree, and when

- **`check` — preflight, in the tree, before leaving it.** Called by `/commit` (directly, or under `/ship` and `/mill`) after step 4's rebase and after `/ship`'s re-verify, before step 5's ignored-files question and `ExitWorktree`. It changes nothing and decides only *go* or *refuse*. INS-355's refusal cases can all be decided from the tree (verification against the tip, the commit series, infra-only paths, the provisioning checks), so a refusal here leaves the session **still isolated** and the tree untouched. Exit 64 means the hook has no preflight: `/commit` goes on to `land`. *To measure before finalising:* that a project script run from the tree passes isolation (plain script calls did when per-tree state was made writable from a worktree; this one is unmeasured).
- **`land` — in the main checkout, after `ExitWorktree keep`.** Called by `/commit` in place of step 6's push and fast-forward. `land` must make every refusal decision itself, whether or not `check` ran — a project may not implement `check`, and a user finishing by hand runs `land` directly — and must make them before it pushes.
- **`abandon` — in the main checkout, when a tree is discarded.** Called by the skill that abandons trees (not built yet: the step that creates and tears down a per-task tree), after its one confirmation and before removal. See *Abandoning*.

No session calls a hook-point from the main checkout on its own initiative; a user finishing by hand runs `land` there with the arguments `/commit` reported.

### Division of labour with `/commit`

| `/commit` step | Generic route (`CLAUDE.md` opt-in, hook absent) | Hook route (trusted hook) |
|---|---|---|
| 1–2: commit on the branch, record paths, fetch | `/commit` | `/commit` |
| 3: may this project integrate? | the `CLAUDE.md` line | the step-3 trust tests above; a hook that fails them stops here |
| 4: rebase onto `origin/<default>` | `/commit` (`/ship` re-verifies) | `/commit` (`/ship` re-verifies) |
| preflight | — | the identity check, then `integrate check`, in the tree |
| 5: ask about ignored files, `ExitWorktree keep` | `/commit` | `/commit` |
| 6, preconditions: main checkout on `<default>`; local `<default>` contained in the branch | `/commit` | `/commit`, before calling `land`; it stops on either as today |
| 6: fast-forward the local default branch onto the branch, then push it (`git push origin <default>`) | `/commit` | the identity check, then `integrate land`, in the main checkout |
| verify the outcome | — | `/commit` (below) |
| 7: remove the tree and branch | `/commit`, with `provision teardown` first, if provided | `/commit`, with `provision teardown` first, if provided |
| 8: report; the task is advanced by `/ship`, never by either | `/commit` | `/commit` |

The hook never removes the tree or the branch (the ignored-files question that guards removal is the skill's), never prompts (it has no one to ask), and never force-pushes. It lands the way the generic step does — fast-forward the local default branch onto what it lands, then push the default branch by name (`git push origin <default>`), restoring the local branch with `git reset --keep ORIG_HEAD` if a push fails, and never pushing `<branch>:<default>` or `<sha>:<default>` — so the local default branch is never ahead of `origin`, and behind what it pushed only after a push reported as failed that landed anyway. Within that it may do more — fast-forward to `origin/<default>` first, land commit by commit (fast-forward to one commit, push, wait for its deploy, repeat) — as long as its exit status tells the truth about what reached `origin`.

### Arguments

`--remote` is always `origin` for now. All paths are absolute. Where each value comes from:

- `--branch <name>`, `--tree <path>`, `--main <path>` — `/commit` step 1: the tree's branch, its top level (still on disk in every phase), and the main checkout.
- `--default <name>` — step 2: the default branch, without `origin/` (`main`).
- `--base <sha>` — the `origin/<default>` tip just after step 2's fetch, so `--base..<branch>` is exactly the series being landed. Step 2 does not record it today; *Finalising* adds `git rev-parse origin/<default>` there.
- `--rebased` — present when step 4 rebased the branch **in this run**. It misses a rebase made by an earlier run that stopped afterwards (a red re-verify, a closed session), whose branch the next run finds already up to date; so it is a hint for the report, never evidence that the tip is verified.
- `--verified-tree <tree sha>` — supplied by `/ship`, not `/commit`: the git tree object the verification set (`verify-core.md`) last passed on, green — the snapshot hash `sh ~/.claude/skills/review-diff.sh --tree` printed when its verification passed, or after the re-verify that follows a rebase. Once everything is committed, a hook compares it with `git rev-parse <branch>^{tree}`: equal means the tip being landed is exactly the tree that was verified, however many runs it took to get there. A bare `/commit` verifies nothing and passes none. This is how a hook learns, without asking anyone, whether the verification set ran on the rebased tip — INS-355's first case.

`check` runs with the tree as its working directory; `land` and `abandon` with the main checkout.

### Exit codes and outcomes

| Exit | `check` | `land` | `abandon` |
|---|---|---|---|
| 0 | `result: go` | `result: integrated` — the skill verifies it | `result: done` |
| 10 | `result: refused` — nothing changed | `result: refused` — nothing pushed (below) | — |
| 64 | `result: unsupported` — no preflight; go on to `land` | `result: unsupported` — failure | `result: unsupported` — nothing to clean up; go on |
| other | failure | failure | failure |

10, not a low number, because a shell hook under `set -e` exits with whatever status its failing command returned, and `grep`, `diff`, `test` and Python's `argparse` all return 2 on error; a refusal must not be something an error can claim by accident. A hook that cannot tell whether its push happened must exit with a failure, never 10.

**`/commit` verifies every `land` outcome itself**, whatever the exit status, with two plain commands from the main checkout after `git fetch origin` — and if that fetch fails, the outcome is **unknown** whatever the exit status: nothing removed, Done not claimed, and the user checks before re-running, as for `/commit`'s own **unknown** case:

- `git merge-base --is-ancestor <branch> origin/<default>` — is the branch on the remote default branch?
- `git merge-base --is-ancestor <branch> <default>` — does the local default branch contain it?

| Exit | On `origin/<default>` | In local `<default>` | Outcome |
|---|---|---|---|
| 0 | yes | yes | **integrated** — continue to step 7 |
| 10 | no | — | **refused** — tree and branch kept; *Finishing by hand* on the hook route (below), leading with the hook's remedy |
| any | otherwise | | **failure** — nothing removed; reported with the state the two checks show. If the branch is on `origin/<default>` the change landed although the run failed (a push reported as failed that landed anyway, or a hook that broke the fast-forward-first rule): Done, with the local fast-forward, the tree's removal and the task left to the user in that order, as for `/commit`'s own **landed** case (step 6) |

So a hook can neither fake Done nor hide a push behind a refusal. **Refused means nothing pushed**: every refusal decision is made before the landing's first fast-forward, so the local default branch has at most been fast-forwarded to `origin/<default>` (a sync, not a landing). After a refusal or failure in `land` the session is in the main checkout, no longer isolated, and says so as every post-`ExitWorktree` stop does; after a refusal in `check` it is still in the tree.

### Finishing by hand on the hook route

`/commit`'s *Finishing by hand* prints the generic push and fast-forward. On the hook route those are exactly the steps the hook exists to gate, so a refusal, a failure or an untrusted hook must never be followed by them. Instead: the hook's remedy (or the trust check's, above), then — once the user has acted on it — `.claude/workspace/integrate land` from the main checkout with the arguments `/commit` recorded, then the removal steps — `.claude/workspace/provision teardown` (if provided) before `git worktree remove`, as on every path that removes a tree. *Finalising* makes `commit/SKILL.md` § *Finishing by hand* branch on the hook's presence; until then `/commit` stops at its seam and prints the generic steps, which is safe only because no project has a hook yet.

### Abandoning

**`integrate abandon` cleans up landing-side state only** — what the hook route put outside the tree for this branch, for instance a branch pushed to `origin` as a branch to run validation without deploying. It must not touch the tree, its branch or its commits, must not push to the default branch, and must not prompt. Per-tree state that `provision` created is `provision teardown`'s, not this.

**The one explicit confirmation stays with the skill.** Before anything is discarded, the abandoning skill lists what would be lost — uncommitted changes (`git status --porcelain`), commits not on `origin/<default>` (`git log --oneline origin/<default>..<branch>`), and gitignored files (`!!` in `git status --porcelain --ignored`) — and asks once (`AskUserQuestion`). Only on a yes does it leave the tree (`ExitWorktree keep`), run `integrate abandon` (if trusted) and `provision teardown` (if provided) from the main checkout, and remove the tree and branch. That answer is also the only thing that licenses a forced removal (`git worktree remove --force`, `git branch -D`), which stay `ask` rules in `claude/settings.json`. If either hook-point fails, the skill keeps the tree and reports: nothing is lost, and the abandon can be retried. Before running `integrate abandon` it applies the abandon-time trust test, mode first: a hook that is not `100755` on `origin/<default>` is not run — its fix is a change landed on the default branch through the project's own procedure, which an abandon does not wait on — so the skill still removes the tree and reports that landing-side cleanup was skipped and why; a hook that is executable there but fails the identity check in the main checkout keeps the tree, with the remedy above (fast-forward or revert there), so the abandon can be retried with the tree still on disk.

## `provision`

- **`run`** — called by the skill that creates the tree, in the tree, right after `EnterWorktree` (not built yet: the step that creates a per-task tree before the plan gate). Idempotent, always: a project can wire the same work to its own `SessionStart` or `PostToolUse` hooks, and a session can re-enter a tree, so every step must skip a result that is already in place. Stdout lists what was provisioned and, separately, what could not be. **Any non-zero exit is a warning**, relayed, and the session continues — an unprovisioned tree still works, only worse.
- **`teardown`** — called from the main checkout immediately before a tree is removed, by whoever removes it: `/commit` step 7 after an integration, the abandoning skill, or the user following removal steps a skill printed — after a kept tree (ignored files, a refused removal) or *Finishing by hand* — which therefore always list it before `git worktree remove`. Not while the tree is kept. It undoes what `run` set up outside the tree (for lumus, the `claude mcp add -s local` registration keyed by the tree's path), is idempotent, and must not touch the tree's files, branch or commits. Exit 0 or 64 (nothing to tear down) lets removal proceed; any other status keeps the tree and is reported, so the teardown can be retried before removing by hand.
- **Arguments:** `--tree <path> --branch <name> --main <path> --default <name>`, meaning what they mean for `integrate`.

**Relation to a project's own provisioning hook.** In lumus, `.claude/hooks/provision_worktree.py` already provisions a tree from `SessionStart` and `PostToolUse/EnterWorktree` (`.env.local`, `.env.worktree`, `.claude/settings.local.json` and the per-tree MCP server, and the push guard). `.claude/workspace/provision` is not a second implementation: `run` would be a thin entry into that same script — which needs a command-line entry taking `--tree` beside its hook-payload one — so the work is one implementation reached two ways, and `teardown` is the inverse that script does not have yet. Which wiring stays once a skill calls `provision run` is open question 8.

## Defaults

For a project that provides neither hook-point:

- **Provision:** nothing to set up, nothing to tear down.
- **Integrate:** what `/commit` does from a worktree today, and only where the project opts in in its `CLAUDE.md` on `origin/<default>` — fast-forward the main checkout's default branch onto the branch, then `git push origin <default>` (undoing the fast-forward if the push fails), then remove the tree and branch. Without the opt-in: commit on the branch and stop with the by-hand steps.
- **Abandon:** the skill's confirmed removal, with nothing to clean up.

A project may provide either hook-point without the other: `provision` alone pairs with the generic route, and `integrate` alone needs no provisioning.

## Harness settings this depends on

- **`worktree.baseRef` — assumed `fresh`** (the default, so no setting is needed): a tree branches from `origin/<default>`, so `--base..<branch>` is the tree's own work after step 4's rebase. Under `head` a tree branches from the local `HEAD`, carrying any unpushed commits on the local default branch into the branch, and both `/commit` step 6's ancestor check and a hook would pass them through to the push. A project that sets `head` takes that on itself; the contract does not reconcile it.
- **`worktree.symlinkDirectories`** overlaps `provision run`: a directory the harness shares into the tree needs no provisioning. Not settled here; noted so a project does not do both.
- `worktree.sparsePaths` and `worktree.bgIsolation` do not touch the contract.

## Finalising

The skill edits that wiring the hook-points in requires, once INS-355 has answered the questions below:

- `commit/SKILL.md` step 2 records `--base`; step 3 applies the three-state trust check in place of its unconditional stop, and the identity check runs before each call to `check` and `land`; `check` runs before step 5; `land` replaces step 6's push and fast-forward after its two preconditions; the outcome table above follows it; step 7 runs `provision teardown` before removal.
- `commit/SKILL.md` § *Finishing by hand* branches on the hook's presence, as above, and every set of removal steps `/commit` prints — there, and for a tree kept in steps 5–7 — lists `provision teardown` before `git worktree remove`.
- `/ship` passes `--verified-tree`.
- The skill that creates per-task trees calls `provision run`; the skill that abandons them owns the confirmation, applies the abandon-time trust test (*Discovery and trust*), and calls `integrate abandon` and `provision teardown`.
- Permission entries for both hook-points in those skills' `allowed-tools`, plus `Bash(git ls-tree:*)` and `Bash(test -x:*)` for `/commit`, which has neither today.

## Open questions for INS-355

1. **Opt-in.** Is a trusted `integrate` on `origin/main` enough (proposed), or does lumus also want a `CLAUDE.md` line before the hook route runs?
2. **Verification.** `--verified-tree` equal to the tip's tree is the only evidence the tip was verified. With it absent — a bare `/commit` — does `land` refuse, so that only `/ship` ever integrates, or land with a notice when the branch was not rebased?
3. **Commit series.** How does the hook recognise, in `--base..<branch>`, a series lumus's `docs/process/deployment.md` wants pushed commit by commit (a commit trailer, migration-stage detection, an env-var diff)? And does it refuse, or push commit by commit, waiting for each deploy?
4. **Infra-only.** Derive it from `validate.yml`'s `paths-ignore` — read from `origin/main`, per the dependency rule under *Discovery and trust* — or hard-code the paths? And refuse, or land with a notice that the Infrastructure workflow plans it?
5. **Unsafe provisioning.** Re-run `provision_worktree.py`'s safety checks against `--tree`, loading that script from `origin/main` (stateless; proposed), or have provisioning persist its report for the hook to read?
6. **Push order.** Adopt push-then-fast-forward in place of lumus's `docs/process/worktree-integration.md` order, fast-forward-then-push? *Refused means nothing pushed* allows a fast-forward to `origin/main` first, but the landing's own fast-forward of the local `main` onto the branch has to come after the push for a rejected push to change nothing locally. *Answered by lumus (INS-362, its ADR-43): fast-forward, then `git push origin main`, restoring the local `main` after any failed push; `/commit`'s generic route now does the same.*
7. **Done.** Lumus's done gate resolves an issue on the worktree commit, before integration; with a refusing hook, an issue can be Done and not deployed. Stop resolving on worktree commits, or keep the gap and document it as deliberate?
8. **Provision wiring.** With a `--tree` entry added to `provision_worktree.py`, keep or drop the `PostToolUse/EnterWorktree` wiring once a skill calls `provision run`? (`SessionStart` stays either way, for `claude -w` and trees opened by hand.)
9. **Landing-side state.** Does lumus push a tree's branch as a branch to run Validate without deploying (`docs/process/worktree-push-guard.md`)? If so, should `integrate abandon` delete that remote branch, and should `land` delete it after integrating?
10. **Preflight.** Will lumus implement `check`? Without it, every refusal comes from `land`, after `ExitWorktree`, leaving the session unisolated in the main checkout.
11. **Hook dependencies.** Is loading helpers and configuration from `origin/main` with `git show` workable for a Python hook, or would lumus rather declare a list of paths that the skill checks with the same `git diff --quiet` before each call?
