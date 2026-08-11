# Review principles (shared core)

This file is the shared policy for all review skills. It defines *what counts as a finding*, *how to look for findings*, and *how findings are formatted*. It deliberately says nothing about where the changes come from (local diff, pull request, …) or what happens after findings are presented — the invoking skill owns those mechanics.

## Threshold

A finding is reported as an **Issue** only if, on its own, it could plausibly cause one of these outcomes:

- **User problems** — confusion, frustration, surprise, or broken expectations for a real user, operator, or downstream caller.
- **Security risk** — exploitable flaw, credential or PII exposure, or weakened auth.
- **Data inconsistency** — state that diverges from what the user, system, or invariants expect.
- **Operational failure** — outages, resource exhaustion, degraded performance, or unrecoverable states: the failures that page an operator before any user files a bug.

Anything below this threshold is either omitted entirely or, if genuinely useful, reported as a **Note**. Notes are observations and improvement suggestions — never blockers.

Every Issue must name its trigger — the concrete scenario in which the failure occurs ("when X happens, Y goes wrong"). If you can name an outcome but not a trigger, it is not an Issue; if you can name neither, omit it.

## Introduced versus pre-existing

Judge every candidate finding on whether the change under review caused it:

- **Introduced or worsened by the change** — apply the threshold normally.
- **Pre-existing, in code the change touches** — still report it if it meets the threshold, tagged `(pre-existing)` on the first line. The author needs to know it is there, but fixing it is not automatically their obligation in this change.
- **Pre-existing and below the threshold** — omit. Auditing legacy code adjacent to the diff for Notes is scope creep, not review.

## Calibrating against planned work

If the repo records planned work — a `TODO.md` at the root, a `plans/` or `todo/` directory, or similar in-repo notes — read it before applying the threshold. For code or modules that these notes mark as slated for replacement, removal, or significant rework, calibrate findings as follows:

- `security`, `data-integrity`, and `reliability` findings still meet the threshold regardless of planned rework. Code in production exposes users until it is actually replaced — "we're rewriting it" does not retire the risk.
- `correctness` and `user-impact` findings still meet the threshold if they affect users today. They drop out only if the affected behavior itself is being removed (not merely rewritten in a different stack).
- `architecture`, `drift`, `maintainability`, and `testing` findings about code slated for replacement should be downgraded to Notes or omitted. The cost to fix them is unlikely to pay off before the code is deleted.

When you downgrade or omit a finding because of planned work, say so explicitly — either inline on the finding or in a short preamble at the top of the review (e.g., "downgraded based on `plans/frontend-rewrite.md` noting that the HTMX layer is being replaced with React"). Cite the specific file or note so the user can find it. The user needs to see what was set aside so they can override.

If the repo has no such planned-work notes, or none of them touch the changed code, ignore this section.

## Categories

Tag every finding with exactly one category. The first five are threshold-meeting by default; the last four are Notes by default and only become Issues when their severity clearly hits the threshold.

| Category | What it covers |
|---|---|
| `security` | Exploitable flaws, secret exposure, missing auth/authz, unsafe input handling, injection. |
| `correctness` | Bugs, race conditions, edge cases, logic errors, off-by-one, wrong results under foreseeable inputs. |
| `data-integrity` | Missing transactions, write races, missing constraints/validation at the boundary, partial-failure recovery gaps, ordering bugs. |
| `reliability` | Missing timeouts on outbound calls, resource leaks, unbounded memory or queue growth, retry storms, non-idempotent operations that get retried, N+1 or O(n²) work on hot paths, deploy-order hazards (code assuming a migration or config that ships separately). |
| `user-impact` | Confusing UX, surprising errors, broken API/CLI contracts, accessibility regressions, breaking changes without migration. |
| `architecture` | Violations of project boundaries, dependency direction, CQRS, layer rules from ARCHITECTURE.md or CLAUDE.md. |
| `drift` | Undocumented domain concepts, docs/code divergence, naming inconsistent with conventions, README.md not updated for new aggregates/value objects/flags/statuses/workflows. |
| `maintainability` | Premature abstractions, dead code, unclear control flow, hidden coupling that will make safe change hard. |
| `testing` | Missing coverage on threshold-meeting behaviors; tests weakened, deleted, skipped, or made tautological. |

`drift` for new domain concepts is one of the few cases where a "secondary" category routinely meets the threshold: undocumented domain knowledge compounds into user-facing confusion and inconsistency over time.

`testing` likewise routinely meets the threshold in one pattern: a test weakened, deleted, or skipped in the same change that alters the behavior it covered. That pattern is how bugs ship with green CI.

## How to look

The categories say what counts; this section is how to find it.

