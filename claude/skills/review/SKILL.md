---
name: review
description: Review all outstanding changes — or, when the working tree is clean on a non-main branch, the branch's diff from the main branch — with a fanned-out set of parallel reviewers (area slices plus claims/tests/contracts/ux/security lenses as the change warrants), then interactively fix the findings the user picks, by class, and check the fixes before finishing. Findings are split into Issues (consequential) and Nitpicks (cosmetic).
disable-model-invocation: true
---

# Code Review

Produce one complete review of the changes under review, let the user pick which findings to fix, fix them properly, and confirm the fixes introduced nothing new. Finding-generation is fanned out to parallel `code-reviewer` agents; this skill owns the plan, the interaction and the fixing.

## Composed pieces

- **Reviewing** follows `~/.claude/skills/review-fanout.md` in **full** mode: prepare the diff once, plan area and lens reviewers, run them in parallel, verify coverage, merge. The bar is `~/.claude/skills/review-core.md`.
- **Fixing** follows `~/.claude/skills/review-fix.md`: confirm each finding, fix the whole class, pin behaviour with tests, then re-verify (`~/.claude/skills/verify-core.md`) and run a delta check.
- **Ledger:** `review-fanout.md` § *The review ledger* — the per-worktree file at `$(git rev-parse --absolute-git-dir)/review/ledger.md` that every reviewer reads, written here for settled findings, rejected findings, and the decisions its escalations produce. It belongs to this one change; entries left in it suppress matching findings in any delta-mode round, and in every review of a change made on the same `HEAD`.

## Workflow

1. **Review.** Run the fan-out in full mode. Do not narrow the scope — `review-diff.sh` picks outstanding vs. branch mode. If it reports `MODE: none`, there is nothing to review: say so and stop (no run directory was created, but an earlier ledger may still be there — see the Rules).

2. **Present the findings.** Relay the merged findings **verbatim** — Issues then Nitpicks, one continuous numbering, each with its fix — followed by the one-line plan and coverage. The numbers are the user's selection handles; do not renumber, summarize or drop any. If the review is clean and complete, say so and stop. If it is incomplete (a reviewer never finished), say which role is missing, present what the completed roles found, and tell the user the list is partial — they can act on it, but re-run `/review` afterwards if they want the missing slice covered.

3. **Ask which findings to fix.** Both sections are selectable. Do not modify any code yet — wait for the reply. The full numbered list is already on screen above, so do not restate it; prompt with a short line like: `Which to fix? (e.g. 1b, 2, 3a, 5 (with the database), 6, 8 — or "all")`.

   Expect free text naming findings by number, optionally with a fix-option letter and/or a parenthetical hint:
   - `2` — fix finding 2 (the only fix, or option `a.` if there are several).
   - `3a` — fix finding 3 using option `a.`.
   - `5 (with the database)` — the parenthetical is the user's steer on how; honor it.
   - Ranges (`3–6`), lists, and `all` / `all nitpicks` / `all issues`.

   A bare "nothing", "none" or similar → end without changing anything and without writing to the ledger; declining to act on a review now is not a decision to suppress it forever. Only findings the user names as ones to leave ("fix 2 and 3, leave 5") get a `settled:` entry — stamped with `base=` the `FROM` from `meta.txt`, so in outstanding mode it expires the moment the change is committed. In branch mode it is shorter-lived than that reads: applying this run's fixes makes the tree dirty, so the next review is outstanding mode with a different `FROM` and the entry is already expired — and the merge-base moves as soon as the branch is rebased onto or merged with an advanced `main`. Tell the user that leaving a finding in branch mode holds for this run only.

4. **Fix the picked findings** per `review-fix.md`. Before the first edit, determine and run the verification set per `verify-core.md`, so a check that was already red is reported as pre-existing rather than blamed on the fixes. Then snapshot and **confirm every picked finding first**, before fixing any of them — that is what makes the escalation below a single batch rather than a series of interruptions. Then, for each, fix every instance of its root cause, add or tighten tests for behaviour changes, write comment/doc wording yourself. With several options and no letter or hint, apply `a.` and say so; if the user's parenthetical hint matches none of the listed options, follow the hint directly and say what you did. A picked finding that turns out to be wrong is rejected (recorded in the ledger), not applied. A judgment call the confirmation surfaces — a fix that would reverse an earlier decision, or one that turns out to need work outside the change's scope — goes back to the user rather than being decided here; ask about the batch of them in one prompt before fixing.

5. **Check the fixes.** Re-run that same verification set, then the delta check from `review-fix.md`. Fix what the delta check finds (same rules) — this is part of the fixes the user asked for, not new scope. If a delta finding is a genuine judgment call, ask instead. If nothing was applied, there is nothing to check.

6. **Summarize.** What was fixed (with the extra locations each class sweep found), what was rejected and why, the delta check's result, and the verification state — naming any check that was already red before the fixes, so it is not mistaken for damage they did. Then say where things stand: nothing is committed — `/ship` next, or `/commit`, which commits *and pushes* but does no review and no task update. Say what became of the findings the user did not pick: those they explicitly asked to leave were recorded as `settled:` and will not be re-raised, but any they simply did not mention still stand — `/ship` will block on every Issue and `(defect)` Nitpick among them. End with the **Ledger** line the rule below requires, which is genuinely the last thing printed.

## Rules

- All rules from `review-core.md` apply to the findings.
- Only fix findings the user picked (plus problems the delta check finds in those fixes) — never others.
- **However this skill ends, name the review directory.** Every exit — a `MODE: none` stop, a clean review, a "none" reply, an incomplete review, or a finished fix pass — has already run `review-diff.sh`, which leaves `$(git rev-parse --absolute-git-dir)/review/` behind except on `MODE: none`, and a ledger from an earlier round may be sitting there regardless. So every exit ends with a **Ledger** line: the path, any entries this run appended, and that only `/ship` deletes the directory (after it pushes) — so the user should delete it themselves after a hand `/commit` or if the change is abandoned. Ledger entries suppress matching findings in any delta-mode round, and in every review of a change made on the same `HEAD`; neither the writes nor the file itself is ever left unmentioned.
- Never commit.
