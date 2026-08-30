---
name: forge
description: Pick the next task, implement it, then iterate a strict code review (up to seven rounds) until the change is perfected — leaving it reviewed and ready for the user to commit.
disable-model-invocation: true
---

# Forge

Take one work item from selection all the way to a review-hardened change: run the `/next` workflow to pick, plan, and implement a task, then loop a strict review — delegated each round to the `code-reviewer` agent — fixing everything a strict senior developer would insist on, until two reviews in a row come back clean or seven review runs are spent. Finish by summarizing the change and every review turn. **Never commit** — the change is left In Review for the user to `/commit`.

## Argument

An optional argument may follow the command: `$ARGUMENTS`. When present, it is a hint (task ID, filename, or descriptive text) forwarded to the `/next` selection step. When absent, `/next` picks the first task by its source's order.

## Composed pieces

This skill only adds orchestration and a stricter fix policy on top of existing pieces — they remain the single source of truth:

- **Selection, planning, implementation** come from `/next` (`~/.claude/skills/next/SKILL.md`), which owns the plan-approval gate and other user interactions. A subagent can't run those gates, so **read and follow that `SKILL.md` directly** in this (main-loop) context. It sets `disable-model-invocation: true`, so it can't be invoked through the Skill tool anyway.
- **Reviewing** is delegated to the `code-reviewer` agent (`~/.claude/agents/code-reviewer.md`), which applies the shared threshold in `~/.claude/skills/review-core.md`. **Spawn it each round via the Agent tool** instead of inlining `/review` — its isolated context absorbs the diff-reading and finding-generation, so seven rounds don't accumulate in this orchestrator's context; you keep only the returned findings. Acting on those findings (fixing, escalating) stays here, where the tools and user gates live.

## Procedure

### 1. Select, plan, implement

Follow `~/.claude/skills/next/SKILL.md`, treating this skill's argument as its `$ARGUMENTS`.

- The plan-mode gate is a **hard user gate** (project Hard Rule 3): surface the plan and wait for the user's `ExitPlanMode` approval. Do not modify any file before approval. The plan's own first step is its Backlog bookkeeping (record the plan, move the task to In Progress, self-assign) — verify it is present, as the plan-gate hook requires.
- Before implementing, record the baseline (`git status` and `git rev-parse HEAD`) so the final summary can describe exactly what changed.
- Once approved, implement the plan.

If `/next` finds no actionable task, report that and stop.

### 2. Establish a green baseline

Run the project's mandated verification (per `CLAUDE.md`): `make lint`, `make test`, `go build -o /dev/null ./...`, `make lint-size`, and — for Go changes — `make mutate`. Rerun `make install` if anything under `application/lumus/` changed. A review of broken code wastes rounds; get to green before reviewing.

### 3. Review loop — up to seven review runs

Convergence requires **two consecutive clean reviews**, not one. A single clean review only provisionally confirms the change; a second review of the unchanged diff guards against a review that missed something or made an inconsistent call. Keep a consecutive-clean counter, starting at 0.

For each review run (1 through 7):

1. **Review.** Spawn the `code-reviewer` agent (via the Agent tool) to review the **outstanding** diff. It gathers the diff, reads every untracked file in full, applies `~/.claude/skills/review-core.md`, and returns the numbered findings (Issues, Notes, Documentation) as its final message. State in the prompt that it is reviewing the outstanding changes just implemented/fixed this round. Running it as a subagent keeps the round's diff-reading out of this orchestrator's context — you retain only the findings to act on.

