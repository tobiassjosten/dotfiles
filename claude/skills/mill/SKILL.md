---
name: mill
description: Take a series of work-item identifiers and run each one from identifier to pushed commit — `/next` plans it in plan mode and implements it on approval, the verification set is brought to green, and `/ship now` commits and pushes it without a code review — then move on to the next. Every identifier is resolved and confirmed up front, and the order given is the order worked. The plan gate is the only gate per item; a check this run turned red is fixed, and anything needing judgment beyond the approved plan stops and asks. For work simple enough that the plan is the review — /forge stays the default for everything else.
disable-model-invocation: true
argument-hint: <id> [<id> ...]
---

# Mill

Run a series of work items through the routine path: for each one in turn, `/next` plans it in plan mode and implements it once the user approves, the verification set is brought back to green, and `/ship now` commits and pushes it. The user's attention is spent on one thing per item — the plan — and on nothing else unless something goes wrong.

**No review round runs.** That is the whole trade: `/mill` is for items whose description already carries the detail needed to get them right, where the plan *is* the review and the verification set is the proof. Everything else belongs in `/forge`, which selects and implements the same way but hands the change to `/polish`'s fanned-out review and stops before the commit. If a run finds itself repeatedly stopping to ask, the list was misjudged — say so, and finish the rest with `/forge`.

## Argument

`$ARGUMENTS` is the work-item identifiers, separated by whitespace or commas — `/mill ENG-14 ENG-15 ENG-19`. **The order given is the order worked**, not the source's own order: the point of this skill is that the user chose these items and this sequence. A single identifier is legal and yields a one-item run.

If it's empty, ask the user which items to run and stop; the list they send in reply is the input, handled exactly as if it had arrived as the argument.

An entry that isn't an identifier is treated as a hint and resolved the way `/next` resolves one — but every entry, ID or hint, must survive the resolution gate in § 1 before anything is planned.

## Composed pieces

This skill only adds orchestration on top of existing pieces — they remain the single source of truth:

- **Selection, planning, implementation** come from `/next` (`~/.claude/skills/next/SKILL.md`), run once per identifier with that identifier as its `$ARGUMENTS`. It owns the plan-approval gate, which a subagent can't run, so **read and follow that `SKILL.md` directly** in this (main-loop) context. It sets `disable-model-invocation: true`, so it can't be invoked through the Skill tool anyway.
- **The work-item source** — where items live, the shape they take, and their lifecycle — is discovered **once**, up front, by `/next`'s *Determine the work-item source* section, and passed forward to every iteration so the loop doesn't rediscover it per item.
- **The verification set** comes from `~/.claude/skills/verify-core.md`, also settled **once** at the start of the run and reused for every item. This skill's disposition on a check that *this run* turned red is to fix it; on one that was already red, to stop before starting (§ 2).
- **Shipping** comes from `/ship` (`~/.claude/skills/ship/SKILL.md`), followed once per item with the argument `now` — its review dial set to skip, its verification gate still running, its `/commit` step pushing, and its Finish gate advancing the item. It owns user interaction too, so **read and follow that `SKILL.md` directly** in this (main-loop) context. It also sets `disable-model-invocation: true`.

## Procedure

### 1. Resolve the whole list, and confirm it

Before anything is planned and before any file is touched. Determine the work-item source once (`next/SKILL.md` § *Determine the work-item source*), then resolve every entry in the argument against it, using `/next`'s two mechanisms: an entry that looks like an ID resolves directly, anything else is matched as a hint.

Present the result as one short table — entry, what it resolved to, its current state — and get the user's confirmation for the whole set. **This is a gate**: proceed on their say-so, not before. An entry that resolves to nothing, to more than one item, or to an item already in its terminal state is named here with the reason and **dropped from the run** rather than guessed at; it still gets a line in the final report.

Resolving the whole list before planning any of it is deliberate. A misresolved identifier in a batch implements the wrong item under the right name, and the cheapest moment to catch that is before a plan has been drafted for it.

### 2. Establish a green baseline — once, for the run

