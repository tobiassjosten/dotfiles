---
name: review
description: Review all outstanding changes. Reports Issues (anything that could cause user problems, security risk, or data inconsistency) and optional Notes for further improvement.
disable-model-invocation: true
---

# Code Review

Review all outstanding changes against a fixed threshold. The aim is a bounded, useful review — not an open-ended hunt for things to flag.

## Threshold

A finding is reported as an **Issue** only if, on its own, it could plausibly cause one of these outcomes:

- **User problems** — confusion, frustration, surprise, or broken expectations for a real user, operator, or downstream caller.
- **Security risk** — exploitable flaw, credential or PII exposure, or weakened auth.
- **Data inconsistency** — state that diverges from what the user, system, or invariants expect.

Anything below this threshold is either omitted entirely or, if genuinely useful, reported as a **Note**. Notes are observations and improvement suggestions — never blockers.

If you cannot articulate which of the three outcomes a finding maps to, it is not an Issue.

## Calibrating against planned work

If the repo records planned work — a `TODO.md` at the root, a `plans/` or `todo/` directory, or similar in-repo notes — read it before applying the threshold. For code or modules that these notes mark as slated for replacement, removal, or significant rework, calibrate findings as follows:

- `security` and `data-integrity` findings still meet the threshold regardless of planned rework. Code in production exposes users until it is actually replaced — "we're rewriting it" does not retire the risk.
- `correctness` and `user-impact` findings still meet the threshold if they affect users today. They drop out only if the affected behavior itself is being removed (not merely rewritten in a different stack).
- `architecture`, `drift`, `maintainability`, and `testing` findings about code slated for replacement should be downgraded to Notes or omitted. The cost to fix them is unlikely to pay off before the code is deleted.

When you downgrade or omit a finding because of planned work, say so explicitly — either inline on the finding or in a short preamble at the top of the review (e.g., "downgraded based on `plans/frontend-rewrite.md` noting that the HTMX layer is being replaced with React"). Cite the specific file or note so the user can find it. The user needs to see what was set aside so they can override.

If the repo has no such planned-work notes, or none of them touch the changed code, ignore this section.

## Categories

Tag every finding with exactly one category. The first four are threshold-meeting by default; the last four are Notes by default and only become Issues when their severity clearly hits the threshold.

| Category | What it covers |
|---|---|
| `security` | Exploitable flaws, secret exposure, missing auth/authz, unsafe input handling, injection. |
| `correctness` | Bugs, race conditions, edge cases, logic errors, off-by-one, wrong results under foreseeable inputs. |
| `data-integrity` | Missing transactions, write races, missing constraints/validation at the boundary, partial-failure recovery gaps, ordering bugs. |
| `user-impact` | Confusing UX, surprising errors, broken API/CLI contracts, accessibility regressions, breaking changes without migration. |
| `architecture` | Violations of project boundaries, dependency direction, CQRS, layer rules from ARCHITECTURE.md or CLAUDE.md. |
| `drift` | Undocumented domain concepts, docs/code divergence, naming inconsistent with conventions, README.md not updated for new aggregates/value objects/flags/statuses/workflows. |
| `maintainability` | Premature abstractions, dead code, unclear control flow, hidden coupling that will make safe change hard. |
| `testing` | Missing coverage on behaviors whose breakage would hit one of the threshold-meeting categories. |

`drift` for new domain concepts is one of the few cases where a "secondary" category routinely meets the threshold: undocumented domain knowledge compounds into user-facing confusion and inconsistency over time.

## Workflow

1. **Gather the changes.** Run `git diff HEAD` to see all outstanding changes (staged and unstaged together — staging state is irrelevant). Run `git status` to identify untracked files, and read every untracked file in full.

2. **Understand the intent and planned work.** Before critiquing, understand what the changes are trying to accomplish. Read surrounding code and related files as needed to build context. Check the repo for planned-work notes (e.g., `TODO.md`, a `plans/` or `todo/` directory) and read what's relevant so you know which areas are slated for replacement or rework — see *Calibrating against planned work* above.

3. **Review against each category.** Walk through the categories in the order listed above. For each candidate finding, check it against the threshold before deciding whether it is an Issue or a Note.

4. **Check documentation alignment.** Read README.md, ARCHITECTURE.md, and CLAUDE.md if they exist. Check both directions:
   - **Code matches docs** — do the changes follow documented principles, patterns, and conventions?
   - **Docs match code** — if the changes introduce new domain concepts, architectural patterns, or naming conventions (or modify existing ones), does the documentation need updating?

   New domain concepts not in README.md are a `drift` Issue — they cause downstream confusion.

5. **Present findings.** Single continuous numbered list, grouped under section headings. Numbering does not reset between sections — every finding has a unique number across the whole review. Tag each finding with its category inline.

   Sections (omit any that are empty):
   - **Issues** — findings that meet the threshold. Must be addressed before shipping.
   - **Notes** — observations, improvement suggestions, and questions. Below the threshold by definition.
   - **Documentation** — concrete suggestions for `CLAUDE.md`, `README.md`, `ARCHITECTURE.md`, or other in-repo docs that would have prevented one or more of the findings above. See *Documentation suggestions* below for what qualifies.

   If the changes look good, say so clearly. Do not invent problems to justify the review.

