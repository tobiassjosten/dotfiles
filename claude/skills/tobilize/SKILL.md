---
name: tobilize
description: Bootstrap or sync the tobilize approach in the current project — a thin CLAUDE.md that imports @docs/approach.md plus a docs/ tree (architecture/, design/, domain/, process/, and plan/ or an external work tracker) with INDEX.md in each. Discovers project tooling and layout to seed real build commands and an initial architecture overview, not generic placeholders. Also offers method-specific guidance files (DDD, TDD, Hexagonal, SOLID).
disable-model-invocation: true
context: fork
allowed-tools: Bash(ls:*), Bash(diff:*), Bash(grep:*), Bash(find:*), Read, Edit, Write, AskUserQuestion
---

Align the current project with the tobilize approach: a thin `CLAUDE.md` that imports `@docs/approach.md`, plus a `docs/` tree (`architecture/`, `design/`, `domain/`, `process/`, and — depending on the project's outstanding-work mode — `plan/`) with `INDEX.md` in each.

## Precedence over existing conventions

When the project already has documentation or instructions that conflict with how this skill captures knowledge — a different `CLAUDE.md` philosophy, a different `docs/` layout, different file names or category boundaries, ADRs under `docs/decisions/`, narrative material spread across the repo root — **the tobilize approach wins.** Existing content is reorganized, renamed, split, or moved to fit the structure described in this skill; the skill is not a passive overlay that defers to whatever was there before.

This applies to *how* knowledge is structured, not the knowledge itself. Preserve the substance of hand-authored material when migrating — but route it through tobilize's destinations, classifications, and conventions even if the project previously used a different scheme. The per-section proposal in Step 3 still lets the user redirect individual decisions, but the **default** proposal aligns the project with the skill, not the other way around. When a section in the existing `CLAUDE.md` or a pre-existing doc file straddles tobilize's categories, propose splitting it across tobilize destinations rather than keeping the original grouping intact.

## Paths

Two roots are referenced throughout this skill. Resolve each **once** at the start of the run, then treat every path below as relative to one of them.

- **Skill root** — the directory containing this `SKILL.md`. Use `${CLAUDE_PLUGIN_ROOT}` if Claude Code sets it (the conventional env var name); otherwise resolve from the location Claude Code reports for this `SKILL.md`. Every `templates/...` path is relative to the skill root.
- **Project root** — `${CLAUDE_PROJECT_DIR:-$PWD}`. Every `CLAUDE.md` / `docs/...` path is relative to the project root.

When a tool call needs an absolute path, prepend the resolved root.

## Reliance on Git

This skill takes no backups before it writes. **Undo is git's job.** Before accepting any proposed change, the user should ensure the project is in a committed (or otherwise recoverable) state, so that `git diff` / `git checkout -- <file>` / `git restore` can revert anything they don't want. The skill also leaves all writes uncommitted — staging and committing is the user's call.

If the project isn't a git repo, warn the user before any non-fresh-scaffold write.

## Outstanding-work modes

Projects track not-yet-done work in one of two modes, and several steps below branch on it:

- **Plan mode** — outstanding work lives in `docs/plan/`, one file per change. This is what the templates are written for.
- **Tracker mode** — outstanding work lives in a work tracker (Backlog.md, Jira, Linear, beads, …). `docs/plan/` does not exist, and the docs tree points at the tracker instead.

**Detecting the mode.** An existing `docs/plan/INDEX.md` means plan mode. A tracker signal — a `backlog/config.yml`, a `.beads/` directory, a tracker MCP server, or `CLAUDE.md`/`docs/approach.md` naming a tracker as where work is tracked — means tracker mode. When neither signal exists (a fresh scaffold), or both do, ask the user via `AskUserQuestion` rather than guessing.

**Tracker-mode adaptations.** In tracker mode, adapt what you write — and treat these adaptations as deliberate when syncing, never as drift to revert:

- `docs/approach.md` — drop the `plan/` bullet from the structure section ("Five subdirectories" becomes "Four subdirectories"); after the list, note that outstanding work is tracked in the project's tracker (name it, and point at where the tracker's workflow is documented, typically `CLAUDE.md`) and should be searched before starting new work; "All but `plan/` accumulate over time" becomes "All four accumulate over time"; retitle "Suggesting `plan/` entries" to "Suggesting follow-up tasks" and reframe it around proposing tracker tasks (a draft title, a one-line *what / why / done when*, ordering constraints as dependencies) — the end-of-task suggestion habit itself stays; "The five base subdirectories" becomes "The four base subdirectories".
- `docs/INDEX.md` — drop the `plan/` entry, note where outstanding work is tracked instead, and "five above" becomes "four above".
- Never scaffold `docs/plan/`, propose reinstating it, or sync plan-related template prose into a tracker-mode project.