Determine and run the verification set per `~/.claude/skills/verify-core.md`. Record the checks settled on; every item in the run reuses this same set.

**Any check already red → stop, before the first item.** Report which check and its output, and stop without planning anything. `/mill` repairs what this run breaks; a check that was failing beforehand is a different job with a different scope, and fixing it silently inside an unrelated item's commit is how that scope creep becomes permanent. Repair it outside the run, then start `/mill` again. This is a normal, expected exit — not a failure.

### 3. Work each item, in order

For each confirmed item in the order given:

**Precondition — the tree must be clean.** `sh ~/.claude/skills/review-diff.sh --tree` must equal `git rev-parse -q --verify 'HEAD^{tree}'`. After the first item it will be, because the previous iteration pushed. If the tree isn't clean, something was left behind — stop and go to § 4 rather than folding a stray change into this item's commit.

**Plan and implement.** Follow `~/.claude/skills/next/SKILL.md` with this item's identifier as its `$ARGUMENTS`, skipping its selection step — § 1 already resolved it — but not its check that the workspace is free, which runs before anything is claimed.

- The plan-mode gate is a **hard user gate**: surface the plan and wait for the user's `ExitPlanMode` approval. **Do not modify any file before approval.** The plan's own first step is its opening bookkeeping (record the plan, move the item to In Progress, self-assign) — verify it is present.
- **A rejected plan is not the end of the run.** Treat the rejection as input, draft a fresh plan for the same item, and present it again. If the rejection says to skip the item, skip it per § 4. If it says to stop, stop and report.
- Once approved, implement the plan.

**Verify to green.** Run the check set from § 2. A red check is this item's to fix: fix and re-check, up to **3 fix → check cycles**. Fix by class, not by instance, and keep the fix inside this item's scope — a red check that turns out to need a change outside it goes to § 4 instead of growing the item.

**Ship.** Follow `~/.claude/skills/ship/SKILL.md` with `now` as its `$ARGUMENTS`: verification runs again as its gate, no review runs, `/commit` commits and pushes, and its Finish gate advances the item. Carry this item into `/ship` explicitly, as § 1 resolved it — the source's own id, and for a `TODO.md` item the task line — not the entry as typed: `/ship` resolves the task from the marker `/next` wrote when it claimed the item, and stops if the item passed in is a different one — the cross-check that catches a marker left over from an earlier item, which in a loop is the easiest thing to get wrong. If `/ship` stops for any reason — a check it finds red, a failing pre-commit hook, a push that diverged — go to § 4. So does a ship that went through but left the item **not advanced** — failed, or deferred (the main checkout was off the default branch) — `/ship` says so, and in the main checkout it also leaves the task marker in place, so the workspace is still bound to it and the next item's `/next` would refuse to start. Key on `/ship`'s report, not on the marker alone: from a linked worktree the marker is removed with the tree (unless it was kept) whether or not the advance succeeded.