6. **Ask which Issues to fix, then implement them.** If the review surfaced one or more Issues, end the review by asking the user which to proceed to fix. Do not modify any code yet — wait for the user's reply.

   Prompt them with a short line like: `Which to fix? (e.g. 1b, 2, 3a, 5 (with the database), 6, 8, D11)`. The full numbered findings list is already on screen above, so do not restate the Issues.

   Expect free-text input naming Issues by number, optionally with a fix-option letter and/or a parenthetical hint. Examples of valid input:
   - `2` — fix Issue 2 (apply the only fix, or option `a.` if there are several).
   - `3a` — fix Issue 3 using option `a.`.
   - `5 (with the database)` — fix Issue 5; the parenthetical is the user's steer on how — honor it, picking the option or approach that matches.
   - `1b, 2, 3a, 5 (with the database), 6, 8` — apply each in turn.
   - Ranges like `3–6` are also valid and mean every Issue in that range.

   For each named Issue:
   - Single fix (`→`): apply it.
   - Multiple fix options (`a.`, `b.`, `c.`) with no letter or hint from the user: apply option `a.` and mention which one you used in your implementation summary, so the user can redirect — e.g., "for #3 I applied option a; reply if you'd prefer b".
   - Parenthetical hint: pick the option or approach that matches the hint. If no listed option fits, follow the hint directly and note what you did.

   Notes are below the threshold and are never offered for selection — ignore any Note numbers the user names, and say so.

   Documentation suggestions can be applied alongside Issue fixes. The user names them with a `D` prefix (e.g., `D11`) or naturally in a parenthetical. Apply them as straightforward doc edits.

   If the user replies with nothing, "none", or similar, end without implementing anything.

### Format for Issues

Each Issue separates the problem from the fix so the user can reply with shorthand like "Implement 1a, 2b, and 3–6":

- First line: category tag, file and line reference, then the problem in one or more lines.
- Next: the recommended solution. If there is only one good fix, write a single line prefixed with `→`. If there are multiple viable fixes, list them as `a.`, `b.`, `c.`, one per line.

Example:

```
3. `[security]` `src/auth/session.ts:42` — token comparison uses `==` instead of a constant-time check, so the endpoint is vulnerable to timing attacks.
   a. Replace with `crypto.timingSafeEqual(...)`.
   b. Move the comparison into the existing `verifyToken` helper, which already uses constant-time comparison.

4. `[correctness]` `src/api/users.ts:88` — missing `await` on `db.commit()` means the response can be sent before the write is durable, so a crash between response and commit leaves the client thinking the write succeeded.
   → Add `await` before `db.commit()`.
```

### Format for Notes

Each Note is a single entry — no problem/solution split required.

Example:

```
9. `[maintainability]` `src/billing/invoice.ts:120-145` — the discount calculation duplicates logic already in `pricing/discount.ts`. Worth consolidating next time this area is touched.
```

### Documentation suggestions

A Documentation entry proposes a concrete edit to an in-repo doc (`CLAUDE.md`, `README.md`, `ARCHITECTURE.md`, etc.) that would have steered the author away from one or more findings above. Use a `D`-prefixed number so it stays distinct from Issues and Notes.

Only include a suggestion when all of the following hold:

- It maps to at least one Issue or Note in this review (cite which).
- The guidance is concrete and generalizable — a rule, convention, or domain fact future contributors can follow — not a restatement of the bug.
- The target doc exists or is the obvious place for it; don't propose creating a new doc unless several findings cluster around the same gap.

If no finding would have been prevented by a doc change, omit the section entirely. Do not pad it.

Example:

```
D10. `CLAUDE.md` — add to the "Background jobs" section: "Always wrap retriable work in `runWithRetry(...)`; bare `setTimeout` loops bypass the dead-letter queue." Would have prevented Issue 4 and Note 9.
D11. `README.md` — document the new `RecurringPayment` aggregate (introduced in `src/billing/recurring.ts`) under "Domain concepts", so future contributors know it owns subscription state. Addresses Issue 7 (`drift`).
```

## Rules

- The review itself is read-only — do not modify any code while reviewing or before the user has selected which Issues to implement via the dialog. Only implement Issues the user explicitly picks.
- Be direct and specific. Cite file paths and line numbers.
- Apply the threshold honestly. If a finding does not map to user problems, security, or data inconsistency, it is a Note or it is omitted — not an Issue dressed up as one.
- Skip trivial style nits unless they violate explicit project guidelines.
- Consider the change as a whole. Look for cross-cutting concerns and interactions between modified files.
- If something is unclear, frame it as a question in Notes rather than assuming it is wrong.