## 1. Discover the project

Before reading state or proposing changes, gather facts about what this project actually is. Discovery feeds the scaffold, migrate, and drift-fix steps so the docs you write contain **real project content**, not generic placeholders. Run a small set of fast checks; the goal is signal, not exhaustive analysis. Skip discovery entirely only when Step 2 lands in the pure sync case (`docs/approach.md` already exists) — sync touches only managed files and doesn't need it.

### Language and tooling

Detect from manifest files at the project root (and one level down for obvious monorepos). Each manifest implies a default set of commands; pick the smallest set covering install/setup, test, run/dev, build.

| Manifest | Implies |
|---|---|
| `go.mod` | Go module — `go test ./...`, `go build ./...`, `go run ./<cmd-path>` |
| `package.json` | Node/JS — read the `scripts` block; pick `dev`/`start`, `build`, `test`, `lint`. Lockfile signals the runner: `pnpm-lock.yaml` → pnpm, `yarn.lock` → yarn, `package-lock.json` → npm, `bun.lockb` → bun |
| `Cargo.toml` | Rust crate — `cargo test`, `cargo build`, `cargo run` |
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python — check for poetry, uv, hatch, plain pip; derive test and run |
| `Gemfile` | Ruby — `bundle install`, `bundle exec rake test`, plus framework-specific (`rails s` if Rails) |
| `pom.xml`, `build.gradle`, `build.gradle.kts` | JVM — `mvn test`, `gradle test`, etc. |
| `Makefile`, `justfile`, `Taskfile.yml` | Read the targets; **prefer these over language defaults** when present — they're the project's conventional entry points |
| `wrangler.toml`, `wrangler.jsonc` | Cloudflare Worker — `wrangler dev`, `wrangler deploy` |
| `Dockerfile`, `docker-compose.yml` | Containerized — note for the layout overview, don't elevate as default commands |

When a task runner (`make`, `just`) wraps a lower-level tool, use the runner's targets — that's the convention the project signals.

### Layout

List top-level directories and sniff each one's purpose. Recognize common patterns; for the rest, describe what's in it from one or two files glanced at.

- `cmd/` — entry binaries (Go convention)
- `internal/` — private packages (Go convention)
- `pkg/` — public packages
- `src/` — source root
- `app/`, `pages/`, `routes/` — web-framework routes
- `domain/`, `application/`, `infrastructure/`, `ports/`, `adapters/` — DDD / hexagonal layers
- `tests/`, `test/`, `__tests__/` — test trees
- `migrations/` — database migrations
- `scripts/` — operational scripts
- `docs/` — already managed by this skill, but pre-existing content here is a flag to surface

For unrecognized directories, write what's there ("contains the four service entry points" / "auto-generated OpenAPI clients") rather than guessing.

### Work tracking

Look for how the project tracks outstanding work: a `docs/plan/` directory, a canonical `TODO.md`, or a tracker signal (`backlog/config.yml`, `.beads/`, a tracker MCP server, a tracker named in `CLAUDE.md`). This feeds the outstanding-work mode (see "Outstanding-work modes" above).

### README and existing docs

If `README.md` is present, read it for the project description and any commands not picked up from manifests. Note what it already covers (overview, install, usage, contributing) — Step 3 uses this to decide whether to scaffold a README, append to an existing one, or leave it alone. If `README.md` is **absent**, note that too: it's a flag for Step 3 to scaffold one from `templates/README.md` so the `@README.md` import in `CLAUDE.md` resolves.

