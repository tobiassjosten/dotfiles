---
name: forge
description: Pick the next task, implement it, then harden it with /polish's fanned-out review rounds until a round finds no defects and has nothing left to fix, or the round limit is spent — leaving it reviewed and ready for the user to ship.
disable-model-invocation: true
---

# Forge

Take one work item from selection all the way to a review-hardened change: run the `/next` workflow to pick, plan, and implement a task, then hand the result to `/polish` to loop a strict review — fixing everything a strict senior developer would insist on — until a round finds no defects and has nothing left to fix, or its round limit is spent. Finish by moving the task to In Review and summarizing the change and every review round. **Never commit** — the change is left In Review for the user to `/ship`.

## Argument

An optional argument may follow the command: `$ARGUMENTS`. When present, it is a hint (task ID, filename, or descriptive text) forwarded to the `/next` selection step. When absent, `/next` picks the first task by its source's order.

## Composed pieces

This skill only adds orchestration on top of existing pieces — they remain the single source of truth:

- **Selection, planning, implementation** come from `/next` (`~/.claude/skills/next/SKILL.md`), which owns the plan-approval gate and other user interactions. A subagent can't run those gates, so **read and follow that `SKILL.md` directly** in this (main-loop) context. It sets `disable-model-invocation: true`, so it can't be invoked through the Skill tool anyway.
- **The review+fix loop** comes from `/polish` (`~/.claude/skills/polish/SKILL.md`): it establishes a green baseline, then runs fanned-out review rounds with a strict fix policy (fix by class, tests, delta checks) until a round finds no defects and has nothing left to fix, or its round limit is spent. `/forge` follows it with no arguments, so polish's defaults apply. It owns user gates too (batched escalations), so **read and follow that `SKILL.md` directly** in this (main-loop) context. It also sets `disable-model-invocation: true`.

## Procedure

### 1. Select, plan, implement

Follow `~/.claude/skills/next/SKILL.md`, treating this skill's argument as its `$ARGUMENTS`.

- The plan-mode gate is a **hard user gate** (project Hard Rule 3): surface the plan and wait for the user's `ExitPlanMode` approval. Do not modify any file before approval. The plan's own first step is its Backlog bookkeeping (record the plan, move the task to In Progress, self-assign) — verify it is present, as the plan-gate hook requires.
- Before implementing, record the baseline (`git status` and `git rev-parse HEAD`) so the final summary can describe exactly what changed.
- Once approved, implement the plan.

If `/next` finds no actionable task, report that and stop — naming `$(git rev-parse --absolute-git-dir)/review/` if it already exists, since a ledger left there suppresses findings in any delta-mode round, and in every review of a change made on the same `HEAD`.

### 2. Harden the change

Follow `~/.claude/skills/polish/SKILL.md` on the change just implemented, with no arguments (polish's defaults): it establishes a green baseline and runs the review+fix rounds. Retain its per-round tracking and its final round's items — the final summary below folds them in. Its fix policy, escalation gates, and re-verification are authoritative; do not duplicate or override them here.

### 3. Finish — project Review gate, no commit

If the project documents a Review gate — `docs/process/task-workflow.md`, CLAUDE.md, Backlog instructions — follow it exactly. Generically: verify each acceptance criterion and Definition-of-Done item against objective evidence, record the outcome on the task, and move it to the project's review state. On a **Backlog.md board** that is `backlog task edit --check-ac` / `--check-dod`, a review note via `--append-notes`, and In Review; an **external tracker** is transitioned through its own API.

Whether these writes land in the repo depends on the source, and that decides whether `/polish`'s convergence record — which names the reviewed diff, base and working tree both — still matches when `/ship` runs. A **Backlog.md board** is written here, so the tree moves on and `/ship` reviews afresh; that is the intended trade, since the acceptance criteria are then checked against the polished code. A **`TODO.md` or per-task-file** source was already cleared back in step 1 (`/next` requires the implementation plan to end by marking the task done in its source), so this step may write nothing and the record can still match. An **external tracker** never touches the tree at all.

Do **not** write the final summary to the task, move it to Done, or commit — those belong to the Finish gate, which the user triggers with `/ship` (Hard Rule 4). `/ship` is the counterpart to this skill: it re-checks verification, reviews (or reuses `/polish`'s convergence record when one matches the current diff — the same base and the same tree), commits and pushes via `/commit`, and advances the task to Done.

### 4. Summary

Present, in the conversation:

- **Change** — the task worked, and a concise description of the code changes (files and areas touched).
- **Rounds**, **Final round** and **Ledger** — `/polish`'s summary bullets verbatim, including all four of its endings (converged, hit the cap, stopped on an incomplete review, or stopped before the loop) and its report of any pre-existing entries the rounds ignored as belonging to an earlier change. Point at them rather than paraphrasing: a paraphrase here is how this mirror drifts the next time `/polish` changes. A `/forge` run escalates through `/polish`, so it routinely records `settled:`, `rejected:`, `decided:` and `converged:` entries; say so, and say that only `/ship` deletes the directory — after it pushes — while every other ending leaves it for the user to delete at `$(git rev-parse --absolute-git-dir)/review`.
- **Verification** — the final state of each check in `/polish`'s verification set (name them and their pass/fail state).
- **Next step** — branch on how `/polish` ended. **Converged:** the task is In Review; `/ship` reviews (or reuses the convergence record, though if step 3 wrote to the repo — a Backlog.md board does — the tree has moved on and it will review), commits and pushes, and closes the task out. **Hit the cap:** the open findings listed above still stand and `/ship` will block on any defect among them, so fix them first. **Stopped on an incomplete review:** the named role's slice was never reviewed at this bar — re-run `/polish` before shipping. **Stopped before the loop on a red baseline:** the change is implemented and uncommitted and its task is still In Progress, but the verification set was red before it and `/polish` did not widen scope to repair that — repair the named check outside this change, then run `/polish` again and carry on from § 3. Do *not* re-run `/forge`: `/next` would select a different To Do task and leave two In Progress. **Stopped before the loop with nothing outstanding:** § 1 produced no file changes at all, so there is nothing to harden or ship — find out why the task implemented nothing before running `/forge` again. In every case, `/commit` commits *and pushes* but goes no further: no review, no task update, and it leaves the review directory in place.

## Rules

- **However this skill ends, name the review directory.** Every exit — no actionable task, the plan gate declined, or any of `/polish`'s endings carried into § 4 — names `$(git rev-parse --absolute-git-dir)/review/` if it exists, says whether anything was written to it, and says who deletes it.
- Honor every project Hard Rule and gate (`CLAUDE.md`): plan approval before any file change, at most one task In Progress, and never commit or push without the user's explicit instruction.
- Fix autonomously within the change's scope; escalate anything requiring judgment — the fix policy and escalation gates live in `/polish`.
- Boy-scout fixes stay proportionate and adjacent — never a silent refactor of unrelated code.
- The loop's ceiling and convergence rule are `/polish`'s; the cap never yields to "just one more round."
