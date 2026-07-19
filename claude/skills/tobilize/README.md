# tobilize

An opinionated approach to developing software with Claude Code, packaged as a Claude Code **skill** so it can be applied across projects and kept in sync as it evolves. The approach is a strict structure for *where instructions live* and *how the context Claude reads for any given task is engineered* — so that Claude has the right material in front of it at the right time, and nothing more.

The skill's mechanism for delivering that approach is a thin `CLAUDE.md` (instructions for how to work and how to build context), a `README.md` for overview and general functionality (humans first, but the assistant reads it too), and a `docs/` tree (the durable, task-shaped context Claude pulls from) with indices for navigability.

Installing and updating is done by invoking the skill: `/tobilize`

## What `/tobilize` does

Before deciding what to write, `/tobilize` **discovers the project** — reads manifests (`go.mod`, `package.json`, `Cargo.toml`, `pyproject.toml`, `Makefile`, `wrangler.toml`, etc.), the README, and the top-level directory layout. Findings are used to fill scaffolded files with real project content (build/test/run commands that match the actual tooling, a layout overview that names actual directories), so a fresh Go project doesn't end up with `pnpm` examples in `CLAUDE.md`.

- **Fresh project** (no `CLAUDE.md`, no `docs/approach.md`) → scaffolds `CLAUDE.md`, `docs/INDEX.md`, the managed `docs/approach.md`, a stub `INDEX.md` in each of the four base subdirectories (`architecture/`, `design/`, `domain/`, `plan/`), and — only if one isn't already present — a thin `README.md` so the `@README.md` import in `CLAUDE.md` resolves. Seeds `docs/plan/` with example entries (suffixed `-EXAMPLE`) that demonstrate the filename convention. Fills `CLAUDE.md`'s build/test/run section from discovery, seeds the scaffolded `README.md`'s Install/Usage sections with discovered commands, and writes an initial `docs/architecture/overview.md` describing the discovered top-level layout.

- **Existing project with a `CLAUDE.md`** (no `docs/approach.md` yet) → analyzes the existing `CLAUDE.md` and proposes a reorganization: durable content moves into the appropriate `docs/` subdirectory so `CLAUDE.md` becomes thin, user-facing material (overview, install, usage, contributing) is routed to `README.md` (scaffolded if absent, otherwise proposed as an append or flagged for manual fold-in), and the rest of the docs tree gets scaffolded. The proposal is augmented with discovery findings — missing build commands, a seed `docs/architecture/overview.md` from the discovered layout (skipped if `CLAUDE.md` already has a layout section being migrated), and flags for any pre-existing `ARCHITECTURE.md` / `CONTRIBUTING.md` content the user may want to fold in manually. The full plan is shown to the user before any file is touched.

- **`docs/approach.md` already in place** → semantic sync against the current template. Identical → no-op. Different → classifies each hunk (template addition, project-specific addition, modified wording, legacy residue) and proposes per-hunk: add what the template gained, preserve what the user added, update revised prose, strip self-referential branding left by earlier skill versions. The user accepts or redirects each item before any write. Method files (e.g. `docs/architecture/ddd.md`) sync the same way.

- **Missing pieces of the docs tree** (drift) → after the case-specific step, lists any missing `INDEX.md` files or a missing `@docs/approach.md` import in `CLAUDE.md`, and offers to fix them inline. The same pass also sweeps the docs tree for legacy self-referential residue left by earlier versions and offers to remove it — the principle is that the project should adhere to the approach without naming the skill that scaffolded it.

The cases are handled inline by the `/tobilize` skill itself — it reads filesystem state, decides which case applies, and (for everything except the fresh-project scaffold) proposes the plan before any write.

After handling scaffold/migrate/sync, `/tobilize` offers — via the Claude Code UI — to drop a guidance file for each recognized methodology (DDD, TDD, hexagonal architecture, SOLID) under `docs/architecture/`. Every method not yet adopted is offered, regardless of what the codebase looks like — there is no detection, and nothing is written without an explicit Yes. Method files already present in the project are re-synced against the templates on each run, same diff/confirm flow as `approach.md`.

## Reliance on Git for undo

`/tobilize` takes no backups before writing. Undo relies on git: before accepting any proposed change, make sure the project is in a committed (or otherwise recoverable) state, so `git diff` / `git restore` can revert anything you don't like. The skill leaves all writes uncommitted — staging and committing is your call. If the project isn't a git repo, `/tobilize` will warn you before any non-fresh-scaffold write.

## Install

The skill lives in the dotfiles repo (`claude/skills/tobilize/`) and reaches Claude Code through the repo's `~/.claude/skills` symlink — `make files` sets it up along with everything else. There is no separate installation step.

Verify by invoking the skill from inside a project:

```
/tobilize
```

## Update

Edit the skill in the dotfiles repo; changes are live immediately through the symlink. The next `/tobilize` in any project will diff the project's `docs/approach.md` (and any adopted method files) against the updated templates; if anything changed, the diff is surfaced and you can apply it.

## Versioning

There is no version stamp in any file the skill writes. The current `templates/docs/approach.md` (and the `templates/methods/*.md` files) are the source of truth, and sync is driven by comparing the project file against them — classifying each difference as a template improvement to pull in, a project-specific edit to preserve, or legacy residue to strip.

If you run `/tobilize` from a machine whose dotfiles checkout is older than the one that last synced a project, the comparison will surface template content as "missing from the project file" when it's actually a downgrade. Read the proposal before accepting; if it looks like a step backwards, pull the latest dotfiles and re-run.

## Layout

```
tobilize/
├── SKILL.md                           # the skill itself (frontmatter + instructions)
├── README.md                          # this file
└── templates/
    ├── CLAUDE.md
    ├── README.md                      # thin scaffold; only written when the project has no README
    ├── docs/INDEX.md
    ├── docs/approach.md               # the managed file
    ├── docs/architecture/INDEX.md
    ├── docs/design/INDEX.md
    ├── docs/domain/INDEX.md
    ├── docs/plan/INDEX.md
    ├── docs/plan/*-EXAMPLE.md         # example plan entries (scaffolded on fresh projects)
    └── methods/                       # optional methodology guides, offered by /tobilize
        ├── ddd.md
        ├── tdd.md
        ├── hexagonal.md
        └── solid.md
```

## Status

v2. Sync is semantic — the skill classifies each diff hunk and proposes per-item rather than wholesale-overwriting. Hand-edit detection on managed files is implicit (the proposal is what the user reviews; there is no checksum sidecar). Multi-step migrations are not supported — re-render is assumed to be idempotent.