**An item shipped from a linked worktree ends the run.** There `/ship` — through `/commit` — integrates, pushes, removes the tree and leaves the session in the main checkout, **no longer worktree-isolated**. The next item must not carry on unisolated, and creating a fresh tree per item is a later change, so stop after recording this item: every identifier after it is *not reached (run ended after a worktree item)*, and the report's Next step names the invocation that resumes them from a new tree. The same holds for **any `/ship` stop inside `/commit` after it committed on the branch** — the work is on the tree's branch, not in a clean place for the next item, and if `/commit` had left the tree the session is in the main checkout. A `/ship` stop before anything was committed (verification red at `/ship`'s own gate, before `/commit` runs) leaves the session in the tree with the work uncommitted, and § 4's general options apply. A red re-verification after `/commit` rebased the branch is a stop *after* committing.

**Record** the outcome before moving on: the new commits (`git log --oneline`), whether the push succeeded, and the item's final state.

### 4. Trouble — stop and ask

Reached when verification is still red after its three cycles, when the item turns out to need a decision the approved plan doesn't cover, when the tree wasn't clean at the start of an item, when `/next` stopped (the workspace still bound to an earlier item, for one), or when `/ship` stopped or reported the item as not advanced (failed or deferred). Put it to the user in a single `AskUserQuestion`, naming what happened concretely, with three options:

- **Skip this item and continue** — `git stash -u` whatever this item produced, so nothing is discarded; name the stash in the report. Return the item to the state it was in before the run, so the board doesn't claim work that isn't happening and no item is left In Progress, and clear the workspace's binding to it (`sh ~/.claude/skills/task-marker.sh clear`) — otherwise the next item's `/next` finds the workspace still bound and refuses to claim it. Continue with the next identifier.
- **Dig in** — work the problem here and now, then rejoin § 3 where it left off. The run continues afterwards.
- **End the run** — stop, leaving this item's work in the tree as it stands (not stashed — the user is taking it over). Every identifier after it is *not reached*.

Three triggers read these options differently, because the item is not in the failed-before-shipping state the options assume:

- **`/ship` stopped inside `/commit` from a linked worktree, after committing** — the item's work is committed on the tree's branch, and the tree, branch and marker are where `/ship` named them; if `/commit` had already left the tree, the session is in the main checkout, where nothing of this item lives. The run ends after this item whatever is chosen (§ 3), so ask a **two-way** question instead of the three options above: leave it to the user — name the tree, the branch and `/ship`'s by-hand steps — or dig in and follow those steps here — after a refusal from the project's integrate hook (`/commit`'s hook route), that means acting on the hook's remedy and re-running its `land`, never landing around it. Neither stashes nor clears anything (`git stash -u` and `task-marker.sh clear` would act on the main checkout, not the item), and neither touches the item's tracker state: its work exists, on a branch. Record it as **committed, not integrated** (§ 5). (A stop before anything was committed is not this case: the work is uncommitted in the tree, the session is still in it, and the general options apply.) A stop whose push `/ship` reported as **landed** or of **unknown** outcome takes the same two-way question with other steps: leave it to the user names what `/ship` named — for landed, the local fast-forward, the tree's removal and the advance, in that order; for unknown, the check first — and dig in follows them here (for unknown, the check, then the landed steps if it landed; if it did not, nothing was pushed and the item resumes from a session opened in its tree, which this run does not do). Record it as **landed, not advanced** or **push outcome unknown** (§ 5), not committed, not integrated.
- **`/ship` pushed but the item was not advanced** (failed, or deferred) — the commit is out, so nothing here returns the item to its pre-run state or stashes anything. Name the item and why it was not advanced; what to offer depends on where and why:
  - **Main checkout, failed** — the three options, read as: skip leaves the advance to the user and clears the marker so the next item can start; dig in retries the advance and then clears the marker; end the run leaves both to the user.
  - **Main checkout, deferred** (the checkout was on a feature branch) — skip or end the run only, no dig in: what deferred it is landing that branch on the default branch, an ungated push to the default branch that `/mill` never makes. Skip clears the marker so the next item can start; end the run leaves it. Either way, name the landing as the user's, and that the item is advanced only after it (`/ship` § 5).
  - **From a worktree** — the run ends after this item whatever is chosen (§ 3), and no `task-marker.sh` command runs: from the main checkout it would hit that checkout's own binding, while this item's marker went with the tree or sits in the kept tree at the path `/ship` reported. A worktree ship is never deferred — `/commit` integrates onto the default branch or stops — so only a **failed** advance reaches here (a push reported as failed that landed anyway is a stop, above): ask two ways, leave it to the user, or dig in and retry the advance.
- **`/next` found the workspace bound to an earlier item** — the binding is that earlier item's, not this one's. Name it; clearing its marker is offered only as its own explicit choice, never as part of skip, which here just records this item as not started and moves on (and the next item will stop the same way until the binding is resolved).

Never discard an item's work without saying so, and never `git reset --hard` to get out of trouble.

### 5. Report

One block, covering the whole run:

- **Items** — every identifier from the argument, in the order given, each with an explicit outcome: **shipped** with its commit SHAs, **shipped, not advanced** with its commit SHAs and why — failed (the advance is left to the user) or deferred (the branch must land on the default branch before the item may be advanced), **skipped (\<reason\>)** with its stash name when anything was stashed, **not started (workspace bound to \<item\>)**, **committed, not integrated (`<branch>` in `<tree>`)**, **landed, not advanced (`<branch>` in `<tree>`)** — a worktree ship whose push `/commit` reported as failed but whose change reached the default branch anyway, or **push outcome unknown (`<branch>` in `<tree>`)** when it could not tell, **dropped at resolution (\<reason\>)**, **not reached (run ended at `<id>`)**, or **not reached (run ended after a worktree item)**. Never a blank outcome; an identifier the user typed is always findable in this list.
- **Verification** — the check set settled on in § 2, and its final pass/fail state.
- **Review directory** — for a run that stayed in one checkout, the path `sh ~/.claude/skills/review-state.sh dir` prints, if it exists (exit 1: it does not). Say plainly that no review ran on any item, that `/ship now` never consulted the ledger, and that `/ship` deletes the directory after each successful push — so a directory still there came from something before this run and is the user's to delete. For a run that ended after a worktree item, do not look it up afresh — the session is in the main checkout, whose directory has nothing to do with this run: report the path `/ship` named for that item instead (removed with the tree, or kept with it).
- **Remaining steps** — `/ship`'s § 6 bullet, folded across the whole run: what still has to happen before this work is actually done, split into **Blocking** and **Follow-up**, each saying what and who/where. If there is genuinely nothing, say so explicitly.
- **Next step** — if the run ended early or left items not started, the exact `/mill` invocation that resumes it (the identifiers not reached, and those not started once their workspace binding is resolved). If items were skipped, what each one needs. For each item shipped but not advanced: a failed one still needs moving in its source by the user; a deferred one needs its branch landed on the default branch first — and only then moving, never before. A **landed, not advanced** item is Done: it needs the local fast-forward (`git merge --ff-only <branch>` in the main checkout), its tree removed, and moving in its source, in that order. A **push outcome unknown** item needs checking (`git fetch origin`, then `git merge-base --is-ancestor <branch> origin/<default>`) before anything is re-run: on the default branch, it is landed and needs the steps above; otherwise nothing was pushed, and it resumes from its tree. Say that everything shipped only when every item's outcome is plain **shipped**.

Ending mid-list is a normal exit, not a failure. The report is what makes resuming cheap.

## Rules

- **Order is fixed:** resolve and confirm the whole list → green baseline → then, per item, clean tree → plan gate → implement → verify to green → `/ship now`. Never start an item while the previous one's change is still in the tree.
- **The plan gate is never batched.** One plan, one approval, one implementation, one push, then the next item. Presenting several plans at once, or implementing ahead of an approval, loses track of which change is in the tree — and the tree is what `/ship` commits.
- **No review runs, and the summary says so.** `/mill` ships on the strength of an approved plan and a green verification set, nothing more. Where the project's lifecycle has a review state, pass through it, but never record an acceptance-criteria or Definition-of-Done check that no reviewer performed. Marking work as reviewed that was never reviewed is the one outcome this family of skills exists to prevent, and skipping the review does not license claiming it.
- **Never silently drop an identifier.** Every entry in the argument gets an outcome in the report.
- **Never discard work silently.** Skipping stashes and names the stash; nothing in this skill resets the tree.
- **Fix what this run broke, and nothing else.** A pre-existing red check stops the run at § 2. Boy-scout fixes stay proportionate and adjacent — never a silent refactor of unrelated code.
- Honor every project Hard Rule and gate (`CLAUDE.md`): plan approval before any file change, at most one item In Progress, and the project's documented Finish gate.
- **This is the exception, not the default.** `/forge` is the default path and the one to reach for whenever an item might need judgment. If more than an item or two in a run stops at § 4, say so in the report: the list was misjudged, and the rest is better run through `/forge`.
