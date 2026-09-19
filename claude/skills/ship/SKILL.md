---
name: ship
description: Gate the outstanding change on verification (lint/tests/build must be green) and then a code review — delegated to the code-reviewer agent — and, only if both pass, commit it via /commit and advance its task to its terminal state (where the source has one). A red check, any Issue, or a defect-level Nitpick stops the ship and flags it; preference-level polish rides along as advisory and does not block. The counterpart to /forge on the far side of the commit boundary.
disable-model-invocation: true
---

# Ship

Take the change already sitting in the working tree and send it out the door — but only if it passes two gates first. First **verify** it is green (lint, tests, build); reviewing or shipping broken code is pointless. Then **review** it, delegated to the `code-reviewer` agent. If verification is red, or the review surfaces a **blocking finding** — any Issue, or a Nitpick marked `(defect)` (cosmetic but *wrong*) — **stop and flag it**; do not fix, do not commit. A green change whose only review findings are `(preference)` polish passes through to `/commit` — those nits ride along as advisory rather than blocking — after which the associated task is advanced to its Done/terminal state.

This is the automated far half of your workflow: `/forge` selects, implements, review-hardens, and leaves a task **In Review**; `/ship` re-checks quality at the last moment, commits, and closes the task out. It is a **gate and a finalizer, not a fixer** — when it stops, fixing is the user's call (`/polish`, manual edits, etc.). Its bar is deliberately narrower than `/polish`'s: `/polish` sweeps *every* improvement including preferences, so that `/ship` — re-reviewing a possibly freshly-polished diff — gates only on what is genuinely *wrong* and does not re-block over a fresh preference-level nit the non-deterministic reviewer happens to surface. The independent re-review still earns its keep: it catches real defects (including ones a prior `/polish` round missed on the same diff) that must not ship.

## Composed pieces

This skill only adds orchestration on top of existing pieces — they remain the single source of truth:

- **The green-baseline check** — which verification checks to run — comes from `~/.claude/skills/verify-core.md` (shared with `/polish`). This skill's disposition on a red check is to stop the ship, not to fix.
- **Reviewing** is delegated to the `code-reviewer` agent (`~/.claude/agents/code-reviewer.md`), which applies the shared threshold in `~/.claude/skills/review-core.md`. **Spawn it via the Agent tool with `model: "opus"`** — do not inline `/review`, which is interactive (it asks "which to fix?" and then modifies code); `/ship` needs a non-interactive verdict and never fixes. Its isolated context absorbs the diff-reading; you keep only the returned findings to decide the gate.
- **Committing** comes from `/commit` (`~/.claude/skills/commit/SKILL.md`): it groups the outstanding changes into atomic Conventional Commits, pushes, and rebases on a rejected push. It sets `disable-model-invocation: true`, so it can't be invoked through the Skill tool — **read and follow that `SKILL.md` directly** in this (main-loop) context.
- **Task lifecycle** — `/commit` is deliberately barred from the tracker, and `/forge` defers moving a task to Done to the project's **Finish gate**. `/ship` *is* that gate: after a successful commit it advances the task per the project's documented lifecycle, generically over the work-item source (the same sources `/next` enumerates).

## Procedure

### 1. Precondition — there must be something to ship

Run `git status`. If there are no outstanding changes, there is nothing to commit — tell the user and stop. (`/ship` gates and commits the *outstanding* change; it does not review a clean branch diff the way `/review` does.)

### 2. Verification gate — get to green first

Reviewing or shipping broken code is pointless. Before the review, determine and run the verification set per `~/.claude/skills/verify-core.md`.

- **Any check red → stop and flag.** Report which checks failed and their output; do **not** review, commit, or touch the task tracker. Getting the change green is the user's call (fix it, or run `/polish`, then `/ship` again). This is a normal, expected exit — not a failure of the skill.
- **All green → proceed to step 3.**

### 3. Review gate — one review, defect bar

Spawn the `code-reviewer` agent (via the Agent tool with `model: "opus"`) to review the **outstanding** diff. It gathers the diff, reads every untracked file in full, applies `~/.claude/skills/review-core.md`, and returns the numbered findings — two sections, Issues then Nitpicks, each carrying a `(defect)` / `(preference)` marker and a fix — as its final message.

A single review is sufficient: unlike `/polish`, this skill does not mutate the diff between rounds, so there is no changed diff to re-review and no need for `/polish`'s consecutive-clean convergence rule.

