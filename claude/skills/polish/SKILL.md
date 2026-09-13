---
name: polish
description: Harden the outstanding change by iterating a strict code review (up to ten rounds) — delegated each round to the code-reviewer agent — fixing everything a strict senior developer would insist on, until two reviews in a row come back clean. Leaves the change reviewed, green, and uncommitted for the user to commit.
disable-model-invocation: true
---

# Polish

Take the change already sitting in the working tree and harden it: loop a strict review — delegated each round to the `code-reviewer` agent — fixing everything a strict senior developer would insist on, until two reviews in a row come back clean or ten review runs are spent. Finish by summarizing every review turn. This skill does not select, plan, or implement work, and it does not touch a task tracker — it operates on whatever is already changed. **Never commit** — the change is left reviewed and green for the user to `/commit`.

## Composed pieces

This skill adds orchestration and a stricter fix policy on top of existing pieces — they remain the single source of truth:

- **Reviewing** is delegated to the `code-reviewer` agent (`~/.claude/agents/code-reviewer.md`), which applies the shared threshold in `~/.claude/skills/review-core.md`. **Spawn it each round via the Agent tool** instead of inlining `/review` — its isolated context absorbs the diff-reading and finding-generation, so ten rounds don't accumulate in this orchestrator's context; you keep only the returned findings. Acting on those findings (fixing, escalating) stays here, where the tools and user gates live.
- **The green-baseline check** — which verification checks to run — comes from `~/.claude/skills/verify-core.md` (shared with `/ship`). This skill's disposition on a red check is to fix the change until it passes.

## Procedure

### 1. Establish a green baseline

Verify the change is sound before reviewing — a review of broken code wastes rounds; get to green first.

Determine and run the verification set per `~/.claude/skills/verify-core.md`. If any check is red, fix the change until all pass before entering the review loop. The loop's re-verify step and the summary refer back to this same set.

### 2. Review loop — up to ten review runs

Convergence requires **two consecutive clean reviews**, not one. A single clean review only provisionally confirms the change; a second review of the unchanged diff guards against a review that missed something or made an inconsistent call. Keep a consecutive-clean counter, starting at 0.

For each review run (1 through 10):

1. **Review.** Spawn the `code-reviewer` agent (via the Agent tool) to review the **outstanding** diff. It gathers the diff, reads every untracked file in full, applies `~/.claude/skills/review-core.md`, and returns the numbered findings — two sections, Issues then Nitpicks, each with a fix — as its final message. State in the prompt that it is reviewing the outstanding changes just implemented/fixed this round. Running it as a subagent keeps the round's diff-reading out of this orchestrator's context — you retain only the findings to act on.

2. **Act on findings — the senior-developer bar.** The `code-reviewer` agent only reports; the fixing is yours. Here you fix autonomously and only escalate genuine judgment calls.
   - **Fix every finding — Issues and Nitpicks alike.** Polish exists to leave nothing a senior developer would still change, so the cosmetic tier gets fixed too, not just the consequential one. Every finding the reviewer returns is a concrete problem with a fix, and by default each one gets fixed this round. (Nitpicks are usually trivial edits — apply them directly; they rarely warrant escalation.)
   - **Scout rule:** also fix related and adjacent problems the review surfaces in the code you touched — including pre-existing ones — when the fix is clear and proportionate. Do not expand into unrelated subsystems or large refactors; that is scope expansion and gets escalated, not done.
   - **Escalate, never guess:** anything that is a genuine trade-off, ambiguous intent, scope expansion, or otherwise *not* resolvable from existing code or documentation goes to the user — this is the one exit for a finding you do not fix directly. Batch all of a round's escalations into a single `AskUserQuestion`, apply the answers, then continue. A decision that *is* determinable from code or docs is resolved autonomously — note the inference in the summary. Record each escalation's outcome: a finding the user directs you to leave as-is is **settled** — do not re-escalate it in later rounds, and it no longer blocks a clean review.
   - Keep documentation aligned as you go (`docs/`, `INDEX.md`, README) — a strict review treats doc drift as a defect, and the reviewer reports it as one.

   A **clean** review has nothing left to act on: no findings — Issue or Nitpick — other than ones already settled this session (a finding the user directed you to leave as-is when it was escalated). A single fresh finding — one not yet fixed or settled — means the review is **not** clean: fix it or escalate it, then reset the counter to 0. Only a review that surfaces nothing but settled findings (or nothing at all) is clean — increment the consecutive-clean counter and go straight to step 4.

3. **Re-verify.** Only when this run applied fixes (a clean run changed nothing): rerun the same verification set settled on in step 1. Fixes must not break any of those checks.

4. **Decide whether to continue.**
   - **Two consecutive clean reviews** (counter reached 2): the change is perfected. Exit the loop.
   - **One clean review** (counter is 1): loop again to run the confirming review — no fixes were applied, so the diff is unchanged.
   - **This run applied fixes or escalations:** the diff changed, so loop again to re-review it.
   - **Ten runs exhausted without two clean reviews in a row:** stop. Do not loop further and do not claim completion — carry the remaining findings into the summary.

Track for each run: the finding count (Issues and Nitpicks), what was auto-fixed, and every escalation with the user's decision. Retain the full finding items of the two converging clean reviews (or, on the cap, the final run) for the summary.

### 3. Summary

Present, in the conversation:

- **Review turns** — one line per round: finding count (Issues and Nitpicks), what was fixed automatically, what was escalated and how the user decided. State whether the loop converged on a clean round or hit the ten-round cap with N findings still open (list them).
- **Last review** — list the items from **both** consecutive clean reviews that ended the loop, grouped by run and labelled (e.g. "Run 5", "Run 6"), one condensed line each (category tag, file:line, and the gist — enough to recognize the finding, not the full explanation/fix block). A clean review carries only settled findings (ones the user directed you to leave as-is) or nothing at all — say "nothing" for any run that returned nothing. Do not collapse them into a verdict or a count; the point is for the user to see exactly what each converging review surfaced and confirm they agree the loop was right to stop. If the ten-run cap was hit without two clean reviews in a row, list instead the final run's items and mark which remain unaddressed.
- **Verification** — the final state of each check in the verification set from step 1 (name them and their pass/fail state).
- **Next step** — the change is reviewed and green; the user runs `/commit` when satisfied.

## Rules

- Fix autonomously within the change's scope; escalate anything requiring judgment. When in doubt whether a decision is inferable, ask.
- Boy-scout fixes stay proportionate and adjacent — never a silent refactor of unrelated code.
- The loop's hard ceiling is ten review runs. Convergence (two clean reviews in a row) ends it sooner; the cap never yields to "just one more run."
- **Never commit or push.** The change is left In Review for the user to `/commit`.
