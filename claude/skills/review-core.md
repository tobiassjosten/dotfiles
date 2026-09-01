# Review principles (shared core)

This file is the shared policy for all review skills. It defines *what counts as a finding*, *how to look for findings*, and *how findings are formatted*. It deliberately says nothing about where the changes come from (local diff, pull request, …) or what happens after findings are presented — the invoking skill owns those mechanics.

**This review reports every genuine improvement to the code under review, sorted into two tiers.** A finding is anything a fix would genuinely improve: from security holes and data-loss bugs down to an unclear name, an inconsistent parameter order, or a missed early-return. The bar is a senior developer nitpicking the change — when the findings are fixed, there should be nothing left they would change, however much they nitpick. No improvement is too small to report. To keep the reader focused without losing that exhaustiveness, findings are split into two sections:

- **Issues** — consequential findings: bugs, security/data/reliability risks, broken contracts, real maintainability traps. What the reader must not miss.
- **Nitpicks** — cosmetic findings: clarity and consistency polish (naming, ordering, early returns, minor redundancy). Small, but still worth fixing.

The split is about presentation and focus, **not** about which to fix — both tiers are genuine improvements a senior developer would make, and both are offered for fixing. This is not a return of the old advisory "Notes" tier: a Nitpick is a concrete problem with a concrete fix, not a "keep in mind". Two things are still excluded: (1) **non-actionable commentary** — heads-ups, observations with no concrete fix — which belongs in a different skill; and (2) **changes that are not genuine improvements** — churn and linter-territory noise, screened out by the threshold below. Every finding names a problem and a fix, or it is omitted.

## Threshold

Report a finding as an **Issue** when fixing it would genuinely improve the code under review. "Improve" spans the full range:

- **Correctness & safety** — the change could cause user problems (confusion, surprise, broken expectations for a user, operator, or downstream caller), a **security risk** (exploitable flaw, credential or PII exposure, weakened auth), a **data inconsistency** (state diverging from what the user, system, or invariants expect), or an **operational failure** (outages, resource exhaustion, degraded performance, unrecoverable states). These are the most severe and lead the review.
- **Clarity & consistency** — unclear or misleading names, ordering or structure inconsistent with the surrounding code, missed guard clauses or early returns, needless nesting, dead or redundant code, comments that mislead or merely restate the code.
- **Anything else a careful senior developer would change** in the changed code, however minor.

The threshold screens out only two kinds of candidate, so the review stays honest rather than noisy:

- **Not a genuine improvement.** A lateral rewrite to personal taste — equivalent constructs, a style the code could reasonably go either way on — is churn, not a fix. If a competent peer could prefer the original, it is not an issue.
- **Already handled by tooling.** Whatever the project's formatter or linter auto-fixes or auto-flags is not worth a manual finding. Report what tooling will not catch.

Severity does not decide *whether* to report — only how to order findings (most severe first), which tier they land in, and how much to explain each (see *Presenting findings*). Name the concrete cost of every finding: for correctness-class findings, the trigger ("when X happens, Y goes wrong"); for clarity-class findings, what is harder to read, maintain, or get right as long as it stands. A candidate with no nameable cost is churn — omit it.

**Which tier.** Sort each reported finding by consequence:

- **Issue** — fixing it prevents a real problem: a bug, a security/data/reliability risk, a broken API/CLI contract, a genuine maintainability trap, an undocumented domain concept, or a test gap that lets bugs ship. The consequence reaches beyond readability.
- **Nitpick** — fixing it makes the code cleaner with no consequence beyond readability or local consistency: a clearer name, consistent ordering, a guard clause, less nesting, a small redundancy, a comment that should match the code. Small and cosmetic, but still wanted — a senior developer would still change it.

When a finding could go either way, decide by consequence: if leaving it unfixed could bite someone later (a maintainer misled, a bug enabled), it is an Issue; if it only makes the code marginally nicer to read, it is a Nitpick.

## Introduced versus pre-existing

Exhaustiveness applies to the **change**, not the whole codebase.

- **Introduced or modified by the change** — the full nitpick bar applies. Every genuine improvement, down to the smallest, is an Issue.
- **Pre-existing, in code the change touches** — report it only when it is a genuinely significant problem (correctness, security, data, reliability, or a real maintainability trap), tagged `(pre-existing)` on the first line. Do **not** nitpick untouched pre-existing lines for naming or style: auditing legacy code the change did not create is scope creep, and it buries the change's own issues in noise. The author needs to know a significant pre-existing problem is there, but fixing it is not automatically their obligation in this change.
- **Pre-existing and merely stylistic** — omit.

