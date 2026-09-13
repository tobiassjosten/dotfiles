---
name: review
description: Review all outstanding changes — or, when the working tree is clean on a non-main branch, the branch's diff from the main branch — by delegating to the code-reviewer agent, then interactively fix the findings the user picks. Findings are split into Issues (consequential) and Nitpicks (cosmetic).
disable-model-invocation: true
---

# Code Review

Generate a review of the changes under review and act on it interactively: present the findings, let the user pick which to fix, and apply exactly those. Finding-generation is delegated to the `code-reviewer` agent — the single keeper of the review bar. This skill owns only the interaction and the fixing.

## Composed pieces

- **Reviewing** is delegated to the `code-reviewer` agent (`~/.claude/agents/code-reviewer.md`), which applies the shared threshold in `~/.claude/skills/review-core.md` and selects the diff base via `~/.claude/skills/review-diff.sh` (outstanding changes, or the branch diff when the tree is clean). **Spawn it via the Agent tool.** It gathers the diff, reads every untracked file, recovers a truncated diff, applies the bar, and returns the numbered findings — Issues then Nitpicks, each with a fix — as its final message, and never modifies code. Presenting those findings, asking which to fix, and fixing them stays here.

## Workflow

1. **Review.** Spawn the `code-reviewer` agent to review the changes under review. Do not narrow the scope — let its base-selection pick outstanding vs. branch mode. It returns the findings as its final message.

2. **Present the findings.** The agent's output is not shown to the user, so relay its returned findings **verbatim** — the two sections, Issues then Nitpicks, under one continuous numbering, each with its fix. The numbers are the user's selection handles, so reproduce them exactly; do not renumber, summarize, or drop any. If the agent found nothing to improve, say so and stop.

3. **Ask which findings to fix.** End by asking the user which to fix. Both sections are selectable by number; Nitpicks are fixable findings, not advisory. Do not modify any code yet — wait for the user's reply.

   Prompt them with a short line like: `Which to fix? (e.g. 1b, 2, 3a, 5 (with the database), 6, 8 — or "all")`. The full numbered findings list is already on screen above, so do not restate it.

   Expect free-text input naming findings by number, optionally with a fix-option letter and/or a parenthetical hint. Examples of valid input:
   - `2` — fix finding 2 (apply the only fix, or option `a.` if there are several).
   - `3a` — fix finding 3 using option `a.`.
   - `5 (with the database)` — fix finding 5; the parenthetical is the user's steer on how — honor it, picking the option or approach that matches.
   - `1b, 2, 3a, 5 (with the database), 6, 8` — apply each in turn.
   - Ranges like `3–6` are also valid and mean every finding in that range.
   - `all` (or `all nitpicks`, `all issues`) — apply every finding, or every finding in that section.

   If the user replies with nothing, "none", or similar, end without implementing anything.

4. **Implement the picked findings.** For each named finding:
   - Single fix (`→`): apply it.
   - Multiple fix options (`a.`, `b.`, `c.`) with no letter or hint from the user: apply option `a.` and mention which one you used in your implementation summary, so the user can redirect — e.g., "for #3 I applied option a; reply if you'd prefer b".
   - Parenthetical hint: pick the option or approach that matches the hint. If no listed option fits, follow the hint directly and note what you did.

## Rules

- All rules from `~/.claude/skills/review-core.md` apply to the findings.
- Only implement findings the user explicitly picks in step 3 — never before, never others.
