---
name: forge
description: Pick the next task, implement it, then iterate a strict code review until the change is perfected — leaving it reviewed and ready for the user to commit.
disable-model-invocation: true
---

# Forge

Take one work item from selection all the way to a review-hardened change: run the `/next` workflow to pick, plan, and implement a task, then hand the result to `/polish` to loop a strict review — fixing everything a strict senior developer would insist on — until it converges. Finish by moving the task to In Review and summarizing the change and every review turn. **Never commit** — the change is left In Review for the user to `/commit`.

## Argument

An optional argument may follow the command: `$ARGUMENTS`. When present, it is a hint (task ID, filename, or descriptive text) forwarded to the `/next` selection step. When absent, `/next` picks the first task by its source's order.

## Composed pieces

This skill only adds orchestration on top of existing pieces — they remain the single source of truth:

- **Selection, planning, implementation** come from `/next` (`~/.claude/skills/next/SKILL.md`), which owns the plan-approval gate and other user interactions. A subagent can't run those gates, so **read and follow that `SKILL.md` directly** in this (main-loop) context. It sets `disable-model-invocation: true`, so it can't be invoked through the Skill tool anyway.
- **The review+fix loop** comes from `/polish` (`~/.claude/skills/polish/SKILL.md`): it establishes a green baseline, then loops the `code-reviewer` agent with a strict fix policy until 2 consecutive clean reviews or 10 runs. `/forge` follows it with no arguments, so polish's defaults (N=10, M=2) apply. It owns user gates too (batched escalations), so **read and follow that `SKILL.md` directly** in this (main-loop) context. It also sets `disable-model-invocation: true`.

## Procedure

### 1. Select, plan, implement

Follow `~/.claude/skills/next/SKILL.md`, treating this skill's argument as its `$ARGUMENTS`.

- The plan-mode gate is a **hard user gate** (project Hard Rule 3): surface the plan and wait for the user's `ExitPlanMode` approval. Do not modify any file before approval. The plan's own first step is its Backlog bookkeeping (record the plan, move the task to In Progress, self-assign) — verify it is present, as the plan-gate hook requires.
- Before implementing, record the baseline (`git status` and `git rev-parse HEAD`) so the final summary can describe exactly what changed.
- Once approved, implement the plan.

If `/next` finds no actionable task, report that and stop.

### 2. Harden the change

Follow `~/.claude/skills/polish/SKILL.md` on the change just implemented: it establishes a green baseline and runs the review+fix loop (up to 10 runs, converging on 2 consecutive clean reviews — polish's defaults, since `/forge` passes no arguments). Retain its per-run tracking and the items of the converging clean reviews — the final summary below folds them in. Its fix policy, escalation gates, and re-verification are authoritative; do not duplicate or override them here.

### 3. Finish — project Review gate, no commit

Follow the project's Review gate (`docs/process/task-workflow.md`): verify each acceptance criterion and Definition-of-Done item against objective evidence, check them off (`backlog task edit --check-ac` / `--check-dod`), append a review summary note (`--append-notes`), and move the task to In Review.

Do **not** write the final summary to the task, move it to Done, or commit — those belong to the Finish gate, which the user triggers with `/commit` (Hard Rule 4).

### 4. Summary

Present, in the conversation:

- **Change** — the task worked, and a concise description of the code changes (files and areas touched).
- **Review turns** — one line per round, from `/polish`: finding count (Issues and Nitpicks), what was fixed automatically, what was escalated and how the user decided. State whether the loop converged on a clean round or hit the iteration cap with findings still open (list them).
- **Last review** — list the items from both consecutive clean reviews that ended the loop, grouped by run and labelled (e.g. "Run 5", "Run 6"), one condensed line each (category tag, file:line, and the gist — enough to recognize the finding, not the full explanation/fix block). A clean review carries only settled findings (ones the user directed you to leave as-is) or nothing at all — say "nothing" for any run that returned nothing. Do not collapse them into a verdict or a count; the point is for the user to see exactly what each converging review surfaced and confirm they agree the loop was right to stop. If the iteration cap was hit without 2 consecutive clean reviews, list instead the final run's items and mark which remain unaddressed.
- **Verification** — the final state of each check in `/polish`'s verification set (name them and their pass/fail state).
- **Next step** — the task is In Review; the user runs `/commit` when satisfied.

## Rules

- Honor every project Hard Rule and gate (`CLAUDE.md`): plan approval before any file change, at most one task In Progress, and never commit or push without the user's explicit instruction.
- Fix autonomously within the change's scope; escalate anything requiring judgment — the fix policy and escalation gates live in `/polish`.
- Boy-scout fixes stay proportionate and adjacent — never a silent refactor of unrelated code.
- The loop's hard ceiling is 10 review runs. Convergence (2 consecutive clean reviews) ends it sooner; the cap never yields to "just one more run."