## Calibrating against planned work

If the repo records planned work — a `TODO.md` at the root, a `plans/` or `todo/` directory, or similar in-repo notes — read it before applying the threshold. For code or modules that these notes mark as slated for replacement, removal, or significant rework, calibrate findings as follows:

- `security`, `data-integrity`, and `reliability` findings still meet the threshold regardless of planned rework. Code in production exposes users until it is actually replaced — "we're rewriting it" does not retire the risk.
- `correctness` and `user-impact` findings still meet the threshold if they affect users today. They drop out only if the affected behavior itself is being removed (not merely rewritten in a different stack).
- `architecture`, `drift`, `maintainability`, `clarity`, and `testing` findings about code slated for replacement should be omitted. Nitpicking code that is about to be deleted is wasted effort.

When you omit a finding because of planned work, say so explicitly — a short preamble at the top of the review (e.g., "omitted the duplicated-parsing finding based on `plans/frontend-rewrite.md` noting that the HTMX layer is being replaced with React"). Cite the specific file or note so the user can find it. The user needs to see what was set aside so they can override.

If the repo has no such planned-work notes, or none of them touch the changed code, ignore this section.

## Categories

Tag every finding with exactly one category. They run roughly from most to least severe and map loosely onto the two tiers: `security`, `correctness`, `data-integrity`, `reliability`, `user-impact`, and `architecture` findings are almost always **Issues**; `clarity` findings are almost always **Nitpicks**; `maintainability`, `drift`, and `testing` split by consequence — a real trap or an undocumented domain concept is an Issue, a cosmetic tidy-up is a Nitpick. All are reportable; use the list as a checklist of what to look for.

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
| `clarity` | Unclear or misleading names, parameter/return ordering or structure inconsistent with neighbouring code, missed guard clauses or early returns, needless nesting or complexity, redundant local code, comments that mislead or merely restate the code. This is where most nitpick-level findings land. |
| `testing` | Missing coverage on threshold-meeting behaviors; tests weakened, deleted, skipped, or made tautological. |

`drift` for new domain concepts routinely rises to the severe end: undocumented domain knowledge compounds into user-facing confusion over time. Report it when a doc now contradicts the code or a new domain concept is undocumented; the fix is the concrete doc edit.

`testing` likewise routinely rises to the severe end in one pattern: a test weakened, deleted, or skipped in the same change that alters the behavior it covered. That pattern is how bugs ship with green CI.

## How to look

The categories say what counts; this section is how to find it.

- **Read the surrounding code, not just the hunk.** Diff hunks lie by omission. Never report a finding from a hunk alone — read enough of the file (and the functions it calls) to confirm it is real. This is also where false positives and churn die.
- **Trace the blast radius.** For every changed public symbol, find its callers; for every changed interface, its other implementers. Bugs often live in what the diff *didn't* touch: duplicated logic elsewhere that now diverges, an error message, doc, or test still describing the old behavior of a renamed or reworked concept.
- **Check symmetric pairs.** Encode/decode, open/close, acquire/release, subscribe/unsubscribe, up/down migrations: when one side changes, verify the other side changed too or provably didn't need to.
- **Trace failure paths.** For each new or changed code path, ask: what happens on the error branch? On concurrent invocation? On retry or partial failure? On empty, null, or boundary input? Most threshold-meeting bugs are an unasked question from this list.
- **Read the tests for damage, not just absence.** For every test the diff touches, ask what it can no longer catch: loosened assertions, deleted or newly skipped cases, tests that assert a mock returns what the mock was told to return. New behavior with no test at all belongs here too.
- **Make the nitpick pass explicitly.** After the bug hunt, reread the changed code the way a senior developer would line-by-line in review: Is every name accurate, and consistent with its neighbours? Is parameter/field ordering consistent across related functions? Would a guard clause or early return flatten the nesting? Is anything redundant, dead, or more complex than the job needs? Do the comments still match the code, and earn their place? Each of these is an Issue in the changed code — not an aside.

## Documentation alignment

Read README.md, ARCHITECTURE.md, and CLAUDE.md if they exist. Check both directions:

- **Code matches docs** — do the changes follow documented principles, patterns, and conventions? A violation is an `architecture` Issue.
- **Docs match code** — if the changes introduce new domain concepts, architectural patterns, or naming conventions (or modify existing ones), the documentation is now out of date. A doc that contradicts the code, or a new domain concept absent from README.md, is a `drift` Issue — it causes downstream confusion. Its fix is the concrete doc edit.

## Presenting findings