If `ARCHITECTURE.md`, `CONTRIBUTING.md`, or pre-existing `docs/*` content exists, **don't auto-migrate** — flag them in the report so the user knows hand-curated material may need folding in. A `CONTRIBUTING.md` is fine left in place — it's a conventional location and `README.md` typically links to it rather than absorbing it.

### Output

Discovery produces an in-context summary: detected language(s), suggested build/test/run commands, top-level layout with brief descriptions, and flags about existing docs. This summary is what Step 3 draws from when filling scaffolded files. Use a few targeted `ls` / `find` / `grep` / `Read` calls; don't crawl the whole tree.

## 2. Read project state

Check whether these exist in the project root:

- `CLAUDE.md`
- `README.md`
- `docs/approach.md`

`CLAUDE.md` and `docs/approach.md` are what drive the case selection in Step 3. `README.md` presence is a secondary input — it doesn't change which case applies, but it determines whether the fresh-scaffold and migrate paths write a `README.md` (only when one doesn't already exist) and whether the migrate path can route overview/install/usage/contribution sections to an existing README or a new one.

## 3. Decide what to do

**Neither exists — fresh project.** Scaffold the full tobilize structure. No proposal needed (nothing to overwrite); just create the files and report what was done.

Copy from `templates/` to the project root:

- `CLAUDE.md`
- `README.md` — **only if the project doesn't already have one.** If a `README.md` exists, leave it alone (it's user-owned content, not a managed file). Either way, the `@README.md` import in `CLAUDE.md` will resolve.
- `docs/INDEX.md`
- `docs/approach.md`
- `docs/architecture/INDEX.md`
- `docs/design/INDEX.md`
- `docs/domain/INDEX.md`
- `docs/process/INDEX.md`

Then resolve the outstanding-work mode (see "Outstanding-work modes"; on a fresh scaffold there are usually no signals, so ask). In plan mode, additionally copy:

- `docs/plan/INDEX.md`
- `docs/plan/1-finish-legacy-migration-EXAMPLE.md`
- `docs/plan/2-extract-billing-service-EXAMPLE.md`
- `docs/plan/3-add-event-bus-EXAMPLE.md`
- `docs/plan/consolidate-logging-EXAMPLE.md`

In tracker mode, skip the `docs/plan/` templates and apply the tracker-mode adaptations to the files just scaffolded.

The `docs/plan/` files other than `INDEX.md` are example placeholders demonstrating the naming convention — the `-EXAMPLE` suffix is the signal to delete or replace them. Tell the user this in the report. Likewise the scaffolded `README.md` is a thin stub with placeholder comments — call it out as something to flesh out, not something the skill will manage on future runs.

**Fill the scaffold from discovery.** A bare template copy is not enough; the point of discovery is that scaffolded files carry real project content, not generic placeholders.

- **`CLAUDE.md` → `## Build / test / run`** — replace the placeholder comment with the commands from discovery, one per line. If discovery found nothing concrete (truly empty project), leave the placeholder comment alone.
- **`docs/architecture/overview.md`** (new file, **not** copied from a template — write it inline) — capture the discovered top-level layout. Use this shape:

  ```markdown
  # Layout

  Top-level directories and what lives in each.

  - `cmd/` — service entry points; one binary per subdirectory.
  - `internal/` — private packages, not importable outside this module.
  - `migrations/` — SQL migrations applied at startup.
  ```

  One line per directory. Skip directories that are obvious from convention and don't carry project-specific meaning (`.git/`, `.github/`, `node_modules/`, `vendor/`, `target/`, `dist/`). If the project is empty or has no clear layout, skip this file.

  When you write `overview.md`, update `docs/architecture/INDEX.md` to link it — replace the "no documents yet" placeholder with a list entry (same shape as the method-file index update in Step 4).
- **`docs/domain/`, `docs/design/`** — leave the placeholder INDEX content as-is; these grow as the user works on specific features and domain concepts.
- **`README.md` (only when scaffolded fresh)** — if the scaffolded README is being written, fill in what discovery turned up: replace `{{Project name}}` with the directory name (or a name found in manifest metadata if obvious), and use the discovered install/run commands to seed the Install and Usage sections. Leave the rest of the placeholders as comments for the user to flesh out. Don't touch an existing README — it's user-owned.
- **README-derived facts (when README already exists)** — discovery may have read facts out of the existing README. The one-line description belongs in the natural place (as project context Claude reads via `@README.md`); don't duplicate it into `docs/`.

