# Documentation

Durable documentation about this project. Anything Claude (or a human) should be able to look up later, organized so the right material is reachable when a task calls for it.

- [`approach.md`](approach.md) — how the assistant works in this codebase: where instructions live, how context is engineered.

## Subdirectories

- [`architecture/`](architecture/INDEX.md) — how the system is built: cross-cutting technical patterns and conventions. Answers *"how is X implemented here, in general?"*.
- [`design/`](design/INDEX.md) — how one specific feature works: implementation knowledge tied to a single subsystem. Answers *"how does this specific feature work?"*.
- [`domain/`](domain/INDEX.md) — the business the system serves: terminology, rules, and external systems that hold true regardless of how the code is written.
- [`process/`](process/INDEX.md) — how we work on the project: procedures for developing, shipping, and operating it. Answers *"what's the procedure for X?"*.
- [`plan/`](plan/INDEX.md) — outstanding work the project wants done but hasn't done yet. Entries are deleted when complete.

Each subdirectory has its own `INDEX.md`. Keep these indexes in sync when adding or renaming files. Add a new top-level subdirectory only when you have material that doesn't fit any of the five above.
