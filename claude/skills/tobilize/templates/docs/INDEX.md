# Documentation

Durable documentation about this project. Anything Claude (or a human) should be able to look up later, organized so the right material is reachable when a task calls for it.

- [`approach.md`](approach.md) — how the assistant works in this codebase: where instructions live, how context is engineered.

## Subdirectories

- [`architecture/`](architecture/INDEX.md) — cross-cutting patterns and conventions that apply system-wide. Answers *"how do we do X here, in general?"*.
- [`design/`](design/INDEX.md) — feature-specific knowledge. Answers *"how does this specific feature work?"*.
- [`domain/`](domain/INDEX.md) — business logic and knowledge about the field the project operates in.
- [`plan/`](plan/INDEX.md) — outstanding work the project wants done but hasn't done yet. Entries are deleted when complete.

Each subdirectory has its own `INDEX.md`. Keep these indexes in sync when adding or renaming files. Add a new top-level subdirectory only when you have material that doesn't fit any of the four above.