2. **Act on findings — the senior-developer bar.** The `code-reviewer` agent only reports; the fixing is yours. Here you fix autonomously and only escalate genuine judgment calls.
   - **Fix every Issue.**
   - **Fix every Note by default — nothing below the Issue bar gets a pass.** `review-core.md` writes Notes for a generic reviewer who must weigh each fix against the cost of disturbing otherwise-untouched code, so many are phrased as deferrals ("worth consolidating next time this area is touched," "a one-word tweak next time this file is touched"). In forge that deferral has already come due: the file *is* being touched this round, so the cost the Note was waiting on is already paid. Treat every "next time this is touched," "worth doing later," or "minor" as "do it now." A Note is left unfixed **only** when one of the two rules below removes it — never because it seemed too small to bother with.
   - **Scout rule:** also fix related and adjacent problems the review surfaces in the code you touched — including pre-existing ones — when the fix is clear and proportionate. Do not expand into unrelated subsystems or large refactors; that is scope expansion and gets escalated, not done.
   - **Escalate, never guess:** anything that is a genuine trade-off, ambiguous intent, scope expansion, or otherwise *not* resolvable from existing code or documentation goes to the user — this is the one exit for a Note you do not fix. Batch all of a round's escalations into a single `AskUserQuestion`, apply the answers, then continue. A decision that *is* determinable from code or docs is resolved autonomously — note the inference in the summary. Record each escalation's outcome: a Note the user declines to fix is **settled** — do not re-escalate it in later rounds, and it no longer blocks a clean review.
   - Keep documentation aligned as you go (`docs/`, `INDEX.md`, README) — a strict review treats doc drift as a defect.

   A **clean** review has nothing left to act on: no Issues, and no Notes other than ones already settled this session (a Note the user declined to fix when it was escalated). Because the default is to fix every Note, a single fresh Note — one not yet fixed or settled — means the review is **not** clean: fix it or escalate it, then reset the counter to 0. Only a review that surfaces nothing but settled Notes (or nothing at all) is clean — increment the consecutive-clean counter and go straight to step 4.

3. **Re-verify.** Only when this run applied fixes (a clean run changed nothing): rerun the mandated verification from step 2. Fixes must not break lint, tests, build, mutation, or size checks.

4. **Decide whether to continue.**
   - **Two consecutive clean reviews** (counter reached 2): the change is perfected. Exit the loop.
   - **One clean review** (counter is 1): loop again to run the confirming review — no fixes were applied, so the diff is unchanged.
   - **This run applied fixes or escalations:** the diff changed, so loop again to re-review it.
   - **Seven runs exhausted without two clean reviews in a row:** stop. Do not loop further and do not claim completion — carry the remaining findings into the summary.

Track for each run: the findings count (Issues / Notes), what was auto-fixed, and every escalation with the user's decision. Retain the full Issue/Note items of the two converging clean reviews (or, on the cap, the final run) for the summary.

### 4. Finish — project Review gate, no commit

Follow the project's Review gate (`docs/process/task-workflow.md`): verify each acceptance criterion and Definition-of-Done item against objective evidence, check them off (`backlog task edit --check-ac` / `--check-dod`), append a review summary note (`--append-notes`), and move the task to In Review.

Do **not** write the final summary to the task, move it to Done, or commit — those belong to the Finish gate, which the user triggers with `/commit` (Hard Rule 4).

### 5. Summary

Present, in the conversation:

- **Change** — the task worked, and a concise description of the code changes (files and areas touched).
- **Review turns** — one line per round: findings count, what was fixed automatically (Issues and Notes), what was escalated and how the user decided. State whether the loop converged on a clean round or hit the seven-round cap with N findings still open (list them).
- **Last review** — list the items from **both** consecutive clean reviews that ended the loop, grouped by run and labelled (e.g. "Run 5", "Run 6"), one condensed line each (category tag, file:line, and the gist — enough to recognize the finding, not the full explanation/fix block). A clean review carries only settled Notes (ones the user declined to fix) or nothing at all — say "nothing" for any run that returned nothing. Do not collapse them into a verdict or a count; the point is for the user to see exactly what each converging review surfaced and confirm they agree the loop was right to stop. If the seven-run cap was hit without two clean reviews in a row, list instead the final run's items and mark which remain unaddressed.
- **Verification** — the final state of lint, test, build, mutation, and size checks.
- **Next step** — the task is In Review; the user runs `/commit` when satisfied.

## Rules

- Honor every project Hard Rule and gate (`CLAUDE.md`): plan approval before any file change, at most one task In Progress, and never commit or push without the user's explicit instruction.
- Fix autonomously within the change's scope; escalate anything requiring judgment. When in doubt whether a decision is inferable, ask.
- Boy-scout fixes stay proportionate and adjacent — never a silent refactor of unrelated code.
- The loop's hard ceiling is seven review runs. Convergence (two clean reviews in a row) ends it sooner; the cap never yields to "just one more run."