**Evaluate with the defect bar.** `/ship` gates on what is *wrong*, not on taste. A finding is **blocking** if it is any **Issue**, or a **Nitpick marked `(defect)`** (cosmetic but wrong — a malformed string, an off-by-one, a comment that misstates the code). A finding is **non-blocking** if it is a **Nitpick marked `(preference)`** (a genuine but lateral improvement — extract a helper, rename, reorder). This deliberately differs from `/polish`, whose job is to sweep preferences too; `/ship` is a correctness gate, not a second taste pass, so it will not re-block a freshly-polished change over a fresh preference-level nit. (An Issue always blocks regardless of its marker — Issues are consequential by definition, so err toward blocking.)

- **Any blocking finding → stop and flag.** Present the agent's findings verbatim (both sections, one continuous numbering, *including* the `(preference)` Nitpicks so the picture is complete) and halt. Do **not** fix anything, do **not** commit, do **not** touch the task tracker. Close with a short line telling the user the ship is blocked on the defect(s) and that fixing is theirs to drive (e.g. run `/polish` to loop the fix-review cycle, or fix directly, then `/ship` again). This is the skill's normal, expected exit — not a failure.
- **No blocking findings → proceed to step 4.** If the review surfaced only `(preference)` Nitpicks, they ride along unfixed as advisory — carry them into the summary; do not fix them here (that is `/polish`'s job).

### 4. Commit

The review surfaced no blocking findings. Commit the change by following `~/.claude/skills/commit/SKILL.md` end to end — atomic Conventional Commits, then push (with its fetch-rebase-retry handling on a rejected push). Honor its rules: never `git add -A`/`.`, never amend, never bypass a failing pre-commit hook — if a hook fails, stop and report, and do **not** proceed to the task step (nothing shipped).

### 5. Finish gate — advance the task

Only after the commit **and push** succeed. Determine whether the change corresponds to a task in the project's work-item source (the sources `/next` enumerates: `TODO.md`, a per-task-file directory, a Backlog.md board, or an MCP issue tracker). If the project documents a task lifecycle (e.g. `docs/process/task-workflow.md`, CLAUDE.md, Backlog instructions), **follow its Finish gate exactly** — typically: append a final summary note to the task and move it to its terminal state (Done / closed).

- **Backlog.md board** — `backlog task edit <id> --append-notes "…"` then `-s Done`, per the project's documented lifecycle.
- **Issue tracker (MCP)** — transition the issue to its done/closed state.
- **`TODO.md` / per-task file** — these are typically already cleared by `/next` when the task was implemented; only act if the project's lifecycle says otherwise.

If no task is associated, or the source is ambiguous, say so and skip this step rather than guessing — do not invent or move an unrelated task.

### 6. Summary

Present, in the conversation:

- **Verification** — the final pass/fail state of each check in the verification set (named).
- **Gate** — passed (shipped) or blocked. If blocked, the blocking findings (Issues and `(defect)` Nitpicks) with their count. Either way, list any `(preference)` Nitpicks that were surfaced — on a pass they rode along as advisory and were **not** fixed; note them so the user can pick them up (e.g. via `/polish`) if they want.
- **Commits** — when shipped, the `git log --oneline` of the new commits and whether the push succeeded (or diverged and needs manual resolution, per `/commit`).
- **Task** — the task advanced to its terminal state, or a note that none applied / it was skipped.
- **Remaining steps** — anything that still has to happen before the work is *actually* done, beyond the code that just shipped. Draw from this conversation's main context and the nature of the change itself. For each item, say plainly **what** must happen and **who/where** (you vs. the user vs. another system). This list is the whole reason `/ship` runs in main context rather than being delegated — surface it prominently. If there is genuinely nothing left, say so explicitly ("Nothing outstanding — the shipped commit completes the work") rather than omitting the section.
  - **Blocking** — must happen before the change is safe/complete (e.g. run the migration before this deploys, configure the required secret).
  - **Follow-up** — should happen but doesn't block (e.g. file a ticket for the deferred refactor, update docs elsewhere).

## Rules

- **Defect bar.** Any Issue, or any Nitpick marked `(defect)`, blocks the ship. `(preference)` Nitpicks do **not** block — they are reported as advisory and left for `/polish` or the user. This is the one place the workflow's bars deliberately differ: `/polish` fixes preferences, `/ship` won't block on them (but still blocks on anything genuinely wrong, including a cosmetic defect).
- **Never fix.** `/ship` is a gate; on any blocking finding it stops and flags, and it never fixes even the preference-level nits it lets ride. Fixing is the user's decision (`/polish` or manual).
- **Order is fixed:** verify → (green) → review → (no blocking findings) → commit+push → advance task. Never review broken code, never commit while a defect stands, never advance the task before the commit lands.
- Honor every project Hard Rule and gate (`CLAUDE.md`); the task step follows the project's documented Finish gate.
