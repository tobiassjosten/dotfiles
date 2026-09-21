---
name: plan-task
description: Turn a feature-level request into a set of ready, correctly-sequenced work items in whatever source the project tracks work in. Investigates the codebase, drafts a plan in plan mode surfacing the open product/architecture questions, decomposes it into task drafts, critiques the set for readiness and dependency order, then creates the items on your approval. The feature-scale counterpart to /next's single-task planning.
disable-model-invocation: true
---

# Plan Task

Turn one feature-level request into a **set** of ready, well-formed, correctly-sequenced work items. Where `/next` plans and executes a single task, `/plan-task` plans a whole effort, decomposes it into tasks, wires the dependencies among them, and files them into the project's work-item source. It plans and files; it does not implement — that's `/next`.

This skill owns the **what**: investigate, plan, decompose, sequence, check for readiness, create. Each project owns the **how**: where work items live, the shape they take, and their lifecycle. Discover that from the project — the same way `/next` does — and never hardcode a particular tracker.

## Argument

The seed request is `$ARGUMENTS` — the feature or effort to plan. If it's empty, ask the user what to plan and stop.

## Determine the work-item source

Learn three things about the project before creating anything: **where work items live**, **the shape they take** (template/fields), and **their lifecycle** (states, how new items are recorded, any staged-follow-up convention). Discover them the same way `/next` does:

- First consult the project's own Claude instructions and documentation (CLAUDE.md, AGENTS.md, `docs/`, READMEs). If they name a work-item source, a task template, or a lifecycle, follow that — it takes precedence over everything below.
- Otherwise discover the source among the ones `/next` enumerates — a `TODO.md` file, a directory of per-task files, a Backlog.md board, or an MCP-connected issue tracker. These are examples, not an exhaustive list.
- If more than one source exists and the docs don't disambiguate, ask the user which to use.

You create into that source, in its shape, honoring its lifecycle. Default new items to the source's unstarted/backlog state unless the project's lifecycle says otherwise.

## Steps

1. **Guard against duplicates and overlap.** Search the work-item source for items overlapping the effort. Surface strong matches and confirm with the user whether to fold into existing work, proceed alongside it, or stop.

2. **Investigate.** Spawn the `Explore` agent with a brief derived from the request: where in the codebase this lands, the affected areas/subsystems, relevant constraints and prior art, existing patterns to reuse, and the natural seams for splitting the work. Keep its findings; don't dump them on the user.

3. **Plan in plan mode.** From the findings, draft a feature-level plan against the *current* code, reusing existing patterns and solutions as far as possible. Surface the genuinely open decisions — product, architecture, anything novel — to the user via `AskUserQuestion`; skip what the investigation already settled. Iterate until the plan is right and approved. **Wrap plan mode — don't reimplement planning.** The plan is the input to decomposition, not itself a work item.

4. **Decompose into task drafts.** Break the approved plan into the smallest set of independently-meaningful tasks that covers it — each one task, one done-state (YAGNI; prefer clean scope over speculative generality). Draft each in the project's task shape: its documented template if there is one, otherwise a plain default — a **Context** (what changes and why), **testable Acceptance Criteria**, and a **Definition of Done**, plus constraints/dependencies/non-goals where the plan surfaced them. Then propose the **sequence**: the dependency edges among these new tasks, and any grouping the source supports (project/epic/label) — but only for a genuine goal-directed effort, not mere topical relatedness.

5. **Critique the set for readiness and sequencing.** If the project provides a **task-readiness reviewer** — an agent or skill its docs name for this — delegate the critique to it, passing every draft, the investigation findings, the proposed sequence, and a digest of related existing items. Otherwise apply a Definition of Ready inline: single clear outcome; testable acceptance criteria; Definition of Done present; constraints and edge cases named; dependencies identified and expressible in the source; right-sized (not an epic, not a trivial fragment); no blocking ambiguity. Judge each draft **and the relationships among the new drafts**, not just against existing items. Keep it proportional — a two-task effort shouldn't loop.

6. **Resolve.** Address the punch-list: revise drafts, adjust the sequence, merge or split. For real gaps and any conflict the critique surfaces (overlapping scope, contradictory ordering, an ambiguous boundary), ask the user (`AskUserQuestion`). Re-critique only if the set changed materially.

7. **Approve.** Present the set as a unit: the ordered list of titles, the dependency graph (what blocks what), the proposed grouping/placement, and any task that is a sequenced later stage which should start ahead of the backlog per the project's convention. Get the user's explicit go-ahead. **Nothing is written to the source before this.**

8. **Create.** Write each item into the work-item source in dependency order, so each dependency can reference an already-created predecessor. Use the project's documented mechanism and lifecycle: default new items to the source's unstarted/backlog state; set dependencies where the source supports them; apply grouping only where a genuine goal warrants it; honor any staged-follow-up convention the project documents. Follow the project's lifecycle exactly — it may gate where new work is allowed to land.

9. **Decision records.** If the plan settled a decision with real alternatives and the project records decisions (e.g. an ADR practice), remind the user and offer to draft one.

10. **Report** the created items' identifiers or links in dependency order, the sequence, and the placement.

Scope note: this skill decomposes an effort into a set of *ready* items (the create step at feature scale). It does not plan any individual implementation or start work — that's `/next`. Efforts large enough to warrant several sequenced items are the typical case, but a one-item set is valid — `/shape` chains every promoted idea here regardless of size. Scale the ceremony to the effort; outside that chain, a lone task can also be filed by hand or by the project's own intake.