Two sections — **Issues** first, then **Nitpicks** — as a single continuously numbered list. Numbering does not reset between sections, so every finding has a unique number the user can select with shorthand like "1a, 2, 7–9"; the numbers are selection handles, not decoration. Within each section, order most severe first — the reader triages top-down. Omit a section that is empty. Group by root cause: the same underlying mistake in several places is one finding listing every location, not one finding per site.

Output **nothing but the two sections**: no preamble, no summary of what the change does, no overall verdict, no closing remarks. The one exception is the planned-work preamble described above, when it applies. If the change has genuinely nothing to improve — no Issues and no Nitpicks — say so in a single line (e.g. "No issues found.") and stop, but reach that conclusion only after the nitpick pass, not as a shortcut.

### Format for each Issue

Each Issue is written so a reader who knows the system's shape — but not this file's every line, variable, or signature — can understand the problem and judge the fix **without opening the code**. Gloss internal names on first use (`verifyToken`, the helper that checks session cookies) rather than assuming the reader recognizes them.

**Scale the explanation to the finding.** A substantive Issue gets the full structure below. A Nitpick does not — collapse it to a single line naming the problem and its fix. Never pad a Nitpick to look bigger, and never compress a real bug to look smaller.

Substantive issues use these parts:

- **First line:** category tag, file and line reference, then the problem in one sentence. Add `(pre-existing)` after the category tag where it applies.
- **What's wrong:** two to four sentences. Cover what this code's job is, the concrete cost (the trigger "when X happens, Y goes wrong" for correctness; what's harder to read/maintain/get-right for clarity), and who is affected and how badly.
- **Fix — and what it achieves:** the concrete change, plus what applying it accomplishes (what the code will do correctly, or read more clearly, afterward — not just the mechanical edit). One `→` line for a single good fix; `a.`, `b.`, `c.` when there are genuinely different approaches, each saying what it achieves or trades off.
- **Ramifications** *(optional)*: include only when applying the fix has non-obvious knock-on effects — behavior changes for other callers, a migration or deploy-ordering requirement, a performance trade-off, or follow-up work elsewhere. Prefix the line `Ramifications:`. Omit it entirely when the fix is self-contained; do not pad findings with a trivial one.

Example — the Issues get the full structure; the Nitpicks collapse to one line each; numbering runs continuously across both sections:

```
Issues

1. `[security]` `src/auth/session.ts:42` — token comparison uses `==` instead of a constant-time check.
   This comparison decides whether an incoming API request's session token is valid. A plain `==` returns as soon as the first character differs, so the time it takes leaks how many leading characters were correct. An attacker measuring response times can reconstruct a valid token character by character and hijack a session — no credentials required.
   a. Replace with `crypto.timingSafeEqual(...)` — makes the comparison take the same time regardless of how much of the token matches, so response timing reveals nothing.
   b. Route the check through the existing `verifyToken` helper (the session-cookie checker the web routes already use), which compares in constant time — same effect, and it removes the duplicated comparison logic.

2. `[correctness]` `src/api/users.ts:88` — missing `await` on `db.commit()`.
   This endpoint saves a user's profile update and then reports success. Without the `await`, the success response is sent while the database write is still in flight; if the process crashes or restarts in that window, the write is lost after the client was already told it succeeded. It surfaces as sporadic "my changes didn't stick" reports that are near-impossible to reproduce.
   → Add `await` before `db.commit()` so the success response is sent only after the write has durably landed.

Nitpicks

3. `[clarity]` `src/billing/invoice.ts:20` — `d` holds the customer's outstanding balance; the one-letter name hides that at every use.
   → Rename `d` to `outstandingBalance`.

4. `[clarity]` `src/billing/invoice.ts:34-48` — the early-exit conditions are nested three deep, so the success path is hard to follow.
   → Return early on each guard (`if (!customer) return ...`) to flatten the body to a single level.
```

## Rules

- The review itself is read-only — gather context and present findings first. Act (fix code, post comments) only on the user's explicit selection, per the invoking skill's workflow.
- Be direct and specific. Cite file paths and line numbers.
- Apply the threshold honestly in both directions: report every genuine improvement to the changed code, however minor — and omit anything that is not one. Subjective churn (lateral rewrites to taste) and linter-territory nits are not improvements.
- No nit is too small if it genuinely improves the changed code. But the nitpick bar is the changed code, not untouched pre-existing lines — see *Introduced versus pre-existing*.
- Consider the change as a whole. Look for cross-cutting concerns and interactions between modified files.
- If you are unsure whether something is a real problem, resolve it by reading more code — confirm it or drop it. Do not report speculation, and do not hedge it into a soft observation; there is no advisory tier.
