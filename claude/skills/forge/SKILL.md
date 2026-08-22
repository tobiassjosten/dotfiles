---
name: forge
description: Pick the next task, implement it, then iterate a strict code review (up to seven rounds) until the change is perfected — leaving it reviewed and ready for the user to commit.
disable-model-invocation: true
---

# Forge

Take one work item from selection all the way to a review-hardened change: run the `/next` workflow to pick, plan, and implement a task, then loop a strict review — delegated each round to the `code-reviewer` agent — fixing everything a strict senior developer would insist on, until a review comes back clean or seven rounds are spent. Finish by summarizing the change and every review turn. **Never commit** — the change is left In Review for the user to `/commit`.

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

### 3. Review loop — up to seven rounds

For each round (1 through 7):

1. **Review.** Spawn the `code-reviewer` agent (via the Agent tool) to review the **outstanding** diff. It gathers the diff, reads every untracked file in full, applies `~/.claude/skills/review-core.md`, and returns the numbered findings (Issues, Notes, Documentation) as its final message. State in the prompt that it is reviewing the outstanding changes just implemented/fixed this round. Running it as a subagent keeps the round's diff-reading out of this orchestrator's context — you retain only the findings to act on.

2. **Act on findings — the senior-developer bar.** The `code-reviewer` agent only reports; the fixing is yours. Here you fix autonomously and only escalate genuine judgment calls.
   - **Fix every Issue.**
   - **Fix Notes that have an unambiguous, low-risk fix** — dead code, duplication, doc/README/INDEX drift, missing tests on changed behavior, naming inconsistencies, and the like.
   - **Scout rule:** also fix related and adjacent problems the review surfaces in the code you touched — including pre-existing ones — when the fix is clear and proportionate. Do not expand into unrelated subsystems or large refactors; that is scope expansion and gets escalated, not done.
   - **Escalate, never guess:** anything that is a genuine trade-off, ambiguous intent, scope expansion, or otherwise *not* resolvable from existing code or documentation goes to the user. Batch all of a round's escalations into a single `AskUserQuestion`, apply the answers, then continue. A decision that *is* determinable from code or docs is resolved autonomously — note the inference in the summary.
   - Keep documentation aligned as you go (`docs/`, `INDEX.md`, README) — a strict review treats doc drift as a defect.

3. **Re-verify.** Rerun the mandated verification from step 2. Fixes must not break lint, tests, build, mutation, or size checks.

4. **Decide whether to continue.**
   - **Clean round** — no Issues and no actionable Notes (nothing to fix, nothing to escalate): the change is perfected. Exit the loop.
   - **Otherwise** — fixes or escalated decisions were applied this round: the diff changed, so loop again to re-review it.
   - **Round 7 exhausted with findings remaining:** stop. Do not loop further and do not claim completion — carry the remaining findings into the summary.

Track for each round: the findings count (Issues / Notes), what was auto-fixed, and every escalation with the user's decision.

### 4. Finish — project Review gate, no commit

Follow the project's Review gate (`docs/process/task-workflow.md`): verify each acceptance criterion and Definition-of-Done item against objective evidence, check them off (`backlog task edit --check-ac` / `--check-dod`), append a review summary note (`--append-notes`), and move the task to In Review.

Do **not** write the final summary to the task, move it to Done, or commit — those belong to the Finish gate, which the user triggers with `/commit` (Hard Rule 4).

### 5. Summary

Present, in the conversation:

- **Change** — the task worked, and a concise description of the code changes (files and areas touched).
- **Review turns** — one line per round: findings count, what was fixed automatically (Issues and Notes), what was escalated and how the user decided. State whether the loop converged on a clean round or hit the seven-round cap with N findings still open (list them).
- **Verification** — the final state of lint, test, build, mutation, and size checks.
- **Next step** — the task is In Review; the user runs `/commit` when satisfied.

## Rules

- Honor every project Hard Rule and gate (`CLAUDE.md`): plan approval before any file change, at most one task In Progress, and never commit or push without the user's explicit instruction.
- Fix autonomously within the change's scope; escalate anything requiring judgment. When in doubt whether a decision is inferable, ask.
- Boy-scout fixes stay proportionate and adjacent — never a silent refactor of unrelated code.
- The loop's hard ceiling is seven review rounds. Convergence (a clean round) ends it sooner; the cap never yields to "just one more round."
