# Approach

## Three entry points

- **`CLAUDE.md`** — thin, stable. Imports `@README.md` and `@docs/approach.md`. Holds only what doesn't fit a `docs/` file (e.g., a handful of build/test commands). Move material into `docs/` if it grows past a screen.
- **`README.md`** — overview and general functionality of the project: what it is, how to install it, how to use it, how to contribute. Primarily aimed at humans, but the assistant reads it too and you should reach for it whenever the task is about the project as a whole (rather than a specific subsystem). Keep prose oriented to a newcomer; deeper material belongs under `docs/`.
- **`docs/`** — durable knowledge, organized so the right material is reachable for the right task.

## docs/ structure

Five subdirectories, each with its own `INDEX.md`:

- **`architecture/`** — how the system is built: cross-cutting technical patterns and conventions that apply system-wide — dependency wiring, background-job processing, CQRS read/write split, logging, layering. Answers *"how is X implemented here, in general?"*. Load when reasoning about how the system as a whole behaves.
- **`design/`** — how one specific feature works: how authentication is implemented, gotchas in the admin dashboard, trade-offs behind the billing module. Answers *"how does this specific feature work?"*. Load when working on or near a specific feature.
- **`domain/`** — the business the system serves: terminology, external systems, business rules — knowledge that holds true regardless of how the code is written. Load when the task touches the domain.
- **`process/`** — how we work on the project: writing tasks, operating developer tooling, sequencing deploys, working across repos. Answers *"what's the procedure for X?"*. Load when the task is about a way of working rather than the system itself.
- **`plan/`** — outstanding work the project wants done but hasn't done yet (cleanup, chunked migrations, leftovers). Load before starting new work. See `docs/plan/INDEX.md` for the filename convention and the rename-to-insert rule. Entries are **deleted** when done.

All but `plan/` accumulate over time; `plan/` shrinks and grows. `INDEX.md` is the navigation entry point — keep it in sync any time files in its directory change (added, renamed, removed, or *completed and deleted*).

## Working in docs/

**One topic per file.** A file about authentication shouldn't also cover payments — different tasks need them separately. When files relate, **link**; never duplicate.

**Keep each file short** — aim for under ~50 lines of content, treat ~75 as a hard ceiling. A long file forces every task touching any sub-topic to drag in all the others, defeating selective loading. When a file approaches the ceiling, split it; that usually means the topic was actually more than one.

**Capture as you work.** Prefer a new, small, single-topic file over expanding an existing one with tangential material. If you'd add a `## New section` for it, it belongs in its own file. Update the subdirectory's `INDEX.md` in the same change, and cross-link related files.

**Skip ephemera** — task notes, conversation summaries, debugging logs. Test: would the topic still be useful six months from now?

## Suggesting `plan/` entries

While working, you'll notice improvements outside the current task's scope but worth doing later (duplication to dedupe, a paused migration step still pending, a stale config default, a dep upgrade, a far-away bug). Don't bury these as drive-by edits and don't silently drop them. At the end of the task, propose them as `plan/` entries: short filename (atomic vs. sequenced, and whether the head-of-queue rename per `docs/plan/INDEX.md` applies), plus a one-line *what / why / done when*. The user decides which to write, edit, or drop.

The bar: would this still be worth doing in a few weeks if you didn't bring it up?

## Adding subdirectories

The five base subdirectories cover most projects. Add another only when ≥ 2 documents belong together and don't fit any of them. Give it an `INDEX.md` and link it from `docs/INDEX.md`.

## What not to put here

- **Code patterns and conventions** — the code is authoritative.
- **Git history** — `git log` is authoritative.
- **Per-task or per-PR context** — commit messages and PR descriptions.
- **Secrets, credentials, or PII** — never, in any form.

## Boundary

This file describes *how the project documents itself*, not *what the project is*. Project-specific rules (build commands, deployment targets, on-call rotations, domain safety constraints) belong in other files under `docs/`.
