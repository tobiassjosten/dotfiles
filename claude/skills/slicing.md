# Slicing work into items (shared procedure)

How an effort is cut into work items, and how the cut is tracked. `/plan-task` decomposes by it, a project's intake and grooming skills judge right-sizing by it, and `/forge <parent>` works the result. A project's own docs may refine it with its architecture's names — they win where they say more.

## The unit is one coherent change

A work item is one change a reviewer can hold in mind and judge against one stated intent. **Coherence is the criterion; size is a symptom.** A large diff is a reason to look for a seam, not a seam in itself: a long change that is all one concern stays whole, and a short one that mixes two splits. Signs an item holds more than one concern:

- its acceptance criteria are checked in unrelated parts of the system;
- it changes more than one model with invariants of its own;
- it carries a schema and the user interface that consumes it;
- it builds a shared primitive inside its first consumer, where the next consumer will not find it.

## Seams, from the inside out

Cut along the dependency direction, innermost first, so every slice builds on something already reviewed and landed:

1. **Intent** — where the project records decisions and designs, the decision record and the design doc for the target come first, before code. Every later slice is then reviewed against a stated design instead of discovering it. Where design docs describe the system as it is, one written ahead of its code opens with a status line naming the parent and saying the later slices make it true; the last slice removes it.
2. **Core model** — business rules and use cases (in DDD terms the domain and application layers), verified by tests at their own boundary with fakes for the ports they define. One model per item when models carry distinct invariants.
3. **Edges** — persistence, infrastructure and transport adapters, each implementing ports the core already defines. A primitive more than one consumer needs is an item of its own.
4. **Surface** — the user-facing part that composes them, with the fixtures that make it inspectable.

Within a layer, the write side and the read side (in CQRS terms, commands and queries) are separate seams when they have different consumers.

Two limits keep this honest. Slice **per model, not across the whole feature**: "all the domain, then all the persistence" for independent models batches unrelated review just as badly as one big item. And slice **no finer than coherence**: a slice whose acceptance criteria only make sense alongside a neighbour's folds into it.

Every slice must stand on its own. Where the default branch deploys, an inner slice lands before anything calls it, so it passes the verification set and is harmless while unwired; and its acceptance criteria are verifiable at its own boundary — never "works once a later slice lands".

## Tracking: a parent and its children

When an effort becomes more than one item, file a **parent** that holds what the slices share — why, the constraints, the non-goals, the decisions — and a breakdown of the slices, and file each slice as its **child**:

- **Where the source supports it**: Linear sub-issues (`parentId`), Jira sub-tasks or epic children, Backlog.md subtasks (`--parent`). A `TODO.md` or a directory of per-task files has no hierarchy: file no parent there, and cross-reference the items instead.
- **Children** carry their own context, acceptance criteria and Definition of Done, link the parent for the shared context rather than copying it, and are filed in the parent's state and priority, since they are one effort. Blocked-by edges go only where a real dependency exists, so independent slices can run in parallel, one tree each.
- **Promoted as one**: moving a parent into the queue `/next` draws from moves its open children with it, at its priority — `/next` passes over the parent, so children left behind are never picked.
- **Only an item not yet started becomes a parent.** One already claimed — In Progress, In Review, or bound by a tree's marker — stays a child, under a new parent.
- **The parent is never worked**: never claimed, never bound by a task marker, never given a tree. Its acceptance criteria are "every child is done", plus any end-to-end check the slices cannot make alone. The `/forge <parent>` run that finds every child done closes it: it verifies the remaining criteria with the user from the main checkout — no code edits, no claim — and then moves the parent to its terminal state, or proposes a fix child when a check fails. A tracker that closes a parent with its last child (Linear's parent auto-close) would skip that check, so leave such a setting off.
- **A project instead of a parent**: where the repository's instructions track an effort as the items of one tracker project (a Linear project) rather than under a parent, the project plays the parent's role — its description holds what the slices share and its done-when, and the slices' order is `blockedBy` plus whatever the repository's instructions add; its items are the children; no parent is filed; and `/forge <project>` closes it by moving the project to its completed state once its done-when is checked.
- **`/forge <parent>`** works the children wave by wave (`forge/SKILL.md` § *A parent item*), and `/next` never selects a parent (`next/SKILL.md` § *Parent items*).
