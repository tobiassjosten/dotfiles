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

**Precondition — the tree must be clean.** `sh ~/.claude/skills/review-diff.sh --tree` must equal `git rev-parse -q --verify 'HEAD^{tree}'`. After the first item it will be, because the previous iteration pushed. If it isn't, something was left behind — stop and go to § 4 rather than folding a stray change into this item's commit.

**Plan and implement.** Follow `~/.claude/skills/next/SKILL.md` with this item's identifier as its `$ARGUMENTS`, skipping its selection step — § 1 already resolved it — but not its check that the workspace is free, which runs before anything is claimed.

- The plan-mode gate is a **hard user gate**: surface the plan and wait for the user's `ExitPlanMode` approval. **Do not modify any file before approval.** The plan's own first step is its opening bookkeeping (record the plan, move the item to In Progress, self-assign) — verify it is present.
- **A rejected plan is not the end of the run.** Treat the rejection as input, draft a fresh plan for the same item, and present it again. If the rejection says to skip the item, skip it per § 4. If it says to stop, stop and report.
- Once approved, implement the plan.

**Verify to green.** Run the check set from § 2. A red check is this item's to fix: fix and re-check, up to **3 fix → check cycles**. Fix by class, not by instance, and keep the fix inside this item's scope — a red check that turns out to need a change outside it goes to § 4 instead of growing the item.

**Ship.** Follow `~/.claude/skills/ship/SKILL.md` with `now` as its `$ARGUMENTS`: verification runs again as its gate, no review runs, `/commit` commits and pushes, and its Finish gate advances the item. Carry this item into `/ship` explicitly, as § 1 resolved it — the source's own id, and for a `TODO.md` item the task line — not the entry as typed: `/ship` resolves the task from the marker `/next` wrote when it claimed the item, and stops if the item passed in is a different one — the cross-check that catches a marker left over from an earlier item, which in a loop is the easiest thing to get wrong. If `/ship` stops for any reason — a check it finds red, a failing pre-commit hook, a push that diverged — go to § 4. So does a ship that went through but left the task marker in place because advancing the item failed: the workspace is still bound to it, and the next item's `/next` would refuse to start.

**Record** the outcome before moving on: the new commits (`git log --oneline`), whether the push succeeded, and the item's final state.

### 4. Trouble — stop and ask

Reached when verification is still red after its three cycles, when the item turns out to need a decision the approved plan doesn't cover, when the tree wasn't clean at the start of an item, when `/next` stopped (the workspace still bound to an earlier item, for one), or when `/ship` stopped or left the task marker in place. Put it to the user in a single `AskUserQuestion`, naming what happened concretely, with three options:

- **Skip this item and continue** — `git stash -u` whatever this item produced, so nothing is discarded; name the stash in the report. Return the item to the state it was in before the run, so the board doesn't claim work that isn't happening and no item is left In Progress, and clear the workspace's binding to it (`sh ~/.claude/skills/task-marker.sh clear`) — otherwise the next item's `/next` finds the workspace still bound and refuses to claim it. Continue with the next identifier.
- **Dig in** — work the problem here and now, then rejoin § 3 where it left off. The run continues afterwards.
- **End the run** — stop, leaving this item's work in the tree as it stands (not stashed — the user is taking it over). Every identifier after it is *not reached*.

Two triggers read these options differently, because the item is not in the failed-before-shipping state the options assume:

- **`/ship` pushed but left the marker in place** — the commit is out, so skipping must *not* return the item to its pre-run state or stash anything. Name the item and why advancing it failed; skip then means leaving the advance to the user and clearing the marker, dig in means retrying the advance and then clearing it.
- **`/next` found the workspace bound to an earlier item** — the binding is that earlier item's, not this one's. Name it; clearing its marker is offered only as its own explicit choice, never as part of skip, which here just records this item as not started and moves on (and the next item will stop the same way until the binding is resolved).

Never discard an item's work without saying so, and never `git reset --hard` to get out of trouble.

### 5. Report

One block, covering the whole run:

- **Items** — every identifier from the argument, in the order given, each with an explicit outcome: **shipped** with its commit SHAs, **shipped, not advanced** with its commit SHAs (pushed, but advancing the item was left to the user), **skipped (\<reason\>)** with its stash name when anything was stashed, **not started (workspace bound to \<item\>)**, **dropped at resolution (\<reason\>)**, or **not reached (run ended at `<id>`)**. Never a blank outcome; an identifier the user typed is always findable in this list.
- **Verification** — the check set settled on in § 2, and its final pass/fail state.
- **Review directory** — `$(git rev-parse --absolute-git-dir)/review/`, if it exists. Say plainly that no review ran on any item, that `/ship now` never consulted the ledger, and that `/ship` deletes the directory after each successful push — so a directory still there came from something before this run and is the user's to delete.
- **Remaining steps** — `/ship`'s § 6 bullet, folded across the whole run: what still has to happen before this work is actually done, split into **Blocking** and **Follow-up**, each saying what and who/where. If there is genuinely nothing, say so explicitly.
- **Next step** — if the run ended early or left items not started, the exact `/mill` invocation that resumes it (the identifiers not reached, and those not started once their workspace binding is resolved). If items were skipped, what each one needs. For each item shipped but not advanced, that it still needs moving in its source by the user. Say that everything shipped only when every item's outcome is plain **shipped**.

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
