# Plan

Outstanding work the project wants done but hasn't done yet: cleanup, refactoring, ops chores, parts of a chunked migration, leftovers from previous changes. One file per change.

Unlike `architecture/`, `design/`, and `domain/` — which accumulate durable knowledge — entries here are **removed when the work is complete**. `plan/` shrinks as work finishes and grows as new work is identified.

## Naming convention

The filename signals when the change should happen relative to others in `plan/`.

- **`{name}.md`** — atomic. No ordering constraints; the change can land any time, independently of the others. Multiple atomic entries can coexist with no order among themselves. Example: `consolidate-logging.md`.
- **`{N}-{name}.md`** with `N ≥ 1` — sequenced. Sequenced entries must happen in strict numeric order, lowest first, and all of them before any atomic entry. Example: `1-finish-legacy-migration.md`, then `2-extract-billing-service.md`, then `3-add-event-bus.md`.

The ordering is: `1-*`, `2-*`, … in strict numeric order, then all atomic entries (unordered among themselves).

## Inserting a change before everything else

The sequenced numbers are not stable IDs — they encode *position in the queue*. When a new change needs to land **before** the current `1-*` (a leftover from a paused migration, a chunked-migration step that pre-empts the rest of the queue, or any other "a previous change isn't done until this is done" case), **rename the existing files to make room**. This is the same **one file per change** principle the rest of `docs/` follows — there's no special "front of the queue" prefix; you just shift the queue:

- The new change becomes `1-…`.
- The previous `1-` becomes `2-`, the previous `2-` becomes `3-`, and so on.
- Update this `INDEX.md` and any cross-references between plan entries in the same change.

`1-finish-legacy-migration.md` in the example set below is exactly this kind of case — a paused migration step that now blocks downstream work. When it was added, the billing-service and event-bus entries were renumbered up by one to make room. The same shuffle applies any time a new must-happen-first item appears.

## File contents

A plan entry should explain *what* the change is, *why* it's needed, and *what "done" looks like* — enough that anyone (Claude or a human) picking it up later has the context to execute. Keep it short; if the change needs more design, capture the design in `docs/design/` and link to it from here.

## When done

Delete the file and update this index in the same change. Don't leave completed entries lying around — that's what Git history is for.

## Current plan

*The entries below are example placeholders demonstrating the naming convention. The `-EXAMPLE` suffix marks them as scaffold leftovers — delete or replace them with your project's actual plan (and drop the suffix on real entries).*

- [`1-finish-legacy-migration-EXAMPLE.md`](1-finish-legacy-migration-EXAMPLE.md) — drop the deprecated `user_id_old` column and remove the dual-write path. Inserted at the head of the queue (other entries were renumbered up by one).
- [`2-extract-billing-service-EXAMPLE.md`](2-extract-billing-service-EXAMPLE.md) — pull billing out of the monolith into its own service.
- [`3-add-event-bus-EXAMPLE.md`](3-add-event-bus-EXAMPLE.md) — introduce a shared event bus (depends on billing extraction).
- [`consolidate-logging-EXAMPLE.md`](consolidate-logging-EXAMPLE.md) — unify three near-duplicate logging helpers into one (atomic; can land any time).
