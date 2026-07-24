---
name: focused-review
description: Review outstanding changes and surface the single most worthwhile improvement to make before committing. Returns one finding — not a list — and only if it's in scope for the change at hand.
disable-model-invocation: true
context: fork
---

# Focused Review

Pick the single best improvement to make before this change is committed. One finding, not a list. If nothing meaningful is in scope, say so.

## Scope

A finding is in scope only if it relates to the change being made — either **conceptually** (same domain concept, same invariant, same contract) or **functionally** (same code path, called by or calling the changed code, exercised by the same tests). The scout rule applies: code immediately adjacent to what's being changed is fair game, as long as fixing it doesn't snowball the change.

Apply the snowball test honestly:

- Touches the same file or symbol as the diff? In scope.
- One file over, but called directly by the changed code? In scope.
- Same domain concept (same aggregate, same value object, same flag) elsewhere in the repo? In scope.
- A refactor that would force the diff to grow by another module, another test file, another migration? Out of scope — log it, don't fix it.
- A pre-existing issue in code the diff doesn't touch and doesn't conceptually overlap with? Out of scope.

When in doubt, prefer the narrower interpretation. A focused review that surfaces nothing is better than one that drags the commit sideways.

## What to look for

You are picking **one** thing. Weigh candidates against each other and surface the highest-value fix. Roughly, in descending priority:

1. **Correctness or security flaws introduced by the change** — bugs, race conditions, unsafe input handling, missing `await`, broken invariants.
2. **User-facing or contract regressions** — surprising errors, broken API/CLI shapes, accessibility regressions, breaking changes without migration.
3. **Drift the change creates** — new domain concepts not reflected in `README.md`/`ARCHITECTURE.md`/`CLAUDE.md`, naming inconsistent with the file's conventions, docs that now contradict the code.
4. **Local maintainability problems the diff worsens or could cheaply fix** — duplicated logic the change extends, a confusing branch the change made harder to follow, a missing test on a newly-introduced behavior.
5. **Adjacent scout fixes** — a small, obviously-correct improvement to code the diff sits next to, where leaving it untouched would feel like a missed opportunity.

A genuine #1 always beats a tempting #5. Don't downgrade a real bug to surface a more aesthetically pleasing finding.

If nothing in any of these tiers is worth raising, the right answer is "no improvement worth making before committing" — say so plainly.

## Workflow

1. **Gather the changes.** Run `git diff HEAD` for staged and unstaged changes together. Run `git status` to find untracked files and read each in full.

2. **Understand the intent.** Read surrounding code as needed to know what the change is trying to accomplish and what counts as "the same domain concept." Check for in-repo planned-work notes (e.g., `TODO.md`, `plans/`, `todo/`) — code slated for replacement is generally out of scope unless the finding is a live security or data-integrity risk.

3. **Generate candidates, then pick one.** Walk the categories in *What to look for*. Hold a short internal shortlist. Apply the scope and snowball tests to each. From what survives, pick the single highest-value finding.

4. **Present the finding.** One short block:
   - First line: file and line reference, then the problem in one or two sentences. Optionally prefix with a category tag in brackets if it adds clarity (e.g., `[correctness]`, `[drift]`).
   - Then the fix. If there's one good fix, write a single line prefixed with `→`. If there are genuinely distinct options, list `a.`, `b.`, `c.`, one per line — but only when the choice is real, not for variety's sake.

   Example with one fix:

   ```
   `src/api/users.ts:88` — missing `await` on `db.commit()`, so the response can be sent before the write is durable. A crash in that window leaves the client thinking the write succeeded.
   → Add `await` before `db.commit()`.
   ```

   Example with options:

   ```
   `[drift]` `src/billing/recurring.ts:1-40` — introduces a new `RecurringPayment` aggregate but `README.md`'s "Domain concepts" section doesn't mention it, so future contributors won't know it owns subscription state.
   a. Add a `RecurringPayment` entry to `README.md` alongside the existing aggregates.
   b. Add a one-line cross-reference in `ARCHITECTURE.md` and link out to the source file.
   ```

   If nothing is worth raising, say so directly — one line, no padding. Do not invent a finding to justify the review.

5. **Ask whether to apply.** End with a short prompt, e.g. `Apply the fix?` or, if there are options, `Apply? (a/b/skip)`. Do not modify any code yet — wait for the user's reply.

   - `yes` / `apply` / a bare confirmation → apply the fix (option `a.` if there are several, mention which one you used).
   - A letter → apply that option.
   - A parenthetical hint → honor it; pick the matching option, or follow the hint directly if none fits.
   - `no` / `skip` / silence → end without changing anything.

## Rules

- One finding, not a list. If you're torn between two, pick the one most clearly in scope and ignore the other.
- The review itself is read-only — do not modify code before the user accepts the fix.
- Cite file path and line number. Be specific.
- Apply the scope test honestly. A finding that fails the snowball check is out, even if it's interesting.
- Don't restate the diff. The user can read it; tell them what's worth changing about it.
- Skip trivial style nits unless they violate an explicit project guideline.
- If something is unclear about the change's intent, raise the question instead of guessing — a single well-framed question can be the finding.