The user can edit anything you wrote — call it out in the report as a best-guess seed.

**`CLAUDE.md` exists, `docs/approach.md` does not — migrate.** The project has an existing `CLAUDE.md` to reorganize.

Read the project's `CLAUDE.md` and `README.md` (if present). Classify each section of `CLAUDE.md`:

| Section type | Destination |
|---|---|
| Title, top-level navigation, `@README.md` import, build/test commands | **Keep** in `CLAUDE.md` |
| Project overview / elevator pitch, "what this is" | `README.md` (create one if absent, otherwise propose merging) |
| Installation, getting started, prerequisites | `README.md` |
| Usage examples, CLI invocations, high-level user-facing workflows | `README.md` |
| Contributing guide, issue / PR conventions, code of conduct | `README.md` (or a separate `CONTRIBUTING.md` if it's substantial) |
| Overall shape of the system, layering, cross-cutting concerns | `docs/architecture/` |
| Coding conventions, style guides, naming rules | `docs/architecture/` |
| Deployment, release, ops, runbooks | `docs/process/` |
| How-we-work procedure: task writing, tooling operation, cross-repo workflows | `docs/process/` |
| Specific features, modules, or packages | `docs/design/` |
| Per-feature troubleshooting / FAQ | `docs/design/` (alongside the feature) |
| Cross-cutting troubleshooting / FAQ | `docs/architecture/` |
| Domain knowledge, terminology, external systems, business rules | `docs/domain/` |
| TODOs, deferred cleanup, pending refactors, chunked migrations | `docs/plan/` in plan mode (one file per change; see `docs/plan/INDEX.md` for naming); filed as tracker tasks in tracker mode |

The four `README.md` rows reflect the rule: README is the project's human-facing front door, covering overview and general functionality. Content that explains *what the project is* and *how to use it from the outside* belongs there. Content about *how it's built internally* belongs in `docs/`. When `CLAUDE.md` has user-facing material that isn't in `README.md`, propose moving it; when there's no `README.md` yet, propose creating one (copy the template scaffold, fill in what the migrated sections cover, and route the user-facing sections into it).

The table is a guide, not a decision tree — many sections will sit between two rows. When in doubt, prefer moving content to `docs/` over keeping `CLAUDE.md` thick.

**Propose per-section, not as a single monolith.** Real `CLAUDE.md` files have sections that straddle categories or don't fit any row cleanly; a single bundled plan hides those judgment calls. Instead:

1. List every section of the existing `CLAUDE.md` (heading + one-line summary).
2. For each, propose one of: **Keep** (stays in `CLAUDE.md`), **Move to `<destination file>`** (with a suggested filename), **Split** (this section actually contains N topics — propose each), or **Ambiguous** (call it out, suggest options, ask).
3. Show the resulting trimmed `CLAUDE.md` and the list of new files to be created.
4. Let the user redirect any individual decision before confirming. Iterate until they say go.

If the existing `CLAUDE.md` is already thin, the proposal collapses to a single-line insertion of `@docs/approach.md`. That's fine — say so explicitly rather than dressing it up.

**Augment the proposal with discovery findings.** Section classification is about existing `CLAUDE.md` content; discovery adds material on top:

- If existing `CLAUDE.md` has no build/test/run section but discovery found commands, propose adding one.
- If existing `CLAUDE.md` has build commands but they're stale or thinner than what discovery suggests (e.g., a single `make test` when there are also `make lint`, `make build` targets), surface the gap and propose an update.
- Propose a new `docs/architecture/overview.md` seeded from the discovered layout — **unless** a "Layout" / "Project structure" / "Repository structure" section already exists in `CLAUDE.md` and is being moved to `docs/architecture/`, in which case let the existing content win (don't duplicate or overwrite hand-authored material).
- **README handling.** If no `README.md` exists at the project root, propose scaffolding one from `templates/README.md` (with `{{Project name}}` filled in and discovered install/run commands seeded) — and route any user-facing sections being migrated out of `CLAUDE.md` (overview, install, usage, contributing) into it instead of into `docs/`. If a `README.md` already exists, never overwrite it; when user-facing material is being migrated, propose either appending to the existing `README.md` (with a clear preview of the new sections) or leaving it for the user to fold in manually — let them choose.
- If `ARCHITECTURE.md`, `CONTRIBUTING.md`, or a pre-existing `docs/` directory with non-tobilize content exists at the project root, classify each file the same way as `CLAUDE.md` sections and **propose moving it into the appropriate tobilize destination** (`docs/architecture/`, `docs/design/`, `docs/domain/`, `docs/plan/`, or `README.md` for user-facing material). `CONTRIBUTING.md` is the one common exception — it's a conventional root-level file `README.md` typically links to, so leaving it in place is fine. The user can redirect any specific proposal, but the default is to fold pre-existing docs into tobilize's structure rather than leaving them alongside it.

Include these augmentations in the per-section proposal so the user can accept or redirect each one alongside the section moves.

On confirm: create the new files in one atomic pass, update the affected `INDEX.md` files, rewrite `CLAUDE.md` with `@docs/approach.md` inserted near the top (after any title and `@README.md` import), and create the rest of the scaffold (`docs/INDEX.md`, `docs/approach.md`, the subdirectory `INDEX.md` files — `architecture/`, `design/`, `domain/`, `process/`, plus `plan/` in plan mode — and, only if the project doesn't already have one, a scaffolded `README.md`). Do **not** copy the example `docs/plan/` files in this case — the user adds their own.

**`docs/approach.md` exists — sync.** No version stamps; compare semantically against the template and propose changes that move the project toward the ideal while preserving deliberate project edits.

Read both files:

```bash
diff -u docs/approach.md "$SKILL_ROOT/templates/docs/approach.md"
```

(Run from the project root with `SKILL_ROOT` resolved per "Paths" above.)

Empty diff → in sync, report and continue. Otherwise classify each hunk:

| Category | Default |
|---|---|
| **In template, missing from project file** — template gained material since the project's copy was written. | Propose adding. |
| **In project file, missing from template** — either a project-specific addition the user made, or legacy template residue from older skill versions (see below). | Preserve, unless it's recognizable residue. |
| **Same section, different wording** — template revised the prose. | Propose updating to the template wording, unless the project version reads like deliberate adaptation. |
| Whitespace-only | Preserve the project's whitespace, no proposal. |

**Recognizing legacy template residue.** Earlier versions of this skill wrote self-referential branding into project files: a template-version HTML comment on line 1, an admonition blockquote naming the skill, and trailing references in prose to the skill's own sync command. The new template contains none of that. Rule of thumb: any line containing "tobilize" in a managed scaffold file is residue — propose removing it.

**Propose, then write.** Present the classified hunks (one bullet per non-trivial difference, default action shown). Let the user accept-all, redirect individual items, or skip. On confirm, write the merged result to `docs/approach.md`. Do not touch any other file in this step.

If every difference is a preserved project addition (the user has adapted the file substantially and the template adds nothing new), report "no template-driven changes" and continue.

**INDEX file sync.** After `approach.md`, run the same semantic-sync over each `INDEX.md` file that exists in the project: `docs/INDEX.md`, `docs/architecture/INDEX.md`, `docs/design/INDEX.md`, `docs/domain/INDEX.md`, `docs/process/INDEX.md`, and — in plan mode — `docs/plan/INDEX.md`. These files mix template prose (describing what goes in the directory) with user content (lists of documents the user has added). When classifying hunks:

- **Prose paragraphs** — header descriptions, naming conventions, principles — are template content. Propose updates to match the template wording. This is how revised category descriptions (e.g., the architecture/design distinction) propagate into existing projects.
- **Bullet list entries linking to documents** (e.g. `` - [`auth.md`](auth.md) — ... ``) are user content. Preserve them verbatim.
- **The `*No documents yet — …*` placeholder** is template content. If the project file has real list entries, drop the placeholder from the merged result; if both still have the placeholder, sync the wording.
- **`docs/INDEX.md` subdirectory list.** The standard entries (`architecture/`, `design/`, `domain/`, `process/`, and `plan/` in plan mode) carry template-owned descriptions — propose updates. If the user has added an extra subdirectory per the "Adding subdirectories" guidance in `approach.md`, preserve that entry. In tracker mode, the absence of `plan/` — and the tracker note in its place in both `docs/INDEX.md` and `approach.md` — is deliberate adaptation, not drift; never propose reinstating plan material (see "Outstanding-work modes").
- **`docs/plan/INDEX.md` "Current plan" section.** Everything above it is template prose and syncs normally; the entries listed under "Current plan" (including any `-EXAMPLE` placeholders) are user-owned and preserved.

Present these alongside the `approach.md` proposal so the user accepts or redirects them in the same pass. On confirm, write each merged INDEX file. If every INDEX is in sync, report "INDEX files in sync" and continue.

After the INDEX sync, run the same semantic-sync over each method file that exists in the project (see "Method file sync" in Step 4).

**Drift check.** Note any of these that are missing:

- `CLAUDE.md` exists and imports `@docs/approach.md`
- `docs/INDEX.md`
- `docs/architecture/INDEX.md`
- `docs/design/INDEX.md`
- `docs/domain/INDEX.md`
- `docs/process/INDEX.md`
- `docs/plan/INDEX.md` — **plan mode only**; in tracker mode its absence is correct

If anything is missing, list it and **offer to fix it inline** — ask the user via `AskUserQuestion` whether to scaffold the missing pieces. On **Yes**, copy the missing template files (or insert the missing `@docs/approach.md` import into `CLAUDE.md`) and report what was added. On **No**, leave the project alone.

**Legacy residue sweep.** Earlier skill versions stamped self-referential branding into files the sync flow doesn't touch — most commonly a suffix on the `approach.md` entry in `docs/INDEX.md`. Grep the project's `docs/` tree and `CLAUDE.md` for "tobilize" (case-insensitive); for any match that is recognizable legacy branding (not user content that happens to mention the skill), surface it and offer to remove the residue inline. The principle: the project should adhere to the approach without naming the skill that scaffolded it.

## 4. Method guidance files

After the scaffold/migrate/sync step is complete (or would have been a no-op), handle method files in two passes: **sync** (for already-adopted methods) and **offer** (for methods not yet adopted).

### Available methods

| Method | Template | Destination |
|---|---|---|
| Domain-Driven Design | `templates/methods/ddd.md` | `docs/architecture/ddd.md` |
| Test-Driven Development | `templates/methods/tdd.md` | `docs/architecture/tdd.md` |
| Hexagonal Architecture | `templates/methods/hexagonal.md` | `docs/architecture/hexagonal.md` |
| SOLID | `templates/methods/solid.md` | `docs/architecture/solid.md` |

### Method file sync

For each method whose destination file already exists in the project, apply the same semantic-sync used for `docs/approach.md`:

```bash
diff -u docs/architecture/<method>.md "$SKILL_ROOT/templates/methods/<method>.md"
```

Classify each hunk (template addition, project-specific addition, modified wording, whitespace) and propose accordingly. Any line containing "tobilize" is legacy residue — the new templates write none — and should be flagged for removal. On confirm, write the merged result to that method file only.

### Offering new methods

For each method whose destination does **not** exist, offer it via `AskUserQuestion`. **Never write a method file without an explicit Yes from the user — not even in auto mode.** Do not inspect the codebase for signals of method usage beforehand; offer every unadopted method regardless of what the project looks like, and let the user decide.

**Batch into a single `AskUserQuestion` call** with one question per method-not-yet-adopted, asked together (the tool accepts up to four questions). Each question's options: **Yes** (copy template, update `docs/architecture/INDEX.md`), **No** (skip). Phrase each question one line, describing the method.

> Example phrasing:
> - *"Add `docs/architecture/ddd.md`? Domain-Driven Design guidance for aggregates, value objects, and ubiquitous language."*
> - *"Add `docs/architecture/solid.md`? Guidance on the five SOLID principles for OO design."*

On **Yes** for any method: copy the template file to the destination verbatim, then update `docs/architecture/INDEX.md` (see "INDEX shape" below).

If all four destinations already exist (the sync pass handled them), skip the offering step.

### INDEX shape when adding a method file

The fresh `docs/architecture/INDEX.md` template looks like:

```markdown
# Architecture

General principles for how the application is structured: overall shape, layering, module boundaries, cross-cutting concerns, and the major decisions that determined them.

*No documents yet — add files here as architectural patterns and structural decisions accumulate. Update this index when you do.*
```

When the first method file is added, replace the placeholder italic line with a list and the new entry. The result for, say, DDD:

```markdown
# Architecture

General principles for how the application is structured: overall shape, layering, module boundaries, cross-cutting concerns, and the major decisions that determined them.

- [`ddd.md`](ddd.md) — Domain-Driven Design guidance for working with aggregates, value objects, and ubiquitous language.
```

When subsequent method files are added (placeholder already gone), append to the existing list:

```markdown
- [`ddd.md`](ddd.md) — Domain-Driven Design guidance.
- [`tdd.md`](tdd.md) — Test-Driven Development guidance.
```

Use a one-line description per entry. If the user has added their own architecture docs to the list, leave them in place — just append the method entry below them.

## 5. Report

Summarize what changed (or that nothing did), list any drift the user declined, and note which method files were added, synced, or declined. Call out any discovery-derived content written (build commands in `CLAUDE.md`, the `docs/architecture/overview.md` seed) and remind the user it's a best-guess to review. Flag any existing `ARCHITECTURE.md`/`CONTRIBUTING.md`/`docs/` content the skill noticed but did not touch. Mention that all writes are uncommitted and the user should review with `git status` / `git diff` before committing. Keep it tight.

## 6. Offer follow-up verification

After the report, offer two optional deeper checks via a single `AskUserQuestion` call (two questions, run independently, default Yes for each). Skip the offer only when the run was a no-op (sync produced no changes and no method files were touched) or when the project is a truly empty fresh scaffold with nothing to check against.

**Sanity-check the documentation and instructions.** Re-read every file the skill produced, migrated, or touched in this run (`CLAUDE.md`, `docs/approach.md`, every affected `INDEX.md`, any method files just added, `docs/architecture/overview.md` if seeded, the scaffolded `README.md` if written) and look for:

- Broken `@`-imports and Markdown links.
- Contradictions across files (e.g., build commands that disagree, layout claims that don't match each other).
- Stale residue and surviving placeholders (`{{...}}`, `-EXAMPLE` files outside the fresh-scaffold case, "no documents yet" INDEX lines that should now have entries because something was added).
- Sections that read like generic template prose rather than project-specific content.

Mechanical issues (broken links, surviving placeholders, residue) are fixed inline after surfacing them. Substantive issues (sections that need rewriting, contradictions whose resolution isn't obvious) are surfaced for the user to address — do not invent project content to fill gaps.

**Deep-analyze the codebase against the documentation.** Read the actual code and check whether the documentation reflects reality:

- The `docs/architecture/overview.md` layout matches the current top-level directories.
- Build/test/run commands in `CLAUDE.md` are coherent with the manifest files (read `package.json` scripts, `Makefile` / `justfile` / `Taskfile.yml` targets, etc. — don't execute the commands).
- Domain terms in any `docs/domain/` files appear under recognizable names in the code.
- Method files just added describe patterns actually present in the code (aggregates / value objects for DDD; ports / adapters for Hexagonal; a real test tree for TDD; small focused responsibilities for SOLID). If a method was just added with a Yes, the user has signaled intent — gaps aren't necessarily wrong, but flag them as places to either align the code or trim the docs.
- Conventions described in any architecture or design file are followed in practice.

This is read-only: produce a divergence report classified as **doc-says-but-code-doesn't** (docs are wrong or aspirational) and **code-does-but-doc-doesn't** (docs are incomplete). Change nothing — the user decides what to do with the findings.

## Safety

- Fresh-project scaffold: free-running, nothing to overwrite.
- Migration, sync (approach + methods), drift-fix, and method adoption: propose, then write only on user confirmation.
- No backups are taken — undo relies on git. Warn the user up front if the project isn't a git repo.
- Never touch hand-authored content outside the explicit scope of the action you're taking.