- **Read the surrounding code, not just the hunk.** Diff hunks lie by omission. Never report an Issue from a hunk alone — read enough of the file (and the functions it calls) to confirm the problem is real. This is also where false positives die.
- **Trace the blast radius.** For every changed public symbol, find its callers; for every changed interface, its other implementers. Bugs often live in what the diff *didn't* touch: duplicated logic elsewhere that now diverges, an error message, doc, or test still describing the old behavior of a renamed or reworked concept.
- **Check symmetric pairs.** Encode/decode, open/close, acquire/release, subscribe/unsubscribe, up/down migrations: when one side changes, verify the other side changed too or provably didn't need to.
- **Trace failure paths.** For each new or changed code path, ask: what happens on the error branch? On concurrent invocation? On retry or partial failure? On empty, null, or boundary input? Most threshold-meeting bugs are an unasked question from this list.
- **Read the tests for damage, not just absence.** For every test the diff touches, ask what it can no longer catch: loosened assertions, deleted or newly skipped cases, tests that assert a mock returns what the mock was told to return. New behavior with no test at all belongs here too.

## Documentation alignment

Read README.md, ARCHITECTURE.md, and CLAUDE.md if they exist. Check both directions:

- **Code matches docs** — do the changes follow documented principles, patterns, and conventions?
- **Docs match code** — if the changes introduce new domain concepts, architectural patterns, or naming conventions (or modify existing ones), does the documentation need updating?

New domain concepts not in README.md are a `drift` Issue — they cause downstream confusion.

## Presenting findings

Single continuous numbered list, grouped under section headings. Numbering does not reset between sections — every finding has a unique number across the whole review. Tag each finding with its category inline.

Within Issues, order most severe first — the reader triages top-down. Group by root cause: the same underlying mistake in several places is one finding listing every location, not one finding per site.

Sections (omit any that are empty):

- **Issues** — findings that meet the threshold. Must be addressed before shipping.
- **Notes** — observations, improvement suggestions, and questions. Below the threshold by definition.
- **Documentation** — concrete suggestions for `CLAUDE.md`, `README.md`, `ARCHITECTURE.md`, or other in-repo docs that would have prevented one or more of the findings above. See *Documentation suggestions* below for what qualifies.

If the changes look good, say so clearly. Do not invent problems to justify the review.

### Format for Issues

Each Issue separates problem, explanation, and fix so the user can reply with shorthand like "1a, 2b, and 3–6":

- **First line:** category tag, file and line reference, then the problem in one sentence. Add `(pre-existing)` after the category tag where it applies.
- **Explanation:** two to four sentences written for a reader who does not know this part of the code. Cover what the code's job is, the trigger ("when X happens, Y goes wrong"), and the ramification — who gets hit and how badly. Gloss internal names on first use (`verifyToken`, the helper that checks session cookies) rather than assuming the reader knows them. The test: a teammate who has never opened this file should understand the problem and be able to judge the fix options without reading any code.
- **Fix:** if there is only one good fix, a single line prefixed with `→`. If there are multiple viable fixes, list them as `a.`, `b.`, `c.`, one per line.

Example:

```
3. `[security]` `src/auth/session.ts:42` — token comparison uses `==` instead of a constant-time check.
   This comparison decides whether an incoming API request's session token is valid. A plain `==` returns as soon as the first character differs, so the time the comparison takes leaks how many leading characters were correct. An attacker measuring response times can reconstruct a valid token character by character and hijack a session — no credentials required.
   a. Replace with `crypto.timingSafeEqual(...)`.
   b. Move the comparison into the existing `verifyToken` helper (the session-cookie checker used by the web routes), which already compares in constant time.

4. `[correctness]` `src/api/users.ts:88` — missing `await` on `db.commit()`.
   This endpoint saves a user's profile update and then reports success. Without the `await`, the success response is sent while the database write is still in flight; if the process crashes or restarts in that window, the write is lost after the client was already told it succeeded. This surfaces as sporadic "my changes didn't stick" reports that are near-impossible to reproduce.
   → Add `await` before `db.commit()`.
```

### Format for Notes

Each Note is a single entry — no problem/explanation/fix split required. The self-containment expectation still applies, compressed: enough context that the reader understands the observation without opening the file.

Example:

```
9. `[maintainability]` `src/billing/invoice.ts:120-145` — the discount calculation re-implements logic that already lives in `pricing/discount.ts`, the module every other billing path uses for discounts. Two copies will drift apart the next time discount rules change. Worth consolidating next time this area is touched.
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

- The review itself is read-only — gather context and present findings first. Act (fix code, post comments) only on the user's explicit selection, per the invoking skill's workflow.
- Be direct and specific. Cite file paths and line numbers.
- Apply the threshold honestly. If a finding does not map to user problems, security, data inconsistency, or operational failure, it is a Note or it is omitted — not an Issue dressed up as one.
- Skip trivial style nits unless they violate explicit project guidelines.
- Consider the change as a whole. Look for cross-cutting concerns and interactions between modified files.
- If something is unclear, frame it as a question in Notes rather than assuming it is wrong.
